#!/usr/bin/env bats
# Tests for setup.sh

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$REPO_ROOT/setup.sh"
  BOOTSTRAP="$REPO_ROOT/bootstrap.sh"
  SYNC_TEMPLATE="$REPO_ROOT/sync-to-template.sh"
  CONFIG_TEMPLATE="$REPO_ROOT/config/openclaw.template.json5"
}

assert_script_contains() {
  grep -Fq "$1" "$SCRIPT"
}

assert_script_matches() {
  grep -Eq "$1" "$SCRIPT"
}

assert_script_not_contains() {
  ! grep -Fq "$1" "$SCRIPT"
}

assert_script_not_matches() {
  ! grep -Eq "$1" "$SCRIPT"
}

@test "setup.sh exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "bootstrap.sh exists and is executable" {
  [ -x "$BOOTSTRAP" ]
}

@test "sync-to-template.sh exists and is executable" {
  [ -x "$SYNC_TEMPLATE" ]
}

@test "workspace templates are present" {
  [ -f "$REPO_ROOT/workspace/AGENTS.md" ]
  [ -f "$REPO_ROOT/workspace/SOUL.md" ]
  [ -f "$REPO_ROOT/workspace/MEMORY.md" ]
  [ -f "$REPO_ROOT/workspace/USER.md" ]
}

@test "config template is present" {
  [ -f "$CONFIG_TEMPLATE" ]
}

@test "setup.sh passes bash syntax check" {
  run bash -n "$SCRIPT"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "setup.sh help exits cleanly and lists supported flags" {
  run bash "$SCRIPT" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"--workspace-dir ~/clawd"* ]]
  [[ "$output" == *"--no-launchagents"* ]]
  [[ "$output" == *"--skip-dashboard"* ]]
  [[ "$output" == *"--no-tailscale"* ]]
  [[ "$output" == *"--no-caffeinate"* ]]
  [[ "$output" == *"--update-dashboard"* ]]
  [[ "$output" == *"--uninstall"* ]]
}

@test "setup.sh accepts value flags before help" {
  run bash "$SCRIPT" --workspace-dir "$BATS_TEST_TMPDIR/custom-clawd" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"--workspace-dir ~/clawd"* ]]
}

@test "setup.sh rejects unknown flags" {
  run bash "$SCRIPT" --bogus

  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown flag: --bogus"* ]]
}

@test "setup.sh resolves paths from the script location and avoids set -e hard failure mode" {
  assert_script_contains 'SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"'
  assert_script_contains '# Note: intentionally NO `set -e`'
  assert_script_not_matches '^set -e'
}

@test "setup.sh uses BREW_PREFIX instead of hardcoded brew shellenv paths" {
  assert_script_contains 'BREW_PREFIX="/opt/homebrew"'
  assert_script_contains 'BREW_PREFIX="/usr/local"'
  assert_script_not_contains 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  assert_script_contains 'eval "$("${BREW_PREFIX}/bin/brew" shellenv)"'
  assert_script_contains 'eval "\$(${BREW_PREFIX}/bin/brew shellenv)" 2>/dev/null'
}

@test "setup.sh protects user files during workspace deployment" {
  assert_script_contains 'SYSTEM_DIRS=("scripts" "prompts" "eval" "skills" "mcp-bridge")'
  assert_script_contains 'cp -a "$dst" "$backup"'
  assert_script_contains 'rsync -a "$src/" "$dst/"'
  assert_script_not_contains 'rsync -a --delete'
  assert_script_contains 'USER_CONFIGS=('
  assert_script_contains 'if [ -f "$src" ] && [ ! -f "$dst" ]; then'
  assert_script_contains 'basename="$(basename "$example" .example)"'
}

@test "setup.sh generates a qmd-safe wrapper with a node bin fallback" {
  assert_script_contains 'NODE_BIN_QMD="$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")/qmd"'
  assert_script_contains 'QMD_PATH="$(command -v qmd 2>/dev/null || echo "$NODE_BIN_QMD")"'
  assert_script_contains 'cat > "${OPENCLAW_STATE}/scripts/qmd-safe.sh"'
  assert_script_contains 'exec "${QMD_PATH}" "\$@"'
}

