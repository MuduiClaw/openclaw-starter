#!/bin/bash
# fix-sqlite3-arch.sh
# 修复 better-sqlite3 原生二进制架构不匹配问题
# 场景：Dashboard 在 arm64 机器 build，部署到 x86_64 Mac mini
# 症状：/api/usage/history, /api/usage/sample, /api/usage/cli-history 返回 500
#       dlopen(...better_sqlite3.node) incompatible architecture (have arm64, need x86_64h)

set -euo pipefail

DASHBOARD_DIR="${1:-/Users/apollos/projects/infra-dashboard}"

echo "检查当前架构..."
ARCH=$(uname -m)
SQLITE_NODE="$DASHBOARD_DIR/node_modules/better-sqlite3/build/Release/better_sqlite3.node"

if [ ! -f "$SQLITE_NODE" ]; then
  echo "❌ better_sqlite3.node 不存在: $SQLITE_NODE"
  exit 1
fi

CURRENT=$(file "$SQLITE_NODE" | grep -o 'arm64\|x86_64' | head -1)
echo "系统架构: $ARCH | better-sqlite3 架构: $CURRENT"

if [ "$CURRENT" = "$ARCH" ]; then
  echo "✅ 架构匹配，无需修复"
  exit 0
fi

echo "⚠️ 架构不匹配，重新编译..."
cd "$DASHBOARD_DIR/node_modules/better-sqlite3"
npm run build-release

NEW_ARCH=$(file "$SQLITE_NODE" | grep -o 'arm64\|x86_64' | head -1)
echo "✅ 编译完成: $NEW_ARCH"

echo "重启 Dashboard..."
launchctl bootout "gui/$(id -u)/com.openclaw.infra-dashboard" 2>/dev/null || true
sleep 2
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.openclaw.infra-dashboard.plist 2>/dev/null || true
echo "✅ Done"
