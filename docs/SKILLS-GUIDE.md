# Skills 扩展指南

> 三层 Skills 体系：内置 → 自定义 → ClawHub 社区

## 什么是 Skill？

Skill 是 AI 的能力模块。每个 skill 是一个目录，包含 `SKILL.md`（行为指令）和可选的脚本/参考文档。AI 根据用户请求自动匹配并加载对应 skill。

```
my-skill/
├── SKILL.md           # 必须：AI 行为指令
├── references/        # 可选：参考文档
├── scripts/           # 可选：执行脚本
└── run.sh             # 可选：入口脚本
```

## 三层体系

### 1. 内置 Skills（50+）
随 OpenClaw 安装自动可用，包括：
- `weather` — 天气查询
- `github` — GitHub 操作
- `discord` — Discord 管理
- `coding-agent` — Coding agent 调度
- `1password` — 密码管理
- `tmux` — 终端会话管理
- ... 等等

查看所有内置 skills：
```bash
ls ~/.nvm/versions/node/*/lib/node_modules/openclaw/skills/
```

### 2. 自定义 Skills（24 个）
ClawKing 包含的 battle-tested skills：

| Skill | 用途 |
|-------|------|
| **brainstorming** | 创意/需求探索（任何创作前必用） |
| **planning-with-files** | 复杂任务的文件化计划 |
| **self-improving** | 自我改进协议 |
| **heartbeat-guide** | 心跳行为指南 |
| **canvas-design** | 可视化设计创作 |
| **frontend-design** | 前端 UI 设计 |
| **blueprint-infographic** | 信息图生成 |
| **design-os** | 产品设计系统 |
| **codebase-standards** | 代码规范发现 |
| **web-artifacts-builder** | Web 应用构建 |
| **webapp-testing** | Web 应用测试 |
| **crawl4ai** | 高性能网页爬取 |
| **gpt-researcher** | 深度研究 |
| **kb-rag** | 知识库 RAG |
| **find-skills** | 发现新 skills |
| **login-machine** | 浏览器自动登录 |
| **mcp-builder** | MCP server 开发 |
| **discord-ops** | Discord 运维 |
| **agent-guides** | Agent 能力文档 |
| **docx** | Word 文档操作 |
| **xlsx** | Excel 操作 |
| **pdf** | PDF 操作 |
| **product-manager-toolkit** | 产品管理工具 |
| **remotion-video-toolkit** | 视频制作 |

### 3. ClawHub 社区
社区贡献的 skills，通过 `clawhub` CLI 安装：

```bash
# 搜索
clawhub search "image generation"

# 安装
clawhub install skill-name

# 更新
clawhub update skill-name
```

浏览：<https://clawhub.com>

## 创建自己的 Skill

### 最简 Skill

```bash
mkdir -p ~/clawd/skills/my-skill
cat > ~/clawd/skills/my-skill/SKILL.md << 'EOF'
# My Skill

当用户要求 [触发条件] 时，执行以下步骤：

1. [步骤 1]
2. [步骤 2]
3. [步骤 3]

## 规则
- [规则 1]
- [规则 2]
EOF
```

就这样。AI 下次匹配到对应描述时会自动加载这个 skill。

### 进阶结构

```
advanced-skill/
├── SKILL.md              # AI 行为指令
├── references/
│   ├── api-docs.md       # API 参考（AI 按需读取）
│   └── examples.md       # 示例
├── scripts/
│   ├── main.py           # 执行脚本
│   └── utils.py
├── run.sh                # uv/venv 入口
├── pyproject.toml        # Python 依赖
└── templates/
    └── output.md         # 输出模板
```

### SKILL.md 最佳实践

1. **清晰的触发描述** — `description` 字段决定 AI 什么时候选择这个 skill
2. **具体的步骤** — 不要含糊，写清楚每一步
3. **包含规则/约束** — 什么不该做和什么该做同样重要
4. **引用相对路径** — 用 `references/xxx.md` 引用文档，AI 会按需读取
5. **控制 context 大小** — SKILL.md 本身尽量精简，详细文档放 references/

### Skill 注册

Skills 放在以下位置自动被发现：
- `~/clawd/skills/` — workspace skills（自定义）
- OpenClaw 安装目录的 `skills/` — 内置 skills
- `~/.agents/skills/` — 用户全局 skills

## 常用操作

```bash
# 查看已安装 skills
openclaw skills list

# 搜索社区 skills
clawhub search "keyword"

# 安装社区 skill
clawhub install skill-name

# 从目录安装
openclaw skills install ./path/to/skill
```
