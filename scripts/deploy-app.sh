#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f app/manifests/namespace.yaml
kubectl apply -f app/manifests/podinfo.yaml
kubectl -n incident-lab rollout status deploy/podinfo

echo "Podinfo is deployed in namespace incident-lab."
