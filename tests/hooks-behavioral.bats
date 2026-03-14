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
  git init -q -b main
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
  # Skip if shellcheck not installed (CI may not have it)
  command -v shellcheck &>/dev/null || skip "shellcheck not installed"
  cd "$SANDBOX"
  # SC2164 (warning): Use 'cd ... || exit' in case cd fails
  printf '#!/bin/bash\ncd /somewhere\nls\n' > bad.sh
  git add bad.sh
  run env REVIEWED=1 git commit -m "feat: add bad script" 2>&1
  # Should fail (shellcheck -S warning catches SC2164)
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

# ─── Security: anti-forgery tests ───

@test "injected Pre-commit-gate trailer is stripped and regenerated" {
  cd "$SANDBOX"
  printf '#!/bin/bash\necho "legit"\n' > app.sh
  git add app.sh
  # Attempt to inject a fake tree-hash trailer via -m
  fake_hash="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  run env REVIEWED=1 git commit -m "feat: inject trailer" -m "Pre-commit-gate: $fake_hash" 2>&1
  [ "$status" -eq 0 ]
  # The real trailer should be the actual tree hash, NOT our injected one
  trailer=$(git log -1 --format='%B' | grep 'Pre-commit-gate:' | awk '{print $2}')
  [ "$trailer" != "$fake_hash" ]
  actual=$(git rev-parse HEAD^{tree})
  [ "$trailer" = "$actual" ]
}

# ─── Gate 6: E2E awareness behavioral tests ───
# Gate 6 tests need a remote to push to. We set up a bare repo as origin.

_setup_remote() {
  local bare="$BATS_TEST_TMPDIR/remote.git"
  rm -rf "$bare"
  git clone --bare "$SANDBOX" "$bare" 2>/dev/null
  cd "$SANDBOX"
  git remote remove origin 2>/dev/null || true
  git remote add origin "$bare"
}

@test "Gate 6 blocks page.tsx change without e2e test" {
  cd "$SANDBOX"
  # Create a playwright config to trigger Gate 6
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  _setup_remote

  # Change a page file without e2e
  mkdir -p app
  echo "export default function Page() { return <div/>; }" > app/page.tsx
  git add app/page.tsx
  REVIEWED=1 git commit -q -m "feat: add home page" 2>/dev/null

  # Push should fail Gate 6
  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  echo "# STATUS: $status" >&3
  [[ "$output" == *"Gate 6"* ]] || [[ "$output" == *"E2E"* ]]
  [[ "$status" -ne 0 ]]
}

@test "Gate 6 passes with [e2e-ack] exemption" {
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  _setup_remote

  mkdir -p app
  echo "export default function Page() { return <div/>; }" > app/page.tsx
  git add app/page.tsx
  REVIEWED=1 git commit -q -m "feat: add home page [e2e-ack]" 2>/dev/null

  run git push origin main 2>&1
  [[ "$output" != *"❌"*"Gate 6"* ]]
}

@test "Gate 6 warns when vitest config present but no e2e" {
  cd "$SANDBOX"
  # Gate 6 now checks project-level vitest.config.ts, not push-level test files
  echo '{}' > playwright.config.ts
  echo '{}' > vitest.config.ts
  git add playwright.config.ts vitest.config.ts
  REVIEWED=1 git commit -q -m "chore: add configs" 2>/dev/null

  _setup_remote

  # Include a unit test to satisfy Gate 4 TDD, but no e2e test
  mkdir -p app src/__tests__
  echo "export default function Page() { return <div/>; }" > app/page.tsx
  echo "test('x', () => {})" > src/__tests__/page.test.ts
  git add app/page.tsx src/__tests__/page.test.ts
  REVIEWED=1 git commit -q -m "feat: add page with unit test but no e2e" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  [[ "$output" == *"warning only"* ]] || [[ "$output" == *"⚠️"* ]]
  [[ "$output" != *"❌"*"Gate 6"* ]]
}

