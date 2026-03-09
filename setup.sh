#!/bin/bash
set -euo pipefail

# ============================================================================
# OpenClaw Starter Kit — setup.sh
# Interactive, idempotent installer. User does 3 things:
#   1. Run this script
#   2. Paste Anthropic credential
#   3. Paste Chat Channel token
# Everything else is fully automatic.
# ============================================================================

STARTER_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Defaults ---
WORKSPACE_DIR="${HOME}/clawd"
OPENCLAW_STATE="${HOME}/.openclaw"
NO_LAUNCHAGENTS=false
UNINSTALL=false
SKIP_DASHBOARD=false

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
    --uninstall)       UNINSTALL=true; shift ;;
    --help|-h)
      echo "Usage: ./setup.sh [--workspace-dir ~/clawd] [--no-launchagents] [--skip-dashboard] [--uninstall]"
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
               com.openclaw.infra-dashboard com.openclaw.mcp-bridge; do
    plist_path="${HOME}/Library/LaunchAgents/${plist}.plist"
    if [ -f "$plist_path" ]; then
      launchctl unload "$plist_path" 2>/dev/null || true
      rm -f "$plist_path"
      info "Removed $plist"
    fi
  done

  echo ""
  ask "Delete workspace ${WORKSPACE_DIR}? [y/N]"
  read -r confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    rm -rf "$WORKSPACE_DIR"
    info "Workspace deleted"
  fi

  ask "Delete state dir ${OPENCLAW_STATE}? [y/N]"
  read -r confirm
  if [[ "$confirm" =~ ^[yY]$ ]]; then
    rm -rf "$OPENCLAW_STATE"
    info "State directory deleted"
  fi

  success "Uninstall complete"
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
for port_info in "3001:infra-dashboard" "9100:mcp-bridge"; do
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
  info "Installing Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null || true
  # Wait for installation
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
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
if ! command -v node &>/dev/null; then
  info "Installing Node.js..."
  brew install node@24
  success "Node.js $(node --version)"
