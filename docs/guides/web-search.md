# Web Search — 给 AI 联网搜索的能力

## 为什么用它

默认情况下，AI 只知道训练数据里的东西。但你经常需要它：

- 搜索最新的技术文档
- 查询今天的新闻
- 找某个 API 的最新用法
- 研究竞品信息

配置 Web Search 后，OpenClaw 可以像你一样上网搜索——然后把结果整理成你需要的格式。

简单说：**让 AI 能上网，不再只靠"记忆"。**

---

## 你需要准备什么

📋 清单：
- OpenClaw 已安装
- 以下搜索服务的 API Key（选一个就行）：

| 服务 | 免费额度 | 特点 |
|------|---------|------|
| [Brave Search](https://brave.com/search/api/) | 2000 次/月 | 免费额度最大，推荐起步 |
| [Perplexity](https://www.perplexity.ai) | 按量付费 | 搜索 + AI 总结一步到位 |
| [Tavily](https://tavily.com) | 1000 次/月 | 专为 AI Agent 设计的搜索 API |

---

## 快速开始（以 Brave Search 为例）

### 第一步：获取 API Key

1. 注册 [Brave Search API](https://brave.com/search/api/)
2. 创建一个 API Key
3. 存到 1Password（参考 [1Password 指南](1password.md)）

### 第二步：在 OpenClaw 中配置

方式一：使用 onboarding 向导

```bash
$ openclaw configure --section web
```

选择 Brave Search，粘贴 API Key。

方式二：手动配置

```bash
$ openclaw gateway config.patch '{
  "web": {
    "provider": "brave",
    "apiKey": "你的Brave API Key"
  }
}'
```

> 💬 **JSON 看不懂？** 只需要把 `你的Brave API Key` 换成真实 Key，其他照抄。格式说明见 [从零开始](prerequisites.md#json--配置文件的语言)。

### 第三步：验证

在 OpenClaw 对话中问一个需要搜索的问题：

> "搜索一下 OpenClaw 最新版本是什么"

如果它返回了包含网络信息的回答，就配好了 🎉

---

## 核心用法

### 自然语言搜索

配好后不需要特殊语法。在对话中问需要最新信息的问题，OpenClaw 会自动判断是否需要搜索。

你也可以明确要求：

> "帮我搜索一下 React 19 的新特性"

> "网上查一下这个错误信息是什么意思：ECONNREFUSED 127.0.0.1:3000"

### 研究任务

> "帮我研究一下 2026 年最流行的 CSS 框架，做个对比"

OpenClaw 会搜索多个来源、交叉验证、整理成结构化的报告。

### 技术文档查询

> "搜索 Tailscale 的 ACL 配置文档"

比自己翻文档快。AI 搜完还会总结关键信息。

---

## 各搜索服务的对比

### Brave Search

- ✅ 免费额度最大（2000 次/月）
- ✅ 搜索质量好
- ✅ 配置最简单
- ❌ 中文搜索一般

### Perplexity

- ✅ 搜索 + AI 理解一步完成
- ✅ 结果质量最高
- ❌ 需要付费
- ❌ 调用频率有限制

### Tavily

- ✅ 专为 AI Agent 设计，返回结构化数据
- ✅ 免费 1000 次/月
- ❌ 中文搜索一般

💡 **推荐**：从 Brave Search 开始（免费够用），需要更好效果时考虑 Perplexity，Agent 自动化场景可以试 Tavily。

---

## 最佳实践

💡 **不是所有问题都需要搜索**：
AI 对训练数据范围内的问题已经很懂了。搜索主要用于：最新信息、具体数据、实时变化的内容。不要什么都搜——浪费额度。

💡 **API Key 保护**：
搜索 API Key 虽然不像支付 Key 那么敏感，但也应该用 1Password 管理，不要硬写在配置里。

💡 **配合代理使用**：
如果你在中国大陆，有些搜索 API 可能需要代理才能访问。在 OpenClaw 的 `env.vars` 里配置代理。

⚠️ **额度注意**：
免费 tier 有调用限制。如果 OpenClaw 的 cron 任务频繁搜索，可能很快用完。给 cron 任务设置搜索频率限制。

---

## 和 OpenClaw 的集成

### Cron + 搜索

定时搜索某个话题的最新动态：

> "每天早上 9 点搜索'AI agent 最新进展'，总结发到 Discord"

### 研究 Skill

OpenClaw 的研究类 Skill（如 gpt-researcher）会自动使用配置好的搜索服务。

### 多源交叉验证

搜索结果不一定准确。OpenClaw 会尝试从多个来源验证信息。配置多个搜索服务可以提高准确性。

---

## 常见问题

**Q: AI 搜索和我自己搜有什么区别？**
AI 搜索后会理解、筛选、总结——你拿到的是整理好的答案，不是一堆链接。

**Q: 可以同时配多个搜索服务吗？**
可以。OpenClaw 支持配置多个 provider，会根据场景选用。

**Q: 搜索结果不准怎么办？**
AI 搜索和人类搜索一样——网上的信息不一定都对。对关键信息要求 AI 给出来源链接，自己验证。

**Q: Brave Search 免费真的够用吗？**
普通使用 2000 次/月绰绰有余。如果有大量自动化搜索需求（cron 高频搜索），可能需要付费计划或换 provider。

---

## 进阶阅读

- [Brave Search API](https://brave.com/search/api/)
- [OpenClaw Web 工具文档](https://docs.openclaw.ai/tools/web)
- [OpenClaw Brave Search 文档](https://docs.openclaw.ai/brave-search)
