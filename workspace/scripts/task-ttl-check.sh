#!/usr/bin/env bash
# task-ttl-check.sh — Scan tasks/backlog.json, mark stale/expired, report
# Usage: bash scripts/task-ttl-check.sh [--auto-expire] [--json]
# Called by: daily review cron / manual
set -euo pipefail

BACKLOG="${BACKLOG:-$(dirname "$0")/../tasks/backlog.json}"
AUTO_EXPIRE=false
JSON_OUT=false

for arg in "$@"; do
  case "$arg" in
    --auto-expire) AUTO_EXPIRE=true ;;
    --json) JSON_OUT=true ;;
  esac
done

if [[ ! -f "$BACKLOG" ]]; then
  echo "NO_BACKLOG" && exit 0
fi

TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" "+%s" 2>/dev/null || date -d "$TODAY" "+%s")

changes=0
stale_items=""
expired_items=""
active_items=""

# Process each task
count=$(jq 'length' "$BACKLOG")
for ((i=0; i<count; i++)); do
  status=$(jq -r ".[$i].status" "$BACKLOG")
  [[ "$status" == "done" || "$status" == "expired" ]] && continue

  id=$(jq -r ".[$i].id" "$BACKLOG")
  title=$(jq -r ".[$i].title" "$BACKLOG")
  ttl=$(jq -r ".[$i].ttl_days" "$BACKLOG")
  last_touched=$(jq -r ".[$i].last_touched" "$BACKLOG")
  line=$(jq -r ".[$i].line // \"\"" "$BACKLOG")

  touch_epoch=$(date -j -f "%Y-%m-%d" "$last_touched" "+%s" 2>/dev/null || date -d "$last_touched" "+%s")
  age_days=$(( (TODAY_EPOCH - touch_epoch) / 86400 ))

  if (( age_days >= ttl )); then
    if [[ "$AUTO_EXPIRE" == "true" ]]; then
      # Mark as expired in-place
      tmp=$(mktemp)
      jq ".[$i].status = \"expired\"" "$BACKLOG" > "$tmp" && mv "$tmp" "$BACKLOG"
      expired_items="${expired_items}\n  ❌ ${line} ${title} (${age_days}d, TTL=${ttl}d)"
      changes=$((changes + 1))
    else
      expired_items="${expired_items}\n  ⏰ ${line} ${title} (${age_days}d past, TTL=${ttl}d) → 待确认"
    fi
  elif (( age_days >= ttl - 1 )); then
    stale_items="${stale_items}\n  ⚠️ ${line} ${title} (明天过期)"
  else
    remaining=$((ttl - age_days))
    active_items="${active_items}\n  ✅ ${line} ${title} (剩 ${remaining}d)"
  fi
done

if [[ "$JSON_OUT" == "true" ]]; then
  jq '.' "$BACKLOG"
  exit 0
fi

echo "📋 Task Backlog Health Check ($TODAY)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -n "$expired_items" ]]; then
  echo -e "\n🔴 过期:"
  echo -e "$expired_items"
fi

if [[ -n "$stale_items" ]]; then
  echo -e "\n🟡 即将过期:"
  echo -e "$stale_items"
fi

if [[ -n "$active_items" ]]; then
  echo -e "\n🟢 活跃:"
  echo -e "$active_items"
fi

done_count=$(jq '[.[] | select(.status == "done" or .status == "expired")] | length' "$BACKLOG")
active_count=$(jq '[.[] | select(.status == "active")] | length' "$BACKLOG")
echo -e "\n总计: ${active_count} active / ${done_count} closed"

if [[ $changes -gt 0 ]]; then
  echo -e "\n⚡ 已自动过期 ${changes} 个任务"
fi
