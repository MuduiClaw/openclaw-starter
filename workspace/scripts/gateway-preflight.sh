#!/usr/bin/env bash
# gateway-preflight.sh — Gateway 配置变更前后验收门禁
# 用法:
#   bash scripts/gateway-preflight.sh                 # 默认 pre
#   bash scripts/gateway-preflight.sh --phase post
#
# 通过标准（硬门禁）:
# 1) openclaw config validate --json => valid=true
# 2) openclaw gateway call health --json => ok=true
# 3) openclaw gateway status => 包含 "RPC probe: ok"
# 4) openclaw doctor --non-interactive 命令可执行（结果落盘供审计）

set -euo pipefail

PHASE="pre"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --phase)
      PHASE="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,60p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 64
      ;;
  esac
done

if [[ "$PHASE" != "pre" && "$PHASE" != "post" ]]; then
  echo "--phase must be pre|post" >&2
  exit 64
fi

TS="$(date '+%Y%m%d-%H%M%S')"
OUT_DIR="${TMPDIR:-/tmp}/openclaw-preflight-${PHASE}-${TS}"
mkdir -p "$OUT_DIR"

fail() {
  local step="$1"
  local reason="$2"
  echo "GATEWAY_PREFLIGHT_FAIL phase=${PHASE} step=${step} reason=${reason} report=${OUT_DIR}" >&2
  exit 1
}

# 1) 配置校验
if ! openclaw config validate --json >"$OUT_DIR/config-validate.json" 2>"$OUT_DIR/config-validate.err"; then
  fail "config_validate" "command_failed"
fi

if ! jq -e '.valid == true' "$OUT_DIR/config-validate.json" >/dev/null 2>&1; then
  fail "config_validate" "invalid_config"
fi

# 2) Gateway 健康 RPC
if ! openclaw gateway call health --json >"$OUT_DIR/gateway-health.json" 2>"$OUT_DIR/gateway-health.err"; then
  fail "gateway_health" "rpc_failed"
fi

if ! jq -e '.ok == true' "$OUT_DIR/gateway-health.json" >/dev/null 2>&1; then
  fail "gateway_health" "health_not_ok"
fi

# 3) Gateway 状态探针
if ! openclaw gateway status >"$OUT_DIR/gateway-status.txt" 2>"$OUT_DIR/gateway-status.err"; then
  fail "gateway_status" "command_failed"
fi

if ! rg -q "RPC probe: ok" "$OUT_DIR/gateway-status.txt"; then
  fail "gateway_status" "rpc_probe_not_ok"
fi

# 4) Doctor 快速体检（非交互）
if ! openclaw doctor --non-interactive >"$OUT_DIR/doctor.txt" 2>"$OUT_DIR/doctor.err"; then
  fail "doctor" "command_failed"
fi

echo "GATEWAY_PREFLIGHT_OK phase=${PHASE} report=${OUT_DIR}"