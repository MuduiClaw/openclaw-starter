#!/usr/bin/env bash
# coding-preflight.sh — Hard gate before spawning coding agents
#
# Purpose: Prevent "inertia bypass" — spawning Codex/Claude without following the Loop.
# Must be run BEFORE sessions_spawn(runtime:"acp") for any coding task.
#
# Usage:
#   bash scripts/coding-preflight.sh --fix <project-dir>           # Fix-level (≤3 files, skip spec)
#   bash scripts/coding-preflight.sh --spec tasks/slug.md <dir>    # Feature-level (requires task-start first)
#   bash scripts/coding-preflight.sh --explore <project-dir>       # Exploration mode (skip spec, marked [探索])
#
# Exit 0 + clearance token = spawn allowed
# Exit 1 = blocked, do NOT spawn
#
# The clearance token MUST appear in the conversation before sessions_spawn.
# No token visible = process violation.

set -euo pipefail

MODE=""
SPEC_FILE=""
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)     MODE="fix"; shift ;;
    --spec)    MODE="spec"; SPEC_FILE="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    --explore) MODE="explore"; shift ;;
    *)         PROJECT_DIR="$1"; shift ;;
  esac
done

# For --fix and --explore, project dir is required upfront.
# For --spec, project dir can come from meta.json (deferred check).
if [[ "$MODE" != "spec" ]]; then
  if [[ -z "$PROJECT_DIR" ]]; then
    echo "⛔ SPAWN BLOCKED — no project directory specified" >&2
    echo "  Usage: bash scripts/coding-preflight.sh [--fix|--spec file|--explore] <project-dir>" >&2
    exit 1
  fi
  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "⛔ SPAWN BLOCKED — project directory not found: $PROJECT_DIR" >&2
    exit 1
  fi
fi

if [[ -z "$MODE" ]]; then
  echo "⛔ SPAWN BLOCKED — must specify mode: --fix, --spec <file>, or --explore" >&2
  echo "" >&2
  echo "  --fix       Fix-level change (≤3 files, clear scope, skip spec)" >&2
  echo "  --spec      Feature-level (requires task-start first)" >&2
  echo "  --explore   Exploration/prototype (skip spec, output marked [探索])" >&2
  exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TOKEN=$(date '+%s' | shasum | head -c 8)

# ─── Build check (multi-language, priority: Node > Go > Rust > Python) ───
# macOS has no GNU timeout; use perl alarm as portable alternative
run_with_timeout() {
  local secs="$1"; shift
  perl -e "alarm $secs; exec @ARGV" -- "$@"
}

