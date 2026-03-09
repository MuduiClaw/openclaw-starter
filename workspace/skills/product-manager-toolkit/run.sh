#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="$(basename "$SKILL_DIR")"
VENV_BASE="${CLAWD_SKILLS_VENV_BASE:-${XDG_CACHE_HOME:-$HOME/.cache}/clawd-skills-venvs}"
VENV_DIR="${VENV_BASE}/${SKILL_NAME}"
STAMP="${VENV_DIR}/.pip-stamp"

export VIRTUAL_ENV="${VENV_DIR}"
export PATH="${VENV_DIR}/bin:${PATH}"
export PYTHONNOUSERSITE=1

# 创建 venv（如果不存在）
if [ ! -x "${VENV_DIR}/bin/python" ]; then
    python3 -m venv "${VENV_DIR}"
fi

# 安装依赖（如果 requirements.txt 更新了）
if [ -f "${SKILL_DIR}/requirements.txt" ]; then
    if [ ! -f "${STAMP}" ] || [ "${SKILL_DIR}/requirements.txt" -nt "${STAMP}" ]; then
        "${VENV_DIR}/bin/python" -m pip install -q -r "${SKILL_DIR}/requirements.txt"
        touch "${STAMP}"
    fi
fi

cd "${SKILL_DIR}"

if [ $# -eq 0 ]; then
    exec "${VENV_DIR}/bin/python"
fi

exec "$@"
