# Discord — 让 OpenClaw 住进你的聊天服务器

## 为什么用它

Discord 是和 OpenClaw 对话最自然的方式之一。你在 Discord 里发消息，OpenClaw 就能回复你——支持私聊、群聊、线程、按钮、投票，甚至可以在线程里启动编码代理帮你写代码。

简单说：**你在哪聊天，AI 就在哪工作。**

---

## 你需要准备什么

📋 清单：
- 一个 Discord 账号
- 一个你有管理员权限的 Discord 服务器（没有就新建一个，免费的）
- OpenClaw 已安装并且 Gateway 在运行

---

## 快速开始

### 第一步：创建 Discord Bot

1. 打开 [Discord Developer Portal](https://discord.com/developers/applications)
2. 点击 **New Application**，给它起个名字（比如 `My OpenClaw`）
3. 左侧菜单进入 **Bot** 页面
4. 点击 **Reset Token**，复制这个 Token

   ⚠️ **这个 Token 只显示一次**，马上保存好。如果用 1Password，现在就存进去。

5. 在 Bot 页面往下滚，打开这些开关：
   - ✅ **Message Content Intent**（必须，否则收不到消息内容）
   - ✅ **Server Members Intent**（推荐）
   - ✅ **Presence Intent**（可选）

### 第二步：邀请 Bot 到你的服务器

1. 左侧菜单进入 **OAuth2** 页面
2. 在 **OAuth2 URL Generator** 里：
   - Scopes 勾选 `bot`
   - Bot Permissions 勾选：
     - Send Messages
     - Read Message History
     - Add Reactions
     - Use Slash Commands
     - Manage Threads（如果要用线程功能）
     - Attach Files（如果要发文件/图片）
3. 复制生成的 URL，在浏览器打开
4. 选择你的服务器，授权

### 第三步：在 OpenClaw 里配置

最简单的方式，用向导：

```bash
$ openclaw configure --section channels
```

选择 Discord，粘贴你的 Bot Token。

或者手动配置。在终端运行：

```bash
$ openclaw gateway config.patch '{
  "channels": {
    "discord": {
      "enabled": true,
      "token": "你的Bot Token"
    }
  }
}'
```

> 💬 **看不懂这段命令？** `config.patch` 后面的 `{...}` 是 JSON 格式的配置。你只需要把 `你的Bot Token` 替换成真实的 Token，其他照抄就行。JSON 格式说明见 [从零开始](prerequisites.md#json--配置文件的语言)。

### 第四步：验证

在 Discord 里给 Bot 发条私聊消息，比如 `你好`。如果收到回复，恭喜你配好了 🎉

---

## 核心用法

### 私聊 vs 群聊

- **私聊**：直接给 Bot 发消息就行，默认就能收到
- **群聊**：Bot 需要被邀请到服务器的频道里，并且需要配置 allowlist

### 配置群聊权限

OpenClaw 默认不会回复所有群聊消息（安全考虑）。你需要告诉它哪些服务器/频道可以回复。

💡 **推荐做法**：按服务器（Guild）粒度放行，而不是逐个频道配置。

```bash
$ openclaw gateway config.patch '{
  "channels": {
    "discord": {
      "allowlist": {
        "guilds": ["你的服务器ID"]
      }
    }
  }
}'
```

怎么拿服务器 ID？在 Discord 里打开 **设置 → 高级 → 开发者模式**，然后右键服务器图标 → **复制服务器 ID**。

### 线程

OpenClaw 支持 Discord 线程。你可以：
- 让 AI 创建新线程来讨论某个话题
- 在线程里启动 Codex / Claude Code 编码会话（ACP 绑定）

### 消息格式

Discord 支持 Markdown，但有些限制：
- ⚠️ **不要用表格**——Discord 渲染表格很丑，用列表代替
- 链接用 `<URL>` 包裹可以防止自动预览

---

## 最佳实践

💡 **安全第一**：
- Bot Token 绝对不要提交到 Git 仓库
- 用 1Password 管理 Token（参考 [1Password 指南](1password.md)）
- 不需要的频道不要放行

💡 **群聊建议**：
- 按 Guild 粒度配 allowlist，不要逐频道加，维护成本太高
- 多人服务器里考虑用 `groupPolicy` 控制 AI 什么时候回复

💡 **性能**：
- 如果有多个频道高频消息，OpenClaw 会排队处理
- 大文件/图片发送可能需要几秒

---

## 和 OpenClaw 的集成

### Cron 推送

可以把定时任务的产出推送到指定 Discord 频道：

```json5
// openclaw.json cron 配置片段
{
  "deliveryQueue": {
    "targets": ["channel:你的频道ID"]
  }
}
```

⚠️ target 必须带 `channel:` 前缀。

### Reactions

OpenClaw 可以给消息添加 emoji 反应。在配置里启用：

```json5
{
  "channels": {
    "discord": {
      "reactions": true
    }
  }
}
```

### ACP 线程绑定

在 Discord 线程里可以启动编码代理（Codex、Claude Code 等），代理的所有输出会留在线程里。详见 [Codex 指南](codex.md) 和 [Claude Code 指南](claude-code.md)。

---

## 常见问题

**Q: Bot 在线但不回复消息？**
检查三件事：① Bot 有没有 Message Content Intent ② 频道/服务器在不在 allowlist ③ `openclaw gateway status` 确认 Gateway 在运行

**Q: 怎么让 Bot 只在被 @ 时回复？**
配置 `groupPolicy`。在 `openclaw.json` 的 discord 区块里设置群聊行为策略。

**Q: 可以同时接多个 Discord 服务器吗？**
可以。一个 Bot 可以加入多个服务器，在 allowlist 里放多个 Guild ID 就行。

**Q: 消息有长度限制吗？**
Discord 单条消息上限 2000 字符。OpenClaw 会自动把长消息分片发送。

---

## 进阶阅读

- [OpenClaw 官方文档 - Discord](https://docs.openclaw.ai/channels/discord)
- [Discord Developer Portal](https://discord.com/developers/docs)
- [Discord 社区](https://discord.com/invite/clawd)
