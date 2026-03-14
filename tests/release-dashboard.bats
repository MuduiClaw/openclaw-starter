#!/usr/bin/env bats
# Tests for scripts/release-dashboard.sh

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TEST_ROOT="$BATS_TEST_TMPDIR/release-dashboard"
  TEST_HOME="$TEST_ROOT/home"
  STUB_BIN="$TEST_ROOT/bin"
  COMMAND_LOG="$TEST_ROOT/commands.log"
  GH_LOG="$TEST_ROOT/gh.log"
  NPM_LOG="$TEST_ROOT/npm.log"
  GH_CAPTURE_TARBALL="$TEST_ROOT/captured.tar.gz"

  rm -rf "$TEST_ROOT"
  rm -f /tmp/infra-dashboard-standalone.tar.gz

  mkdir -p "$TEST_HOME/projects/infra-dashboard" "$STUB_BIN"
  : > "$COMMAND_LOG"
  : > "$GH_LOG"
  : > "$NPM_LOG"

  create_stub_node
  create_stub_git
  create_stub_npm
  create_stub_gh
  create_stub_curl
}

teardown() {
  rm -f /tmp/infra-dashboard-standalone.tar.gz
}

create_dashboard() {
  local version="$1"
  local with_server="${2:-1}"
  local with_sqlite="${3:-1}"
  local dashboard_dir="$TEST_HOME/projects/infra-dashboard"

  mkdir -p "$dashboard_dir/.next/standalone/.next"
  mkdir -p "$dashboard_dir/.next/static"
  mkdir -p "$dashboard_dir/public"

  printf '{ "version": "%s" }
' "$version" > "$dashboard_dir/package.json"
  printf 'console.log("server")
' > "$dashboard_dir/app.js"
  printf 'static asset
' > "$dashboard_dir/.next/static/app.js"
  printf 'public asset
' > "$dashboard_dir/public/logo.txt"

  if [[ "$with_server" == "1" ]]; then
    printf 'console.log("server")
' > "$dashboard_dir/.next/standalone/server.js"
  fi

  if [[ "$with_sqlite" == "1" ]]; then
    mkdir -p "$dashboard_dir/node_modules/better-sqlite3/build/Release"
    mkdir -p "$dashboard_dir/node_modules/better-sqlite3/src"
    mkdir -p "$dashboard_dir/node_modules/better-sqlite3/deps"
    mkdir -p "$dashboard_dir/.next/standalone/node_modules/better-sqlite3"

    printf 'native addon
' > "$dashboard_dir/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
    printf 'binding
' > "$dashboard_dir/node_modules/better-sqlite3/binding.gyp"
    printf 'source
' > "$dashboard_dir/node_modules/better-sqlite3/src/addon.cc"
    printf 'dependency
' > "$dashboard_dir/node_modules/better-sqlite3/deps/sqlite3.c"
  fi
}

create_stub_node() {
  cat <<'EOF' > "$STUB_BIN/node"
#!/bin/sh
set -eu

if [ "${1-}" = "--version" ]; then
  printf '%s
' "${NODE_VERSION:-v20.11.1}"
  exit 0
fi

if [ "${1-}" = "-e" ]; then
  script="${2-}"
  package_json=$(printf '%s' "$script" | sed "s/.*require('//;s/').*//" )
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$package_json"
  exit 0
fi

printf 'unexpected node invocation: %s
' "$*" >&2
exit 1
EOF
  chmod +x "$STUB_BIN/node"
}

create_stub_git() {
  cat <<'EOF' > "$STUB_BIN/git"
#!/bin/sh
set -eu
printf '%s
' "$*" >> "$COMMAND_LOG"
exit 0
EOF
  chmod +x "$STUB_BIN/git"
}

create_stub_npm() {
  cat <<'EOF' > "$STUB_BIN/npm"
#!/bin/sh
set -eu
printf '%s|%s
' "${NEXT_PUBLIC_EDITION-}" "$*" >> "$NPM_LOG"
exit 0
EOF
  chmod +x "$STUB_BIN/npm"
}

create_stub_gh() {
  cat <<'EOF' > "$STUB_BIN/gh"
#!/bin/sh
set -eu

printf 'gh %s
' "$*" >> "$GH_LOG"

if [ "$#" -ge 3 ] && [ "$1" = "release" ] && [ "$2" = "view" ]; then
  printf 'view:%s
' "$3" >> "$GH_LOG"
  if [ "${GH_RELEASE_EXISTS:-0}" = "1" ]; then
    exit 0
  fi
  exit 1
fi

if [ "$#" -ge 3 ] && [ "$1" = "release" ] && [ "$2" = "delete" ]; then
  printf 'delete:%s
' "$3" >> "$GH_LOG"
  exit 0
fi

if [ "$#" -ge 4 ] && [ "$1" = "release" ] && [ "$2" = "create" ]; then
  tag="$3"
  asset="$4"

  printf 'create:%s
' "$tag" >> "$GH_LOG"
  printf 'asset:%s
' "$asset" >> "$GH_LOG"

  shift 4
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --repo)
        printf 'repo:%s
' "$2" >> "$GH_LOG"
        shift 2
        ;;
      --title)
        printf 'title:%s
' "$2" >> "$GH_LOG"
        shift 2
        ;;
      --notes)
        printf 'notes:%s
