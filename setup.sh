#!/bin/bash
set -uo pipefail
# Note: intentionally NO `set -e` — installer needs graceful degradation
# (e.g., qmd failing shouldn't prevent gateway startup)

# ============================================================================
# OpenClaw Starter Kit — setup.sh
# Interactive, idempotent installer. User does 2 things:
#   1. Run this script
#   2. Paste Chat Channel token (Discord or 飞书)
# MiniMax M2.5 is built-in as the default model — zero config needed.
# Optionally bring your own Anthropic key for Claude.
# Everything else is fully automatic.
# ============================================================================

STARTER_VERSION="1.3.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Defaults ---
WORKSPACE_DIR="${HOME}/clawd"
OPENCLAW_STATE="${HOME}/.openclaw"
NO_LAUNCHAGENTS=false
UNINSTALL=false
SKIP_DASHBOARD=false
NO_TAILSCALE=false
NO_CAFFEINATE=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Helpers ---
info()    { printf "${BLUE}     %s${NC}\n" "$*"; }
success() { printf "${GREEN}     %s ✓${NC}\n" "$*"; }
warn()    { printf "${YELLOW}     ⚠ %s${NC}\n" "$*"; }
error()   { printf "${RED}     ✗ %s${NC}\n" "$*"; }
fatal()   { error "$*"; exit 1; }
step()    { printf "\n${BOLD}${CYAN}[%s]${NC} ${BOLD}%s${NC}\n" "$1" "$2"; }
ask()     { printf "${BOLD}     %s${NC} " "$1"; }

progress_done() {
  printf "${GREEN}     %-30s ✓${NC}\n" "$1"
}

# --- Parse Flags ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace-dir)   WORKSPACE_DIR="$2"; shift 2 ;;
    --no-launchagents) NO_LAUNCHAGENTS=true; shift ;;
    --skip-dashboard)  SKIP_DASHBOARD=true; shift ;;
    --no-tailscale)    NO_TAILSCALE=true; shift ;;
    --no-caffeinate)   NO_CAFFEINATE=true; shift ;;
    --uninstall)       UNINSTALL=true; shift ;;
    --help|-h)
      echo "Usage: ./setup.sh [--workspace-dir ~/clawd] [--no-launchagents] [--skip-dashboard] [--no-tailscale] [--no-caffeinate] [--uninstall]"
      exit 0 ;;
    *) fatal "Unknown flag: $1" ;;
  esac
done

# ============================================================================
# UNINSTALL MODE
# ============================================================================
if $UNINSTALL; then
  step "🗑" "Uninstalling OpenClaw Starter Kit"

  # Unload LaunchAgents
  for plist in ai.openclaw.gateway ai.openclaw.guardian ai.openclaw.backup \
               ai.openclaw.log-rotate ai.openclaw.sessions-prune-cron \
               ai.openclaw.caffeinate \
               com.openclaw.infra-dashboard com.openclaw.mcp-bridge; do
    plist_path="${HOME}/Library/LaunchAgents/${plist}.plist"
    if [ -f "$plist_path" ]; then
      launchctl unload "$plist_path" 2>/dev/null || true
      rm -f "$plist_path"
      info "Removed $plist"
    fi
  done

  # Remove cron jobs
  if command -v openclaw &>/dev/null; then
    info "Removing cron jobs..."
    openclaw cron list --json 2>/dev/null | python3 -c "
import json, sys
try:
    jobs = json.load(sys.stdin)
    for j in jobs:
        print(j.get('name',''))
except: pass
" 2>/dev/null | while read -r job_name; do
      [ -n "$job_name" ] && openclaw cron remove "$job_name" 2>/dev/null && info "Removed cron: $job_name"
    done
  fi

  # Remove infra-dashboard
  DASHBOARD_DIR="${HOME}/projects/infra-dashboard"
  if [ -d "$DASHBOARD_DIR" ]; then
    ask "Delete infra-dashboard (${DASHBOARD_DIR})? [y/N]"
    read -r confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
      rm -rf "$DASHBOARD_DIR"
      info "infra-dashboard deleted"
    fi
  fi

  # Remove dashboard config
  DASHBOARD_CONF="${HOME}/.config/openclaw"
  if [ -d "$DASHBOARD_CONF" ]; then
    rm -rf "$DASHBOARD_CONF"
    info "Removed ${DASHBOARD_CONF}"
  fi

  # Remove qmd
  QMD_LIB="${HOME}/.local/lib/qmd"
  QMD_BIN="${HOME}/.local/bin/qmd"
  if [ -d "$QMD_LIB" ] || [ -f "$QMD_BIN" ]; then
    rm -rf "$QMD_LIB" "$QMD_BIN" 2>/dev/null
    info "Removed qmd"
  fi

  echo ""
  ask "Delete workspace ${WORKSPACE_DIR}? [y/N]"
  read -r confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    # Safety: refuse to delete critical paths
    case "$WORKSPACE_DIR" in
      /|"$HOME"|/usr|/var|/etc|/tmp)
        fatal "Safety check: refusing to delete ${WORKSPACE_DIR}" ;;
    esac
    rm -rf "$WORKSPACE_DIR"
    info "Workspace deleted"
  fi

  ask "Delete state dir ${OPENCLAW_STATE}? [y/N]"
  read -r confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    case "$OPENCLAW_STATE" in
      /|"$HOME"|/usr|/var|/etc|/tmp)
        fatal "Safety check: refusing to delete ${OPENCLAW_STATE}" ;;
    esac
    rm -rf "$OPENCLAW_STATE"
    info "State directory deleted"
  fi

  success "Uninstall complete"

  echo ""
  info "以下内容未自动删除（可能被其他项目使用）："
  printf "   ${DIM}npm 全局包:${NC}  npm uninstall -g openclaw @openai/codex @anthropic-ai/claude-code @google/gemini-cli @steipete/oracle mcporter clawhub playwright @upstash/context7-mcp\n"
  printf "   ${DIM}Homebrew 包:${NC} brew uninstall node@24 git tailscale\n"
  printf "   ${DIM}Bun 运行时:${NC}  rm -rf ~/.bun\n"
  printf "   ${DIM}uv 运行时:${NC}   rm -rf ~/.local/bin/uv ~/.local/bin/uvx\n"
  printf "   ${DIM}Shell PATH:${NC}  检查 ~/.zprofile 删除 OpenClaw 追加的 PATH 行\n"
  exit 0
fi

# ============================================================================
# HEADER
# ============================================================================
printf "\n${BOLD}🦞 OpenClaw Starter Kit v%s${NC}\n" "$STARTER_VERSION"
printf "${DIM}   Battle-tested AI partner setup for macOS${NC}\n\n"

# ============================================================================
# STEP 0: PRE-FLIGHT CHECKS
# ============================================================================
step "0/3" "环境检查 (Pre-flight)"

