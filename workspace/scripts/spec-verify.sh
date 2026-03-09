#!/usr/bin/env bash
# spec-verify.sh — Hard gate: Oracle verifies deliverables against spec acceptance criteria
# Usage: bash scripts/spec-verify.sh tasks/<slug>.md [deliverable_files...]
#
# Loop ③ 验证门禁：基于 spec 验收标准逐项验证实际交付物
# Exit 0 = PASS/PASS_WITH_NOTES
# Exit 1 = ITERATE (can retry)
# Exit 2 = ESCALATE (3-round fuse tripped, must get human override)
#
# Verification results written to tasks/<slug>.verify-N.md (not appended to spec)

set -euo pipefail

SPEC_FILE="${1:-}"
shift || true

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Usage: bash scripts/spec-verify.sh tasks/<slug>.md [files...]" >&2
  echo "  files: deliverable files for Oracle to inspect" >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SPEC_DIR=$(dirname "$SPEC_FILE")
LOCK_DIR=".task-lock"
STARTED_MARKER="$LOCK_DIR/${SLUG}.started"

# Gate: must have been started
if [[ ! -f "$STARTED_MARKER" ]]; then
  echo "⛔ VERIFY BLOCKED — task was never started through task-start.sh" >&2
  exit 1
fi

# ─── 3-round fuse ───
# Count existing verify files (exclude override files)
verify_count=0
for f in "$SPEC_DIR/${SLUG}.verify-"*.md; do
  [[ -f "$f" ]] || continue
  [[ "$f" == *"-override.md" ]] && continue
  verify_count=$(( verify_count + 1 ))
done

if [[ $verify_count -ge 3 ]]; then
  echo "🚨 ESCALATE — Oracle 验证已连续 $verify_count 轮，未能 PASS。"
  echo ""
  echo "最近一轮反馈:"
  latest_verify=$(ls -t "$SPEC_DIR/${SLUG}.verify-"*.md 2>/dev/null | head -1)
  [[ -f "$latest_verify" ]] && tail -30 "$latest_verify"
  echo ""
  echo "需要 用户 决定:"
  echo "  ① 继续修复后重试: 删除 verify 文件重置计数 → rm ${SPEC_DIR}/${SLUG}.verify-*.md"
  echo "  ② 覆盖通过: echo 'VERDICT: HUMAN_OVERRIDE' > ${SPEC_DIR}/${SLUG}.verify-override.md"
  echo "  ③ 放弃任务: 修改 spec status 为 abandoned"
  exit 2
fi

next_round=$(( verify_count + 1 ))
VERIFY_FILE="$SPEC_DIR/${SLUG}.verify-${next_round}.md"

# Build file args for Oracle
FILE_ARGS=()
for f in "$@"; do
  if [[ -f "$f" ]]; then
    FILE_ARGS+=("--file" "$f")
  else
    echo "⚠️  File not found, skipping: $f"
  fi
done

# Auto-include browser verification evidence if present
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
BROWSER_DIR="$PROJECT_ROOT/.browser-verify"
BROWSER_EVIDENCE=false
if [[ -d "$BROWSER_DIR" ]]; then
  [[ -s "$BROWSER_DIR/assertions.md" ]] && FILE_ARGS+=("--file" "$BROWSER_DIR/assertions.md") && BROWSER_EVIDENCE=true
  [[ -s "$BROWSER_DIR/screenshot.png" ]] && FILE_ARGS+=("--file" "$BROWSER_DIR/screenshot.png") && BROWSER_EVIDENCE=true
  $BROWSER_EVIDENCE && echo "  🌐 含浏览器验收证据: .browser-verify/"
fi

VERIFY_PROMPT='你是一个务实的验收审查员。这是 Loop ③ 验证阶段——你的角色是确认交付物能用，不是追求完美。

**逐项验证 spec 验收标准：** [关键]
对每条验收标准：
- ✅ **通过**：交付物中有对应实现 + 测试覆盖
- ⚠️ **部分通过**：实现存在但不完整（说明缺了什么）
- ❌ **未通过**：找不到对应实现或测试

