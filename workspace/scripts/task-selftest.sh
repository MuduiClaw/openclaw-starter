#!/usr/bin/env bash
# task-selftest.sh — Hard gate: verify self-test evidence exists before entering ③ Verify
# Usage: bash scripts/task-selftest.sh tasks/<slug>.md [evidence_files...]
#
# Loop ② → ③ 过渡门禁：执行完成后必须有自测证据才能进入验证阶段
# Exit 0 = evidence found
# Exit 1 = blocked

set -euo pipefail

SPEC_FILE="${1:-}"
shift || true

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Usage: bash scripts/task-selftest.sh tasks/<slug>.md [evidence_files...]" >&2
  echo "  evidence_files: test output logs, screenshots, QA results, etc." >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SPEC_ABS=$(cd "$(dirname "$SPEC_FILE")" && pwd)/$(basename "$SPEC_FILE")
REPO_ROOT=$(cd "$(dirname "$SPEC_ABS")" && git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$SPEC_ABS")")
LOCK_DIR="$REPO_ROOT/.task-lock"
STARTED_MARKER="$LOCK_DIR/${SLUG}.started"

# Gate 1: Must have been started
if [[ ! -f "$STARTED_MARKER" ]]; then
  echo "⛔ SELFTEST BLOCKED — task was never started through task-start.sh" >&2
  exit 1
fi

# Gate 2: Evidence files must exist and be non-empty
if [[ $# -eq 0 ]]; then
  echo "⛔ SELFTEST BLOCKED — no evidence files provided"
  echo ""
  echo "  必须提供自测证据文件，例如："
  echo "  代码: test output log, lint results, build output"
  echo "  内容: article-qa.py output, fact-check results"
  echo "  研究: source verification log, cross-check results"
  echo "  运维: health check output, diff file"
  echo ""
  echo "  bash scripts/task-selftest.sh $SPEC_FILE test-output.log build.log"
  exit 1
fi

missing=()
empty=()
for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    missing+=("$f")
  elif [[ ! -s "$f" ]]; then
    empty+=("$f")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⛔ SELFTEST BLOCKED — evidence files not found: ${missing[*]}"
  exit 1
fi

if [[ ${#empty[@]} -gt 0 ]]; then
  echo "⛔ SELFTEST BLOCKED — evidence files are empty: ${empty[*]}"
  exit 1
fi

# Gate 3: Browser verification — driven by task.meta.json, NOT keyword grep
# Architecture: docs/architecture/global-gate-architecture.md §禁止关键词猜测
META_FILE="$LOCK_DIR/${SLUG}.meta.json"
browser_required=false

if [[ ! -f "$META_FILE" ]]; then
  echo "⛔ SELFTEST BLOCKED — task.meta.json 不存在，请先运行 task-start.sh" >&2
  exit 1
fi

# Read and validate required_evidence.browser from meta.json (fail-fast, no silent defaults)
# Pass path via argv to avoid shell injection with single quotes in paths
browser_required=$(python3 - "$META_FILE" <<'PYEOF'
import json, sys
meta_path = sys.argv[1]
try:
    with open(meta_path) as f:
        meta = json.load(f)
except (json.JSONDecodeError, ValueError) as e:
    print(f'⛔ SELFTEST BLOCKED — task.meta.json 格式损坏: {e}', file=sys.stderr)
    sys.exit(1)
if 'required_evidence' not in meta:
    print('⛔ SELFTEST BLOCKED — task.meta.json 缺少字段: required_evidence', file=sys.stderr)
    sys.exit(1)
if 'browser' not in meta['required_evidence']:
    print('⛔ SELFTEST BLOCKED — task.meta.json 缺少字段: required_evidence.browser', file=sys.stderr)
    sys.exit(1)
print('true' if meta['required_evidence']['browser'] else 'false')
PYEOF
) || exit 1

if [[ "$browser_required" == "true" ]]; then
  # Use project_path from meta.json if available; fall back to git root
  PROJECT_ROOT=$(python3 - "$META_FILE" <<'PYEOF' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as f:
        meta = json.load(f)
    p = meta.get('project_path', '')
    if p: print(p)
    else: sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
  ) || PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  BROWSER_DIR="$PROJECT_ROOT/.browser-verify"

  if [[ ! -d "$BROWSER_DIR" ]]; then
    echo "⛔ SELFTEST BLOCKED — 任务要求浏览器验证但缺少 .browser-verify/"
    echo ""
    echo "  task.meta.json 中 required_evidence.browser=true"
    echo "  Coding agent 必须用 chrome-devtools-mcp 逐改动验收："
    echo "  .browser-verify/assertions.md — 逐条验收表（改了什么→验了什么→结果）"
    echo "  .browser-verify/screenshot.png — 页面截图"
    echo ""
    echo "  详见: scripts/browser-evidence-spec.md"
    exit 1
  fi

  # assertions.md 必须存在且有内容
  if [[ ! -s "$BROWSER_DIR/assertions.md" ]]; then
    echo "⛔ SELFTEST BLOCKED — 缺少 .browser-verify/assertions.md"
    exit 1
  fi

  # 必须有至少 1 条具体验收项（表格行以 | 数字 | 开头）
  assertion_count=0
  assertion_count=$(grep -cE '^\| [0-9]+ \|' "$BROWSER_DIR/assertions.md" 2>/dev/null) || assertion_count=0
  if [[ "$assertion_count" -eq 0 ]]; then
    echo "⛔ SELFTEST BLOCKED — assertions.md 没有具体验收项"
    echo "  每个改动点必须有对应断言，不接受纯 'console 0 errors'"
    exit 1
  fi

  # 检查是否有失败项
  fail_count=0
  fail_count=$(grep -cE '^\|.*❌' "$BROWSER_DIR/assertions.md" 2>/dev/null) || fail_count=0
  if [[ "$fail_count" -gt 0 ]]; then
    echo "⛔ SELFTEST BLOCKED — 浏览器验收有 $fail_count 项未通过 (❌)"
    grep -E '^\|.*❌' "$BROWSER_DIR/assertions.md"
    exit 1
  fi

  # BROWSER_FAIL 硬阻断
  if grep -q "BROWSER_FAIL" "$BROWSER_DIR/assertions.md"; then
    echo "⛔ SELFTEST BLOCKED — BROWSER_FAIL"
    exit 1
  fi

  echo "  🌐 浏览器验收通过: $assertion_count 项全 ✅"
fi

# Record selftest completion
SELFTEST_MARKER="$LOCK_DIR/${SLUG}.selftest"
{
  echo "selftest=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "spec=$SPEC_FILE"
  echo "evidence=$*"
} > "$SELFTEST_MARKER"

echo "✅ Self-test evidence verified: $#  file(s)"
for f in "$@"; do
  size=$(wc -c < "$f" | tr -d ' ')
  echo "  📄 $f (${size} bytes)"
done
echo ""
echo "  Next: bash scripts/spec-verify.sh $SPEC_FILE [deliverable_files...]"
