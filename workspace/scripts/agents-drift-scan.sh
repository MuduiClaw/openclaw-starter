#!/usr/bin/env bash
# agents-drift-scan.sh — 扫描 6 个项目 AGENTS.md 漂移 + 执行可行性审计
# 用法:
#   bash scripts/agents-drift-scan.sh               # 默认 full + strict-peter（含基线命令执行）
#   bash scripts/agents-drift-scan.sh --mode runtime
#   bash scripts/agents-drift-scan.sh --mode structural
#   bash scripts/agents-drift-scan.sh --no-strict-peter   # 仅兼容旧报告

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/agents-drift-scan.py" "$@"
