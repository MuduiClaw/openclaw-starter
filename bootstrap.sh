#!/bin/bash
# ============================================================================
# ClawKing 🦞 — Bootstrap
# One-liner that works on a FRESH Mac (no Xcode CLT, no git, no Homebrew).
# Downloads via curl (built into macOS), installs Xcode CLT if needed,
# then clones the repo and hands off to setup.sh.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/MuduiClaw/ClawKing/main/bootstrap.sh)"
# ============================================================================
set -uo pipefail

RED='[0;31m'
GREEN='[0;32m'
YELLOW='[1;33m'
CYAN='[0;36m'
BOLD='[1m'
DIM='[2m'
NC='[0m'

info()    { printf "${CYAN}     %s${NC}
" "$*"; }
success() { printf "${GREEN}     %s ✓${NC}
" "$*"; }
warn()    { printf "${YELLOW}     ⚠ %s${NC}
" "$*"; }
fatal()   { printf "${RED}     ✗ %s${NC}
" "$*"; exit 1; }

REPO_URL="https://github.com/MuduiClaw/ClawKing.git"
CLONE_DIR="${HOME}/ClawKing"

printf "
${BOLD}🦞 ClawKing 🦞 — Bootstrap${NC}

"

# --- macOS only ---
if [[ "$(uname)" != "Darwin" ]]; then
  fatal "This installer only supports macOS."
fi

# --- System proxy auto-detection (for China network) ---
if [[ -z "${https_proxy:-}" ]] && [[ -z "${HTTPS_PROXY:-}" ]]; then
  PROXY_HOST=$(scutil --proxy 2>/dev/null | awk '/HTTPSProxy/ {print $3}')
  PROXY_PORT=$(scutil --proxy 2>/dev/null | awk '/HTTPSPort/ {print $3}')
  if [[ -n "$PROXY_HOST" ]] && [[ "$PROXY_HOST" != "0" ]]; then
    export https_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    export HTTPS_PROXY="$https_proxy"
    export HTTP_PROXY="$http_proxy"
    info "检测到系统代理: ${PROXY_HOST}:${PROXY_PORT}"
  fi
fi

# --- Xcode Command Line Tools ---
if xcode-select -p &>/dev/null; then
  success "Xcode Command Line Tools 已安装"
else
  info "正在安装 Xcode Command Line Tools（全新 Mac 必须，请耐心等待）..."

  # Headless install via softwareupdate (no GUI popup)
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  CLT_LABEL=$(softwareupdate -l 2>&1 | grep -m1 "Label:.*Command Line Tools" | sed 's/.*Label: //')

  if [[ -n "$CLT_LABEL" ]]; then
    info "找到: ${CLT_LABEL}"
    info "下载安装中（可能需要几分钟，取决于网速）..."
    sudo softwareupdate -i "$CLT_LABEL" --verbose 2>&1 | while IFS= read -r line; do
      # Show progress percentage if available
      if echo "$line" | grep -qE '[0-9]+\.[0-9]+%'; then
        printf "${DIM}     %s${NC}" "$line"
      fi
    done
    echo ""
  fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # Fallback: interactive install if headless didn't work
  if ! xcode-select -p &>/dev/null; then
    warn "后台安装未完成，尝试交互式安装..."
    xcode-select --install 2>/dev/null || true
    info "等待安装完成（弹窗中点击「安装」）..."
    until xcode-select -p &>/dev/null; do
      sleep 5
    done
  fi

  if xcode-select -p &>/dev/null; then
    success "Xcode Command Line Tools 安装完成"
  else
    fatal "Xcode Command Line Tools 安装失败。请手动运行: xcode-select --install"
  fi
fi

# --- Verify git works ---
if ! command -v git &>/dev/null; then
  fatal "git 不可用。请先完成 Xcode Command Line Tools 安装"
fi

# --- Clone repo ---
if [[ -d "$CLONE_DIR" ]]; then
  info "目录 ${CLONE_DIR} 已存在，拉取最新代码..."
  cd "$CLONE_DIR" && git pull --ff-only 2>/dev/null || true
else
  info "下载 ClawKing 🦞..."
  if ! git clone "$REPO_URL" "$CLONE_DIR" 2>&1; then
    # Fallback: tarball download (works better behind some firewalls)
    warn "git clone 失败，尝试 tarball 下载..."
    mkdir -p "$CLONE_DIR"
    if curl -sL https://api.github.com/repos/MuduiClaw/ClawKing/tarball/main | \
       tar xz --strip-components=1 -C "$CLONE_DIR" 2>/dev/null; then
      success "Tarball 下载完成"
    else
      rm -rf "$CLONE_DIR"
      fatal "下载失败。请检查网络连接，或手动下载: ${REPO_URL}"
    fi
  fi
fi

success "代码就绪: ${CLONE_DIR}"

# --- Hand off to setup.sh ---
echo ""
info "启动安装程序..."
echo ""
cd "$CLONE_DIR" || fatal "无法进入 ${CLONE_DIR}"
exec bash ./setup.sh "$@"
