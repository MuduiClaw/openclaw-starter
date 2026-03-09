# AGENTS.md — The Loop

> 人定规则，AI 在规则内自主闭环。不达标不停，卡住换路径，不等人。
> 所有任务类型适用。简单任务压缩步骤，但每步的意识要在。

## Every Session
1. **按需检索，不盲读**：用 `memory_search` 按任务关键词检索记忆，不预加载 journal。
2. **Main session only**: MEMORY.md 已作为 workspace 文件自动注入，不需要额外 Read。

## The Loop

```
① 想清楚 → ② 执行 → ③ 验证门禁 → ④ 交付 → ⑤ 复盘
  ↑(思路错)    ↑(代码错)__ 不过关 ___|
```
**熔断**：同类失败 ≥3 次，强制回 ① 重新审视假设和方案。

### ① 想清楚（Plan）
- 不清楚就先确认，不猜。≥3 步先写计划。
- **搜索先行**：debug/排查/新功能前先搜（`web_search` + `memory_search` + 仓库 grep）。
- **Spec 先行**：所有任务动手前先产出 spec。小任务 5 行（目标/改什么/怎么验/不做什么/影响），≥3 步写 `tasks/<slug>.md`，走 Oracle review → 用户审批 → approved。免 spec 仅限单步小修。
- **上下文预算**：单次注入 8k~12k tokens，超大文件只读相关片段。
- **复杂变更**：先评估爆炸半径（改了什么 / 谁受影响 / 回滚方案 / 验证方式）。

### ② 执行（Execute）
- 简单任务主 session 直接做；复杂任务 spawn 子代理隔离。
- **代码**：无测试不开工，先写测试再改代码。
- **内容**：读写作 skill → 写 → 质量自测。
- **研究**：多源交叉，链接全部点检。
- **运维**：变更前后 diff + 健康检查。
- **失败不盲目重试**：先归因，调整后再试。
- **强制非交互**：长跑任务加 `-y/--yes/--non-interactive`。

### ③ 验证门禁（Verify）
- **不信任"完成了"——只信任证据。**
- 代码：测试 + lint + build + 浏览器验证。
- 内容：事实/逻辑 + 质量清单。
- 研究：双源交叉验证。运维：diff + 健康检查。
- **三证据**：`commit hash + 关键 diff + 验证输出`，缺一禁止宣称完成。

### ④ 交付（Ship）
- 代码：commit → push main。
- Push 必须验证到达（`git log origin/main..HEAD` = 0）。

### ⑤ 复盘（Learn）
- **纠正即记录** → `memory/archive/lessons.md`。
- **fix/revert 必须回写项目 AGENTS.md** → 仅限「不写进去下次还会犯」的教训。
- **操作前主动检索** → `memory_search("lessons + 关键词")`。

---

## 质量标准（DoD）

| 任务类型 | 什么算完成 |
|---------|-----------|
| 代码 | 测试通过 + lint + build + UI 正常 |
| 内容 | 事实准确 + 无 AI 腔 + eval ≥ 7/10 |
| 研究 | 多源交叉 + 链接有效 + 结论有数据 |
| 运维 | diff 清晰 + 健康检查通过 + 回滚方案就绪 |

---

## 铁律（永不跳过）

> 优先级：Safety > 铁律 > Loop。卡住 → 2 次替代路径 → 仍阻塞报告用户。

1. **没有验证证据不交付。**
2. **不信任"完成了"** — subagent/自己说完成 → 独立检查产出物。
3. **归因门禁** — "X 有问题"前用独立手段验证。修根因不打补丁。
4. **源头验证** — 配置从 config 取不从记忆取。
5. **改基建前查教训** — `memory_search("lessons + 关键词")`。
6. **文档先行** — 改代码前先改文档。
7. **验证必须有执行证据** — stdout/stderr 片段，不接受纯文字"通过了"。

---

## 纪律

- 代码只推 main，不建分支不走 PR。
- 原子提交，`git diff --cached --stat` 确认。
- 改了 N 处验 N 次。
- 关键信息写文件，不靠 session memory。
- 不输出 token/密钥。
- 没东西说就不说，不硬凑。

---

## 派发 Coding Agent

> spawn subagent / ACP coding agent 前必须完成：

1. **定位仓库**：`git rev-parse --show-toplevel` 校验。
2. **注入上下文**：读项目 `AGENTS.md`（自包含，无需读全局）。
3. **声明 DoD** + **输出契约**（`subtask_result.md`：结论/证据/风险/下一步）。
4. **跑基线检查**：`typecheck/build` 至少跑一次。
5. **描述性 label**：禁止用 agent 名字或空 label。
