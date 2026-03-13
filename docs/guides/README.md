# 工具深度指南

> 安装配置看 [SETUP-GUIDE.md](../SETUP-GUIDE.md)。
> 这套指南聚焦**为什么用、日常怎么用、最佳实践和进阶技巧**。

## 适合谁

- 已经跑完 `setup.sh`，基础环境就绪
- 想深入了解每个工具的能力和最佳用法
- 不需要是程序员，跟着做就行

## 全局前置条件

> 如果你通过 `setup.sh` 安装，以下依赖已自动就绪。

- **Node.js 22+**：`node --version` 检查
- **Git**：`git --version` 检查

## 阅读顺序

按**你最可能先用到的**排序。不必全看，按需取用。

### 🔰 第零篇 — 如果你不是程序员，先看这个

| 指南 | 一句话说明 | 时间 |
|------|-----------|------|
| [从零开始](prerequisites.md) | 终端怎么用、npm 是什么、API Key 是什么 | 10 分钟 |

### 🟢 基础篇 — 先连上，先用起来

| 指南 | 一句话说明 | 时间 |
|------|-----------|------|
| [Discord](discord.md) | 群聊权限、线程、ACP 绑定、消息格式 | 15 分钟 |
| [GitHub](github.md) | gh CLI 核心用法、SSH 配置、CI 查看 | 10 分钟 |
| [1Password](1password.md) | op CLI 密钥注入、环境变量管理 | 15 分钟 |
| [Tailscale](tailscale.md) | 远程访问 Gateway、MagicDNS、安全配置 | 10 分钟 |

### 🟡 进阶篇 — 释放编码和自动化能力

| 指南 | 一句话说明 | 时间 |
|------|-----------|------|
| [Codex](codex.md) | full-auto 模式、ACP 调度、验收约束 | 20 分钟 |
| [Claude Code](claude-code.md) | --print 模式、和 Codex 的分工、MCP 集成 | 20 分钟 |
| [Browser](browser.md) | 隔离 profile、截图验证、headless 模式 | 15 分钟 |

### 🔴 扩展篇 — 玩出花样

| 指南 | 一句话说明 | 时间 |
|------|-----------|------|
| [Oracle](oracle.md) | Gemini 审查、编写-审查闭环、三轮熔断 | 15 分钟 |
| [MCP Bridge](mcp-bridge.md) | stdio/HTTP 模式、mcporter 管理、安全隔离 | 20 分钟 |
| [Cloudflare](cloudflare.md) | Pages 自动部署、R2 图床、自定义域名 | 15 分钟 |
| [Web Search](web-search.md) | Brave/Perplexity/Tavily 对比与配置 | 10 分钟 |

## 约定

- 📋 表示需要你准备/记录的东西
- 💡 表示最佳实践提示
- ⚠️ 表示常见坑，别踩
- `$` 开头表示在终端里输入的命令
- 💬 注释框链接到[第零篇](prerequisites.md)解释术语
