#!/usr/bin/env bats
# Tests for gateway self-kill protection (issue #13)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SETUP_SCRIPT="$REPO_ROOT/setup.sh"
  CONFIG_TEMPLATE="$REPO_ROOT/config/openclaw.template.json5"
  WATCHDOG_PLIST="$REPO_ROOT/services/launchagents/ai.openclaw.watchdog.plist.template"
  WATCHDOG_SCRIPT="$REPO_ROOT/services/scripts/gateway-watchdog.sh"
  SAFE_RESTART="$REPO_ROOT/services/scripts/openclaw-safe-restart.sh"
  AGENTS_MD="$REPO_ROOT/workspace/AGENTS.md"
}

# --- Layer 1: denyCommands in config template ---

@test "config template has denyCommands array" {
  grep -q '"denyCommands"' "$CONFIG_TEMPLATE"
}

@test "denyCommands blocks 'openclaw gateway restart'" {
  grep -q 'openclaw gateway restart' "$CONFIG_TEMPLATE"
}

@test "denyCommands blocks 'openclaw gateway stop'" {
  grep -q 'openclaw gateway stop' "$CONFIG_TEMPLATE"
}

@test "denyCommands blocks 'launchctl bootout'" {
  grep -q 'launchctl bootout' "$CONFIG_TEMPLATE"
}

@test "denyCommands blocks 'launchctl unload'" {
  grep -q 'launchctl unload' "$CONFIG_TEMPLATE"
}

# --- Layer 2: watchdog LaunchAgent ---

@test "watchdog plist template exists" {
  [ -f "$WATCHDOG_PLIST" ]
}

@test "watchdog plist is valid XML" {
  python3 -c "import plistlib; plistlib.load(open('$WATCHDOG_PLIST','rb'))"
}

@test "watchdog plist label is ai.openclaw.watchdog" {
  grep -q 'ai.openclaw.watchdog' "$WATCHDOG_PLIST"
}

@test "watchdog plist runs every 30 seconds" {
  grep -A1 'StartInterval' "$WATCHDOG_PLIST" | grep -q '30'
}

@test "watchdog script exists and is valid bash" {
  [ -f "$WATCHDOG_SCRIPT" ]
  bash -n "$WATCHDOG_SCRIPT"
}

@test "watchdog script checks launchctl list" {
  grep -q 'launchctl list' "$WATCHDOG_SCRIPT"
}

@test "watchdog script re-bootstraps on failure" {
  grep -q 'launchctl bootstrap' "$WATCHDOG_SCRIPT"
}

# --- Layer 3: safe-restart script ---

@test "safe-restart script exists and is valid bash" {
  [ -f "$SAFE_RESTART" ]
  bash -n "$SAFE_RESTART"
}

@test "safe-restart detaches via nohup + disown" {
  grep -q 'nohup' "$SAFE_RESTART"
  grep -q 'disown' "$SAFE_RESTART"
}

@test "safe-restart performs bootout then bootstrap" {
  grep -q 'launchctl bootout' "$SAFE_RESTART"
  grep -q 'launchctl bootstrap' "$SAFE_RESTART"
}

# --- Integration: setup.sh wiring ---

@test "setup.sh installs watchdog script" {
  grep -q 'gateway-watchdog.sh' "$SETUP_SCRIPT"
}

@test "setup.sh installs safe-restart script" {
  grep -q 'openclaw-safe-restart.sh' "$SETUP_SCRIPT"
}

@test "setup.sh uninstall cleans up watchdog LaunchAgent" {
  grep -q 'ai.openclaw.watchdog' "$SETUP_SCRIPT"
}

# --- AGENTS.md iron rule ---

@test "AGENTS.md contains gateway self-kill iron rule" {
  grep -q 'gateway 自杀' "$AGENTS_MD" || grep -q 'gateway restart' "$AGENTS_MD"
}
