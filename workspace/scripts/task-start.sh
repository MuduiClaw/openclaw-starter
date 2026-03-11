#!/usr/bin/env bash
# task-start.sh — Hard gate: verify spec is approved before starting execution
# Usage: bash scripts/task-start.sh tasks/<slug>.md
#
# Checks:
# 1. Oracle review PASS/PASS_WITH_NOTES in review files, or HUMAN_OVERRIDE
# 2. Status is "approved"
# Creates .task-lock/<slug>.started marker + <slug>.meta.json on success
#
# meta.json fields parsed from spec header:
#   Type → task_type | Surface → surface[] | Risk → risk | Project → project_path
#
# Exit 0 = cleared to start
# Exit 1 = blocked

set -euo pipefail

SPEC_FILE="${1:-}"

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "⛔ TASK START BLOCKED — spec file not found: ${SPEC_FILE:-<empty>}" >&2
  echo "  Usage: bash scripts/task-start.sh tasks/<slug>.md" >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SPEC_DIR=$(dirname "$SPEC_FILE")
# Derive repo root from the SPEC FILE location, not cwd — prevents lock files
# ending up in the wrong project when running from a different directory.
SPEC_ABS=$(cd "$(dirname "$SPEC_FILE")" && pwd)/$(basename "$SPEC_FILE")
REPO_ROOT=$(cd "$(dirname "$SPEC_ABS")" && git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$SPEC_ABS")")
LOCK_DIR="$REPO_ROOT/.task-lock"
STARTED_MARKER="$LOCK_DIR/${SLUG}.started"

# ─── Gate 1: Oracle review must PASS, PASS_WITH_NOTES, or have HUMAN_OVERRIDE ───
oracle_passed=false

# Check separate review files (new format)
for f in "$SPEC_DIR/${SLUG}.review-"*.md; do
  [[ -f "$f" ]] || continue
  if grep -qi "VERDICT:.*PASS\|VERDICT:.*HUMAN_OVERRIDE" "$f"; then
    oracle_passed=true
    break
  fi
done

# Fallback: check spec inline (backwards compatibility with old format)
if ! $oracle_passed; then
  if grep -qi "VERDICT:.*PASS" "$SPEC_FILE"; then
    oracle_passed=true
  fi
fi

if ! $oracle_passed; then
  echo "⛔ TASK START BLOCKED — no Oracle PASS/PASS_WITH_NOTES/HUMAN_OVERRIDE found"
  echo "  Run: bash scripts/spec-review.sh $SPEC_FILE"
  echo "  Or override: echo 'VERDICT: HUMAN_OVERRIDE' > ${SPEC_DIR}/${SLUG}.review-override.md"
  exit 1
fi

# ─── Gate 2: Status must be approved (exact word boundary, not "unapproved") ───
if ! grep -qiE '\*\*Status\*\*:.*\bapproved\b' "$SPEC_FILE"; then
  echo "⛔ TASK START BLOCKED — status not approved in $SPEC_FILE"
  echo "  Send to Mudui first. After approval, update status to approved."
  exit 1
fi

# ─── Gate 3: Type field must exist in spec header ───
spec_type=$(grep -i '^\*\*Type\*\*:\|^>.*\*\*Type\*\*:' "$SPEC_FILE" | head -1 | sed 's/.*\*\*Type\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' || true)
if [[ -z "$spec_type" ]]; then
  echo "⛔ TASK START BLOCKED — spec header 缺少 Type 字段" >&2
  echo "  在 spec 头部加: > **Type**: code|docs|content|research|ops" >&2
  exit 1
fi

# All gates passed — generate meta.json FIRST, then create .started marker LAST
# (other gates check .started as readiness signal; meta.json must exist before that)
mkdir -p "$LOCK_DIR"

# ─── Generate task.meta.json ───
META_FILE="$LOCK_DIR/${SLUG}.meta.json"

# Parse spec header fields
spec_surface=$(grep -i '^\*\*Surface\*\*:\|^>.*\*\*Surface\*\*:' "$SPEC_FILE" | head -1 | sed 's/.*\*\*Surface\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' || true)
spec_risk=$(grep -i '^\*\*Risk\*\*:\|^>.*\*\*Risk\*\*:' "$SPEC_FILE" | head -1 | sed 's/.*\*\*Risk\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]' || true)
spec_project=$(grep -i '^\*\*Project\*\*:\|^>.*\*\*Project\*\*:' "$SPEC_FILE" | head -1 | sed 's/.*\*\*Project\*\*:[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)

# Default surface from type if not specified
if [[ -z "$spec_surface" ]]; then
  case "$spec_type" in
    code) spec_surface="cli" ;;
    docs|content|research) spec_surface="docs" ;;
    ops) spec_surface="ops" ;;
    *) spec_surface="cli" ;;
  esac
fi

# Default risk
[[ -z "$spec_risk" ]] && spec_risk="feature"

# Default project
[[ -z "$spec_project" ]] && spec_project="$REPO_ROOT"

# Generate meta.json via python for proper JSON
python3 - "$SLUG" "$SPEC_FILE" "$spec_type" "$spec_surface" "$spec_risk" "$spec_project" "$META_FILE" <<'PYEOF'
import json, sys
from datetime import datetime, timezone, timedelta

slug, spec, task_type, surface_raw, risk, project_path, out_path = sys.argv[1:8]

# Parse surface: "ui, api" → ["ui", "api"]
surfaces = [s.strip() for s in surface_raw.split(",") if s.strip()]

# Determine required_evidence based on architecture rules
evidence = {
    "tests": task_type == "code",
    "build": any(s in ("ui", "api", "lib") for s in surfaces),
    "browser": "ui" in surfaces,
    "diff": task_type in ("code", "ops"),
    "logs": task_type == "ops",
    "document": task_type in ("docs", "content", "research"),
}

meta = {
    "slug": slug,
    "spec": spec,
    "task_type": task_type,
    "surface": surfaces,
    "risk": risk,
    "project_path": project_path,
    "required_evidence": evidence,
    "created": datetime.now(timezone(timedelta(hours=8))).isoformat(),
}

with open(out_path, "w") as f:
    json.dump(meta, f, indent=2, ensure_ascii=False)

print(f"  Meta: {out_path}")
print(f"  task_type={task_type} surface={surfaces} risk={risk}")
print(f"  browser_required={evidence['browser']}")
PYEOF

# Write .started marker LAST — signals to downstream gates that meta.json is ready
{
  echo "started=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "spec=$SPEC_FILE"
} > "$STARTED_MARKER"

echo "✅ Task started: $SLUG"
echo "  Spec: $SPEC_FILE"
echo "  Marker: $STARTED_MARKER"

# Update spec status to in_progress (only the Status: line, not other occurrences)
if grep -qi '^>.*\*\*Status\*\*:.*approved\|^\*\*Status\*\*:.*approved' "$SPEC_FILE"; then
  sed -i '' '/^>.*\*\*Status\*\*:/s/approved/in_progress/I; /^\*\*Status\*\*:/s/approved/in_progress/I' "$SPEC_FILE"
  echo "  Status → in_progress"
fi
