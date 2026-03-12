# 配置指南

> 安装脚本会交互式引导完成配置。这里是每个步骤的详细说明，方便提前准备。

## LLM 模型配置

安装时选一个默认 LLM 提供商：

### 选项 1：MiniMax M2.5（推荐，最快上手）

[MiniMax M2.5](https://www.minimax.io/news/minimax-m25) 面向编程和复杂任务优化，**价格便宜**。

1. 注册 [MiniMax 开放平台](https://platform.minimax.io/)
2. 创建 API Key
3. 安装时粘贴

> 配置：`minimax/MiniMax-M2.5`（通过 `https://api.minimax.io/anthropic` 兼容接口）

### 选项 2：Anthropic API Key（按量付费）

1. 创建 [Anthropic API Key](https://console.anthropic.com/settings/keys)（格式 `sk-ant-...`）
2. 安装时粘贴

> 配置：`anthropic/claude-sonnet-4-6` · [文档](https://docs.openclaw.ai/providers/anthropic)

### 选项 3：Anthropic OAuth（Claude Pro/Max 订阅）

1. 安装时选 3，脚本运行 `openclaw onboard`
2. 浏览器打开授权页面，登录
3. 复制 setup-token 粘贴到终端

> ⚠️ 订阅认证不支持 prompt caching，且政策可能变化。生产环境推荐 API Key。
>
> [文档](https://docs.openclaw.ai/concepts/oauth)

### 安装后切换模型

```bash
openclaw configure              # 交互式切换（选 "Model/auth"）

# 或直接修改
openclaw config set 'agents.defaults.model.primary' '"anthropic/claude-opus-4-6"' --json
openclaw gateway restart
```

完整提供商列表：[docs.openclaw.ai/providers/models](https://docs.openclaw.ai/providers/models)

---

## 聊天频道配置

至少配一个频道，AI 才能和你对话。

### Discord

**准备工作**（5 分钟）：

1. **创建 Bot**
   - [Discord Developer Portal](https://discord.com/developers/applications) → New Application
   - 左侧 **Bot** → 设置头像和名称

2. **开启 Intents**
   - Bot 页面 → Privileged Gateway Intents：
     - ✅ Message Content Intent（必须）
     - ✅ Server Members Intent（推荐）

3. **复制 Bot Token**
   - Bot 页面 → Reset Token → 复制保存

4. **加 Bot 到服务器**
   - OAuth2 → 勾选 `bot` + `applications.commands`
   - Permissions：View Channels / Send Messages / Read Message History / Embed Links / Attach Files / Add Reactions
   - 复制 URL → 浏览器打开 → 选服务器

5. **获取 ID**
   - Discord 设置 → 高级 → 开发者模式
   - 右键服务器 → Copy Server ID
   - 右键你自己 → Copy User ID

6. **允许 DM**
   - 右键服务器 → 隐私设置 → 允许服务器成员给你发私信

> [文档](https://docs.openclaw.ai/channels/discord)

### 飞书 (Feishu)

**准备工作**（5 分钟）：

1. [飞书开放平台](https://open.feishu.cn/app) → 创建企业自建应用（海外用 [Lark](https://open.larksuite.com/app)）
2. 复制 **App ID**（`cli_xxx`）和 **App Secret**
3. 权限管理 → 添加：`im:message` / `im:message:readonly` / `im:message.p2p_msg:readonly` / `im:chat.members:bot_access`
4. 应用能力 → 添加**机器人**
5. 版本管理 → 创建版本 → 申请发布 → 管理员审批

> [文档](https://docs.openclaw.ai/channels/feishu)

### 添加更多频道

```bash
openclaw channels add
```

支持：Discord / 飞书 / Telegram / WhatsApp / Slack / Signal / iMessage / IRC / Line / Matrix 等。[完整列表](https://docs.openclaw.ai/channels)

---

## Web 搜索（可选）

[Brave Search API](https://brave.com/search/api/) 让 AI 能搜索互联网。免费额度足够个人使用。

安装时粘贴 API Key 或回车跳过（稍后在配置里补）。

---

## 语音消息（自动）

安装自动配置 [whisper.cpp](https://github.com/ggerganov/whisper.cpp)：
- 本地运行，不调用外部 API
- 自动下载 tiny 模型（74MB）
- Apple Silicon / Intel 均支持
- 发语音就能识别，无需额外配置

---

## 可选 CLI 工具

安装脚本会自动安装以下工具，全部为 non-critical（失败不阻塞）：

| 工具 | 安装方式 | 解锁的能力 |
|------|----------|-----------|
| [himalaya](https://github.com/pimalaya/himalaya) | `brew install himalaya` | 邮件（IMAP/SMTP） |
| [gog](https://gogcli.sh) | `brew install gogcli` | Google Workspace（Gmail/Calendar/Drive） |
| [bird](https://www.npmjs.com/package/@steipete/bird) | `npm i -g @steipete/bird` | X/Twitter 读写搜索 |
| [blogwatcher](https://github.com/Hyaxia/blogwatcher) | `go install` (自动装 Go) | RSS/博客监控 |

> blogwatcher 需要 Go 运行时，安装脚本会自动处理 Go 安装、编译、PATH 配置和 LaunchAgent 可见性（软链到 `/opt/homebrew/bin/`）。

### 手动安装（已有环境）

如果之前安装时跳过了某些工具，重跑 setup.sh 即可自动补装（幂等设计）。

---

## Tailscale 远程访问

setup.sh 自动安装 [Tailscale](https://tailscale.com/) 并开启 SSH：

| 能力 | 说明 |
|------|------|
| SSH 远程控制 | `ssh user@<tailscale-ip>` |
| 自动组网 | 无需公网 IP / 端口转发 |

### 安装流程

1. `brew install tailscale`
2. 启动 tailscaled daemon（三级 fallback）
3. `tailscale login` — 浏览器授权（**需手动点击**）
4. 开启 macOS Remote Login — 自动尝试，失败则弹出系统设置

> ⚠️ macOS Ventura+ 限制了命令行开启 SSH。脚本会自动弹出系统设置页面，你只需打开 **远程登录** 开关。

### 常用命令

```bash
tailscale status              # 查看设备
tailscale ip -4               # 本机 IP
ssh user@<tailscale-ip>       # 远程连接
```

---

## 两个 Web 面板

### Control UI（对话）

| | |
|---|---|
| **地址** | `http://localhost:3456` |
| **用途** | 网页版聊天界面 |
| **登录** | 粘贴 Gateway Token |

![Control UI](https://img.mudui.me/docs/starter/a31203e8-94b5-4620-b82d-ff6db5a6898c-ed9b256c.png)

Token 忘了？
```bash
python3 -c "import json; c=json.load(open('$HOME/.openclaw/openclaw.json')); print(c['gateway']['auth']['token'])"
```

### Infra Dashboard（监控）

| | |
|---|---|
| **地址** | `http://localhost:3001` |
| **用途** | 服务状态、Settings 全量配置、工具版本、模型用量、Cron、Git Gates |
| **登录** | 用带 `?token=xxx` 链接（自动登录）或密码 `0000` |

![Dashboard](https://img.mudui.me/docs/starter/6f291f3e-7ccc-4e98-ab26-97f53906b95e-7dd435d8.png)

> 💡 把带 token 的链接保存为书签，以后直接进。

---

## LaunchAgent 后台服务

8 个 macOS LaunchAgent：

| 服务 | plist ID | 作用 |
|------|----------|------|
| Gateway | `ai.openclaw.gateway` | 核心进程 |
| Guardian | `ai.openclaw.guardian` | 自动恢复守护 |
| Dashboard | `com.openclaw.infra-dashboard` | 监控面板 |
| MCP Bridge | `com.openclaw.mcp-bridge` | MCP 服务 |
| 备份 | `ai.openclaw.backup` | Git 自动备份 |
| 日志轮转 | `ai.openclaw.log-rotate` | 日志清理 |
| Session 清理 | `ai.openclaw.sessions-prune-cron` | 过期 session |
| 防休眠 | `ai.openclaw.caffeinate` | 保持在线 |

PATH 由 setup.sh 动态生成。换 Node.js 版本后需重跑 setup.sh。

```bash
launchctl list | grep -E "openclaw|infra-dashboard"   # 状态
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway  # 重启
tail -f ~/.openclaw/logs/gateway.log                   # 日志
```

---

## 卸载

```bash
./setup.sh --uninstall
```

自动清理：8 个 LaunchAgent、Cron、Dashboard、配置、qmd、workspace（需确认）。

不自动删除的（可能被其他项目使用）：
```bash
npm uninstall -g openclaw @openai/codex @anthropic-ai/claude-code @google/gemini-cli @steipete/oracle mcporter clawhub playwright @upstash/context7-mcp
brew uninstall node git tailscale himalaya gogcli
rm -rf ~/.bun ~/.local/bin/uv ~/.local/bin/uvx
# 检查 ~/.zprofile 删除 OpenClaw 追加的行
```
