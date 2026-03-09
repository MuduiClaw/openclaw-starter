---
name: login-machine
description: Universal browser login automation using LLM vision + 1Password. One loop handles any login flow — no per-site scripts. Use when user asks to "login to X", "sign into", "authenticate on", or needs automated browser authentication.
description_zh: "通用浏览器自动登录：LLM 视觉 + 1Password，一个循环搞定任意登录流程，无需每站写脚本。"
---

# Login Machine

AI-powered universal login automation. Uses LLM vision to classify login pages and Playwright to interact with them. Credentials come from 1Password — they never touch the LLM.

Based on [RichardHruby/login-machine](https://github.com/RichardHruby/login-machine) (MIT), adapted for local infrastructure.

## How It Works

```
Navigate to login page
        ↓
  ┌─→ Screenshot + Extract HTML
  │         ↓
  │   LLM Classifies Screen Type
  │         ↓
  │   ┌─ credential_form → 1Password → fill → submit
  │   ├─ choice_screen → auto-select or ask user
  │   ├─ blocked_screen → auto-dismiss
  │   ├─ loading_screen → wait
  │   ├─ magic_link → report (can't auto-handle)
  │   └─ logged_in → done!
  │         ↓
  └─── Loop until logged in
```

## Prerequisites

1. **Playwright** installed (auto-launches headless Chromium; or use `--cdp <url>` for existing browser)
2. **1Password CLI** (`op`) authenticated — `source ~/.config/openclaw/1password.env`
3. **Antigravity** running on `http://127.0.0.1:8045/v1` (or any OpenAI-compatible endpoint)

## Usage

### CLI

```bash
cd ~/clawd/skills/login-machine
bun src/cli.ts <url> [options]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--item <ref>` | auto-detect | 1Password item reference (name or ID) |
| `--model <model>` | `claude-sonnet-4-5` | LLM model via Antigravity |
| `--cdp <url>` | `launch` (new browser) | CDP URL or "launch" for fresh instance |
| `--max-steps <n>` | `20` | Max observe-act loop iterations |
| `--timeout <sec>` | `120` | Overall timeout |
| `--verbose` | off | Detailed step logging |

### Examples

```bash
# Login to GitHub using stored credentials
bun src/cli.ts https://github.com/login --item "GitHub" --verbose

# Login to Netflix (auto-detect 1Password item by domain)
bun src/cli.ts https://netflix.com/login

# Custom LLM model
bun src/cli.ts https://app.example.com/signin --model gemini-3.1-pro-low
```

### Output

JSON result on stdout:
```json
{
  "success": true,
  "finalUrl": "https://github.com/dashboard",
  "steps": 3,
  "screenTypes": ["blocked_screen", "credential_login_form", "logged_in_screen"],
  "duration": 15234
}
```

## From OpenClaw Agent

When using this skill from the OpenClaw agent:

```bash
# Run login
cd ~/clawd/skills/login-machine && bun src/cli.ts "https://target.com/login" --item "ItemName" --verbose
```

The agent should:
1. Ensure the headless browser is running (`browser status` → profile `openclaw`)
2. Run the CLI command
3. Parse the JSON result
4. Report success/failure to user

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LM_BASE_URL` | `http://127.0.0.1:8045/v1` | LLM API endpoint |
| `LM_API_KEY` | Antigravity key | LLM API key |
| `LM_MODEL` | `claude-sonnet-4-5` | LLM model name |

## Security

- **Credentials never touch the LLM** — the LLM analyzes page structure and returns locators; credentials are fetched separately from 1Password and injected directly into the browser DOM
- **Credentials never appear in logs** — field names are logged, values are not
- **Browser page is isolated** — each login creates a new page tab, closed after completion

## Limitations

- **Magic login links**: Can detect them but can't auto-complete (requires email access)
- **CAPTCHAs**: No built-in solver. Relies on browser fingerprint to avoid them
- **Registration flows**: Designed for login; registration may need additional screen types
- **MFA**: Can handle OTP fields if 1Password has the TOTP secret; SMS/app-based MFA requires user intervention

## Screen Types

| Type | Auto-handled | Description |
|------|-------------|-------------|
| `credential_login_form` | ✅ (with 1Password) | Email/password/OTP forms |
| `choice_screen` | ✅ (first option) | Account pickers, SSO selectors |
| `blocked_screen` | ✅ | Cookie banners, popups |
| `loading_screen` | ✅ | Spinners, redirects |
| `magic_login_link` | ❌ | "Check your email" screens |
| `logged_in_screen` | ✅ (terminal) | Successfully authenticated |
