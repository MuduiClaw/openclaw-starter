#!/usr/bin/env bash
# Oracle CLI wrapper — routes to Gemini 3.1 Pro API
# Usage: oracle.sh --prompt "..." --file src/**/*.ts
# 不要把 OPENAI_BASE_URL 设到全局 env.vars，会影响 Codex
#
# 最佳配置:
#   oracle-gemini -p "Review for bugs and edge cases" -f "src/**/*.ts" --max-output 16384
#   oracle-gemini -p "设计评审" -f lib/api.ts -f docs/spec.md --timeout 120

set -euo pipefail

if ! command -v oracle &> /dev/null; then
  echo "❌ oracle 未安装。运行: npm i -g @steipete/oracle" >&2
  exit 1
fi

CONFIG_FILE="$HOME/.config/md2wechat/config.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
  GEMINI_KEY=$(sed -n 's/^[[:space:]]*gemini_key:[[:space:]]*"\{0,1\}\([^"[:space:]#]*\)"\{0,1\}.*$/\1/p' "$CONFIG_FILE")
else
  GEMINI_KEY=""
fi

if [[ -z "$GEMINI_KEY" ]]; then
  echo "❌ Gemini API key not found in $CONFIG_FILE" >&2
  exit 1
fi

exec env \
  GEMINI_API_KEY="$GEMINI_KEY" \
  oracle --model gemini-3.1-pro --engine api "$@"
