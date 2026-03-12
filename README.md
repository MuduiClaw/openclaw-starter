# 🦞 OpenClaw Starter Kit

> 经过真实场景验证的 AI 合伙人系统——10 分钟在你的 Mac 上跑起来。

一条命令，全自动安装。不需要任何技术背景，不需要手动配环境。

## 快速开始

一行命令，全新 Mac 也能跑（不需要提前装 git 或任何工具）：

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MuduiClaw/openclaw-starter/main/bootstrap.sh)"
```

> 全新 Mac 会自动安装 Xcode Command Line Tools（首次可能需要几分钟），之后自动进入安装流程。

<details>
<summary>或者手动 clone（需要已装好 git）</summary>

```bash
git clone https://github.com/MuduiClaw/openclaw-starter.git
cd openclaw-starter
./setup.sh
```
</details>

脚本会引导你完成所有配置。完成后打开 `http://localhost:3001` 查看监控面板。

## 你会得到什么

| 能力 | 说明 |
|------|------|
| **The Loop 方法论** | 实战检验的 Agent 工作循环：想清楚 → 执行 → 验证 → 交付 → 复盘 |
| **Cron 定时任务** | 内置调度引擎，按需配置晨报、复盘、健康监控等自动化任务 |
| **23 个 Skills** | 设计、开发、研究、文档、测试、视频——模块化的 AI 能力 |
| **Coding Agents** | Codex + Claude Code + Gemini CLI 作为 AI 的执行团队 |
| **语音消息** | whisper.cpp 本地语音转文字，无需 API Key |
| **记忆系统（qmd）** | 语义搜索，让 AI 记住上下文和决策 |
| **infra-dashboard** | `localhost:3001` 实时监控面板（服务状态 / 工具 / LaunchAgent / Cron） |
| **MCP Bridge** | context7 + deepwiki，实时文档查询 |
| **Guardian Agent** | 3 层守护：进程检查 → 自动修复 → 自动重启（无需人工审批） |
| **27 个自动化脚本** | 升级、备份、日志轮转、Fleet 检查、健康巡检、Git 质量门禁等 |

## 系统要求

- **macOS** Ventura (13.0) 或更高（Apple Silicon / Intel 均可）
- **Node.js v25+**（安装脚本自动安装，无需手动准备）
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

