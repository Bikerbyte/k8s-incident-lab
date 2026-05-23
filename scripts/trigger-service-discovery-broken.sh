#!/usr/bin/env bash
set -euo pipefail

echo "Breaking podinfo Service selector (pointing to non-existent label)..."
kubectl -n incident-lab patch svc podinfo --type='json' \
  -p='[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"podinfo-typo"}]'

echo
echo "Current Service endpoints (should be empty):"
kubectl -n incident-lab get endpoints podinfo

echo
echo "Pods are still Running and Ready:"
kubectl -n incident-lab get pods

echo
echo "Service discovery broken. Traffic cannot reach any pod."
echo "Restore with: scripts/restore-service-discovery-broken.sh"
