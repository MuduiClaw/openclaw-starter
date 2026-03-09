---
name: crawl4ai
description: High-performance web crawler that converts web pages to clean Markdown.
---
# Crawl4AI Skill

## Description

A high-performance web crawler designed for AI agents. It fetches web pages and converts them into clean, LLM-friendly Markdown, stripped of ads and navigation clutter.

## When to Use

Use this skill when you need to:

- Read the content of an external URL.
- Scrape documentation or blog posts from the web.
- Extract clear text/markdown from a messy webpage.
- Perform "Search & Browse" tasks where you specific URLs are known.

**Do NOT** use this for:

- Complex interactions (logging in, clicking buttons, filling forms) -> Use `Browser Subagent`.
- Local file reading.

## How to Use

This skill uses a Python script `engine.py` managed by `uv` (or `pip`).

### Command

To crawl a URL, run the following command structure using `run_command`.

**Important**:

1. You must run this from the skill directory or provide the full path.
2. The `uv` command is preferred as it handles virtual environments automatically.

```bash
# Option 1: Using uv (Recommended)
cd "$HOME/clawd/skills/crawl4ai"
uv run scripts/engine.py --url "https://example.com"

# Option 2: Using python (if uv is not available, requires dependencies installed)
cd "$HOME/clawd/skills/crawl4ai"
pip install -r pyproject.toml # (pseudo-command, install dependecies first)
python scripts/engine.py --url "https://example.com"
```

### Output

The command prints a JSON object to stdout.

```json
{
  "success": true,
  "url": "...",
  "content": "# Markdown Content...",
  "metadata": {...}
}
```

Always check "success". If false, checking "error".
