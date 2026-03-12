#!/usr/bin/env bash
# verify-test-diff.sh — TDD 硬门禁：验证 commit 是否包含测试文件变更
#
# Gate 2 of TDD enforcement. Called by main session AFTER agent exits,
# BEFORE reviewing the diff.
#
# Usage:
#   bash scripts/verify-test-diff.sh [<commit>]              # Check HEAD (default) or specific commit
#   bash scripts/verify-test-diff.sh --meta <path> [<commit>] # Read task.meta.json to check required_evidence.tests
#   bash scripts/verify-test-diff.sh --skip-tdd [reason]      # Bypass with WARNING
#
# Exit 0 = PASS (test diff found or legitimately skipped)
# Exit 1 = BLOCK (no test diff, or test diff too small)
#
# [spec:tdd-enforcement-gate]

set -euo pipefail

# ─── Constants ───
MIN_TEST_BYTES=100
# Test file grep pattern (covers JS/TS/Python/Go/Rust + common directories)
TEST_GREP_PATTERN='(^|/)(__tests__|tests)/|(\.|_)(test|spec)\.[^/]+$|^test_[^/]+\.[^/]+$|_test\.[^/]+$'

# Doc-only file extensions (auto-skip)
DOC_EXTENSIONS='\.md$|\.txt$|\.rst$|\.adoc$|\.mdx$'
# Config-only file extensions (auto-skip)
CONFIG_EXTENSIONS='\.json$|\.ya?ml$|\.toml$|\.ini$|\.env$|\.config\.'
# Style-only file extensions (auto-skip)
STYLE_EXTENSIONS='\.css$|\.scss$|\.sass$|\.less$|\.styled\.'

# ─── Parse args ───
META_FILE=""
SKIP_TDD=""
SKIP_REASON=""
COMMIT="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --meta)
      META_FILE="${2:-}"
      shift 2
      ;;
    --skip-tdd)
      SKIP_TDD="1"
      shift
      if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
        SKIP_REASON="$1"
        shift
      else
        SKIP_REASON="manual"
      fi
      ;;
    -*)
      echo "⛔ Unknown flag: $1" >&2
      exit 1
      ;;
    *)
      COMMIT="$1"
      shift
      ;;
  esac
done

