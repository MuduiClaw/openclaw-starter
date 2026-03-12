# 🦞 OpenClaw Starter Kit

> 经过真实场景验证的 AI 合伙人系统——10 分钟在你的 Mac 上跑起来。

## 快速开始

一行命令，全新 Mac 也能跑：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MuduiClaw/openclaw-starter/main/bootstrap.sh)"
```

> 全新 Mac 会自动安装 Xcode Command Line Tools（首次可能需要几分钟）。

<details>
<summary>或者手动 clone</summary>

```bash
git clone https://github.com/MuduiClaw/openclaw-starter.git
cd openclaw-starter
./setup.sh
```
</details>

脚本会引导你完成所有配置。完成后：
- `http://localhost:3456` — 跟 AI 对话（粘贴 Gateway Token）
- `http://localhost:3001` — 基建监控面板

## 你会得到什么

| 能力 | 说明 |
|------|------|
| **The Loop** | 实战检验的 Agent 工作循环：想清楚 → 执行 → 验证 → 交付 → 复盘 |
| **Coding Agents** | Codex + Claude Code + Gemini CLI 作为 AI 的执行团队 |
| **23 个 Skills** | 设计、开发、研究、文档、测试、视频——模块化的 AI 能力 |
| **Git 质量门禁** | [21 层自动化 Gate](docs/GATES.md)：commit 格式、scope 检查、spec 审查、TDD 强制、tree-hash 防伪 |
| **Cron 定时任务** | 内置调度引擎，按需配置自动化任务 |
| **infra-dashboard** | 实时监控：服务状态、Settings 配置、工具版本、模型用量、Cron、Gate 健康 |
| **语音消息** | whisper.cpp 本地语音转文字，无需 API Key |
| **记忆系统** | qmd 语义搜索，让 AI 记住上下文和决策 |
| **可选 CLI 工具** | himalaya (邮件) · gog (Google) · bird (X/Twitter) · blogwatcher (RSS) |
| **MCP Bridge** | context7 + deepwiki，实时文档查询 |
| **Guardian Agent** | 3 层守护：进程检查 → 自动修复 → 自动重启 |
| **27 个脚本** | 升级、备份、日志轮转、Fleet 检查、健康巡检等 |

## 系统要求

- **macOS** Ventura (13.0)+，Apple Silicon / Intel 均可
- **8GB+ RAM**，**5GB+ 磁盘**
- **聊天频道**：Discord 或飞书（至少配一个）
- **LLM**：MiniMax / Anthropic API / Claude 订阅（安装时选择）

Node.js、Homebrew 等依赖全部由安装脚本自动处理。

## 安装过程

```
🦞 OpenClaw Starter Kit v1.3.1

[1/3] 依赖安装
     OpenClaw ✓  Codex ✓  Claude Code ✓  Gemini CLI ✓
     qmd ✓  whisper.cpp ✓  himalaya ✓  gog ✓  bird ✓  blogwatcher ✓

[2/3] 配置
     LLM 模型 — 选择默认提供商:
       1. MiniMax M2.5 (推荐，最快上手)
       2. Anthropic API Key (按量付费)
       3. Anthropic OAuth (用 Claude 订阅)

     Chat Channel — Discord / 飞书

[3/3] 启动
     Gateway ✓  Dashboard ✓  MCP Bridge ✓  Guardian ✓

🎉 你的 AI 合伙人已就绪。
```

## 安装后

### 定义你的 AI

编辑 `~/clawd/` 下的文件，打造你自己的 AI 合伙人：

| 文件 | 用途 |
|------|------|
| `SOUL.md` | AI 的人格、调性、行为准则 |
| `IDENTITY.md` | 名字、角色、已知缺陷 |
| `USER.md` | 你是谁、你的目标、偏好 |
| `TOOLS.md` | 工具链索引、安全规则 |
| `AGENTS.md` | 工作方法论（The Loop） |
| `MEMORY.md` | 核心记忆索引 |

这些文件升级时**永远不会被覆盖**。

### 常用命令

```bash
openclaw status                 # 系统状态
openclaw doctor                 # 健康诊断
openclaw cron list              # 查看定时任务
openclaw cron trigger <job>     # 手动触发
./setup.sh --update-dashboard   # 更新监控面板
./setup.sh --uninstall          # 完全卸载
```

### 安装选项

```bash
./setup.sh                      # 标准安装
./setup.sh --update-dashboard   # 更新 infra-dashboard
./setup.sh --no-launchagents    # 不装后台服务
./setup.sh --skip-dashboard     # 不装监控面板
./setup.sh --no-tailscale       # 跳过 Tailscale
./setup.sh --no-caffeinate      # 不配置防休眠
./setup.sh --uninstall          # 完全卸载
```

## 架构

```
你 ←→ Discord/飞书 ←→ OpenClaw Gateway (:3456)
                          ├── Agent (LLM + Skills + Memory)
                          ├── Cron Engine (定时任务)
                          └── MCP Bridge (:9100)

监控面板 → infra-dashboard (:3001)
守护进程 → Guardian Agent (自动恢复)
后台服务 → 8 个 LaunchAgent
质量门禁 → 7 层 Git Gates (commit → push)
```

## 项目结构

```
openclaw-starter/
├── bootstrap.sh             # 一行 curl 入口
├── setup.sh                 # 主安装脚本
├── workspace/               # → 安装到 ~/clawd
│   ├── AGENTS.md            # The Loop 方法论
│   ├── *.md.example         # 个性化模板
│   ├── skills/              # 23 个 skills
│   ├── scripts/             # 27 个脚本
│   └── mcp-bridge/          # MCP 服务
├── config/                  # 配置模板
├── services/                # LaunchAgent + 启动脚本
├── tasks/                   # Spec 模板
├── tests/                   # bats 测试
└── docs/                    # 详细文档 ↓
```

## 文档

| 文档 | 内容 |
|------|------|
| **[配置指南](docs/SETUP-GUIDE.md)** | LLM、频道、搜索、语音、Tailscale 详细配置 |
| **[FAQ](docs/FAQ.md)** | 常见问题、排错、升级 |
| **[架构](docs/ARCHITECTURE.md)** | 系统架构详解 |
| **[Cron Fleet](docs/CRON-FLEET.md)** | 定时任务使用指南 |
| **[门禁系统](docs/GATES.md)** | 21 层自动化质量门禁：安装、使用、自定义 |
| **[Skills](docs/SKILLS-GUIDE.md)** | Skills 扩展指南 |
| **[升级](docs/UPGRADE.md)** | 三层升级：OpenClaw / Dashboard / Starter |
| **[排错](docs/TROUBLESHOOTING.md)** | 问题诊断与解决 |

### 外部链接

- [OpenClaw 官方文档](https://docs.openclaw.ai)
- [OpenClaw 社区 (Discord)](https://discord.com/invite/clawd)
- [GitHub](https://github.com/openclaw/openclaw)

## 安全设计

- 所有服务绑定 `127.0.0.1`，不暴露局域网
- API Key 交互式输入，不硬编码
- 敏感文件 `umask 077`
- Gateway Token 自动生成，重跑不覆盖
- 配置生成用 python3 + 环境变量，无 shell 注入
- 卸载路径安全检查（拒绝删除危险路径）

## 致谢

基于 [OpenClaw](https://github.com/openclaw/openclaw) 构建。

## License

MIT
