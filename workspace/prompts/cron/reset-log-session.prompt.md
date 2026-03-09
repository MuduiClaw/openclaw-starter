---
job_id: "b815bcfd-ffd5-408c-a098-179f3ecee2e5"
version: "v1.0.0"
name: "Reset Log Channel Session"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 120
schedule: "10 3 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段（不是 `to`）
- 示例：`message`(action: send, channel: discord, target: "channel:1468286777419890804", message: "...")

执行日志频道 session 重置：
`python3 $HOME/clawd/scripts/reset-log-session.py 2>&1`

用 `message`(action: send, channel: discord, target: "channel:1468286777419890804") 发送：
- 成功：`♻️ 日志会话重置: ✅ <摘要>`
- 失败：`♻️ 日志会话重置: ❌ <错误>`

硬约束：
- 禁止空输出。
- 禁止 NO_REPLY。
- 最终必须输出 1 行：
`RESET_LOG_SESSION_DONE status=<ok|error>`