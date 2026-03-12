#!/usr/bin/env bats
# Tests for config/openclaw.template.json5

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEMPLATE="$REPO_ROOT/config/openclaw.template.json5"
}

json_query() {
  local query="${1-}"

  python3 - "$TEMPLATE" "$query" <<'PY'
import json
import pathlib
import re
import sys

template = pathlib.Path(sys.argv[1])
query = sys.argv[2]

text = template.read_text(encoding="utf-8")
out = []
i = 0
in_string = False
quote = ""
escape = False

while i < len(text):
    ch = text[i]
    nxt = text[i + 1] if i + 1 < len(text) else ""

    if in_string:
        out.append(ch)
        if escape:
            escape = False
        elif ch == "\\":
            escape = True
        elif ch == quote:
            in_string = False
        i += 1
        continue

    if ch in ("'", '"'):
        in_string = True
        quote = ch
        out.append(ch)
        i += 1
        continue

    if ch == "/" and nxt == "/":
        i += 2
        while i < len(text) and text[i] not in "\r\n":
            i += 1
        continue

    if ch == "/" and nxt == "*":
        i += 2
        while i + 1 < len(text) and not (text[i] == "*" and text[i + 1] == "/"):
            i += 1
        i += 2
        continue

    out.append(ch)
    i += 1

normalized = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
doc = json.loads(normalized)
value = doc

if query:
    for part in query.split("."):
        if not part:
            continue
        value = value[int(part)] if part.isdigit() else value[part]

if isinstance(value, (dict, list)):
    print(json.dumps(value, separators=(",", ":"), ensure_ascii=False))
elif isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("null")
else:
    print(value)
PY
}

json_has_key() {
  json_query "$1" >/dev/null 2>&1
}

assert_json_value() {
  local query="$1"
  local expected="$2"

  run json_query "$query"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "openclaw template exists and parses as JSON5" {
  [ -f "$TEMPLATE" ]

  run json_query

  [ "$status" -eq 0 ]
  [[ "$output" == *'"gateway"'* ]]
  [[ "$output" == *'"memory"'* ]]
  [[ "$output" == *'"acp"'* ]]
}

@test "openclaw template sets gateway and agent defaults" {
  assert_json_value "gateway.port" "3456"
  assert_json_value "gateway.mode" "production"
  assert_json_value "gateway.auth.mode" "token"
  ! json_has_key "gateway.auth.token"
  assert_json_value "agents.defaults.model.primary" "anthropic/claude-sonnet-4-6"
}

@test "openclaw template configures qmd memory defaults" {
  assert_json_value "memory.backend" "qmd"
  assert_json_value "memory.citations" "auto"
  assert_json_value "memory.qmd.command" "__HOME__/.openclaw/scripts/qmd-safe.sh"
  assert_json_value "memory.qmd.searchMode" "search"
  assert_json_value "memory.qmd.includeDefaultMemory" "true"
  assert_json_value "memory.qmd.update.interval" "5m"
  assert_json_value "memory.qmd.update.debounceMs" "15000"
  assert_json_value "memory.qmd.update.onBoot" "true"
  assert_json_value "memory.qmd.limits.maxResults" "10"
  assert_json_value "memory.qmd.limits.timeoutMs" "60000"
}

@test "openclaw template exposes ACP, skills, and cron defaults" {
  assert_json_value "acp.enabled" "true"
  assert_json_value "acp.dispatch.enabled" "true"
  assert_json_value "acp.backend" "acpx"
  assert_json_value "acp.defaultAgent" "codex"
  assert_json_value "acp.allowedAgents" '["pi","claude","codex","opencode","gemini"]'
  assert_json_value "acp.maxConcurrentSessions" "4"
  assert_json_value "skills.load.watch" "false"
  assert_json_value "skills.install.nodeManager" "npm"
  assert_json_value "cron.maxConcurrentRuns" "3"
}

@test "openclaw template configures logging session and browser defaults" {
  assert_json_value "logging.level" "info"
  assert_json_value "logging.file" "true"
  assert_json_value "logging.consoleLevel" "warn"
  assert_json_value "session.dmScope" "user"
  assert_json_value "browser.enabled" "true"
  assert_json_value "browser.headless" "true"
}

@test "openclaw template keeps optional integrations disabled by default" {
  assert_json_value "env.vars" "{}"
  assert_json_value "models.providers" "{}"
  assert_json_value "channels" "{}"
  assert_json_value "tools.profile" "full"
  ! json_has_key "tools.web"
  ! json_has_key "workspace"
  grep -Fq '"workspace": "__HOME__/clawd"' "$TEMPLATE"
}

@test "openclaw template uses placeholders instead of embedded secrets" {
  grep -Fq "__YOUR_ANTHROPIC_API_KEY__" "$TEMPLATE"
  grep -Fq "__YOUR_DISCORD_BOT_TOKEN__" "$TEMPLATE"
  grep -Fq "__YOUR_FEISHU_APP_SECRET__" "$TEMPLATE"
  grep -Fq "__YOUR_BRAVE_API_KEY__" "$TEMPLATE"
  grep -Fq "__HOME__/.openclaw/scripts/qmd-safe.sh" "$TEMPLATE"
  ! grep -Eq '(sk-ant-|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xoxb-[A-Za-z0-9-]+)' "$TEMPLATE"
}
