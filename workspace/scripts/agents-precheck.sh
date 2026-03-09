#!/usr/bin/env bash
# agents-precheck.sh — 单项目开工门禁
# 用法:
#   bash scripts/agents-precheck.sh infra-dashboard

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/agents-precheck.sh <project>" >&2
  exit 64
fi

PROJECT="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 "$SCRIPT_DIR/agents-drift-scan.py" --mode full --strict-peter --project "$PROJECT"

REPORT="$HOME/clawd/reports/agents-drift/latest.md"
echo "PRECHECK_OK project=$PROJECT report=$REPORT"
