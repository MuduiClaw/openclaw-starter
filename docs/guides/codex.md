# Codex — OpenAI 编码代理

## 为什么用它

Codex 是 OpenAI 出品的编码代理。你用自然语言描述你想做什么，它帮你写代码、改代码、跑测试。

不是补全几行代码那种——Codex 能：
- 从零创建一个项目
- 重构几十个文件
- 看完报错日志自己修 bug
- 写测试、跑测试、确认通过

简单说：**你描述需求，它交付代码。**

---

## 你需要准备什么

📋 清单：
- [OpenAI 账号](https://platform.openai.com)，确保有 API 额度（Codex 使用的模型需要付费）
- Node.js 22+
- OpenClaw 已安装

---

## 快速开始

### 第一步：安装 Codex CLI

```bash
$ npm install -g @openai/codex
```

> 💬 **npm 是什么？** Node.js 的"应用商店"，`-g` 表示全局安装。需要先装 Node.js，见 [从零开始](prerequisites.md#nodejs--很多工具的地基)。

验证：
```bash
$ codex --version
```

### 第二步：配置 API Key

```bash
$ export OPENAI_API_KEY="你的OpenAI API Key"
```

> 💬 **这行什么意思？** `export` 设置一个"环境变量"，让 Codex 知道去哪找你的 API Key。关掉终端就失效了。详见 [从零开始](prerequisites.md#环境变量--告诉程序去哪里找密钥)。

💡 推荐存到 1Password 而不是写死在 shell 配置里（参考 [1Password 指南](1password.md)）。

### 第三步：跑一个简单任务

```bash
$ codex exec "创建一个 hello world 的 Python 脚本"
```

如果它创建了一个 Python 文件并且能跑，恭喜你配好了 🎉

---

## 核心用法

### 自主模式（Full Auto）

让 Codex 完全自主地完成任务，不需要你中途确认：

```bash
$ codex --full-auto exec "给这个 Express 项目加一个健康检查接口 /health，写测试，确保测试通过"
```

适合：需求明确、风险可控的任务。

### 交互模式

默认模式。Codex 会在关键步骤暂停，等你确认：

```bash
$ codex "重构这个项目的数据库层，从 MySQL 切到 PostgreSQL"
```

适合：大范围重构、不确定最终方案的探索性任务。

### 在特定目录工作

```bash
$ cd /path/to/your/project
$ codex exec "修复所有 TypeScript 编译错误"
```

Codex 会读取当前目录的代码上下文。

### 通过 OpenClaw 调度

在 Discord 或任何聊天界面里说：

> "用 Codex 帮我在 my-project 仓库里加一个用户注册功能"

OpenClaw 会通过 ACP（Agent Client Protocol）启动 Codex 会话。

---

## 最佳实践

💡 **prompt 要具体**：
不要说"改善这个项目"。要说"给 `/api/users` 接口加分页，每页 20 条，返回 total count"。越具体，结果越好。

💡 **给上下文**：
如果项目有 `AGENTS.md` 或 `README.md`，Codex 会自动读取。在里面写清楚项目的技术栈、目录结构、代码规范——这是你和 AI 的契约。

💡 **验收要独立验证**：
Codex 说"完成了"不代表真完成。自己跑一遍测试、看一遍 diff。

⚠️ **验收任务的特殊约束**：
如果你用 Codex 做验收（review 代码），prompt 里要明确说**"只验证，不改代码，发现问题标 ❌"**。否则 Codex 会"顺手修"引入新 bug。

💡 **模型选择**：
Codex 默认使用 `gpt-5.4`。这是目前编码能力最强的模型，建议保持默认。

💡 **Token 用量**：
大型任务会消耗较多 token。留意 OpenAI 账单，设置 usage limit 防止超支。

---

## 和 OpenClaw 的集成

### ACP 方式（推荐给聊天场景）

在 Discord 线程里启动 Codex 会话：

> "在这个线程里启动 Codex，帮我重构 auth 模块"

OpenClaw 会创建一个 ACP 会话，Codex 的所有输出留在线程里。你可以持续对话、补充需求。

### PTY 方式（推荐给后台任务）

OpenClaw 在后台用 PTY 运行 Codex：

```bash
# OpenClaw 内部执行方式（你不需要手动跑）
$ codex --full-auto exec "你的任务描述"
```

### coding-agent Skill

OpenClaw 有内置的 `coding-agent` skill，自动处理：
- 项目目录的 AGENTS.md 注入
- spawn 前的门禁检查
- 完成后的 diff review
- 测试通过后的 git push

### 搭配 Oracle 审查

代码写完 → Oracle（Gemini）review → 发现问题 → 返工或通过。形成编写 + 审查的闭环。详见 [Oracle 指南](oracle.md)。

---

## 常见问题

**Q: Codex 和 ChatGPT 里的代码能力有什么区别？**
Codex CLI 是独立的编码代理，能直接读写你本地的文件、运行命令、跑测试。ChatGPT 只是对话框里生成代码片段。

**Q: API Key 报错 401？**
检查 Key 是否有效、账户是否有余额。去 [platform.openai.com](https://platform.openai.com) 查看。

**Q: 可以限制 Codex 能访问的目录吗？**
可以。通过 sandbox 配置限制工作目录。ACP 模式下默认隔离。

**Q: Codex 写的代码质量怎么样？**
取决于 prompt 质量和项目上下文。有好的 AGENTS.md + 测试覆盖 + review 流程，产出质量很高。没有这些——看运气。

---

## 进阶阅读

- [OpenAI Codex 官方文档](https://platform.openai.com/docs)
- [OpenClaw ACP Agents 文档](https://docs.openclaw.ai/tools/acp-agents)
- [coding-agent Skill](https://clawhub.com)
