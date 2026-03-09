# 教训条目格式定义

## 完整格式

```markdown
## [LSN-YYYYMMDD-XXX] pattern_key: 关键词短语

- **优先级**: critical | high | medium | low
- **状态**: pending | resolved | promoted → <目标文件>#<编号>
- **复现**: N 次（YYYY-MM-DD, YYYY-MM-DD, ...）
- **领域**: infra | content | product | trading | ops

### 摘要
一句话，不超过 20 字

### 触发场景 + 错误模式
什么情况下触发、错误的行为是什么、为什么错

### 正确做法
应该怎么做

### if-then
IF <具体触发条件> THEN <具体正确行为>
```

## 字段说明

- **ID**: `LSN-YYYYMMDD-<3位随机字母数字>`。用日期 + 随机字符，避免并发写入时序号冲突
- **pattern_key**: 2-4 个英文单词，用 `-` 连接。用于 grep 去重（如 `compaction-hallucination`、`script-review-before-commit`）
- **优先级**:
  - `critical` — 生产事故 / 数据丢失 / 安全问题 / Gateway 故障
  - `high` — 反复犯的错误 / 影响工作质量 / 耽误用户时间
  - `medium` — 单次错误已修 / 有 workaround
  - `low` — 小问题 / 偏好级
- **状态**:
  - `pending` — 已记录，未完全吸收
  - `resolved` — 已修复根因或建立了防护机制
  - `promoted → AGENTS.md#铁律7` — 已晋升到核心文件，标注具体位置
- **复现**: 每次复现追加日期。初次记录写 `1 次（YYYY-MM-DD）`
- **领域**: 便于按领域检索。一条教训只标一个主领域
- **if-then**: 行为触发器，用条件句。这是最重要的字段——它直接告诉未来的自己"遇到 X 就做 Y"

## 示例

### Critical 示例

```markdown
## [LSN-20260307-K2F] pattern_key: compaction-hallucination

- **优先级**: critical
- **状态**: promoted → IDENTITY.md#9
- **复现**: 3 次（2026-03-06, 2026-03-07, 2026-03-07）
- **领域**: infra

### 摘要
Compaction 诊断结论不是事实，新 session 无条件继承导致错误传播

### 触发场景 + 错误模式
用户发语音消息 → session 误判为文档附件 → compaction 固化错误诊断 → 后续 3+ session 继承"看不到附件"的错误结论并反复尝试修复不存在的问题

### 正确做法
compaction summary 中的归因/诊断不可信。遇到"看不到 X"先用 message(action=read) 验证原始数据

### if-then
IF 继承 compaction 中的诊断结论 THEN 先用工具验证原始数据再行动
```

### High 示例

```markdown
## [LSN-20260218-R4M] pattern_key: script-review-before-commit

- **优先级**: high
- **状态**: pending
- **复现**: 2 次（2026-02-09, 2026-02-18）
- **领域**: ops

### 摘要
脚本修改后未 review 直接提交，引入语法错误

### 触发场景 + 错误模式
修改 shell 脚本 → 自信"小改动不会出错" → 不跑 shellcheck → push 后 cron 执行失败

### 正确做法
shell 脚本修改后 `bash -n script.sh` + `shellcheck script.sh` 再提交

### if-then
IF 修改 shell 脚本 THEN `bash -n` + `shellcheck` 验证后再 commit
```

### Medium 示例

```markdown
## [LSN-20260305-P8C] pattern_key: xargs-macos-no-r-flag

- **优先级**: medium
- **状态**: resolved
- **复现**: 1 次（2026-03-05）
- **领域**: infra

### 摘要
macOS xargs 没有 -r 参数

### 触发场景 + 错误模式
写脚本用了 `xargs -r`，Linux 习惯带入 macOS，命令报错

### 正确做法
macOS 上用 `xargs` 不加 `-r`，或用 `gxargs -r`（需 brew install findutils）

### if-then
IF 在 macOS 上写 xargs 命令 THEN 不用 -r 参数，或用 gxargs
```

## 去重操作

新增教训前：
1. `grep "pattern_key:.*关键词" memory/archive/lessons.md`
2. 命中 → 找到原条目，更新复现计数（追加日期），不新建
3. 未命中 → 新建条目，pattern_key 用 2-4 个英文单词描述核心模式