# --- Sudo pre-collection (needed for Homebrew, pmset, systemsetup) ---
info "Some steps require admin privileges (Homebrew, sleep settings, SSH)."
if sudo -v 2>/dev/null; then
  # Keep sudo alive in background (refresh every 50s, killed on script exit)
  ( while true; do sudo -n true 2>/dev/null; sleep 50; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT
else
  warn "Sudo not available — some steps may be skipped"
fi

# --- System proxy auto-detection (critical for China network) ---
if [[ -z "${https_proxy:-}" ]] && [[ -z "${HTTPS_PROXY:-}" ]]; then
  PROXY_HOST=$(scutil --proxy 2>/dev/null | awk '/HTTPSProxy/ {print $3}')
  PROXY_PORT=$(scutil --proxy 2>/dev/null | awk '/HTTPSPort/ {print $3}')
  if [[ -n "$PROXY_HOST" ]] && [[ "$PROXY_HOST" != "0" ]]; then
    export https_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    export HTTPS_PROXY="$https_proxy"
    export HTTP_PROXY="$http_proxy"
    info "Detected system proxy: ${PROXY_HOST}:${PROXY_PORT}"
  fi
fi

# --- Verify GitHub connectivity (with or without proxy) ---
if ! curl --connect-timeout 8 -sf https://github.com >/dev/null 2>&1; then
  warn "GitHub unreachable (even after proxy detection)"
  warn "如果在中国，建议配置 Homebrew 清华镜像:"
  warn "  export HOMEBREW_BREW_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
  warn "  export HOMEBREW_CORE_GIT_REMOTE=https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
  warn "Proceeding anyway — some downloads may fail"
fi

# --- macOS only ---
if [[ "$(uname)" != "Darwin" ]]; then
  fatal "This installer only supports macOS. Linux support coming in v2."
fi

# --- Architecture ---
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  BREW_PREFIX="/opt/homebrew"
elif [[ "$ARCH" == "x86_64" ]]; then
  BREW_PREFIX="/usr/local"
else
  fatal "Unsupported architecture: $ARCH"
fi
progress_done "macOS ($ARCH)"

# --- macOS Version ---
MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"
if [[ "$MACOS_MAJOR" -lt 13 ]]; then
  fatal "macOS Ventura (13.0) or later required. You have: $MACOS_VERSION"
fi
progress_done "macOS $MACOS_VERSION"

# --- Disk Space ---
DISK_FREE_GB=$(df -g / | awk 'NR==2 {print $4}')
if [[ "$DISK_FREE_GB" -lt 5 ]]; then
  fatal "Need ≥5GB free disk space. Available: ${DISK_FREE_GB}GB"
fi
progress_done "Disk: ${DISK_FREE_GB}GB free"

# --- RAM ---
RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
RAM_GB=$((RAM_BYTES / 1073741824))
if [[ "$RAM_GB" -lt 8 ]]; then
  fatal "Need ≥8GB RAM. Detected: ${RAM_GB}GB"
fi
progress_done "RAM: ${RAM_GB}GB"

# --- npm global writable ---
NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo "")"
if [[ -n "$NPM_PREFIX" ]] && [[ ! -w "${NPM_PREFIX}/lib/node_modules" ]]; then
  warn "npm global dir not writable: ${NPM_PREFIX}/lib/node_modules"
  warn "Fix: sudo chown -R \$(whoami) ${NPM_PREFIX}/lib/node_modules"
  warn "Or use nvm to manage Node.js"
fi

# --- Port Check (advisory, not blocking) ---
for port_info in "3456:openclaw-gateway" "3001:infra-dashboard" "9100:mcp-bridge"; do
  port="${port_info%%:*}"
  name="${port_info##*:}"
  pid=$(lsof -ti ":$port" 2>/dev/null || true)
  if [[ -n "$pid" ]]; then
    warn "Port $port ($name) in use by PID $pid"
    ask "Kill it? [y/N]"
    read -r kill_it
    if [[ "$kill_it" =~ ^[yY]$ ]]; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      success "Killed PID $pid"
    else
      warn "Proceeding anyway — $name may fail to start"
    fi
  fi
done

# ============================================================================
# STEP 1: INSTALL DEPENDENCIES (automatic)
# ============================================================================
step "1/3" "依赖安装 (Dependencies)"

# --- Xcode CLT ---
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (headless)..."
  # Headless install via softwareupdate (works over SSH, no GUI needed)
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  CLT_LABEL=$(softwareupdate -l 2>&1 | grep -m1 "Label:.*Command Line Tools" | sed 's/.*Label: //')
  if [[ -n "$CLT_LABEL" ]]; then
    softwareupdate -i "$CLT_LABEL" 2>/dev/null
  fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  # Fallback to interactive if headless didn't work
  if ! xcode-select -p &>/dev/null; then
    xcode-select --install 2>/dev/null || true
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi
  success "Xcode CLT"
else
  progress_done "Xcode CLT"
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Ensure brew is on PATH for this session
  eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
  success "Homebrew"
else
  progress_done "Homebrew"
fi

# --- Node.js ---
NODE24_BIN="${BREW_PREFIX}/opt/node@24/bin"
if ! command -v node &>/dev/null; then
  info "Installing Node.js..."
  brew install node@24
  export PATH="${NODE24_BIN}:$PATH"
  hash -r
  if ! command -v node &>/dev/null; then
    fatal "Node.js installed but not on PATH. Try: export PATH=\"${NODE24_BIN}:\$PATH\""
  fi
  success "Node.js $(node --version)"
else
  NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
  if [[ "$NODE_VERSION" -lt 20 ]]; then
    warn "Node.js v${NODE_VERSION} detected, v20+ recommended"
    info "Installing Node.js 24..."
    brew install node@24
    export PATH="${NODE24_BIN}:$PATH"
    hash -r
    success "Node.js $(node --version)"
  else
    progress_done "Node.js $(node --version)"
  fi
fi

# --- Git ---
if ! command -v git &>/dev/null; then
  info "Installing Git..."
  brew install git
  success "Git"
else
  progress_done "Git $(git --version | awk '{print $3}')"
fi

# --- uv (Python package manager) ---
if ! command -v uv &>/dev/null; then
  info "Installing uv (Python package manager)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null
  export PATH="$HOME/.local/bin:$PATH"
  success "uv"
else
  progress_done "uv"
fi

# --- Homebrew packages from Brewfile ---
if [ -f "${SCRIPT_DIR}/workspace/scripts/Brewfile" ]; then
  info "Installing Homebrew packages..."
  brew bundle --file="${SCRIPT_DIR}/workspace/scripts/Brewfile" --quiet --no-lock 2>/dev/null || true
  progress_done "Homebrew packages"
fi

# --- OpenClaw ---
if ! command -v openclaw &>/dev/null; then
  info "Installing OpenClaw..."
  npm i -g openclaw@latest 2>/dev/null
  success "OpenClaw $(openclaw --version 2>/dev/null | head -1 || echo 'installed')"
else
  progress_done "OpenClaw $(openclaw --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
fi

# --- npm globals (coding agents + tools) ---
# Ensure npm global bin is on PATH (covers keg-only node@24)
NPM_BIN="$(npm config get prefix 2>/dev/null)/bin"
if [[ -d "$NPM_BIN" ]] && [[ ":$PATH:" != *":$NPM_BIN:"* ]]; then
  export PATH="$NPM_BIN:$PATH"
fi

NPM_GLOBALS=(
  "@anthropic-ai/claude-code"
  "@openai/codex"
  "@google/gemini-cli"
  "@steipete/oracle"
  "mcporter"
  "clawhub"
  "playwright"
)

for pkg in "${NPM_GLOBALS[@]}"; do
  short_name="${pkg##*/}"
  if npm ls -g "$pkg" &>/dev/null 2>&1; then
    progress_done "$short_name"
  else
    info "Installing $short_name..."
    npm i -g "$pkg" 2>/dev/null || warn "Failed to install $short_name (non-critical)"
  fi
done

# --- Playwright Chromium ---
if ! npx playwright install --dry-run chromium &>/dev/null 2>&1; then
  info "Installing Playwright Chromium..."
  npx playwright install chromium 2>/dev/null || warn "Playwright Chromium install failed (non-critical)"
  progress_done "Playwright Chromium"
