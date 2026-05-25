#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

python3 - "${PROMETHEUS_URL}" <<'PY'
import json
import sys
import urllib.error
import urllib.request

base = sys.argv[1].rstrip("/")
url = f"{base}/api/v1/alerts"

try:
    with urllib.request.urlopen(url, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))
except urllib.error.URLError as exc:
    print(f"Cannot reach Prometheus at {base}: {exc}")
    print("Start local access with: scripts/lab.sh access")
    sys.exit(1)

alerts = payload.get("data", {}).get("alerts", [])
if not alerts:
    print("No alerts returned by Prometheus.")
    sys.exit(0)

print(f"Prometheus alerts from {base}")
print()
for alert in alerts:
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    name = labels.get("alertname", "unknown")
    state = alert.get("state", "unknown")
    severity = labels.get("severity", "unknown")
    scenario = labels.get("scenario", "-")
    summary = annotations.get("summary", "")
    active_at = alert.get("activeAt", "")
    print(f"- {name} [{state}] severity={severity} scenario={scenario}")
    if active_at:
        print(f"  activeAt: {active_at}")
    if summary:
        print(f"  summary: {summary}")
PY
