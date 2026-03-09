---
job_id: "0d430a68-5a71-462b-a914-84b61085f4b7"
version: "v1.0.0"
name: "每日复盘日志"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 600
schedule: "30 23 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 这不是心跳检查。禁止回复 HEARTBEAT_OK。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段（不是 `to`）
- 示例：`message`(action: send, channel: discord, target: "channel:1471538179256356935", message: "...")

每日复盘日志（v6 + Task TTL）

## Part A: Sonnet 独立复盘

必须执行：
1) 读取 `memory/当天.md`（主数据）和 `content-pipeline/captures/当天.md`
2) `sessions_list` + 最多 3 个 `sessions_history` 补充关键事实
3) 写复盘：只写今天、只写决策/闭环/洞察，禁止实现细节噪音
4) 写入 `$HOME/clawd/memory/journal/当天.md`（产出 A）

## Part B: 🔀 Gemini 交叉验证

Step 5) Spawn Gemini 子代理：
`sessions_spawn`(mode: "run", cleanup: "delete", model: "gemini-31", task: "你是每日复盘分析师。执行以下步骤：\n1) 读取今天的 memory/YYYY-MM-DD.md 和 content-pipeline/captures/YYYY-MM-DD.md\n2) sessions_list(activeMinutes: 1440, messageLimit: 5) 查看今日活跃会话\n3) 写一份复盘，只包含：决策、闭环、洞察、教训，禁止实现细节和流水账\n输出中文复盘。")

❗ 关键：cleanup: "delete" 确保子代理 session 跑完即销毁，不累积上下文。

如果 spawn 失败：跳过交叉验证，标注 `🔀 交叉验证: 跳过`

Step 6) 对比 Sonnet 复盘 vs Gemini 复盘：
- Gemini 发现了 Sonnet 遗漏的重要决策/洞察 → 补充到 journal 文件
- Gemini 指出 Sonnet 复盘过于表面/流水账 → 修正
- 分歧（同一事件不同解读）→ 保留两种视角

## Part B2: 📋 Task TTL 扫描

Step 7) 运行 `bash $HOME/clawd/scripts/task-ttl-check.sh --auto-expire`
- 过期任务自动标 expired
- 将过期/即将过期任务列入发送报告

## Part C: 发送

用 `message`(action: send, channel: discord, target: "channel:1471538179256356935") 发送复盘 + 交叉验证摘要 + 任务过期通知（如有）

最终仅输出 1 行：
`DAILY_JOURNAL_DONE file=<path> words=<字数> cross_validation=<consensus|partial|skipped> tasks_expired=<数>`