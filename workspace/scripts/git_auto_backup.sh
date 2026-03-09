#!/bin/bash
# OpenClaw Auto Backup Script
# Runs via LaunchAgent ai.openclaw.backup (hourly)
# Backs up both ~/.openclaw and ~/clawd to their respective GitHub repos

# Resolve real home directory (handles symlinks like $HOME → $HOME)
REAL_HOME="$(cd ~ && pwd -P)"
LOG="/tmp/openclaw_backup.log"
ALERT_FILE="/tmp/openclaw_backup_alert_sent"

# Branch routing (policy: all repos on main)
OPENCLAW_CONFIG_BRANCH="${OPENCLAW_CONFIG_BRANCH:-main}"
CLAWD_WORKSPACE_BRANCH="${CLAWD_WORKSPACE_BRANCH:-main}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

alert() {
    log "⚠️ ALERT: $1"
    if command -v openclaw &>/dev/null; then
        openclaw message send --channel discord --target "channel:1468294832551362782" \
            --message "⚠️ **备份失败**: $1" 2>/dev/null &
    fi
}

# POSIX timeout replacement for macOS
run_with_timeout() {
    local timeout_sec="$1"
    shift
    "$@" &
    local pid=$!
    ( sleep "$timeout_sec" && kill "$pid" 2>/dev/null ) &
    local watchdog=$!
    wait "$pid" 2>/dev/null
    local exit_code=$?
    kill "$watchdog" 2>/dev/null 2>&1
    wait "$watchdog" 2>/dev/null 2>&1
    return $exit_code
}

backup_repo() {
    local DIR="$1"
    local NAME="$2"
    local BRANCH="$3"
    
    cd "$DIR" || { alert "$NAME: 目录不存在 $DIR"; return 1; }
    
    if [ ! -d .git ]; then
        alert "$NAME: 不是 git repo"
        return 1
    fi
    
    if ! git remote get-url origin &>/dev/null; then
        alert "$NAME: 没有 remote"
        return 1
    fi
    
    local CHANGED_FILES=$(git status --porcelain 2>/dev/null)
    local CHANGES=$(echo "$CHANGED_FILES" | grep -c '[^ ]' || true)
    if [ "$CHANGES" = "0" ]; then
        log "$NAME: 无变更，跳过"
        return 0
    fi
    
    # Build descriptive commit message: list changed dirs/files
    local SUMMARY=$(echo "$CHANGED_FILES" | awk '{print $2}' | sed 's|/.*||' | sort -u | head -5 | tr '\n' ', ' | sed 's/,$//')
    local EXTRA=""
    local DIR_COUNT=$(echo "$CHANGED_FILES" | awk '{print $2}' | sed 's|/.*||' | sort -u | wc -l | tr -d ' ')
    if [ "$DIR_COUNT" -gt 5 ]; then
        EXTRA=" +$((DIR_COUNT - 5)) more"
    fi
    
    if ! git add -A 2>&1 | tee -a "$LOG"; then
        alert "$NAME: git add 失败 (可能有嵌套 .git 目录)"
        # Fallback: add tracked files only
        git add -u 2>/dev/null
    fi
    
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit --no-verify -m "backup: ${SUMMARY}${EXTRA} (${CHANGES} files) $(date '+%m-%d %H:%M')" --quiet 2>/dev/null
    else
        log "⚠️ $NAME: 有变更但 staging 为空 (git add 可能失败)"
        return 1
    fi
    
    local PUSH_REFSPEC="HEAD:${BRANCH}"
    local PUSH_LOG="/tmp/openclaw_backup_push_${NAME}_$$.log"

    if run_with_timeout 180 bash -lc "git push origin '${PUSH_REFSPEC}' >'${PUSH_LOG}' 2>&1"; then
        log "✅ $NAME: 推送成功 ($CHANGES 文件变更, branch=${BRANCH})"
        rm -f "${ALERT_FILE}_${NAME}" 2>/dev/null
        rm -f "$PUSH_LOG" 2>/dev/null
        return 0
    else
        local REASON="unknown"
        if [ -f "$PUSH_LOG" ]; then
            if grep -Eiq "non-fast-forward|fetch first|rejected" "$PUSH_LOG"; then
                REASON="non-fast-forward（远端分叉/领先）"
            elif grep -Eiq "could not read Username|Authentication failed|Permission denied|403|401" "$PUSH_LOG"; then
                REASON="鉴权失败"
            elif grep -Eiq "timed out|timeout|Connection reset|network" "$PUSH_LOG"; then
                REASON="网络/超时"
            fi
            log "❌ $NAME push stderr: $(tail -n 3 "$PUSH_LOG" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
        fi

        if [ ! -f "${ALERT_FILE}_${NAME}" ]; then
            alert "$NAME: push 失败 - ${REASON} (branch=${BRANCH})"
            touch "${ALERT_FILE}_${NAME}"
        else
            log "❌ $NAME: push 仍然失败 (已发过告警, reason=${REASON})"
        fi
        rm -f "$PUSH_LOG" 2>/dev/null
        return 1
    fi
}

