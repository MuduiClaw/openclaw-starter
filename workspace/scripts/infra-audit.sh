#!/bin/bash
# infra-audit.sh — Infrastructure health audit for Dashboard /infra page
# Output format: NAME [pass|warn|fail] DESCRIPTION
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE_ROOT:-${CLAWD_ROOT:-$HOME/clawd}}"
OPENCLAW_STATE="${OPENCLAW_STATE_DIR:-$HOME/.openclaw}"

# 1. Gateway process
if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
  echo "Gateway进程 pass Gateway 运行中 ($(pgrep -f 'openclaw.*gateway' | head -1))"
else
  echo "Gateway进程 fail Gateway 未运行"
fi

# 2. Gateway HTTP
GW_PORT=$(grep -o '"port":[[:space:]]*[0-9]*' "$OPENCLAW_STATE/openclaw.json" 2>/dev/null | grep -o '[0-9]*' | head -1)
GW_PORT="${GW_PORT:-3456}"
if curl -sf "http://127.0.0.1:${GW_PORT}/health" -o /dev/null 2>/dev/null; then
  echo "Gateway响应 pass HTTP :${GW_PORT} 正常"
else
  echo "Gateway响应 fail HTTP :${GW_PORT} 无响应"
fi

# 3. Node.js version
NODE_VER=$(node --version 2>/dev/null || echo "none")
if [[ "$NODE_VER" == "none" ]]; then
  echo "Node.js fail 未安装"
elif [[ "${NODE_VER#v}" == "22"* ]] || [[ "$(printf '%s\n' "22" "${NODE_VER#v}" | sort -V | head -1)" == "22" ]]; then
  echo "Node.js pass ${NODE_VER}"
else
  echo "Node.js warn ${NODE_VER} (建议 ≥22)"
fi

# 4. Disk space
DISK_USE=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [[ "$DISK_USE" -lt 80 ]]; then
  echo "磁盘空间 pass 已用 ${DISK_USE}%"
elif [[ "$DISK_USE" -lt 90 ]]; then
  echo "磁盘空间 warn 已用 ${DISK_USE}%"
else
  echo "磁盘空间 fail 已用 ${DISK_USE}% (>90%)"
fi

# 5. Memory
if command -v vm_stat >/dev/null 2>&1; then
  FREE_PAGES=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
  FREE_MB=$(( FREE_PAGES * 4096 / 1024 / 1024 ))
  if [[ "$FREE_MB" -gt 512 ]]; then
    echo "内存 pass 空闲 ${FREE_MB}MB"
  elif [[ "$FREE_MB" -gt 128 ]]; then
    echo "内存 warn 空闲 ${FREE_MB}MB"
  else
    echo "内存 fail 空闲 ${FREE_MB}MB (<128MB)"
  fi
else
  echo "内存 pass (vm_stat 不可用)"
fi

# 6. LaunchAgents
EXPECTED_AGENTS="ai.openclaw.gateway ai.openclaw.guardian"
for agent in $EXPECTED_AGENTS; do
  if launchctl list "$agent" >/dev/null 2>&1; then
    PID=$(launchctl list "$agent" 2>/dev/null | grep '"PID"' | grep -o '[0-9]*')
    if [[ -n "$PID" ]] && [[ "$PID" != "0" ]]; then
      echo "LaunchAgent:${agent} pass 运行中 (pid=${PID})"
    else
      echo "LaunchAgent:${agent} warn 已加载但未运行"
    fi
  else
    echo "LaunchAgent:${agent} fail 未加载"
  fi
done

# 7. OpenClaw version
if command -v openclaw >/dev/null 2>&1; then
  OC_VER=$(openclaw --version 2>/dev/null | head -1)
  echo "OpenClaw版本 pass ${OC_VER}"
else
  echo "OpenClaw版本 fail 未安装"
fi

# 8. Workspace exists
if [[ -d "$WORKSPACE" ]]; then
  FILE_COUNT=$(find "$WORKSPACE" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
  echo "Workspace pass ${WORKSPACE} (${FILE_COUNT} md files)"
else
  echo "Workspace fail ${WORKSPACE} 不存在"
fi

# 9. Git backup health
if [[ -d "$WORKSPACE/.git" ]]; then
  LAST_COMMIT=$(cd "$WORKSPACE" && git log -1 --format="%ar" 2>/dev/null || echo "unknown")
  echo "Git备份 pass 最后提交: ${LAST_COMMIT}"
else
  echo "Git备份 warn ${WORKSPACE} 非 Git 仓库"
fi

# 10. Log directory size
if [[ -d "$OPENCLAW_STATE/logs" ]]; then
  LOG_SIZE=$(du -sh "$OPENCLAW_STATE/logs" 2>/dev/null | awk '{print $1}')
  echo "日志大小 pass ${LOG_SIZE}"
else
  echo "日志大小 pass 无日志目录"
fi

# 11. MCP bridge
if lsof -i :9100 >/dev/null 2>&1; then
  echo "MCP-Bridge pass :9100 运行中"
else
  echo "MCP-Bridge warn :9100 未运行"
fi

# 12. Dashboard
if curl -sf "http://127.0.0.1:3001/" -o /dev/null 2>/dev/null; then
  echo "Dashboard pass :3001 正常"
else
  echo "Dashboard warn :3001 未响应"
fi

# 13. Tailscale
if command -v tailscale >/dev/null 2>&1; then
  TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
  if [[ -n "$TS_IP" ]]; then
    echo "Tailscale pass ${TS_IP}"
  else
    echo "Tailscale warn 未登录"
  fi
else
  echo "Tailscale pass 未安装 (可选)"
fi

# 14. Security: log file permissions
AUDIT_LOG="$OPENCLAW_STATE/logs/gateway-audit.log"
if [[ -f "$AUDIT_LOG" ]]; then
  PERMS=$(stat -f "%Lp" "$AUDIT_LOG" 2>/dev/null || stat -c "%a" "$AUDIT_LOG" 2>/dev/null || echo "unknown")
  if [[ "$PERMS" == "600" ]]; then
    echo "日志权限 pass ${AUDIT_LOG} (${PERMS})"
  else
    echo "日志权限 warn ${AUDIT_LOG} 权限 ${PERMS} (建议 600)"
  fi
else
  echo "日志权限 pass 审计日志未创建"
fi
