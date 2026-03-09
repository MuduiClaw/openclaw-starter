---
name: codebase-standards
description: Auto-discover, index, and inject coding standards from any codebase. Use when user asks to "discover standards", "extract conventions", "document patterns", or "shape a spec" for a project.
description_zh: "自动发现和索引代码库的编码规范：提取约定、记录模式、生成规范文档。"
---

# Codebase Standards — Skill

> Adapted from [Agent OS](https://github.com/buildermethods/agent-os) by Brian Casel.
> Auto-discover, index, and inject coding standards from any codebase. Plan products and shape feature specs with standards-aware context.

## Available Commands

| Command | Trigger | Reference |
|---------|---------|-----------|
| **Discover Standards** | "discover standards", "extract conventions", "document patterns" | `references/discover-standards.md` |
| **Inject Standards** | "inject standards", "load standards", "apply conventions" | `references/inject-standards.md` |
| **Index Standards** | "rebuild index", "update standards index" | `references/index-standards.md` |
| **Plan Product** | "plan product", "define product", "product mission" | `references/plan-product.md` |
| **Shape Spec** | "shape spec", "plan feature", "spec out" | `references/shape-spec.md` |

## How It Works

1. **Read the relevant reference file** for the command being invoked
2. **Follow the reference instructions** step by step
3. **Interact conversationally** — ask the user questions directly (no special tools needed)
4. **Write files** to the project's standards/product/specs directories

## Workspace Conventions

All files are stored relative to the **target project root** (not the agent workspace):

```
{project}/
├── agent-os/
│   ├── standards/          # Discovered coding standards
│   │   ├── index.yml       # Standards index for quick matching
│   │   ├── api/            # Standards by area
│   │   ├── database/
│   │   ├── frontend/
│   │   └── global/
│   ├── product/            # Product documentation
│   │   ├── mission.md
│   │   ├── roadmap.md
│   │   └── tech-stack.md
│   └── specs/              # Feature specifications
│       └── {YYYY-MM-DD-HHMM-feature-slug}/
│           ├── plan.md
│           ├── shape.md
│           ├── standards.md
│           └── references.md
```

If the project root is the current workspace (`$HOME/clawd`), files go in `./agent-os/`. If working on a different project, ask the user for the project path first.

## OpenClaw Integration

- **Subagent for large codebases**: If the codebase has 100+ files to scan, spawn a subagent for the discovery phase to keep the main session clean.
- **Memory**: After discovering standards for a project, consider noting key conventions in daily notes for cross-session awareness.
- **Context Isolation**: When analyzing multiple files for `discover-standards`, read files via subagent if the total content exceeds ~50KB.

## Adaptation Notes

- Original Agent OS uses `AskUserQuestion` tool → We ask the user directly in conversation
- Original uses Claude Code slash commands → We trigger via natural language
- Original has profile-based config with inheritance → Simplified to per-project `agent-os/` directory
- All original command logic is preserved in the reference files
