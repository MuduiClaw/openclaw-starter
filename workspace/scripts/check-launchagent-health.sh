#!/bin/bash
# LaunchAgent 健康检查 — 检查所有自管 LaunchAgent 的运行状态和产出有效性
# 供 Cron Health Scanner 调用，输出 JSON 报告
set -euo pipefail

ISSUES=()
OK=()

check_running() {
  local label="$1"
  local name="$2"
  local state
  state=$(/bin/launchctl print "gui/$(id -u)/$label" 2>/dev/null | grep -m1 "state = " | awk '{print $NF}' || echo "not_found")
  if [[ "$state" == "running" ]]; then
    OK+=("{\"agent\":\"$name\",\"status\":\"running\"}")
    return 0
  else
    ISSUES+=("{\"agent\":\"$name\",\"status\":\"$state\",\"severity\":\"high\",\"detail\":\"LaunchAgent not running\"}")
    return 1
  fi
}

check_backup_freshness() {
  local repo_dir="$HOME/.openclaw"
  local max_age_hours=3
  
  if [[ ! -d "$repo_dir/.git" ]]; then
    ISSUES+=("{\"agent\":\"backup\",\"status\":\"error\",\"severity\":\"high\",\"detail\":\"backup repo .git not found\"}")
    return 1
  fi
  
  # Check last push time via reflog
  local last_commit_epoch
  last_commit_epoch=$(cd "$repo_dir" && git log -1 --format=%ct 2>/dev/null || echo 0)
  local now_epoch
  now_epoch=$(date +%s)
  local age_hours=$(( (now_epoch - last_commit_epoch) / 3600 ))
  
  if [[ "$age_hours" -gt "$max_age_hours" ]]; then
    ISSUES+=("{\"agent\":\"backup\",\"status\":\"stale\",\"severity\":\"high\",\"detail\":\"Last commit ${age_hours}h ago (threshold: ${max_age_hours}h)\"}")
    return 1
  else
    OK+=("{\"agent\":\"backup-freshness\",\"status\":\"ok\",\"detail\":\"Last commit ${age_hours}h ago\"}")
    return 0
  fi
}

check_mcp_bridge_port() {
  # MCP bridge uses SSE, root returns 404 which is expected — any HTTP response = alive
  # This is a supplemental check merged into the main mcp-bridge entry (no separate card)
  local http_code
  http_code=$(curl -s --connect-timeout 3 -o /dev/null -w "%{http_code}" http://127.0.0.1:9100/ 2>/dev/null || echo "000")
  if [[ "$http_code" == "000" ]]; then
    ISSUES+=("{\"agent\":\"mcp-bridge-port\",\"status\":\"port_down\",\"severity\":\"medium\",\"detail\":\"Port 9100 not responding (process may be running but not serving)\"}")
    return 1
  fi
  return 0
}

check_guardian_state() {
  local state_file="$HOME/.openclaw/logs/guardian_state.json"
  if [[ ! -f "$state_file" ]]; then
    ISSUES+=("{\"agent\":\"guardian\",\"status\":\"no_state\",\"severity\":\"medium\",\"detail\":\"guardian_state.json not found\"}")
    return 1
  fi
  
  local consecutive
  consecutive=$(python3 -c "import json; print(json.load(open('$state_file')).get('consecutive_failures',0))" 2>/dev/null || echo "-1")
  if [[ "$consecutive" -gt 3 ]]; then
    ISSUES+=("{\"agent\":\"guardian\",\"status\":\"stuck\",\"severity\":\"high\",\"detail\":\"consecutive_failures=$consecutive\"}")
    return 1
  fi
  OK+=("{\"agent\":\"guardian-state\",\"status\":\"ok\",\"detail\":\"consecutive_failures=$consecutive\"}")
  return 0
}

# === Run all checks ===
check_running "ai.openclaw.gateway" "gateway" || true
check_running "ai.openclaw.backup" "backup" || true
check_running "ai.openclaw.guardian" "guardian" || true
check_running "com.openclaw.mcp-bridge" "mcp-bridge" || true
check_running "com.openclaw.gateway-restart-notifier" "notifier" || true
check_running "com.xhs-crawler.chrome" "crawler-chrome" || true

check_backup_freshness || true
check_mcp_bridge_port || true
check_guardian_state || true

# === Output JSON ===
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  issues_json=$(printf '%s\n' "${ISSUES[@]}" | paste -sd',' -)
else
  issues_json=""
fi
if [[ ${#OK[@]} -gt 0 ]]; then
  ok_json=$(printf '%s\n' "${OK[@]}" | paste -sd',' -)
else
  ok_json=""
fi

cat <<EOF
{
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "issue_count": ${#ISSUES[@]},
  "ok_count": ${#OK[@]},
  "issues": [${issues_json}],
  "ok": [${ok_json}]
}
EOF

if [[ ${#ISSUES[@]} -gt 0 ]]; then
  exit 1
else
  exit 0
fi
