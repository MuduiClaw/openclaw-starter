#!/bin/bash
set -euo pipefail

# Start infra-dashboard (called by LaunchAgent)
# __HOME__ will be replaced by setup.sh

export PATH="__NODE_BIN__:/usr/local/bin:/opt/homebrew/bin:$PATH"
export HOME="__HOME__"
export NODE_ENV="production"

# Dashboard token (set during setup)
if [ -f "$HOME/.config/openclaw/dashboard.env" ]; then
  source "$HOME/.config/openclaw/dashboard.env"
fi

if [[ -z "${DASHBOARD_TOKEN:-}" ]]; then
  echo "[infra-dashboard] DASHBOARD_TOKEN is empty; refusing to start" >&2
  exit 1
fi

cd "$HOME/projects/infra-dashboard"

# ABI guard: ensure better-sqlite3 matches this Node version
SQLITE_CHECK=$(node -e "
  try {
    const D = require('better-sqlite3');
    const d = new D(':memory:');
    d.close();
    console.log('ok');
  } catch(e) {
    console.log('fail');
  }
" 2>/dev/null || echo "fail")

if [[ "$SQLITE_CHECK" != "ok" ]]; then
  echo "[start] better-sqlite3 incompatible, rebuilding..."
  npm rebuild better-sqlite3
fi

if [[ ! -f .next/BUILD_ID ]] || find app components lib public -type f -newer .next/BUILD_ID | head -n 1 | grep -q .; then
  npm run build
fi

exec npx next start --port 3001 --hostname 0.0.0.0
