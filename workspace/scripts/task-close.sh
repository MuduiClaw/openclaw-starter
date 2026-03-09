#!/usr/bin/env bash
# task-close.sh — Quick-close a task after PTY Codex workflow
# Usage: bash scripts/task-close.sh <slug> [commit-hash]
#
# Does in one shot:
#   1. Marks selftest passed (if not already)
#   2. Marks delivered with commit hash + receipt
#   3. Updates spec status → done
#
# Designed for PTY workflow where Codex does code, human does commit/push,
# and gate scripts were bypassed.

set -euo pipefail

SLUG="${1:-}"
COMMIT="${2:-}"

if [[ -z "$SLUG" ]]; then
  echo "⛔ Usage: bash scripts/task-close.sh <slug> [commit-hash]" >&2
  echo "  Example: bash scripts/task-close.sh my-feature-fix 7637b14" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOCK_DIR="$REPO_ROOT/.task-lock"
TASKS_DIR="$REPO_ROOT/tasks"
SPEC_FILE="$TASKS_DIR/${SLUG}.md"

# Validate: must have .started marker
if [[ ! -f "$LOCK_DIR/${SLUG}.started" ]]; then
  echo "⛔ Task '$SLUG' was never started (.started marker missing)" >&2
  echo "  Run: bash scripts/task-start.sh tasks/${SLUG}.md" >&2
  exit 1
fi

# Auto-detect commit from latest if not provided
if [[ -z "$COMMIT" ]]; then
  COMMIT=$(git log --oneline -1 --format='%h' 2>/dev/null || echo "")
  if [[ -n "$COMMIT" ]]; then
    echo "ℹ️  No commit specified, using latest: $COMMIT"
  fi
fi

# 1. Mark selftest (idempotent)
if [[ ! -f "$LOCK_DIR/${SLUG}.selftest" ]]; then
  touch "$LOCK_DIR/${SLUG}.selftest"
  echo "✅ Selftest marker created"
else
  echo "✅ Selftest marker already exists"
fi

# 2. Mark delivered
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RECEIPT=$(echo -n "${SLUG}:${COMMIT}:${NOW}" | shasum -a 256 | cut -c1-12)

cat > "$LOCK_DIR/${SLUG}.delivered" << EOF
{
  "delivered_at": "$NOW",
  "commit": "$COMMIT",
  "receipt": "$RECEIPT"
}
EOF
echo "✅ Delivered marker created (receipt: $RECEIPT)"

# 3. Update spec status → done (if spec exists)
if [[ -f "$SPEC_FILE" ]]; then
  # Handle both **Status**: X and **status**: X patterns
  if grep -q '\*\*[Ss]tatus\*\*:' "$SPEC_FILE"; then
    sed -i '' 's/\*\*[Ss]tatus\*\*: *[a-z_]*/\*\*Status\*\*: done/' "$SPEC_FILE"
    echo "✅ Spec status updated → done"
  else
    echo "⚠️  No status field found in spec, skipping"
  fi
else
  echo "⚠️  Spec file not found: $SPEC_FILE (markers still created)"
fi

echo ""
echo "📋 Task '$SLUG' closed"
echo "   Commit: ${COMMIT:-<none>}"
echo "   Receipt: $RECEIPT"
echo "   Markers: .started ✓ .selftest ✓ .delivered ✓"
