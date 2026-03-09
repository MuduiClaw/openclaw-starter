---
name: design-os
description: Structured product design planning from vision to implementation handoff. Use when user asks to "plan a product design", "design tokens", "shape a section", "design screen", or "export product plan". Generates specs, sample data, React components, and coding agent handoff packages.
description_zh: "结构化产品设计规划：从愿景到开发交接。生成设计规范、示例数据、React 组件和 Coding Agent 交接包。"
---

# Design OS — Skill

> Adapted from [Design OS](https://github.com/buildermethods/design-os) by Brian Casel.
> Structured product design planning: vision → design system → shell → sections → screen designs → export handoff.

## The Planning Flow

Design OS follows a strict sequential workflow. Each step builds on the previous:

```
1. Product Vision  →  2. Design Tokens  →  3. App Shell
                                                  ↓
         6. Export  ←  5. Screenshot  ←  4. Sections (shape → data → screen)
```

| Step | Command | Trigger | Reference |
|------|---------|---------|-----------|
| 1 | **Product Vision** | "define product", "product vision" | `references/product-vision.md` |
| 1b | **Product Roadmap** | "update roadmap", "add sections" | `references/product-roadmap.md` |
| 1c | **Data Shape** | "update data shape", "define entities" | `references/data-shape.md` |
| 2 | **Design Tokens** | "choose colors", "design tokens", "typography" | `references/design-tokens.md` |
| 3 | **Design Shell** | "design shell", "app navigation", "layout" | `references/design-shell.md` |
| 4a | **Shape Section** | "shape section", "define section spec" | `references/shape-section.md` |
| 4b | **Sample Data** | "update sample data", "regenerate data" | `references/sample-data.md` |
| 4c | **Design Screen** | "design screen", "create UI components" | `references/design-screen.md` |
| 5 | **Screenshot** | "screenshot design", "capture screen" | `references/screenshot-design.md` |
| 6 | **Export Product** | "export product", "generate handoff" | `references/export-product.md` |

## How It Works

1. **Read the relevant reference file** for the step being invoked
2. **Also read `references/agents.md`** for overall Design OS directives and file structure
3. **Follow the reference instructions** step by step
4. **Read `references/screen-design-guide.md`** when creating any screen designs (Step 4c)

## Workspace Conventions

All files are stored relative to the **target project root**:

```
{project}/
├── product/                           # Product definition (portable)
│   ├── product-overview.md
│   ├── product-roadmap.md
│   ├── data-shape/
│   │   └── data-shape.md
│   ├── design-system/
│   │   ├── colors.json
│   │   └── typography.json
│   ├── shell/
│   │   └── spec.md
│   └── sections/
│       └── {section-id}/
│           ├── spec.md
│           ├── data.json
│           ├── types.ts
│           └── *.png
│
├── src/                               # Screen design components
│   ├── shell/
│   │   ├── components/
│   │   │   ├── AppShell.tsx
│   │   │   ├── MainNav.tsx
│   │   │   ├── UserMenu.tsx
│   │   │   └── index.ts
│   │   └── ShellPreview.tsx
│   └── sections/
│       └── {section-id}/
│           ├── components/            # Exportable (props-based)
│           │   ├── {Component}.tsx
│           │   └── index.ts
│           └── {ViewName}.tsx         # Preview wrapper
│
└── product-plan/                      # Export package (generated)
    ├── README.md
    ├── product-overview.md
    ├── prompts/
    ├── instructions/
    ├── design-system/
    ├── data-shapes/
    ├── shell/
    └── sections/
```

## OpenClaw Integration

### Canvas Preview
Instead of requiring a local Vite dev server, use **Canvas** to preview generated React components:
- After generating screen design components, render them in Canvas for instant visual feedback
- This replaces the original Design OS's local dev server preview

### Subagent for Heavy Work
- **Screen design creation** (Step 4c) involves generating multiple React components — spawn a subagent if the section has complex UI requirements
- **Export generation** (Step 6) is 1000+ lines — **always spawn a subagent** for this step. Read the reference in sections: lines 1-200 (overview + templates), 200-600 (section generation), 600+ (prompts + README).

### Memory
- After completing product vision, note the product name and key sections in daily notes
- Design tokens (colors/fonts) are worth remembering for consistency across sessions

## Key Design Principles

From the `screen-design-guide` reference (read it for every screen design):

- **Bold aesthetic direction** — Choose a clear visual concept, never generic
- **Tailwind CSS v4** — No `tailwind.config.js`, use built-in utilities
- **Props-based components** — All data and callbacks via props, never import data directly
- **Mobile responsive + dark mode** — Always
- **Design tokens applied** — Product's colors and typography, not defaults

## Adaptation Notes

- Original uses Claude Code slash commands → We trigger via natural language
- Original uses `AskUserQuestion` tool → We ask the user directly in conversation
- Original requires Vite dev server for preview → We can use Canvas for quick preview
- Original requires Playwright MCP for screenshots → We use `browser` tool or Canvas snapshot
- All original command logic is preserved in the reference files
- The React application part of Design OS is NOT included — we only use the planning workflow and component generation
