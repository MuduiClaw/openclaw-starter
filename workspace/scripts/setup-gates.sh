#!/usr/bin/env bash
# setup-gates.sh — Install OpenClaw project gates (git hooks)
# Usage: bash setup-gates.sh [--global] [--uninstall]
set -euo pipefail

# ─── Colors ───
RED='[0;31m'
GREEN='[0;32m'
YELLOW='[0;33m'
CYAN='[0;36m'
NC='[0m'

# ─── Find workspace root (look for SOUL.md or HEARTBEAT.md going up) ───
find_workspace() {
  local dir
  dir="$(cd "$(dirname "$0")/../.." && pwd)"
  # setup-gates.sh is at workspace/scripts/setup-gates.sh
  # So ../../ is the project root, workspace is ../
  local workspace="${dir}/workspace"
  if [[ -d "${workspace}/.githooks" ]]; then
    echo "$workspace"
    return 0
  fi
  # Fallback: maybe we're already in workspace
  if [[ -d "${dir}/.githooks" && -f "${dir}/SOUL.md" || -f "${dir}/HEARTBEAT.md" ]]; then
    echo "$dir"
    return 0
  fi
  return 1
}

# ─── Parse args ───
MODE="local"
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --global) MODE="global" ;;
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      echo "Usage: bash setup-gates.sh [--global] [--uninstall]"
      echo ""
      echo "  (default)     Install hooks for current repo only"
      echo "  --global      Install hooks globally (all repos on this machine)"
      echo "  --uninstall   Remove hooks configuration"
      exit 0
      ;;
  esac
done

# ─── Uninstall ───
if [[ $UNINSTALL -eq 1 ]]; then
  # Try both local and global
  removed=0
  if git config --local core.hooksPath &>/dev/null; then
    git config --local --unset core.hooksPath
    echo -e "${GREEN}✅ Removed local hooks configuration${NC}"
    removed=1
  fi
  if git config --global core.hooksPath &>/dev/null; then
    echo -e "${YELLOW}⚠️  Found global hooks configuration:${NC} $(git config --global core.hooksPath)"
    read -rp "Remove global hooks too? (y/N) " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      git config --global --unset core.hooksPath
      echo -e "${GREEN}✅ Removed global hooks configuration${NC}"
      removed=1
    fi
  fi
  if [[ $removed -eq 0 ]]; then
    echo "No hooks configuration found to remove."
  fi
  exit 0
fi

# ─── Find workspace ───
WORKSPACE=$(find_workspace) || {
  echo -e "${RED}❌ Cannot find workspace directory${NC}"
  echo "  Run this script from the ClawKing project root"
  exit 1
}

HOOKS_DIR="${WORKSPACE}/.githooks"
if [[ ! -f "${HOOKS_DIR}/prepare-commit-msg" ]]; then
  echo -e "${RED}❌ Hooks not found at ${HOOKS_DIR}${NC}"
  exit 1
fi

# Make hooks executable
chmod +x "${HOOKS_DIR}/prepare-commit-msg" "${HOOKS_DIR}/pre-push"

# ─── Install ───
if [[ "$MODE" == "global" ]]; then
  echo ""
  echo -e "${YELLOW}⚠️  WARNING: Global installation will affect ALL git repos on this machine.${NC}"
  echo -e "  Every repo you commit to or push from will run these gates."
  echo -e "  Non-workspace repos will be checked in strict mode (conventional commits, etc)."
  echo ""
  read -rp "Proceed with global installation? (y/N) " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  git config --global core.hooksPath "$HOOKS_DIR"
  echo -e "${GREEN}✅ Global hooks installed: ${HOOKS_DIR}${NC}"
else
  # Per-repo: must be in a git repo
  if ! git rev-parse --git-dir &>/dev/null; then
    echo -e "${RED}❌ Not in a git repository. Use --global or cd into a repo first.${NC}"
    exit 1
  fi
  git config core.hooksPath "$HOOKS_DIR"
  echo -e "${GREEN}✅ Local hooks installed for $(basename "$(git rev-parse --show-toplevel)")${NC}"
fi

# ─── Status report ───
echo ""
echo -e "${CYAN}── Active Gates ──${NC}"
echo "  🔒 Commit gates (prepare-commit-msg):"
echo "     • Prompt CHANGELOG enforcement"
echo "     • Scope lock (>5 files needs [scope-ack])"
echo "     • Spec gate (feat/fix with >=2 impl files needs [spec:slug])"
echo "     • REVIEWED=1 for code changes (non-workspace repos)"
echo "     • ShellCheck / JSON / YAML syntax validation"
echo "     • Tree-hash anti-forgery trailer"
echo ""
echo "  🚀 Push gates (pre-push):"
echo "     • Conventional commit format"
echo "     • Cumulative impl check (anti-salami-slicing)"
echo "     • Tree-hash trailer verification"
echo "     • TDD enforcement (test framework detected → tests required)"
echo ""

# Check optional components
SCRIPTS_DIR="${WORKSPACE}/scripts"
if [[ -x "${SCRIPTS_DIR}/gate-telemetry.sh" ]]; then
  echo -e "  📊 Telemetry: ${GREEN}enabled${NC} (${SCRIPTS_DIR}/gate-telemetry.sh)"
else
  echo -e "  📊 Telemetry: ${YELLOW}disabled${NC} (gate-telemetry.sh not found — gates still work without it)"
fi

echo ""
echo -e "${CYAN}── Quick Reference ──${NC}"
echo "  Skip gates for one commit:  git commit --no-verify"
echo "  Skip gates for one push:    git push --no-verify"
echo "  Uninstall:                   bash $0 --uninstall"
echo "  Docs:                        docs/GATES.md"
