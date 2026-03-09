---
job_id: "a1b2c3d4-5e6f-7890-abcd-ef1234567890"
version: "v1.0.0"
name: "Daily Project Sync"
model: "google/gemini-3-flash-preview"
thinking: "medium"
timeout: 600
schedule: "40 3 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段（不是 `to`）
- 示例：`message`(action: send, channel: discord, target: "channel:1468286777419890804", message: "...")

执行一次：
`bash ~/clawd/skills/sync-projects/scripts/sync_projects.sh 2>&1`

完成后用 `message`(action: send, channel: discord, target: "channel:1468286777419890804") 发送：
- 成功：`🔄 项目同步 [日期]: ✅ 完成`
- 失败：`🔄 项目同步 [日期]: ❌ <错误摘要>`

限制：只允许 1 次 exec，不做源码分析。

硬约束：
- 禁止空输出。
- 禁止 NO_REPLY。
- 最终必须输出 1 行：
`PROJECT_SYNC_DONE status=<ok|error>`