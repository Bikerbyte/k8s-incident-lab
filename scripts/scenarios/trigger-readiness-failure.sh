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

if ! kubectl -n incident-lab rollout status deploy/podinfo --timeout=30s; then
  echo
  echo "Rollout did not complete, which is expected for this scenario."
  echo "The new pod cannot become Ready because its readiness probe now points to /broken-readyz."
fi

echo
echo "Current pod state:"
kubectl -n incident-lab get pods

echo
echo "Current Service endpoints:"
kubectl -n incident-lab get endpoints podinfo

echo
echo "Readiness failure triggered."
echo "Restore with: scripts/lab.sh scenario readiness restore"