else
  progress_done "Playwright Chromium"
fi

# --- MCP servers ---
if ! npm ls -g @upstash/context7-mcp &>/dev/null 2>&1; then
  info "Installing context7 MCP server..."
  npm i -g @upstash/context7-mcp 2>/dev/null || true
fi
progress_done "MCP servers"

# --- qmd (semantic memory search — installed from source, needs bun) ---
QMD_DIR="${HOME}/.local/lib/qmd"
if ! command -v qmd &>/dev/null; then
  # Install bun if missing
  if ! command -v bun &>/dev/null; then
    info "Installing bun (for qmd)..."
    curl -fsSL https://bun.sh/install | bash 2>/dev/null || true
    export PATH="$HOME/.bun/bin:$PATH"
  fi

  if command -v bun &>/dev/null; then
    info "Installing qmd (semantic search)..."
    if [ ! -d "$QMD_DIR" ]; then
      git clone --depth 1 https://github.com/tobi/qmd.git "$QMD_DIR" 2>/dev/null || \
        (mkdir -p "$QMD_DIR" && curl -sL https://api.github.com/repos/tobi/qmd/tarball/main | \
          tar xz --strip-components=1 -C "$QMD_DIR" 2>/dev/null) || true
    fi
    if [ -d "$QMD_DIR" ]; then
      cd "$QMD_DIR" || true
      bun install 2>/dev/null || true
      # Create global bin wrapper
      QMD_BIN="${HOME}/.local/bin/qmd"
      mkdir -p "${HOME}/.local/bin"
      if [ ! -f "$QMD_BIN" ]; then
        cat > "$QMD_BIN" << 'QBIN'
#!/bin/bash
exec bun run __QMD_DIR__/src/qmd.ts "$@"
QBIN
        sed -i '' "s|__QMD_DIR__|${QMD_DIR}|g" "$QMD_BIN"
        chmod +x "$QMD_BIN"
      fi
      cd "$SCRIPT_DIR" || true
      success "qmd"
    else
      warn "qmd install failed (non-critical)"
    fi
  else
    warn "bun not available — qmd skipped (non-critical)"
  fi
else
  progress_done "qmd"
fi

# --- Tailscale (remote access) ---
if ! $NO_TAILSCALE; then
  if ! command -v tailscale &>/dev/null; then
    info "Installing Tailscale (remote access)..."
    brew install tailscale 2>/dev/null || warn "Tailscale install failed (non-critical)"
  fi
  if command -v tailscale &>/dev/null; then
    # Start Tailscale service
    brew services start tailscale 2>/dev/null || true
    # Check if already logged in
    if ! perl -e 'alarm 5; exec @ARGV' tailscale status &>/dev/null 2>&1; then
      echo ""
      info "下一步将打开浏览器进行 Tailscale 授权"
      info "完成浏览器中的登录后，返回此窗口继续..."
      echo ""
      tailscale login 2>/dev/null || warn "Tailscale login failed — run 'tailscale login' later"
    fi
    # Enable Tailscale SSH
    tailscale set --ssh 2>/dev/null || true
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "")
    if [[ -n "$TS_IP" ]]; then
      progress_done "Tailscale ($TS_IP)"
    else
      progress_done "Tailscale (pending login)"
    fi
  fi
else
  info "Tailscale skipped (--no-tailscale)"
fi

# --- Enable macOS SSH (Remote Login) ---
if ! sudo systemsetup -getremotelogin 2>/dev/null | grep -qi "on"; then
  info "Enabling macOS Remote Login (SSH)..."
  sudo systemsetup -setremotelogin on 2>/dev/null || warn "Could not enable SSH — run: sudo systemsetup -setremotelogin on"
  progress_done "SSH (Remote Login)"
else
  progress_done "SSH (Remote Login)"
fi

# --- Persist PATH in shell profile (so new terminals find node/openclaw/bun) ---
SHELL_PROFILE="${HOME}/.zprofile"
PATH_MARKER="# OpenClaw — Node.js & tools PATH"
if ! grep -q "$PATH_MARKER" "$SHELL_PROFILE" 2>/dev/null; then
  cat >> "$SHELL_PROFILE" << PATHEOF

${PATH_MARKER} (added by setup.sh)
export PATH="${NODE24_BIN}:\$HOME/.bun/bin:\$HOME/.local/bin:\$PATH"
eval "\$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
PATHEOF
  progress_done "Shell PATH → ~/.zprofile"
else
  progress_done "Shell PATH (already configured)"
fi

# ============================================================================
# STEP 2: WORKSPACE DEPLOYMENT
# ============================================================================
step "2/3" "配置 (Configuration)"

# Create workspace directory
mkdir -p "$WORKSPACE_DIR"
mkdir -p "${OPENCLAW_STATE}/logs"
mkdir -p "${OPENCLAW_STATE}/scripts"
mkdir -p "${HOME}/.config/openclaw"
mkdir -p "${HOME}/projects"

# --- Zone-based file deployment ---
# System core zone: always overwrite (with backup)
SYSTEM_DIRS=("scripts" "prompts" "eval" "skills" "mcp-bridge")
DATE_STAMP=$(date +%Y%m%d)

for dir in "${SYSTEM_DIRS[@]}"; do
  src="${SCRIPT_DIR}/workspace/${dir}"
  dst="${WORKSPACE_DIR}/${dir}"
  if [ -d "$src" ]; then
    if [ -d "$dst" ]; then
      # Backup existing before overwrite
      backup="${dst}.bak.${DATE_STAMP}"
      if [ ! -d "$backup" ]; then
        cp -a "$dst" "$backup"
      fi
    fi
    # Sync (overwrite system files, but don't delete user additions)
    rsync -a "$src/" "$dst/"
  fi
done

# User config zone: only copy if not exists
USER_CONFIGS=(
  "AGENTS.md"
  "HEARTBEAT.md"
  "BOOTSTRAP.md"
  "MEMORY.md"
)

for f in "${USER_CONFIGS[@]}"; do
  src="${SCRIPT_DIR}/workspace/${f}"
  dst="${WORKSPACE_DIR}/${f}"
  if [ -f "$src" ] && [ ! -f "$dst" ]; then
    cp "$src" "$dst"
  fi
done

