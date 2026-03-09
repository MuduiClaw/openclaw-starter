# 🦞 OpenClaw Starter Kit

> 把 battle-tested 的 AI 合伙人能力打包——10 分钟在你的 Mac 上跑起来。

你只需要做 **3 件事**：
1. 运行 `./setup.sh`
2. 粘贴 Anthropic 凭证
3. 粘贴 Chat Channel Token

其余全自动。

## 你会得到什么

| 能力 | 说明 |
|------|------|
| **The Loop 方法论** | 经过实战检验的 Agent 工作循环：想清楚 → 执行 → 验证 → 交付 → 复盘 |
| **Cron Fleet（13 任务）** | 每日晨报、自动复盘、Fleet 健康监控、博客追踪、记忆归档... |
| **24 个 Skills** | 设计、开发、研究、文档、测试、视频——AI 的能力模块 |
| **Coding Agents** | Codex + Claude Code + Gemini CLI，AI 的执行团队 |
| **记忆系统（qmd）** | 语义搜索，让 AI 记住你说过的话 |
| **infra-dashboard** | `localhost:3001` 监控面板 |
| **MCP Bridge** | context7 + deepwiki，实时文档查询 |
| **25 个自动化脚本** | 升级、备份、日志轮转、Fleet 检查... |

## 要求

- macOS Ventura (13.0) 或更高
- 8GB+ RAM
- 5GB+ 可用磁盘空间
- Anthropic API Key 或 Claude Pro/Max 订阅

## 快速开始

```bash
git clone https://github.com/YOUR_USER/openclaw-starter.git
cd openclaw-starter
./setup.sh
```

安装过程：

```
🦞 OpenClaw Starter Kit v1.0.0

[0/3] 环境检查 ━━━━━━━━━━━━━━━━━━━━
     macOS (arm64) ✓
     macOS 15.3 ✓
     Disk: 120GB free ✓
     RAM: 16GB ✓

[1/3] 依赖安装
     Xcode CLT ✓  Homebrew ✓  Node.js v24 ✓
     OpenClaw ✓  Codex ✓  Claude Code ✓  Gemini CLI ✓  qmd ✓

[2/3] 配置
     Anthropic 认证 — 选择方式:
       1. API Key (按量付费)
       2. setup-token (用 Claude 订阅)
     > _

     Chat Channel — 选择一个:
       1. Discord
       2. 飞书 (Feishu)
     > _

[3/3] 启动
     Gateway ✓  Dashboard ✓  Memory ✓

🎉 你的 AI 合伙人已就绪。
   Dashboard:  http://localhost:3001
   下一步:     在 Discord/飞书 跟你的 AI 说句话试试
```

## 安装后

### 自定义你的 AI
编辑 `~/clawd/` 下的文件，定义你的 AI 合伙人：

| 文件 | 用途 | 首次安装自动创建 |
|------|------|:---:|
| `SOUL.md` | AI 的人格、调性、行为准则 | ✅ |
| `IDENTITY.md` | AI 的名字、角色、已知缺陷 | ✅ |
| `USER.md` | 你是谁、你的目标、你的偏好 | ✅ |
| `TOOLS.md` | 工具链索引、安全规则 | ✅ |
| `AGENTS.md` | 工作方法论（The Loop） | ✅ |
| `MEMORY.md` | 核心记忆索引 | ✅ |

这些文件升级时**永远不会被覆盖**。

### 常用命令

```bash
# 检查状态
openclaw status

# 查看 cron 任务
openclaw cron list

# 手动触发 cron
openclaw cron trigger morning-briefing

# 查看 Gateway 日志
tail -f ~/.openclaw/logs/gateway.log

# 升级 OpenClaw
bash ~/clawd/scripts/safe-upgrade-openclaw.sh

# 卸载
./setup.sh --uninstall
```

## 文档

- [系统架构](docs/ARCHITECTURE.md) — 组件如何协作
- [Cron Fleet](docs/CRON-FLEET.md) — 定时任务详解
- [Skills 指南](docs/SKILLS-GUIDE.md) — 扩展 AI 能力
- [升级指南](docs/UPGRADE.md) — 版本升级方法
- [问题排查](docs/TROUBLESHOOTING.md) — 常见问题解决

## 项目结构

```
openclaw-starter/
├── setup.sh                 # 安装脚本（你运行的唯一命令）
├── sync-to-template.sh      # 维护者：从 live 环境同步
├── workspace/               # → 安装到 ~/clawd
│   ├── AGENTS.md            # The Loop 方法论
│   ├── *.md.example         # 个性化模板
│   ├── skills/              # 24 个 skills
│   ├── scripts/             # 25 个自动化脚本
│   ├── prompts/             # 13 个 cron 模板
│   ├── eval/                # 质量评估框架
│   └── mcp-bridge/          # MCP 服务
├── config/                  # 配置模板
├── services/                # LaunchAgent + 服务脚本
└── docs/                    # 文档
```

## 致谢

基于 [OpenClaw](https://github.com/openclaw/openclaw) 构建。

## License

MIT
