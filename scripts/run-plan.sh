#!/usr/bin/env bash
set -euo pipefail

PLAN_TEMPLATE="${1:-plans/scan-juice-shop.yaml}"
RENDERED_PLAN="/tmp/zap-plan-rendered.yaml"

if [[ ! -f "${PLAN_TEMPLATE}" ]]; then
  echo "[run-plan] ERROR: Plan template not found: ${PLAN_TEMPLATE}" >&2
  exit 1
fi

mkdir -p "${REPORT_DIR:-/zap/wrk/reports}"

# Use a strictly SCOPED variable list for envsubst so ZAP's own internal placeholders survive untouched
SCOPED_VARS='${TARGET_URL} ${AUTH_HEADER_NAME} ${ZAP_AUTH_HEADER_VALUE} ${SPIDER_MAX_DURATION_MINS} ${AJAX_SPIDER_MAX_DURATION_MINS} ${REPORT_DIR} ${REPORT_NAME}'

echo "[run-plan] Rendering plan template ${PLAN_TEMPLATE} -> ${RENDERED_PLAN}"
envsubst "${SCOPED_VARS}" < "${PLAN_TEMPLATE}" > "${RENDERED_PLAN}"

echo "[run-plan] Starting ZAP (-cmd -silent -autorun)..."
/zap/zap.sh -cmd -silent -autorun "${RENDERED_PLAN}"
