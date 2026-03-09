---
job_id: "f1cfbe85-7732-4acc-a558-f7e4abc2084f"
version: "v1.0.0"
name: "Daily Updates Check (CLI + Skill)"
model: "google/gemini-3-flash-preview"
thinking: "medium"
timeout: 420
schedule: "10 4 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段
- ⚠️ 禁止对 OpenClaw 执行 git pull/fetch/clone

🔄 Daily Updates Check（CLI + Skill 合并版）

Step 1) CLI 工具更新
`bash $HOME/clawd/scripts/cli_update_check.sh 2>&1`

Step 2) Skill 插件更新
`bash $HOME/clawd/scripts/skill_update_check.sh 2>&1`

Step 3) 报告
- 有更新：`message`(action: send, channel: discord, target: "channel:1468286777419890804", message: "🔄 更新检查: CLI=<status> Skill=<status>")
- 全部 current：静默

最终输出 1 行：
`UPDATES_CHECK_DONE cli=<updated|current|error> skill=<updated|audit_only|current|error>`