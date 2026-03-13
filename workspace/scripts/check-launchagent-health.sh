#!/bin/bash
# check-launchagent-health.sh — ClawKing LaunchAgent health check
# Returns JSON for infra-dashboard consumption

AGENTS=(
  "ai.openclaw.gateway"
  "ai.openclaw.caffeinate"
  "ai.openclaw.backup"
  "ai.openclaw.log-rotate"
  "ai.openclaw.sessions-prune-cron"
  "com.openclaw.infra-dashboard"
  "com.openclaw.mcp-bridge"
)

ok_items="[]"
issue_items="[]"
ok_count=0
issue_count=0

for agent in "${AGENTS[@]}"; do
  short="${agent##*.}"
  line=$(launchctl list 2>/dev/null | grep "$agent")
  if [ -n "$line" ]; then
    pid=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $2}')
    if [ "$pid" = "-" ] && [ "$status" = "0" ]; then
      # Scheduled job, not running = OK
      ok_items=$(echo "$ok_items" | python3 -c "import sys,json; l=json.load(sys.stdin); l.append({'agent':'$short','status':'ok','detail':'scheduled (idle)'}); print(json.dumps(l))")
      ok_count=$((ok_count + 1))
    elif [ "$status" = "0" ] || [ "$status" = "-15" ]; then
      ok_items=$(echo "$ok_items" | python3 -c "import sys,json; l=json.load(sys.stdin); l.append({'agent':'$short','status':'ok','detail':'running (pid $pid)'}); print(json.dumps(l))")
      ok_count=$((ok_count + 1))
    else
      issue_items=$(echo "$issue_items" | python3 -c "import sys,json; l=json.load(sys.stdin); l.append({'agent':'$short','status':'error','severity':'high','detail':'exit code $status'}); print(json.dumps(l))")
      issue_count=$((issue_count + 1))
    fi
  else
    # Not loaded — check if plist exists
    plist="$HOME/Library/LaunchAgents/${agent}.plist"
    if [ -f "$plist" ]; then
      issue_items=$(echo "$issue_items" | python3 -c "import sys,json; l=json.load(sys.stdin); l.append({'agent':'$short','status':'error','severity':'medium','detail':'plist exists but not loaded'}); print(json.dumps(l))")
      issue_count=$((issue_count + 1))
    else
      issue_items=$(echo "$issue_items" | python3 -c "import sys,json; l=json.load(sys.stdin); l.append({'agent':'$short','status':'warning','severity':'low','detail':'not installed'}); print(json.dumps(l))")
      issue_count=$((issue_count + 1))
    fi
  fi
done

python3 -c "
import json
print(json.dumps({
  'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
  'issue_count': $issue_count,
  'ok_count': $ok_count,
  'issues': $issue_items,
  'ok': $ok_items
}))
"
