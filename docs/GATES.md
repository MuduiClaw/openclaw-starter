# Project Gates — 门禁系统

> 自动化质量门禁，在 commit 和 push 时拦截不符合规范的变更。

## 为什么需要门禁？

AI 代理（Codex、Claude Code 等）可以高速产出代码，但高速产出 + 零质量把控 = 高速积累技术债。门禁系统在代码进入仓库的两个关键节点（commit 和 push）自动检查，确保：

- 每次 commit 都通过语法检查
- 每次 push 都遵循约定式提交格式
- 复杂变更必须先写 spec、再动手
- 代码变更必须伴随测试
- 提交记录不可伪造

## 安装

```bash
# 仅当前仓库生效（推荐）
bash workspace/scripts/setup-gates.sh

# 全局生效（所有 git 仓库）
bash workspace/scripts/setup-gates.sh --global

# 卸载
bash workspace/scripts/setup-gates.sh --uninstall
```

安装后，所有 `git commit` 和 `git push` 会自动触发门禁检查。

## 门禁列表

### Commit 门禁 (prepare-commit-msg)

| 门禁 | 触发条件 | 行为 |
|------|---------|------|
| **Prompt CHANGELOG** | 修改了 `prompts/` 目录下的文件 | 要求同时更新 `prompts/CHANGELOG.md` |
| **Scope Lock** | staged 文件 > 5 个 | 要求 commit message 包含 `[scope-ack]` |
| **Spec Gate** | `feat:/fix:/refactor:` + ≥2 个实现文件 + 项目有 `tasks/` 目录 | 要求 `[spec:slug]` 引用已审批的 spec |
| **REVIEWED** | 代码/配置文件变更（非 workspace 项目） | 要求 `REVIEWED=1 git commit` |
| **ShellCheck** | staged `.sh` 文件 | 自动运行 shellcheck |
| **JSON/YAML 语法** | staged `.json`/`.yml`/`.yaml` 文件 | 自动验证语法 |
| **Tree-hash 签章** | 每次成功 commit | 自动添加不可伪造的 `Pre-commit-gate:` trailer |
| **Project Gates** | 项目有 `.githooks/project-gates.sh` | 运行项目特有的检查 |

### Push 门禁 (pre-push)

| 门禁 | 触发条件 | 行为 |
|------|---------|------|
| **Conventional Commit** | 所有 commit | 要求 `type[(scope)]: description` 格式 |
| **Anti-salami-slicing** | 累积 ≥8 个实现文件 | 要求 spec 引用，防止大变更拆成小 commit 绕过 spec |
| **Tree-hash 验证** | 所有 commit | 验证 trailer 的 tree-hash 与实际一致 |
| **TDD 强制** | 有代码变更且检测到测试框架 | 要求 push 包含测试变更 |

### 门禁模式

- **Workspace 模式** (SOUL.md 或 HEARTBEAT.md 存在)：大多数门禁降级为警告（适合文档/配置/脚本类仓库）
- **Strict 模式** (默认)：门禁阻断不符合规范的操作

## 自定义

### 项目特有门禁

在项目根目录创建 `.githooks/project-gates.sh`，它会在全局门禁之后被 source：

```bash
#!/usr/bin/env bash
# .githooks/project-gates.sh
# Available vars: $COMMIT_MSG_FILE, $COMMIT_MSG_LINE, $STAGED_FILES, $STAGED_COUNT

# 示例：禁止直接修改 dist/ 目录
for f in $STAGED_FILES; do
  case "$f" in
    dist/*) 
      echo "⛔ BLOCKED: 不要直接修改 dist/ — 运行 npm run build"
      exit 1 ;;
  esac
done
```

### Telemetry (可选)

如果 `workspace/scripts/gate-telemetry.sh` 存在，门禁会记录触发/拦截事件到 `~/.openclaw/logs/gate-events.jsonl`。用于分析门禁效果。

不安装也不影响门禁功能。

## FAQ

### 如何临时跳过门禁？

```bash
git commit --no-verify -m "emergency fix"
git push --no-verify
```

⚠️ 跳过后 push 时会被 tree-hash 门禁拦截（没有 trailer）。如果确实需要跳过，commit 和 push 都要加 `--no-verify`。

### Commit 被拦截了怎么办？

看输出提示。常见原因：

- `缺 REVIEWED=1` → 加环境变量：`REVIEWED=1 git commit -m "..."`
- `staged files > 5 but no [scope-ack]` → 确认所有文件都该提交，然后在 message 加 `[scope-ack]`
- `ShellCheck failed` → 修复 shell 脚本中的问题
- `no spec reference` → 先写 spec（`tasks/SPEC-TEMPLATE.md`），走审批流程

### 支持哪些测试框架？

TDD 门禁自动检测：Vitest、Jest、pytest、Go、Rust (Cargo)、Bats。检测到任一框架，push 时有代码变更就必须有测试变更。

### 门禁和 CI 什么关系？

门禁在本地运行（commit/push 时），是第一道防线。CI 在服务器运行（push 后），是第二道防线。两者互补：
- 门禁快（< 5s），拦截明显问题
- CI 慢但全面（构建、测试套件、安全扫描）

### 如何添加新门禁？

1. 在 `prepare-commit-msg`（commit 时检查）或 `pre-push`（push 时检查）中添加逻辑
2. 遵循模式：检测条件 → 输出错误信息 → `failed=1`（或直接 `exit 1`）
3. 可选：添加 `_tel <gate-id> <pass|block>` 记录 telemetry