# .example files → remove suffix (only if target missing)
for example in "${SCRIPT_DIR}"/workspace/*.example; do
  [ -f "$example" ] || continue
  basename="$(basename "$example" .example)"
  dst="${WORKSPACE_DIR}/${basename}"
  if [ ! -f "$dst" ]; then
    cp "$example" "$dst"
    info "Created ${basename} from template"
  fi
done

# Memory directory structure
mkdir -p "${WORKSPACE_DIR}/memory/archive"
mkdir -p "${WORKSPACE_DIR}/memory/journal"

# Tasks directory
mkdir -p "${WORKSPACE_DIR}/tasks"

progress_done "Workspace → ${WORKSPACE_DIR}"

# --- qmd-safe.sh wrapper ---
NODE_BIN_QMD="$(dirname "$(command -v node 2>/dev/null || echo /usr/local/bin/node)")/qmd"
QMD_PATH="$(command -v qmd 2>/dev/null || echo "$NODE_BIN_QMD")"
cat > "${OPENCLAW_STATE}/scripts/qmd-safe.sh" << QMDEOF
#!/bin/bash
set -euo pipefail
# qmd wrapper — safe mode for LaunchAgent
exec "${QMD_PATH}" "\$@"
QMDEOF
chmod +x "${OPENCLAW_STATE}/scripts/qmd-safe.sh"
progress_done "qmd wrapper"

# --- Dotfiles (non-destructive: only add if not present) ---
DOTFILES_DIR="${SCRIPT_DIR}/scripts/dotfiles"
if [ -d "$DOTFILES_DIR" ]; then
  # .editorconfig → workspace root
  if [ -f "${DOTFILES_DIR}/.editorconfig" ] && [ ! -f "${WORKSPACE_DIR}/.editorconfig" ]; then
    cp "${DOTFILES_DIR}/.editorconfig" "${WORKSPACE_DIR}/.editorconfig"
  fi

  # gitconfig aliases (merge into existing, don't overwrite)
  if [ -f "${DOTFILES_DIR}/gitconfig.ini" ]; then
    if ! git config --global alias.lg &>/dev/null; then
      git config --global include.path "${DOTFILES_DIR}/gitconfig.ini" 2>/dev/null || true
      info "Git aliases added (via include)"
    fi
  fi

  # nanorc
  if [ -f "${DOTFILES_DIR}/nanorc" ] && [ ! -f "${HOME}/.nanorc" ]; then
    cp "${DOTFILES_DIR}/nanorc" "${HOME}/.nanorc"
  fi

  progress_done "Dotfiles"
fi

# --- ClawHub community skills (recommended set) ---
if command -v clawhub &>/dev/null; then
  CLAWHUB_RECOMMENDED=(
    "find-skills"
    "android-adb"
    "remotion-video-toolkit"
  )

  INSTALLED_ANY=false
  for skill in "${CLAWHUB_RECOMMENDED[@]}"; do
    if [ ! -d "${WORKSPACE_DIR}/skills/${skill}" ]; then
      info "Installing ClawHub skill: ${skill}..."
      (cd "$WORKSPACE_DIR" && clawhub install "$skill" --no-input 2>/dev/null) || true
      INSTALLED_ANY=true
    fi
  done
  if $INSTALLED_ANY; then
    success "ClawHub community skills"
  else
    progress_done "ClawHub skills (already installed)"
  fi
fi

# ============================================================================
# INTERACTIVE CONFIG: Anthropic + Chat Channel
# ============================================================================

# Detect if already configured
EXISTING_CONFIG="${OPENCLAW_STATE}/openclaw.json"
ANTHROPIC_MODE=""
ANTHROPIC_KEY=""
CHANNEL_TYPE=""
DISCORD_TOKEN=""
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""
DISCORD_GUILD=""
DISCORD_USER=""

if [ -f "$EXISTING_CONFIG" ]; then
  info "Existing configuration found at ${EXISTING_CONFIG}"
  ask "Reconfigure? [y/N]"
  read -r reconfig
  if [[ ! "$reconfig" =~ ^[yY]$ ]]; then
    info "Keeping existing configuration"
    # Jump past interactive config
    SKIP_CONFIG=true
  else
    SKIP_CONFIG=false
  fi
else
  SKIP_CONFIG=false
fi

if [[ "${SKIP_CONFIG:-false}" != "true" ]]; then

  # ========================================================================
  # Interactive config loop — user can review and redo before proceeding
  # ========================================================================
  CONFIG_CONFIRMED=false
  while ! $CONFIG_CONFIRMED; do

  # --- LLM Model Selection ---
  echo ""
  printf "${BOLD}     LLM 模型 — 选择方式:${NC}\n"
  printf "       ${CYAN}1.${NC} MiniMax M2.5 ${DIM}(价格便宜，推荐)${NC}\n"
  printf "       ${CYAN}2.${NC} Anthropic API Key ${DIM}(按量付费)${NC}\n"
  printf "       ${CYAN}3.${NC} Anthropic setup-token ${DIM}(用 Claude Pro/Max 订阅额度)${NC}\n"
  printf "       ${DIM}       MiniMax 注册: https://platform.minimax.io${NC}\n"
  printf "       ${DIM}       Anthropic: https://docs.openclaw.ai/providers/anthropic${NC}\n"
  echo ""
  ask "> "
  read -r auth_choice

  MINIMAX_KEY=""
  ANTHROPIC_MODE=""
  ANTHROPIC_KEY=""
  case "$auth_choice" in
    1)
      ANTHROPIC_MODE="none"
      ANTHROPIC_KEY=""
      echo ""
      info "在 https://platform.minimax.io 注册后，进入 API Keys 页面创建 key"
      ask "MiniMax API Key (sk-...): "
      read -rs MINIMAX_KEY
      echo ""
      if [[ -z "$MINIMAX_KEY" ]]; then
        fatal "MiniMax API Key 不能为空。请先去 platform.minimax.io 注册获取"
      fi
      success "使用 MiniMax M2.5"
      ;;
    2)
      ANTHROPIC_MODE="api-key"
      ask "Anthropic API Key (sk-ant-...): "
      read -rs ANTHROPIC_KEY
      echo ""
      if [[ ! "$ANTHROPIC_KEY" =~ ^sk-ant- ]]; then
        warn "Key doesn't start with sk-ant-. Are you sure it's correct?"
      fi
      echo ""
      info "MiniMax M2.5 作为 fallback 模型（可选，回车跳过）"
      ask "MiniMax API Key (sk-..., 可选): "
      read -rs MINIMAX_KEY
      echo ""
      success "Anthropic API Key${MINIMAX_KEY:+ + MiniMax fallback}"
      ;;
    3)
      ANTHROPIC_MODE="setup-token"
      echo ""
      info "请在另一个终端运行:"
      printf "       ${BOLD}claude setup-token${NC}\n"
      info "然后粘贴获得的 token"
      echo ""
      ask "Setup Token: "
      read -rs ANTHROPIC_KEY
      echo ""
      echo ""
      info "MiniMax M2.5 作为 fallback 模型（可选，回车跳过）"
      ask "MiniMax API Key (sk-..., 可选): "
      read -rs MINIMAX_KEY
      echo ""
      success "Anthropic Setup Token${MINIMAX_KEY:+ + MiniMax fallback}"
      ;;
    *)
      ANTHROPIC_MODE="none"
      ANTHROPIC_KEY=""
      echo ""
      info "在 https://platform.minimax.io 注册后，进入 API Keys 页面创建 key"
      ask "MiniMax API Key (sk-...): "
      read -rs MINIMAX_KEY
      echo ""
      if [[ -z "$MINIMAX_KEY" ]]; then
        fatal "MiniMax API Key 不能为空。请先去 platform.minimax.io 注册获取"
      fi
      success "使用 MiniMax M2.5"
      ;;
  esac

  # --- Chat Channel Selection (optional) ---
  echo ""
  CHANNEL_TYPE=""
  DISCORD_TOKEN=""
  DISCORD_GUILD=""
  DISCORD_USER=""
  FEISHU_APP_ID=""
  FEISHU_APP_SECRET=""
  printf "${BOLD}     Chat Channel — 选择一个:${NC}\n"
  printf "       ${CYAN}1.${NC} Discord\n"
  printf "       ${CYAN}2.${NC} 飞书 (Feishu)\n"
  printf "       ${CYAN}3.${NC} 跳过 ${DIM}(稍后通过 Dashboard 或 openclaw channels add 配置)${NC}\n"
  echo ""
  ask "> [3] "
  read -r channel_choice

  case "$channel_choice" in
    1)
      CHANNEL_TYPE="discord"
      ask "Discord Bot Token: "
      read -rs DISCORD_TOKEN
      echo ""
      echo ""
      ask "Discord Guild (Server) ID: "
      read -r DISCORD_GUILD
      ask "Your Discord User ID: "
      read -r DISCORD_USER
      success "Discord"
      ;;
    2)
      CHANNEL_TYPE="feishu"
      ask "飞书 App ID: "
      read -r FEISHU_APP_ID
      ask "飞书 App Secret: "
      read -rs FEISHU_APP_SECRET
      echo ""
      success "飞书 (Feishu)"
      ;;
    *)
      CHANNEL_TYPE=""
      info "跳过频道配置（安装后运行 openclaw channels add）"
      ;;
  esac

  # --- Review & Confirm ---
  echo ""
  printf "${BOLD}     配置确认:${NC}\n"
  if [[ "$ANTHROPIC_MODE" == "none" ]] || [[ -z "$ANTHROPIC_KEY" ]]; then
    printf "       模型:  MiniMax M2.5\n"
  elif [[ "$ANTHROPIC_MODE" == "api-key" ]]; then
    printf "       模型:  Anthropic API Key${MINIMAX_KEY:+ + MiniMax fallback}\n"
  else
    printf "       模型:  Anthropic OAuth${MINIMAX_KEY:+ + MiniMax fallback}\n"
  fi
  if [[ "$CHANNEL_TYPE" == "discord" ]]; then
    printf "       频道:  Discord (Guild: ${DISCORD_GUILD:-未设置})\n"
  elif [[ "$CHANNEL_TYPE" == "feishu" ]]; then
    printf "       频道:  飞书 (App: ${FEISHU_APP_ID:-未设置})\n"
  else
    printf "       频道:  ${DIM}未配置（稍后添加）${NC}\n"
  fi
  echo ""
  ask "确认以上配置？[Y/n] (n=重新配置) "
  read -r confirm_config
  if [[ "$confirm_config" =~ ^[nN]$ ]]; then
    info "重新开始配置..."
    continue
  fi
  CONFIG_CONFIRMED=true

  done  # end config loop

  # ========================================================================
  # VALIDATE CHANNEL CREDENTIALS
  # ========================================================================
  
  if [[ "$CHANNEL_TYPE" == "feishu" ]] && [[ -n "$FEISHU_APP_ID" ]]; then
    info "Validating Feishu credentials..."
    FEISHU_RESP=$(curl -sf -m 10 -X POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal \
      -H "Content-Type: application/json" \
      -d "{\"app_id\":\"${FEISHU_APP_ID}\",\"app_secret\":\"${FEISHU_APP_SECRET}\"}" 2>/dev/null || echo "")
    if echo "$FEISHU_RESP" | grep -q '"code":0\|"code": 0'; then
      success "Feishu credentials valid"
      
    else
      warn "Feishu credentials invalid — channel will be skipped (Gateway still starts, configure later in Dashboard)"
      CHANNEL_TYPE=""
    fi
  elif [[ "$CHANNEL_TYPE" == "discord" ]] && [[ -n "$DISCORD_TOKEN" ]]; then
    info "Validating Discord token..."
    DISCORD_RESP=$(curl -sf -m 10 -H "Authorization: Bot ${DISCORD_TOKEN}" https://discord.com/api/v10/users/@me 2>/dev/null || echo "")
    if echo "$DISCORD_RESP" | grep -q '"id"'; then
      DISCORD_BOT_NAME=$(echo "$DISCORD_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('username',''))" 2>/dev/null || echo "")
      success "Discord Bot verified: ${DISCORD_BOT_NAME}"
      
    else
      warn "Discord token invalid — channel will be skipped (Gateway still starts, configure later)"
      CHANNEL_TYPE=""
    fi
  fi

  # ========================================================================
  # GENERATE openclaw.json
  # ========================================================================
  info "Generating configuration..."

  # Determine primary model + fallback based on auth choice
  if [[ "$ANTHROPIC_MODE" != "none" ]] && [[ -n "$ANTHROPIC_KEY" ]]; then
    PRIMARY_MODEL="anthropic/claude-sonnet-4-6"
    if [[ -n "${MINIMAX_KEY:-}" ]]; then
      FALLBACK_LINE="fallbacks: ['minimax/MiniMax-M2.5'],"
    else
      FALLBACK_LINE=""
    fi
  else
    PRIMARY_MODEL="minimax/MiniMax-M2.5"
    FALLBACK_LINE=""
  fi

  # Generate gateway auth token (reuse existing if reconfiguring)
  EXISTING_GW_TOKEN=""
  if [ -f "$EXISTING_CONFIG" ]; then
    EXISTING_GW_TOKEN=$(python3 -c "import json; c=json.load(open('$EXISTING_CONFIG')); print(c.get('gateway',{}).get('auth',{}).get('token','') or c.get('gateway',{}).get('token',''))" 2>/dev/null || true)
  fi
  GATEWAY_TOKEN="${EXISTING_GW_TOKEN:-$(openssl rand -hex 24)}"

  # Generate openclaw.json using python3 (safe from shell injection)
  _OC_PRIMARY_MODEL="$PRIMARY_MODEL" \
  _OC_FALLBACK="${FALLBACK_LINE:+minimax/MiniMax-M2.5}" \
  _OC_MINIMAX_KEY="${MINIMAX_KEY:-}" \
  _OC_ANTHROPIC_KEY="${ANTHROPIC_KEY:-}" \
  _OC_ANTHROPIC_MODE="$ANTHROPIC_MODE" \
  _OC_DISCORD_TOKEN="${DISCORD_TOKEN:-}" \
  _OC_DISCORD_GUILD="${DISCORD_GUILD:-}" \
  _OC_DISCORD_USER="${DISCORD_USER:-}" \
  _OC_FEISHU_APP_ID="${FEISHU_APP_ID:-}" \
  _OC_FEISHU_APP_SECRET="${FEISHU_APP_SECRET:-}" \
  _OC_CHANNEL_TYPE="${CHANNEL_TYPE:-}" \
  _OC_STATE_DIR="$OPENCLAW_STATE" \
  _OC_GW_TOKEN="$GATEWAY_TOKEN" \
  python3 -c '
import json, os

E = os.environ.get

# env vars
env_vars = {}
if E("_OC_MINIMAX_KEY"):
    env_vars["MINIMAX_API_KEY"] = E("_OC_MINIMAX_KEY")
if E("_OC_ANTHROPIC_MODE") == "api-key" and E("_OC_ANTHROPIC_KEY"):
    env_vars["ANTHROPIC_API_KEY"] = E("_OC_ANTHROPIC_KEY")
if E("_OC_DISCORD_TOKEN"):
    env_vars["DISCORD_BOT_TOKEN"] = E("_OC_DISCORD_TOKEN")

# model
model_block = {"primary": E("_OC_PRIMARY_MODEL")}
if E("_OC_FALLBACK"):
    model_block["fallbacks"] = [E("_OC_FALLBACK")]

# minimax provider (only if key provided)
providers = {}
if E("_OC_MINIMAX_KEY"):
    providers["minimax"] = {
        "baseUrl": "https://api.minimax.io/anthropic",
        "apiKey": "${MINIMAX_API_KEY}",
        "api": "anthropic-messages",
        "models": [
            {"id": "MiniMax-M2.5", "name": "MiniMax M2.5", "reasoning": True, "input": ["text"],
             "cost": {"input": 0.3, "output": 1.2, "cacheRead": 0.03, "cacheWrite": 0.12},
             "contextWindow": 200000, "maxTokens": 8192},
            {"id": "MiniMax-M2.5-highspeed", "name": "MiniMax M2.5 Highspeed", "reasoning": True, "input": ["text"],
             "cost": {"input": 0.3, "output": 1.2, "cacheRead": 0.03, "cacheWrite": 0.12},
             "contextWindow": 200000, "maxTokens": 8192},
        ],
    }

# channels
channels = {}
ch = E("_OC_CHANNEL_TYPE")
if ch == "discord" and E("_OC_DISCORD_TOKEN"):
    disc = {}
    allow = {}
    if E("_OC_DISCORD_GUILD"):
        allow["guild"] = E("_OC_DISCORD_GUILD")
    if E("_OC_DISCORD_USER"):
        allow["users"] = [E("_OC_DISCORD_USER")]
    if allow:
        disc["allowlist"] = [allow]
    channels["discord"] = disc
elif ch == "feishu" and E("_OC_FEISHU_APP_ID"):
    channels["feishu"] = {
        "appId": E("_OC_FEISHU_APP_ID"),
        "appSecret": E("_OC_FEISHU_APP_SECRET", ""),
    }

state = E("_OC_STATE_DIR")
config = {
    "env": {"vars": env_vars},
    "gateway": {"port": 3456, "mode": "local", "auth": {"mode": "token", "token": E("_OC_GW_TOKEN")}},
    "agents": {"defaults": {"model": model_block}},
    "models": {"mode": "merge", "providers": providers},
    "memory": {
        "backend": "qmd", "citations": "auto",
        "qmd": {
            "command": f"{state}/scripts/qmd-safe.sh",
            "searchMode": "search", "includeDefaultMemory": True,
            "update": {"interval": "5m", "debounceMs": 15000, "onBoot": True},
            "limits": {"maxResults": 10, "timeoutMs": 60000},
        },
    },
    "channels": channels,
    "acp": {
        "enabled": True, "dispatch": {"enabled": True}, "backend": "acpx",
        "defaultAgent": "codex",
        "allowedAgents": ["pi", "claude", "codex", "opencode", "gemini"],
        "maxConcurrentSessions": 4,
    },
    "tools": {"profile": "full"},
    "skills": {"load": {"watch": False}, "install": {"nodeManager": "npm"}},
    "cron": {"maxConcurrentRuns": 3},
    "logging": {"level": "info", "file": f"{state}/logs/gateway-audit.log", "consoleLevel": "warn"},
    "session": {"dmScope": "per-channel-peer"},
    "browser": {"enabled": True, "headless": True},
}
print(json.dumps(config, indent=2))
' | (umask 077; cat > "$EXISTING_CONFIG")

  success "Generated ${EXISTING_CONFIG}"

  # Handle setup-token auth
  if [[ "$ANTHROPIC_MODE" == "setup-token" ]] && [[ -n "$ANTHROPIC_KEY" ]]; then
    info "Configuring Anthropic setup-token..."
    # Store via openclaw CLI if available
    if command -v openclaw &>/dev/null; then
      echo "$ANTHROPIC_KEY" | openclaw models auth setup-token --provider anthropic 2>/dev/null || \
        warn "Could not configure setup-token via CLI. You may need to run: openclaw models auth setup-token --provider anthropic"
    fi
  fi

fi  # end SKIP_CONFIG

# ============================================================================
# STEP 3: SERVICES & STARTUP
# ============================================================================
step "3/3" "启动 (Launch)"

# --- infra-dashboard (pre-built standalone from GitHub Release) ---
if ! $SKIP_DASHBOARD; then
  DASHBOARD_DIR="${HOME}/projects/infra-dashboard"
  DASHBOARD_RELEASE_URL="https://github.com/MuduiClaw/openclaw-starter/releases/latest/download/infra-dashboard-standalone.tar.gz"

  if [ ! -d "$DASHBOARD_DIR" ] || [ ! -f "$DASHBOARD_DIR/server.js" ]; then
    info "Installing infra-dashboard (standalone)..."
    mkdir -p "$DASHBOARD_DIR"

    if curl --connect-timeout 10 --max-time 120 -fsSL "$DASHBOARD_RELEASE_URL" | tar xz -C "$DASHBOARD_DIR" 2>/dev/null; then
      success "infra-dashboard downloaded"
    else
      rm -rf "$DASHBOARD_DIR"
      warn "Failed to download infra-dashboard (check network)"
      warn "Retry later: curl -fsSL $DASHBOARD_RELEASE_URL | tar xz -C ~/projects/infra-dashboard"
    fi
  fi

  if [ -d "$DASHBOARD_DIR" ] && [ -f "$DASHBOARD_DIR/server.js" ]; then
    # Generate dashboard token if missing
    DASHBOARD_ENV="${HOME}/.config/openclaw/dashboard.env"
    if [ ! -f "$DASHBOARD_ENV" ]; then
      DASH_TOKEN="0000"
      (umask 077; echo "export DASHBOARD_TOKEN=${DASH_TOKEN}" > "$DASHBOARD_ENV")
      success "Dashboard token generated"
    fi

    # Write dashboard config (controls which tools/modules are displayed)
    DASHBOARD_CONFIG="${HOME}/.config/openclaw/dashboard.config.json"
    if [ ! -f "$DASHBOARD_CONFIG" ]; then
      cat > "$DASHBOARD_CONFIG" << 'DASHCFG'
{
  "tools": [
    { "name": "openclaw", "command": "openclaw", "versionArgs": ["--version"] },
    { "name": "claude", "command": "claude", "versionArgs": ["--version"] },
    { "name": "codex", "command": "codex", "versionArgs": ["--version"] },
    { "name": "gemini", "command": "gemini", "versionArgs": ["--version"] },
    { "name": "qmd", "command": "qmd" },
    { "name": "mcporter", "command": "mcporter", "versionArgs": ["--version"] },
    { "name": "clawhub", "command": "clawhub", "versionArgs": ["--version"] },
    { "name": "oracle", "command": "oracle", "versionArgs": ["--version"] },
    { "name": "uv", "command": "uv", "versionArgs": ["--version"] },
    { "name": "bun", "command": "bun", "versionArgs": ["--version"] }
  ],
  "modules": ["运行态", "基建", "知识", "配置"],
  "projects": [
    { "key": "openclaw-workspace", "path": "~/clawd", "repo": "" },
    { "key": "infra-dashboard", "path": "~/projects/infra-dashboard", "repo": "MuduiClaw/infra-dashboard" }
  ],
  "channels": {}
}
DASHCFG
      success "Dashboard config written"
    fi

    # Prepare start script
    NODE_BIN_DIR="$(dirname "$(command -v node)")"
    START_SCRIPT="${OPENCLAW_STATE}/scripts/start-infra-dashboard.sh"
    sed -e "s|__HOME__|${HOME}|g" \
        -e "s|__NODE_BIN__|${NODE_BIN_DIR}|g" \
        -e "s|__GATEWAY_PORT__|3456|g" \
        "${SCRIPT_DIR}/services/scripts/start-infra-dashboard.sh" > "$START_SCRIPT"
    chmod +x "$START_SCRIPT"

    progress_done "infra-dashboard"
  else
    warn "infra-dashboard not found — skipping (download later from GitHub Release)"
  fi

# --- MCP Bridge start script ---
if [ -f "${SCRIPT_DIR}/services/scripts/start-mcp-bridge.sh" ]; then
  NODE_BIN_DIR="$(dirname "$(command -v node)")"
  MCP_START="${OPENCLAW_STATE}/scripts/start-mcp-bridge.sh"
  sed -e "s|__HOME__|${HOME}|g" \
      -e "s|__NODE_BIN__|${NODE_BIN_DIR}|g" \
      "${SCRIPT_DIR}/services/scripts/start-mcp-bridge.sh" > "$MCP_START"
  chmod +x "$MCP_START"
  progress_done "MCP bridge start script"
fi
else
  info "Dashboard skipped (--skip-dashboard)"
fi

# --- LaunchAgents ---
if ! $NO_LAUNCHAGENTS; then
  LA_DIR="${HOME}/Library/LaunchAgents"
  mkdir -p "$LA_DIR"
  NODE_BIN_DIR="$(dirname "$(command -v node)")"
  OPENCLAW_BIN="$(command -v openclaw 2>/dev/null || echo "${NODE_BIN_DIR}/openclaw")"
  OPENCLAW_DIST="$(node -e "console.log(require.resolve('openclaw/dist/index.js'))" 2>/dev/null || echo "")"

  for template in "${SCRIPT_DIR}"/services/launchagents/*.plist.template; do
    [ -f "$template" ] || continue
    plist_name="$(basename "$template" .template)"
    plist_dest="${LA_DIR}/${plist_name}"

    # Unload existing first (prevent conflicts)
    if [ -f "$plist_dest" ]; then
      launchctl unload "$plist_dest" 2>/dev/null || true
    fi

    # Template substitution
    sed -e "s|__HOME__|${HOME}|g" \
        -e "s|__USER__|$(whoami)|g" \
        -e "s|__NODE_BIN__|${NODE_BIN_DIR}|g" \
        -e "s|__OPENCLAW_BIN__|${OPENCLAW_BIN}|g" \
        -e "s|__OPENCLAW_DIST__|${OPENCLAW_DIST}|g" \
        -e "s|__BREW_PREFIX__|${BREW_PREFIX}|g" \
        "$template" > "$plist_dest"

    launchctl load "$plist_dest" 2>/dev/null || warn "Failed to load ${plist_name}"
  done
  progress_done "LaunchAgents"
else
  info "LaunchAgents skipped (--no-launchagents)"
fi

# --- Memory System (qmd) ---
if command -v qmd &>/dev/null; then
  QMD_SAFE="${OPENCLAW_STATE}/scripts/qmd-safe.sh"

  # Initialize core collections
  if ! "$QMD_SAFE" collection list 2>/dev/null | grep -q "memory-root-main"; then
    "$QMD_SAFE" collection add "$WORKSPACE_DIR" --name memory-root-main --mask "MEMORY.md" 2>/dev/null || true
  fi
  if ! "$QMD_SAFE" collection list 2>/dev/null | grep -q "memory-dir-main"; then
    "$QMD_SAFE" collection add "$WORKSPACE_DIR" --name memory-dir-main --mask "memory/**/*.md" 2>/dev/null || true
  fi

  # Initial embed (background, don't block)
  "$QMD_SAFE" embed 2>/dev/null &
  QMD_PID=$!

  progress_done "Memory system (qmd)"
