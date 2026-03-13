# 🦞 OpenClaw

让 AI 从聊天框里走出来。

装在你的 Mac 上，能发消息、写代码、管文件、自动干活——不只是陪你聊天。

## 这是什么

[OpenClaw](https://github.com/openclaw/openclaw) 是一个开源的 AI 助手平台——功能强大，但装好之后你面对的是一堆配置项和空白文件。

这个项目是基于 OpenClaw 的**开箱即用方案**。我们把配置、工具、脚本、监控全部调通了，你只需要跑一行命令。

> 如果 OpenClaw 是毛坯房，这里就是精装交付。搬进去就能住。

| 自己装 OpenClaw | 用 Starter |
|---|---|
| 手动配 LLM、频道、工具 | 一行命令，交互式引导全搞定 |
| AI 没有人格，每次对话从零开始 | 人格和记忆系统已设计好，开口就有性格 |
| 写了代码不知道对不对 | 19 层自动化门禁，AI 乱搞会被拦住 |
| 不知道系统跑得怎么样 | 可视化监控面板，一眼看全 |
| 想让 AI 写代码得自己接 | Codex + Claude Code + Gemini 开箱可用 |
| AI 只在你找它时工作 | 定时任务 7×24 自动巡检、归档、监控 |
| 进程挂了得自己发现 | 守护进程自动重启 |
| 能力有限 | 23 个预装技能（设计/开发/文档/研究……）|

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

![Dashboard — 实时监控面板](https://img.mudui.me/docs/dashboard/dashboard-hero-87a89c11.png)

**核心能力：**

- 🧠 **会思考的工作流** — 想清楚 → 执行 → 验证 → 交付 → 复盘，不是无脑对话
- 💻 **帮你写代码** — Codex + Claude Code + Gemini CLI，三个编码代理开箱可用
- 🎯 **23 个技能** — 设计、开发、研究、文档、测试、视频——模块化的能力
- 🚧 **19 层质量门禁** — AI 写的代码[自动检查](docs/GATES.md)，格式不对、没测试、逻辑错都会被拦住
- ⏰ **7×24 自动干活** — 定时任务引擎，按需配置自动化巡检、归档、监控
- 📊 **可视化监控** — 服务状态、模型用量、Cron 健康、门禁统计，一眼看全
- 🎙️ **语音消息** — whisper.cpp 本地语音转文字，无需 API Key
- 🧩 **记忆系统** — 语义搜索，AI 记住你说过什么、做过什么决定
- 📧 **可选工具** — 邮件 (himalaya) · Google (gog) · X/Twitter (bird) · RSS (blogwatcher)
- 🔌 **MCP Bridge** — context7 + deepwiki，实时文档查询
- 🛡️ **自动守护** — 进程挂了自动重启，不用你盯着
- 🔧 **27 个脚本** — 升级、备份、日志轮转、健康巡检，运维自动化

## 系统要求

- **macOS** Ventura (13.0)+，Apple Silicon / Intel 均可
- **8GB+ RAM**，**5GB+ 磁盘**
- **聊天频道**：Discord 或飞书（至少配一个）
- **LLM**：MiniMax / Anthropic API / Claude 订阅（安装时选择）

Node.js、Homebrew 等依赖全部由安装脚本自动处理。

## 安装过程

```
🦞 OpenClaw Starter v1.3.1

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

编辑 `~/clawd/` 下的文件，打造你自己的 AI：

| 文件 | 用途 |
|------|------|
| `SOUL.md` | AI 的人格、调性、行为准则——它是谁 |
| `IDENTITY.md` | 名字、角色、已知缺陷 |
| `USER.md` | 你是谁、你的目标、偏好——让 AI 理解你 |
| `TOOLS.md` | 工具链索引、安全规则 |
| `AGENTS.md` | 工作方法论（The Loop） |
| `MEMORY.md` | 核心记忆索引——AI 的长期记忆 |

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
质量门禁 → 19 层 Git Gates (plan → ship → system)
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
| **[工具深度指南](docs/guides/README.md)** | 12 篇实战指南：Codex、Claude Code、Discord、1Password、MCP 等 |
| **[FAQ](docs/FAQ.md)** | 常见问题、排错、升级 |
| **[架构](docs/ARCHITECTURE.md)** | 系统架构详解 |
| **[Cron Fleet](docs/CRON-FLEET.md)** | 定时任务使用指南 |
| **[门禁系统](docs/GATES.md)** | 19 层自动化质量门禁 |
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
