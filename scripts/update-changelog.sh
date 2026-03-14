#!/bin/bash
set -euo pipefail

# ============================================================================
# update-changelog.sh — 增量追加新提交到 CHANGELOG.md [开发中]
#
# 两种调用方式:
#   1. commit-msg hook 调用: bash update-changelog.sh --msg "feat: 新功能"
#      → 解析单条消息，追加到 CHANGELOG，git add（让它进同一个 commit）
#   2. 手动调用: bash update-changelog.sh [--since <ref>] [--dry-run]
#      → 扫描 cursor 到 HEAD 的所有提交
#
# 不需要 amend，不需要 post-commit hook。
# ============================================================================

CYAN='\033[0;36m'; GREEN='\033[0;32m'; NC='\033[0m'
info()    { printf "${CYAN}[changelog]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[changelog]${NC} %s ✓\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CHANGELOG="$REPO_ROOT/CHANGELOG.md"
CURSOR_FILE="$REPO_ROOT/.changelog-cursor"
SINCE=""
DRY_RUN=false
SINGLE_MSG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --msg)     SINGLE_MSG="$2"; shift 2 ;;
    --since)   SINCE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# --- Regex for conventional commit ---
cc_re='^(feat|fix|docs|test|chore|ci|revert|refactor)(\([^)]+\))?:[[:space:]]*(.+)$'

# --- Parse a single commit message into type+body, returns 1 if not parseable ---
parse_msg() {
  local msg="$1"
  # Clean noise
  msg=$(echo "$msg" | sed -E 's/\[scope-ack\]//g; s/\[spec:[^]]*\]//g; s/[[:space:]]+/ /g; s/ $//')

  if [[ "$msg" =~ $cc_re ]]; then
    PARSED_TYPE="${BASH_REMATCH[1]}"
    PARSED_BODY="${BASH_REMATCH[3]}"
  else
    return 1
  fi

  # Skip noise
  [[ "$PARSED_BODY" =~ ^[Mm]erge ]] && return 1
  [[ "$PARSED_BODY" =~ ^release ]] && return 1
  return 0
}

# --- Read existing [开发中] section only (not full file) for dedup ---
read_dev_section() {
  if [[ -f "$CHANGELOG" ]]; then
    sed -n '/^## \[开发中\]\|^## \[Unreleased\]/,/^---$\|^## v/{/^##\|^---/d; p;}' "$CHANGELOG" 2>/dev/null || echo ""
  fi
}

is_dup() {
  local body="$1"
  local dev_section="$2"
  # Match on first 40 chars, search ONLY within [开发中] section
  local key="${body:0:40}"
  [[ -n "$key" ]] && echo "$dev_section" | grep -qF -- "$key" 2>/dev/null
}

# --- Insert block before --- or next ## after [开发中] ---
insert_block() {
  local block_file="$1"

  if ! grep -q '^## \[开发中\]\|^## \[Unreleased\]' "$CHANGELOG" 2>/dev/null; then
    # No section — create at top
    local tmp="${CHANGELOG}.tmp"
    { echo "## [开发中]"; echo ""; cat "$block_file"; echo ""; echo "---"; echo ""; cat "$CHANGELOG"; } > "$tmp"
    mv "$tmp" "$CHANGELOG"
    return
  fi

  # Try inserting before --- first; fallback to before next ## v
  awk -v bf="$block_file" '
    /^## \[开发中\]/ || /^## \[Unreleased\]/ { in_dev=1 }
    in_dev && (/^---$/ || /^## v/) {
      while ((getline line < bf) > 0) print line
      close(bf)
      print ""
      in_dev=0
    }
    { print }
    END {
      # Fallback: if in_dev never closed (no --- or ## v), append at EOF
      if (in_dev) {
        while ((getline line < bf) > 0) print line
        close(bf)
      }
    }
  ' "$CHANGELOG" > "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
}