else
  warn "qmd not found — memory system unavailable"
fi

# --- MCP Config (Gemini settings.json) ---
GEMINI_DIR="${HOME}/.gemini"
if [ ! -f "${GEMINI_DIR}/settings.json" ]; then
  mkdir -p "$GEMINI_DIR"
  cp "${SCRIPT_DIR}/config/gemini-settings.template.json" "${GEMINI_DIR}/settings.json"
  progress_done "Gemini MCP config"
else
  progress_done "Gemini MCP config (exists)"
fi

# --- Start Gateway ---
if command -v openclaw &>/dev/null; then
  # Fix permissions
  chmod 700 "${OPENCLAW_STATE}" 2>/dev/null || true
  chmod 600 "${EXISTING_CONFIG}" 2>/dev/null || true
  mkdir -p "${OPENCLAW_STATE}/agents/main/sessions"

  # Validate config first
  if openclaw config validate 2>/dev/null; then
    # Install gateway service (creates LaunchAgent + auto-generates token if missing)
    openclaw gateway install 2>/dev/null || warn "Gateway install failed"

    # Patch gateway plist with correct PATH (openclaw gateway install inherits shell PATH
    # which may miss keg-only node paths; we always ensure the correct PATH is set)
    GW_PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.gateway.plist"
    NODE_BIN_DIR="$(dirname "$(command -v node)")"
    CORRECT_PATH="${NODE_BIN_DIR}:${HOME}/.bun/bin:${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    if [ -f "$GW_PLIST" ]; then
      python3 -c "
