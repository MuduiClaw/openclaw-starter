# Cron Fleet 指南

> 定时任务舰队：让 AI 自动执行周期性工作。

## 概念

Cron Fleet 是 OpenClaw 的定时任务系统。每个 "job" 就是一个 prompt 模板，按设定频率自动触发 agent 执行。

你的 AI 助手不只在你找它时才工作——它 7×24 在后台巡检、归档、监控。

## 推荐 Cron Jobs（7 个）

### 🔴 核心

| Job | 频率 | 做什么 |
|-----|------|--------|
| **auto-dispatch** | 4x/day | 主动发现问题 + 自动修复：cron 失败、LaunchAgent 异常、任务积压 |
| **cron-health-scanner** | 2x/day | Fleet 自身健康检查：连续失败检测、timeout 自动调整 |

### 🟡 日常

| Job | 频率 | 做什么 |
|-----|------|--------|
| **morning-briefing** | 每天 08:10 | 晨报：昨日摘要 + 今日待办 |
| **daily-journal** | 每天 23:30 | 复盘日志：今天做了什么 → `memory/journal/YYYY-MM-DD.md` |
| **daily-memory-archive** | 每天 01:10 | 记忆归档：将 session 中重要信息沉淀到 memory/ |

### 🔵 周度

| Job | 频率 | 做什么 |
|-----|------|--------|
| **weekly-memory-maintenance** | 周日 05:10 | 记忆去重/清理：删除重复、合并相似 |

### ⚪ 维护

| Job | 频率 | 做什么 |
|-----|------|--------|
| **reset-log-session** | 每天 03:10 | Session + 日志清理：防止 bloat |

## 配置 Cron Jobs

Cron jobs 通过 `openclaw.json` 的 `cron` 字段配置，或通过 CLI 管理：

```bash
# 查看所有 cron jobs
openclaw cron list

# 查看某个 job 的详情
openclaw cron info <job-name>

# 手动触发
openclaw cron trigger <job-name>

# 禁用/启用
openclaw cron disable <job-name>
openclaw cron enable <job-name>
```

## 添加自定义 Cron

1. 在 `~/clawd/prompts/cron/` 创建 `your-job.prompt.md`
2. 写 prompt 模板（参考现有模板的格式）
3. 通过 `openclaw cron` 或 `openclaw.json` 注册

### Prompt 模板格式

```markdown
---
# Cron metadata (YAML frontmatter)
schedule: "0 */6 * * *"     # 标准 cron 表达式
model: "anthropic/claude-sonnet-4-6"  # 模型（可选，默认用 agents.defaults）
timeout: 300                 # 超时秒数
enabled: true
---

# Job Title

你的 prompt 内容...
```

## 监控

### 通过 Dashboard
infra-dashboard (`localhost:3001`) 提供 cron 执行历史的可视化。

### 通过 CLI
```bash
# 查看最近执行
openclaw cron runs --limit 20

# 查看失败的 jobs
openclaw cron runs --status failed
```

### 通过 Auto-Dispatch
`auto-dispatch` cron job 会自动检测连续失败的 job 并尝试修复（比如调大 timeout）。

## 最佳实践

1. **不要把所有事情都塞进 cron** — cron 适合重复性、低风险的任务
2. **设合理的 timeout** — 太短会频繁失败，太长会浪费资源
3. **控制并发** — `cron.maxConcurrentRuns` 默认 3，防止爆 token 预算
4. **看日志** — `~/.openclaw/logs/` 有详细执行日志
5. **先 dry-run** — 新 job 先手动触发测试，再启用自动调度
