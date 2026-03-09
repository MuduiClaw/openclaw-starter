---
job_id: "c3d4e5f6-7081-9012-cdef-123456789012"
version: "v1.0.0"
name: "Weekly Memory Maintenance (Audit + Compound)"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 900
schedule: "10 5 * * 0"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

🧠 Weekly Memory Maintenance（Audit + Compound 合并版）

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段

## 🛡️ 护栏规则（最高优先级）
- **decisions.md 免改区**: 修改任何记忆内容前，必须先读取 `memory/archive/decisions.md` 最近 30 天条目。如果某个状态/配置与 decision 记录一致，**禁止修改**，即使看起来与代码/git 历史矛盾。人工决策 > 历史推断。
- **`<!-- protected:` 标记**: 含此标记的行禁止修改。
- **报告模式**: 发现记忆文件与现状不一致时，**不要直接修改**。将差异记录到报告中（Part C），标注"⚠️ 疑似过时"，等人工确认后再改。仅修正明确的格式错误/typo。

## Part A: 审计清理
1) 读取 `MEMORY.md`、`TOOLS.md`、最近 14 天 `memory/*.md`
2) 读取 `memory/archive/decisions.md`（近 30 天条目必读）
3) `cron list` 获取任务现状
4) 清理 daily notes 噪音（保留决策/结果/教训）
5) 归档 >7 天高价值内容到 `memory/archive/*`，删除低价值冗余
6) 核对关键工具与服务（which + health）并在报告中标注差异（不直接改 STALE 信息）
7) 审核 `memory/archive/decisions.md` 中🔄项，能更新就更新

## Part B: 周度复合（原 Weekly Compound）
8) 从本周 daily notes 提炼：新偏好、决策模式、项目状态变化、关键教训
9) 更新 `MEMORY.md`（新增有效认知，删除过时项 — 但遵守护栏规则）
10) 扫描 `tasks/backlog.json`，运行 `bash scripts/task-ttl-check.sh --auto-expire`，过期任务标 expired
11) 执行 `cd $HOME/clawd && qmd update && qmd embed`

## Part C: 报告
`message`(action: send, channel: discord, target: "channel:1468286777419890804")
审计报告 + MEMORY.md 变更摘要 + ⚠️ 疑似过时待确认项（如有）+ 任务过期通知（如有）

最终仅输出 1 行：
`WEEKLY_MEMORY_DONE stale_fixed=<数> archived=<数> cleaned=<数> memory_added=<数> memory_pruned=<数> tasks_expired=<数>`