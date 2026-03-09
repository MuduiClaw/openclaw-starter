#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"
VENV_BASE="${CLAWD_SKILLS_VENV_BASE:-${XDG_CACHE_HOME:-$HOME/.cache}/clawd-skills-venvs}"
VENV_DIR="${VENV_BASE}/${SKILL_NAME}"
STAMP="${VENV_DIR}/.sync-stamp"

export UV_PROJECT_ENVIRONMENT="${VENV_DIR}"
export PYTHONNOUSERSITE=1

if ! command -v uv >/dev/null 2>&1; then
    echo "uv is required. Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
    exit 1
fi

mkdir -p "${VENV_BASE}"
cd "${SKILL_DIR}"

# 检查是否需要重新同步
needs_sync=false
if [ ! -f "${STAMP}" ]; then
    needs_sync=true
elif [ -f "${SKILL_DIR}/pyproject.toml" ] && [ "${SKILL_DIR}/pyproject.toml" -nt "${STAMP}" ]; then
    needs_sync=true
elif [ -f "${SKILL_DIR}/uv.lock" ] && [ "${SKILL_DIR}/uv.lock" -nt "${STAMP}" ]; then
    needs_sync=true
fi

if $needs_sync; then
    uv sync --frozen 2>/dev/null || uv sync
    mkdir -p "${VENV_DIR}"
    touch "${STAMP}"
fi

exec uv run "$@"
