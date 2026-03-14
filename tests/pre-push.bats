#!/usr/bin/env bats
# Behavioral tests for workspace/.githooks/pre-push

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SANDBOX="$BATS_TEST_TMPDIR/pre-push-sandbox"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  NPX_LOG="$BATS_TEST_TMPDIR/npx.log"
  REMOTE="$BATS_TEST_TMPDIR/remote.git"

  rm -rf "$SANDBOX" "$STUB_BIN" "$REMOTE"
  rm -f "$NPX_LOG" /tmp/.tdd-gate4-files

  mkdir -p "$SANDBOX/.githooks" "$SANDBOX/scripts" "$STUB_BIN"
  cd "$SANDBOX"

  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"

  cp "$REPO_ROOT/workspace/.githooks/prepare-commit-msg" "$SANDBOX/.githooks/"
  cp "$REPO_ROOT/workspace/.githooks/pre-push" "$SANDBOX/.githooks/"
  chmod +x "$SANDBOX/.githooks/"*

  git config core.hooksPath "$SANDBOX/.githooks"

  printf '#!/bin/sh\nexit 0\n' > "$SANDBOX/scripts/gate-telemetry.sh"
  chmod +x "$SANDBOX/scripts/gate-telemetry.sh"

  create_npx_stub

  echo "init" > README.md
  git add README.md
  git commit -q -m "init: initial commit" --no-verify
}

teardown() {
  cd /
  rm -f /tmp/.tdd-gate4-files
  rm -rf "$SANDBOX" "$STUB_BIN" "$REMOTE"
}

create_npx_stub() {
  cat > "$STUB_BIN/npx" <<'EOF'
#!/bin/sh
set -eu

: "${NPX_LOG:?}"

printf '%s\n' "$*" >> "$NPX_LOG"

cmd="${1-}"
case "$cmd" in
  tsc)
    if [ "${NPX_TSC_EXIT:-0}" -ne 0 ]; then
      printf '%s\n' "${NPX_TSC_OUTPUT:-Typecheck failed}" >&2
      exit "${NPX_TSC_EXIT}"
    fi
    exit 0
    ;;
  eslint)
    if [ "${NPX_ESLINT_EXIT:-0}" -ne 0 ]; then
      printf '%s\n' "${NPX_ESLINT_OUTPUT:-ESLint failed}" >&2
      exit "${NPX_ESLINT_EXIT}"
    fi
    exit "${NPX_ESLINT_EXIT:-0}"
    ;;
  *)
    printf 'unexpected npx invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$STUB_BIN/npx"
  : > "$NPX_LOG"
}

setup_remote() {
  rm -rf "$REMOTE"
  git clone --bare "$SANDBOX" "$REMOTE" >/dev/null 2>&1
  cd "$SANDBOX"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$REMOTE"
}

enable_workspace_mode() {
  echo "soul" > SOUL.md
  git add SOUL.md
  git commit -q -m "docs: add soul" --no-verify
}

commit_with_review() {
  local msg="$1"
  env REVIEWED=1 git commit -q -m "$msg" 2>/dev/null
}

commit_without_hooks_with_tree_trailer() {
  local msg="$1"
  local tree

  git commit -q --no-verify -m "$msg" 2>/dev/null
  tree="$(git rev-parse HEAD^{tree})"
  git commit -q --amend --no-verify -m "$msg" -m "Pre-commit-gate: $tree" 2>/dev/null
}

commit_without_hooks_with_custom_trailer() {
  local msg="$1"
  local trailer="$2"

  git commit -q --no-verify -m "$msg" 2>/dev/null
  git commit -q --amend --no-verify -m "$msg" -m "Pre-commit-gate: $trailer" 2>/dev/null
}

create_impl_files() {
  local count="$1"
  local i

  mkdir -p src
  for i in $(seq 1 "$count"); do
    printf '#!/bin/sh\necho %s\n' "$i" > "src/file${i}.sh"
  done
}

create_bats_test_file() {
  local path="$1"

  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
#!/usr/bin/env bats
@test "smoke" {
  true
}
EOF
}

