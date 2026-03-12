#!/usr/bin/env bash
# gate-telemetry.sh — append gate trigger/block events to jsonl log
# Usage: gate-telemetry.sh <gate-id> <pass|block> [repo] [extra-field=value...]
# Example: gate-telemetry.sh hook-spec block clawd files=3
# Output: {"ts":"2026-03-12T23:01:00+08:00","gate":"hook-spec","result":"block","repo":"clawd","files":3}
set -euo pipefail

GATE_ID="${1:-}"
RESULT="${2:-}"
REPO="${3:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo 'unknown')")}"

if [[ -z "$GATE_ID" || -z "$RESULT" ]]; then
  echo "Usage: gate-telemetry.sh <gate-id> <pass|block> [repo]" >&2
  exit 1
fi

LOG_DIR="${HOME}/.openclaw/logs"
LOG_FILE="${LOG_DIR}/gate-events.jsonl"
mkdir -p "$LOG_DIR"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

printf '{"ts":"%s","gate":"%s","result":"%s","repo":"%s"}\n' "$TS" "$GATE_ID" "$RESULT" "$REPO" >> "$LOG_FILE"
