#!/usr/bin/env bash
# spec-review.sh — Oracle (Gemini 3.1 Pro) reviews a spec before human approval
# Usage: bash scripts/spec-review.sh tasks/<slug>.md
#
# Exit 0 = Oracle PASS/PASS_WITH_NOTES, ready for 用户
# Exit 1 = Oracle ITERATE (can retry)
# Exit 2 = ESCALATE (3-round fuse tripped, must get human override)
#
# Reviews are written to tasks/<slug>.review-N.md (not appended to spec)
# After 3 rounds of ITERATE, outputs ESCALATE and blocks further Oracle runs.

set -euo pipefail

SPEC_FILE="${1:-}"

if [[ -z "$SPEC_FILE" || ! -f "$SPEC_FILE" ]]; then
  echo "Usage: bash scripts/spec-review.sh tasks/<slug>.md" >&2
  exit 1
fi

SLUG=$(basename "$SPEC_FILE" .md)
SPEC_DIR=$(dirname "$SPEC_FILE")

# Structural pre-check: required sections
missing=()
grep -q "## 目标" "$SPEC_FILE" || missing+=("目标")
grep -q "## 现状分析" "$SPEC_FILE" || missing+=("现状分析")
grep -q "## 范围" "$SPEC_FILE" || missing+=("范围")
grep -q "### 不做什么" "$SPEC_FILE" || missing+=("不做什么")
grep -q "## 场景覆盖" "$SPEC_FILE" || missing+=("场景覆盖")
grep -q "## 验收标准" "$SPEC_FILE" || missing+=("验收标准")
grep -q "## 测试计划" "$SPEC_FILE" || missing+=("测试计划")
grep -q "## 影响分析" "$SPEC_FILE" || missing+=("影响分析")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "⛔ Spec 缺少必要章节: ${missing[*]}"
  echo "  模板: tasks/SPEC-TEMPLATE.md"
  exit 1
fi

# ─── 3-round fuse ───
# Count existing review files (exclude override files)
review_count=0
for f in "$SPEC_DIR/${SLUG}.review-"*.md; do
  [[ -f "$f" ]] || continue
  [[ "$f" == *"-override.md" ]] && continue
  review_count=$(( review_count + 1 ))
done

if [[ $review_count -ge 3 ]]; then
  echo "🚨 ESCALATE — Oracle 已连续审查 $review_count 轮，未能 PASS。"
  echo ""
  echo "最近一轮反馈:"
  latest_review=$(ls -t "$SPEC_DIR/${SLUG}.review-"*.md 2>/dev/null | head -1)
  [[ -f "$latest_review" ]] && tail -30 "$latest_review"
  echo ""
  echo "需要 用户 决定:"
  echo "  ① 继续迭代: 删除 review 文件重置计数 → rm ${SPEC_DIR}/${SLUG}.review-*.md"
  echo "  ② 覆盖通过: echo 'VERDICT: HUMAN_OVERRIDE' > ${SPEC_DIR}/${SLUG}.review-override.md"
  echo "  ③ 放弃任务: 修改 spec status 为 abandoned"
  exit 2
fi

next_round=$(( review_count + 1 ))
REVIEW_FILE="$SPEC_DIR/${SLUG}.review-${next_round}.md"

ORACLE_PROMPT='你是一个务实的 spec 审查员。这份 spec 是给 AI Agent 执行的需求文档。Agent 以分钟为单位工作，不以天/周为单位。

逐项审查以下 7 个维度，每个维度给出 ✅ 或 ⚠️ 并附具体理由：

**1. 需求完整性** [关键]
spec 能否完全解决提出的问题？Agent 拿到这个 spec 后还需要问什么？如果还需要问 = 不完整。

**2. 目标对齐**
是否对准了三条战线（💰量化交易/📢内容影响力/🚀产品）中的至少一条？

**3. 场景覆盖** [关键]
正常场景、边界场景、错误场景是否都列出来了？特别检查：空输入、超长输入、并发、网络中断、权限不足、依赖服务不可用。

**4. 验收标准可测性** [关键]
每条验收标准能否直接用命令（curl/test/截图）验证？"做好了""优化了""正常工作"这种不算。

**5. 模块关系**
是否分析了和已有模块的关系？影响分析是否覆盖了依赖方？

**6. 粒度控制**
spec 是否控制在合理范围内？交付物是否超过 5 个？

**7. 时间尺度**
有没有出现"天""周""阶段"这类人类开发节奏的描述？

## 评判标准

三个关键维度（1/3/4）标注了 [关键]。

最后给出结论：
```
VERDICT: PASS | PASS_WITH_NOTES | ITERATE
```

- **PASS** = 关键维度全 ✅，其他维度无阻塞问题
- **PASS_WITH_NOTES** = 关键维度全 ✅，其他维度有 ⚠️ 但不影响执行（附建议，Agent 可在实现中注意）
- **ITERATE** = 任何关键维度有 ⚠️，或存在阻塞执行的缺陷

注意：你的角色是确保 spec 可执行，不是追求完美。小的改进建议放在 NOTES 里不阻塞。只有真正影响 Agent 能否正确执行的问题才应该 ITERATE。

对每个 ⚠️ 给出具体的修改建议，让 Agent 知道改哪里、改成什么。'

echo "🔍 Oracle reviewing spec: $SPEC_FILE (round $next_round/3)"
echo "---"

REVIEW_OUTPUT=$(bash "$(dirname "$0")/oracle.sh" \
  --prompt "$ORACLE_PROMPT" \
  --file "$SPEC_FILE" \
  --max-output 16384 \
  --timeout 120 2>&1) || {
  echo "❌ Oracle 执行失败"
  echo "$REVIEW_OUTPUT"
  exit 1
}

echo "$REVIEW_OUTPUT"
echo "---"

VERDICT=$(echo "$REVIEW_OUTPUT" | grep -i "VERDICT:" | head -1 || true)

# Write review to separate file (not appended to spec)
{
  echo "# Oracle Spec Review — Round $next_round"
  echo ""
  echo "**Date**: $(date '+%Y-%m-%d %H:%M')"
  echo "**Spec**: $SPEC_FILE"
  echo ""
  echo "$REVIEW_OUTPUT"
} > "$REVIEW_FILE"

echo ""
echo "📝 Review saved: $REVIEW_FILE"

if echo "$VERDICT" | grep -qi "PASS"; then
  echo ""
  echo "✅ Oracle PASSED — send to 用户 for approval"
  exit 0
else
  remaining=$(( 3 - next_round ))
  echo ""
  echo "⚠️  Oracle ITERATE (round $next_round/3, $remaining rounds left)"
  echo "  Fix issues above, then re-run:"
  echo "  bash scripts/spec-review.sh $SPEC_FILE"
  exit 1
fi