# ─── Skip-tdd bypass ───
if [[ -n "$SKIP_TDD" ]]; then
  if [[ "$SKIP_REASON" == "refactor" ]]; then
    # Refactor bypass: check that existing tests exist in the project
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    EXISTING_TESTS=$(find "$PROJECT_ROOT" -maxdepth 4 \
      \( -name "*.test.*" -o -name "*.spec.*" -o -name "*_test.*" -o -name "test_*.*" \) \
      -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/.venv/*" \
      2>/dev/null | head -1)
    EXISTING_TEST_DIRS=""
    for td in "tests" "__tests__" "test" "spec"; do
      [[ -d "$PROJECT_ROOT/$td" ]] && EXISTING_TEST_DIRS="$td"
    done

    if [[ -z "$EXISTING_TESTS" && -z "$EXISTING_TEST_DIRS" ]]; then
      echo "⛔ Refactor bypass rejected — no existing tests found in $PROJECT_ROOT" >&2
      echo "  Cannot skip TDD for refactor without existing test coverage." >&2
      echo "  Write tests first, then refactor." >&2
      exit 1
    fi
    echo "⚠️  TDD bypassed (refactor — existing tests found: ${EXISTING_TESTS:-$EXISTING_TEST_DIRS})"
  else
    echo "⚠️  TDD bypassed ($SKIP_REASON)"
  fi
  exit 0
fi

# ─── Read meta.json if provided ───
if [[ -n "$META_FILE" ]]; then
  if [[ ! -f "$META_FILE" ]]; then
    echo "⛔ BLOCKED — task.meta.json not found: $META_FILE" >&2
    echo "  Fail-fast per global gate architecture. Run task-start.sh first." >&2
    exit 1
  fi

  # Parse required_evidence.tests (path via env to avoid injection)
  TESTS_REQUIRED=$(_OC_META="$META_FILE" python3 -c "
import json, os, sys
try:
    with open(os.environ['_OC_META']) as f:
        meta = json.load(f)
    re = meta.get('required_evidence', {})
    print('true' if re.get('tests', True) else 'false')
except json.JSONDecodeError as e:
    print(f'ERROR:{e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR:{e}', file=sys.stderr)
    sys.exit(1)
" 2>&1) || {
    echo "⛔ BLOCKED — task.meta.json parse failed: $TESTS_REQUIRED" >&2
    exit 1
  }

  if [[ "$TESTS_REQUIRED" == "false" ]]; then
    echo "⏭️  Tests not required (task.meta.json required_evidence.tests=false)"
    exit 0
  fi
fi

# ─── Get changed files in commit ───
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT" 2>/dev/null) || {
  echo "⛔ BLOCKED — Cannot read commit: $COMMIT" >&2
  exit 1
}

if [[ -z "$CHANGED_FILES" ]]; then
  echo "⚠️  Empty commit, nothing to check"
  exit 0
fi

# ─── Check if all files are doc/config/style only ───
NON_DOC_FILES=$(echo "$CHANGED_FILES" | grep -vE "$DOC_EXTENSIONS" || true)
if [[ -z "$NON_DOC_FILES" ]]; then
  echo "⏭️  Doc-only commit, TDD skip"
  exit 0
fi

NON_CONFIG_FILES=$(echo "$NON_DOC_FILES" | grep -vE "$CONFIG_EXTENSIONS" || true)
if [[ -z "$NON_CONFIG_FILES" ]]; then
  echo "⏭️  Config-only commit, TDD skip"
  exit 0
fi

NON_STYLE_FILES=$(echo "$NON_CONFIG_FILES" | grep -vE "$STYLE_EXTENSIONS" || true)
if [[ -z "$NON_STYLE_FILES" ]]; then
  echo "⏭️  Style-only commit, TDD skip"
  exit 0
fi

# ─── Check if project has a test framework ───
# Detect by presence of test runner configs or test directories
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HAS_TEST_FRAMEWORK=false
for indicator in \
  "$PROJECT_ROOT/jest.config"* \
  "$PROJECT_ROOT/vitest.config"* \
  "$PROJECT_ROOT/pytest.ini" \
  "$PROJECT_ROOT/pyproject.toml" \
  "$PROJECT_ROOT/setup.cfg" \
  "$PROJECT_ROOT/Cargo.toml" \
  "$PROJECT_ROOT/go.mod" \
  "$PROJECT_ROOT/tests" \
  "$PROJECT_ROOT/__tests__" \
  "$PROJECT_ROOT/.mocharc"* \
  "$PROJECT_ROOT/karma.conf"*; do
  # shellcheck disable=SC2086
  if ls $indicator >/dev/null 2>&1; then
    HAS_TEST_FRAMEWORK=true
    break
  fi
done

if [[ "$HAS_TEST_FRAMEWORK" == "false" ]]; then
  echo "⚠️  No test framework detected in $PROJECT_ROOT"
  echo "  Consider initializing: jest/vitest (JS/TS), pytest (Python), go test (Go), cargo test (Rust)"
  echo "  Skipping TDD check (WARNING, not BLOCK)"
  exit 0
fi

# ─── Find test files in changed files ───
# Build grep pattern from test patterns
TEST_FILES=$(echo "$CHANGED_FILES" | grep -iE "$TEST_GREP_PATTERN" || true)

if [[ -z "$TEST_FILES" ]]; then
  echo "⛔ No test changes detected in commit $COMMIT" >&2
  echo "" >&2
  echo "  Changed files:" >&2
  echo "$CHANGED_FILES" | sed 's/^/    /' >&2
  echo "" >&2
  echo "  Expected test file patterns:" >&2
  echo "    *.test.* | *.spec.* | *_test.* | test_*.* | tests/ | __tests__/" >&2
  echo "" >&2
  echo "  Fix: Add tests for your changes, or use --skip-tdd <reason> if not applicable." >&2
  exit 1
fi

# ─── Check test diff size (>=100 bytes of actual additions) ───
TEST_DIFF_BYTES=0
for tf in $TEST_FILES; do
  # Count only added lines (^+) excluding the +++ header
  BYTES=$(git diff-tree -p "$COMMIT" -- "$tf" 2>/dev/null | grep '^+' | grep -v '^+++' | wc -c | tr -d ' ')
  TEST_DIFF_BYTES=$((TEST_DIFF_BYTES + BYTES))
done

if [[ $TEST_DIFF_BYTES -lt $MIN_TEST_BYTES ]]; then
  echo "⛔ Test diff too small (${TEST_DIFF_BYTES}B < ${MIN_TEST_BYTES}B minimum)" >&2
  echo "" >&2
  echo "  Test files found:" >&2
  echo "$TEST_FILES" | sed 's/^/    /' >&2
  echo "" >&2
  echo "  Tests must contain real assertions, not empty stubs." >&2
  echo "  Fix: Write meaningful test cases with actual assertions." >&2
  exit 1
fi

# ─── PASS ───
echo "✅ Test diff found (${TEST_DIFF_BYTES}B across $(echo "$TEST_FILES" | wc -l | tr -d ' ') file(s))"
echo "  Test files:"
echo "$TEST_FILES" | sed 's/^/    /'
exit 0
