#!/bin/bash
set -euo pipefail

# ============================================================================
# release.sh — openclaw-starter release automation
#
# Usage:
#   bash scripts/release.sh [--version 1.4.0] [--dry-run]
#
# What it does:
#   1. Validate: clean working tree, on main, tests pass
#   2. Bump VERSION file
#   3. Update CHANGELOG.md: [Unreleased] → [x.y.z] - date
#   4. Commit + tag + push
#
# CHANGELOG convention:
#   - Keep an [Unreleased] section at the top
#   - This script moves its contents to the new version section
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m'

info()    { printf "${CYAN}[release]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[release]${NC} %s ✓\n" "$*"; }
warn()    { printf "${RED}[release]${NC} %s\n" "$*"; }
fatal()   { printf "${RED}[release]${NC} %s\n" "$*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# --- Parse args ---
VERSION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: bash scripts/release.sh [--version 1.4.0] [--dry-run]"
      exit 0
      ;;
    *) fatal "Unknown flag: $1" ;;
  esac
done

# --- Validate ---
info "Validating..."

BRANCH=$(git branch --show-current)
[[ "$BRANCH" == "main" ]] || fatal "Not on main branch (on: $BRANCH)"

if [[ -n "$(git status --porcelain)" ]]; then
  fatal "Working tree not clean. Commit or stash first."
fi

CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "0.0.0")
info "Current version: $CURRENT_VERSION"

# --- Determine new version ---
if [[ -z "$VERSION" ]]; then
  # Auto-increment: check CHANGELOG for hints
  # If [Unreleased] has "### 新功能" or "### New" → minor bump
  # Otherwise → patch bump
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
  if grep -A 50 '^\## \[Unreleased\]' CHANGELOG.md 2>/dev/null | grep -q '### 新功能\|### New'; then
    MINOR=$((MINOR + 1))
    PATCH=0
  else
    PATCH=$((PATCH + 1))
  fi
  VERSION="${MAJOR}.${MINOR}.${PATCH}"
fi

# Validate semver
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fatal "Invalid version: $VERSION (expected semver x.y.z)"
fi

info "New version: $VERSION"

# --- Check CHANGELOG has [Unreleased] ---
if ! grep -q '^\## \[Unreleased\]' CHANGELOG.md; then
  fatal "CHANGELOG.md missing [Unreleased] section. Add it before releasing."
fi

# Check [Unreleased] has content
UNRELEASED_CONTENT=$(sed -n '/^## \[Unreleased\]/,/^## \[/{ /^## \[/d; /^$/d; p; }' CHANGELOG.md)
if [[ -z "$UNRELEASED_CONTENT" ]]; then
  fatal "CHANGELOG.md [Unreleased] section is empty. Nothing to release."
fi

# --- Run tests ---
info "Running tests..."
if command -v bats &>/dev/null && [[ -d tests ]]; then
  if ! bats tests/ 2>&1 | tail -5; then
    warn "Some tests failed — review above"
    read -rp "Continue anyway? [y/N] " yn
    [[ "$yn" =~ ^[Yy] ]] || exit 1
  fi
fi

# --- Preview ---
echo ""
info "Release plan:"
printf "  ${DIM}Version:${NC}   %s → %s\n" "$CURRENT_VERSION" "$VERSION"
printf "  ${DIM}Tag:${NC}       v%s\n" "$VERSION"
printf "  ${DIM}Changes:${NC}\n"
echo "$UNRELEASED_CONTENT" | head -15 | sed 's/^/    /'
[[ $(echo "$UNRELEASED_CONTENT" | wc -l) -gt 15 ]] && printf "    ${DIM}... (%d more lines)${NC}\n" "$(( $(echo "$UNRELEASED_CONTENT" | wc -l) - 15 ))"
echo ""

if $DRY_RUN; then
  info "[dry-run] Would bump VERSION, update CHANGELOG, commit, tag v${VERSION}, push"
  exit 0
fi

read -rp "Proceed? [Y/n] " yn
[[ -z "$yn" || "$yn" =~ ^[Yy] ]] || exit 0

# --- Bump VERSION ---
echo "$VERSION" > VERSION
success "VERSION → $VERSION"

# --- Update CHANGELOG ---
TODAY=$(date +%Y-%m-%d)
# Replace [Unreleased] with [x.y.z] - date, add empty [Unreleased] above
sed -i '' "s/^## \[Unreleased\]/## [${VERSION}] - ${TODAY}/" CHANGELOG.md

# Add new [Unreleased] section at the top (after # Changelog header)
sed -i '' "/^# Changelog/a\\
\\
## [Unreleased]\\
" CHANGELOG.md

success "CHANGELOG → [${VERSION}] - ${TODAY}"

# --- Commit + Tag + Push ---
git add VERSION CHANGELOG.md
REVIEWED=1 git commit -m "chore: release v${VERSION}"
git tag -a "v${VERSION}" -m "Release v${VERSION}"

info "Pushing..."
git push origin main
git push origin "v${VERSION}"

success "Released: v${VERSION}"
echo ""
printf "  ${CYAN}GitHub:${NC} https://github.com/MuduiClaw/openclaw-starter/releases/tag/v${VERSION}\n"
printf "  ${DIM}Create GitHub Release manually or via:${NC}\n"
printf "  gh release create v${VERSION} --title 'v${VERSION}' --notes-file <(sed -n '/^## \\[${VERSION}\\]/,/^## \\[/{/^## \\[${VERSION}\\]/d;/^## \\[/d;p;}' CHANGELOG.md)\n"
