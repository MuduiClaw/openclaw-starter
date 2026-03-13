# Project Gates — 门禁系统

> 19 层自动化质量门禁，覆盖从构思到部署的完整 Loop。
> 每个门禁都是**物理执行**的——能阻断操作，不只是提示。

![门禁 Dashboard — 19 个门禁按 Loop 阶段展示，含触发/拦截统计](https://img.mudui.me/docs/gates/gates-overview-fe16ecce.png)

## 为什么需要门禁？

AI 代理（Codex、Claude Code 等）可以高速产出代码，但高速产出 + 零质量把控 = 高速积累技术债。

门禁系统在代码流转的关键节点自动检查，确保：

- 复杂变更必须先写 spec、过 Oracle 审查
- 每次 commit 都通过语法检查 + 签章防伪
- 每次 push 都有格式、类型、测试、lint 全链路验证
- 部署后自动验收生产环境
- 系统级操作有安全阀

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

---

## 门禁全览（19 个，按 Loop 阶段）

门禁按 **Loop 四步 + 系统防护** 组织：

```
① 想清楚 → ② 执行 → ③ 验证 → ④ 交付 → 系统防护
```

### ① 想清楚（Plan）— 2 个门禁

| ID | 名称 | 执行方式 | 触发条件 | 阻断行为 |
|---|---|---|---|---|
| `script-spec-review` | **Oracle Spec 审查** | 脚本 | ≥3 步复杂任务启动前 | `spec-review.sh` 调 Gemini 3.1 Pro 逐 7 维度审查，ITERATE 则 exit 1。3 轮未通过自动 ESCALATE |
| `hook-spec` | **Spec 引用 + 状态验证** | Git Hook | commit 含 `[spec:slug]` 或 push ≥8 impl 文件 | prepare-commit-msg 验证 spec 文件存在 + status 为 approved/in_progress/done。pre-push Gate 2 强制大变更附带 spec 引用 |

**设计意图**：先想清楚再动手。Oracle 替代人工 review，spec 引用防止"拿到任务直接冲"。

### ② 执行（Execute）— 3 个门禁

| ID | 名称 | 执行方式 | 触发条件 | 阻断行为 |
|---|---|---|---|---|
| `script-spawn-preflight` | **Coding Agent 派发门禁** | 脚本 | spawn Codex/Claude Code 前 | `spawn-agent.sh` 检查 3 项：① 是 git repo ② AGENTS.md 存在 ③ baseline build 通过。不过则 exit 1 |
| `hook-shellcheck` | **Shell 语法检查** | Git Hook | commit 包含 `.sh` 文件 | `shellcheck -S warning` 不过则阻断 commit（Workspace 模式降级为警告） |
| `hook-json-yaml` | **JSON/YAML 语法检查** | Git Hook | commit 包含 `.json` / `.yml` / `.yaml` | `python3 json.tool` / `yaml.safe_load` 验证语法 |

**设计意图**：执行阶段保证基本质量——agent 有正确的项目上下文，配置/脚本语法无误。

### ③ 验证（Verify）— 5 个门禁

| ID | 名称 | 执行方式 | 触发条件 | 阻断行为 |
|---|---|---|---|---|
| `hook-typecheck` | **TypeScript 类型检查** | Git Hook | push 含 .ts/.tsx + 项目有 tsconfig.json | pre-push 跑 `npx tsc --noEmit` (30s timeout)，有错误则 block push |
| `hook-eslint` | **ESLint 检查** | Git Hook | push 含 .ts/.tsx/.js/.jsx + 项目有 eslint config | pre-push 跑 `npx eslint` (30s timeout)，有错误则 block push |
| `hook-tdd` | **TDD 门禁** | Git Hook | push 含代码文件变更 + 检测到测试框架 | 整个 push 范围内有代码变更必须有对应测试变更，否则 block push |
| `ci-eval-regression` | **Eval 回归检测** | CI | push 含 `prompts/` 改动 | Gemini API 对 15 样本真跑评分，pass 数下降 >1 则 CI 失败 |
| `ci-config-drift` | **Config 漂移检测** | CI | push 到 main | 对比 cron prompt 文件与运行时 cron job 配置，不一致则 CI 失败 |

**设计意图**：push 时全链路验证。TDD 防止"改了代码不写测试"，typecheck/eslint 防止类型和规范错误，CI 防止 prompt 回归和配置漂移。

### ④ 交付（Ship）— 6 个门禁

| ID | 名称 | 执行方式 | 触发条件 | 阻断行为 |
|---|---|---|---|---|
| `hook-commit-format` | **Conventional Commits** | Git Hook | push 时逐 commit 验证 | 正则检查 `type[(scope)]: description` 格式，不匹配 block push |
| `hook-tree-hash` | **Trailer 防伪造** | Git Hook | push 时逐 commit 验证 | 提取 commit tree hash 与 `Pre-commit-gate:` trailer 比对，不匹配/缺失/legacy 均 block |
| `hook-scope-lock` | **提交范围锁** | Git Hook | commit staged >5 个文件 | 需 `[scope-ack]` 确认，防止 `git add -A` 混入无关文件 |
| `hook-changelog` | **Prompt CHANGELOG** | Git Hook | commit 含 `.prompt.md` 文件 | 同时要求 `prompts/CHANGELOG.md` 在 staged 中 |
| `ci-precommit-verify` | **Tree-hash CI 校验** | CI | push 到 main | 服务端二次验证 tree-hash trailer，拦截绕过本地 hook 的 commit |
| `script-verify-production` | **生产环境验收** | 脚本 | 部署后自动触发 | HTTP 健康检查 + 响应大小 + 错误字符串检测。失败自动尝试重启服务，仍失败则写告警通知 Discord |

**设计意图**：交付时的最终防线。tree-hash 双层（本地 + CI）保证不可绕过；scope-lock 防止范围蔓延；生产验收确保部署真正成功。

### 系统防护 — 3 个门禁

| ID | 名称 | 执行方式 | 触发条件 | 阻断行为 |
|---|---|---|---|---|
| `wrapper-self-destruct` | **Gateway 自杀防护** | CLI Wrapper | gateway 进程树内执行 `openclaw gateway stop/restart` | 检测 PID 祖先链，匹配则 exit 1 |
| `wrapper-config-preflight` | **配置变更预检** | CLI Wrapper | 执行 `openclaw gateway config.patch` | 先跑 `config validate`，失败则 exit 1 + 写审计日志 |
| `script-gateway-restart` | **Gateway 重启门禁** | 脚本 | 任何组件请求 gateway restart | validate → 写请求文件 → 等人工 Discord DM 确认后才执行 |

**设计意图**：保护基础设施。Agent 不能把自己跑着的 gateway 弄挂，配置变更有审计链，重启需人工确认。

---

## 门禁模式

- **Workspace 模式** — 项目根有 `SOUL.md` 或 `HEARTBEAT.md`：shellcheck 等门禁降级为**警告**，不阻断（适合文档/配置类仓库）
- **Strict 模式** — 默认：门禁阻断不符合规范的操作

---

## Telemetry（门禁触发统计）

每个门禁在 **pass（通过）和 block（拦截）** 时都上报事件到 `~/.openclaw/logs/gate-events.jsonl`。

```json
{"ts":"2026-03-13T01:02:02Z","gate":"hook-tree-hash","result":"pass","repo":"infra-dashboard"}
```

Dashboard 的门禁页面自动读取这个文件，显示每个门禁的 7 天触发数和拦截数。

**Telemetry 不影响门禁功能**——即使 `gate-telemetry.sh` 不存在或不可执行，门禁本身照常工作（fire-and-forget 模式）。

---

## 辅助工具

### git-push-safe.sh — TDD 自动补救

当 TDD 门禁（`hook-tdd`）拦截 push 时，可以用这个脚本自动补救：

```bash
bash scripts/git-push-safe.sh
```

工作流程：
1. 先尝试正常 `git push`
2. 如果被 TDD 门禁拦截，自动检测缺少测试的代码文件
3. 调用 Codex 生成对应测试 → Claude Code fallback → 脚手架兜底
4. 自动 commit 测试 → 重新 push

### spawn-agent.sh — Agent 派发门禁

Spawn coding agent（Codex / Claude Code）前的前置检查：

```bash
bash scripts/spawn-agent.sh <project-dir>
```

三项检查：
1. **是 git repo** — 不是则拒绝
2. **AGENTS.md 存在** — agent 需要项目上下文
3. **Baseline build 通过** — 不在坏的 build 上浪费 token

---

## 任务看板（Spec-Driven）

门禁与任务看板深度集成。任务生命周期：

![任务看板 — Spec-Driven 状态流转，从 draft 到 done](https://img.mudui.me/docs/tasks/tasks-board-21d50545.png)

```
draft → Oracle 审查 → approved → in_progress → done
```

- **Spec 门禁** (`hook-spec`) 确保代码变更引用了 approved 状态的 spec
- **Anti-salami-slicing** (pre-push Gate 2) 防止大变更拆成小 commit 绕过 spec 要求
- Dashboard 任务页面自动读取 `tasks/*.md`，展示进度和状态

---

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

### 添加新门禁

1. 在 `prepare-commit-msg`（commit 时）或 `pre-push`（push 时）中添加检查逻辑
2. 遵循模式：检测条件 → 输出错误信息 → `failed=1`（或直接 `exit 1`）
3. 添加 `_tel <gate-id> <pass|block>` 记录 telemetry（pass 和 block 都要记录）
4. 在 `infra-dashboard/lib/gates.ts` 注册门禁定义

---

## FAQ

### 如何临时跳过门禁？

```bash
git commit --no-verify -m "emergency fix"
git push --no-verify
```

⚠️ 跳过后 push 时会被 tree-hash 门禁拦截（没有 trailer）。如果确实需要跳过，commit 和 push 都要加 `--no-verify`。即使本地跳过，CI 层的 `ci-precommit-verify` 仍会标记。

### Commit 被拦截了怎么办？

看输出提示。常见原因：

- `缺 REVIEWED=1` → `REVIEWED=1 git commit -m "..."`
- `staged files > 5 but no [scope-ack]` → 确认所有文件都该提交，在 message 加 `[scope-ack]`
- `ShellCheck failed` → 修复 shell 脚本中的问题
- `no spec reference` → 先写 spec（`tasks/SPEC-TEMPLATE.md`），走审批流程

### Push 被拦截了怎么办？

- `Bad commit format` → `git commit --amend` 修改 message 为 `type(scope): description`
- `TDD gate` → `bash scripts/git-push-safe.sh` 自动补测试
- `Typecheck/ESLint failed` → 修复代码中的类型/lint 错误
- `Tree-hash mismatch` → `git commit --amend --no-edit` 重新生成 trailer

### 支持哪些测试框架？

TDD 门禁自动检测：**Vitest**、**Jest**、**pytest**、**Go test**、**Rust (Cargo)**、**Bats**。检测到任一框架，push 时有代码变更就必须有测试变更。

### 门禁和 CI 什么关系？

```
本地门禁 (commit/push)  →  CI (push 后)
   第一道防线                第二道防线
   快 (<5s)                 慢但全面
   可跳过 (--no-verify)     不可跳过
```

Tree-hash 是唯一同时有本地 + CI 双层执行的门禁，确保即使本地跳过也能在 CI 拦截。
