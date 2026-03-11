# AGENTS.md — openclaw-starter

## 项目定位
OpenClaw Starter Kit：把 battle-tested 的 OpenClaw 全套能力打包成可分发的一键安装包。

## 核心规则

### 安全红线
- **零 secrets**：仓库内禁止出现任何真实 API key、token、密码。占位符格式 `__YOUR_xxx__`
- **发版门禁**：`grep -rE '(sk-|AKIA|ghp_|xoxb-)' --exclude-dir=node_modules` 必须零命中
- **不含私有文件**：aihub、雪哒、XHS、bitmart 相关内容禁止进入本仓库

### 与 live 环境的关系
- **只读消费者**：从 `~/clawd` 单向提取通用文件，不反向影响
- **sync-to-template.sh**：维护者同步工具，白名单机制，只同步通用文件
- **独立版本**：自己的 VERSION + CHANGELOG，不跟 clawd 版本号

### setup.sh 原则
- **幂等**：重跑不破坏已有配置
- **用户配置区不覆盖**：SOUL.md, IDENTITY.md, USER.md, TOOLS.md, MEMORY.md
- **系统核心区强制覆盖**：scripts/, prompts/, eval/, skills/（覆盖前 .bak 备份）
- **依赖自动装**：缺啥装啥，用户只需要贴 API key + channel token

### 文件分类
| 类型 | 文件 | 规则 |
|------|------|------|
| 用户自定义 | *.example → 无后缀 | 只首次复制，不覆盖 |
| 系统核心 | scripts/, prompts/, skills/ | 升级时强制覆盖 + .bak |
| 配置模板 | openclaw.template.json5 | 全脱敏，变量占位 |

### 验证标准
- setup.sh 干净环境零报错
- `openclaw status` = running
- `curl localhost:3001` = 200
- `qmd status` ≥ 2 collections
- secret scan 零命中

## 教训
（从实践中积累，每次翻车追加）
- [2026-03-10] **禁止在源码中硬编码 API Key，即使是"内置免费 key"** — generate.mjs 泄露 Gemini key，Oracle 审查发现（be16e0e）
- [2026-03-10] **服务默认绑定 127.0.0.1 不绑 0.0.0.0；用户输入不可拼入 shell 命令** — 安全审查发现 dashboard 监听所有接口 + 脚本存在注入向量（3ec1cff）
- [2026-03-10] **macOS plist 修改用 plistlib，不用 sed** — sed 操作 XML plist 易因格式差异静默失败，plistlib 结构化操作才可靠（f3f4248）
- [2026-03-10] **自动化脚本中 git clone 必须加 GIT_TERMINAL_PROMPT=0** — 无 token 时 git 弹交互式凭证提示导致脚本挂起（4a296de）
- [2026-03-11] **Setup 脚本中 Homebrew 路径应使用 BREW_PREFIX** — 禁止硬编码 `/opt/homebrew` 以免在 Intel Mac (/usr/local) 上失效
- [2026-03-11] **脚本应从源文件绝对路径推导 REPO_ROOT 而非 CWD** — 防止在不同目录下执行时将 lock/marker 文件写入错误项目
- [2026-03-11] **Next.js Standalone 打包须手动包含 .node 二进制与源码** — 默认构建会剥离原生插件，需手动复制并提供 rebuild 路径以支持不同 Node 版本
