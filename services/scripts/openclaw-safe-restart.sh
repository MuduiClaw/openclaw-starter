#!/bin/bash
# Safe gateway restart — works even when called from within a gateway session.
# Instead of direct launchctl bootout (which kills the caller), it uses
# a background detached process to perform the restart.
set -euo pipefail

LABEL="ai.openclaw.gateway"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [ ! -f "$PLIST" ]; then
  echo "❌ Gateway plist not found: $PLIST"
  exit 1
fi

echo "🔄 Safe gateway restart initiated..."
echo "   (detaching from process tree to survive gateway shutdown)"

# Detach a background process that:
# 1. Waits 2s for the current command to finish printing
# 2. bootout the gateway
# 3. Immediately bootstrap it back
nohup bash -c "
  sleep 2
  UID_VAL=\$(id -u)
  DOMAIN=\"gui/\${UID_VAL}\"
  launchctl bootout \"\$DOMAIN/$LABEL\" 2>/dev/null || true
  sleep 1
  launchctl bootstrap \"\$DOMAIN\" \"$PLIST\" 2>/dev/null || launchctl load -w \"$PLIST\" 2>/dev/null
  sleep 2
  if launchctl list \"$LABEL\" &>/dev/null; then
    echo \"\$(date '+%Y-%m-%d %H:%M:%S') ✅ Gateway restarted successfully\" >> \"\$HOME/.openclaw/logs/watchdog.log\"
  else
    echo \"\$(date '+%Y-%m-%d %H:%M:%S') ❌ Gateway restart failed\" >> \"\$HOME/.openclaw/logs/watchdog.log\"
  fi
" &>/dev/null &
disown

echo "✅ Restart scheduled (background process detached)"
echo "   Gateway will be back in ~5 seconds"
