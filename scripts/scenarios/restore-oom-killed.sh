#!/usr/bin/env bash
set -euo pipefail

echo "Restoring podinfo memory limit to 128Mi..."
kubectl -n incident-lab set resources deployment/podinfo \
  --containers=podinfo \
  --limits=memory=128Mi

kubectl -n incident-lab rollout status deploy/podinfo
echo "Memory limits restored."
