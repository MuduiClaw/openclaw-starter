# Claude Code — Anthropic 编码代理

## 为什么用它

Claude Code 是 Anthropic 出品的编码代理。和 Codex 一样，你用自然语言描述需求，它帮你写代码。但它们有不同的性格：

- **Codex** 更像一个高效执行者——给它明确任务，快速交付
- **Claude Code** 更像一个深度思考者——擅长推理复杂逻辑、协调多文件改动、理解上下文

两个都配好，按任务特点选用，或者让 OpenClaw 自动调度。

简单说：**多一个编码代理，多一种解题思路。**

---

## 你需要准备什么

📋 清单：
- [Anthropic 账号](https://console.anthropic.com)，或 Claude Max 订阅
- Node.js 22+
- OpenClaw 已安装

---

## 快速开始

### 第一步：安装 Claude Code

```bash
$ npm install -g @anthropic-ai/claude-code
```

> 💬 **npm 不熟？** 见 [从零开始](prerequisites.md#nodejs--很多工具的地基)。

验证：
```bash
$ claude --version
```

### 第二步：配置认证

**方式 A：API Key（推荐）**

```bash
$ export ANTHROPIC_API_KEY="你的Anthropic API Key"
```

**方式 B：OAuth 登录（Claude Max 订阅用户）**

```bash
$ claude auth login
```

跟提示走，浏览器授权。

💡 推荐用 1Password 管理 API Key（参考 [1Password 指南](1password.md)）。

### 第三步：跑一个简单任务

```bash
$ claude --print "写一个 Python 函数，输入一个列表，返回去重后的列表，保持原始顺序"
```

`--print` 是非交互模式，直接输出结果到终端。

---

## 核心用法

### 非交互模式（--print）

适合流水线、脚本、自动化场景。一次性任务，跑完就退出：

```bash
$ claude --print "读取 src/ 目录下所有 .ts 文件，列出所有导出的函数名"
```

### 交互模式

像对话一样和 Claude Code 协作：

```bash
$ claude
> 帮我看看这个项目的目录结构
> 这个 auth 模块的逻辑是什么？
> 重构它，把 JWT 验证抽成中间件
```

### 权限模式

Claude Code 默认会在做危险操作前问你确认。如果是自动化流水线，可以跳过：

```bash
$ claude --print --permission-mode bypassPermissions "修复所有 lint 错误"
```

⚠️ **`bypassPermissions` 意味着 Claude Code 可以自由读写文件和运行命令**。只在你信任任务内容时使用。

### 在特定目录工作

```bash
$ cd /path/to/your/project
$ claude --print "给这个 React 项目的所有组件加上 PropTypes 验证"
```

---

## 什么时候用 Claude Code，什么时候用 Codex

这不是非此即彼——两个工具互补：

| 场景 | 推荐 | 原因 |
|------|------|------|
| 需求明确、快速交付 | Codex | 执行速度快 |
| 复杂推理、多文件协调 | Claude Code | 深度思考更好 |
| 大规模重构 | Claude Code | 上下文理解更强 |
| 跑测试、验证代码 | Codex | full-auto 模式顺畅 |
| 自动化流水线 | Claude Code（--print） | 非交互输出干净 |
| 探索性任务 | Claude Code（交互） | 对话式更灵活 |

实践中，不必纠结。两个都配好，试几次就知道各自的脾气了。

---

## 最佳实践

💡 **`--print` 是自动化的好朋友**：
在 OpenClaw 里调度 Claude Code 时，用 `--print` 模式。它不需要 PTY，输出干净，方便解析。

💡 **AGENTS.md 很重要**：
和 Codex 一样，Claude Code 也会读项目的 `AGENTS.md`。写清楚项目规范，两个代理都受益。

💡 **MCP 集成**：
Claude Code 原生支持 MCP（Model Context Protocol）。如果你有 MCP server，Claude Code 可以直接调用。

💡 **Context 管理**：
大项目不要一次性让 Claude Code 看所有文件。指定范围："只看 src/auth/ 目录"比"修复这个项目"有效得多。

---

## 和 OpenClaw 的集成

### ACP 方式

和 Codex 一样，在 Discord 线程里可以启动 Claude Code 会话：

> "用 Claude Code 在这个线程里帮我设计一个数据库 schema"

### PTY 方式

OpenClaw 内部用 `--print` + `--permission-mode bypassPermissions` 运行 Claude Code，不需要 PTY。

### 和 Codex 配合

典型工作流：
1. Claude Code 做方案设计和复杂推理
2. Codex 做批量执行和测试
3. Oracle（Gemini）做最终审查

---

## 常见问题

**Q: Claude Code 和 Claude 网页版有什么区别？**
Claude Code 是独立的编码代理，能读写你的本地文件、运行命令。Claude 网页版只是对话界面。

**Q: API Key 和 OAuth 选哪个？**
API Key 更通用、更容易自动化。OAuth 如果你有 Claude Max 订阅，可以不用额外花 API 费用。

**Q: 和 Codex 冲突吗？**
完全不冲突。它们是独立的工具，可以同时安装、同时使用。OpenClaw 会根据任务路由到合适的代理。

**Q: 输出的代码我要手动 review 吗？**
强烈建议是。AI 生成的代码不等于正确的代码。`git diff` 看一遍，测试跑一遍。

---

## 进阶阅读

- [Anthropic Claude Code 文档](https://docs.anthropic.com/en/docs/claude-code)
- [OpenClaw ACP Agents 文档](https://docs.openclaw.ai/tools/acp-agents)
- [coding-agent Skill](https://clawhub.com)
