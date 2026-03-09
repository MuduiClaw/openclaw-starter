# MEMORY.md - 核心知识索引

> 精简索引。详细信息 → `memory_search` 或 `read memory/archive/*.md`
> 归档：`lessons.md` | `infrastructure.md` | `decisions.md`

---

## 🧠 核心认知

- **CLI > MCP**: AI 用 CLI 自学，MCP 是多余翻译层。仅在无 CLI 或需 OAuth 时用
- **Context Isolation**: 大文件/多文件/深度研究 → spawn subagent
- **时区**: 注意 API 返回 UTC，转换后使用

## 📚 项目速查

（在这里记录你的项目索引）

## 💡 核心教训

> 完整表 → `memory/archive/lessons.md`

- 独立验证：所有任务需提供验证证据
- 源头验证：配置从 config 取，不从记忆/compaction 取
- 用户消息优先，后台任务不抢占
- 修问题先 review 全部历史，草率修复 = 二次返工
