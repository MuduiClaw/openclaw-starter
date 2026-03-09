#!/usr/bin/env bash
# task-deliver.sh — Hard gate: verify full pipeline before delivery
# Usage: bash scripts/task-deliver.sh tasks/<slug>.md
#
# Checks ALL prior gates, then generates a delivery receipt.
# The receipt hash must be included in the delivery message.
#
# Exit 0 = cleared to deliver (receipt generated)
# Exit 1 = blocked

set -euo pipefail

SPEC_FILE="${1:-}"

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "⛔ DELIVERY BLOCKED — spec file not found: ${SPEC_FILE:-<empty>}" >&2
  echo "  Usage: bash scripts/task-deliver.sh tasks/<slug>.md" >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SPEC_DIR=$(dirname "$SPEC_FILE")
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
LOCK_DIR="$REPO_ROOT/.task-lock"
STARTED_MARKER="$LOCK_DIR/${SLUG}.started"
SELFTEST_MARKER="$LOCK_DIR/${SLUG}.selftest"

echo "🔍 Delivery gate checking: $SLUG"
echo ""

blocked=0

# ─── Gate 1: Must have been started properly ───
if [[ ! -f "$STARTED_MARKER" ]]; then
  echo "❌ Gate 1 FAIL — task was never started through task-start.sh"
  blocked=1
else
  echo "✅ Gate 1 — task-start completed"
fi

# ─── Gate 1.5: Self-test evidence ───
if [[ ! -f "$SELFTEST_MARKER" ]]; then
  echo "❌ Gate 1.5 FAIL — self-test was never completed"
  echo "  Run: bash scripts/task-selftest.sh $SPEC_FILE [evidence_files...]"
  blocked=1
else
  echo "✅ Gate 1.5 — self-test evidence exists"
fi

# ─── Gate 2: Oracle spec review PASS ───
review_passed=false
for f in "$SPEC_DIR/${SLUG}.review-"*.md; do
  [[ -f "$f" ]] || continue
  if grep -qi "VERDICT:.*PASS\|VERDICT:.*HUMAN_OVERRIDE" "$f"; then
    review_passed=true
    break
  fi
done
# Fallback: check inline (backwards compat)
if ! $review_passed && grep -qi "VERDICT:.*PASS" "$SPEC_FILE" 2>/dev/null; then
  review_passed=true
fi

if $review_passed; then
  echo "✅ Gate 2 — Oracle review passed"
else
  echo "❌ Gate 2 FAIL — no Oracle review PASS found"
  blocked=1
fi

# ─── Gate 2.5: Spec verification PASS ───
verify_passed=false
for f in "$SPEC_DIR/${SLUG}.verify-"*.md; do
  [[ -f "$f" ]] || continue
  if grep -qi "VERDICT:.*PASS\|VERDICT:.*HUMAN_OVERRIDE" "$f"; then
    verify_passed=true
    break
  fi
done
# Fallback: check inline
if ! $verify_passed && grep -qi "Spec Verification" "$SPEC_FILE" 2>/dev/null; then
  if grep -A5 "Spec Verification" "$SPEC_FILE" | grep -qi "VERDICT:.*PASS"; then
    verify_passed=true
  fi
fi

if $verify_passed; then
  echo "✅ Gate 2.5 — spec verification passed"
else
  echo "❌ Gate 2.5 FAIL — spec verification not passed"
  echo "  Run: bash scripts/spec-verify.sh $SPEC_FILE [deliverable_files...]"
  blocked=1
fi

# ─── Gate 3: Status in_progress or done ───
if ! grep -qiE '\*\*Status\*\*:.*\b(in_progress|done)\b' "$SPEC_FILE"; then
  echo "❌ Gate 3 FAIL — status not in_progress/done"
  blocked=1
else
  echo "✅ Gate 3 — status is in_progress/done"
fi

echo ""

if [[ $blocked -eq 1 ]]; then
  echo "⛔ DELIVERY BLOCKED — fix failures above"
  exit 1
fi

# All gates passed — generate delivery receipt
RECEIPT_FILE="$LOCK_DIR/${SLUG}.delivered"
RECEIPT_HASH=$(echo "${SLUG}-$(date '+%Y%m%d%H%M%S')-$$" | shasum -a 256 | cut -c1-12)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

{
  echo "delivered=$TIMESTAMP"
  echo "spec=$SPEC_FILE"
  echo "receipt=$RECEIPT_HASH"
  echo "gates_passed=start,selftest,review,verify,deliver"
} > "$RECEIPT_FILE"

# Update spec status to done (only the Status: line, not other occurrences)
if grep -qi '^>.*\*\*Status\*\*:.*in_progress\|^\*\*Status\*\*:.*in_progress' "$SPEC_FILE"; then
  sed -i '' '/^>.*\*\*Status\*\*:/s/in_progress/done/I; /^\*\*Status\*\*:/s/in_progress/done/I' "$SPEC_FILE"
fi

echo "═══════════════════════════════════════"
echo "📦 DELIVERY: $SLUG"
echo "═══════════════════════════════════════"
echo ""
echo "Spec: $SPEC_FILE"
echo "Status: done"
echo "Gates: 5/5 passed"
echo "Receipt: $RECEIPT_HASH"
echo "Time: $TIMESTAMP"
echo ""
echo "---"
echo "Include this receipt hash in your delivery message to Mudui:"
echo "📦 Receipt: $RECEIPT_HASH"
echo ""
echo "Mudui can verify: cat $RECEIPT_FILE"
