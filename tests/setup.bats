#!/usr/bin/env bats
# Tests for setup.sh core functions

setup() {
  # Source only the functions we need (not the main execution)
  export TEST_MODE=1
}

@test "setup.sh exists and is executable" {
  [ -x "./setup.sh" ]
}

@test "bootstrap.sh exists and is executable" {
  [ -x "./bootstrap.sh" ]
}

@test "sync-to-template.sh exists and is executable" {
  [ -x "./sync-to-template.sh" ]
}

@test "workspace templates are present" {
  [ -f "./workspace/AGENTS.md" ]
  [ -f "./workspace/SOUL.md" ]
  [ -f "./workspace/MEMORY.md" ]
  [ -f "./workspace/USER.md" ]
}

@test "config templates are present" {
  [ -f "./config/openclaw.template.json5" ]
}
