# 晋升规则 + 衰减规则

## 晋升判定（优先级 × 复现双重条件）

| 优先级 | 复现要求 | 动作 |
|--------|---------|------|
| 🔴 Critical | 无（首次即晋升） | → AGENTS.md 铁律 或 IDENTITY.md 已知缺陷 |
| 🟡 High | ≥3 次，且跨 ≥2 个不同任务 | → AGENTS.md 铁律 或 IDENTITY.md 已知缺陷 |
| 🟢 Medium | 不晋升 | 留在 lessons.md，供 memory_search 命中 |
| ⚪ Low | 不晋升 | 留在 lessons.md，供 memory_search 命中 |

## 晋升目标选择

- **行为缺陷** → IDENTITY.md 已知缺陷（如"表演性验证"、"完成偏好"）
- **操作规则** → AGENTS.md 铁律（如"Gateway 重启门禁"、"源头验证"）
- **项目特定** → 项目 AGENTS.md 教训段（如"Next.js App Router 不支持 X"）

## 晋升操作流程

1. 在目标文件中添加规则/缺陷条目
2. 回到 lessons.md，更新原条目状态：`promoted → AGENTS.md#铁律N` 或 `promoted → IDENTITY.md#N`
3. 原条目保留不删（保持完整追溯链）

## 衰减规则

- **条件**：90 天未被 memory_search 命中 + 非 critical + 状态为 resolved
- **动作**：移入 `memory/archive/lessons-cold.md`
- **操作**：在 lessons.md 原位留引用 `→ moved to lessons-cold.md [LSN-ID]`
- **频率**：手动执行，不设 cron（当前体量不需要自动化）
- **可恢复**：从 cold 移回 warm 只需剪切粘贴

## 去重操作

```bash
# 检查是否已有相同 pattern
grep "pattern_key:.*关键词" memory/archive/lessons.md

# 命中 → 更新复现计数
# 在该条目的"复现"行追加新日期，N+1

# 未命中 → 新建条目
# 用完整格式（见 format.md）
```

## 优先级判定指南

不确定优先级时：
- 有没有影响生产环境？→ critical
- 有没有浪费用户时间超过 10 分钟？→ high
- 是不是只影响了自己的效率？→ medium
- 是不是知道就好，下次注意？→ low
