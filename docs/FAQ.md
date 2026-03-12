# FAQ

> 常见问题速查。详细排错见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

## 安装相关

### Q: 全新 Mac 能直接装吗？

可以。bootstrap.sh 会自动安装 Xcode Command Line Tools、Homebrew、Node.js 等全部依赖。唯一需要你做的是在弹窗中确认安装 Xcode CLT。

### Q: 安装需要多长时间？

- **首次安装**：10-15 分钟（含下载依赖）
- **弱网环境**：20-30 分钟（建议配代理或清华镜像）
- **重跑 setup.sh**：1-2 分钟（已有依赖跳过）

### Q: 国内网络装不上怎么办？

安装脚本会自动检测系统代理。如果 GitHub/npm 不通：

```bash
# Homebrew 清华镜像
export HOMEBREW_BREW_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git
export HOMEBREW_CORE_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git

# 然后重跑
./setup.sh
```

### Q: Intel Mac 支持吗？

完整支持。Homebrew 装在 `/usr/local`（非 `/opt/homebrew`），脚本自动检测。

### Q: 重跑 setup.sh 会覆盖我的配置吗？

不会。设计原则：
- **用户文件**（SOUL.md、IDENTITY.md 等）：首次创建，之后不覆盖
- **系统文件**（scripts/、skills/）：升级时覆盖（自动 `.bak` 备份）
- **Gateway Token**：自动保留
- **用户新增文件**：不删除

### Q: 可以装在非 ~/clawd 目录吗？

可以：
```bash
./setup.sh --workspace-dir ~/my-ai
```

---

## 模型与费用

### Q: 哪个 LLM 选项最便宜？

MiniMax M2.5，按量计费且单价低。适合入门和日常使用。

### Q: Claude 订阅和 API Key 有什么区别？

| | 订阅（OAuth） | API Key |
|---|---|---|
| 费用 | 月费固定 | 按量付费 |
| Prompt Caching | ❌ 不支持 | ✅ 支持 |
| 稳定性 | 可能随政策变化 | 稳定 |
| 推荐场景 | 个人试用 | 生产环境 |

### Q: 安装后怎么切换模型？

```bash
openclaw configure  # 交互式，选 "Model/auth"
```

### Q: 可以用多个模型吗？

可以。配置 fallback 链，主模型失败自动降级：

```bash
openclaw config set 'agents.defaults.model.fallbackChain' '["anthropic/claude-sonnet-4-6","minimax/MiniMax-M2.5"]' --json
```

---

## Dashboard

### Q: Dashboard 打开是空白/401？

- **401**：需要登录。用安装完显示的 `?token=xxx` 链接，或输入默认密码 `0000`
- **空白**：检查服务是否运行：`launchctl list | grep infra-dashboard`
- **连接拒绝**：确认端口 `curl http://localhost:3001/`

### Q: 怎么更新 Dashboard？

```bash
cd ~/openclaw-starter && git pull && ./setup.sh --update-dashboard
```

一条命令：备份旧版 → 下载最新 → 重编译 → 重启。

### Q: Dashboard Settings 显示工具 missing？

这是实时检测。安装缺失的工具后自动识别：

```bash
# 例如安装 himalaya
brew install himalaya

# 刷新 Dashboard 即可看到变化
```

或重跑 setup.sh 自动补装所有缺失工具。

---

## Git Gates（质量门禁）

### Q: 提交被 Gate 拦住了怎么办？

常见 Gate 和解决方案：

| Gate | 报错 | 解法 |
|------|------|------|
| Gate 0.5 Scope | `N files staged but no [scope-ack]` | 确认文件列表后在 commit message 加 `[scope-ack]` |
| Gate 0.7 Spec | `no spec reference` | 创建 `tasks/xxx.md` 并在 message 加 `[spec:xxx]` |
| Gate 1 Format | `Bad commit format` | 格式：`type(scope): description`（如 `feat: add X`） |
| Gate 3 Tree-hash | `legacy 'passed' trailer` | `git commit --amend --no-edit` 重新生成 |
| Gate 4 TDD | `code changes but no test changes` | 添加测试，或用 `bash scripts/git-push-safe.sh` |
| REVIEWED | `缺 REVIEWED=1` | `REVIEWED=1 git commit -m "..."` |

### Q: 可以临时跳过 Gate 吗？

```bash
git push --no-verify  # 跳过 pre-push hooks（不推荐）
```

### Q: 我的项目不需要 Spec 流程？

删除项目根目录的 `tasks/` 文件夹即可关闭 Gate 0.7。

---

## 可选工具

### Q: bird/blogwatcher/himalaya/gog 是必须的吗？

不是。这些是可选工具，解锁额外 Skills。安装失败不影响核心功能。

### Q: blogwatcher 装不上？

blogwatcher 需要 Go 运行时。如果自动安装失败：

```bash
brew install go
go install github.com/Hyaxia/blogwatcher/cmd/blogwatcher@latest
ln -sf ~/go/bin/blogwatcher /opt/homebrew/bin/blogwatcher
```

### Q: 怎么知道哪些工具缺失？

打开 Dashboard → Settings → Skills，显示每个 Skill 的依赖状态和缺失项。

---

## 运维

### Q: 服务挂了怎么办？

Guardian Agent 会自动恢复。手动检查：

```bash
openclaw status                    # 总览
openclaw doctor                    # 诊断
bash ~/clawd/scripts/check-launchagent-health.sh  # LaunchAgent 健康
```

### Q: 怎么查日志？

```bash
tail -f ~/.openclaw/logs/gateway.log    # Gateway
tail -f ~/.openclaw/logs/guardian.log    # Guardian
tail -f ~/.openclaw/logs/infra-dashboard.log  # Dashboard
```

### Q: 怎么完全卸载？

```bash
./setup.sh --uninstall
```

详见 [配置指南 — 卸载](SETUP-GUIDE.md#卸载)。

### Q: 换了 Node.js 版本后服务起不来？

重跑 setup.sh，它会更新所有 LaunchAgent 的 PATH：

```bash
cd ~/openclaw-starter && ./setup.sh
```

---

## 远程访问

### Q: Tailscale 是什么？为什么需要它？

Tailscale 让你从手机/其他电脑远程访问 Mac。通过 WireGuard VPN 组网，不需要公网 IP。

如果你的 Mac 始终在身边，可以跳过：`./setup.sh --no-tailscale`

### Q: macOS SSH 开不了？

macOS Ventura+ 限制了命令行开启 Remote Login。setup.sh 会自动弹出系统设置，你只需手动打开开关。

---

## 升级

### Q: 怎么升级 OpenClaw 本体？

```bash
bash ~/clawd/scripts/safe-upgrade-openclaw.sh
```

### Q: 怎么升级 Starter Kit？

```bash
cd ~/openclaw-starter && git pull && ./setup.sh
```

### Q: 怎么升级 Dashboard？

```bash
cd ~/openclaw-starter && git pull && ./setup.sh --update-dashboard
```

详见 [UPGRADE.md](UPGRADE.md)。