create_verify_production_stub() {
  local exit_code="${1:-0}"
  local message="${2:-verify-production}"

  cat > "$SANDBOX/scripts/verify-production.sh" <<EOF
#!/bin/sh
printf '%s\n' '$message'
exit $exit_code
EOF
  chmod +x "$SANDBOX/scripts/verify-production.sh"
}

run_push() {
  local ref="${1:-main}"

  run env \
    PATH="$STUB_BIN:$PATH" \
    NPX_LOG="$NPX_LOG" \
    NPX_TSC_EXIT="${NPX_TSC_EXIT:-0}" \
    NPX_TSC_OUTPUT="${NPX_TSC_OUTPUT:-}" \
    NPX_ESLINT_EXIT="${NPX_ESLINT_EXIT:-0}" \
    NPX_ESLINT_OUTPUT="${NPX_ESLINT_OUTPUT:-}" \
    git push origin "$ref" 2>&1
}

@test "pre-push rejects pushing a new branch" {
  cd "$SANDBOX"
  setup_remote

  git checkout -q -b feature/test

  run_push "feature/test"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Pushing new branch"* ]]
}

@test "Gate 1 blocks loose commit format in non-workspace repos" {
  cd "$SANDBOX"
  setup_remote

  echo "product repo" >> README.md
  git add README.md
  git commit -q -m "bad message" 2>/dev/null

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"Bad commit format: bad message"* ]]
}

@test "Gate 1 warns only for loose commit format in workspace mode" {
  cd "$SANDBOX"
  enable_workspace_mode
  setup_remote

  echo "workspace repo" >> README.md
  git add README.md
  git commit -q -m "bad message" 2>/dev/null

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"Loose commit format (workspace): bad message"* ]]
  [[ "$output" == *"Pre-push gate: passed"* ]]
}

@test "workspace mode still enforces trailer checks when .githooks changes" {
  cd "$SANDBOX"
  enable_workspace_mode
  setup_remote

  printf '#!/bin/sh\necho local\n' > .githooks/local-note.sh
  chmod +x .githooks/local-note.sh
  git add .githooks/local-note.sh
  git commit -q --no-verify -m "chore: touch hook" 2>/dev/null

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"missing Pre-commit-gate trailer"* ]]
}

@test "Gate 3 blocks commits missing the Pre-commit-gate trailer" {
  cd "$SANDBOX"
  setup_remote

  echo "docs" >> README.md
  git add README.md
  git commit -q --no-verify -m "docs: update readme" 2>/dev/null

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"missing Pre-commit-gate trailer"* ]]
}

@test "Gate 3 blocks legacy passed trailers" {
  cd "$SANDBOX"
  setup_remote

  echo "legacy" >> README.md
  git add README.md
  commit_without_hooks_with_custom_trailer "docs: legacy trailer" "passed"

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"legacy 'passed' trailer"* ]]
}

@test "Gate 3 blocks forged tree-hash trailers" {
  cd "$SANDBOX"
  setup_remote

  echo "forged" >> README.md
  git add README.md
  commit_without_hooks_with_custom_trailer "docs: forged trailer" "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"tree-hash mismatch"* ]]
}

@test "Gate 2 blocks large implementation pushes without a spec reference" {
  cd "$SANDBOX"
  setup_remote

  mkdir -p tasks tests
  create_impl_files 8
  create_bats_test_file tests/smoke.bats
  git add src tests

  commit_without_hooks_with_tree_trailer "feat: add batch"

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"[Gate 2]"* ]]
  [[ "$output" == *"无 spec 引用"* ]]
}

@test "Gate 2.1 warns and continues when the referenced spec file is missing" {
  cd "$SANDBOX"
  setup_remote

  mkdir -p tasks tests
  create_impl_files 8
  create_bats_test_file tests/smoke.bats
  git add src tests

  commit_without_hooks_with_tree_trailer "feat: add batch [spec:missing-spec]"

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"[Gate 2.1]"* ]]
  [[ "$output" == *"Spec file not found: tasks/missing-spec.md"* ]]
}

