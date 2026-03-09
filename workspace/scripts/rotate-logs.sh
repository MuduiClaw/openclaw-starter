#!/usr/bin/env bash
# rotate-logs.sh — OpenClaw 日志轮转
# 清理 gateway-audit.log（最大的日志源）和其他大日志
# 策略：保留最近 1 个备份，超过 50MB 就轮转

set -euo pipefail

LOGS_DIR="${HOME}/.openclaw/logs"
MAX_SIZE_MB=50

rotate_log() {
  local file="$1"
  local name
  name=$(basename "$file")

  if [[ ! -f "$file" ]]; then
    return
  fi

  local size_bytes
  size_bytes=$(stat -f%z "$file" 2>/dev/null || echo 0)
  local size_mb=$((size_bytes / 1024 / 1024))

  if [[ $size_mb -ge $MAX_SIZE_MB ]]; then
    # 删旧备份
    rm -f "${file}.1"
    # 当前 → .1 备份
    cp "$file" "${file}.1"
    # 清空当前文件（保留 fd）
    : > "$file"
    echo "✅ ${name}: ${size_mb}MB → rotated"
  fi
}

# 清理历史残留 .bak-* 和 .old 文件
find "$LOGS_DIR" -name "*.bak-*" -o -name "*.old" | while read -r f; do
  rm -f "$f"
  echo "🗑️ deleted: $(basename "$f")"
done

# 轮转主要日志
rotate_log "${LOGS_DIR}/gateway-audit.log"
rotate_log "${LOGS_DIR}/gateway.log"
rotate_log "${LOGS_DIR}/gateway.err.log"
rotate_log "${LOGS_DIR}/guardian.log"
rotate_log "${LOGS_DIR}/infra-dashboard.log"

# 总大小
total=$(du -sh "$LOGS_DIR" 2>/dev/null | cut -f1)
echo "📊 logs 目录: ${total}"
