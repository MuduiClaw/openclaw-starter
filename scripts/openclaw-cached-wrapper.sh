#!/bin/bash
REAL="/Users/apollos/.npm-global/bin/openclaw"
CACHE="/tmp/openclaw-status-cache.json"
MAX_AGE=30

# 只拦截 "status --json" 调用
if [ "$1" = "status" ] && [ "$2" = "--json" ]; then
  if [ -f "$CACHE" ]; then
    age=$(($(date +%s) - $(stat -f%m "$CACHE" 2>/dev/null || echo 0)))
    if [ "$age" -lt "$MAX_AGE" ]; then
      cat "$CACHE"
      exit 0
    fi
  fi
  # 缓存过期，重新获取
  "$REAL" status --json 2>/dev/null > "${CACHE}.tmp" && mv "${CACHE}.tmp" "$CACHE" && cat "$CACHE"
  exit $?
fi

# 其他命令直接透传
exec "$REAL" "$@"
