#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Cannot connect to the Kubernetes API server."
  echo "If you are using minikube, start it first:"
  echo "  minikube start"
  exit 1
fi

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "${REPO_ROOT}/monitoring/helm-values/kube-prometheus-stack-values.yaml"

helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values "${REPO_ROOT}/monitoring/helm-values/loki-values.yaml"

helm upgrade --install promtail grafana/promtail \
  --namespace monitoring \
  --values "${REPO_ROOT}/monitoring/helm-values/promtail-values.yaml"

kubectl -n monitoring rollout status deploy/kube-prometheus-stack-grafana
kubectl apply -f "${REPO_ROOT}/monitoring/servicemonitors/podinfo-servicemonitor.yaml"
kubectl apply -f "${REPO_ROOT}/monitoring/dashboards/podinfo-overview-dashboard.yaml"

echo "Monitoring stack installed."
echo "Open Grafana with:"
echo "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
echo "Login: admin / admin"
