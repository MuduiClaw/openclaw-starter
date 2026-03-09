# Changelog

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
- infra-dashboard 监控面板（强制安装）
- MCP Bridge
- 记忆系统 (qmd) 自动配置
- Coding Agents (Codex + Claude Code + Gemini CLI)
- setup.sh 一键安装（macOS）
- 支持 Discord / 飞书 channel
- 支持 Anthropic API Key / setup-token