@test "Gate 6 skips when no playwright.config.ts" {
  cd "$SANDBOX"
  _setup_remote

  mkdir -p app
  echo "export default function Page() { return <div/>; }" > app/page.tsx
  git add app/page.tsx
  REVIEWED=1 git commit -q -m "feat: add page" 2>/dev/null

  run git push origin main 2>&1
  [[ "$output" != *"Gate 6"* ]]
}

@test "amend regenerates tree-hash trailer" {
  cd "$SANDBOX"
  printf '#!/bin/bash\necho "v1"\n' > app.sh
  git add app.sh
  env REVIEWED=1 git commit -q -m "feat: v1" 2>/dev/null
  old_trailer=$(git log -1 --format='%B' | grep 'Pre-commit-gate:' | awk '{print $2}')
  # Amend with different content
  printf '#!/bin/bash\necho "v2"\n' > app.sh
  git add app.sh
  env REVIEWED=1 git commit -q --amend -m "feat: v2" 2>/dev/null
  new_trailer=$(git log -1 --format='%B' | grep 'Pre-commit-gate:' | awk '{print $2}')
  actual=$(git rev-parse HEAD^{tree})
  [ "$new_trailer" = "$actual" ]
  [ "$new_trailer" != "$old_trailer" ]
}

# ─── Gate 7: Spec delivery screenshot verification ───

@test "Gate 7 warns when spec delivered without screenshots" {
  cd "$SANDBOX"
  # Setup pw + e2e first
  echo '{}' > playwright.config.ts
  mkdir -p e2e
  cat > e2e/smoke.spec.ts << 'EOF'
import { test, expect } from "@playwright/test";
test("home renders", async ({ page }) => {
  await page.goto("/");
});
test("about renders", async ({ page }) => {
  await page.goto("/about");
});
EOF
  git add playwright.config.ts e2e/smoke.spec.ts
  REVIEWED=1 git commit -q -m "chore: add e2e" 2>/dev/null

  # Setup remote BEFORE the delivery commit
  _setup_remote

  # Now make the delivery commit (this is what gets pushed)
  mkdir -p tasks
  cat > tasks/my-feature.md << 'EOF'
# Spec: My Feature
- **Status**: delivered
EOF
  git add tasks/my-feature.md
  REVIEWED=1 git commit -q -m "feat: deliver my-feature [spec:my-feature]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  # Should warn about missing screenshots
  [[ "$output" == *"Gate 7"* ]]
  [[ "$output" == *"no screenshots"* ]] || [[ "$output" == *"⚠️"* ]]
  # Should NOT block (warn only)
  [[ "$status" -eq 0 ]]
}

@test "Gate 7 passes when spec delivered with screenshots" {
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  mkdir -p e2e
  cat > e2e/smoke.spec.ts << 'EOF'
import { test, expect } from "@playwright/test";
test("home renders", async ({ page }) => {
  await page.goto("/");
});
test("about renders", async ({ page }) => {
  await page.goto("/about");
});
EOF
  git add playwright.config.ts e2e/smoke.spec.ts
  REVIEWED=1 git commit -q -m "chore: add e2e scaffold" 2>/dev/null

  # Remote BEFORE delivery commit
  _setup_remote

  mkdir -p tasks docs/acceptance/my-feature
  cat > tasks/my-feature.md << 'EOF'
# Spec: My Feature
- **Status**: delivered
EOF
  # Create distinct screenshots (different content so dedup gate passes)
  printf '\x89PNG-home' > docs/acceptance/my-feature/E01-home.png
  printf '\x89PNG-about' > docs/acceptance/my-feature/E02-about.png
  git add tasks/my-feature.md docs/acceptance/my-feature/
  REVIEWED=1 git commit -q -m "feat: deliver my-feature with screenshots [spec:my-feature]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  [[ "$output" == *"Gate 7"* ]]
  [[ "$output" == *"✅"*"Gate 7"* ]]
  [[ "$status" -eq 0 ]]
}

