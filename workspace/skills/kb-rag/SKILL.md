---
name: kb-rag
description: Knowledge Base RAG - retrieve and answer questions from indexed knowledge (blog translations, skills docs, project docs, memory archives). Use when user asks questions that might be answered by accumulated knowledge, wants to search across the knowledge base, or asks "我们知识库里有什么关于X的". Also use for ingesting new content into the knowledge base.
description_zh: "知识库 RAG 检索：从已索引的知识（博客翻译、技能文档、项目文档、记忆归档）中检索和回答问题。"
---

# Knowledge Base RAG

## Architecture

- **Backend**: qmd (BM25 + vector + hybrid reranker)
- **LLM**: Antigravity proxy (Gemini/Claude, $0 cost)
- **Collections**: 7 indexed collections, auto-updated every 5 min by OpenClaw

## Collections

| Collection | Content | Path |
|---|---|---|
| kb-articles | Blog translations & analysis | `output/blog-translations/` |
| kb-skills | Skill documentation | `skills/**/SKILL.md` |
| kb-captures | Conversation insight captures | `content-pipeline/captures/` |
| kb-docs | Project documentation | `docs/` |
| memory-dir | Daily notes & archives | `memory/` |
| memory-root | Core memory index | `MEMORY.md` |
| memory-alt | Alt memory | `memory.md` |

## Query (RAG Pipeline)

Run the RAG script for end-to-end retrieve + generate:

```bash
python3 skills/kb-rag/scripts/rag_query.py "question"
```

Options:
- `-c <collection>` — limit to specific collection (e.g. `kb-articles`)
- `-k <N>` — top-K chunks (default 8)
- `-m <model>` — LLM model (default `gemini-3.1-pro-high`)
- `--retrieve-only` — skip LLM, just show retrieved chunks
- `--json` — JSON output

Examples:
```bash
# General KB question
python3 skills/kb-rag/scripts/rag_query.py "OpenClaw 2026.2.13 有什么重要更新"

# Search only blog articles
python3 skills/kb-rag/scripts/rag_query.py "Agent 自主付费" -c kb-articles

# Just retrieve, no generation
python3 skills/kb-rag/scripts/rag_query.py "Peter Steinberger 的创业哲学" --retrieve-only
```

## Manual Search (without LLM)

Direct qmd commands for quick lookups:

```bash
# Hybrid search (best quality)
qmd query "search terms" -n 5

# Vector similarity (better for semantic/fuzzy)
qmd vsearch "search terms" -n 5

# Full-text BM25 (exact term matching)
qmd search "search terms" -n 5

# Limit to collection
qmd query "search terms" -c kb-articles -n 5
```

## Ingest New Content

### Add individual files
New `.md` files dropped into indexed directories are auto-picked up on next `qmd update && qmd embed`.

### Add new collection
```bash
qmd collection add /path/to/dir --name collection-name --mask "**/*.md"
qmd update && qmd embed
```

### Manual re-index
```bash
qmd update    # re-index all collections
qmd embed     # regenerate embeddings
```

Note: OpenClaw runs `qmd update` every 5 minutes automatically. Run manually only when immediate indexing is needed.

## Known Limitations

- Reranker (qwen3-reranker-0.6b) is weak on Chinese structured content — if results seem off, try `qmd vsearch` (pure vector) instead of `qmd query` (hybrid)
- Large files get chunked at 800 tokens with 15% overlap — very long articles may lose cross-chunk context
