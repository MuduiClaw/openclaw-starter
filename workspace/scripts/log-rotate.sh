#!/bin/bash
# Log rotation for OpenClaw
# Rotates gateway, mcp-bridge, and dashboard logs
# Called by LaunchAgent daily

LOG_DIR="$HOME/.openclaw/logs"
MAX_SIZE=$((10 * 1024 * 1024))  # 10MB

rotate_log() {
  local log_file="$1"
  if [ -f "$log_file" ]; then
    local size
    size=$(stat -f%z "$log_file" 2>/dev/null || echo 0)
    if [ "$size" -gt "$MAX_SIZE" ]; then
      mv "$log_file" "${log_file}.$(date +%Y%m%d)"
      echo "Rotated: $log_file ($size bytes)"
      # Keep only last 7 rotated files
      ls -t "${log_file}".* 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null
    fi
  fi
}

for log in "$LOG_DIR"/*.log; do
  [ -f "$log" ] && rotate_log "$log"
done

echo "[$(date)] Log rotation complete"
