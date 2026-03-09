# 🦞 OpenClaw Starter Kit

> 把 battle-tested 的 AI 合伙人系统打包——10 分钟在你的 Mac 上跑起来。

一条命令，全自动安装。不需要 Docker，不需要手动配环境。

## 快速开始

```bash
git clone https://github.com/MuduiClaw/openclaw-starter.git
cd openclaw-starter
./setup.sh
```

脚本会引导你完成所有配置。完成后打开 `http://localhost:3001` 查看监控面板。

## 你会得到什么

| 能力 | 说明 |
|------|------|
| **The Loop 方法论** | 实战检验的 Agent 工作循环：想清楚 → 执行 → 验证 → 交付 → 复盘 |
| **Cron Fleet（13 任务）** | 每日晨报、自动复盘、Fleet 健康监控、博客追踪、记忆归档等 |
| **24 个 Skills** | 设计、开发、研究、文档、测试、视频——模块化的 AI 能力 |
| **Coding Agents** | Codex + Claude Code + Gemini CLI 作为 AI 的执行团队 |
| **记忆系统（qmd）** | 语义搜索，让 AI 记住上下文和决策 |
| **infra-dashboard** | `localhost:3001` 实时监控面板（服务状态 / 工具 / LaunchAgent / Cron） |
| **MCP Bridge** | context7 + deepwiki，实时文档查询 |
| **Guardian Agent** | 3 层智能守护：进程检查 → 自动修复 → 回滚 → 通知 |
| **25 个自动化脚本** | 升级、备份、日志轮转、Fleet 检查、健康巡检等 |

## 系统要求

- **macOS** Ventura (13.0) 或更高（Apple Silicon / Intel 均可）
- **8GB+** RAM
- **5GB+** 可用磁盘空间
- **LLM 提供商**（三选一）：
  - MiniMax M2.5（推荐，内置 API Key 开箱即用）
  - Anthropic API Key（按量付费）
  - Claude Pro/Max 订阅（通过 OAuth setup-token）

## 安装过程

```
🦞 OpenClaw Starter Kit v1.3.0

[0/3] 环境检查 ━━━━━━━━━━━━━━━━━━━━
     macOS (arm64) ✓  15.7.3 ✓
     Disk: 402GB free ✓  RAM: 18GB ✓

[1/3] 依赖安装
     Xcode CLT ✓  Homebrew ✓  Node.js v24 ✓  Bun ✓  uv ✓
     OpenClaw ✓  Codex ✓  Claude Code ✓  Gemini CLI ✓
     qmd ✓  mcporter ✓  clawhub ✓  oracle ✓

[2/3] 配置
     LLM 模型 — 选择默认提供商:
       1. MiniMax M2.5 (推荐，开箱即用)
       2. Anthropic API Key (按量付费)
       3. Anthropic OAuth (用 Claude 订阅)
     > 1 ✓

     Chat Channel — 选择一个:
       1. Discord
       2. 飞书 (Feishu)
     > _

[3/3] 启动
     Gateway ✓  Dashboard ✓  MCP Bridge ✓  Guardian ✓
     LaunchAgents: 8/8 ✓

🎉 你的 AI 合伙人已就绪。
   Dashboard:  http://localhost:3001
   下一步:     在 Discord/飞书跟你的 AI 说句话试试
```

## 安装后

### 定义你的 AI

编辑 `~/clawd/` 下的文件，打造你自己的 AI 合伙人：

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
# 检查系统状态
openclaw status

# 健康诊断
openclaw doctor

# 查看 cron 任务
openclaw cron list

# 手动触发 cron
openclaw cron trigger <job-name>

# 查看 Gateway 日志
tail -f ~/.openclaw/logs/gateway.log

# LaunchAgent 健康检查
bash ~/clawd/scripts/check-launchagent-health.sh

# 升级 OpenClaw
bash ~/clawd/scripts/safe-upgrade-openclaw.sh

# 卸载全部
./setup.sh --uninstall
```

### 安装选项

```bash
./setup.sh                    # 标准安装
./setup.sh --no-launchagents  # 不安装后台服务
./setup.sh --skip-dashboard   # 不安装监控面板
./setup.sh --no-tailscale     # 跳过 Tailscale 远程访问
./setup.sh --no-caffeinate    # 不配置防休眠
./setup.sh --uninstall        # 完全卸载
```

## 安全设计

- 所有服务绑定 `127.0.0.1`（不暴露到局域网）
- API Key 交互式输入，不硬编码在脚本中
- GitHub Token 通过 `http.extraheader` 传递，不写入 `.git/config`
- 配置生成使用 python3 + 环境变量，无 shell 注入风险
- Guardian Agent：`shell=False` + `shlex.split`

## 架构

```
你 ←→ Discord/飞书 ←→ OpenClaw Gateway (:3456)
                          ├── Agent (LLM + Skills + Memory)
                          ├── Cron Fleet (13 定时任务)
                          └── MCP Bridge (:9100)

监控面板 → infra-dashboard (:3001)
守护进程 → Guardian Agent (3 层自动恢复)
后台服务 → 8 个 LaunchAgent (备份/日志/清理/防休眠...)
```

## 项目结构

```
openclaw-starter/
├── setup.sh                 # 安装脚本（你运行的唯一命令）
├── CHANGELOG.md             # 版本变更记录
├── workspace/               # → 安装到 ~/clawd
│   ├── AGENTS.md            # The Loop 方法论
│   ├── *.md.example         # 个性化文件模板
│   ├── skills/              # 24 个 skills
│   ├── scripts/             # 25 个自动化脚本
│   ├── prompts/             # 13 个 cron 模板
│   ├── eval/                # 质量评估框架
│   └── mcp-bridge/          # MCP 服务
├── config/                  # 配置模板
├── services/                # LaunchAgent 模板 + 服务启动脚本
└── docs/                    # 文档
```

## 文档

- [系统架构](docs/ARCHITECTURE.md) — 组件如何协作
- [Cron Fleet](docs/CRON-FLEET.md) — 定时任务详解
- [Skills 指南](docs/SKILLS-GUIDE.md) — 扩展 AI 能力
- [升级指南](docs/UPGRADE.md) — 版本升级方法
- [问题排查](docs/TROUBLESHOOTING.md) — 常见问题解决

## 致谢

基于 [OpenClaw](https://github.com/openclaw/openclaw) 构建。

## License

MIT
