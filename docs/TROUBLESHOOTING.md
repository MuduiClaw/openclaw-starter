# Troubleshooting

> 常见问题与解决方案

## 安装问题

### setup.sh 报 "permission denied"
```bash
chmod +x setup.sh
./setup.sh
```

### npm install 权限错误
```
Error: EACCES: permission denied
```

修复：
```bash
# 查看 npm prefix
npm config get prefix

# 修复权限
sudo chown -R $(whoami) $(npm config get prefix)/lib/node_modules
```

或者使用 nvm 管理 Node.js（推荐）：
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
nvm install 24
```

### Xcode CLT 安装卡住
```bash
# 手动安装
xcode-select --install
# 如果弹窗没出现
sudo xcode-select --reset
```

### Homebrew 安装失败（中国网络）
```bash
# 使用清华镜像
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Gateway 问题

### Gateway 启动失败
```bash
# 检查状态
openclaw status

# 查看日志
tail -50 ~/.openclaw/logs/gateway.err.log

# 验证配置
openclaw config validate

# 常见原因：端口被占用
lsof -ti :3456
# 如果有进程占用，kill 它
kill $(lsof -ti :3456)

# 重新启动
openclaw gateway start
```

### Gateway 连不上 Discord
1. 检查 Bot Token 是否正确
2. 确认 Bot 已添加到 Server（Guild）
3. 检查 `openclaw.json` 中 `channels.discord.allowlist` 的 guild ID

```bash
# 查看配置
openclaw config get channels.discord

# 测试 token
curl -H "Authorization: Bot YOUR_TOKEN" https://discord.com/api/v10/users/@me
```

### Gateway 连不上飞书
1. 检查 App ID 和 App Secret
2. 确认已开启"机器人"能力
3. 确认已在飞书群内添加机器人

## Dashboard 问题

### Dashboard 打不开 (localhost:3001)
```bash
# 检查是否运行
lsof -ti :3001

# 检查 LaunchAgent
launchctl list | grep infra-dashboard

# 查看日志
tail -50 ~/.openclaw/logs/infra-dashboard.log

# 手动启动测试
cd ~/projects/infra-dashboard
DASHBOARD_TOKEN=$(cat ~/.config/openclaw/dashboard.env | grep TOKEN | cut -d= -f2) \
  npx next start --port 3001
```

### Dashboard 报 "DASHBOARD_TOKEN is empty"
```bash
# 生成 token
openssl rand -hex 32 > /tmp/token
echo "DASHBOARD_TOKEN=$(cat /tmp/token)" > ~/.config/openclaw/dashboard.env
chmod 600 ~/.config/openclaw/dashboard.env
```

## 记忆系统问题

### qmd 命令找不到
```bash
npm i -g qmd
```

### qmd embed 失败
```bash
# 检查 collection
qmd collection list

# 重建 collection
qmd collection remove memory-root-main
qmd collection add ~/clawd --name memory-root-main --mask "MEMORY.md"
qmd embed
```

## Cron 问题

### Cron job 不触发
```bash
# 检查 cron 列表
openclaw cron list

# 检查 Gateway 是否运行
openclaw status

# 手动触发测试
openclaw cron trigger <job-name>
```

### Cron job 频繁超时
可能是模型响应慢或 prompt 太复杂。调大 timeout：
```bash
openclaw config set cron.jobs.<name>.timeout 600
```

## LaunchAgent 问题

### LaunchAgent 不工作
```bash
# 查看状态
launchctl list | grep openclaw

# 重新加载
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 查看错误
launchctl error ai.openclaw.gateway
```

### 卸载所有 LaunchAgents
```bash
./setup.sh --uninstall
```

## Coding Agent 问题

### Codex/Claude Code 命令找不到
```bash
npm i -g @openai/codex @anthropic-ai/claude-code @google/gemini-cli
```

### Codex 报认证错误
```bash
# 登录
codex auth
```

### Claude Code 报认证错误
```bash
# 使用 setup-token
claude setup-token
# 或设置 API key
export ANTHROPIC_API_KEY=sk-ant-...
```

## 网络问题

### npm registry 连不上（中国网络）
```bash
# 使用淘宝镜像
npm config set registry https://registry.npmmirror.com
```

### GitHub 克隆失败（中国网络）
使用代理或镜像：
```bash
git config --global url."https://ghproxy.com/https://github.com/".insteadOf "https://github.com/"
```

## 重置

### 完全重装
```bash
# 卸载
./setup.sh --uninstall

# 清理残留
rm -rf ~/.openclaw
rm -rf ~/clawd

# 重新安装
./setup.sh
```

### 只重置配置
```bash
rm ~/.openclaw/openclaw.json
./setup.sh   # 会重新走配置流程
```

## 获取帮助

- OpenClaw 文档：<https://docs.openclaw.ai>
- 社区 Discord：<https://discord.com/invite/clawd>
- GitHub Issues：<https://github.com/openclaw/openclaw/issues>