else
  NODE_VERSION=$(node --version | sed 's/v//' | cut -d. -f1)
  if [[ "$NODE_VERSION" -lt 20 ]]; then
    warn "Node.js v${NODE_VERSION} detected, v20+ recommended"
    info "Installing Node.js 24..."
    brew install node@24
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
NPM_GLOBALS=(
  "@anthropic-ai/claude-code"
  "@openai/codex"
  "@google/gemini-cli"
  "@steipete/oracle"
  "mcporter"
  "clawhub"
  "qmd"
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
    # Sync (overwrite)
    rsync -a --delete "$src/" "$dst/"
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
QMD_PATH="$(command -v qmd 2>/dev/null || echo "${BREW_PREFIX}/bin/qmd")"
cat > "${OPENCLAW_STATE}/scripts/qmd-safe.sh" << QMDEOF
#!/bin/bash
set -euo pipefail
# qmd wrapper — safe mode for LaunchAgent
exec "${QMD_PATH}" "\$@"
QMDEOF
chmod +x "${OPENCLAW_STATE}/scripts/qmd-safe.sh"
progress_done "qmd wrapper"

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
  echo ""
  printf "${BOLD}     Anthropic 认证 — 选择方式:${NC}\n"
  printf "       ${CYAN}1.${NC} API Key (按量付费，需 Anthropic Console 账号)\n"
  printf "       ${CYAN}2.${NC} setup-token (用 Claude Pro/Max 订阅额度)\n"
  printf "       ${DIM}       参考: https://docs.openclaw.ai/providers/anthropic${NC}\n"
  echo ""
  ask "> "
  read -r auth_choice

  case "$auth_choice" in
    1)
      ANTHROPIC_MODE="api-key"
      ask "Anthropic API Key (sk-ant-...): "
      read -rs ANTHROPIC_KEY
      echo ""
      if [[ ! "$ANTHROPIC_KEY" =~ ^sk-ant- ]]; then
        warn "Key doesn't start with sk-ant-. Are you sure it's correct?"
      fi
      success "Anthropic API Key"
      ;;
    2)
      ANTHROPIC_MODE="setup-token"
      echo ""
      info "请在另一个终端运行:"
      printf "       ${BOLD}claude setup-token${NC}\n"
      info "然后粘贴获得的 token"
      echo ""
      ask "Setup Token: "
      read -rs ANTHROPIC_KEY
      echo ""
      success "Anthropic Setup Token"
      ;;
    *)
      warn "Invalid choice, defaulting to API Key"
      ANTHROPIC_MODE="api-key"
      ask "Anthropic API Key: "
      read -rs ANTHROPIC_KEY
      echo ""
      ;;
  esac

  echo ""
  printf "${BOLD}     Chat Channel — 选择一个:${NC}\n"
  printf "       ${CYAN}1.${NC} Discord\n"
  printf "       ${CYAN}2.${NC} 飞书 (Feishu)\n"
  echo ""
  ask "> "
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
      warn "Invalid choice, defaulting to Discord"
      CHANNEL_TYPE="discord"
      ask "Discord Bot Token: "
      read -rs DISCORD_TOKEN
      echo ""
      ask "Discord Guild ID: "
      read -r DISCORD_GUILD
      ask "Your Discord User ID: "
      read -r DISCORD_USER
      ;;
  esac

  # --- Optional: GitHub Token ---
  echo ""
  ask "GitHub Token (可选, 直接回车跳过): "
  read -rs GITHUB_TOKEN
  echo ""

  # ========================================================================
  # GENERATE openclaw.json
  # ========================================================================
  info "Generating configuration..."

  NODE_BIN="$(dirname "$(command -v node)")"

  # Build env.vars
  ENV_VARS="{"
  if [[ "$ANTHROPIC_MODE" == "api-key" ]] && [[ -n "$ANTHROPIC_KEY" ]]; then
    ENV_VARS+="\"ANTHROPIC_API_KEY\": \"${ANTHROPIC_KEY}\""
  fi
  if [[ "$CHANNEL_TYPE" == "discord" ]] && [[ -n "$DISCORD_TOKEN" ]]; then
    [[ "$ENV_VARS" != "{" ]] && ENV_VARS+=","
    ENV_VARS+="\"DISCORD_BOT_TOKEN\": \"${DISCORD_TOKEN}\""
  fi
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    [[ "$ENV_VARS" != "{" ]] && ENV_VARS+=","
    ENV_VARS+="\"GITHUB_TOKEN\": \"${GITHUB_TOKEN}\""
  fi
  ENV_VARS+="}"

  # Build channels block
  CHANNELS="{"
  if [[ "$CHANNEL_TYPE" == "discord" ]]; then
    CHANNELS+="\"discord\": {"
    if [[ -n "$DISCORD_GUILD" ]]; then
      CHANNELS+="\"allowlist\": [{\"guild\": \"${DISCORD_GUILD}\""
      if [[ -n "$DISCORD_USER" ]]; then
        CHANNELS+=",\"users\": [\"${DISCORD_USER}\"]"
      fi
      CHANNELS+="}]"
    fi
    CHANNELS+="}"
  elif [[ "$CHANNEL_TYPE" == "feishu" ]]; then
    CHANNELS+="\"feishu\": {"
    CHANNELS+="\"appId\": \"${FEISHU_APP_ID}\","
    CHANNELS+="\"appSecret\": \"${FEISHU_APP_SECRET}\""
    CHANNELS+="}"
  fi
  CHANNELS+="}"

  # Build models block
  MODELS="{\"providers\": {}}"

  # Generate openclaw.json using node for proper JSON
  node -e "
