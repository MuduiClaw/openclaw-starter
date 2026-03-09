---
job_id: "1de5d8b5-fdc0-4005-96d2-8ae4a5ed7797"
version: "v1.0.0"
name: "每日晨报 (Morning Briefing + Health)"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 420
schedule: "10 8 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

☀️ 每日晨报（v2 含督工健康检查）

目标：一条消息让用户看到系统全貌 + 今日待办。吸收原督工的健康检查职能。

强约束：
- 所有 `message(action=send)` 必须使用 `target` 字段
- 最终发送到 `channel:1468286777419890804`

Step 1) 系统健康检查（原督工职能）
- `exec`: `bash $HOME/clawd/scripts/check-fleet.sh --json 2>&1`
- 解析 JSON：status / gateway.healthCode / disk.usedPct / cron.errorCount / cron.cooldownCount / cron.errorJobs[] / deliveryQueue.failedCount / issues[]

Step 2) Cron 运行情况补充
- `cron` list（includeDisabled: false）
- 对每个 job 检查 `state`：lastStatus、consecutiveErrors、lastDurationMs
- 与 check-fleet.sh 数据交叉验证，补充脚本可能遗漏的细节
- 分类统计：✅ 成功 / ⚠️ 失败 / ⏱️ 超时 / 🔄 耗时异常（>timeout*0.8）

Step 3) 关键产出扫描
- 检查 `output/blog-translations/` 今天/昨天新增文件：`exec`: `find $HOME/clawd/output/blog-translations/ -name '*.md' -mtime -1 | wc -l`
- 检查竞品/X 情报：搜索 Discord 最近 24h 的哨塔和 X 动态帖
  `message`(action: search, channel: discord, channelId: "1468286777419890804", query: "竞品哨塔 OR X 竞品动态 OR 情报", limit: 5)

Step 4) 待办检查
- 读取 `memory/YYYY-MM-DD.md`（今天，如果存在）和昨天的
- 识别未闭环的承诺/待办（标记为「进行中」「待确认」「blocked」的条目）
- 读取 `content-pipeline/daily-brief-*.md` 最近一份，检查有无待审批内容

Step 5) 发送晨报
`message`(action: send, channel: discord, target: "channel:1468286777419890804")

格式：
```
☀️ 晨报 [MM-DD HH:MM]

🔨 系统: <fleet_status> | GW <healthCode>/<service> | 磁盘 XX% | cron N/M ✅ | 异常 X | cooldown Y | 死信 Z
⚠️ 异常任务:（无异常则省略此段）
- <任务名> — <问题描述>

📰 产出: 翻译 N 篇 | 情报 N 条 | 内容简报 <有/无>

📋 待办:
- <未闭环事项1>
- <未闭环事项2>
（无待办则写「无未闭环事项」）
```

硬约束：
- 全报告 ≤500 字
- 无异常 + 无产出 + 无待办 = 仍必须发送（极简版：系统状态一行）
- 最终输出 1 行：
`MORNING_BRIEFING_DONE fleet=<ok|warn|critical> crons_ok=<N> crons_fail=<N> outputs=<N> todos=<N>`