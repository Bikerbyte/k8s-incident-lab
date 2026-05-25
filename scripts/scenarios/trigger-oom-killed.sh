#!/usr/bin/env bash
set -euo pipefail

echo "Setting podinfo memory limit to 15Mi to trigger OOMKill..."
kubectl -n incident-lab set resources deployment/podinfo \
  --containers=podinfo \
  --limits=memory=15Mi

echo
echo "Rollout in progress (new pod will OOMKill under this limit)..."
if ! kubectl -n incident-lab rollout status deploy/podinfo --timeout=60s; then
  echo
  echo "Rollout did not complete, which is expected for this scenario."
fi

echo
echo "Current pod state:"
kubectl -n incident-lab get pods

echo
echo "Watch for OOMKill and restart count:"
echo "  kubectl -n incident-lab get pods -w"
echo "  kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo"
echo
echo "Restore with: scripts/lab.sh scenario oom restore"
