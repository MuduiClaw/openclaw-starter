---
name: heartbeat-guide
description: "心跳（Heartbeat）行为指南：何时主动、何时沉默、heartbeat vs cron 选择、主动检查清单、记忆维护。在收到 heartbeat poll 或配置 HEARTBEAT.md 时触发。"
---

# Heartbeat 行为指南

## 核心原则

收到 heartbeat poll 时，**不要只回 `HEARTBEAT_OK`**。用每次 heartbeat 做点有用的事。

## Heartbeat vs Cron：选型指南

| 用 Heartbeat | 用 Cron |
|-------------|---------|
| 多项检查可批量执行 | 需要精确时间 |
| 需要最近对话上下文 | 需要隔离 session |
| 时间可以有漂移 | 需要指定不同模型 |
| 想减少 API 调用 | 一次性提醒 |

**Tips**: 相似的周期性检查批量写入 `HEARTBEAT.md`，不要建多个 cron job。精确调度和独立任务用 cron。

## 主动检查清单（每天轮检 2-4 次）

- **邮件** — 未读紧急邮件？
- **日历** — 未来 24-48h 有事件？
- **社交** — Twitter/社交通知？
- **天气** — 用户可能出门？

用 `memory/heartbeat-state.json` 追踪检查时间：
```json
{
  "lastChecks": {
    "email": 1703275200,
    "calendar": 1703260800,
    "weather": null
  }
}
```

## 何时主动联系

- 收到重要邮件
- 日历事件 <2h
- 发现有趣的东西
- 已 >8h 没说话

## 何时沉默 (HEARTBEAT_OK)

- 深夜 (23:00-08:00) 除非紧急
- 用户明显很忙
- 上次检查后无新信息
- 刚检查过 (<30 min)

## 可自主执行的工作

- 读取和整理记忆文件
- 检查项目状态 (git status)
- 更新文档
- commit and push 自己的变更
- **审阅和更新 MEMORY.md**

## 🔄 记忆维护（Heartbeat 期间）

每隔几天，利用一次 heartbeat 执行：
1. 读取近期 `memory/YYYY-MM-DD.md`
2. 识别值得长期保留的事件、教训、洞察
3. 更新 `MEMORY.md` 对应章节
4. 从 `MEMORY.md` 删除过时信息

**类比**: 人类翻阅日记、更新心智模型。Daily notes 是原始笔记；MEMORY.md 是提炼后的智慧。
