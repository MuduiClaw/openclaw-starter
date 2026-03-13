#!/usr/bin/env bash
set -euo pipefail

OUTPUT_MODE="text"
if [[ "${1:-}" == "--json" ]]; then
  OUTPUT_MODE="json"
fi

DISK_PATH="$HOME"
if [[ ! -d "$DISK_PATH" ]]; then
  DISK_PATH="$HOME"
fi

now_local=$(TZ=Asia/Shanghai date +"%Y-%m-%d %H:%M:%S %Z")
now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
host=$(hostname)

# Dynamic port: read from config, fallback 3456
GATEWAY_PORT=$(python3 -c "import json; print(json.load(open('$HOME/.openclaw/openclaw.json')).get('gateway',{}).get('port',3456))" 2>/dev/null || echo 3456)

health_code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${GATEWAY_PORT}/health" || echo "down")

disk_used_raw=$(df -h "$DISK_PATH" 2>/dev/null | awk 'NR==2{print $5}')
disk_used_pct=${disk_used_raw%%%}
if [[ -z "${disk_used_pct:-}" ]]; then
  disk_used_pct=0
fi

status_raw=$(openclaw status 2>&1 || true)
if grep -Eq "Gateway service.+running" <<<"$status_raw"; then
  gateway_service="running"
else
  gateway_service="unknown"
fi

cron_raw=$(openclaw cron list --all --json 2>&1 || true)
cron_json=$(awk 'BEGIN{p=0} /^\{/ {p=1} p{print}' <<<"$cron_raw")

cron_parse_ok=true
if [[ -z "$cron_json" ]] || ! jq empty >/dev/null 2>&1 <<<"$cron_json"; then
  cron_parse_ok=false
  cron_json='{"jobs":[]}'
fi

