#!/usr/bin/env bash
# spawn-agent.sh — Lightweight physical gate before spawning coding agents
# Replaces the bloated coding-preflight.sh (170 lines, never called)
# This script is the ONLY sanctioned path to spawn a coding agent.
#
# Usage:
#   bash scripts/spawn-agent.sh <project-dir>
#   bash scripts/spawn-agent.sh .                 # current dir
#
# Checks (3 only — fast, no fluff):
#   1. Valid git repo
#   2. Project AGENTS.md exists (agent needs context)
#   3. Baseline build passes (if detectable)
#
# Output: clearance token on success, exit 1 on failure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
TELEMETRY="${WORKSPACE_ROOT}/scripts/gate-telemetry.sh"
_tel() { [[ -x "$TELEMETRY" ]] && "$TELEMETRY" "$@" 2>/dev/null || true; }

PROJECT_DIR="${1:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
  echo "⛔ SPAWN BLOCKED — directory does not exist: $1" >&2
  _tel spawn-preflight block "unknown"
  exit 1
}

REPO_NAME="$(basename "$PROJECT_DIR")"

# ─── Gate 1: Valid git repo ───
if ! (cd "$PROJECT_DIR" && git rev-parse --show-toplevel) &>/dev/null; then
  echo "⛔ SPAWN BLOCKED — not a git repo: $PROJECT_DIR" >&2
  _tel spawn-preflight block "$REPO_NAME"
  exit 1
fi
echo "✅ Gate 1 — valid git repo: $REPO_NAME"

# ─── Gate 2: Project AGENTS.md exists ───
if [[ ! -f "$PROJECT_DIR/AGENTS.md" ]]; then
  echo "⛔ SPAWN BLOCKED — no AGENTS.md in $PROJECT_DIR" >&2
  echo "  Agent needs project context to work effectively." >&2
  _tel spawn-preflight block "$REPO_NAME"
  exit 1
fi
echo "✅ Gate 2 — AGENTS.md found"

# ─── Gate 3: Baseline build check (best-effort, 30s timeout) ───
BUILD_CMD=""
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  # Check if build script exists
  if grep -q '"build"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    BUILD_CMD="npm run build"
  elif grep -q '"typecheck"' "$PROJECT_DIR/package.json" 2>/dev/null; then
    BUILD_CMD="npm run typecheck"
  fi
elif [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
  BUILD_CMD="cargo check"
elif [[ -f "$PROJECT_DIR/go.mod" ]]; then
  BUILD_CMD="go build ./..."
elif [[ -f "$PROJECT_DIR/pyproject.toml" ]] || [[ -f "$PROJECT_DIR/setup.py" ]]; then
  # Python: just check syntax with py_compile on changed files
  BUILD_CMD=""  # skip — no universal build for Python
fi

if [[ -n "$BUILD_CMD" ]]; then
  echo "⏳ Gate 3 — running: $BUILD_CMD (timeout 30s)"
  # Use perl for portable timeout (macOS has no GNU timeout)
  if (cd "$PROJECT_DIR" && perl -e 'alarm 30; exec @ARGV' -- bash -c "$BUILD_CMD" 2>&1); then
    echo "✅ Gate 3 — build passed"
  else
    exit_code=$?
    if [[ $exit_code -eq 142 ]]; then
      echo "⚠️  Gate 3 — build timed out (>30s), proceeding anyway" >&2
    else
      echo "⛔ SPAWN BLOCKED — build failed: $BUILD_CMD" >&2
      echo "  Fix build errors before spawning agent." >&2
      _tel spawn-preflight block "$REPO_NAME"
      exit 1
    fi
  fi
else
  echo "✅ Gate 3 — no build command detected, skipped"
fi

# ─── All gates passed — emit token ───
TOKEN="SPAWN-$(date +%s | shasum | head -c 8)"
echo ""
echo "🟢 SPAWN CLEARED — token: $TOKEN"
echo "  repo: $REPO_NAME"
echo "  dir:  $PROJECT_DIR"

_tel spawn-preflight pass "$REPO_NAME"
exit 0
