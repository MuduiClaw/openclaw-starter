#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# OpenClaw Safe Upgrade (集中式入口)
# =============================================================================
# 用法:
#   bash ~/clawd/scripts/safe-upgrade-openclaw.sh
#   bash ~/clawd/scripts/safe-upgrade-openclaw.sh 2026.3.2
#   bash ~/clawd/scripts/safe-upgrade-openclaw.sh --dry-run
#   bash ~/clawd/scripts/safe-upgrade-openclaw.sh --strict-patches
#
# 设计目标:
# 1) 升级前后可验证（preflight）
# 2) 升级后自动重打本地补丁（集中在本脚本 + hooks 目录）
# 3) 避免 openclaw gateway restart（SIGUSR1 drain bug）
# 4) 失败自动回滚（配置 + 旧版本）
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK_DIR="$SCRIPT_DIR/openclaw-upgrade-hooks"
PREFLIGHT_SCRIPT="$SCRIPT_DIR/gateway-preflight.sh"
CAPTURE_SCRIPT="$HOOK_DIR/sync-captured-overrides.sh"
# Dynamic resolution: prefer nvm global, fallback to /opt/homebrew symlink
resolve_openclaw_root() {
  local nvm_root=""
  nvm_root="$(npm root -g 2>/dev/null || true)"
  if [[ -n "$nvm_root" && -d "$nvm_root/openclaw" ]]; then
    echo "$nvm_root/openclaw"
    return
  fi
  # Fallback: Homebrew path (may be symlink to nvm)
  if [[ -d "/opt/homebrew/lib/node_modules/openclaw" ]]; then
    echo "/opt/homebrew/lib/node_modules/openclaw"
    return
  fi
  echo "/opt/homebrew/lib/node_modules/openclaw"  # default even if missing
}
OPENCLAW_ROOT="$(resolve_openclaw_root)"

VERSION="latest"
DRY_RUN=false
STRICT_PATCHES=false
SKIP_PATCHES=false
SKIP_CAPTURE=false

usage() {
  cat <<'EOF'
Usage:
  bash ~/clawd/scripts/safe-upgrade-openclaw.sh [version]
  bash ~/clawd/scripts/safe-upgrade-openclaw.sh --dry-run

Options:
  --dry-run        only run checks, no install
  --strict-patches fail upgrade when patch step fails
  --skip-patches   skip local patch re-apply
  --skip-capture   skip auto capture local overrides before upgrade
  -h, --help       show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --strict-patches)
      STRICT_PATCHES=true
      shift
      ;;
    --skip-patches)
      SKIP_PATCHES=true
      shift
      ;;
    --skip-capture)
      SKIP_CAPTURE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ "$1" == --* ]]; then
        echo "Unknown option: $1" >&2
        exit 64
      fi
      VERSION="$1"
      shift
      ;;
  esac
done

TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.openclaw/backup/upgrade-$TS"
LOG_FILE="$BACKUP_DIR/upgrade.log"
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
PLIST_FILE="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
HEALTH_TIMEOUT=45

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }
step() { echo -e "\n${GREEN}[STEP]${NC} $*"; }

mkdir -p "$BACKUP_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

UID_NUM="$(id -u)"
LAUNCHD_LABEL="ai.openclaw.gateway"

safe_gateway_restart() {
  local zombie_pids
  zombie_pids=$(/usr/sbin/lsof -ti :18789 2>/dev/null || true)
  if [[ -n "$zombie_pids" ]]; then
    warn "Killing stale gateway pids: $zombie_pids"
    echo "$zombie_pids" | xargs kill -9 2>/dev/null || true
  fi

  sleep 2
  if launchctl kickstart -k "gui/$UID_NUM/$LAUNCHD_LABEL" >/dev/null 2>&1; then
    log "Gateway kickstart ok"
    return 0
  fi

  warn "kickstart failed; fallback openclaw gateway start"
  openclaw gateway start >/dev/null 2>&1 || true
}

wait_gateway_healthy() {
  local timeout="${1:-45}"
  for i in $(seq 1 "$timeout"); do
    if openclaw health >/dev/null 2>&1; then
      log "Gateway healthy after ${i}s"
      # Check for plugin load failures in recent err.log (last 30 lines)
      local plugin_errors
      plugin_errors=$(tail -30 "$HOME/.openclaw/logs/gateway.err.log" 2>/dev/null \
        | grep -c "failed to load plugin\|Cannot find module" || echo "0")
      if [[ "$plugin_errors" -gt 0 ]]; then
        warn "Gateway healthy but $plugin_errors plugin load error(s) detected in err.log"
      fi
      return 0
    fi
    sleep 1
  done
  return 1
}

