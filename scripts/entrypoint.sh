#!/usr/bin/env bash
set -euo pipefail

export TARGET_URL="${TARGET_URL:-http://juice-shop:3000}"
export PLAN_FILE="${PLAN_FILE:-plans/scan-juice-shop.yaml}"
export REPORT_DIR="${REPORT_DIR:-/zap/wrk/reports}"
export REPORT_NAME="${REPORT_NAME:-zap-scan-report}"
export SPIDER_MAX_DURATION_MINS="${SPIDER_MAX_DURATION_MINS:-2}"
export AJAX_SPIDER_MAX_DURATION_MINS="${AJAX_SPIDER_MAX_DURATION_MINS:-2}"
export AUTH_HEADER_NAME="${AUTH_HEADER_NAME:-Authorization}"

echo "[entrypoint] Target URL: ${TARGET_URL}"
echo "[entrypoint] Plan file : ${PLAN_FILE}"

# Wait briefly for target to be reachable before authenticating
for i in {1..20}; do
  if curl -sk -o /dev/null "${TARGET_URL}"; then
    break
  fi
  echo "[entrypoint] Waiting for ${TARGET_URL} to respond (${i}/20)..."
  sleep 2
done

# Obtain Bearer token if ZAP_AUTH_HEADER_VALUE is not already supplied and AUTH_LOGIN_URL is configured
if [[ -z "${ZAP_AUTH_HEADER_VALUE:-}" && -n "${AUTH_LOGIN_URL:-}" && -n "${AUTH_EMAIL:-}" && -n "${AUTH_PASSWORD:-}" ]]; then
  # Only auto-authenticate against AUTH_LOGIN_URL if it matches the target origin or is explicitly set
  TARGET_ORIGIN=$(echo "${TARGET_URL}" | awk -F/ '{print $1"//"$3}')
  LOGIN_ORIGIN=$(echo "${AUTH_LOGIN_URL}" | awk -F/ '{print $1"//"$3}')

  if [[ "${TARGET_ORIGIN}" == "${LOGIN_ORIGIN}" ]]; then
    echo "[entrypoint] Authenticating test user (${AUTH_EMAIL}) at ${AUTH_LOGIN_URL}..."

    # If AUTH_REGISTER_URL is set (e.g., fresh Juice Shop instance), ensure the test account exists
    if [[ -n "${AUTH_REGISTER_URL:-}" ]]; then
      curl -sk -X POST "${AUTH_REGISTER_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${AUTH_EMAIL}\",\"password\":\"${AUTH_PASSWORD}\",\"passwordRepeat\":\"${AUTH_PASSWORD}\",\"securityQuestion\":{\"id\":1,\"question\":\"Your eldest siblings middle name?\"},\"securityAnswer\":\"test\"}" \
        >/dev/null 2>&1 || true
    fi

    LOGIN_RESP=$(curl -sk -X POST "${AUTH_LOGIN_URL}" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"${AUTH_EMAIL}\",\"password\":\"${AUTH_PASSWORD}\"}" || true)

    TOKEN=$(echo "${LOGIN_RESP}" | jq -r '.authentication.token // .token // .access_token // empty' 2>/dev/null || true)

    if [[ -n "${TOKEN}" ]]; then
      PREFIX="${AUTH_TOKEN_PREFIX:-Bearer}"
      export ZAP_AUTH_HEADER_VALUE="${PREFIX} ${TOKEN}"
      echo "[entrypoint] Authenticated successfully (token length: ${#TOKEN} chars)."
    else
      echo "[entrypoint] WARNING: Could not extract token from ${AUTH_LOGIN_URL}; proceeding with unauthenticated/fallback header."
      export ZAP_AUTH_HEADER_VALUE="Bearer unauthenticated"
    fi
  else
    export ZAP_AUTH_HEADER_VALUE="Bearer unauthenticated"
  fi
else
  export ZAP_AUTH_HEADER_VALUE="${ZAP_AUTH_HEADER_VALUE:-Bearer unauthenticated}"
fi

# Run the ZAP Automation Framework plan
ZAP_EXIT=0
/zap/wrk/scripts/run-plan.sh "${PLAN_FILE}" || ZAP_EXIT=$?

# Run severity-gated webhook notification if JSON report was generated
JSON_REPORT="${REPORT_DIR}/${REPORT_NAME}.json"
if [[ -f "${JSON_REPORT}" ]]; then
  /zap/wrk/scripts/notify-webhook.sh "${JSON_REPORT}"
fi

exit "${ZAP_EXIT}"
