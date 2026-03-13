# Oracle — 用 Gemini 做独立审查

## 为什么用它

你让 Codex 写了代码，让 Claude Code 做了重构——但谁来检查它们的产出？

Oracle 是一个**独立的审查角色**，用 Google 的 Gemini 模型来审查代码、spec、内容。关键在于"独立"——它不是写代码的那个 AI，所以不会为自己的代码辩护。

就像公司里代码要别人 review 一样——写的人和审的人不能是同一个。

简单说：**AI 写完，另一个 AI 审。**

---

## 你需要准备什么

📋 清单：
- [Google AI Studio 账号](https://aistudio.google.com)
- Gemini API Key（在 AI Studio 里创建）
- OpenClaw 已安装

---

## 快速开始

### 第一步：获取 Gemini API Key

1. 登录 [Google AI Studio](https://aistudio.google.com)
2. 点击 **Get API Key** → **Create API Key**
3. 复制 Key

💡 存到 1Password（参考 [1Password 指南](1password.md)）。

### 第二步：安装 Gemini CLI

```bash
$ npm install -g @anthropic-ai/gemini-cli
# 或者根据 Oracle 工具的实际安装方式
```

设置环境变量：

```bash
$ export GEMINI_API_KEY="你的Gemini API Key"
```

💡 更推荐的方式是把它加到 1Password 环境文件里（参考 [1Password 指南](1password.md)）：

```bash
# 追加到 ~/.config/openclaw/1password.env
export GEMINI_API_KEY=$(op read "op://Server/Gemini API Key/credential")
```

### 第三步：跑一个审查

准备一段代码或一个文件：

```bash
$ oracle-gemini review src/auth/login.ts
```

或者审查一个 spec：

```bash
$ oracle-gemini review docs/plans/my-feature-spec.md
```

---

## 核心用法

### 代码审查

```bash
$ oracle-gemini review src/main.ts
```

Oracle 会指出：
- 逻辑错误
- 安全隐患
- 性能问题
- 代码风格不一致

### Spec 审查

在动手写代码之前，先让 Oracle 审一遍设计方案：

```bash
$ oracle-gemini review tasks/my-feature-spec.md
```

比代码审查更高效——在设计阶段发现方向错误，比写完代码再推翻便宜 10 倍。

### 内容审查

不只是代码——文章、文档、翻译也可以审：

```bash
$ oracle-gemini review article-draft.md --mode content
```

---

## 最佳实践

💡 **三轮熔断**：
对同一个文件，最多审查 3 轮。如果 3 轮还过不了，说明需要的不是 review 而是重写。避免陷入无限修改循环。

💡 **让写和审分开**：
这是 Oracle 存在的核心价值。Codex/Claude Code 写 → Oracle 审 → 发现问题打回 → 修完再审。不要让同一个 AI 自审——它倾向于认为自己是对的。

💡 **先审 spec 再审代码**：
方向对了，代码再烂都能改。方向错了，代码写得再好也是浪费。

💡 **模型选择**：
Oracle 使用 Gemini 3.1 Pro，特点是长上下文窗口。适合审查大型文件和完整项目结构。

---

## 和 OpenClaw 的集成

### 完整的编写-审查闭环

```
需求 → 写 Spec → Oracle 审 Spec → 通过 → Codex 写代码 → Oracle 审代码 → 通过 → 部署
```

### 使用脚本封装

OpenClaw 提供了 `scripts/oracle.sh` 封装脚本，简化调用：

```bash
$ bash scripts/oracle.sh my-spec.md
```

### 搭配 Coding Agent

在 `coding-agent` skill 的工作流里，Oracle 是验收环节的关键角色——写完代码后自动触发审查。

---

## 常见问题

**Q: Oracle 和直接用 Gemini 有什么区别？**
Oracle 是一个**角色定位**——专门做审查，有预设的审查 prompt 和流程。你当然可以直接用 Gemini，但 Oracle 帮你定义了"审查者"的行为模式。

**Q: 审查结果不准怎么办？**
AI 审查不是银弹。它能发现很多问题，但也可能误判。把它当作第一道过滤器，最终判断权在你手里。

**Q: 免费额度够用吗？**
Google AI Studio 有免费 tier。日常审查通常够用。高频场景需要付费。

**Q: 可以用其他模型做审查吗？**
当然可以。Oracle 的核心是"独立审查"的理念，不绑死特定模型。你可以配置成用 Claude 或 GPT 做审查——关键是审的人不能是写的人。

---

## 进阶阅读

- [Google AI Studio](https://aistudio.google.com)
- [Gemini API 文档](https://ai.google.dev/docs)
- [OpenClaw Oracle 平台文档](https://docs.openclaw.ai/platforms/oracle)