@test "setup.sh embeds MiniMax vision support in generated config" {
  assert_script_contains '{"id": "MiniMax-VL-01", "name": "MiniMax VL 01", "reasoning": False, "input": ["text", "image"]'
  assert_script_contains 'agent_defaults["imageModel"] = {"primary": "minimax/MiniMax-VL-01"}'
  assert_script_contains '"allowedAgents": ["pi", "claude", "codex", "opencode", "gemini"]'
}

@test "setup.sh installs whisper-cpp and downloads tiny model for local STT" {
  grep -q 'whisper-cpp' "$REPO_ROOT/workspace/scripts/Brewfile"
  assert_script_contains 'ggml-tiny.bin'
  assert_script_contains 'whisper-cli'
  # Model path must use BREW_PREFIX, not hardcoded /opt/homebrew (Intel Mac uses /usr/local)
  assert_script_contains 'WHISPER_MODEL="${BREW_PREFIX}/share/whisper-cpp/for-tests-ggml-tiny.bin"'
}

@test "setup.sh sets feishu groupPolicy open for personal bot" {
  assert_script_contains '"groupPolicy": "open"'
}

@test "setup.sh generates local gateway config and reuses existing gateway tokens" {
  assert_script_contains '# Generate openclaw.json using python3 (safe from shell injection)'
  assert_script_contains 'GATEWAY_TOKEN="${EXISTING_GW_TOKEN:-$(openssl rand -hex 24)}"'
  assert_script_contains '"gateway": {"port": 3456, "mode": "local", "auth": {"mode": "token", "token": E("_OC_GW_TOKEN")}}'
  assert_script_contains '"command": f"{state}/scripts/qmd-safe.sh"'
  assert_script_contains '"session": {"dmScope": "per-channel-peer"}'
}

@test "setup.sh preserves dashboard login tokens when syncing gateway auth" {
  assert_script_contains 'grep -v "OPENCLAW_GATEWAY_TOKEN" "$DASHBOARD_ENV" > "${DASHBOARD_ENV}.tmp"'
  assert_script_contains 'echo "export OPENCLAW_GATEWAY_TOKEN=${GW_TOKEN}" >> "${DASHBOARD_ENV}.tmp"'
  assert_script_contains 'export DASHBOARD_TOKEN=0000'
}

@test "setup.sh patches the gateway plist with plistlib and reloads it" {
  assert_script_contains 'import plistlib, sys'
  assert_script_contains "env['PATH'] = '\$CORRECT_PATH'"
  assert_script_contains 'launchctl unload "$GW_PLIST" 2>/dev/null || true'
  assert_script_contains 'launchctl load "$GW_PLIST" 2>/dev/null || true'
}

@test "setup.sh guards destructive uninstall paths twice" {
  run grep -c 'Safety check: refusing to delete' "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
  assert_script_contains 'fatal "Safety check: refusing to delete ${WORKSPACE_DIR}"'
  assert_script_contains 'fatal "Safety check: refusing to delete ${OPENCLAW_STATE}"'
  assert_script_contains '/|"$HOME"|/usr|/var|/etc|/tmp'
}

@test "setup.sh uses loopback URLs and never references 0.0.0.0" {
  assert_script_contains 'http://localhost:3456'
  assert_script_contains 'http://localhost:3001'
  assert_script_not_contains '0.0.0.0'
}

@test "setup.sh includes optional CLI tools section with all 4 tools" {
  assert_script_contains 'Optional CLI Tools'
  assert_script_contains 'brew install himalaya'
  assert_script_contains 'brew install gogcli'
  assert_script_contains '@steipete/bird'
  assert_script_contains 'blogwatcher/cmd/blogwatcher@latest'
}

@test "setup.sh symlinks blogwatcher to homebrew bin for LaunchAgent PATH" {
  assert_script_contains 'ln -sf "$GOPATH/bin/blogwatcher" /opt/homebrew/bin/blogwatcher'
}

@test "setup.sh adds Go bin to .zprofile for blogwatcher" {
  assert_script_contains 'go/bin'
  assert_script_contains '.zprofile'
}

@test "release.sh exists and passes syntax check" {
  [ -x "$REPO_ROOT/scripts/release.sh" ]
  run bash -n "$REPO_ROOT/scripts/release.sh"
  [ "$status" -eq 0 ]
}

@test "release.sh --help exits cleanly" {
  run bash "$REPO_ROOT/scripts/release.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--version"* ]]
  [[ "$output" == *"--dry-run"* ]]
}
