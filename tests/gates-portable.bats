#!/usr/bin/env bats
# Tests for workspace/.githooks/ portable hooks and setup

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  WORKSPACE="$REPO_ROOT/workspace"
  HOOKS_DIR="$WORKSPACE/.githooks"
  SCRIPTS_DIR="$WORKSPACE/scripts"
}

# ─── Hook files exist ───

@test "prepare-commit-msg hook exists and is readable" {
  [ -f "$HOOKS_DIR/prepare-commit-msg" ]
}

@test "pre-push hook exists and is readable" {
  [ -f "$HOOKS_DIR/pre-push" ]
}

# ─── Portable path discovery (no hardcoded paths) ───

@test "prepare-commit-msg has no hardcoded user paths" {
  ! grep -q '/Users/wangshufu\|/Users/mudui\|/home/[a-z]' "$HOOKS_DIR/prepare-commit-msg"
}

@test "pre-push has no hardcoded user paths" {
  ! grep -q '/Users/wangshufu\|/Users/mudui\|/home/[a-z]' "$HOOKS_DIR/pre-push"
}

@test "prepare-commit-msg uses portable HOOKS_DIR discovery" {
  grep -q 'HOOKS_DIR=.*dirname.*\$0' "$HOOKS_DIR/prepare-commit-msg"
}

@test "pre-push uses portable HOOKS_DIR discovery" {
  grep -q 'HOOKS_DIR=.*dirname.*\$0' "$HOOKS_DIR/pre-push"
}

@test "telemetry path is relative to WORKSPACE_ROOT" {
  grep -q 'TELEMETRY=.*WORKSPACE_ROOT.*/scripts/gate-telemetry.sh' "$HOOKS_DIR/prepare-commit-msg"
  grep -q 'TELEMETRY=.*WORKSPACE_ROOT.*/scripts/gate-telemetry.sh' "$HOOKS_DIR/pre-push"
}

# ─── Telemetry graceful skip ───

@test "telemetry _tel function has graceful skip" {
  # Should check -x before calling, and have || true
  grep -q '\-x.*TELEMETRY' "$HOOKS_DIR/prepare-commit-msg"
  grep -q '|| true' "$HOOKS_DIR/prepare-commit-msg"
}

# ─── Tree-hash anti-forgery (v2) ───

@test "prepare-commit-msg generates tree-hash trailer (not plain 'passed')" {
  grep -q 'git write-tree' "$HOOKS_DIR/prepare-commit-msg"
  grep -q 'Pre-commit-gate:' "$HOOKS_DIR/prepare-commit-msg"
}

@test "pre-push verifies tree-hash trailer" {
  grep -q 'rev-parse.*\^{tree}' "$HOOKS_DIR/pre-push"
}

@test "pre-push rejects legacy 'passed' trailers" {
  grep -q '"passed"' "$HOOKS_DIR/pre-push"
}

# ─── Task-lock graceful skip ───

@test "task-lock checks are conditional on .task-lock dir existing" {
  # All task-lock file checks should first test -d .task-lock
  grep -q '\-d.*task-lock' "$HOOKS_DIR/prepare-commit-msg"
}

# ─── Setup script ───

@test "setup-gates.sh exists and is executable" {
  [ -x "$SCRIPTS_DIR/setup-gates.sh" ]
}

@test "setup-gates.sh supports --uninstall" {
  grep -q '\-\-uninstall' "$SCRIPTS_DIR/setup-gates.sh"
}

@test "setup-gates.sh defaults to local (per-repo) install" {
  grep -q 'git config core.hooksPath' "$SCRIPTS_DIR/setup-gates.sh"
  # --global requires explicit flag
  grep -q '\-\-global' "$SCRIPTS_DIR/setup-gates.sh"
}

@test "setup-gates.sh warns before global install" {
  grep -q 'WARNING\|⚠️' "$SCRIPTS_DIR/setup-gates.sh"
}

# ─── Telemetry script ───

@test "gate-telemetry.sh exists and is executable" {
  [ -x "$SCRIPTS_DIR/gate-telemetry.sh" ]
}

# ─── Documentation ───

@test "GATES.md documentation exists" {
  [ -f "$REPO_ROOT/docs/GATES.md" ]
}

@test "GATES.md covers installation" {
  grep -q 'setup-gates' "$REPO_ROOT/docs/GATES.md"
}

@test "GATES.md covers FAQ" {
  grep -q 'FAQ\|--no-verify' "$REPO_ROOT/docs/GATES.md"
}
