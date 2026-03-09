#!/usr/bin/env bash
# safe-gateway-restart.sh — Gateway 重启统一入口
#
# 两种模式：
#   --request (默认): 验证 config → 写请求文件 → 退出等待人工确认
#   --execute:        收到人工确认后，实际执行重启
#
# 所有自动化路径（Guardian / Auto-Dispatch）调用 --request 模式。
# 只有 admin 通过 Discord DM 确认后，主 session 调用 --execute。
#
# Usage:
#   bash scripts/safe-gateway-restart.sh --caller guardian --reason "L1 health check failed"
#   bash scripts/safe-gateway-restart.sh --execute --caller agent --reason "approved by admin"
#
# Exit codes:
#   0 = restart completed (--execute) or request already pending (--request)
#   1 = blocked (validation failure)
#   2 = restart failed (--execute)
#   3 = request filed, waiting for human approval (--request)

set -euo pipefail

# ─── Config ───
LAUNCHD_LABEL="ai.openclaw.gateway"
GATEWAY_PORT=18789
HEALTH_URL="http://127.0.0.1:${GATEWAY_PORT}/healthz"
AUDIT_LOG="${HOME}/.openclaw/logs/gateway-audit.log"
REQUEST_FILE="${HOME}/.openclaw/state/gateway-restart-request.json"
UID_NUM=$(id -u)

# ─── Parse args ───
CALLER="unknown"
REASON="unspecified"
MODE="request"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --caller) CALLER="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --execute) MODE="execute"; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ─── Helpers ───
log_audit() {
  local ts
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  mkdir -p "$(dirname "$AUDIT_LOG")"
  echo "[$ts] caller=$CALLER reason=\"$REASON\" action=$1 detail=\"${2:-}\"" >> "$AUDIT_LOG"
}

validate_config() {
  openclaw config validate 2>&1 || {
    echo "CONFIG_INVALID"
    return 1
  }
  return 0
}

check_health() {
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
  [[ "$status" == "200" ]]
}

kill_port_zombies() {
  local pids
  pids=$(/usr/sbin/lsof -ti :"$GATEWAY_PORT" 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    echo "$pids" | xargs kill -9 2>/dev/null || true
    sleep 2
  fi
}

# ═══════════════════════════════════════
# REQUEST mode — file a restart request, don't actually restart
# ═══════════════════════════════════════
if [[ "$MODE" == "request" ]]; then
  echo "🔄 Gateway restart REQUEST: caller=$CALLER reason=\"$REASON\""

  # Check if request already pending
  if [[ -f "$REQUEST_FILE" ]]; then
    local_ts=$(python3 -c "import json; print(json.load(open('$REQUEST_FILE')).get('ts','?'))" 2>/dev/null || echo "?")
    echo "⏳ Restart request already pending (filed at $local_ts)"
    log_audit "ALREADY_PENDING" "duplicate request from $CALLER"
    exit 0
  fi

  # Validate config first
  echo "  Validating config..."
  if ! validate_config; then
    log_audit "BLOCKED" "config validation failed"
    echo "⛔ Config validation failed — request NOT filed"
    exit 1
  fi

  # Write request file
  mkdir -p "$(dirname "$REQUEST_FILE")"
  cat > "$REQUEST_FILE" <<EOF
{
  "ts": "$(date '+%Y-%m-%d %H:%M:%S')",
  "epoch": $(date +%s),
  "caller": "$CALLER",
  "reason": "$REASON"
}
EOF

  log_audit "REQUEST_FILED" "waiting for admin approval via Discord DM"
  echo "📋 Restart request filed. Waiting for admin to approve via Discord DM."
  echo "  Request: $REQUEST_FILE"
  echo "  Caller: $CALLER"
  echo "  Reason: $REASON"
  exit 3
fi

# ═══════════════════════════════════════
# EXECUTE mode — actually restart (called after human approval)
# ═══════════════════════════════════════
echo "🔄 Gateway restart EXECUTING: caller=$CALLER reason=\"$REASON\""

# Kill port zombies
echo "  Killing port zombies..."
kill_port_zombies

# Kickstart
echo "  Kickstarting service..."
launchctl kickstart -k "gui/${UID_NUM}/${LAUNCHD_LABEL}" 2>/dev/null || {
  log_audit "FAILED" "kickstart command failed"
  echo "❌ kickstart failed"
  exit 2
}

# Health check
echo "  Waiting for health check..."
sleep 8

if check_health; then
  log_audit "SUCCESS" "healthy after restart"
  echo "✅ Gateway restarted and healthy"
  # Clean up request file
  rm -f "$REQUEST_FILE"
  exit 0
fi

# Retry
sleep 5
if check_health; then
  log_audit "SUCCESS" "healthy after extended wait"
  echo "✅ Gateway restarted and healthy (slow start)"
  rm -f "$REQUEST_FILE"
  exit 0
fi

log_audit "UNHEALTHY" "not healthy 13s after restart"
echo "⚠️ Gateway restarted but health check failed"
rm -f "$REQUEST_FILE"
exit 2
