# 从零开始 — 在读其他指南之前，先看这篇

## 这篇是写给谁的

如果你看到 `npm install` 或 `export API_KEY=xxx` 就知道怎么做——跳过这篇，直接去看感兴趣的工具指南。

如果你不确定"终端"是什么、"环境变量"是什么——花 10 分钟看完这篇，后面的指南就不会卡壳了。

---

## 终端（Terminal）

终端是一个文字界面，你在里面输入命令，电脑就去执行。所有指南里的操作都在终端里完成。

### 怎么打开终端

**macOS：**
- 按 `Command + 空格`，输入"终端"或"Terminal"，回车

**Windows：**
- 按 `Win + R`，输入 `wt`（Windows Terminal）或 `cmd`，回车
- 💡 强烈推荐装 [WSL2](https://learn.microsoft.com/zh-cn/windows/wsl/install)（Windows 里跑 Linux），OpenClaw 在 WSL2 下体验最好

**Linux：**
- `Ctrl + Alt + T`（大部分发行版）

### 终端里的命令长什么样

本指南里所有以 `$` 开头的行都是终端命令。**你不需要输入 `$` 符号本身**，它只是表示"这是一条命令"。

```
$ node --version     ← 你输入 node --version，然后按回车
v25.5.0              ← 这是电脑的回复
```

如果命令前面没有 `$`，通常是输出结果或配置内容。

---

## Node.js — 很多工具的"地基"

Node.js 是一个运行 JavaScript 的环境。你不需要会 JavaScript——但很多 AI 工具（Codex、Claude Code、Wrangler 等）是用它构建的，所以需要装它。

### 检查有没有装

```bash
$ node --version
```

如果输出 `v22.x.x` 或更高，就没问题。如果提示"command not found"，需要安装。

### 怎么安装

**最简单的方式（推荐）：**

macOS：
```bash
$ curl -fsSL https://fnm.vercel.app/install | bash   # 安装 fnm（Node 版本管理器）
$ fnm install 22                                      # 安装 Node.js 22
```

或者直接去 [nodejs.org](https://nodejs.org) 下载安装包，一路点下一步。

### npm 是什么

装好 Node.js 后，你会自动获得一个叫 `npm` 的工具。它是 Node.js 的"应用商店"——你可以用它安装各种命令行工具。

```bash
$ npm install -g @openai/codex
```

这行命令的意思是：
- `npm install`：从应用商店安装
- `-g`：全局安装（安装一次，到处能用，不限于当前目录）
- `@openai/codex`：要安装的工具名

---

## Homebrew — macOS 的另一个"应用商店"

如果你用 macOS，很多指南会用 `brew install xxx`。Homebrew 是 macOS 上的命令行软件管理器。

### 怎么安装 Homebrew

```bash
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

装好后就可以用 `brew install` 了：

```bash
$ brew install gh        # 安装 GitHub CLI
$ brew install tailscale # 安装 Tailscale
```

💡 Windows/Linux 不用 Homebrew，每个指南里会给你对应的安装方式。

---

## API Key — 你的"通行证"

很多服务（OpenAI、Anthropic、Google 等）需要你注册账号，然后生成一个 **API Key**。它是一串字符（像密码一样），证明"这个请求是我发的"。

长这样：`sk-abc123...xyz789`

### 怎么拿 API Key

每个服务不一样，但流程基本是：
1. 去官网注册账号
2. 进入"API"或"Developer"页面
3. 点"Create API Key"
4. 复制保存

⚠️ **API Key 等于密码**——不要发给别人、不要贴到公开的地方（GitHub、论坛……）。后面的 [1Password 指南](1password.md) 会教你怎么安全管理它们。

---

## 环境变量 — 告诉程序"去哪里找密钥"

你拿到 API Key 后，需要告诉工具去哪找它。最常见的方式是设置**环境变量**。

你可以把环境变量理解为**贴在电脑上的便签纸**——程序运行时会读这些便签，拿到需要的信息。

### 怎么设置

```bash
$ export OPENAI_API_KEY="sk-abc123...xyz789"
```

- `export`：设置一个环境变量
- `OPENAI_API_KEY`：变量的名字（程序约定好了叫这个名字）
- `"sk-abc123..."`：变量的值（你的 API Key）

### 重要：关掉终端就没了

`export` 设置的环境变量**只在当前终端窗口有效**。关掉窗口、重启电脑就没了。

要让它"永久生效"，需要写到配置文件里：

```bash
# macOS / Linux（用 zsh 的情况）
$ echo 'export OPENAI_API_KEY="你的Key"' >> ~/.zshrc
$ source ~/.zshrc   # 让它立刻生效
```

💡 但更推荐的方式是用 1Password 管理密钥，不把明文写在文件里。参考 [1Password 指南](1password.md)。

---

## JSON — 配置文件的"语言"

OpenClaw 的配置文件用 JSON 格式。JSON 就是一种写数据的格式，长这样：

```json
{
  "name": "张三",
  "age": 25,
  "hobbies": ["读书", "跑步"]
}
```

规则很简单：
- 用 `{}` 包裹一组数据
- 每项是 `"名字": "值"` 的格式
- 文本值要用双引号 `""`
- 多项之间用逗号 `,` 分隔
- **最后一项后面不能有逗号**（最常见的错误！）

在指南里你会看到这样的命令：

```bash
$ openclaw gateway config.patch '{
  "channels": {
    "discord": {
      "enabled": true
    }
  }
}'
```

不用紧张——你只需要**替换其中的值**（比如把 Token 换成你自己的），结构照抄就行。

💡 如果 JSON 写错了（少个逗号、多个引号），命令会报错。可以把你的 JSON 粘贴到 [jsonlint.com](https://jsonlint.com) 验证一下格式对不对。

---

## Git — 代码的"时光机"

Git 是一个版本管理工具——它帮你记录文件的每一次修改，随时可以回退到之前的版本。

你不需要深入学 Git。在这套指南里，你只需要知道：

```bash
$ git clone https://github.com/xxx/yyy    # 从 GitHub 下载一个项目
$ git add .                                # 标记所有修改
$ git commit -m "说明改了什么"              # 保存一个版本
$ git push                                 # 推送到 GitHub
```

如果你完全没用过 Git，推荐先看 [GitHub 指南](github.md)——那篇会带你从装 Git 到配好 GitHub。

---

## 下一步

看完这篇，你已经知道了：
- ✅ 终端在哪、怎么用
- ✅ Node.js 和 npm 是什么
- ✅ 怎么安装命令行工具
- ✅ API Key 是什么、怎么拿
- ✅ 环境变量怎么设置
- ✅ JSON 格式怎么看
- ✅ Git 基础命令

现在可以去看 [Discord 指南](discord.md) 了——从最简单的开始，一步步来。
