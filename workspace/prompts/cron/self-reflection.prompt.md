---
job_id: "6aedeef5-0b75-4aff-8448-d078da5c9f6a"
version: "v1.0.0"
name: "Self-Reflection Loop"
model: "google/gemini-3-flash-preview"
thinking: "medium"
timeout: 360
schedule: "600000"
schedule_tz: "N/A"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 非 heartbeat，禁止输出 HEARTBEAT_OK。

Self-Reflection Loop v13（全频道动态扫描）

目标：发现 ① 频道漏接 ② bot 异常 ③ 承诺未闭环。
约束：
- 禁止 spawn 子代理
- 只允许必要工具调用，控制 token
- 最终只输出一行：SELF_REFLECTION_DONE channels_scanned=<N> missed=<N> errors=<N> promises=<N> status=<ok|degraded>

步骤：
1) 动态扫描全服务器频道
- `message(action=channel-list, channel=discord, guildId="1088387031597596762")`
- 过滤：只保留 type=0 且 last_message_id 非空的文字频道
- 对每个活跃频道：`message(action=read, channel=discord, target="channel:{id}", limit=5)`

2) 检测规则
**A) 漏接**：用户消息后 5 分钟内无 bot 有效回复（排除单字符/emoji）
- 同一用户连续 2 次追问（如"？""啥情况"）且无有效回复
**B) 异常**（严格过滤，宁可漏报不可误报）：
- 仅检测 **最近 15 分钟内** 的 bot 消息（超过 15min 的视为已过期，跳过）
- bot 消息含 ❌/error/failed/timeout 关键词
- **排除已闭环**：同频道后续消息含"已修/已自愈/假阳性/已处理/已恢复/搞定"则跳过
- **排除 cron 产出报告**：Watchdog/Scanner 等 cron 的状态汇报本身含 ❌ 不算异常

3) 承诺闭环（轻量）
- sessions_list(activeMinutes=120, messageLimit=6)
- 若出现"我会/稍后/正在处理"且 30 分钟无回执，记 promise risk

4) 处理漏接（仅命中时）
**A) 频道漏接 → 催对应 session 回复**（不要自己代答）
- `sessions_list(kinds=["discord"])` 找到负责该频道的 session
- `sessions_send(sessionKey=<对应session>, message="⚠️ 频道漏接：#<频道> 有来自 <用户> 的未回复消息（<X>min），请立即处理。消息内容：\"<前80字>\"")`
- 催完后在 channel:1468286777419890804 简要记录：`⚠️ [频道漏接] #<频道> → 已催 session <key> 处理`

**B) 异常/承诺 → 发到日志频道**
- message(search, channel=discord, channelId="1468286777419890804", query="[异常] OR [PROMISE]", limit=6)
- 3 小时内重复则跳过
- **时间格式统一北京时间**：`HH:MM` 或 `HH:MM UTC+8`，禁止使用 CST/EST 等缩写
- 格式：
  ❌ [异常] #<频道>: "错误摘要"（HH:MM）
  📋 [PROMISE] <会话> (<X>min): "摘要"

无命中则静默（但仍输出完成行）。