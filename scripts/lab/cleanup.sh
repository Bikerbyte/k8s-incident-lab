#!/usr/bin/env bash
set -euo pipefail

kubectl delete namespace incident-lab --ignore-not-found

helm uninstall promtail --namespace monitoring --ignore-not-found || true
helm uninstall loki --namespace monitoring --ignore-not-found || true
helm uninstall kube-prometheus-stack --namespace monitoring --ignore-not-found || true
kubectl delete namespace monitoring --ignore-not-found

echo "Incident lab resources removed."
