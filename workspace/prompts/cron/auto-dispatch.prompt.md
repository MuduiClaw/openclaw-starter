---
job_id: "36767cf3-9d76-4ddf-a86f-fc489df34cb2"
version: "v1.0.0"
name: "Auto-Dispatch: 主动发现与修复"
model: "google/gemini-3-flash-preview"
thinking: "high"
timeout: 600
schedule: "0 9,13,17,21 * * *"
schedule_tz: "Asia/Shanghai"
session_target: "isolated"
enabled: true
synced_at: "2026-03-01T07:56:54Z"
---

📋 **执行纪律**：开始任务前，先 `read ~/clawd/prompts/cron/_loop-discipline.md`，严格遵守其中的 Loop 规则。

⛔ 禁止回复 HEARTBEAT_OK。

Auto-Dispatch v4: 修复优先，发现→立即修→再扫描

核心原则：**发现问题就修，不是发现问题就告警。能自动修的立即修，修不了的才告警。**

## Phase 1: Cron 修复（最高优先级，必须先跑）🆕

1. `cron(action=list)` 获取所有 enabled job
2. 对每个 `consecutiveErrors > 0` 或 `lastStatus != ok` 的 job，**立即修复**：
   - **Timeout**（`lastDurationMs ≈ timeoutSeconds*1000` 且 `timeoutSeconds < 1800`）→ `cron update` timeout × 1.5（上限 1800s）→ 修完 `cron run` 验证
   - **Model 不可用**（overloaded/503）→ 不自动切换 model（风险高），记录 + 告警
   - **Prompt 问题** → 不改 prompt，记录 + 告警
   - **⑦ 自身故障** → 重点关注：Cron Health Scanner 自己挂了意味着监控链断裂，必须修（timeout 类按上面规则修）
3. 修复后 `cron run` 重跑验证，60s 后检查结果
4. 修复结果立即记录，不等到 Phase 4 才汇报

## Phase 1.5: Cron 空转检测
- 筛选可疑空转：`lastDurationMs < 60000` 且 `lastStatus=ok` 的 agentTurn job
- 对可疑 job（最多 5 个）：`cron(action=runs, jobId=X)` 查最近 3 次
- 连续 3 次 ok 但 summary 无实质产出 = 空转，标记告警（不修 prompt）

## Phase 2: 脚本层发现（快速）
`exec: bash $HOME/clawd/scripts/auto-dispatch/run.sh --source all`

## Phase 3: 深层发现（API 层，token 预算允许时）

### 3a. Discord 频道扫描（缩减版，最多 10 个最活跃频道）
1. `message(action=channel-list, channel=discord, guildId="1088387031597596762")` 获取频道
2. 过滤 type=0 且 last_message_id 非空
3. 只扫最近 **10 个**最活跃频道（不是全部）
4. 漏接检测：用户消息后 >10min 无 bot 回复
5. 异常检测：bot 消息含 ❌/error/failed/timeout

### 3b. Session 健康
- `sessions_list(activeMinutes=60, messageLimit=3)`
- context > 80% → 记录

## Phase 4: 汇报
有发现时发 Discord 告警到 `channel:1468286777419890804`。无发现则静默。

最终输出 1 行：
`AUTODISPATCH_DONE script_issues=<N> deep_issues=<M> channels_scanned=<C> missed=<X> errors_found=<Y> stale=<S> fixed=<K> alerts=<L> status=<clean|fixed|needs_attention>`