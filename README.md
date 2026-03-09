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
- **聊天频道**：Discord 或飞书（至少配一个）
- **LLM 提供商**：安装脚本会引导你选择（见下方详细说明）

---

## 配置指南

安装脚本会交互式引导你完成以下配置。这里是每个步骤的详细说明，方便你提前准备。

### LLM 模型配置

安装时会让你选一个默认 LLM 提供商。三个选项：

#### 选项 1：MiniMax M2.5（推荐，最快上手）

[MiniMax M2.5](https://www.minimax.io/news/minimax-m25) 是面向编程和复杂任务优化的模型。安装脚本内置了可用的 API Key，**选 1 即可直接用，无需额外注册**。

如果你想用自己的 key：去 [MiniMax 开放平台](https://platform.minimax.io/) 注册并创建 API Key。

> 对应配置：`minimax/MiniMax-M2.5`（通过 `https://api.minimax.io/anthropic` 兼容接口）

#### 选项 2：Anthropic API Key（按量付费）

适合有 Anthropic 账号、想用 Claude 系列模型的用户。

1. 去 [Anthropic Console](https://console.anthropic.com/settings/keys) 创建 API Key
2. 安装时粘贴 key（格式 `sk-ant-...`）

> 对应配置：`anthropic/claude-sonnet-4-6`
>
> 官方文档：[docs.openclaw.ai — Anthropic Provider](https://docs.openclaw.ai/providers/anthropic)

#### 选项 3：Anthropic OAuth（用 Claude Pro/Max 订阅）

如果你有 Claude Pro 或 Max 订阅，可以免 API 费用使用。

1. 安装时选 3，脚本会运行 `openclaw onboard`
2. 浏览器打开 Anthropic OAuth 页面，登录授权
3. 复制 setup-token 粘贴到终端

> ⚠️ Anthropic 订阅认证不支持 prompt caching，且政策可能变化。生产环境推荐 API Key。
>
> 官方文档：[docs.openclaw.ai — OAuth](https://docs.openclaw.ai/concepts/oauth)

#### 安装后切换/添加模型

```bash
# 交互式切换
openclaw configure  # 选 "Model/auth"

# 或直接修改配置
openclaw config set 'agents.defaults.model.primary' '"anthropic/claude-opus-4-6"' --json
openclaw gateway restart
```

支持的完整提供商列表：[docs.openclaw.ai — Model Providers](https://docs.openclaw.ai/providers/models)

---

### 聊天频道配置

你需要配至少一个频道，AI 才能和你对话。安装脚本支持 Discord 和飞书。

#### Discord

你需要创建一个 Discord Bot 并把它加到你的服务器。

**准备工作**（5 分钟）：

1. **创建应用和 Bot**
   - 打开 [Discord Developer Portal](https://discord.com/developers/applications) → **New Application** → 起个名字（如 "OpenClaw"）
   - 左侧点 **Bot** → 设置头像和名称

2. **开启 Intents**
   - 在 Bot 页面滚到 **Privileged Gateway Intents**，打开：
     - ✅ **Message Content Intent**（必须）
     - ✅ **Server Members Intent**（推荐）
     - ☐ Presence Intent（可选）

3. **复制 Bot Token**
   - Bot 页面点 **Reset Token** → 复制保存

4. **生成邀请链接，加 Bot 到服务器**
   - 左侧点 **OAuth2** → 勾选 `bot` + `applications.commands`
   - Bot Permissions 勾选：View Channels / Send Messages / Read Message History / Embed Links / Attach Files / Add Reactions
   - 复制生成的 URL → 浏览器打开 → 选服务器 → 确认

5. **获取 ID**
   - Discord 设置 → 高级 → 打开**开发者模式**
   - 右键服务器图标 → Copy Server ID
   - 右键你自己头像 → Copy User ID

6. **允许 Bot DM**
   - 右键服务器图标 → 隐私设置 → 打开**允许服务器成员给你发私信**

安装脚本会依次要求你输入：Bot Token、Server ID、User ID。

> 官方文档：[docs.openclaw.ai — Discord](https://docs.openclaw.ai/channels/discord)

#### 飞书 (Feishu)

你需要在飞书开放平台创建一个应用。

**准备工作**（5 分钟）：

1. **创建企业应用**
   - 打开 [飞书开放平台](https://open.feishu.cn/app) → 创建企业自建应用
   - 填写名称和描述
   - 海外用户用 [Lark](https://open.larksuite.com/app)

2. **复制凭证**
   - 在**凭证与基础信息**页面，复制：
     - **App ID**（格式 `cli_xxx`）
     - **App Secret**

3. **配置权限**
   - 在**权限管理**页面，添加以下权限：
     - `im:message`（发消息）
     - `im:message:readonly`（读消息）
     - `im:message.p2p_msg:readonly`（读私聊）
     - `im:chat.members:bot_access`（群成员）

4. **启用机器人能力**
   - 在**应用能力**页面 → 添加**机器人**能力

5. **发布应用**
   - 在**版本管理与发布**页面 → 创建版本 → 申请发布
   - 管理员审批通过后，在飞书 App 中搜索你的机器人即可对话

安装脚本会要求你输入：App ID 和 App Secret。

> 官方文档：[docs.openclaw.ai — Feishu](https://docs.openclaw.ai/channels/feishu)

#### 安装后添加更多频道

```bash
openclaw channels add
```

支持的全部频道：Discord / 飞书 / Telegram / WhatsApp / Slack / Signal / iMessage / IRC / Line / Matrix 等。

完整列表：[docs.openclaw.ai — Channels](https://docs.openclaw.ai/channels)

---

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

## 更多文档

- **OpenClaw 官方文档**：[docs.openclaw.ai](https://docs.openclaw.ai)
- **模型配置**：[docs.openclaw.ai/providers/models](https://docs.openclaw.ai/providers/models)
- **频道配置**：[docs.openclaw.ai/channels](https://docs.openclaw.ai/channels)
- **Gateway 认证**：[docs.openclaw.ai/gateway/authentication](https://docs.openclaw.ai/gateway/authentication)
- **OpenClaw 社区**：[discord.com/invite/clawd](https://discord.com/invite/clawd)
- **GitHub**：[github.com/openclaw/openclaw](https://github.com/openclaw/openclaw)

## 致谢

基于 [OpenClaw](https://github.com/openclaw/openclaw) 构建。

## License

MIT
