#!/usr/bin/env bash
set -euo pipefail

JSON_REPORT="${1:-/zap/wrk/reports/zap-scan-report.json}"
MIN_RISK="${ALERT_MIN_RISK:-3}"

if [[ ! -f "${JSON_REPORT}" ]]; then
  echo "[notify-webhook] No JSON report found at ${JSON_REPORT}; skipping."
  exit 0
fi

# Risk codes in ZAP JSON report: "3" = High, "2" = Medium, "1" = Low, "0" = Informational
HIGH_COUNT=$(jq '[.site[]?.alerts[]? | select((.riskcode | tonumber) >= '"${MIN_RISK}"')] | length' "${JSON_REPORT}")
MED_COUNT=$(jq '[.site[]?.alerts[]? | select((.riskcode | tonumber) == 2)] | length' "${JSON_REPORT}")
LOW_COUNT=$(jq '[.site[]?.alerts[]? | select((.riskcode | tonumber) == 1)] | length' "${JSON_REPORT}")
INFO_COUNT=$(jq '[.site[]?.alerts[]? | select((.riskcode | tonumber) == 0)] | length' "${JSON_REPORT}")

echo "================================================================"
echo " ZAP DAST Scan Summary — Target: ${TARGET_URL:-unknown}"
echo " High: ${HIGH_COUNT} | Medium: ${MED_COUNT} | Low: ${LOW_COUNT} | Info: ${INFO_COUNT}"
echo "================================================================"

if [[ "${HIGH_COUNT}" -eq 0 ]]; then
  echo "[notify-webhook] 0 High findings detected. Staying quiet (alert threshold not met)."
  exit 0
fi

if [[ -z "${WEBHOOK_URL:-}" ]]; then
  echo "[notify-webhook] ${HIGH_COUNT} High finding(s) detected, but WEBHOOK_URL is not set (no-op)."
  exit 0
fi

HIGH_TITLES=$(jq -r '[.site[]?.alerts[]? | select((.riskcode | tonumber) >= '"${MIN_RISK}"') | "• " + .name + " (" + (.instances | length | tostring) + " instance(s))"] | join("\n")' "${JSON_REPORT}")

PAYLOAD=$(jq -n \
  --arg target "${TARGET_URL:-unknown}" \
  --argjson high "${HIGH_COUNT}" \
  --argjson med "${MED_COUNT}" \
  --argjson low "${LOW_COUNT}" \
  --arg titles "${HIGH_TITLES}" \
  '{
    text: ("🚨 *ZAP DAST High-Severity Alert* on `" + $target + "`\n*Counts:* High=" + ($high|tostring) + " | Medium=" + ($med|tostring) + " | Low=" + ($low|tostring) + "\n*High Findings:*\n" + $titles)
  }')

echo "[notify-webhook] Posting High-severity summary to configured webhook..."
curl -sS -X POST "${WEBHOOK_URL}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" >/dev/null
echo "[notify-webhook] Notification sent."
