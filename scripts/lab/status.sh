#!/usr/bin/env bash
set -euo pipefail

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

kctl() {
  if command_exists timeout; then
    timeout 20s kubectl "$@"
  else
    kubectl "$@"
  fi
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
    printf "%-10s localhost:%s not listening  run: scripts/lab.sh access\n" "${name}:" "${port}"
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
CLUSTER_OK=0
if kctl cluster-info >/dev/null 2>&1; then
  echo "kubectl can reach the Kubernetes API."
  kctl get nodes -o wide
  CLUSTER_OK=1
else
  echo "kubectl cannot reach the Kubernetes API."
  echo "If you use minikube, run: minikube start"
fi

section "Podinfo"
if [ "${CLUSTER_OK}" -eq 0 ]; then
  echo "Skipped because the Kubernetes API is not reachable."
elif kctl get namespace incident-lab >/dev/null 2>&1; then
  kctl -n incident-lab get deploy,pods,svc
else
  echo "Namespace incident-lab is missing. Run: scripts/lab.sh deploy"
fi

section "Monitoring"
if [ "${CLUSTER_OK}" -eq 0 ]; then
  echo "Skipped because the Kubernetes API is not reachable."
elif kctl get namespace monitoring >/dev/null 2>&1; then
  kctl -n monitoring get pods,svc
else
  echo "Namespace monitoring is missing. Run: scripts/lab.sh monitoring"
fi

section "Local Web Access"
port_status "Grafana" "3000" "http://localhost:3000"
port_status "Podinfo" "9898" "http://localhost:9898"
port_status "Prometheus" "9090" "http://localhost:9090"

section "Useful Commands"
cat <<'EOF'
Open local web access:
  scripts/lab.sh access

Stop local web access:
  scripts/lab.sh stop-access

Grafana login:
  admin / admin

Trigger scenarios:
  scripts/lab.sh scenario readiness trigger
  scripts/lab.sh scenario errors trigger
  scripts/lab.sh scenario self-healing trigger
  scripts/lab.sh scenario oom trigger
  scripts/lab.sh scenario service-discovery trigger
EOF

if [ "${CLUSTER_OK}" -eq 0 ]; then
  exit 1
fi
