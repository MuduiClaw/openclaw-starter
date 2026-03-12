#!/usr/bin/env bats
# Tests for .githooks/project-gates.sh

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  GATES="$REPO_ROOT/.githooks/project-gates.sh"
}

@test "project-gates.sh exists and is executable" {
  [ -x "$GATES" ]
}

@test "project-gates.sh has P1 secrets gate" {
  grep -q 'Gate P1' "$GATES"
}

@test "project-gates.sh has P2 privacy gate" {
  grep -q 'Gate P2' "$GATES"
}

@test "project-gates.sh detects common secret patterns" {
  # Verify the gate checks for known credential prefixes
  grep -q 'sk-\[a-zA-Z0-9\]' "$GATES"
  grep -q 'AKIA' "$GATES"
  grep -q 'ghp_' "$GATES"
  grep -q 'xoxb-' "$GATES"
}

@test "project-gates.sh skips binary files" {
  grep -q '\.png\|\.jpg\|\.gif' "$GATES"
}

@test "SPEC-TEMPLATE.md exists with required sections" {
  TEMPLATE="$REPO_ROOT/tasks/SPEC-TEMPLATE.md"
  [ -f "$TEMPLATE" ]
  grep -q 'Status' "$TEMPLATE"
  grep -q '交付物' "$TEMPLATE"
  grep -q '不做什么' "$TEMPLATE"
  grep -q '执行顺序' "$TEMPLATE"
  grep -q '风险' "$TEMPLATE"
}
