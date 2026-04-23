#!/usr/bin/env bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n== %s ==\n' "$1"
}

port_status() {
  local name="$1"
  local port="$2"
  local url="$3"

  if ss -ltn "sport = :${port}" | grep -q LISTEN; then
    printf "%-10s localhost:%s listening  %s\n" "${name}:" "${port}" "${url}"
  else
    printf "%-10s localhost:%s not listening  run: scripts/port-forward.sh\n" "${name}:" "${port}"
  fi
}

section "Tools"
for tool in kubectl helm curl ss; do
  if command_exists "${tool}"; then
    printf "%-10s %s\n" "${tool}:" "$(command -v "${tool}")"
  else
    printf "%-10s missing\n" "${tool}:"
  fi
done

if command_exists minikube; then
  printf "%-10s %s\n" "minikube:" "$(command -v minikube)"
else
  printf "%-10s missing\n" "minikube:"
fi

section "Minikube"
if command_exists minikube; then
  minikube status || true
else
  echo "minikube is not installed or not on PATH."
fi

section "Kubernetes API"
if kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl can reach the Kubernetes API."
  kubectl get nodes -o wide
else
  echo "kubectl cannot reach the Kubernetes API."
  echo "If you use minikube, run: minikube start"
  exit 1
fi

section "Podinfo"
if kubectl get namespace incident-lab >/dev/null 2>&1; then
  kubectl -n incident-lab get deploy,pods,svc
else
  echo "Namespace incident-lab is missing. Run: scripts/deploy-app.sh"
fi

section "Monitoring"
if kubectl get namespace monitoring >/dev/null 2>&1; then
  kubectl -n monitoring get pods,svc
else
  echo "Namespace monitoring is missing. Run: scripts/install-monitoring.sh"
fi

section "Local Web Access"
port_status "Grafana" "3000" "http://localhost:3000"
port_status "Podinfo" "9898" "http://localhost:9898"

section "Useful Commands"
cat <<'EOF'
Open local web access:
  scripts/port-forward.sh

Grafana login:
  admin / admin

Trigger scenarios:
  scripts/trigger-readiness-failure.sh
  scripts/generate-errors.sh
  scripts/trigger-pod-self-healing.sh
EOF