resolve_install_bins() {
  local bins=()
  local path_npm=""
  local plist_npm=""

  path_npm="$(command -v npm 2>/dev/null || true)"
  if [[ -n "$path_npm" ]]; then
    bins+=("$path_npm")
  fi

  if [[ -f "$PLIST_FILE" ]]; then
    local plist_node
    # Match both Homebrew Cellar paths and custom node symlinks (e.g. /usr/local/bin/node25)
    plist_node="$(grep -oE '/[^<]*bin/node[0-9]*' "$PLIST_FILE" 2>/dev/null | head -1 || true)"
    if [[ -n "$plist_node" ]]; then
      # Resolve symlink to find the actual node binary's directory
      local real_node
      real_node="$(readlink -f "$plist_node" 2>/dev/null || readlink "$plist_node" 2>/dev/null || echo "$plist_node")"
      if [[ -f "$real_node" ]]; then
        plist_npm="$(dirname "$real_node")/npm"
        if [[ -f "$plist_npm" && "$plist_npm" != "$path_npm" ]]; then
          bins+=("$plist_npm")
        fi
      fi
    fi
  fi

  if [[ ${#bins[@]} -gt 0 ]]; then
    printf '%s\n' "${bins[@]}" | awk '!seen[$0]++'
  fi
}

npm_install_openclaw() {
  local target_ver="$1"
  local failed=0
  local bins=()

  while IFS= read -r npm_path; do
    [[ -n "$npm_path" ]] && bins+=("$npm_path")
  done < <(resolve_install_bins)

  if [[ ${#bins[@]} -eq 0 ]]; then
    err "No npm found"
    return 1
  fi

  for npm_bin in "${bins[@]}"; do
    log "Installing via: $npm_bin"
    if ! env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
      "$npm_bin" i -g "openclaw@$target_ver" --no-audit --no-fund; then
      warn "npm install failed for: $npm_bin"
      failed=$((failed + 1))
    fi
  done

  [[ $failed -lt ${#bins[@]} ]]
}

backup_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    cp -a "$f" "$BACKUP_DIR/"
    log "Backed up: $(basename "$f")"
  fi
}

auto_capture_local_overrides() {
  if [[ "$SKIP_CAPTURE" == "true" ]]; then
    warn "skip local override capture by flag"
    return 0
  fi

  if [[ ! -x "$CAPTURE_SCRIPT" ]]; then
    warn "capture script missing/unexecutable: $CAPTURE_SCRIPT"
    return 0
  fi

  step "Capture local overrides (auto)"
  if ! OPENCLAW_ROOT="$OPENCLAW_ROOT" "$CAPTURE_SCRIPT" --version "$CURRENT_VER"; then
    if [[ "$STRICT_PATCHES" == "true" ]]; then
      err "capture local overrides failed (strict mode)"
      return 1
    fi
    warn "capture local overrides failed (non-strict, continue)"
  fi
}

apply_local_patches() {
  if [[ "$SKIP_PATCHES" == "true" ]]; then
    warn "skip local patches by flag"
    return 0
  fi

  step "Apply local patches (centralized hooks)"

  if [[ ! -d "$HOOK_DIR" ]]; then
    warn "hook dir missing: $HOOK_DIR"
    return 0
  fi

  local hook
  for hook in "$HOOK_DIR"/*.sh; do
    [[ -e "$hook" ]] || continue

    # capture 脚本只在升级前 Phase 1.5 执行，不作为 post-install hook
    if [[ "$hook" == "$CAPTURE_SCRIPT" ]]; then
      continue
    fi

    if [[ ! -x "$hook" ]]; then
      warn "hook not executable, skip: $hook"
      continue
    fi
    log "run hook: $hook"
    if ! OPENCLAW_ROOT="$OPENCLAW_ROOT" "$hook"; then
      if [[ "$STRICT_PATCHES" == "true" ]]; then
        err "hook failed (strict mode): $hook"
        return 1
      fi
      warn "hook failed (non-strict): $hook"
    fi
  done

  # 观测值
  local rfc_count
  rfc_count=$(rg -n "allowRfc2544BenchmarkRange: true" "$OPENCLAW_ROOT/dist" 2>/dev/null | wc -l | tr -d ' ')
  log "observed allowRfc2544BenchmarkRange markers: $rfc_count"
}

# =============================================================================
# Phase 1: Pre-flight
# =============================================================================
log "Start: $(date '+%Y-%m-%d %H:%M:%S %Z')"
log "Target version: $VERSION"
log "Dry run: $DRY_RUN"
log "Strict patches: $STRICT_PATCHES"
log "Skip capture: $SKIP_CAPTURE"
log "Backup dir: $BACKUP_DIR"

step "Phase 1: Pre-flight"
# Read version from actual package.json (not PATH-dependent `openclaw --version`)
if [[ -f "$OPENCLAW_ROOT/package.json" ]]; then
  CURRENT_VER="$(node -p "require('$OPENCLAW_ROOT/package.json').version" 2>/dev/null || echo 'unknown')"
else
  CURRENT_VER="$(openclaw --version 2>/dev/null || echo 'unknown')"
fi
LATEST_VER="$(env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY npm view openclaw version 2>/dev/null || echo 'unknown')"
TARGET_VER="$VERSION"
[[ "$TARGET_VER" == "latest" ]] && TARGET_VER="$LATEST_VER"

log "Current version: $CURRENT_VER"
log "Latest available: $LATEST_VER"
log "Resolved target: $TARGET_VER"

if [[ "$CURRENT_VER" == "$TARGET_VER" ]]; then
  warn "Already on target version: $TARGET_VER"
fi

NODE_PATH="$(command -v node 2>/dev/null || true)"
if [[ -z "$NODE_PATH" ]]; then
  err "Node.js not found"
  exit 1
fi
log "Node: $NODE_PATH ($(node --version 2>/dev/null || echo unknown))"

if [[ -x "$PREFLIGHT_SCRIPT" ]]; then
  if bash "$PREFLIGHT_SCRIPT" --phase pre; then
    log "Preflight pre-phase passed"
  else
    warn "Preflight pre-phase failed (continue for diagnostics)"
  fi
else
  warn "Preflight script missing: $PREFLIGHT_SCRIPT"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry run complete"
  exit 0
fi

# =============================================================================
# Phase 1.5: Capture local overrides
# =============================================================================
auto_capture_local_overrides || {
  err "Local override capture failed"
  exit 1
}

# =============================================================================
# Phase 2: Backup
# =============================================================================
step "Phase 2: Backup"
backup_file "$CONFIG_FILE"
backup_file "$HOME/.openclaw/cron/jobs.json"
backup_file "$PLIST_FILE"
openclaw status --json > "$BACKUP_DIR/status.before.json" 2>/dev/null || true
openclaw cron list --all --json > "$BACKUP_DIR/cron.list.before.json" 2>/dev/null || true

# =============================================================================
# Phase 3: Upgrade
# =============================================================================
step "Phase 3: Install openclaw@$TARGET_VER"
if ! npm_install_openclaw "$TARGET_VER"; then
  err "npm install failed"
  exit 1
fi

# Re-resolve OPENCLAW_ROOT after install (npm may have changed paths)
OPENCLAW_ROOT="$(resolve_openclaw_root)"
log "OPENCLAW_ROOT: $OPENCLAW_ROOT"

if [[ -f "$OPENCLAW_ROOT/package.json" ]]; then
  NEW_VER="$(node -p "require('$OPENCLAW_ROOT/package.json').version" 2>/dev/null || echo 'unknown')"
else
  NEW_VER="$(openclaw --version 2>/dev/null || echo 'unknown')"
fi
log "Installed: $NEW_VER"

# Maintain /opt/homebrew symlinks if gateway plist references that path
if [[ "$OPENCLAW_ROOT" != "/opt/homebrew/lib/node_modules/openclaw" ]]; then
  BREW_LIB="/opt/homebrew/lib/node_modules/openclaw"
  if [[ -L "$BREW_LIB" || -d "$BREW_LIB" ]]; then
    rm -rf "$BREW_LIB"
  fi
  ln -s "$OPENCLAW_ROOT" "$BREW_LIB" 2>/dev/null && log "Updated /opt/homebrew/lib symlink → $OPENCLAW_ROOT" || true

  BREW_BIN="/opt/homebrew/bin/openclaw"
  NVM_BIN="$(dirname "$(npm root -g)" 2>/dev/null)/bin/openclaw"
  if [[ -f "$NVM_BIN" && ( -L "$BREW_BIN" || ! -e "$BREW_BIN" ) ]]; then
    rm -f "$BREW_BIN"
    ln -s "$NVM_BIN" "$BREW_BIN" 2>/dev/null && log "Updated /opt/homebrew/bin symlink" || true
  fi
fi

# =============================================================================
# Phase 4: Patch
# =============================================================================
apply_local_patches || {
  err "Patch phase failed"
  exit 1
}

# =============================================================================
# Phase 5: Restart + Health + Rollback
# =============================================================================
step "Phase 5: Restart + health"
safe_gateway_restart || true

if ! wait_gateway_healthy "$HEALTH_TIMEOUT"; then
  err "Gateway unhealthy after upgrade, start rollback"

  if [[ -f "$BACKUP_DIR/openclaw.json" ]]; then
    cp "$BACKUP_DIR/openclaw.json" "$CONFIG_FILE"
    warn "Config restored"
  fi

  warn "Reinstall previous version: $CURRENT_VER"
  npm_install_openclaw "$CURRENT_VER" || warn "Failed to reinstall old version"

  safe_gateway_restart || true
  if wait_gateway_healthy 30; then
    warn "Rollback completed, gateway recovered"
  else
    err "Rollback failed, manual intervention required"
  fi
  exit 1
fi

if [[ -x "$PREFLIGHT_SCRIPT" ]]; then
  if bash "$PREFLIGHT_SCRIPT" --phase post; then
    log "Preflight post-phase passed"
  else
    warn "Preflight post-phase failed"
  fi
fi

openclaw status --json > "$BACKUP_DIR/status.after.json" 2>/dev/null || true
openclaw cron list --all --json > "$BACKUP_DIR/cron.list.after.json" 2>/dev/null || true

echo ""
log "═══════════════════════════════════════════════════"
log "Upgrade complete: $CURRENT_VER -> $NEW_VER"
log "Hook dir: $HOOK_DIR"
log "Backup: $BACKUP_DIR"
log "═══════════════════════════════════════════════════"
