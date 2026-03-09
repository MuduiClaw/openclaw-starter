<!-- Adapted from Design OS (github.com/buildermethods/design-os) -->
<!-- Rewritten for OpenClaw: uses browser tool + Canvas snapshot instead of Playwright MCP -->

# Screenshot Screen Design

Capture a screenshot of a screen design for documentation purposes.

## Step 1: Identify the Screen Design

Read `product/product-roadmap.md` for the list of sections, then check `src/sections/` for existing screen designs.

- If only one screen design exists, auto-select it.
- If multiple exist, ask the user which one to screenshot:

"Which screen design would you like to screenshot?"

Present options grouped by section:
- [Section Name] / [ScreenDesignName]

## Step 2: Serve & Capture

**Option A: Canvas Preview (preferred for quick capture)**
1. Read the screen design component file (`src/sections/[section-id]/[ViewName].tsx`)
2. Read the sample data (`product/sections/[section-id]/data.json`)
3. Use `canvas` tool to render the component with sample data
4. Use `canvas(action=snapshot)` to capture the rendered output

**Option B: Browser Tool (for full-page capture with real rendering)**
1. Start the dev server: `exec("npm run dev")` in the project directory
2. Wait a few seconds for the server to be ready
3. Use `browser(action=navigate, targetUrl="http://localhost:3000/sections/[section-id]/screen-designs/[screen-design-name]")`
4. Use `browser(action=screenshot, fullPage=true)` to capture

**Do NOT ask the user to start the server — start it yourself.**

## Step 3: Save the Screenshot

Save to: `product/sections/[section-id]/[filename].png`

**Naming convention:** `[screen-design-name]-[variant].png`

Examples:
- `invoice-list.png` (main view)
- `invoice-list-dark.png` (dark mode variant)
- `invoice-detail.png`
- `invoice-form-empty.png` (empty state)

## Step 4: Confirm Completion

Tell the user:

"Screenshot saved to `product/sections/[section-id]/[filename].png` — **[ScreenDesignName]** for the **[Section Title]** section."

Offer additional captures:
- Dark mode version
- Mobile viewport
- Different states (empty, loading, etc.)

## Important Notes

- Capture at consistent viewport width (1280px recommended)
- Always capture full page to include all scrollable content
- PNG format for best quality
- Kill the dev server after you're done (if you started one)
