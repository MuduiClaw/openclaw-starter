# 🦞 OpenClaw Starter Kit

把 battle-tested 的 OpenClaw 全套能力一键部署到你的 Mac 上。

**你只需要做 3 件事**：运行脚本、贴 API key、选聊天频道。其他全自动。

## 你会得到什么

- **The Loop 方法论** — 经过实战验证的 AI agent 工作流（Plan → Execute → Verify → Ship → Learn）
- **24 个 Skills** — 从代码审查到文档生成到网页爬取的预置能力
- **13 个 Cron 任务** — 自动晨报、复盘、Fleet 监控、系统进化
- **Infra Dashboard** — 实时监控你的 AI 系统状态
- **Coding Agents** — Codex + Claude Code + Gemini CLI 编排
- **记忆系统** — qmd 语义搜索，你的 AI 会记住上下文
- **MCP Bridge** — 外部工具集成

## 环境要求

| 项目 | 最低要求 |
|------|---------|
| 系统 | macOS Ventura 13.0+ |
| 芯片 | Apple Silicon 或 Intel |
| 内存 | 8GB RAM |
| 磁盘 | 5GB 可用空间 |

其他依赖（Homebrew、Node.js、Git 等）由安装脚本自动搞定。

## 快速开始

```bash
git clone https://github.com/YOUR_USERNAME/openclaw-starter.git
cd openclaw-starter
./setup.sh
```

安装过程：

```
🦞 OpenClaw Starter Kit v1.0.0

[1/3] 环境准备 ━━━━━━━━━━━━━━━━━━━━ 100%
     Homebrew ✓  Node.js v24 ✓  OpenClaw 2026.3.x ✓
     Codex ✓  Claude Code ✓  Gemini CLI ✓  qmd ✓

[2/3] 配置
     Anthropic 认证 — 选择方式:
       1. API Key (按量付费)
       2. Claude setup-token (用 Claude 订阅)
     > 1
     Anthropic API Key: sk-ant-••••••••
     
     Chat Channel — 选择一个:
       1. Discord
       2. 飞书 (Feishu)
     > 1
     Discord Bot Token: ••••••••

[3/3] 启动 ━━━━━━━━━━━━━━━━━━━━ 100%
     Gateway ✓  Dashboard ✓  Cron Fleet (13 jobs) ✓  Memory ✓

🎉 你的 AI 合伙人已就绪。
   Dashboard:  http://localhost:3001
   下一步:     在 Discord 跟你的 AI 说句话试试
```

## 安装后

### 自定义你的 AI

编辑 `~/clawd/` 下的文件，定义你的 AI 合伙人：

| 文件 | 用途 |
|------|------|
| `SOUL.md` | 人格、思考方式、行为准则 |
| `IDENTITY.md` | 名字、角色、已知缺陷 |
| `USER.md` | 关于你——目标、偏好、决策框架 |
| `TOOLS.md` | 工具索引、网络配置 |
| `MEMORY.md` | 核心知识索引 |

首次安装会从 `.example` 模板创建，按你的需求修改即可。

### 监控

打开 `http://localhost:3001` 查看 Infra Dashboard。

### 升级

```bash
cd openclaw-starter
git pull
./setup.sh  # 幂等，只更新变更的文件
```

## 目录结构

```
workspace/          # → ~/clawd（你的 AI 工作空间）
  ├── AGENTS.md     # The Loop 方法论
  ├── scripts/      # 自动化脚本
  ├── prompts/      # Cron 任务模板
  ├── skills/       # 24 个预置 Skills
  ├── eval/         # 质量评估框架
  └── memory/       # 记忆存储

projects/
  └── infra-dashboard/  # 监控面板（git submodule）

services/           # macOS LaunchAgent 模板
config/             # 配置文件模板
docs/               # 详细文档
```

## 文档

- [系统架构](docs/ARCHITECTURE.md)
- [Cron Fleet 指南](docs/CRON-FLEET.md)
- [Skills 扩展](docs/SKILLS-GUIDE.md)
- [升级指南](docs/UPGRADE.md)
- [常见问题](docs/TROUBLESHOOTING.md)
- [OpenClaw 官方文档](https://docs.openclaw.ai)

## License

MIT
