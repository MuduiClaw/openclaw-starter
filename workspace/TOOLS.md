# TOOLS.md - 能力索引 + 安全规则

> AI 的工具清单和安全边界。按需更新。

## ⛔ 安全规则（优先级最高）

- **禁止 `sudo npm install -g`** — 破坏 Homebrew 权限
- **Gateway 重启门禁** — 任何重启必须先 `openclaw config validate`，再通知 owner 等确认
- **浏览器** — 禁止 `launch()`，一律 `connect_over_cdp`

## 🔧 CLI 工具

<!-- 列出你安装的工具和用法 -->

| 工具 | 命令 | 用途 |
|------|------|------|
| Claude Code | `claude` | 重构/多文件编辑 |
| Codex | `codex` | 深度代码任务 |
| Gemini CLI | `gemini` | 多模态/长上下文 |

## 🌐 网络

<!-- 代理、出口 IP 等网络配置 -->

- **代理**: （如有配置填入，例如 Surge/Clash 地址）

## 🌐 Chrome 实例

<!-- 用于浏览器自动化的 CDP 实例 -->

| 实例 | 端口 | 用途 |
|------|------|------|
| headless | 18800 | 截图/测试/默认 |

## 📤 发布渠道

<!-- 内容发布到哪里 -->

- **媒体输出**: `~/.openclaw/media/outgoing/`

## 🛠️ 基础设施

<!-- LaunchAgent、备份、监控等 -->

- **Guardian**: LaunchAgent `ai.openclaw.guardian`，自动守护 Gateway 进程
- **备份**: （按需配置）