[MiniMax M2.5](https://www.minimax.io/news/minimax-m25) 是面向编程和复杂任务优化的模型，**价格便宜**。

1. 去 [MiniMax 开放平台](https://platform.minimax.io/) 注册账号
2. 进入 API Keys 页面创建 key
3. 安装时粘贴 key

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

### Web 搜索（可选）

安装脚本会询问是否配置 [Brave Search API](https://brave.com/search/api/)，让 AI 能搜索互联网。

1. 去 [Brave Search API](https://brave.com/search/api/) 注册（免费额度足够个人使用）
2. 创建 API Key
3. 安装时粘贴（或回车跳过，稍后在配置里补）

> 不配也能用，AI 只是没法主动搜网页。

---

### 语音消息（自动）

安装脚本会自动安装 [whisper.cpp](https://github.com/ggerganov/whisper.cpp)，支持在 Discord / 飞书中发送语音消息给 AI。

- 本地运行，不调用外部 API
- 自动下载 tiny 模型（74MB）
- Apple Silicon / Intel 均支持

> 安装后无需额外配置，发语音就能识别。

---

## 安装过程

```
🦞 OpenClaw Starter Kit — Bootstrap
     Xcode Command Line Tools 已安装 ✓
     代码就绪: ~/openclaw-starter ✓

🦞 OpenClaw Starter Kit v1.3.0

[0/3] 环境检查 ━━━━━━━━━━━━━━━━━━━━
     macOS (arm64) ✓  15.7.3 ✓
     Disk: 402GB free ✓  RAM: 18GB ✓

[1/3] 依赖安装
     Xcode CLT ✓  Homebrew ✓  Node.js v25 ✓  Bun ✓  uv ✓
     OpenClaw ✓  Codex ✓  Claude Code ✓  Gemini CLI ✓
     qmd ✓  mcporter ✓  clawhub ✓  oracle ✓  whisper.cpp ✓

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

     Brave Search API Key（可选，回车跳过）: _

[3/3] 启动
     Gateway ✓  Dashboard ✓  MCP Bridge ✓  Guardian ✓
     LaunchAgents: 8/8 ✓

🎉 你的 AI 合伙人已就绪。
   Control UI:  http://localhost:3456  (跟 AI 对话)
   Dashboard:   http://localhost:3001/?token=xxx  (基建监控)
                ↑ 保存到浏览器书签，自动登录
   ⚡ Gateway Token: xxx
      (在 Control UI 里粘贴此 token 即可开始对话)
   下一步:     在 Discord/飞书跟你的 AI 说句话试试
```

## 两个面板

安装完成后，你有两个本地 Web 面板：

### Control UI — 跟 AI 对话

| | |
|---|---|
| **地址** | `http://localhost:3456` |
| **用途** | 网页版聊天界面，直接跟 AI 对话 |
| **登录** | 粘贴安装完成时显示的 **Gateway Token** |

打开页面后，在「网关令牌」框里粘贴 token，点「连接」即可开始对话。

![Control UI — 粘贴 Gateway Token 后点连接](https://img.mudui.me/docs/starter/a31203e8-94b5-4620-b82d-ff6db5a6898c-ed9b256c.png)

> Token 忘了？运行：
> ```bash
> python3 -c "import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); print(c['gateway']['auth']['token'])"
> ```

### Infra Dashboard — 基建监控

| | |
|---|---|
| **地址** | `http://localhost:3001` |
| **用途** | 实时监控：服务状态、工具版本、模型用量、Cron 任务、LaunchAgent 健康 |
| **登录** | 用安装完成时终端显示的带 `?token=xxx` 链接打开（自动登录），或手动输入密码 `0000` |

![Infra Dashboard — 登录页面](https://img.mudui.me/docs/starter/6f291f3e-7ccc-4e98-ab26-97f53906b95e-7dd435d8.png)

> 💡 **把带 token 的链接保存为浏览器书签**，以后打开直接进，不用每次输密码。

### 更新面板

infra-dashboard 不会自动更新。当有新版本发布时：

```bash
cd ~/openclaw-starter
git pull
./setup.sh --update-dashboard
```

一条命令完成：备份旧版 → 下载最新 → 重编译 native addon → 重启服务。

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

### 完全卸载

```bash
./setup.sh --uninstall
```

卸载脚本**自动清理**：
- 8 个 LaunchAgent（Gateway、Guardian、备份、日志轮转等）
- Cron 定时任务
- infra-dashboard（`~/projects/infra-dashboard/`，需确认）
- Dashboard 配置（`~/.config/openclaw/`）
- qmd 语义搜索（`~/.local/lib/qmd/` + `~/.local/bin/qmd`）
- Workspace（`~/clawd/`，需确认）
- State 目录（`~/.openclaw/`，需确认）

卸载脚本**不会自动删除**（可能被其他项目使用）：

```bash
# npm 全局包
npm uninstall -g openclaw @openai/codex @anthropic-ai/claude-code \
  @google/gemini-cli @steipete/oracle mcporter clawhub playwright \
  @upstash/context7-mcp

# Homebrew 包
brew uninstall node git tailscale

# Bun 运行时
rm -rf ~/.bun

# uv 运行时
rm -rf ~/.local/bin/uv ~/.local/bin/uvx

# Shell PATH（检查 ~/.zprofile 删除 OpenClaw 追加的行）
```

### 安装选项

```bash
./setup.sh                      # 标准安装
./setup.sh --update-dashboard   # 更新 infra-dashboard 到最新版
./setup.sh --no-launchagents    # 不安装后台服务
./setup.sh --skip-dashboard     # 不安装监控面板
./setup.sh --no-tailscale       # 跳过 Tailscale 远程访问
./setup.sh --no-caffeinate      # 不配置防休眠
./setup.sh --uninstall          # 完全卸载
```

## 远程访问 (Tailscale)

setup.sh 会自动安装 [Tailscale](https://tailscale.com/) 并开启 Tailscale SSH，实现跨网络远程控制。

### 安装后你得到什么

| 能力 | 说明 |
|------|------|
| **SSH 远程控制** | 从任何 Tailnet 设备 `ssh user@<tailscale-ip>` |
| **Tailscale SSH** | 内置 SSH，不依赖 macOS 的 Remote Login |
| **自动组网** | 设备加入 Tailnet 后互通，无需公网 IP / 端口转发 |

### 安装流程（setup.sh 自动完成）

1. `brew install tailscale` — 安装 CLI
2. 启动 tailscaled daemon（三级 fallback：brew services → install-system-daemon → 手动启动）
3. `tailscale login` — 自动打开浏览器授权（**需手动点击确认**）
4. 开启 macOS 远程登录 — 自动尝试，失败则**自动打开系统设置页面**，只需点一下开关

### ⚠️ macOS SSH (Remote Login) 需手动开启

macOS Ventura+ 限制了命令行开启 SSH 的权限。setup.sh 会自动尝试，如果失败会：

1. **自动弹出**系统设置的共享页面
2. 你只需打开 **远程登录 (Remote Login)** 开关
3. 脚本自动检测到开启后继续

> 注意：Homebrew 安装的是 Tailscale CLI 版本，SSH 服务依赖 macOS 原生远程登录（非 Tailscale SSH App 功能）。

### 授权说明

`tailscale login` 会打开浏览器，需要登录 Tailscale 账号。**被控机器必须登录控制方的 Tailscale 账号**，才能在同一个 Tailnet 内互通。

### 常用命令

```bash
tailscale status              # 查看 Tailnet 设备状态
tailscale ip -4               # 查看本机 Tailscale IP
ssh user@<tailscale-ip>       # 远程连接
tailscale set --ssh           # 开启 Tailscale SSH
```

## 安全设计

- 所有服务绑定 `127.0.0.1`（不暴露到局域网）
- API Key 交互式输入，不硬编码在脚本中
- 敏感文件创建时使用 `umask 077`（无权限窗口泄露）
- Gateway Token 自动生成并写入配置（重跑 setup 不覆盖）
- GitHub Token 通过 `http.extraheader` 传递，不写入 `.git/config`
- 配置生成使用 python3 + 环境变量，无 shell 注入风险
- Guardian Agent：`shell=False` + `shlex.split`
- 卸载路径安全检查（拒绝删除 `/`、`$HOME` 等危险路径）

## 架构

```
你 ←→ Discord/飞书 ←→ OpenClaw Gateway (:3456)
                          ├── Agent (LLM + Skills + Memory)
                          ├── Cron Engine (按需配置定时任务)
                          └── MCP Bridge (:9100)

监控面板 → infra-dashboard (:3001)
守护进程 → Guardian Agent (自动恢复 + 自动重启)
后台服务 → 8 个 LaunchAgent (备份/日志/清理/防休眠...)
```

## 项目结构

```
openclaw-starter/
├── bootstrap.sh             # 一行 curl 入口（处理 Xcode CLT + clone）
├── setup.sh                 # 主安装脚本（bootstrap 自动调用）
├── CHANGELOG.md             # 版本变更记录
├── workspace/               # → 安装到 ~/clawd
│   ├── AGENTS.md            # The Loop 方法论
│   ├── *.md.example         # 个性化文件模板
│   ├── skills/              # 23 个 skills
│   ├── scripts/             # 27 个自动化脚本
│   ├── prompts/             # cron 模板 + 同步工具
│   ├── eval/                # 质量评估框架
│   └── mcp-bridge/          # MCP 服务
├── config/                  # 配置模板
├── services/                # LaunchAgent 模板 + 服务启动脚本
└── docs/                    # 文档
```

## 注意事项

### 网络环境
- **国内用户**：安装脚本会自动检测系统代理。如果 GitHub 不通，按提示配置清华镜像
- **Dashboard 下载超时**：弱网环境下 infra-dashboard 下载有 120 秒超时，失败后可手动重试

### 重复运行 setup.sh
- 已有配置会询问是否覆盖，不会静默丢失
- Gateway Token 会自动保留（不会因重配而失效）
- 用户在 `~/clawd/skills/` 等目录下新增的文件不会被删除

### LaunchAgent 后台服务

setup.sh 会创建 8 个 macOS LaunchAgent（位于 `~/Library/LaunchAgents/`）：

| 服务 | plist ID | 作用 |
|------|----------|------|
| Gateway | `ai.openclaw.gateway` | OpenClaw 核心进程 |
| Guardian | `ai.openclaw.guardian` | 3 层自动恢复守护 |
| Dashboard | `com.openclaw.infra-dashboard` | 监控面板 |
| MCP Bridge | `com.openclaw.mcp-bridge` | MCP 服务 |
| 备份 | `ai.openclaw.backup` | workspace git 自动备份 |
| 日志轮转 | `ai.openclaw.log-rotate` | 日志文件清理 |
| Session 清理 | `ai.openclaw.sessions-prune-cron` | 过期 session 清理 |
| 防休眠 | `ai.openclaw.caffeinate` | 保持 Mac 在线 |

**PATH 注入机制**：每个 plist 的 `EnvironmentVariables.PATH` 由 setup.sh 动态生成，包含 Node.js、bun、`~/.local/bin` 等路径。如果更换了 Node.js 版本，需要重跑 `setup.sh` 或手动更新 plist。

**常见操作**：
```bash
# 查看服务状态
launchctl list | grep -E "openclaw|infra-dashboard"

# 重启某个服务
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway

# 查看服务日志
tail -f ~/.openclaw/logs/gateway.log
tail -f ~/.openclaw/logs/guardian.log
```

### 访问面板
- 详见上方 [两个面板](#两个面板) 章节
- 如果看到"链接已失效"提示，说明书签里的 token 过期了，用最新密码重新登录即可

### Intel Mac
- 完整支持 x86_64 架构，qmd 等工具安装在 `~/.local/` 目录下，不需要 sudo

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