total_jobs=$(jq '.jobs | length' <<<"$cron_json")
enabled_jobs=$(jq '[.jobs[] | select(.enabled == true)] | length' <<<"$cron_json")
error_jobs_json=$(jq -c '[.jobs[]
  | select((.state.lastStatus // "unknown") != "ok" or ((.state.consecutiveErrors // 0) > 0))
  | {
      id,
      name,
      lastStatus: (.state.lastStatus // "unknown"),
      consecutiveErrors: (.state.consecutiveErrors // 0),
      lastError: (.state.lastError // "")
    }
]' <<<"$cron_json")
error_count=$(jq 'length' <<<"$error_jobs_json")

slow_jobs_json=$(jq -c '[.jobs[]
  | select(
      (.payload.timeoutSeconds // 0) > 0
      and (.state.lastDurationMs // 0) > ((.payload.timeoutSeconds // 0) * 1000 * 0.8)
      and (.state.lastStatus // "unknown") == "ok"
    )
  | {
      id,
      name,
      durationMs: (.state.lastDurationMs // 0),
      timeoutSeconds: (.payload.timeoutSeconds // 0)
    }
]' <<<"$cron_json")
slow_count=$(jq 'length' <<<"$slow_jobs_json")

cooldown_jobs_json=$(jq -c '[.jobs[]
  | select(((.state.lastError // "") | test("cooldown"; "i")))
  | {
      id,
      name,
      lastError: (.state.lastError // "")
    }
]' <<<"$cron_json")
cooldown_count=$(jq 'length' <<<"$cooldown_jobs_json")

delivery_failed=0
if [[ -d "$HOME/.openclaw/delivery-queue/failed" ]]; then
  delivery_failed=$(find "$HOME/.openclaw/delivery-queue/failed" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

# Coding agent tmux sessions check (absorbed from watchdog.sh)
agent_sessions_total=0
agent_sessions_stale=0
if command -v tmux >/dev/null 2>&1; then
  while IFS=' ' read -r sname sact; do
    [[ -z "$sname" ]] && continue
    agent_sessions_total=$((agent_sessions_total+1))
    age=$(( $(date +%s) - sact ))
    if (( age > 3600 )); then
      agent_sessions_stale=$((agent_sessions_stale+1))
    fi
  done < <(tmux list-sessions -F '#{session_name} #{session_activity}' 2>/dev/null | grep -E '^(codex|claude)-' || true)
fi

issues=()
[[ "$health_code" != "200" ]] && issues+=("gateway_health=$health_code")
[[ "$gateway_service" != "running" ]] && issues+=("gateway_service=$gateway_service")
[[ "$cron_parse_ok" != "true" ]] && issues+=("cron_parse_failed")
(( error_count > 0 )) && issues+=("cron_errors=$error_count")
(( slow_count > 0 )) && issues+=("slow_jobs=$slow_count")
(( cooldown_count > 0 )) && issues+=("provider_cooldown_jobs=$cooldown_count")
(( delivery_failed > 0 )) && issues+=("delivery_failed=$delivery_failed")
(( disk_used_pct >= 90 )) && issues+=("disk=${disk_used_pct}%")
(( agent_sessions_stale > 0 )) && issues+=("stale_agents=$agent_sessions_stale")

status="ok"
if [[ "$health_code" != "200" || "$cron_parse_ok" != "true" || "$gateway_service" != "running" ]]; then
  status="critical"
elif (( error_count > 0 || delivery_failed > 0 || disk_used_pct >= 85 || slow_count > 0 || cooldown_count > 0 || agent_sessions_stale > 0 )); then
  status="warn"
fi

issues_json=$(printf '%s\n' "${issues[@]:-}" | jq -Rsc 'split("\n") | map(select(length > 0))')

result_json=$(jq -n \
  --arg nowLocal "$now_local" \
  --arg nowIso "$now_iso" \
  --arg host "$host" \
  --arg status "$status" \
  --arg healthCode "$health_code" \
  --arg gatewayService "$gateway_service" \
  --arg diskPath "$DISK_PATH" \
  --argjson diskUsedPct "$disk_used_pct" \
  --argjson cronParseOk "$cron_parse_ok" \
  --argjson totalJobs "$total_jobs" \
  --argjson enabledJobs "$enabled_jobs" \
  --argjson errorCount "$error_count" \
  --argjson slowCount "$slow_count" \
  --argjson cooldownCount "$cooldown_count" \
  --argjson deliveryFailed "$delivery_failed" \
  --argjson issues "$issues_json" \
  --argjson errorJobs "$error_jobs_json" \
  --argjson slowJobs "$slow_jobs_json" \
  --argjson cooldownJobs "$cooldown_jobs_json" \
  --argjson agentSessionsTotal "$agent_sessions_total" \
  --argjson agentSessionsStale "$agent_sessions_stale" \
  '{
    nowLocal: $nowLocal,
    nowIso: $nowIso,
    host: $host,
    status: $status,
    gateway: {
      healthCode: $healthCode,
      service: $gatewayService
    },
    disk: {
      path: $diskPath,
      usedPct: $diskUsedPct
    },
    cron: {
      parseOk: $cronParseOk,
      totalJobs: $totalJobs,
      enabledJobs: $enabledJobs,
      errorCount: $errorCount,
      slowCount: $slowCount,
      cooldownCount: $cooldownCount,
      errorJobs: $errorJobs,
      slowJobs: $slowJobs,
      cooldownJobs: $cooldownJobs
    },
    deliveryQueue: {
      failedCount: $deliveryFailed
    },
    agents: {
      total: $agentSessionsTotal,
      stale: $agentSessionsStale
    },
    issues: $issues
  }')

if [[ "$OUTPUT_MODE" == "json" ]]; then
  echo "$result_json"
else
  summary="FLEET status=$status gateway=${health_code}/${gateway_service} cron_errors=$error_count slow=$slow_count cooldown=$cooldown_count disk=${disk_used_pct}% delivery_failed=$delivery_failed agents=${agent_sessions_total}/${agent_sessions_stale}stale"
  echo "$summary"
  if (( ${#issues[@]} > 0 )); then
    printf 'ISSUES: %s\n' "${issues[*]}"
  fi
fi
