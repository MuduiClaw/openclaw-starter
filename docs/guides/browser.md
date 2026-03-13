# Browser — 给 AI 一个浏览器

## 为什么用它

AI 不仅能读写代码和文件——它还能操作浏览器。打开网页、截图、点击按钮、填表单、读取页面内容。

场景举例：
- 部署完网站后，让 AI 打开页面截图验证效果
- 自动化登录某个后台管理页面
- 抓取网页内容并整理成报告
- 检查前端渲染是否正确

OpenClaw 管理一个**独立的浏览器实例**——和你日常用的浏览器完全隔离，不会互相干扰。

简单说：**AI 有了自己的浏览器，能看、能点、能截图。**

---

## 你需要准备什么

📋 清单：
- Chrome / Chromium / Brave / Edge（任一一个就行，大部分系统自带）
- OpenClaw 已安装

---

## 快速开始

### 第一步：启用浏览器功能

```bash
$ openclaw gateway config.patch '{
  "browser": {
    "enabled": true,
    "defaultProfile": "openclaw"
  }
}'
```

`openclaw` profile 是一个独立的浏览器配置文件，和你的个人浏览器完全隔离。

### 第二步：启动浏览器

```bash
$ openclaw browser --browser-profile openclaw start
```

### 第三步：验证

```bash
$ openclaw browser --browser-profile openclaw status
$ openclaw browser --browser-profile openclaw open https://example.com
$ openclaw browser --browser-profile openclaw snapshot
```

如果能看到 snapshot 输出（页面内容），就配好了 🎉

---

## 核心用法

### 打开网页

```bash
$ openclaw browser open https://your-site.com
```

### 截图

```bash
$ openclaw browser screenshot
# 截图保存到本地
```

### 页面快照（读取内容）

```bash
$ openclaw browser snapshot
# 输出页面的文本内容，方便 AI 理解
```

### 在 OpenClaw 对话中使用

在 Discord 或其他聊天界面里说：

> "打开 https://my-app.com 截图看看，检查页面有没有报错"

OpenClaw 会：
1. 用浏览器打开页面
2. 检查控制台有没有错误
3. 截图发给你
4. 总结发现的问题

---

## 理解浏览器 Profile

| Profile | 作用 | 需要扩展？ |
|---------|------|-----------|
| `openclaw` | OpenClaw 管理的独立浏览器，推荐用这个 | 不需要 |
| `chrome` | 你日常用的浏览器，通过 Chrome 扩展连接 | 需要装 OpenClaw 扩展 |

💡 **推荐用 `openclaw` profile**。它是隔离的，不会碰你的个人浏览数据。

---

## 最佳实践

💡 **Headless 模式**：
如果在服务器上（没有显示器），浏览器可以用 headless 模式运行——不需要图形界面：

```json5
// openclaw.json 片段
{
  "browser": {
    "openclaw": {
      "headless": true
    }
  }
}
```

💡 **不要用你的日常浏览器**：
`openclaw` profile 是专门给 AI 的"工作浏览器"。让 AI 操作你的个人浏览器 profile 有隐私风险。

💡 **CDP 连接**：
如果你已经有一个跑着的 Chrome 实例（比如做开发调试），可以让 OpenClaw 通过 Chrome DevTools Protocol (CDP) 连接：

```json5
{
  "browser": {
    "openclaw": {
      "cdpUrl": "http://127.0.0.1:9222"
    }
  }
}
```

💡 **多实例**：
可以配置多个浏览器 profile，用于不同场景（测试环境、生产环境、不同账号等）。

---

## 和 OpenClaw 的集成

### 前端验证工作流

写完代码 → 部署 → 浏览器打开 → 检查控制台错误 → 截图比对 → 通过或返工。

这个流程 OpenClaw 可以全自动完成。

### 搭配 Codex / Claude Code

编码代理改了前端代码后，OpenClaw 用浏览器打开页面验证：
1. 没有 console error ✅
2. 页面渲染正常 ✅
3. 关键功能可用 ✅

### 网页抓取

需要抓取网页内容？OpenClaw 可以用浏览器加载页面（包括需要 JavaScript 渲染的），然后提取内容。

---

## 常见问题

**Q: "Browser disabled" 怎么办？**
在配置里启用浏览器功能。参考上面"快速开始"的第一步。

**Q: 服务器上没有图形界面怎么办？**
用 headless 模式。Chrome 在 headless 模式下不需要显示器也能运行。

**Q: 截图在哪里？**
默认保存在 OpenClaw 的媒体输出目录。具体路径可以在 `openclaw.json` 里配置。

**Q: 可以同时打开多个页面吗？**
可以。OpenClaw 的浏览器支持多 tab 管理（list / open / focus / close）。

**Q: 和 Playwright/Puppeteer 有什么区别？**
OpenClaw 的浏览器是高层抽象——你用自然语言就能操作。不需要写代码。当然，如果你有 Playwright 脚本，OpenClaw 也可以帮你运行。

---

## 进阶阅读

- [OpenClaw 浏览器文档](https://docs.openclaw.ai/tools/browser)
- [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/)
- [Chrome 扩展](https://docs.openclaw.ai/tools/chrome-extension)
