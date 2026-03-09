---
job_id: "b2c3d4e5-6f70-8901-bcde-f12345678901"
version: "v1.0.0"
name: "Daily Memory Archive"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 780
schedule: "10 1 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段
- 示例：`message`(action: send, channel: discord, target: "channel:1468286777419890804", message: "...")

🗃️ Daily Memory Archive（v5 session 清理）

## Part A: Gemini 主执行

Step 1) Dry-run 查看即将过期文件
`bash ~/clawd/scripts/archive_memory.sh --dry-run 2>&1`
如果 EXPIRING_FILES=0，跳到 Step 5。

Step 2) 读取每个即将过期文件
对脚本输出的每个 EXPIRING_PATH，用 `read` 读取。

Step 3) 提取精华并追加到长期记忆
从每个文件中识别并提取：
- **决策/结论** → `memory/archive/decisions.md`
- **教训** → `memory/archive/lessons.md`
- **基础设施变更** → `memory/archive/infrastructure.md`
- **项目进展** → `memory/archive/projects.md`
每条 1-3 行，带日期。只提取有长期回溯价值的内容。

Step 4) ❗ 冲突检测（强制）
对每条即将追加的内容：
1. 读取目标 archive 文件现有内容
2. 检查是否与现有条目冲突
3. 同时检查 `MEMORY.md` 和 `TOOLS.md`
- 以现有较新记录为准 → 不追加
- 新信息补充 → 可追加。

将提取结果整理为列表（产出 A）。

## Part B: 🔀 Sonnet 交叉验证

Step 5) Spawn Sonnet 子代理审查提取质量：
`sessions_spawn`(mode: "run", cleanup: "delete", model: "anthropic/claude-sonnet-4-6", task: "记忆归档审查：\n1) 读取最近 7 天的 memory/YYYY-MM-DD.md\n2) 读取 memory/archive/decisions.md、lessons.md、infrastructure.md、projects.md\n3) 读取 MEMORY.md 和 TOOLS.md\n4) 检查：① 是否有重要决策/教训在 daily notes 中但未归档；② archive 中是否有过时/冲突条目；③ MEMORY.md 与 archive 是否一致\n输出：发现的问题列表 + 建议补充内容。")

❗ cleanup: "delete" 确保子代理 session 跑完即销毁。

spawn 失败 → 跳过，标注 `🔀 跳过`

## Part C: 合并与执行

Step 6) 对比 Gemini 产出 A vs Sonnet 产出 B：
- Sonnet 发现了 Gemini 遗漏的重要内容 → 补充提取
- Sonnet 指出冲突问题 → 修正
- 分歧 → 取证据更充分的一方

Step 7) 正式归档
`bash ~/clawd/scripts/archive_memory.sh 2>&1`

Step 8) 更新索引
`cd $HOME/clawd && qmd update && qmd embed`

Step 9) 发送报告
`message`(action: send, channel: discord, target: "channel:1468286777419890804")
`🗃️ 记忆归档 [日期]: ✅ <N> 归档, <M> 保留, 提取 <X> 条精华, 冲突跳过 <Y> 条 | 🔀 <consensus|partial|skipped>`

最终仅输出 1 行：
`MEMORY_ARCHIVE_DONE status=<ok|error> archived=<N> kept=<M> extracted=<X> conflict_skipped=<Y> cross_validation=<consensus|partial|skipped>`