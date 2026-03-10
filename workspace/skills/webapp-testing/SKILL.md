---
name: webapp-testing
description: Toolkit for interacting with and testing local web applications using Playwright. Supports verifying frontend functionality, debugging UI behavior, capturing browser screenshots, and viewing browser logs.
description_zh: "用 Playwright 测试本地 Web 应用：验证前端功能、调试 UI、截图、查看浏览器日志。"
---

# Web Application Testing

To test local web applications, use Playwright to connect to existing Chrome CDP instances.

> **⚠️ 铁律：禁止 `chromium.launch()`。一律 `connect_over_cdp()` 复用已有 Chrome 实例。**
> Mac mini 上最多 3 个 Chrome 实例（LaunchAgent 管理），新页面开 tab，不开新进程。
> 违反此规则会导致僵尸 Chrome 进程泄漏。

**Helper Scripts Available**:
- `scripts/with_server.py` - Manages server lifecycle (supports multiple servers)

**Always run scripts with `--help` first** to see usage. DO NOT read the source until you try running the script first and find that a customized solution is absolutely necessary. These scripts can be very large and thus pollute your context window. They exist to be called directly as black-box scripts rather than ingested into your context window.

## Chrome CDP 实例（只连接，不启动）

| 用途 | CDP 端口 | 何时用 |
|------|----------|--------|
| 截图/测试/无登录态 | `18800` (openclaw headless) | **默认选这个** |
| 需要登录态的站点 | `18802` | 已登录的 Chrome 实例 |

## Decision Tree: Choosing Your Approach

```
User task → Is it static HTML?
    ├─ Yes → Read HTML file directly to identify selectors
    │         ├─ Success → Write Playwright script using selectors
    │         └─ Fails/Incomplete → Treat as dynamic (below)
    │
    └─ No (dynamic webapp) → Is the server already running?
        ├─ No → Run: python scripts/with_server.py --help
        │        Then use the helper + write simplified Playwright script
        │
        └─ Yes → Reconnaissance-then-action:
            1. Navigate and wait for networkidle
            2. Take screenshot or inspect DOM
            3. Identify selectors from rendered state
            4. Execute actions with discovered selectors
```

## Example: Using with_server.py

To start a server, run `--help` first, then use the helper:

**Single server:**
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- python your_automation.py
```

**Multiple servers (e.g., backend + frontend):**
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- python your_automation.py
```

To create an automation script, **connect to existing Chrome CDP** (servers are managed automatically):
```python
from playwright.sync_api import sync_playwright

CDP_PORT = 18800  # Default: openclaw headless instance

with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp(f"http://127.0.0.1:{CDP_PORT}")
    context = browser.new_context(viewport={"width": 1280, "height": 720})
    page = context.new_page()
    page.goto('http://localhost:5173')  # Server already running and ready
    page.wait_for_load_state('networkidle')  # CRITICAL: Wait for JS to execute
    # ... your automation logic
    page.close()       # Close the tab, NOT the browser
    context.close()    # Clean up context
    # ⚠️ Do NOT call browser.close() — the Chrome instance is shared!
```

## Reconnaissance-Then-Action Pattern

1. **Inspect rendered DOM**:
   ```python
   page.screenshot(path='/tmp/inspect.png', full_page=True)
   content = page.content()
   page.locator('button').all()
   ```

2. **Identify selectors** from inspection results

3. **Execute actions** using discovered selectors

## Common Pitfall

❌ **Don't** inspect the DOM before waiting for `networkidle` on dynamic apps
✅ **Do** wait for `page.wait_for_load_state('networkidle')` before inspection

## Best Practices

- **Use bundled scripts as black boxes** - To accomplish a task, consider whether one of the scripts available in `scripts/` can help. These scripts handle common, complex workflows reliably without cluttering the context window. Use `--help` to see usage, then invoke directly. 
- **禁止 `launch()`** — 永远用 `connect_over_cdp()` 连接已有实例，新需求开 tab 不开进程
- **清理 tab** — 用完 `page.close()` + `context.close()`，但 **不要** `browser.close()`
- Use `sync_playwright()` for synchronous scripts
- Use descriptive selectors: `text=`, `role=`, CSS selectors, or IDs
- Add appropriate waits: `page.wait_for_selector()` or `page.wait_for_timeout()`

## Reference Files

- **examples/** - Examples showing common patterns:
  - `element_discovery.py` - Discovering buttons, links, and inputs on a page
  - `static_html_automation.py` - Using file:// URLs for local HTML
  - `console_logging.py` - Capturing console logs during automation