check_project_health() {
  local dir="$1"
  echo "🔍 Pre-flight: checking project health..."

  if [[ -f "$dir/package.json" ]]; then
    # Node
    if command -v npm &>/dev/null; then
      if ! (cd "$dir" && run_with_timeout 120 npm run build --if-present 2>&1 | tail -3); then
        echo "⛔ SPAWN BLOCKED — Node build failed." >&2
        return 1
      fi
      echo "  ✅ Node build passed"
    else
      echo "  ⚠️  npm not found, skipping Node build check"
    fi
  elif [[ -f "$dir/go.mod" ]]; then
    # Go
    if command -v go &>/dev/null; then
      if ! (cd "$dir" && run_with_timeout 120 go build ./... 2>&1 | tail -3); then
        echo "⛔ SPAWN BLOCKED — Go build failed." >&2
        return 1
      fi
      echo "  ✅ Go build passed"
    else
      echo "  ⚠️  go not found, skipping Go build check"
    fi
  elif [[ -f "$dir/Cargo.toml" ]]; then
    # Rust
    if command -v cargo &>/dev/null; then
      if ! (cd "$dir" && run_with_timeout 120 cargo check 2>&1 | tail -3); then
        echo "⛔ SPAWN BLOCKED — Rust build failed." >&2
        return 1
      fi
      echo "  ✅ Rust build passed"
    else
      echo "  ⚠️  cargo not found, skipping Rust build check"
    fi
  elif [[ -f "$dir/pyproject.toml" || -f "$dir/setup.py" ]]; then
    # Python — compile check excluding venv dirs
    if command -v python3 &>/dev/null; then
      if ! (cd "$dir" && run_with_timeout 120 python3 -c "
import compileall, re
exit(0 if compileall.compile_dir('.', quiet=1, rx=re.compile(r'/(\\.venv|venv|node_modules|__pycache__)/')) else 1)
" 2>&1 | tail -3); then
        echo "⛔ SPAWN BLOCKED — Python compile check failed." >&2
        return 1
      fi
      echo "  ✅ Python compile passed"
    else
      echo "  ⚠️  python3 not found, skipping Python build check"
    fi
  else
    echo "  ⚠️  No recognized build system (package.json/go.mod/Cargo.toml/pyproject.toml)"
  fi
  return 0
}

# ─── Mode: Fix ───
if [[ "$MODE" == "fix" ]]; then
  # Verify project has AGENTS.md (agent can read it)
  if [[ ! -f "$PROJECT_DIR/AGENTS.md" ]]; then
    echo "⚠️  WARNING: No AGENTS.md in $PROJECT_DIR — agent won't have project context"
  fi

  if ! check_project_health "$PROJECT_DIR"; then
    echo "⛔ SPAWN BLOCKED — project build failed. Fix build first." >&2
    exit 1
  fi

  echo ""
  echo "✅ CODING PREFLIGHT CLEARED"
  echo "  Mode: fix"
  echo "  Project: $PROJECT_DIR"
  echo "  Time: $TIMESTAMP"
  echo "  Token: FIX-$TOKEN"
  echo ""
  echo "  Scope rules: ≤3 files changed, clear scope, no new architecture."
  echo "  If scope grows beyond fix → stop, write spec, re-run with --spec."
  exit 0
fi

# ─── Mode: Explore ───
if [[ "$MODE" == "explore" ]]; then
  echo ""
  echo "✅ CODING PREFLIGHT CLEARED [探索]"
  echo "  Mode: explore"
  echo "  Project: $PROJECT_DIR"
  echo "  Time: $TIMESTAMP"
  echo "  Token: EXPLORE-$TOKEN"
  echo ""
  echo "  Rules: Skip heavy verification. Self-test + retrospective only."
  echo "  Output marked [探索]. Must convert to full Loop if viable."
  exit 0
fi

# ─── Mode: Spec ───
if [[ "$MODE" == "spec" ]]; then
  if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
    echo "⛔ SPAWN BLOCKED — spec file not found: ${SPEC_FILE:-<empty>}" >&2
    echo "  Write the spec first, then: bash scripts/coding-preflight.sh --spec tasks/<slug>.md $PROJECT_DIR" >&2
    exit 1
  fi

  SLUG=$(basename "$SPEC_FILE" .md)
  PREFLIGHT_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  LOCK_DIR="$PREFLIGHT_REPO_ROOT/.task-lock"
  META_FILE="$LOCK_DIR/${SLUG}.meta.json"

  # Gate 1: task-start must have been run (upstream gate already checked review + status)
  if [[ ! -f "$LOCK_DIR/${SLUG}.started" ]]; then
    echo "⛔ SPAWN BLOCKED — task not started. 请先运行 task-start.sh" >&2
    echo "  bash scripts/task-start.sh $SPEC_FILE" >&2
    exit 1
  fi

  # Gate 2: Read project_path from meta.json as fallback if CLI arg not given
  if [[ -z "$PROJECT_DIR" && -f "$META_FILE" ]]; then
    PROJECT_DIR=$(python3 - "$META_FILE" <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f:
        meta = json.load(f)
    p = meta.get('project_path', '')
    print(p if p else '')
except Exception:
    pass
PYEOF
    ) || true
  fi

  if [[ -z "$PROJECT_DIR" ]]; then
    echo "⛔ SPAWN BLOCKED — no project directory specified and meta.json has no project_path" >&2
    echo "  Usage: bash scripts/coding-preflight.sh --spec $SPEC_FILE <project-dir>" >&2
    exit 1
  fi

  if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "⛔ SPAWN BLOCKED — project directory not found: $PROJECT_DIR" >&2
    exit 1
  fi

  # Gate 3: Project health (multi-language)
  if ! check_project_health "$PROJECT_DIR"; then
    exit 1
  fi

  echo ""
  echo "✅ CODING PREFLIGHT CLEARED"
  echo "  Mode: spec"
  echo "  Spec: $SPEC_FILE"
  echo "  Project: $PROJECT_DIR"
  echo "  Time: $TIMESTAMP"
  echo "  Token: SPEC-$TOKEN"
  exit 0
fi
