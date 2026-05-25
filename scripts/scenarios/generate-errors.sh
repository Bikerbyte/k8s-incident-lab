#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-9898}"
REQUESTS="${REQUESTS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"

kubectl -n incident-lab port-forward svc/podinfo "${LOCAL_PORT}:9898" >/tmp/podinfo-port-forward.log 2>&1 &
PF_PID=$!

cleanup() {
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 2

for i in $(seq 1 "${REQUESTS}"); do
  curl -s -o /dev/null -w "request ${i}: HTTP %{http_code}\n" "http://127.0.0.1:${LOCAL_PORT}/status/500"
  sleep "${SLEEP_SECONDS}"
done

echo "Generated ${REQUESTS} failing requests."
