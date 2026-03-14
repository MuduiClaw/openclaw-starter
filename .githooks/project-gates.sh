#!/usr/bin/env bash
# Project-specific gates for ClawKing
# Sourced by ~/clawd/.githooks/prepare-commit-msg after global gates
# Available vars: $COMMIT_MSG_FILE, $COMMIT_MSG_LINE, $STAGED_FILES, $STAGED_COUNT
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

# ============================================================
# Gate P1: Secrets scan — zero tolerance for real credentials
# ============================================================
secret_hits=0
for f in $STAGED_FILES; do
  [[ -z "$f" ]] && continue
  # Skip binary/lock files
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.woff*|*.ttf|*.eot|*.lock|*.sum) continue ;;
  esac
  [[ -f "$repo_root/$f" ]] || continue
  if grep -qE '(sk-[a-zA-Z0-9]{20,}|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|xoxb-[0-9]{10,}|AIza[a-zA-Z0-9_-]{35})' "$repo_root/$f" 2>/dev/null; then
    echo "  ❌ [P1 Secrets] Real credential detected in: $f"
    secret_hits=$((secret_hits + 1))
  fi
done

if [[ $secret_hits -gt 0 ]]; then
  echo ""
  echo "⛔ COMMIT BLOCKED — $secret_hits file(s) contain real API keys/tokens"
  echo "  Use placeholder format: __YOUR_xxx__ (see AGENTS.md 安全红线)"
  exit 1
fi

# ============================================================
# Gate P2: No private references — block personal paths/names
# ============================================================
private_hits=0
for f in $STAGED_FILES; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.png|*.jpg|*.gif|*.ico|*.woff*|*.ttf|*.eot|*.lock|*.sum|CHANGELOG.md) continue ;;
  esac
  [[ -f "$repo_root/$f" ]] || continue
  # Build pattern from parts to avoid self-triggering this gate
  _priv_pat="/Users/(mu""dui|wang""shufu)/|hxr""bot@|木""对|雪""哒|ai""hub|bit""mart"
  if grep -qE "$_priv_pat" "$repo_root/$f" 2>/dev/null; then
    echo "  ❌ [P2 Privacy] Private reference in: $f"
    private_hits=$((private_hits + 1))
  fi
done

if [[ $private_hits -gt 0 ]]; then
  echo ""
  echo "⛔ COMMIT BLOCKED — $private_hits file(s) contain private references"
  echo "  Remove personal paths/names before committing to public repo"
  exit 1
fi

echo "  ✅ Project gates: secrets clean, no private refs"
