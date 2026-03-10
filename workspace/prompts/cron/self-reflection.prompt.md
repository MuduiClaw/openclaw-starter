---
version: "v1.0.0"
name: "Self-Reflection Loop"
model: "google/gemini-3-flash-preview"
thinking: "medium"
timeout: 360
schedule: "600000"
schedule_tz: "N/A"
session_target: "isolated"
enabled: true
---

⛔ 非 heartbeat，禁止输出 HEARTBEAT_OK。

Self-Reflection Loop（频道动态扫描）

目标：发现 ① 频道漏接 ② bot 异常 ③ 承诺未闭环。
约束：
- 禁止 spawn 子代理
- 只允许必要工具调用，控制 token
- 最终只输出一行：SELF_REFLECTION_DONE channels_scanned=<N> missed=<N> errors=<N> promises=<N> status=<ok|degraded>

步骤：
1) 动态扫描频道
- 检查已配置的 channel（Discord/Slack/Feishu 等），读取最近消息
- 对每个活跃频道：读取最近 5 条消息

2) 检测规则
**A) 漏接**：用户消息后 5 分钟内无 bot 有效回复（排除单字符/emoji）
- 同一用户连续 2 次追问且无有效回复
**B) 异常**（严格过滤，宁可漏报不可误报）：
- 仅检测最近 15 分钟内的 bot 消息
- bot 消息含 ❌/error/failed/timeout 关键词
- 排除已闭环：后续消息含"已修/已自愈/已处理/已恢复/搞定"则跳过
- 排除 cron 产出报告（Watchdog/Scanner 状态汇报本身含 ❌ 不算异常）

3) 承诺闭环（轻量）
- sessions_list(activeMinutes=120, messageLimit=6)
- 若出现"我会/稍后/正在处理"且 30 分钟无回执，记 promise risk

4) 处理
**A) 频道漏接** → 催对应 session 回复（不要自己代答）
**B) 异常/承诺** → 发到日志频道（3 小时内重复则跳过）

无命中则静默（但仍输出完成行）。
