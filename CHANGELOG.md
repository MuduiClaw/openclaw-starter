# Changelog

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