' "$2" >> "$GH_LOG"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [ -n "${GH_CAPTURE_TARBALL:-}" ]; then
    cp "$asset" "$GH_CAPTURE_TARBALL"
    tar -tzf "$asset" > "${GH_CAPTURE_TARBALL}.list"
  fi

  exit 0
fi

if [ "${1-}" = "api" ]; then
  printf 'api:%s
' "$*" >> "$GH_LOG"
  exit 0
fi

printf 'unexpected gh invocation: %s
' "$*" >&2
exit 1
EOF
  chmod +x "$STUB_BIN/gh"
}

create_stub_curl() {
  cat <<'EOF' > "$STUB_BIN/curl"
#!/bin/sh
set -eu

if [ "${CURL_EXIT_CODE:-0}" -ne 0 ]; then
  exit "${CURL_EXIT_CODE}"
fi

printf '%s' "${CURL_HTTP_CODE:-200}"
EOF
  chmod +x "$STUB_BIN/curl"
}

run_release_dashboard() {
  run env \
    HOME="$TEST_HOME" \
    PATH="$STUB_BIN:$PATH" \
    COMMAND_LOG="$COMMAND_LOG" \
    GH_LOG="$GH_LOG" \
    NPM_LOG="$NPM_LOG" \
    GH_CAPTURE_TARBALL="$GH_CAPTURE_TARBALL" \
    GH_RELEASE_EXISTS="${GH_RELEASE_EXISTS:-0}" \
    CURL_HTTP_CODE="${CURL_HTTP_CODE:-200}" \
    CURL_EXIT_CODE="${CURL_EXIT_CODE:-0}" \
    NODE_VERSION="${NODE_VERSION:-v20.11.1}" \
    bash "$REPO_ROOT/scripts/release-dashboard.sh" "$@"
}

@test "release-dashboard.sh rejects unknown arguments" {
  run_release_dashboard --bogus

  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown arg: --bogus"* ]]
}

@test "release-dashboard.sh auto-detects version, packages standalone output, and uploads release" {
  create_dashboard "1.2.3"

  run_release_dashboard

  [ "$status" -eq 0 ]
  [[ "$output" == *"Building infra-dashboard v1.2.3"* ]]
  [[ "$output" == *"Included better-sqlite3 native addon"* ]]
  [[ "$output" == *"Download URL verified (HTTP 200)"* ]]
  [[ "$output" == *"Released: https://github.com/MuduiClaw/ClawKing/releases/tag/dashboard-v1.2.3"* ]]
  [[ "$output" == *"Done. infra-dashboard v1.2.3 published to MuduiClaw/ClawKing releases."* ]]

  grep -Fq "|install --prefer-offline" "$NPM_LOG"
  grep -Fq "starter|run build" "$NPM_LOG"

  grep -Fq "create:dashboard-v1.2.3" "$GH_LOG"
  grep -Fq "repo:MuduiClaw/ClawKing" "$GH_LOG"
  grep -Fq "title:infra-dashboard v1.2.3 (standalone)" "$GH_LOG"
  grep -Fq "notes:Pre-built infra-dashboard v1.2.3 standalone bundle." "$GH_LOG"

  [ -f "${GH_CAPTURE_TARBALL}.list" ]
  grep -Fq "./server.js" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./.next/static/app.js" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./public/logo.txt" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./node_modules/better-sqlite3/build/Release/better_sqlite3.node" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./node_modules/better-sqlite3/binding.gyp" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./node_modules/better-sqlite3/src/addon.cc" "${GH_CAPTURE_TARBALL}.list"
  grep -Fq "./node_modules/better-sqlite3/deps/sqlite3.c" "${GH_CAPTURE_TARBALL}.list"

  [ ! -e /tmp/infra-dashboard-standalone.tar.gz ]
}

@test "release-dashboard.sh respects --version and deletes an existing release before recreating it" {
  create_dashboard "0.1.0"
  GH_RELEASE_EXISTS=1

  run_release_dashboard --version 9.9.9

  [ "$status" -eq 0 ]
  [[ "$output" == *"Building infra-dashboard v9.9.9"* ]]
  [[ "$output" == *"Deleting existing release dashboard-v9.9.9"* ]]

  grep -Fq "view:dashboard-v9.9.9" "$GH_LOG"
  grep -Fq "delete:dashboard-v9.9.9" "$GH_LOG"
  grep -Fq "api:api -X DELETE repos/MuduiClaw/ClawKing/git/refs/tags/dashboard-v9.9.9" "$GH_LOG"
  grep -Fq "create:dashboard-v9.9.9" "$GH_LOG"
}

@test "release-dashboard.sh fails when the standalone build output is missing server.js" {
  create_dashboard "2.0.0" 0 0

  run_release_dashboard

  [ "$status" -ne 0 ]
  [[ "$output" == *"Standalone build not found. Check next.config.ts has output: 'standalone'"* ]]
  ! grep -Fq "create:" "$GH_LOG"
}

@test "release-dashboard.sh falls back to HTTP 000 when download verification curl fails" {
  create_dashboard "3.4.5"
  CURL_EXIT_CODE=1

  run_release_dashboard

  [ "$status" -eq 0 ]
  [[ "$output" == *"Download URL returned HTTP 000"* ]]
  [[ "$output" == *"Done. infra-dashboard v3.4.5 published to MuduiClaw/ClawKing releases."* ]]
}
