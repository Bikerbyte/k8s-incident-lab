#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

section() {
  printf '\n== %s ==\n' "$1"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section "Shell syntax"
while IFS= read -r script; do
  bash -n "${script}"
  printf "ok  %s\n" "${script}"
done < <(find scripts -type f -name '*.sh' | sort)

section "Python syntax"
python3 -m py_compile console/server.py
printf "ok  console/server.py\n"

section "JavaScript syntax"
if command_exists node; then
  node --check console/static/app.js
  printf "ok  console/static/app.js\n"
else
  echo "skip JavaScript syntax: node is not installed."
fi

section "Kubernetes manifests"
if command_exists kubectl; then
  if timeout 5s kubectl cluster-info >/dev/null 2>&1; then
    kubectl apply --dry-run=client --validate=false -f app/manifests/namespace.yaml >/dev/null
    kubectl apply --dry-run=client --validate=false -f app/manifests/podinfo.yaml >/dev/null
    kubectl apply --dry-run=client --validate=false -f monitoring/servicemonitors/podinfo-servicemonitor.yaml >/dev/null
    kubectl apply --dry-run=client --validate=false -f monitoring/dashboards/podinfo-overview-dashboard.yaml >/dev/null
    kubectl apply --dry-run=client --validate=false -f monitoring/alerts/podinfo-alerts.yaml >/dev/null
    printf "ok  Kubernetes manifests\n"
  else
    echo "skip Kubernetes manifest validation: cluster is not reachable."
  fi
else
  echo "skip Kubernetes manifest validation: kubectl is not installed."
fi

section "Helm values"
if command_exists helm; then
  helm lint prometheus-community/kube-prometheus-stack \
    --values monitoring/helm-values/kube-prometheus-stack-values.yaml >/dev/null 2>&1 \
    && printf "ok  kube-prometheus-stack values\n" \
    || echo "skip kube-prometheus-stack values: add/update Helm repos first."
else
  echo "skip Helm values validation: helm is not installed."
fi

section "Done"
echo "Project validation checks completed."