@test "Gate 2.1 warns and continues when the referenced spec is abandoned" {
  cd "$SANDBOX"

  mkdir -p tasks
  cat > tasks/abandoned.md <<'EOF'
# Spec: Abandoned
- Status: abandoned
EOF
  git add tasks/abandoned.md
  git commit -q -m "docs: add abandoned spec" --no-verify

  setup_remote

  mkdir -p tests
  create_impl_files 8
  create_bats_test_file tests/smoke.bats
  git add src tests

  commit_without_hooks_with_tree_trailer "feat: add batch [spec:abandoned]"

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"[Gate 2.1]"* ]]
  [[ "$output" == *"tasks/abandoned.md is abandoned"* ]]
}

@test "Gate 4 blocks code-only pushes when a bats test framework is present" {
  cd "$SANDBOX"

  mkdir -p tests
  create_bats_test_file tests/existing.bats
  git add tests/existing.bats
  git commit -q -m "test: add bats harness" 2>/dev/null

  setup_remote

  printf '#!/bin/sh\necho hi\n' > app.sh
  git add app.sh
  commit_with_review "feat: add app"

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"[Gate 4 TDD] Push has code changes but no test changes"* ]]
  [ -f /tmp/.tdd-gate4-files ]
  grep -Fq "app.sh" /tmp/.tdd-gate4-files
}

@test "Gate 4 passes when code and tests are both included in the push range" {
  cd "$SANDBOX"
  setup_remote

  printf '#!/bin/sh\necho hi\n' > app.sh
  git add app.sh
  commit_with_review "feat: add app"

  mkdir -p tests
  create_bats_test_file tests/app.bats
  git add tests/app.bats
  git commit -q -m "test: cover app" 2>/dev/null

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" != *"[Gate 4 TDD] Push has code changes but no test changes"* ]]
}

@test "Gate 5 runs typecheck and blocks on failure" {
  cd "$SANDBOX"
  setup_remote

  echo '{}' > tsconfig.json
  mkdir -p src
  echo 'export const answer: string = 42;' > src/app.ts
  git add src/app.ts
  commit_with_review "feat: add typed app"

  NPX_TSC_EXIT=2
  NPX_TSC_OUTPUT="src/app.ts(1,14): error TS2322: Type 'number' is not assignable to type 'string'."
  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"[Gate 5] Running typecheck"* ]]
  [[ "$output" == *"[Gate 5 Typecheck] Failed"* ]]
  [[ "$output" == *"npx tsc --noEmit"* ]]
  grep -Fq "tsc --noEmit" "$NPX_LOG"
}

@test "Gate 5 falls back to eslint and passes when no tsconfig is present" {
  cd "$SANDBOX"
  setup_remote

  echo 'export default [];' > eslint.config.js
  echo 'console.log("ok")' > app.js
  git add app.js
  commit_with_review "feat: add js entry"

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"[Gate 5] Running eslint"* ]]
  [[ "$output" == *"[Gate 5] ESLint passed"* ]]
  grep -Fq "eslint --no-warn-ignored app.js" "$NPX_LOG"
}

@test "Gate 8 runs production verification and passes for deployment changes" {
  cd "$SANDBOX"
  setup_remote

  create_verify_production_stub 0 "verified"
  echo 'module.exports = {}' > next.config.js
  git add next.config.js
  commit_with_review "feat: tweak deploy config"

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"[Gate 8] Deployment files detected"* ]]
  [[ "$output" == *"[Gate 8] Production verification passed"* ]]
}

@test "Gate 8 blocks non-workspace pushes when production verification fails" {
  cd "$SANDBOX"
  setup_remote

  create_verify_production_stub 1 "verify failed"
  echo 'FROM scratch' > Dockerfile
  git add Dockerfile
  git commit -q -m "chore: add dockerfile" 2>/dev/null

  run_push

  [ "$status" -ne 0 ]
  [[ "$output" == *"[Gate 8] Production verification failed"* ]]
}

@test "Gate 8 warns only in workspace mode when production verification fails" {
  cd "$SANDBOX"
  enable_workspace_mode
  setup_remote

  create_verify_production_stub 1 "verify failed"
  echo 'FROM scratch' > Dockerfile
  git add Dockerfile
  git commit -q -m "chore: add dockerfile" 2>/dev/null

  run_push

  [ "$status" -eq 0 ]
  [[ "$output" == *"[Gate 8] Production verification failed (workspace mode: warn only)"* ]]
}