@test "Gate 7 detects delivered status beyond line 5" {
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  # Remote BEFORE delivery
  _setup_remote

  # Spec with delivered on line 10 (beyond old head -5 limit)
  mkdir -p tasks
  cat > tasks/deep-status.md << 'EOF'
# Spec: Deep Status
- **Author**: test
- **Tags**: e2e, infra
- **Priority**: P0
- **Created**: 2026-03-15
- **Updated**: 2026-03-15
- **Reviewer**: oracle
- **Approver**: mudui
- **Sprint**: W1
- **Status**: delivered
EOF
  git add tasks/deep-status.md
  REVIEWED=1 git commit -q -m "feat: deliver deep-status [spec:deep-status]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  # Should detect delivered even on line 10
  [[ "$output" == *"Gate 7"* ]]
  [[ "$output" == *"no screenshots"* ]] || [[ "$output" == *"⚠️"* ]]
  [[ "$status" -eq 0 ]]
}

@test "Gate 7 blocks duplicate screenshots (dedup gate)" {
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  _setup_remote

  mkdir -p tasks docs/acceptance/dup-spec
  cat > tasks/dup-spec.md << 'EOF'
# Spec: Dup Spec
- **Status**: delivered
EOF
  # Create 4 screenshots but 2 are identical (copy of same content)
  printf '\x89PNG-page-a' > docs/acceptance/dup-spec/E01-home.png
  printf '\x89PNG-page-a' > docs/acceptance/dup-spec/E02-about.png
  printf '\x89PNG-page-b' > docs/acceptance/dup-spec/E03-settings.png
  printf '\x89PNG-page-c' > docs/acceptance/dup-spec/E04-profile.png
  git add tasks/dup-spec.md docs/acceptance/dup-spec/
  REVIEWED=1 git commit -q -m "feat: deliver dup-spec [spec:dup-spec]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  [[ "$output" == *"Gate 7"* ]]
  [[ "$output" == *"duplicates"* ]]
  [[ "$output" == *"糊弄"* ]]
  # Should block the push
  [[ "$status" -ne 0 ]]
}

@test "Gate 7c blocks visually similar screenshots (same page, different timestamp)" {
  command -v magick >/dev/null 2>&1 || skip "ImageMagick not available"
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  _setup_remote

  mkdir -p tasks docs/acceptance/visual-dup
  cat > tasks/visual-dup.md << 'EOF'
# Spec: Visual Dup
- **Status**: delivered
EOF
  # Create 3 screenshots: 2 are visually near-identical (1 pixel diff), 1 is different
  # E01 and E02 have different hashes but RMSE < 0.02 (visually same page)
  magick -size 200x200 xc:white docs/acceptance/visual-dup/E01-home.png
  magick -size 200x200 xc:white -fill "rgb(255,255,254)" -draw "point 0,0" docs/acceptance/visual-dup/E02-home-again.png
  magick -size 200x200 xc:blue docs/acceptance/visual-dup/E03-settings.png
  git add tasks/visual-dup.md docs/acceptance/visual-dup/
  REVIEWED=1 git commit -q -m "feat: deliver visual-dup [spec:visual-dup]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  [[ "$output" == *"视觉重复"* ]]
  [[ "$output" == *"RMSE"* ]]
  [[ "$status" -ne 0 ]]
}

@test "Gate 7 passes when all screenshots are unique" {
  cd "$SANDBOX"
  echo '{}' > playwright.config.ts
  git add playwright.config.ts
  REVIEWED=1 git commit -q -m "chore: add pw config" 2>/dev/null

  _setup_remote

  mkdir -p tasks docs/acceptance/unique-spec
  cat > tasks/unique-spec.md << 'EOF'
# Spec: Unique Spec
- **Status**: delivered
EOF
  printf '\x89PNG-page-1' > docs/acceptance/unique-spec/E01-home.png
  printf '\x89PNG-page-2' > docs/acceptance/unique-spec/E02-about.png
  printf '\x89PNG-page-3' > docs/acceptance/unique-spec/E03-settings.png
  git add tasks/unique-spec.md docs/acceptance/unique-spec/
  REVIEWED=1 git commit -q -m "feat: deliver unique-spec [spec:unique-spec]" 2>/dev/null

  run git push origin main 2>&1
  echo "# OUTPUT: $output" >&3
  [[ "$output" == *"Gate 7"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"unique"* ]]
  [[ "$status" -eq 0 ]]
}
