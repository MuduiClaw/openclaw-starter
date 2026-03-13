# Changelog

## [Unreleased]

### 新功能
- ACP auth guidance — setup.sh checks + README docs
- add infra-audit.sh + brand-system skeleton (#7, #11)
- ask user before installing Tailscale (interactive Y/n prompt)
- sync gates telemetry alignment + add git-push-safe.sh
- portable hooks + setup script + documentation
- add release.sh automation + update CHANGELOG with post-1.3.1 changes
- add optional CLI tools to setup.sh — himalaya, gog, bird, blogwatcher with auto-symlink and PATH setup
- add project-gates.sh (secrets+privacy scan) + SPEC-TEMPLATE — align gates with infra-dashboard
- add web/media/links/exec/plugins template + brave setup prompt
- add git quality gates (shellcheck, scope-ack, conventional commits)
- --update-dashboard command + dashboards tutorial in README
- add Self-Reflection Loop cron prompt to starter
- complete uninstall — clean up cron, dashboard, qmd, config
- add release-dashboard.sh for automated dashboard publishing
- distribute infra-dashboard via GitHub Release
- clarify GitHub Token needed for infra-dashboard
- add bootstrap.sh for fresh Mac install

### 修复
- gateway self-kill protection — denyCommands + watchdog + safe-restart
- qmd-safe.sh template — resolve ~/.local/bin/qmd first
- qmd-safe.sh resolve ~/.local/bin/qmd when not in PATH
- improve Tailscale prompt — explain why + free
- Tailscale default to skip (y/N), not auto-install
- Tailscale interactive prompt use Chinese
- qmd shim points to wrong path (src/qmd.ts → src/cli/qmd.ts)
- run tailscale login in background to prevent install deadlock
- guard brew shellenv eval against set -u crash on fresh Mac
- Revert "fix: generate random dashboard token instead of hardcoded 0000"
- generate random dashboard token instead of hardcoded 0000
- remove developer-specific references from workspace templates
- security audit — 3 critical + 3 high + 4 medium
- sync hooks with physicalize iteration — add Gate 2.1 + Gate 5, remove task-lock
- whisper model path use BREW_PREFIX for Intel Mac compat
- set feishu groupPolicy=open to prevent intermittent pairing prompts
- add whisper-cpp local STT for voice message support
- 补齐所有 gate 文件 + wrapper 安装 + hooks 路径去硬编码
- Guardian 端口不再写死 18789，自动从配置读取
- Guardian 默认自动重启，不再需要审批门禁
- SSH 开启自动弹设置页面 + 轮询等待
- SSH 启用改用 launchctl load -w
- macOS SSH 开启兼容 Ventura+ FDA 限制
- tailscale login 自动弹浏览器
- add MiniMax VL-01 for image understanding in setup config
- tailscale daemon 三级启动保障
- require Node.js v25+ (was v24+)
- build dashboard with NEXT_PUBLIC_EDITION=starter to exclude dev modules
- use BREW_PREFIX for Intel Mac .zprofile brew shellenv path
- dashboard token overwrite + Control UI auto-auth URL
- sync gate scripts — derive REPO_ROOT from spec path, not cwd
- clean skills for public use
- native addon in standalone tarball + robust rebuild fallback
- upgrade Node v24→v25, bun fallback, PATH auto-update, native addon rebuild
- remove Self-Reflection Loop from starter
- remove '工程' from default dashboard modules
- address 2 remaining Oracle review gaps
- address all 9 Oracle audit issues
- generate gateway auth token + show dashboard login URL on setup
- prevent git credential prompt blocking install
- MiniMax 推荐理由改为「价格便宜」
- crash on fresh Mac + channel config optional + confirm loop

### 文档
- 三道防线（自愈 + Claude 急救 + GitHub 备份）
- 添加最佳模型搭配推荐 + 龙虾要养越用越香
- README 标题改为 ClawKing 🦞 — OpenClaw 开箱即用精装版
- 重写 README — 面向非技术用户，讲清楚和 OpenClaw 的关系
- 重写 README — 用户视角，加毛坯房 vs 精装交付定位
- README 添加工具深度指南入口
- 工具深度指南 — 12 篇中文实战指南 + 第零篇入门
- 替换截图为 viewport 尺寸（不再 fullPage）
- 添加 dashboard/gates/tasks 截图到 GATES.md 和 README
- GATES.md 全面重写 — 19 个门禁按 Loop 阶段 + telemetry + 辅助工具 + 任务看板
- restructure README → concise landing + SETUP-GUIDE + FAQ
- AGENTS.md 自动教训沉淀
- update README for zero-cron starter (e5232a6)
- sync README with today's changes
- add MCP servers section to config template
- add Control UI + Dashboard screenshots to README
- remove jargon from README intro (battle-tested, Docker)
- update README + CHANGELOG for v1.3.0 Oracle audit fixes
- fix MiniMax description — key is user-provided, not built-in
- add model + channel setup guides with official doc links
- rewrite README for v1.3.0 — MiniMax default, Guardian, security, actual install flow

### 测试
- add git-push-safe.sh gate tests
- add 20 tests for portable hooks, setup script, and docs
- auto-generated tests (TDD gate remediation)
- init bats test suite for TDD gate enforcement

### 维护
- purge remaining 'Starter' references → ClawKing
- fix remaining 'starter kit' references in sync-to-template.sh
- rename openclaw-starter → ClawKing 🦞
- sync physicalize — 删 7 零触发脚本 + 加 spawn-agent.sh
- remove personal CLI tools (bird/blogwatcher/himalaya/gog) from starter
- remove Mac mini-specific cron prompts
- mark v1.3.1-cleanup as done
- v1.3.1 public release cleanup
- add initial lessons.md + journal/.gitkeep for new installs
- remove 7 personal cron prompts, keep 7 universal ones

### 其他
- docs+fix: Tailscale 完整说明 + SSH 开启交互引导

## [1.3.1] - 2026-03-11

### 公开发布清理
- **全量脱敏**：清理 guardian_agent.py、SKILL.md、AGENTS.md、specs 中的私有名字引用
- **新增 workspace 模板**：`SOUL.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md` 通用骨架 + 注释引导
- **Dashboard v1.1.0 发布**：包含 visibleModules 过滤、force-dynamic、Node v25 native addon
- **LaunchAgent 文档**：README 新增完整的 8 个 LaunchAgent 说明 + PATH 机制 + 常见操作
- **添加 MIT License**

### Node v25 升级
- `brew install node` 升级到 v25（最低 v24）
- bun 安装失败 → fallback `npm i -g bun`
- `.zprofile` PATH 自动更新
- infra-dashboard `better-sqlite3` native addon 自动 rebuild

### 新功能
- **`--update-dashboard` 命令**：备份→下载→rebuild→重启→验证
- **Git 质量门禁**：shellcheck、JSON 语法检查、提交范围锁（>5 文件需 `[scope-ack]`）、Conventional Commits 检查
- **README 截图**：Control UI + Infra Dashboard 登录页截图

### 改进
- Skills 清理：移除 login-machine、修复 blueprint-infographic/crawl4ai 硬编码路径、修复 kb-rag API key 泄露
- 减少 cron 到 7 个通用模板（移除 7 个个人内容相关）
- Dashboard 模块精简为 `["运行态", "基建", "知识", "配置"]`
- 完整卸载流程（清理 cron、dashboard、qmd、配置）
- 新安装自带 `memory/archive/lessons.md` + `memory/journal/.gitkeep`

### 修复
- native addon 打包到 standalone tarball（release-dashboard.sh）
- native addon rebuild 失败时 fallback 到 fresh install

## [1.3.1-rc] - 2026-03-11 ~ 2026-03-12

> 以下变更在 1.3.1 发版后陆续合入，属于下次发版内容。

### 新功能
- **whisper-cpp 本地 STT**：语音消息转文字，无需 API Key，自动下载 tiny 模型
- **MiniMax VL-01 视觉模型**：setup 配置自动加入图片理解能力
- **Web/Media/Exec 工具模板**：setup 生成的 config 包含完整 tools 段
- **Brave Search 交互式配置**：安装时引导配置搜索 API Key
- **飞书 groupPolicy=open**：消除间歇性配对弹窗

### 安全与健壮性
- **Guardian 默认自动重启**：不再需要审批门禁
- **Guardian 端口自动读取**：不再硬编码 18789
- **Tailscale 三级启动保障**：brew services → install-system-daemon → 手动
- **Tailscale login 自动弹浏览器**
- **macOS SSH 兼容 Ventura+ FDA 限制**：自动弹系统设置 + 轮询等待
- **Node.js 最低版本改为 v25+**

### Git Gates
- **Gate 文件补齐 + hooks 路径去硬编码**
- **Intel Mac 兼容**：BREW_PREFIX 替代硬编码 `/opt/homebrew`
- **whisper 模型路径兼容 Intel**

### Dashboard
- **NEXT_PUBLIC_EDITION=starter**：排除 dev 模块
- **Dashboard token 不再被覆盖**
- **Control UI auto-auth URL**

## [1.3.0] - 2026-03-10

### 安全修复（Oracle 审查 9 项）
- **文件权限窗口消除**：所有 Token/Config 写入改用 `umask 077`，消除创建到 chmod 之间的泄露窗口
- **卸载路径安全检查**：`--uninstall` 拦截 `/`、`$HOME` 等危险路径，防止误删
- **sudo keepalive 条件启动**：提权失败时不再盲启后台进程

### 健壮性修复
- **Gateway 端口冲突检查**：3456 端口加入 pre-flight 检查
- **Gateway Token 保留**：重跑 setup.sh 重新配置时复用已有 token，不丢失书签/客户端连接
- **LaunchAgent plist 重载**：PATH patch 后立即 unload/load，确保生效
- **rsync 增量覆盖**：去掉 `--delete`，保留用户在 skills/prompts 下的自定义文件
- **qmd 安装路径**：从 `/usr/local/` 迁移到 `~/.local/`，Intel Mac 不再需要 sudo
- **网络超时保护**：Dashboard 下载加 120s 超时；Tailscale 状态检查加 5s 超时

### 安全修复（历史）
- **MCP Bridge + Dashboard 绑定 localhost**：不再暴露到局域网（公共 WiFi 安全）
- **移除硬编码 API Key**：MiniMax key 改为用户交互式输入，不再写死在脚本中
- **消除模板注入风险**：config 生成从 node -e 迁移到 python3 + 环境变量
- **GitHub Token 保护**：git clone 改用 `http.extraheader`，不嵌入 URL
- **Guardian 安全加固**：`shell=False` + `shlex.split`，消除 shell 注入

### 新功能
- **Guardian Agent**：3 层智能守护（进程/端口检查→doctor 修复→回滚→通知）
- **Dashboard 配置化**：`~/.config/openclaw/dashboard.config.json` 控制显示的工具/模块/项目
- **Cron 自动注册**：setup.sh 完成后自动注册 13 个 cron job
- **LaunchAgent 健康检查脚本**：`check-launchagent-health.sh`

### 改进
- Dashboard 和 Gateway 安装后自动打开浏览器
- Oracle 工具加入 dashboard 配置
- "工程" 模块加入侧边栏配置

### 修复
- interval-based cron schedules（ms → --every）正确处理
- Gateway plist PATH 注入（plistlib 可靠替换）
- Gateway token 同步到 dashboard.env（python3 读取 auth.token）
- MCP Bridge `--sse` flag（不是 `--host`）

## [1.2.0] - 2026-03-09

### 新功能
- **系统代理自动检测**：自动读取 macOS 系统代理配置（scutil），国内环境 GitHub/npm 不再裸连超时
- **Tailscale SSH 远程控制**：自动安装 Tailscale + 引导登录 + 开启 SSH，装完后不在同一网络也能远程管理
- **防休眠配置**：`pmset` 禁止系统休眠 + `caffeinate` LaunchAgent 双保险，Mac 7×24 在线
- **SSH 开启**：自动启用 macOS Remote Login

### 改进
- sudo 密码一次性预收集（不再在安装中途反复弹密码提示）
- GitHub 连通性验证：代理设完后实测，不通则提示清华镜像
- 去掉 `set -e`：安装脚本改为 graceful degradation（单项失败不中断全流程）
- 去掉 `npm install --production`：Next.js build 需要 devDependencies

### 修复（v1.1.0 e2e 发现）
- 私有仓库 clone：GitHub token 现在用于 infra-dashboard + shared-ui 认证
- shared-ui 依赖：infra-dashboard 的 `file:../shared-ui` 依赖现在自动同步 clone
- 完成信息显示 Tailscale SSH 连接命令

### 新增 flags
- `--no-tailscale`：跳过 Tailscale 安装
- `--no-caffeinate`：跳过防休眠配置

## [1.1.0] - 2026-03-09

### 新功能
- **MiniMax M2.5 内置**：开箱即用，用户无需配置任何 LLM API key 即可使用
  - 选飞书 → 粘贴飞书 bot 配置 → 直接可用
  - Anthropic 变为可选项（有则 Claude 为主 MiniMax 为 fallback，无则 MiniMax 为主）
- **infra-dashboard 无感安装**：从 GitHub 自动 clone → install → build → 启动，不依赖 git submodule

### 改进
- 安装流程从 3 步简化为 2 步（LLM 模型默认内置）
- 模型选择菜单重新设计，推荐选项更明确

## [1.0.0] - 2026-03-09

### 初始发布
- The Loop 方法论 (AGENTS.md)
- 24 个通用 Skills
- 13 个 Cron Fleet 模板
- 交互式安装脚本（幂等）
- infra-dashboard 监控面板
- 7 个 LaunchAgent 模板
- CI Secret Scan 门禁
