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

@test "zprofile brew shellenv uses BREW_PREFIX not hardcoded path" {
  # Ensure setup.sh does NOT hardcode /opt/homebrew/bin/brew in the .zprofile heredoc
  # It should use ${BREW_PREFIX} so Intel (/usr/local) and ARM (/opt/homebrew) both work
  ! grep -q 'eval.*\$/opt/homebrew/bin/brew shellenv' setup.sh
  grep -q 'eval.*BREW_PREFIX.*brew shellenv' setup.sh
}

@test "minimax config includes VL-01 vision model" {
  # setup.sh must define MiniMax-VL-01 with image input for image understanding
  grep -q 'MiniMax-VL-01' setup.sh
  grep -q '"input": \["text", "image"\]' setup.sh
}

@test "minimax config sets imageModel to VL-01" {
  # When MiniMax key is provided, imageModel should point to VL-01
  grep -q 'imageModel.*minimax/MiniMax-VL-01' setup.sh
}