import plistlib, sys
with open('$GW_PLIST', 'rb') as f:
    d = plistlib.load(f)
env = d.setdefault('EnvironmentVariables', {})
env['PATH'] = '$CORRECT_PATH'
with open('$GW_PLIST', 'wb') as f:
    plistlib.dump(d, f)
" 2>/dev/null || true
      # Reload plist so PATH patch takes effect before gateway start
      launchctl unload "$GW_PLIST" 2>/dev/null || true
      launchctl load "$GW_PLIST" 2>/dev/null || true
    fi

    # Sync gateway token → dashboard.env (gateway install may auto-generate a token)
    DASHBOARD_ENV="${HOME}/.config/openclaw/dashboard.env"
    GW_TOKEN=$(python3 -c "import json; c=json.load(open('${HOME}/.openclaw/openclaw.json')); print(c.get('gateway',{}).get('auth',{}).get('token','') or c.get('gateway',{}).get('token',''))" 2>/dev/null)
    if [[ -n "$GW_TOKEN" ]]; then
      (umask 077; echo "export DASHBOARD_TOKEN=${GW_TOKEN}" > "$DASHBOARD_ENV")
      success "Dashboard token synced with gateway"
    fi

    info "Starting Gateway..."
    openclaw gateway start 2>/dev/null || warn "Gateway start failed — check: openclaw gateway start"
    sleep 3
    if openclaw gateway status 2>/dev/null | grep -qi "running\|online\|ok"; then
      success "Gateway running"

      # Register cron jobs from prompt files
      CRON_DIR="${WORKSPACE_DIR}/prompts/cron"
      if [ -d "$CRON_DIR" ]; then
        CRON_COUNT=0
        for prompt_file in "$CRON_DIR"/*.prompt.md; do
          [ -f "$prompt_file" ] || continue
          # Extract frontmatter fields
          JOB_NAME=$(sed -n 's/^name: *"\(.*\)"/\1/p' "$prompt_file" | head -1)
          JOB_CRON=$(sed -n 's/^schedule: *"\(.*\)"/\1/p' "$prompt_file" | head -1)
          JOB_MODEL=$(sed -n 's/^model: *"\(.*\)"/\1/p' "$prompt_file" | head -1)
          JOB_TIMEOUT=$(sed -n 's/^timeout: *\([0-9]*\)/\1/p' "$prompt_file" | head -1)
          JOB_SESSION=$(sed -n 's/^session_target: *"\(.*\)"/\1/p' "$prompt_file" | head -1)
          JOB_TZ=$(sed -n 's/^schedule_tz: *"\(.*\)"/\1/p' "$prompt_file" | head -1)
          JOB_ENABLED=$(sed -n 's/^enabled: *\(.*\)/\1/p' "$prompt_file" | head -1)

          [ -z "$JOB_NAME" ] && continue
          [ -z "$JOB_CRON" ] && continue

          # Read prompt body (everything after second ---)
          JOB_MESSAGE=$(sed -n '/^---$/,/^---$/!p' "$prompt_file" | tail -n +1)
          [ -z "$JOB_MESSAGE" ] && JOB_MESSAGE="Run: $JOB_NAME"

          # Build cron add command
          CRON_ARGS=(
            --name "$JOB_NAME"
            --message "$JOB_MESSAGE"
            --timeout-seconds "${JOB_TIMEOUT:-300}"
          )

          # Determine schedule type: cron expression vs interval (ms)
          if echo "$JOB_CRON" | grep -qE '^[0-9]+$'; then
            # Pure number = interval in ms, convert to duration
            INTERVAL_SEC=$((JOB_CRON / 1000))
            if [ "$INTERVAL_SEC" -ge 60 ]; then
              CRON_ARGS+=(--every "$((INTERVAL_SEC / 60))m")
            else
              CRON_ARGS+=(--every "${INTERVAL_SEC}s")
            fi
          else
            CRON_ARGS+=(--cron "$JOB_CRON")
          fi
          [ -n "$JOB_MODEL" ] && CRON_ARGS+=(--model "$JOB_MODEL")
          [ -n "$JOB_TZ" ] && CRON_ARGS+=(--tz "$JOB_TZ")
          [ "$JOB_SESSION" = "isolated" ] && CRON_ARGS+=(--session isolated)
          [ "$JOB_ENABLED" = "false" ] && CRON_ARGS+=(--disabled)

          if openclaw cron add "${CRON_ARGS[@]}" 2>/dev/null; then
            CRON_COUNT=$((CRON_COUNT + 1))
          fi
        done
        [ "$CRON_COUNT" -gt 0 ] && success "Registered $CRON_COUNT cron jobs"
      fi
    else
      warn "Gateway may not have started. Run: openclaw gateway start"
    fi
  else
    warn "Config validation failed. Fix config then run: openclaw gateway start"
  fi
else
  warn "OpenClaw not found in PATH"
fi

# Wait for qmd embed if still running
if [[ -n "${QMD_PID:-}" ]] && kill -0 "$QMD_PID" 2>/dev/null; then
  wait "$QMD_PID" 2>/dev/null || true
fi

# --- Anti-sleep configuration (keep Mac alive 24/7) ---
if ! $NO_CAFFEINATE; then
  info "Configuring anti-sleep (Mac needs to stay awake for AI partner)..."

  # System-level: disable sleep, keep disk awake, allow display sleep after 10min
  sudo pmset -a sleep 0 displaysleep 10 disksleep 0 2>/dev/null || \
    warn "Could not set pmset — run: sudo pmset -a sleep 0 displaysleep 10 disksleep 0"

  # Caffeinate LaunchAgent as double insurance
  CAFF_PLIST="${HOME}/Library/LaunchAgents/ai.openclaw.caffeinate.plist"
  if [ ! -f "$CAFF_PLIST" ]; then
    mkdir -p "${HOME}/Library/LaunchAgents"
    cat > "$CAFF_PLIST" << 'CAFFEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.caffeinate</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-dimsu</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
CAFFEOF
    launchctl load -w "$CAFF_PLIST" 2>/dev/null || warn "Could not load caffeinate LaunchAgent"
  else
    # Ensure it's loaded
    launchctl load -w "$CAFF_PLIST" 2>/dev/null || true
  fi

  progress_done "Anti-sleep (pmset + caffeinate)"
  info "💡 可选: 安装 Amphetamine (Mac App Store 免费) 做可视化控制"
else
  info "Anti-sleep skipped (--no-caffeinate)"
fi

# ============================================================================
# COMPLETE
# ============================================================================
echo ""
printf "${BOLD}${GREEN}🎉 你的 AI 合伙人已就绪。${NC}\n"
echo ""
printf "   ${BOLD}Workspace:${NC}   %s\n" "$WORKSPACE_DIR"
printf "   ${BOLD}Config:${NC}      %s\n" "${OPENCLAW_STATE}/openclaw.json"
printf "   ${BOLD}Control UI:${NC}  ${CYAN}http://localhost:3456${NC}  ${DIM}(跟 AI 对话)${NC}\n"

if [ -d "${HOME}/projects/infra-dashboard" ]; then
  DASHBOARD_ENV="${HOME}/.config/openclaw/dashboard.env"
  if [ -f "$DASHBOARD_ENV" ]; then
    _DASH_T=$(grep DASHBOARD_TOKEN "$DASHBOARD_ENV" | sed 's/export DASHBOARD_TOKEN=//' | sed 's/DASHBOARD_TOKEN=//')
    printf "   ${BOLD}Dashboard:${NC}   ${CYAN}http://localhost:3001/?token=${_DASH_T}${NC}  ${DIM}(基建监控)${NC}\n"
    printf "   ${DIM}              ↑ 保存到浏览器书签，自动登录${NC}\n"
  else
    printf "   ${BOLD}Dashboard:${NC}   ${CYAN}http://localhost:3001${NC}  ${DIM}(基建监控)${NC}\n"
  fi
fi

# Auto-open both dashboards in browser
# 1. Control UI (webchat) — gateway's built-in web interface
open "http://localhost:3456" 2>/dev/null || true

# 2. Infra dashboard — with auth token
if [ -d "${HOME}/projects/infra-dashboard" ]; then
  DASHBOARD_ENV="${HOME}/.config/openclaw/dashboard.env"
  if [ -f "$DASHBOARD_ENV" ]; then
    DASH_TOKEN_VAL=$(grep DASHBOARD_TOKEN "$DASHBOARD_ENV" | sed 's/export DASHBOARD_TOKEN=//')
    if [[ -n "$DASH_TOKEN_VAL" ]]; then
      open "http://localhost:3001/?token=${DASH_TOKEN_VAL}" 2>/dev/null || true
    fi
  fi
fi

# Print gateway token for user to paste into Control UI
GW_TOKEN_DISPLAY=$(python3 -c "import json; c=json.load(open('${HOME}/.openclaw/openclaw.json')); print(c.get('gateway',{}).get('auth',{}).get('token',''))" 2>/dev/null)
if [[ -n "$GW_TOKEN_DISPLAY" ]]; then
  echo ""
  printf "   ${BOLD}⚡ Gateway Token:${NC} ${CYAN}${GW_TOKEN_DISPLAY}${NC}\n"
  printf "   ${DIM}   (在 Control UI 里粘贴此 token 即可开始对话)${NC}\n"
fi

# Show Tailscale info if available
TS_IP_FINAL=$(tailscale ip -4 2>/dev/null || echo "")
if [[ -n "$TS_IP_FINAL" ]]; then
  printf "   ${BOLD}Tailscale:${NC}   ${CYAN}ssh $(whoami)@${TS_IP_FINAL}${NC}\n"
fi

echo ""
printf "   ${BOLD}下一步:${NC}\n"
if [[ "${CHANNEL_TYPE:-}" == "discord" ]]; then
  printf "   ${DIM}→ 在 Discord 跟你的 AI 说句话试试${NC}\n"
elif [[ "${CHANNEL_TYPE:-}" == "feishu" ]]; then
  printf "   ${DIM}→ 在飞书跟你的 AI 说句话试试${NC}\n"
fi
printf "   ${DIM}→ 编辑 ${WORKSPACE_DIR}/SOUL.md 定义你的 AI 人格${NC}\n"
printf "   ${DIM}→ 编辑 ${WORKSPACE_DIR}/USER.md 告诉 AI 你是谁${NC}\n"
printf "   ${DIM}→ 查看文档: https://docs.openclaw.ai${NC}\n"
echo ""
printf "   ${DIM}遇到问题? 运行: openclaw status${NC}\n"
echo ""
