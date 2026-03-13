# Upgrade Guide

> 三个层面的升级：OpenClaw 本体、infra-dashboard、ClawKing

## OpenClaw 升级

```bash
# 推荐方式（安全升级脚本）
bash ~/clawd/scripts/safe-upgrade-openclaw.sh

# 或手动
npm i -g openclaw@latest
openclaw config validate    # 验证配置兼容性
openclaw gateway restart    # 重启 Gateway
```

升级后检查：
```bash
openclaw --version
openclaw status
```

## infra-dashboard 升级

```bash
cd ~/projects/infra-dashboard
git pull origin main
npm install
npm run build

# 重启 LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.openclaw.infra-dashboard.plist
launchctl load ~/Library/LaunchAgents/com.openclaw.infra-dashboard.plist
```

## ClawKing 升级

```bash
cd ~/path-to/ClawKing
git pull

# 重新运行 setup（幂等，安全）
./setup.sh
```

### 升级策略

setup.sh 使用**分区覆盖策略**：

| 区域 | 文件 | 升级行为 |
|------|------|---------|
| **用户配置区** | SOUL.md, IDENTITY.md, USER.md, TOOLS.md, MEMORY.md | ❌ **永不覆盖**（你的个性化配置） |
| **系统核心区** | scripts/, prompts/, eval/, skills/ | ✅ **强制覆盖**（备份到 `.bak.YYYYMMDD`） |

这意味着：
- 你对 `SOUL.md` 等文件的修改永远安全
- scripts/skills 自动获得最新版本
- 旧版本备份在 `.bak.日期` 目录中

### 查看变更

升级前查看 CHANGELOG：
```bash
cat CHANGELOG.md
```

## Coding Agents 升级

```bash
npm i -g @anthropic-ai/claude-code@latest
npm i -g @openai/codex@latest
npm i -g @google/gemini-cli@latest
```

## MCP 升级

```bash
npm i -g @upstash/context7-mcp@latest
```

## 全量升级一键命令

```bash
# 升级所有 npm globals
npm update -g

# 升级 Homebrew
brew update && brew upgrade

# 升级 ClawKing
cd ~/path-to/ClawKing && git pull && ./setup.sh
```

## 回滚

如果升级后出问题：

### OpenClaw 回滚
```bash
npm i -g openclaw@<previous-version>
```

### Workspace 回滚
```bash
# 系统核心区有备份
ls ~/clawd/scripts.bak.*
# 恢复
cp -a ~/clawd/scripts.bak.20260309/ ~/clawd/scripts/
```

### Dashboard 回滚
```bash
cd ~/projects/infra-dashboard
git log --oneline -5     # 找到之前的 commit
git checkout <commit>
npm run build
```
