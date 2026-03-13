# GitHub — 代码协作的基础设施

## 为什么用它

GitHub 是代码的家。OpenClaw 通过 `gh`（GitHub CLI）来操作仓库、提交代码、管理 Issue 和 PR。后面你要用 Codex 或 Claude Code 写代码，最终产出都会推到 GitHub 上。

简单说：**GitHub 是 AI 写完代码后，代码住的地方。**

---

## 你需要准备什么

📋 清单：
- 一个 [GitHub 账号](https://github.com/signup)（免费就够）
- OpenClaw 已安装

---

## 快速开始

### 第一步：安装 GitHub CLI

macOS：
```bash
$ brew install gh
```

> 💬 **什么是 brew？** Homebrew 是 macOS 的命令行软件管理器。如果没装过，见 [从零开始](prerequisites.md#homebrew--macos-的另一个应用商店)。

Linux：
```bash
$ curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null
$ sudo apt update
$ sudo apt install gh
```

### 第二步：登录

```bash
$ gh auth login
```

它会问你几个问题：
1. **GitHub.com 还是 Enterprise？** → 选 `GitHub.com`
2. **用什么协议？** → 推荐 `SSH`（更安全，免密码推送）
3. **怎么认证？** → 推荐 `Login with a web browser`

跟着提示走，浏览器会弹出让你确认授权。

### 第三步：验证

```bash
$ gh auth status
```

看到 `Logged in to github.com` 就行了。

### 第四步：配置 SSH Key（如果选了 SSH）

```bash
$ gh ssh-key list
```

如果为空，生成一个：

```bash
$ ssh-keygen -t ed25519 -C "你的邮箱"
$ gh ssh-key add ~/.ssh/id_ed25519.pub --title "OpenClaw Machine"
```

> 💬 **SSH key 是什么？** 一对"钥匙"——私钥留在你电脑上，公钥给 GitHub。以后推送代码时，GitHub 用公钥验证你身份，不需要输密码。

验证：
```bash
$ ssh -T git@github.com
# 应该看到 "Hi xxx! You've successfully authenticated"
```

---

## 核心用法

### 克隆仓库

```bash
$ gh repo clone owner/repo-name
```

### 创建 Issue

```bash
$ gh issue create --title "Bug: 登录页面白屏" --body "复现步骤：..."
```

### 查看 PR 状态

```bash
$ gh pr list
$ gh pr view 42
```

### 查看 CI 运行结果

```bash
$ gh run list
$ gh run view 12345 --log
```

### 用 API 做更复杂的查询

```bash
$ gh api repos/owner/repo/pulls --jq '.[].title'
```

---

## 最佳实践

💡 **SSH > HTTPS**：
SSH 不需要每次输密码，也更安全。如果你还在用 HTTPS + Personal Access Token，建议切换。

💡 **别用 `sudo`**：
安装 `gh` 用包管理器（brew / apt），不要 `sudo npm install -g`。

💡 **多账号场景**：
如果有多个 GitHub 账号（个人 + 公司），用 `gh auth login` 可以切换。或者配置 SSH config 区分 Host。

💡 **Token 权限最小化**：
如果必须用 Personal Access Token（PAT），只勾选你需要的权限（repo, read:org 通常够用）。

---

## 和 OpenClaw 的集成

OpenClaw 在 `exec` 工具里直接调 `gh` 命令，所以只要你在终端能用 `gh`，OpenClaw 就能用。

### gh-issues Skill

自动抓 GitHub Issue、分配 sub-agent 去修、开 PR。配合 Codex 或 Claude Code 形成闭环。

### coding-agent 工作流

Codex/Claude Code 写完代码后，通过 `git push` 推到 GitHub。CI 跑过了就算完成。

### 示例：让 OpenClaw 帮你查 PR

在 Discord 或任何聊天界面问：
> "帮我看看 my-project 仓库有没有还没合的 PR"

OpenClaw 会调 `gh pr list` 并给你结果。

---

## 常见问题

**Q: `gh auth login` 报网络错误？**
如果你在用代理，检查 `HTTP_PROXY` 环境变量是否配对了。有些代理需要配 `NO_PROXY`。

**Q: push 的时候提示权限不够？**
检查 `gh auth status` 确认登录状态。如果用 SSH，确认 key 在 `gh ssh-key list` 里。

**Q: 可以用 GitHub Enterprise 吗？**
可以。`gh auth login --hostname your-enterprise.com`。

---

## 进阶阅读

- [GitHub CLI 官方文档](https://cli.github.com/manual/)
- [OpenClaw 官方文档 - GitHub Copilot Provider](https://docs.openclaw.ai/providers/github-copilot)
- [gh-issues Skill 说明](https://clawhub.com)
