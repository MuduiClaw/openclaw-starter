#!/bin/bash
set -euo pipefail

# Start infra-dashboard (standalone mode, called by LaunchAgent)
# __HOME__, __NODE_BIN__, __GATEWAY_PORT__ will be replaced by setup.sh

export PATH="__NODE_BIN__:/usr/local/bin:/opt/homebrew/bin:$PATH"
export HOME="__HOME__"
export NODE_ENV="production"
export PORT="3001"
export HOSTNAME="127.0.0.1"

# Dashboard token (set during setup)
if [ -f "$HOME/.config/openclaw/dashboard.env" ]; then
  source "$HOME/.config/openclaw/dashboard.env"
fi

if [[ -z "${DASHBOARD_TOKEN:-}" ]]; then
  echo "[infra-dashboard] DASHBOARD_TOKEN is empty; refusing to start" >&2
  exit 1
fi

# OpenClaw gateway connection (required for dashboard API)
export OPENCLAW_GATEWAY_URL="http://127.0.0.1:__GATEWAY_PORT__"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
if [[ -f "$OPENCLAW_CONFIG" ]]; then
  GW_TOKEN=$(node -e "
    const c = require('$OPENCLAW_CONFIG');
    const t = c?.gateway?.auth?.token || c?.gateway?.token || '';
    process.stdout.write(t);
  " 2>/dev/null || echo "")
  if [[ -n "$GW_TOKEN" ]]; then
    export OPENCLAW_GATEWAY_TOKEN="$GW_TOKEN"
  fi
fi

# Workspace paths
export CLAWD_ROOT="$HOME/clawd"
export OPENCLAW_WORKSPACE_ROOT="$HOME/clawd"
export OPENCLAW_ROOT="$HOME/.openclaw"
export OPENCLAW_CONFIG_PATH="$OPENCLAW_CONFIG"
export PROJECTS_ROOT="$HOME/projects"

cd "$HOME/projects/infra-dashboard"

# Standalone mode: just run server.js
exec node server.js
