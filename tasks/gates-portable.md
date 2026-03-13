# Spec: Starter 门禁系统文档化 + 可移植化

> **Status**: approved (Oracle PASS R2, 2026-03-13 02:03)
> **Author**: Partner
> **Created**: 2026-03-13
> **Oracle R1**: ITERATE — 4 issues (全局 hook 入侵性 / 脚本依赖缺失 / 复制来源不明 / 专有环境变量)

## 一句话

让 ClawKing 用户 clone 后能一键激活门禁系统，并理解它在保护什么。

## 背景

门禁系统（21 gates）目前完全依赖我们本地环境：
- hooks 在全局 `~/.gitconfig core.hooksPath=<workspace>/.githooks/`，别人 clone 后不生效
- scripts（telemetry、spec-verify、task-deliver 等）在 `<workspace>/scripts/`，starter repo 里没有
- `prepare-commit-msg` 有硬编码路径 `CLAWD_ROOT="/path/to/workspace"`
- starter 的 `workspace/.githooks/` 有旧版 hooks（无 tree-hash、无 telemetry）
- 零文档——用户不知道有这套系统，更不知道如何使用

**结果**：别人部署 openclaw 后，门禁系统形同虚设。

## 交付物

### T1: hooks 可移植化 + 依赖脚本打包
- **改什么**: `workspace/.githooks/prepare-commit-msg` + `workspace/.githooks/pre-push` + `workspace/scripts/` 目录
- **做什么**:
  - 从 `<workspace>/.githooks/` 同步最新版本到 `workspace/.githooks/`
  - **路径发现**：不用任何专有环境变量（`$CLAWD_DIR` 等），统一用 `git rev-parse --show-toplevel` 动态获取 `$REPO_ROOT`。hooks 自身位于 `<workspace>/.githooks/`，`workspace` 即 hooksPath 的父目录。所有脚本路径相对 `$REPO_ROOT` 或 hooks 所在目录解析
  - **硬编码清除**：删除 `CLAWD_ROOT="/path/to/workspace"` 等所有绝对路径
  - **依赖脚本打包**：将以下脚本清洗后提交到 `workspace/scripts/`（开箱即用，不需要运行时复制）：
    - `gate-telemetry.sh` — telemetry 日志记录
    - `spec-verify.sh` — spec 门禁（如果 hooks 引用）
    - `task-start.sh` / `task-selftest.sh` — task 生命周期（如果 hooks 引用）
  - **Graceful skip**：所有被 hooks 引用的外部脚本，如果文件不存在则静默跳过（不阻塞 commit/push），确保最小安装也能正常工作
  - `project-gates.sh` 路径保持相对 repo root（`${repo_root}/.githooks/project-gates.sh`），已经是
- **怎么验**: 在 `/tmp/test-repo` 做 `git init` → 设 hooksPath → commit → 确认 gates 触发且不报错；在脚本不存在的极简环境下也能 commit/push 成功
- **不做什么**: 不改 gate 逻辑本身，只改路径发现机制 + 打包依赖
- **影响**: 所有 4 个项目（hooks 是共享的，同步后我们的也会用新版）

### T2: 安装脚本
- **改什么**: `workspace/scripts/setup-gates.sh`（新建）
- **做什么**:
  - 检测 workspace dir（找 `SOUL.md` 或 `HEARTBEAT.md` 向上搜索）
  - **默认 per-repo**：`git config core.hooksPath <workspace>/.githooks/`（仅当前仓库生效）
  - **可选 `--global`**：加全局配置，但必须输出强警告："⚠️ 这会接管你所有 Git 仓库的 hooks"，用户需确认 `y/N`
  - 检测 `workspace/scripts/gate-telemetry.sh` 等文件是否存在，不存在则提示"telemetry 未启用（不影响核心功能）"
  - 输出安装结果 + 简要说明哪些 gates 已激活
  - 支持 `--uninstall` 移除 hooksPath 配置
- **怎么验**: `bash workspace/scripts/setup-gates.sh && git config core.hooksPath` 输出正确路径；`--global` 模式需要用户确认
- **不做什么**: 不自动修改用户的 git workflow，不强制安装
- **影响**: 新文件，不影响现有用户

### T3: 门禁文档
- **改什么**: `docs/GATES.md`（新建）
- **内容**:
  - 系统概述：什么是门禁、为什么需要
  - 21 个 gates 分类说明（hook / ci / script / wrapper / hint）
  - 三态系统：active / degraded / inactive
  - 安装步骤（引用 setup-gates.sh）
  - 自定义指南：如何加项目特有 gates（project-gates.sh）
  - FAQ：如何跳过（`--no-verify`）、如何查看 telemetry、如何添加新 gate
- **怎么验**: 文档存在、链接有效、步骤可执行
- **不做什么**: 不写开发者 API 文档（gates.ts 内部实现），只写用户使用文档
- **影响**: 新文件

### T4: README 更新
- **改什么**: `README.md` 加门禁系统 section 引用 `docs/GATES.md`
- **怎么验**: README 中有门禁相关 section
- **不做什么**: 不大改 README 结构
- **影响**: 轻量修改

## 不做什么

- 不改 gate 逻辑（门禁规则不动）
- 不改 CI workflows（GitHub Actions 独立于 hooks）
- 不改 infra-dashboard 的 gates page/API（那是展示层）
- 不做自动同步机制（hooks 更新后需手动同步到 starter）

## 执行顺序

T1（可移植化 + 打包）→ T2（安装脚本）→ T3（文档）→ T4（README）

T1 必须先做——后续都依赖 hooks 能在非我们环境跑通。

## 风险

1. **T1 影响现有项目**: hooks 路径发现逻辑变了，可能影响我们 4 个项目的 commit/push。对策：改完后在 clawd + infra-dashboard 各做一次 commit+push 验证
2. **路径发现极端情况**: 极少数用户可能不在 git repo 内运行。对策：`git rev-parse --show-toplevel` 失败时 graceful exit，不阻塞
3. **telemetry 缺失降级**: 用户没有 telemetry 脚本时，`_tel` 已有 `|| true` 保底。dashboard 上看不到数据。可接受——telemetry 是增强不是核心
4. **脚本打包膨胀**: 清洗后的脚本可能仍引用我们特有的文件（tasks/ 目录、.task-lock/ 等）。对策：清洗时确保所有外部引用都有 graceful skip