const config = {
  env: { vars: ${ENV_VARS} },
  gateway: { port: 3456 },
  agents: {
    defaults: { model: { primary: 'anthropic/claude-sonnet-4-6' } }
  },
  models: ${MODELS},
  memory: {
    backend: 'qmd',
    citations: 'auto',
    qmd: {
      command: '${OPENCLAW_STATE}/scripts/qmd-safe.sh',
      searchMode: 'search',
      includeDefaultMemory: true,
      update: { interval: '5m', debounceMs: 15000, onBoot: true },
      limits: { maxResults: 10, timeoutMs: 60000 }
    }
  },
  channels: ${CHANNELS},
  acp: {
    enabled: true,
    dispatch: { enabled: true },
    backend: 'acpx',
    defaultAgent: 'codex',
    allowedAgents: ['pi', 'claude', 'codex', 'opencode', 'gemini'],
    maxConcurrentSessions: 4
  },
  tools: { profile: 'full' },
  skills: { load: { watch: false }, install: { nodeManager: 'npm' } },
  cron: { maxConcurrentRuns: 3 },
  logging: { level: 'info', file: true, consoleLevel: 'warn' },
  session: { dmScope: 'user' },
  browser: { enabled: true, headless: true }
};
process.stdout.write(JSON.stringify(config, null, 2));
" > "$EXISTING_CONFIG"

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

# --- infra-dashboard ---
if ! $SKIP_DASHBOARD; then
  DASHBOARD_DIR="${HOME}/projects/infra-dashboard"

  if [ -d "${SCRIPT_DIR}/projects/infra-dashboard/.git" ]; then
    # Git submodule present in starter
    if [ ! -d "$DASHBOARD_DIR" ]; then
      info "Setting up infra-dashboard..."
      cd "$SCRIPT_DIR"
      git submodule update --init projects/infra-dashboard 2>/dev/null || true
      if [ -d "${SCRIPT_DIR}/projects/infra-dashboard" ]; then
        cp -a "${SCRIPT_DIR}/projects/infra-dashboard" "$DASHBOARD_DIR"
      fi
    fi
  fi

  if [ -d "$DASHBOARD_DIR" ]; then
    cd "$DASHBOARD_DIR"
    if [ ! -d "node_modules" ]; then
      info "Installing dashboard dependencies..."
      npm install --production 2>/dev/null || warn "Dashboard npm install failed"
    fi
    if [ ! -f ".next/BUILD_ID" ]; then
      info "Building dashboard..."
      npm run build 2>/dev/null || warn "Dashboard build failed"
    fi

    # Generate dashboard token if missing
    DASHBOARD_ENV="${HOME}/.config/openclaw/dashboard.env"
    if [ ! -f "$DASHBOARD_ENV" ]; then
      DASH_TOKEN=$(openssl rand -hex 32)
      echo "DASHBOARD_TOKEN=${DASH_TOKEN}" > "$DASHBOARD_ENV"
      chmod 600 "$DASHBOARD_ENV"
      success "Dashboard token generated"
    fi

    # Prepare start script
    NODE_BIN_DIR="$(dirname "$(command -v node)")"
    START_SCRIPT="${OPENCLAW_STATE}/scripts/start-infra-dashboard.sh"
    sed -e "s|__HOME__|${HOME}|g" \
        -e "s|__NODE_BIN__|${NODE_BIN_DIR}|g" \
        "${SCRIPT_DIR}/services/scripts/start-infra-dashboard.sh" > "$START_SCRIPT"
    chmod +x "$START_SCRIPT"

    progress_done "infra-dashboard"
    cd "$SCRIPT_DIR"
  else
    warn "infra-dashboard not found — skipping (you can clone it later)"
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
  # Validate config first
  if openclaw config validate 2>/dev/null; then
    info "Starting Gateway..."
    openclaw gateway start 2>/dev/null || warn "Gateway start failed — check: openclaw gateway start"
    sleep 2
    if openclaw gateway status 2>/dev/null | grep -qi "running\|online\|ok"; then
      success "Gateway running"
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

# ============================================================================
# COMPLETE
# ============================================================================
echo ""
printf "${BOLD}${GREEN}🎉 你的 AI 合伙人已就绪。${NC}\n"
echo ""
printf "   ${BOLD}Workspace:${NC}   %s\n" "$WORKSPACE_DIR"
printf "   ${BOLD}Config:${NC}      %s\n" "${OPENCLAW_STATE}/openclaw.json"

if [ -d "${HOME}/projects/infra-dashboard" ]; then
  printf "   ${BOLD}Dashboard:${NC}   ${CYAN}http://localhost:3001${NC}\n"
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
