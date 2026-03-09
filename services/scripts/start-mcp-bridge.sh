#!/bin/bash
set -euo pipefail

# Start mcp-bridge (called by LaunchAgent)
# __HOME__, __NODE_BIN__ will be replaced by setup.sh

export PATH="__NODE_BIN__:__HOME__/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
export HOME="__HOME__"

MCP_DIR="__HOME__/clawd/mcp-bridge"

if [ ! -d "$MCP_DIR" ]; then
  echo "[mcp-bridge] Directory not found: $MCP_DIR" >&2
  exit 1
fi

cd "$MCP_DIR"

# Require uv
if ! command -v uv &>/dev/null; then
  echo "[mcp-bridge] uv not found in PATH" >&2
  exit 1
fi

exec uv run server.py --host 0.0.0.0 --port 9100
