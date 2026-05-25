#!/usr/bin/env bash
set -euo pipefail

echo "Restoring podinfo Service selector..."
kubectl -n incident-lab patch svc podinfo --type='json' \
  -p='[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"podinfo"}]'

echo
echo "Current Service endpoints:"
kubectl -n incident-lab get endpoints podinfo
echo "Service selector restored."
