# 1Password — 密钥管理，一劳永逸

## 为什么用它

你会用到很多 API Key：OpenAI、Anthropic、Discord Bot Token、GitHub Token、Cloudflare……把这些密钥硬写在配置文件里，不安全也不好管。

1Password 让你在一个地方管理所有密钥，OpenClaw 通过 `op` CLI 安全地读取它们——密钥不落盘、不明文存储。

简单说：**一个保险箱管所有钥匙，AI 需要用的时候去拿，用完放回去。**

---

## 你需要准备什么

📋 清单：
- [1Password 账号](https://1password.com)（有免费试用，个人版约 $3/月）
- 1Password 桌面应用（macOS / Windows / Linux）
- OpenClaw 已安装

---

## 快速开始

### 第一步：安装 1Password CLI

macOS：
```bash
$ brew install 1password-cli
```

> 💬 **什么是 brew？** 见 [从零开始](prerequisites.md#homebrew--macos-的另一个应用商店)。

Linux：
```bash
# 参考 https://developer.1password.com/docs/cli/get-started/
$ curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | sudo tee /etc/apt/sources.list.d/1password.list
$ sudo apt update && sudo apt install 1password-cli
```

### 第二步：启用桌面集成（推荐）

这一步让 `op` CLI 通过桌面应用认证，不需要单独登录。

1. 打开 1Password 桌面应用
2. 进入 **设置 → 开发者**
3. 打开 **与 1Password CLI 集成**

验证：
```bash
$ op account list
```

如果能看到你的账号信息，就配好了。

### 第三步：存一个 API Key 试试

假设你要存 OpenAI 的 API Key：

1. 在 1Password 里新建一个 **API Credential** 类型的条目
2. 名字叫 `OpenAI API Key`
3. 把你的 Key 粘贴到 credential 字段
4. 保存

然后在终端读取：

```bash
$ op read "op://Personal/OpenAI API Key/credential"
# 应该输出你的 API Key
```

---

## 核心用法

### 读取密钥

```bash
$ op read "op://Vault名/条目名/字段名"
```

Vault 是 1Password 里的"保险箱"，你可以按用途分（Personal、Server、OpenClaw……）。

### 注入环境变量

不想让密钥出现在命令行里？用 `op run`：

```bash
$ op run --env-file=.env.tpl -- some-command
```

`.env.tpl` 文件里这样写：

```
OPENAI_API_KEY=op://Server/OpenAI API Key/credential
ANTHROPIC_API_KEY=op://Server/Anthropic API Key/credential
```

`op run` 会在运行命令时自动把 `op://...` 替换成真实值。

### 在 OpenClaw 中使用

创建一个环境文件供 OpenClaw 加载：

```bash
# ~/.config/openclaw/1password.env
export OPENAI_API_KEY=$(op read "op://Server/OpenAI API Key/credential")
export ANTHROPIC_API_KEY=$(op read "op://Server/Anthropic API Key/credential")
```

在需要时加载：

```bash
$ source ~/.config/openclaw/1password.env
```

---

## 最佳实践

💡 **Vault 分类**：
建一个专门的 Vault（比如叫 `Server` 或 `OpenClaw`），放所有 AI/服务相关的密钥。和个人密码分开。

💡 **命名规范**：
条目名用 `服务名 + 用途`，比如 `OpenAI API Key`、`Discord Bot Token`、`Cloudflare R2 Key`。以后找起来方便。

💡 **Service Account（高级）**：
如果 OpenClaw 跑在服务器上（无人值守），用 [1Password Service Account](https://developer.1password.com/docs/service-accounts/) 而不是个人账号。这样不需要桌面应用也能认证。

💡 **不要用 `sudo`**：
安装 `op` 用 brew 或 apt，不要 `sudo npm install`。

---

## 和 OpenClaw 的集成

### 在 OpenClaw 配置中引用

OpenClaw 支持在 `env.vars` 配置里引用环境变量。你可以：

1. 把密钥存在 1Password
2. 通过 `1password.env` 导出到环境变量
3. OpenClaw 的 `env.vars` 引用这些变量

这样密钥的生命周期是：1Password → 环境变量 → OpenClaw → 各工具。只有一个真相来源。

### 搭配其他工具

本指南里的每个工具几乎都会用到 API Key：

- Discord Bot Token → 存 1Password
- OpenAI API Key（给 Codex） → 存 1Password
- Anthropic API Key（给 Claude Code） → 存 1Password
- Gemini API Key（给 Oracle） → 存 1Password
- Cloudflare API Token → 存 1Password

**先配好 1Password，后面每个工具的密钥管理都轻松了。**

---

## 常见问题

**Q: `op read` 报 "not signed in"？**
确认 1Password 桌面应用在运行，且开启了 CLI 集成。或者手动 `op signin`。

**Q: 服务器上没有桌面应用怎么办？**
用 Service Account Token。创建后设置环境变量 `OP_SERVICE_ACCOUNT_TOKEN`，`op` 就能直接用了。

**Q: 可以用其他密钥管理工具吗？**
当然可以。OpenClaw 不强制 1Password——任何能把密钥注入环境变量的方式都行。1Password 只是我们推荐的方案，因为它在 CLI 集成上做得最好。

---

## 进阶阅读

- [1Password CLI 官方文档](https://developer.1password.com/docs/cli/)
- [1Password Service Accounts](https://developer.1password.com/docs/service-accounts/)
- [OpenClaw 1Password Skill](https://clawhub.com)
