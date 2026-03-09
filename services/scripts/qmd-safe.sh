#!/bin/bash
set -euo pipefail
# qmd wrapper - safe mode for LaunchAgent
exec /opt/homebrew/bin/qmd "$@"
