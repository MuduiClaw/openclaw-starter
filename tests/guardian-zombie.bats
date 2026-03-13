#!/usr/bin/env bats
# Tests for guardian zombie cleanup before kickstart

setup() {
  GUARDIAN="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/workspace/scripts/guardian_agent.py"
}

# --- _kill_zombie_gateway exists and uses launchctl kill ---

@test "guardian has _kill_zombie_gateway method" {
  grep -q 'def _kill_zombie_gateway' "$GUARDIAN"
}

@test "_kill_zombie_gateway uses launchctl kill SIGKILL" {
  grep -q 'launchctl kill SIGKILL' "$GUARDIAN"
}

@test "_kill_zombie_gateway does NOT call kill_port_zombies (KeepAlive race)" {
  # Between _kill_zombie_gateway def and next def, no kill_port_zombies call
  sed -n '/def _kill_zombie_gateway/,/def [a-z]/p' "$GUARDIAN" | grep -vq 'kill_port_zombies'
}

@test "_kill_zombie_gateway polls port release instead of blind sleep" {
  sed -n '/def _kill_zombie_gateway/,/def [a-z]/p' "$GUARDIAN" | grep -q 'sTCP:LISTEN'
}

# --- kill_port_zombies only kills LISTEN sockets ---

@test "kill_port_zombies uses -sTCP:LISTEN filter" {
  grep 'kill_port_zombies' -A10 "$GUARDIAN" | head -15 | grep -q 'sTCP:LISTEN'
}

@test "kill_port_zombies does NOT use bare lsof -ti :port" {
  # The lsof line in kill_port_zombies must have -sTCP:LISTEN
  sed -n '/^def kill_port_zombies/,/^def /p' "$GUARDIAN" | grep 'lsof' | grep -q 'sTCP:LISTEN'
}

# --- All kickstart paths have zombie cleanup ---

@test "Layer 1 kickstart has zombie cleanup" {
  sed -n '/Layer 1: 自动重启/,/kickstart/p' "$GUARDIAN" | grep -q '清理僵尸'
}

@test "Layer 1.5 kickstart has zombie cleanup" {
  sed -n '/Layer 1.5: 自动重启/,/kickstart/p' "$GUARDIAN" | grep -q '清理僵尸'
}

@test "Layer 3 kickstart has zombie cleanup" {
  sed -n '/Layer 3: 自动重启/,/kickstart/p' "$GUARDIAN" | grep -q '清理僵尸'
}

# --- RollbackManager receives health ref ---

@test "RollbackManager accepts health parameter" {
  grep -q 'class RollbackManager' "$GUARDIAN"
  grep -A3 'class RollbackManager' "$GUARDIAN" | grep -q 'health'
}

@test "GuardianAgent passes health to RollbackManager" {
  grep -q 'RollbackManager.*health.*self.health' "$GUARDIAN"
}

# --- Syntax check ---

@test "guardian_agent.py is valid Python" {
  python3 -c "import py_compile; py_compile.compile('$GUARDIAN', doraise=True)"
}
