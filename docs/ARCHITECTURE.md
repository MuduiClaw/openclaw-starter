# Architecture

> OpenClaw 系统架构概览，理解各组件如何协作。

## 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Chat Channels                             │
│              Discord / 飞书 / Telegram / Slack               │
└─────────────────┬───────────────────────────────────────────┘
                  │ WebSocket
┌─────────────────▼───────────────────────────────────────────┐
│                  OpenClaw Gateway                            │
│  ┌──────────┐ ┌────────┐ ┌──────┐ ┌────────┐ ┌──────────┐ │
│  │  Router   │ │ Agent  │ │ Cron │ │ Memory │ │  Skills  │ │
│  │          │ │ Engine │ │Fleet │ │ (qmd)  │ │          │ │
│  └──────────┘ └────────┘ └──────┘ └────────┘ └──────────┘ │
│  Port: 3456                                                 │
└────────┬──────────┬──────────┬──────────────────────────────┘
         │          │          │
    ┌────▼───┐ ┌───▼────┐ ┌──▼─────────────┐
    │ Codex  │ │ Claude │ │  Gemini CLI    │
    │        │ │  Code  │ │                │
    └────────┘ └────────┘ └────────────────┘
         Coding Agents (ACP)

┌─────────────────────────────────────────────────────────────┐
│              infra-dashboard (localhost:3001)                 │
│  Gateway 状态 │ Cron 监控 │ 模型用量 │ Session 列表          │
└─────────────────────────────────────────────────────────────┘
```

## 组件说明

### Gateway
OpenClaw 的核心进程。负责：
- 接收 Chat Channel 消息
- 调度 Agent 推理（LLM API 调用）
- 管理 Cron 定时任务
- 提供 WebSocket API
- 工具调用 (tools) 执行

配置：`~/.openclaw/openclaw.json`
日志：`~/.openclaw/logs/`

### Cron Fleet
定时任务舰队。每个 cron job 是一个 prompt 模板，按设定频率触发 agent 执行。
详见 [CRON-FLEET.md](./CRON-FLEET.md)

### Memory System (qmd)
语义搜索引擎，让 AI 能检索历史记忆和知识。
- 后端：qmd（本地向量数据库）
- Collections：`memory-root-main`（MEMORY.md）、`memory-dir-main`（journal + archive）
- Wrapper：`~/.openclaw/scripts/qmd-safe.sh`

### Coding Agents (ACP)
Agent Control Protocol，让 AI 调度 coding agents：
- **Codex** — OpenAI 的 coding agent
- **Claude Code** — Anthropic 的 coding agent
- **Gemini CLI** — Google 的 coding agent

AI 根据任务复杂度自动选择合适的 agent。

### infra-dashboard
Next.js 监控面板，运行在 `localhost:3001`：
- Gateway 运行状态
- Cron job 执行历史
- 模型调用用量
- Active session 列表

### MCP Bridge
Model Context Protocol 桥接服务，让 AI 使用外部工具：
- **context7** — 实时文档查询
- **deepwiki** — GitHub repo 知识库

### LaunchAgents
macOS 后台服务，确保关键进程常驻：

| 服务 | Label | 用途 |
|------|-------|------|
| Gateway | `ai.openclaw.gateway` | 核心进程（OpenClaw 管理） |
| Guardian | `ai.openclaw.guardian` | Gateway 看门狗 |
| Dashboard | `com.openclaw.infra-dashboard` | 监控面板 |
| Backup | `ai.openclaw.backup` | Git 自动备份 |
| Log Rotate | `ai.openclaw.log-rotate` | 日志轮转 |
| Session Prune | `ai.openclaw.sessions-prune-cron` | Session 清理 |
| MCP Bridge | `com.openclaw.mcp-bridge` | MCP 服务 |

## 数据流

```
用户消息 → Discord/飞书 → Gateway → Agent Engine → LLM API
                                         ↓
                                    Tool Calls
                                    ├── exec (shell)
                                    ├── read/write (files)
                                    ├── memory_search (qmd)
                                    ├── message (reply)
                                    └── sessions_spawn (sub-agent)
```

## 文件系统

```
~/clawd/                    ← Workspace (AI 的工作目录)
├── AGENTS.md               ← 行为规则 (The Loop)
├── SOUL.md                 ← AI 人格
├── IDENTITY.md             ← AI 身份
├── USER.md                 ← 用户画像
├── TOOLS.md                ← 工具索引
├── MEMORY.md               ← 核心记忆
├── HEARTBEAT.md            ← 心跳行为
├── memory/                 ← 记忆存储
├── skills/                 ← 自定义 skills
├── scripts/                ← 自动化脚本
├── prompts/                ← Cron prompt 模板
└── tasks/                  ← 任务 spec

~/.openclaw/                ← State (运行状态)
├── openclaw.json           ← 配置文件
├── logs/                   ← 日志
├── scripts/                ← 服务脚本
└── sessions/               ← Session 数据

~/Library/LaunchAgents/     ← macOS 服务
└── ai.openclaw.*.plist
```

## 端口

| 端口 | 服务 | 说明 |
|------|------|------|
| 3456 | Gateway | OpenClaw 核心 |
| 3001 | Dashboard | 监控面板 |
| 9100 | MCP Bridge | MCP 服务 |
