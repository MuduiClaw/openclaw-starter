# Spec: Security Audit Fixes

**Status:** approved
**Author:** 首席合伙人
**Date:** 2026-03-13
**Priority:** P0

## 目标
修复安全审计发现的所有 Critical + High + Medium 问题（dashboard 默认密码除外，保持 0000）。

## 不做什么
- Dashboard 默认密码不改（保持 0000）
- 不重构整体架构
- 不改 project-gates.sh / secret-scan.yml（它们本身是防护层，不需要改）

## 变更清单

### 🔴 Critical — setup.sh 安装中断

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| C1 | setup.sh:559 | `section` 函数未定义 | 加定义 `section() { step "━" "$*"; }` 或改为 `step` |
| C2 | setup.sh:902 | `SCRIPTS_DIR` 未定义（应为 `SCRIPT_DIR`）, `set -u` 下直接 abort | 改为 `SCRIPT_DIR` |
| C3 | check-fleet.sh:18, openclaw-wrapper:12, safe-upgrade-openclaw.sh:122, safe-gateway-restart.sh:25 | 硬编码端口 18789（用户环境是 3456） | 动态读取：从 `~/.openclaw/openclaw.json` 取 `gateway.port`，fallback 3456 |

### 🟠 High — 隐私泄露

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| H1 | workspace/scripts/dotfiles/gitconfig:9 | `hxrYOUR_USERNAME@gmail.com` 泄露 email 前缀 | 改为 `your-email@example.com` |
| H2 | workspace/scripts/git_auto_backup.sh:20 | 硬编码 Discord 频道 `channel:1468294832551362782` | 改为从环境变量/配置读取，无配置则 skip |
| H3 | workspace/scripts/guardian_agent.py:700,938 | 注释引用 `#clawd-日志` 频道名 | 改为通用描述 `#alerts channel` |

### 🟡 Medium — 功能缺陷

| # | 文件 | 问题 | 修复 |
|---|------|------|------|
| M1 | workspace/scripts/oracle.sh:17 | 依赖 `~/.config/md2wechat/config.yaml` | 优先 `$GEMINI_API_KEY` 环境变量，fallback 原路径 |
| M2 | workspace/scripts/git_auto_backup.sh | 引用不存在的 r2 脚本 / .claw_aliases | 加 `[ -f ] &&` 守卫 |
| M3 | workspace/scripts/Brewfile | 含个人工具（antigravity, android-commandlinetools 等） | 精简为 starter 必需最小集 |
| M4 | setup.sh:426,514 | `curl | sh` 安装 uv/bun | uv 改 `brew install uv`；bun 保留 curl（brew 版有兼容问题） |

## 验证方式
1. `grep -rE '(18789|hxr|1468294832|clawd-日志|md2wechat)' workspace/ services/ setup.sh` = 0 命中
2. `grep -n "section\|SCRIPTS_DIR" setup.sh` 确认修复
3. secret-scan CI 通过
4. bats 测试全过
5. 在干净目录 `bash setup.sh --help` 不报错

## 影响范围
- setup.sh（安装入口）
- workspace/scripts/（6 个脚本）
- workspace/scripts/Brewfile
- 不影响 workspace 模板文件（SOUL.md 等已全部干净）
