# Self-Improving — 教训管理体系

> 基于 ClawHub `self-improving`（ivangdavila）+ `self-improving-agent`（pskoett）改写

## 触发条件

- 被用户纠正
- 操作/工具执行失败
- 完成重要任务后复盘
- 发现更好的做法
- 启动新任务时主动检索相关教训

## 快速参考

| 场景 | 动作 |
|------|------|
| 被纠正 | 记录到 `memory/archive/lessons.md`，格式见 `references/format.md` |
| 操作失败 | 同上。先归因再记录，修根因不打补丁 |
| 新增教训 | 先 `grep "pattern_key:.*关键词" memory/archive/lessons.md` 去重。命中 → 更新复现计数；未命中 → 新建 |
| 任务启动 | `memory_search("lessons + 关键词")` 检索相关教训 |
| 发现复现 ≥3 | 检查是否需要晋升（见 `references/promotion.md`） |
| 完成重要任务 | 主动自评：哪里做得好、哪里可以改进、有无新教训 |

## 教训格式（速查）

```markdown
## [LSN-YYYYMMDD-XXX] pattern_key: 关键词

- **优先级**: critical | high | medium | low
- **状态**: pending | resolved | promoted → <目标文件>
- **复现**: N 次（日期列表）
- **领域**: infra | content | product | trading | ops

### 摘要
一句话描述

### 触发场景 + 错误模式
什么情况下犯的、错在哪

### 正确做法
应该怎么做

### if-then
IF <触发条件> THEN <正确行为>
```

ID 格式：`LSN-YYYYMMDD-<3位随机字符>`（如 `LSN-20260308-A7B`），避免序号冲突。

完整格式定义和示例 → `references/format.md`

## 晋升规则（速查）

| 优先级 | 晋升条件 | 目标 |
|--------|---------|------|
| 🔴 Critical | 首次发生即晋升 | AGENTS.md 铁律 / IDENTITY.md 已知缺陷 |
| 🟡 High | 复现 ≥3 次 | AGENTS.md 铁律 / IDENTITY.md 已知缺陷 |
| 🟢 Medium/Low | 不晋升 | 留在 lessons.md 供检索 |

晋升后原条目状态改为 `promoted → <目标文件>#<编号>`

完整晋升规则 → `references/promotion.md`

## 分层存储

| 层级 | 对应文件 | 加载时机 |
|------|---------|---------|
| HOT | AGENTS.md 铁律 + IDENTITY.md 已知缺陷 | 每个 session 自动注入 |
| WARM | `memory/archive/lessons.md` | `memory_search` 按需检索 |
| COLD | `memory/archive/lessons-cold.md` | 极少访问，90天+ 未引用的非 critical 条目 |

## 衰减规则

- 90 天未被引用 + 非 critical → 移入 `lessons-cold.md`（手动，不自动）
- 移入 COLD 前在原位留一行引用：`→ moved to lessons-cold.md [LSN-ID]`
