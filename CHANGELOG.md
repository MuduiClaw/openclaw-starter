# Changelog

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
