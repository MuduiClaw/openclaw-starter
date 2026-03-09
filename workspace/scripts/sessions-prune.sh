#!/bin/bash
# Session pruning for OpenClaw
# Removes stale session files older than 7 days
# Called by LaunchAgent daily

SESSION_DIR="$HOME/.openclaw/agents/main/sessions"
MAX_AGE_DAYS=7

if [ ! -d "$SESSION_DIR" ]; then
  echo "[$(date)] Session directory not found: $SESSION_DIR"
  exit 0
fi

BEFORE=$(find "$SESSION_DIR" -name "*.json" -not -name "sessions.json" 2>/dev/null | wc -l)

# Remove session files older than MAX_AGE_DAYS (but never the index)
find "$SESSION_DIR" -name "*.json" -not -name "sessions.json" -mtime +"$MAX_AGE_DAYS" -delete 2>/dev/null

AFTER=$(find "$SESSION_DIR" -name "*.json" -not -name "sessions.json" 2>/dev/null | wc -l)
PRUNED=$((BEFORE - AFTER))

echo "[$(date)] Session prune complete: removed $PRUNED stale sessions (kept $AFTER)"
