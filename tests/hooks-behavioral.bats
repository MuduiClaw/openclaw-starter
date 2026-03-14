#!/usr/bin/env bats
# Behavioral tests for workspace/.githooks/
# These actually EXECUTE the hooks in a sandbox git repo and verify behavior.
# Complements grep-based tests in gates-portable.bats / gateway-safety.bats.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SANDBOX="$BATS_TEST_TMPDIR/sandbox"
  rm -rf "$SANDBOX"

  # Create a minimal git repo with our hooks
  mkdir -p "$SANDBOX"
  cd "$SANDBOX"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"

  # Copy the template hooks
  mkdir -p "$SANDBOX/.githooks"
  cp "$REPO_ROOT/workspace/.githooks/prepare-commit-msg" "$SANDBOX/.githooks/"
  cp "$REPO_ROOT/workspace/.githooks/pre-push" "$SANDBOX/.githooks/"
  chmod +x "$SANDBOX/.githooks/"*
  git config core.hooksPath "$SANDBOX/.githooks"

  # Create a telemetry stub (no-op)
  mkdir -p "$SANDBOX/scripts"
  printf '#!/bin/bash\nexit 0\n' > "$SANDBOX/scripts/gate-telemetry.sh"
  chmod +x "$SANDBOX/scripts/gate-telemetry.sh"

  # Create initial commit so we have a HEAD
  echo "init" > README.md
  git add README.md
  git commit -q -m "init: initial commit" --no-verify
}

teardown() {
  cd /
  rm -rf "$SANDBOX"
}

# ─── prepare-commit-msg behavioral tests ───

@test "hook stamps tree-hash trailer on clean commit" {
  cd "$SANDBOX"
  printf '#!/bin/bash\necho "test"\n' > file.sh
  chmod +x file.sh
  git add file.sh
  run env REVIEWED=1 git commit -m "feat: add file" 2>&1
  [ "$status" -eq 0 ]
  # Verify tree-hash trailer exists
  trailer=$(git log -1 --format='%B' | grep 'Pre-commit-gate:' | awk '{print $2}')
  [ -n "$trailer" ]
  # Verify it matches actual tree
  actual=$(git rev-parse HEAD^{tree})
  [ "$trailer" = "$actual" ]
}

@test "hook blocks commit when shellcheck fails on .sh file" {
  cd "$SANDBOX"
  # SC2164 (warning): Use 'cd ... || exit' in case cd fails
  printf '#!/bin/bash\ncd /somewhere\nls\n' > bad.sh
  git add bad.sh
  run env REVIEWED=1 git commit -m "feat: add bad script" 2>&1
  # Should fail (shellcheck -S warning catches SC2086)
  [ "$status" -ne 0 ]
  [[ "$output" == *"shellcheck"* ]] || [[ "$output" == *"PRE-COMMIT"* ]]
}

@test "hook blocks >5 staged files without [scope-ack]" {
  cd "$SANDBOX"
  for i in $(seq 1 6); do echo "$i" > "file${i}.txt"; done
  git add file*.txt
  run env REVIEWED=1 git commit -m "feat: add many files" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"scope-ack"* ]]
}

@test "hook allows >5 staged files WITH [scope-ack]" {
  cd "$SANDBOX"
  for i in $(seq 1 6); do echo "$i" > "file${i}.txt"; done
  git add file*.txt
  REVIEWED=1 git commit -q -m "feat: add many files [scope-ack]" 2>/dev/null
  [ $? -eq 0 ]
}

@test "hook blocks prompt change without CHANGELOG update" {
  cd "$SANDBOX"
  mkdir -p prompts/cron
  echo "v2 prompt" > prompts/cron/test.prompt.md
  git add prompts/cron/test.prompt.md
  run env REVIEWED=1 git commit -m "feat: update prompt" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG"* ]]
}

@test "hook allows prompt change WITH CHANGELOG update" {
  cd "$SANDBOX"
  mkdir -p prompts/cron
  echo "v2 prompt" > prompts/cron/test.prompt.md
  echo "- [2026-03-14] test v2 — updated" > prompts/CHANGELOG.md
  git add prompts/cron/test.prompt.md prompts/CHANGELOG.md
  REVIEWED=1 git commit -q -m "feat: update prompt" 2>/dev/null
  [ $? -eq 0 ]
}

@test "backup: prefix bypasses scope-lock" {
  cd "$SANDBOX"
  for i in $(seq 1 8); do echo "$i" > "file${i}.md"; done
  git add file*.md
  git commit -q -m "backup: auto save" --no-verify 2>/dev/null
  [ $? -eq 0 ]
}

@test "hook requires REVIEWED=1 for code changes in non-workspace repos" {
  cd "$SANDBOX"
  echo "code" > app.ts
  git add app.ts
  run git commit -m "feat: add code" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"REVIEWED=1"* ]]
}

@test "WORKSPACE_MODE skips REVIEWED=1 check" {
  cd "$SANDBOX"
  # Create SOUL.md to trigger workspace mode
  echo "soul" > SOUL.md
  git add SOUL.md
  git commit -q -m "init: add soul" --no-verify
  
  echo "code" > script.sh
  git add script.sh
  run git commit -m "chore: add script" 2>&1
  # Should NOT block on REVIEWED (workspace mode)
  # But may block on shellcheck — that's expected and correct
  [[ "$output" != *"REVIEWED=1"* ]]
}

# ─── JSON/YAML syntax behavioral tests ───

@test "hook blocks invalid JSON" {
  cd "$SANDBOX"
  echo '{"broken": }' > config.json
  git add config.json
  run env REVIEWED=1 git commit -m "chore: add config" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid JSON"* ]]
}

@test "hook passes valid JSON" {
  cd "$SANDBOX"
  echo '{"valid": true}' > config.json
  git add config.json
  REVIEWED=1 git commit -q -m "chore: add config" 2>/dev/null
  [ $? -eq 0 ]
}

@test "hook blocks invalid YAML" {
  cd "$SANDBOX"
  printf 'key: value\n  broken:\nindent' > config.yml
  git add config.yml
  run env REVIEWED=1 git commit -m "chore: add yaml" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid YAML"* ]]
}
