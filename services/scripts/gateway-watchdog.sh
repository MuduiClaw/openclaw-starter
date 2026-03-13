#!/bin/bash
# Gateway Watchdog — auto-recover if ai.openclaw.gateway gets unloaded
# Runs every 30s via LaunchAgent ai.openclaw.watchdog
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
LABEL="ai.openclaw.gateway"
LOG_PREFIX="[watchdog]"

# Check if gateway plist exists
if [ ! -f "$PLIST" ]; then
  exit 0
fi

# Check if gateway is loaded in launchd
if launchctl list "$LABEL" &>/dev/null; then
  exit 0
fi

# Gateway is NOT loaded — this means bootout/unload happened
echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') Gateway unloaded! Re-bootstrapping..."

UID_VAL=$(id -u)
DOMAIN="gui/${UID_VAL}"

# Re-bootstrap the gateway
if launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
  echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') Gateway re-bootstrapped successfully"
else
  # Fallback: try load (older macOS)
  launchctl load -w "$PLIST" 2>/dev/null || true
  echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') Gateway loaded via fallback"
fi

# Wait a moment and verify
sleep 3
if launchctl list "$LABEL" &>/dev/null; then
  echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') ✅ Gateway recovered"
else
  echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') ❌ Gateway recovery failed"
fi
