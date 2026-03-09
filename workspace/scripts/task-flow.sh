#!/usr/bin/env bash
# task-flow.sh — Spec pipeline orchestrator
# Usage: bash scripts/task-flow.sh tasks/<slug>.md [extra_args...]
#
# Reads current spec status, executes the next gate in sequence.
# Reduces manual invocation errors — one command, always the right next step.

set -euo pipefail

SPEC_FILE="${1:-}"
shift || true

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Usage: bash scripts/task-flow.sh tasks/<slug>.md [extra_args...]" >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK_DIR=".task-lock"

# Detect current status from spec file
get_status() {
  local s
  s=$(sed -n 's/.*[Ss]tatus.*[`*]*\(draft\|reviewed\|approved\|in_progress\|done\|abandoned\)[`*]*.*/\1/p' "$SPEC_FILE" | head -1)
  echo "${s:-unknown}"
}

STATUS=$(get_status)

echo "📋 Spec: $SPEC_FILE"
echo "📍 Status: $STATUS"
echo ""

case "$STATUS" in
  draft)
    echo "→ Next: Oracle spec review"
    echo "  Running: spec-review.sh"
    echo "---"
    exit_code=0
    bash "$SCRIPTS_DIR/spec-review.sh" "$SPEC_FILE" || exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
      # PASS or PASS_WITH_NOTES
      sed -i '' -E 's/([Ss]tatus[^a-z]*)draft/\1reviewed/' "$SPEC_FILE"
      echo ""
      echo "✅ Status → reviewed. Send to 用户 for approval."
      echo "  After approval: update status to \`approved\`, then re-run task-flow.sh"
    elif [[ $exit_code -eq 2 ]]; then
      # ESCALATE — 3-round fuse
      echo ""
      echo "🚨 Oracle 3 轮未通过，已升级。等待 用户 决定。"
    else
      # ITERATE
      echo ""
      echo "⚠️  Fix issues and re-run: bash scripts/task-flow.sh $SPEC_FILE"
    fi
    ;;

  reviewed)
    echo "⏳ Waiting for 用户 approval."
    echo "  After approval: change status to \`approved\` in $SPEC_FILE"
    echo "  Then: bash scripts/task-flow.sh $SPEC_FILE"
    ;;

  approved)
    echo "→ Next: Start execution"
    echo "  Running: task-start.sh"
    echo "---"
    bash "$SCRIPTS_DIR/task-start.sh" "$SPEC_FILE"
    echo ""
    echo "🚀 Execution phase. Implement the spec, write tests, collect evidence."
    echo "  When done: bash scripts/task-flow.sh $SPEC_FILE <evidence_files...>"
    ;;

  in_progress)
    STARTED_MARKER="$LOCK_DIR/${SLUG}.started"
    SELFTEST_MARKER="$LOCK_DIR/${SLUG}.selftest"

    if [[ ! -f "$STARTED_MARKER" ]]; then
      echo "⚠️  Status is in_progress but no started marker. Running task-start.sh..."
      bash "$SCRIPTS_DIR/task-start.sh" "$SPEC_FILE"
    elif [[ ! -f "$SELFTEST_MARKER" ]]; then
      if [[ $# -eq 0 ]]; then
        echo "→ Next: Self-test gate"
        echo "  Provide evidence files as arguments:"
        echo "  bash scripts/task-flow.sh $SPEC_FILE test-output.log build.log [screenshot.png]"
        exit 1
      fi
      echo "→ Next: Self-test gate"
      echo "  Running: task-selftest.sh"
      echo "---"
      bash "$SCRIPTS_DIR/task-selftest.sh" "$SPEC_FILE" "$@"
      echo ""
      echo "→ Next: Oracle spec verification"
      echo "  bash scripts/task-flow.sh $SPEC_FILE <deliverable_files...>"
    else
      # Check if verify has been done
      SPEC_DIR=$(dirname "$SPEC_FILE")
      has_verify_pass=false
      for f in "$SPEC_DIR/${SLUG}.verify-"*.md; do
        [[ -f "$f" ]] || continue
        if grep -qi "VERDICT:.*PASS\|VERDICT:.*HUMAN_OVERRIDE" "$f"; then
          has_verify_pass=true
          break
        fi
      done
      # Fallback inline check
      if ! $has_verify_pass && grep -qi "Spec Verification" "$SPEC_FILE" 2>/dev/null; then
        if grep -A5 "Spec Verification" "$SPEC_FILE" | grep -qi "VERDICT:.*PASS"; then
          has_verify_pass=true
        fi
      fi

      if $has_verify_pass; then
        echo "→ Next: Delivery gate"
        echo "  Running: task-deliver.sh"
        echo "---"
        bash "$SCRIPTS_DIR/task-deliver.sh" "$SPEC_FILE"
      else
        if [[ $# -eq 0 ]]; then
          echo "→ Next: Oracle spec verification"
          echo "  Provide deliverable files as arguments:"
          echo "  bash scripts/task-flow.sh $SPEC_FILE src/module.ts src/module.test.ts"
          exit 1
        fi
        echo "→ Next: Oracle spec verification"
        echo "  Running: spec-verify.sh"
        echo "---"
        exit_code=0
        bash "$SCRIPTS_DIR/spec-verify.sh" "$SPEC_FILE" "$@" || exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
          echo ""
          echo "→ Next: Deliver"
          echo "  bash scripts/task-flow.sh $SPEC_FILE"
        elif [[ $exit_code -eq 2 ]]; then
          echo ""
          echo "🚨 Oracle 验证 3 轮未通过，已升级。等待 用户 决定。"
        else
          echo ""
          echo "⚠️  Fix issues and re-run: bash scripts/task-flow.sh $SPEC_FILE [files...]"
        fi
      fi
    fi
    ;;

  done)
    echo "✅ Task completed. Consider moving to tasks/archive/"
    ;;

  abandoned)
    echo "🚫 Task abandoned."
    reason=$(grep -A1 -i "abandon" "$SPEC_FILE" | tail -1 || echo "(no reason found)")
    echo "  Reason: $reason"
    ;;

  *)
    echo "❓ Unknown status: $STATUS"
    echo "  Valid: draft | reviewed | approved | in_progress | done | abandoned"
    exit 1
    ;;
esac