**三类测试覆盖度检查：** [关键]
1. **冒烟测试**：核心链路能跑通吗？
2. **单元测试**：每个模块的行为对不对？
3. **回归测试**：改 A 有没有挂 B？
缺任何一类 = ⚠️，并指出缺了什么。

**场景覆盖检查：**
对照 spec 的正常/边界/错误场景，每个场景必须有对应测试。

**UI/端到端验证（如 spec 涉及 UI）：**
如果有 .browser-verify/assertions.md：
- 验收项是否覆盖本次所有 UI 改动？（遗漏关键改动 = ❌）
- 每条断言是否具体？（"页面能渲染" 不算，必须验具体元素/数据/交互）
- 有没有"改了 A 只验了 B"的情况？
- 验证方法和预期结果是否合理？

**范围蔓延检测：**
对照 spec「不做什么」段，检查交付物是否越界。

**批判建议：**
作为独立审查者，指出你发现的潜在问题——实现中有没有偷工减料、硬编码、遗漏的边界条件？

## 评判标准

两个关键检查项标注了 [关键]：验收标准逐项 + 三类测试。

最后：
```
VERIFIED: X/Y 验收标准通过
TESTS: 冒烟=✅/❌ 单元=✅/❌ 回归=✅/❌ E2E=✅/❌/N/A
VERDICT: PASS | PASS_WITH_NOTES | ITERATE
```

- **PASS** = 验收标准全 ✅ + 三类测试齐全 + 无范围蔓延
- **PASS_WITH_NOTES** = 关键项全 ✅，有小问题但不影响功能（附建议，可后续迭代修）
- **ITERATE** = 验收标准有 ❌，或关键测试缺失，或存在功能性缺陷

注意：你的角色是确认交付物满足 spec 要求，不是追求完美代码。代码风格、变量命名、可选优化放在 NOTES 里不阻塞。只有真正影响功能正确性的问题才 ITERATE。

```
GAPS:
- [具体缺什么]
NOTES:
- [不阻塞的改进建议]
ROOT_CAUSE: EXECUTION_GAP | SPEC_DEFECT | N/A
```

`EXECUTION_GAP` = 执行没做到位 → 回 ② 修实现
`SPEC_DEFECT` = spec 本身有缺陷 → 回 ① 修 spec'

echo "🔍 Oracle verifying deliverables against spec: $SPEC_FILE (round $next_round/3)"
echo "  Files: $*"
echo "---"

VERIFY_OUTPUT=$(bash "$(dirname "$0")/oracle.sh" \
  --prompt "$VERIFY_PROMPT" \
  --file "$SPEC_FILE" \
  "${FILE_ARGS[@]}" \
  --max-output 16384 \
  --timeout 120 2>&1) || {
  echo "❌ Oracle 执行失败"
  echo "$VERIFY_OUTPUT"
  exit 1
}

echo "$VERIFY_OUTPUT"
echo "---"

VERDICT=$(echo "$VERIFY_OUTPUT" | grep -i "VERDICT:" | head -1 || true)

# Write verification to separate file (not appended to spec)
{
  echo "# Oracle Spec Verification — Round $next_round"
  echo ""
  echo "**Date**: $(date '+%Y-%m-%d %H:%M')"
  echo "**Spec**: $SPEC_FILE"
  echo "**Files inspected**: $*"
  echo ""
  echo "$VERIFY_OUTPUT"
} > "$VERIFY_FILE"

echo ""
echo "📝 Verification saved: $VERIFY_FILE"

if echo "$VERDICT" | grep -qi "PASS"; then
  echo ""
  echo "✅ Verification PASSED — all acceptance criteria met"
  echo "  Next: bash scripts/task-deliver.sh $SPEC_FILE"
  exit 0
else
  remaining=$(( 3 - next_round ))
  echo ""
  echo "⚠️  Verification ITERATE (round $next_round/3, $remaining rounds left)"
  echo "  Fix issues above, then re-run:"
  echo "  bash scripts/spec-verify.sh $SPEC_FILE [files...]"
  exit 1
fi
