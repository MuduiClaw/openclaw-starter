#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_BASE="${CLAWD_SKILLS_VENV_BASE:-${XDG_CACHE_HOME:-$HOME/.cache}/clawd-skills-venvs}"
VENV_DIR="${VENV_BASE}/xlsx"
STAMP="${VENV_DIR}/.pip-stamp"

export VIRTUAL_ENV="${VENV_DIR}"
export PATH="${VENV_DIR}/bin:${PATH}"
export PYTHONNOUSERSITE=1

if [ ! -x "${VENV_DIR}/bin/python" ]; then
  python3 -m venv "${VENV_DIR}"
fi

if [ ! -f "${STAMP}" ] || [ "${SKILL_DIR}/requirements.txt" -nt "${STAMP}" ]; then
  "${VENV_DIR}/bin/python" -m pip install -q -r "${SKILL_DIR}/requirements.txt"
  touch "${STAMP}"
fi

cd "${SKILL_DIR}"

if [ $# -eq 0 ]; then
  echo "Usage: ./run.sh <excel_file> [timeout_seconds]" >&2
  exit 1
fi

exec "${VENV_DIR}/bin/python" "${SKILL_DIR}/recalc.py" "$@"
