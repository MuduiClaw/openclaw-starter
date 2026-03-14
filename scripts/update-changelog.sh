#!/bin/bash
set -euo pipefail

# ============================================================================
# update-changelog.sh — 增量追加新提交到 CHANGELOG.md [开发中]
#
# 用法: bash scripts/update-changelog.sh [--since <tag|commit>] [--dry-run]
#
# 工作方式:
#   1. 读 .changelog-cursor（上次处理到的 commit hash）
#   2. 只处理 cursor→HEAD 之间的新提交
#   3. 追加到 [开发中] 段（不覆盖手写内容）
#   4. 更新 cursor
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)   SINCE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

# --- Baseline: cursor > tag > root ---
if [[ -z "$SINCE" && -f "$CURSOR_FILE" ]]; then
  CANDIDATE=$(tr -d '[:space:]' < "$CURSOR_FILE")
  git rev-parse --verify "$CANDIDATE" >/dev/null 2>&1 && SINCE="$CANDIDATE"
fi
if [[ -z "$SINCE" ]]; then
  SINCE=$(git tag -l 'v*' --sort=-version:refname | head -1 || echo "")
  [[ -z "$SINCE" ]] && SINCE=$(git rev-list --max-parents=0 HEAD)
fi

info "扫描自 ${SINCE:0:8} 以来的提交"

# --- Read existing for dedup ---
existing=""
[[ -f "$CHANGELOG" ]] && existing=$(cat "$CHANGELOG")

is_dup() {
  local key="${1:0:40}"
  [[ -n "$key" ]] && echo "$existing" | grep -qF -- "$key" 2>/dev/null
}

# --- Parse & build ---
feat="" fix="" docs="" maint=""
count=0

while IFS= read -r subject; do
  [[ -z "$subject" ]] && continue

  # Clean noise
  msg=$(echo "$subject" | sed -E 's/\[scope-ack\]//g; s/\[spec:[^]]*\]//g; s/[[:space:]]+/ /g; s/ $//')

  # Parse conventional commit (regex in variable to avoid bash escaping issues)
  cc_re='^(feat|fix|docs|test|chore|ci|revert|refactor)(\([^)]+\))?:[[:space:]]*(.+)$'
  if [[ "$msg" =~ $cc_re ]]; then
    type="${BASH_REMATCH[1]}"
    body="${BASH_REMATCH[3]}"
  else
    continue
  fi

  # Skip noise
  [[ "$body" =~ ^[Mm]erge ]] && continue
  [[ "$body" =~ [Cc][Hh][Aa][Nn][Gg][Ee][Ll][Oo][Gg] ]] && continue
  [[ "$body" =~ ^release ]] && continue

  # Dedup
  is_dup "$body" && continue

  count=$((count + 1))
  case "$type" in
    feat)                    feat+="- ${body}"$'\n' ;;
    fix|revert)              fix+="- ${body}"$'\n' ;;
    docs)                    docs+="- ${body}"$'\n' ;;
    test|chore|ci|refactor)  maint+="- ${body}"$'\n' ;;
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

# --- Insert before first --- after [开发中] ---
blkfile="${CHANGELOG}.blk"
printf '%s\n' "$block" > "$blkfile"

if grep -q '^## \[开发中\]\|^## \[Unreleased\]' "$CHANGELOG" 2>/dev/null; then
  awk -v bf="$blkfile" '
    /^## \[开发中\]/ || /^## \[Unreleased\]/ { in_dev=1 }
    in_dev && /^---$/ {
      while ((getline line < bf) > 0) print line
      close(bf)
      in_dev=0
    }
    { print }
  ' "$CHANGELOG" > "${CHANGELOG}.tmp"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
else
  tmp="${CHANGELOG}.tmp"
  { echo "## [开发中]"; cat "$blkfile"; echo ""; echo "---"; echo ""; cat "$CHANGELOG"; } > "$tmp"
  mv "$tmp" "$CHANGELOG"
fi
rm -f "$blkfile"

git rev-parse HEAD > "$CURSOR_FILE"
success "已追加 $count 条到 [开发中]"