# =====================================================================
# Mode 1: Single message (called from commit-msg hook)
# =====================================================================
if [[ -n "$SINGLE_MSG" ]]; then
  if ! parse_msg "$SINGLE_MSG"; then
    exit 0  # Not a conventional commit, skip silently
  fi

  dev_section=$(read_dev_section)
  if is_dup "$PARSED_BODY" "$dev_section"; then
    exit 0  # Already recorded
  fi

  # Map type to emoji header
  case "$PARSED_TYPE" in
    feat)                    header="✨ 新功能（自动记录）" ;;
    fix|revert)              header="🐛 修复（自动记录）" ;;
    docs)                    header="📖 文档（自动记录）" ;;
    test|chore|ci|refactor)  header="🔧 维护（自动记录）" ;;
    *)                       exit 0 ;;
  esac

  block_file="${CHANGELOG}.blk"
  printf '\n### %s\n\n- %s\n' "$header" "$PARSED_BODY" > "$block_file"

  if $DRY_RUN; then
    info "[dry-run] 将追加: $PARSED_BODY"
    rm -f "$block_file"
    exit 0
  fi

  insert_block "$block_file"
  rm -f "$block_file"
  git add "$CHANGELOG" 2>/dev/null || true
  success "已记录: $PARSED_BODY"
  exit 0
fi

# =====================================================================
# Mode 2: Batch scan (manual or CI)
# =====================================================================

# Baseline: cursor > tag > root
if [[ -z "$SINCE" && -f "$CURSOR_FILE" ]]; then
  CANDIDATE=$(tr -d '[:space:]' < "$CURSOR_FILE")
  git rev-parse --verify "$CANDIDATE" >/dev/null 2>&1 && SINCE="$CANDIDATE"
fi
if [[ -z "$SINCE" ]]; then
  SINCE=$(git tag -l 'v*' --sort=-version:refname | head -1 || echo "")
  [[ -z "$SINCE" ]] && SINCE=$(git rev-list --max-parents=0 HEAD | head -n 1)
fi

info "扫描自 ${SINCE:0:8} 以来的提交"

dev_section=$(read_dev_section)
feat="" fix="" docs="" maint=""
count=0

while IFS= read -r subject; do
  [[ -z "$subject" ]] && continue
  parse_msg "$subject" || continue
  is_dup "$PARSED_BODY" "$dev_section" && continue

  count=$((count + 1))
  case "$PARSED_TYPE" in
    feat)                    feat+="- ${PARSED_BODY}"$'\n' ;;
    fix|revert)              fix+="- ${PARSED_BODY}"$'\n' ;;
    docs)                    docs+="- ${PARSED_BODY}"$'\n' ;;
    test|chore|ci|refactor)  maint+="- ${PARSED_BODY}"$'\n' ;;
  esac
done < <(git log --format="%s" "$SINCE"..HEAD 2>/dev/null)

info "发现 $count 条新提交"
[[ $count -eq 0 ]] && { $DRY_RUN || git rev-parse HEAD > "$CURSOR_FILE"; exit 0; }

# Build block
block=""
[[ -n "$feat" ]]  && block+=$'\n'"### ✨ 新功能（自动记录）"$'\n\n'"$feat"
[[ -n "$fix" ]]   && block+=$'\n'"### 🐛 修复（自动记录）"$'\n\n'"$fix"
[[ -n "$docs" ]]  && block+=$'\n'"### 📖 文档（自动记录）"$'\n\n'"$docs"
[[ -n "$maint" ]] && block+=$'\n'"### 🔧 维护（自动记录）"$'\n\n'"$maint"

if [[ -z "$block" ]]; then
  info "所有条目已存在"
  $DRY_RUN || git rev-parse HEAD > "$CURSOR_FILE"
  exit 0
fi

if $DRY_RUN; then
  info "[dry-run] 将追加:"
  echo "$block"
  exit 0
fi

block_file="${CHANGELOG}.blk"
printf '%s\n' "$block" > "$block_file"
insert_block "$block_file"
rm -f "$block_file"

git rev-parse HEAD > "$CURSOR_FILE"
success "已追加 $count 条到 [开发中]"
