# Prompt 变更治理

> 报告来源：Peter Steinberger 方法论 — "Prompt 改动走与代码同等流程：PR、review、测试、changelog"

## 原则

1. **Prompt = Code** — 每个 cron prompt 是一份可执行的指令，改动必须可追溯
2. **版本化** — 每个 prompt 文件有 frontmatter 含 version / last_modified / job_id
3. **Changelog** — 所有变更记录在 `CHANGELOG.md`，格式：日期 + job + 变更 + 原因
4. **Review** — 改 prompt 后必须 `cron run <jobId>` 验证，检查实际产出
5. **回滚** — git history 即回滚能力，出问题 `git checkout HEAD~1 -- prompts/cron/<file>`

## 目录结构

```
prompts/
├── README.md          # 本文件（治理规则）
├── CHANGELOG.md       # 变更日志
├── cron/              # Cron job prompts（SSoT）
│   ├── blog-monitor.prompt.md
│   ├── auto-dispatch.prompt.md
│   └── ...
└── sync-prompts.sh    # 从 cron API 导出 prompt 快照
```

## 工作流

### 改 Prompt
1. 编辑 `prompts/cron/<slug>.prompt.md`
2. 更新 frontmatter: version bump + last_modified
3. 更新 `CHANGELOG.md`
4. `cron update <jobId>` 同步到 Gateway
5. `cron run <jobId>` 验证产出
6. `git add prompts/ && git commit -m "prompt(<slug>): <变更摘要>"`

### 新建 Cron Job
1. 先在 `prompts/cron/` 写 prompt 文件
2. `cron add` 创建 job，记录 job_id 到 frontmatter
3. `cron run` 验证
4. Commit

### 审计
- `prompts/cron/` 文件 vs `cron list` 实际 prompt：定期 diff 检查漂移
- `sync-prompts.sh --diff` 可以对比差异

## 命名规则

文件名: `{slug}.prompt.md`
- 用英文 slug，全小写，连字符分隔
- Frontmatter 含原始中文 job_name

## Commit 规范

```
prompt(<slug>): <一句话变更>

原因: <为什么改>
验证: cron run <jobId> → <结果摘要>
```
