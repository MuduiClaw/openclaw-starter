# Spec: Gateway Self-Kill Protection

**Issue:** https://github.com/MuduiClaw/ClawKing/issues/13
**Status:** approved

## 目标
防止 AI agent 在 session 内执行 `openclaw gateway restart` 导致 gateway 永久下线。

## 改什么
1. `config/openclaw.template.json5` — 加 `denyCommands` 黑名单
2. `services/launchagents/ai.openclaw.watchdog.plist.template` — 新增 watchdog LaunchAgent
3. `services/scripts/gateway-watchdog.sh` — watchdog 检测+恢复脚本
4. `services/scripts/openclaw-safe-restart.sh` — 安全重启脚本（detach 后操作）
5. `setup.sh` — 安装 watchdog + safe-restart 脚本，uninstall 时清理
6. `workspace/AGENTS.md` — 铁律 #8

## 怎么验
- `denyCommands` 在 template 里有 4 条规则
- watchdog plist 是合法 XML
- setup.sh 安装流程包含 watchdog + safe-restart
- uninstall 清理包含 ai.openclaw.watchdog

## 不做什么
- 不改 OpenClaw 框架代码（仅用已有 denyCommands 能力）
- 不改 gateway 本身的 restart 逻辑

## 影响
- 新安装自动获得三层防护
- 已有安装需 `setup.sh` 重跑或手动部署