log "========== 备份开始 =========="

# === Sync dotfiles + LaunchAgents + tool configs before backup ===
_sync_recovery_assets() {
    local HOME_DIR="$REAL_HOME"
    local CLAWD="$HOME_DIR/clawd"

    # Dotfiles (redact secrets inline)
    local DST="$CLAWD/scripts/dotfiles"
    [ -d "$DST" ] || mkdir -p "$DST"
    # Copy zshrc — skip lines with $(op read (already safe), only redact static values
    sed -E '/\$\(op read/!s/(TOKEN|SECRET|PASSWORD|KEY)="[^$][^"]*"/\1="<REDACTED>"/g' \
        "$HOME_DIR/.zshrc" > "$DST/zshrc" 2>/dev/null
    cp -f "$HOME_DIR/.gitconfig" "$DST/gitconfig" 2>/dev/null
    cp -f "$HOME_DIR/.npmrc" "$DST/npmrc" 2>/dev/null
    cp -f "$HOME_DIR/.zshenv" "$DST/zshenv" 2>/dev/null

    # LaunchAgents (custom only)
    local LA_DST="$CLAWD/scripts/launchagents"
    [ -d "$LA_DST" ] || mkdir -p "$LA_DST"
    for f in "$HOME_DIR/Library/LaunchAgents"/com.{YOUR_USERNAME,openclaw,cloudflare,openclaw}*.plist; do
        [ -f "$f" ] && cp -f "$f" "$LA_DST/" 2>/dev/null
    done

    # Brewfile (weekly refresh — check age)
    local BF="$CLAWD/scripts/Brewfile"
    if [ ! -f "$BF" ] || [ "$(find "$BF" -mmin +10080 2>/dev/null)" ]; then
        brew bundle dump --file="$BF" --force 2>/dev/null
    fi
}
_sync_recovery_assets

backup_repo "$REAL_HOME/.openclaw" "openclaw-config" "$OPENCLAW_CONFIG_BRANCH"
backup_repo "$REAL_HOME/.agents" "agents-skills" "main"
backup_repo "$REAL_HOME/clawd" "clawd-workspace" "$CLAWD_WORKSPACE_BRANCH"

# === R2 Daily Backups (sessions + assets) ===
R2_MARKER="/tmp/r2_backup_done_$(date '+%Y-%m-%d')"
if [ ! -f "$R2_MARKER" ]; then
    log "Running daily R2 backups..."
    R2_OK=true
    
    if bash "$REAL_HOME/clawd/scripts/r2_backup_sessions.sh"; then
        log "✅ R2 sessions backup complete"
    else
        log "❌ R2 sessions backup failed"
        R2_OK=false
    fi
    
    if bash "$REAL_HOME/clawd/scripts/r2_backup_assets.sh"; then
        log "✅ R2 assets backup complete"
    else
        log "❌ R2 assets backup failed"
        R2_OK=false
    fi
    
    if $R2_OK; then
        touch "$R2_MARKER"
    fi
else
    log "R2 daily backups already done today, skipping"
fi

log "========== 备份结束 =========="
