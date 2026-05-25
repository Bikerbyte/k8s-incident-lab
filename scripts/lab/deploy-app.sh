#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Cannot connect to the Kubernetes API server."
  echo "If you are using minikube, start it first:"
  echo "  minikube start"
  exit 1
fi

kubectl apply -f "${REPO_ROOT}/app/manifests/namespace.yaml"
kubectl apply -f "${REPO_ROOT}/app/manifests/podinfo.yaml"
kubectl -n incident-lab rollout status deploy/podinfo

echo "Podinfo is deployed in namespace incident-lab."
