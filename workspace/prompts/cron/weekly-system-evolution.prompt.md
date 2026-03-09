---
job_id: "1601ab94-1a4e-41a5-8973-9c5f5db54787"
version: "v1.0.0"
name: "Weekly System Evolution Review"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 900
schedule: "0 15 * * 0"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

🔬 Weekly System Evolution Review（v4.1 含卫生扫描）

核心原则：没有反馈循环的系统 = 死系统。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段
- 低风险变更直接执行，高风险变更只建议

## Part 1: 情报源审计
Step 1) 读取 config/source-quality.json 和 config/x-watchlist.json
Step 2) Blogwatcher: `blogwatcher blogs` + `blogwatcher articles | head -50`
Step 3) X Watchlist: 读 output/x-feeds/ 最近 7 天
Step 4) 识别频繁出现的新源
Step 5) 低风险直接执行，高风险只建议

## Part 2: Cron 系统健康
Step 6) `cron list`（含 disabled），对每个 agentTurn job 查 runs（严格串行，最多 5 个）
Step 7) 分析空转率、超时率、价值密度
Step 8) 建议调整

## Part 3: 内容管线
Step 9) 统计本周捕获→简报→发布漆斗

## Part 4: 写作进化
Step 10) 检查 edit-log.md，发现纠正模式则更新 skill

## Part 5: 工具链 + 配置健康 + 卫生扫描
Step 11) 工具可用性: `which blogwatcher bird gog himalaya qmd`
Step 12) 配置文件审计（原 Config Health 8 维度精简版）：
- 跨文件矛盾检测（MEMORY vs TOOLS vs 实际）
- TOOLS.md 工具可用性快速验证
- 交叉引用完整性
- Daily notes >7天提醒归档
Step 12.5) 卫生扫描: `bash ~/clawd/scripts/weekly-hygiene.sh 2>&1`（只读扫描，检查 prompt drift/大文件/未使用脚本/disabled crons）。将发现纳入报告。

## Part 6: 记忆系统
Step 13) `wc -c MEMORY.md TOOLS.md AGENTS.md` + archive 大小

## Part 7: 更新 + 报告
Step 14) 更新 config/system-evolution.json 和 source-quality.json
Step 15) `message`(action: send, channel: discord, target: "channel:1468286777419890804")

格式：
🔬 周度系统进化 [W周数]

📡 情报: N 源 | 🟡 低效 X | 🟢 新增 Y
⏰ Cron: N job | 空转率 X% | 超时率 Y%
📝 内容: 捕获 N → 简报 M → 发布 K
🛠️ 工具+配置: N 可用 | ⚠️ X | 矛盾 Y
🧹 卫生扫描: prompt drift X | 大文件 Y | 未使用脚本 Z
🧠 记忆: MEMORY XKB | archive NKB

❗ 关键发现:
- <发现>

✅ 已执行:
- <变更>

最终输出 1 行：
`SYSTEM_EVOLUTION_DONE intel_changes=<N> cron_issues=<N> content_rate=<X%> tool_issues=<N> config_issues=<N> hygiene_findings=<N> memory_alerts=<N>`