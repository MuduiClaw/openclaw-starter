#!/bin/bash
set -euo pipefail
# qmd wrapper — safe mode for LaunchAgent
# Resolve qmd: ~/.local/bin (bun install) → PATH → homebrew fallback
QMD_BIN="${HOME}/.local/bin/qmd"
if [[ ! -x "$QMD_BIN" ]]; then
  QMD_BIN="$(command -v qmd 2>/dev/null || echo /opt/homebrew/bin/qmd)"
fi
exec "$QMD_BIN" "$@"
