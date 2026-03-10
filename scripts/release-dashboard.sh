#!/bin/bash
set -euo pipefail

# ============================================================================
# release-dashboard.sh
# Build infra-dashboard standalone and upload to openclaw-starter GitHub Release.
#
# Usage:
#   bash scripts/release-dashboard.sh [--version 1.0.1]
#
# Prerequisites:
#   - gh CLI authenticated
#   - ~/projects/infra-dashboard exists and builds
#   - ~/projects/shared-ui exists (dependency)
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { printf "${CYAN}[release]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[release]${NC} %s ✓\n" "$*"; }
fatal()   { printf "${RED}[release]${NC} %s\n" "$*"; exit 1; }

DASHBOARD_DIR="${HOME}/projects/infra-dashboard"
STARTER_REPO="MuduiClaw/openclaw-starter"
TARBALL="/tmp/infra-dashboard-standalone.tar.gz"

# Parse args
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    *) fatal "Unknown arg: $1" ;;
  esac
done

# Auto-detect version from package.json
if [[ -z "$VERSION" ]]; then
  VERSION=$(node -e "console.log(require('${DASHBOARD_DIR}/package.json').version)")
fi
TAG="dashboard-v${VERSION}"

info "Building infra-dashboard v${VERSION}..."

# --- Build ---
cd "$DASHBOARD_DIR"
git pull --ff-only 2>/dev/null || true
npm install --prefer-offline 2>/dev/null
npm run build

# --- Verify standalone output ---
STANDALONE_DIR="${DASHBOARD_DIR}/.next/standalone"
if [[ ! -f "${STANDALONE_DIR}/server.js" ]]; then
  fatal "Standalone build not found. Check next.config.ts has output: 'standalone'"
fi

# --- Package ---
info "Packaging standalone tarball..."
cp -r .next/static "${STANDALONE_DIR}/.next/static" 2>/dev/null || true
cp -r public "${STANDALONE_DIR}/public" 2>/dev/null || true

# --- Copy native addons (Next.js standalone strips .node binaries) ---
# better-sqlite3: required for /api/usage/history
SQLITE_SRC="${DASHBOARD_DIR}/node_modules/better-sqlite3"
SQLITE_DST="${STANDALONE_DIR}/node_modules/better-sqlite3"
if [[ -d "$SQLITE_SRC/build/Release" ]] && [[ -d "$SQLITE_DST" ]]; then
  mkdir -p "${SQLITE_DST}/build/Release"
  cp "${SQLITE_SRC}/build/Release/better_sqlite3.node" "${SQLITE_DST}/build/Release/" 2>/dev/null || true
  # Also copy binding.gyp + src for npm rebuild on different Node versions
  cp "${SQLITE_SRC}/binding.gyp" "${SQLITE_DST}/" 2>/dev/null || true
  cp -r "${SQLITE_SRC}/src" "${SQLITE_DST}/" 2>/dev/null || true
  cp -r "${SQLITE_SRC}/deps" "${SQLITE_DST}/" 2>/dev/null || true
  success "Included better-sqlite3 native addon (Node $(node --version))"
fi

cd "$STANDALONE_DIR"
tar czf "$TARBALL" .
TARBALL_SIZE=$(du -sh "$TARBALL" | cut -f1)
success "Tarball: ${TARBALL_SIZE} → ${TARBALL}"

# --- Upload to GitHub Release ---
info "Uploading to ${STARTER_REPO} release ${TAG}..."

# Delete existing release if same tag
if gh release view "$TAG" --repo "$STARTER_REPO" &>/dev/null; then
  info "Deleting existing release ${TAG}..."
  gh release delete "$TAG" --repo "$STARTER_REPO" --yes 2>/dev/null || true
  # Also delete the git tag so we can recreate
  gh api -X DELETE "repos/${STARTER_REPO}/git/refs/tags/${TAG}" 2>/dev/null || true
fi

gh release create "$TAG" \
  "$TARBALL" \
  --repo "$STARTER_REPO" \
  --title "infra-dashboard v${VERSION} (standalone)" \
  --notes "Pre-built infra-dashboard v${VERSION} standalone bundle.

Download: \`curl -fsSL https://github.com/${STARTER_REPO}/releases/latest/download/infra-dashboard-standalone.tar.gz | tar xz -C ~/projects/infra-dashboard\`

Run: \`cd ~/projects/infra-dashboard && node server.js\`"

success "Released: https://github.com/${STARTER_REPO}/releases/tag/${TAG}"

# --- Verify download URL ---
info "Verifying download URL..."
HTTP_CODE=$(curl -fsSL -o /dev/null -w "%{http_code}" \
  "https://github.com/${STARTER_REPO}/releases/latest/download/infra-dashboard-standalone.tar.gz" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" == "200" ]]; then
  success "Download URL verified (HTTP 200)"
else
  printf "${RED}[release]${NC} Download URL returned HTTP %s — check release\n" "$HTTP_CODE"
fi

# Cleanup
rm -f "$TARBALL"
success "Done. infra-dashboard v${VERSION} published to ${STARTER_REPO} releases."
