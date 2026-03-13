#!/bin/bash
set -euo pipefail

# ============================================================================
# sync-to-template.sh — Maintainer tool
# Syncs generic files from live environment to starter kit (one-way)
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="${HOME}/clawd"
DRY_RUN=false

RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
# BLUE='[0;34m'  # reserved
BOLD='[1m'
DIM='[2m'
NC='[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)   SOURCE_DIR="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --help|-h)
      echo "Usage: ./sync-to-template.sh [--source ~/clawd] [--dry-run]"
      echo ""
      echo "Syncs generic files from live environment to starter kit."
      echo "  --source DIR   Live environment directory (default: ~/clawd)"
      echo "  --dry-run      Show diff only, don't write"
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${RED}Source directory not found: ${SOURCE_DIR}${NC}"
  exit 1
fi

echo -e "${BOLD}🦞 Sync: ${SOURCE_DIR} → ${SCRIPT_DIR}${NC}"
if $DRY_RUN; then echo -e "${YELLOW}DRY RUN — no files will be written${NC}"; fi
echo ""

# === WHITELIST: Files to sync ===
# Format: source_relative_path → starter_relative_path
# Only these files get synced. Everything else is excluded.

CHANGED=0
SKIPPED=0

sync_file() {
  local src="$1"
  local dst="$2"

  if [ ! -f "${SOURCE_DIR}/${src}" ]; then
    echo -e "${DIM}  skip  ${src} (not in source)${NC}"
    ((SKIPPED++)) || true
    return
  fi

  local dst_full="${SCRIPT_DIR}/${dst}"

  if [ -f "$dst_full" ]; then
    if diff -q "${SOURCE_DIR}/${src}" "$dst_full" &>/dev/null; then
      return  # identical, skip silently
    fi
    echo -e "${YELLOW}  diff  ${dst}${NC}"
    if $DRY_RUN; then
      diff --color=auto -u "$dst_full" "${SOURCE_DIR}/${src}" | head -30 || true
      echo ""
    else
      cp "${SOURCE_DIR}/${src}" "$dst_full"
    fi
    ((CHANGED++)) || true
  else
    echo -e "${GREEN}  new   ${dst}${NC}"
    if ! $DRY_RUN; then
      mkdir -p "$(dirname "$dst_full")"
      cp "${SOURCE_DIR}/${src}" "$dst_full"
    fi
    ((CHANGED++)) || true
  fi
}

sync_dir() {
  local src_dir="$1"
  local dst_dir="$2"
  local exclude="${3:-}"

  if [ ! -d "${SOURCE_DIR}/${src_dir}" ]; then
    echo -e "${DIM}  skip  ${src_dir}/ (not in source)${NC}"
    return
  fi

  # Find all files in source dir
  while IFS= read -r file; do
    local rel="${file#${SOURCE_DIR}/${src_dir}/}"

    # Skip excluded patterns
    if [[ -n "$exclude" ]]; then
      if echo "$rel" | grep -qE "$exclude"; then
        continue
      fi
    fi

    # Skip binary/generated
    if echo "$rel" | grep -qE '\.(pyc|pyo|whl|egg|DS_Store)$|__pycache__|node_modules|\.venv|\.git'; then
      continue
    fi

    sync_file "${src_dir}/${rel}" "${dst_dir}/${rel}"
  done < <(find "${SOURCE_DIR}/${src_dir}" -type f 2>/dev/null)
}

# ============================================================================
# SYNC WHITELIST
# ============================================================================

echo -e "${BOLD}Workspace files:${NC}"
sync_file "AGENTS.md" "workspace/AGENTS.md"
sync_file "HEARTBEAT.md" "workspace/HEARTBEAT.md"
sync_file "BOOTSTRAP.md" "workspace/BOOTSTRAP.md"

echo ""
echo -e "${BOLD}Scripts:${NC}"
sync_dir "scripts" "workspace/scripts" "xhs|bird|sync-discord|sync-gitlab|infra-model|daily-poster|guardian|desktop-cmd|wechat|record-win|cron-win|commits-to-mrr|fix-tailscale|check-repo-hygiene|weekly-hygiene"

echo ""
echo -e "${BOLD}Prompts:${NC}"
sync_dir "prompts" "workspace/prompts" "xhs|aihub|content-brief|content-closer|x-feed|xueda"

echo ""
echo -e "${BOLD}Eval:${NC}"
sync_dir "eval" "workspace/eval"

echo ""
echo -e "${BOLD}MCP Bridge:${NC}"
sync_dir "mcp-bridge" "workspace/mcp-bridge" "\.venv|__pycache__|uv\.lock"

echo ""
echo -e "${BOLD}Skills (generic only):${NC}"
GENERIC_SKILLS=(
  agent-guides brainstorming blueprint-infographic canvas-design
  codebase-standards crawl4ai design-os discord-ops docx find-skills
  frontend-design gpt-researcher heartbeat-guide kb-rag login-machine
  mcp-builder pdf planning-with-files product-manager-toolkit
  remotion-video-toolkit self-improving web-artifacts-builder
  webapp-testing xlsx
)

for skill in "${GENERIC_SKILLS[@]}"; do
  sync_dir "skills/${skill}" "workspace/skills/${skill}" "\.venv|__pycache__|node_modules|output/"
done

echo ""
echo -e "${BOLD}Config templates:${NC}"
# Config templates are manually maintained — just report if source changed
echo -e "${DIM}  (config templates are manually maintained, not auto-synced)${NC}"

# ============================================================================
# POST-SYNC: Secret scan
# ============================================================================
echo ""
echo -e "${BOLD}Secret scan:${NC}"
LEAKS=$(grep -rE '(sk-ant-|sk-proj-|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|xoxb-)' \
  --include='*.md' --include='*.sh' --include='*.json' --include='*.json5' \
  --include='*.py' --include='*.ts' --include='*.js' --include='*.yml' \
  --exclude-dir=node_modules --exclude-dir=.git \
  "${SCRIPT_DIR}/workspace/" "${SCRIPT_DIR}/config/" "${SCRIPT_DIR}/services/" 2>/dev/null || true)

if [[ -n "$LEAKS" ]]; then
  echo -e "${RED}  ⚠ POTENTIAL SECRETS FOUND — DO NOT COMMIT:${NC}"
  echo "$LEAKS" | head -20
  echo ""
  echo -e "${RED}  Fix these before committing!${NC}"
else
  echo -e "${GREEN}  Clean — no secrets detected ✓${NC}"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
if $DRY_RUN; then
  echo -e "${BOLD}Dry run: ${CHANGED} files would change, ${SKIPPED} skipped${NC}"
  echo -e "${DIM}Run without --dry-run to apply changes${NC}"
else
  echo -e "${BOLD}Synced: ${CHANGED} files changed, ${SKIPPED} skipped${NC}"
  if [[ $CHANGED -gt 0 ]]; then
    echo -e "${DIM}Review changes: git diff${NC}"
    echo -e "${DIM}Then: bump VERSION, update CHANGELOG.md, commit + tag${NC}"
  fi
fi
