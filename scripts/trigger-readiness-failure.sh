#!/usr/bin/env bash
set -euo pipefail

kubectl -n incident-lab patch deployment podinfo --type='json' \
  -p='[
    {
      "op": "replace",
      "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
      "value": "/broken-readyz"
    }
  ]'

kubectl -n incident-lab rollout status deploy/podinfo
echo "Readiness failure triggered. Check: kubectl -n incident-lab get pods"
