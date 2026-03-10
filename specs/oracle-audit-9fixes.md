# Spec: Oracle Audit 9 Fixes

> 状态: ✅ 已完成 (commit `063fd7b`)
> 触发: Mudui 在新机器上部署 openclaw-starter，遇到 infra-dashboard token 不匹配 + Control UI "gateway token missing"
> Oracle 审查发现 9 个问题

## 目标
修复 setup.sh 中 Oracle 审查发现的全部 9 个质量/安全/体验问题

## 改什么

### 🔴 严重 (3)

| # | 问题 | 修复方案 | 影响范围 |
|---|------|---------|---------|
| 1 | Gateway 3456 端口没做冲突检查 | 加入 port check 列表 | setup.sh L204 |
| 2 | Token/config 写入有权限窗口 (先写再 chmod) | 所有敏感文件用 `(umask 077; ... > file)` | 4 处写入点 |
| 3 | 重配置全量覆盖 openclaw.json，gateway token 丢失 | 先读旧 config 提取 gateway.auth.token，有则复用 | setup.sh config 生成段 |

### 🟠 中等 (3)

| # | 问题 | 修复方案 | 影响范围 |
|---|------|---------|---------|
| 4 | plist PATH 修改后没 reload | patch 后 `launchctl unload/load` | setup.sh gateway install 段 |
| 5 | `rsync --delete` 误杀用户自定义 skills/prompts | 去掉 `--delete`，只增量覆盖 | setup.sh workspace deploy 段 |
| 6 | qmd wrapper fallback 路径在 Intel Mac 写不进 `/usr/local/bin` | fallback 改为 node bin 目录 | setup.sh qmd-safe 段 |

### 🟡 优化 (3)

| # | 问题 | 修复方案 | 影响范围 |
|---|------|---------|---------|
| 7 | dashboard release curl 无超时，弱网卡死 | `--connect-timeout 10 --max-time 120`；tailscale 加 5s alarm | 2 处 |
| 8 | `--uninstall` 的 `rm -rf` 无路径防呆 | 拦截 `/`、`$HOME`、`/usr`、`/var`、`/etc`、`/tmp` | setup.sh uninstall 段 |
| 9 | sudo keepalive 在提权失败时仍启动 | 改为 `if sudo -v; then ... fi` | setup.sh sudo 段 |

## 怎么验
- `shellcheck -S warning setup.sh` = 零 warning
- `git diff --stat` 确认只改 setup.sh（+config 模板）
- 各修改点代码 review：逻辑正确、不引入回归

## 不做什么
- 不重构 setup.sh 整体架构
- 不改 infra-dashboard 代码（已在单独 commit `49716f4` 修过）
- 不改 openclaw.json 运行时行为

## 验证结果
- shellcheck: ✅ 零 warning
- diff: `1 file changed, 36 insertions(+), 18 deletions(-)`
- push: ✅ `063fd7b` → origin/main
