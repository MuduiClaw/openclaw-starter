#!/usr/bin/env bash
# sync-prompts.sh — Export cron prompts to versioned files
# Usage: 
#   ./sync-prompts.sh              # Extract all prompts (creates/updates files)
#   ./sync-prompts.sh --diff       # Show drift between files and live prompts
#
# Requires: python3, jq
# Data source: /tmp/cron-jobs-export.json (must be populated by agent)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CRON_DIR="$SCRIPT_DIR/cron"
EXPORT_FILE="/tmp/cron-jobs-export.json"
DATE=$(date +%Y-%m-%d)

mkdir -p "$CRON_DIR"

if [[ ! -f "$EXPORT_FILE" ]]; then
    echo "❌ No export file at $EXPORT_FILE"
    echo "Agent should save cron list JSON there first."
    exit 1
fi

MODE="${1:-extract}"

if [[ "$MODE" == "--diff" ]]; then
    echo "🔍 Comparing live prompts vs files..."
    python3 -c "
import json, os, glob

with open('$EXPORT_FILE') as f:
    data = json.load(f)
jobs = data.get('jobs', data) if isinstance(data, dict) else data

prompt_dir = '$CRON_DIR'
files = {os.path.basename(f): f for f in glob.glob(os.path.join(prompt_dir, '*.prompt.md'))}

print(f'Live jobs: {len(jobs)} | Prompt files: {len(files)}')
# TODO: deep diff
print('Full diff not yet implemented. Compare manually.')
"
    exit 0
fi

echo "📝 Extracting prompts from $EXPORT_FILE → $CRON_DIR/"
python3 "$SCRIPT_DIR/extract-cron-prompts.py" "$EXPORT_FILE"
echo "✅ Done. Remember to: git add prompts/ && git commit"
