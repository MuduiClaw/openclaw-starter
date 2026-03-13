#!/bin/bash
set -euo pipefail

# ============================================================================
# update-changelog.sh — Auto-update CHANGELOG.md [Unreleased] from git log
#
# Usage:
#   bash scripts/update-changelog.sh [--since <tag|commit>] [--dry-run]
#
# What it does:
#   1. Find last version tag (or use --since)
#   2. Parse conventional commits since that point
#   3. Group by type: feat→新功能, fix→修复, docs→文档, test→测试, chore→维护
#   4. Merge into [Unreleased] section, dedup against existing entries
#   5. Write back to CHANGELOG.md
#
# Called by: .githooks/post-commit (auto), or manually
# ============================================================================

CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

info()    { printf "${CYAN}[changelog]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[changelog]${NC} %s ✓\n" "$*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CHANGELOG="$REPO_ROOT/CHANGELOG.md"
SINCE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)   SINCE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: bash scripts/update-changelog.sh [--since <tag|commit>] [--dry-run]"
      exit 0
      ;;
    *) shift ;;
  esac
done

# --- Find baseline ---
if [[ -z "$SINCE" ]]; then
  # Find latest version tag (v*.*.*)
  SINCE=$(git tag -l 'v*' --sort=-version:refname | head -1 || echo "")
  if [[ -z "$SINCE" ]]; then
    # No tags — use root commit
    SINCE=$(git rev-list --max-parents=0 HEAD)
  fi
fi

info "Scanning commits since: $SINCE"

# --- Collect commits ---
declare -a FEAT=() FIX=() DOCS=() TEST=() CHORE=() OTHER=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Strip common noise: [scope-ack] [spec:xxx]
  clean=$(echo "$line" | sed -E 's/\[scope-ack\]//g; s/\[spec:[^]]*\]//g; s/[[:space:]]+$//; s/[[:space:]]+/ /g')

  # Parse conventional commit: type(scope): message or type: message
  re='^(feat|fix|docs|test|chore|revert|refactor)(\([^)]*\))?:[[:space:]]*(.+)$'
  if [[ "$clean" =~ $re ]]; then
    TYPE="${BASH_REMATCH[1]}"
    MSG="${BASH_REMATCH[3]}"
  elif [[ "$clean" =~ ^Revert[[:space:]] ]]; then
    TYPE="revert"
    MSG="$clean"
  else
    TYPE="other"
    MSG="$clean"
  fi

  # Skip merge commits, empty, and release commits
  [[ "$MSG" =~ ^[Mm]erge ]] && continue
  [[ "$MSG" =~ ^release\ v ]] && continue
  [[ "$MSG" == "chore: release v"* ]] && continue

  case "$TYPE" in
    feat)     FEAT+=("$MSG") ;;
    fix)      FIX+=("$MSG") ;;
    docs)     DOCS+=("$MSG") ;;
    test)     TEST+=("$MSG") ;;
    chore|refactor) CHORE+=("$MSG") ;;
    revert)   FIX+=("$MSG") ;;
    *)        OTHER+=("$MSG") ;;
  esac
done < <(git log --oneline --format="%s" "$SINCE"..HEAD 2>/dev/null)

TOTAL=$(( ${#FEAT[@]} + ${#FIX[@]} + ${#DOCS[@]} + ${#TEST[@]} + ${#CHORE[@]} + ${#OTHER[@]} ))
info "Found $TOTAL commits (feat:${#FEAT[@]} fix:${#FIX[@]} docs:${#DOCS[@]} test:${#TEST[@]} chore:${#CHORE[@]} other:${#OTHER[@]})"

if [[ $TOTAL -eq 0 ]]; then
  info "No new commits to add"
  exit 0
fi

# --- Read existing [Unreleased] entries for dedup ---
existing_entries=""
if [[ -f "$CHANGELOG" ]]; then
  existing_entries=$(sed -n '/^## \[Unreleased\]/,/^## \[/{/^## \[/d; p;}' "$CHANGELOG" 2>/dev/null || echo "")
fi

# --- Build new [Unreleased] section ---
new_section=""

add_section() {
  local header="$1"
  shift
  local -a items=("$@")
  [[ ${#items[@]} -eq 0 ]] && return

  local section_buf=""
  local seen=""
  # Dedup: skip entries already in changelog or duplicates within batch
  for item in "${items[@]}"; do
    local norm
    norm=$(echo "$item" | sed 's/[[:space:]]*$//' | cut -c1-60)
    # Skip if already in existing changelog
    if [[ -n "$norm" ]] && echo "$existing_entries" | grep -qF -- "$norm" 2>/dev/null; then
      continue
    fi
    # Skip if duplicate within this batch
    if [[ -n "$seen" ]] && echo "$seen" | grep -qxF -- "$norm" 2>/dev/null; then
      continue
    fi
    seen+="$norm"$'\n'
    section_buf+="- ${item}"$'\n'
  done
  # Only add header if there are entries
  if [[ -n "$section_buf" ]]; then
    new_section+="### ${header}"$'\n'
    new_section+="$section_buf"
  fi
  new_section+=$'\n'
}

add_section "新功能" "${FEAT[@]}"
add_section "修复" "${FIX[@]}"
add_section "文档" "${DOCS[@]}"
add_section "测试" "${TEST[@]}"
add_section "维护" "${CHORE[@]}"
[[ ${#OTHER[@]} -gt 0 ]] && add_section "其他" "${OTHER[@]}"

if [[ -z "$new_section" ]]; then
  info "All commits already in CHANGELOG"
  exit 0
fi

if $DRY_RUN; then
  info "[dry-run] Would add to [Unreleased]:"
  echo "$new_section"
  exit 0
fi

# --- Write to CHANGELOG ---
if [[ ! -f "$CHANGELOG" ]]; then
  # Create from scratch
  cat > "$CHANGELOG" <<EOF
# Changelog

## [Unreleased]

${new_section}
EOF
  success "Created CHANGELOG.md"
else
  # Replace [Unreleased] section content
  # Write new content to temp file, then stitch with awk
  tmpnew="${CHANGELOG}.new_section"
  printf '%s' "$new_section" > "$tmpnew"

  awk -v nsfile="$tmpnew" '
    /^## \[Unreleased\]/ {
      print
      print ""
      while ((getline line < nsfile) > 0) print line
      close(nsfile)
      # Skip old [Unreleased] content until next ## section
      while ((getline) > 0) {
        if ($0 ~ /^## \[/) { print; break }
      }
      next
    }
    { print }
  ' "$CHANGELOG" > "${CHANGELOG}.tmp"

  rm -f "$tmpnew"
  mv "${CHANGELOG}.tmp" "$CHANGELOG"
  success "Updated CHANGELOG.md [Unreleased] section"
fi

info "Done — $TOTAL commits processed"
