#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/k8s-incident-lab"
mkdir -p "${STATE_DIR}"

is_listening() {
  local port="$1"
  ss -ltn "sport = :${port}" | grep -q LISTEN
}

start_forward() {
  local name="$1"
  local namespace="$2"
  local service="$3"
  local local_port="$4"
  local remote_port="$5"
  local log_file="${STATE_DIR}/${name}.log"
  local pid_file="${STATE_DIR}/${name}.pid"

  if is_listening "${local_port}"; then
    echo "${name}: localhost:${local_port} is already listening."
    return
  fi

  echo "Starting ${name}: localhost:${local_port} -> ${namespace}/${service}:${remote_port}"
  kubectl -n "${namespace}" port-forward "svc/${service}" "${local_port}:${remote_port}" >"${log_file}" 2>&1 &
  echo "$!" >"${pid_file}"

  sleep 2

  if is_listening "${local_port}"; then
    echo "${name}: ready at http://localhost:${local_port}"
  else
    echo "${name}: failed to start. Log: ${log_file}"
    return 1
  fi
}

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Cannot connect to the Kubernetes API server."
  echo "If you are using minikube, start it first:"
  echo "  minikube start"
  exit 1
fi

start_forward "grafana" "monitoring" "kube-prometheus-stack-grafana" "3000" "80"
start_forward "podinfo" "incident-lab" "podinfo" "9898" "9898"

cat <<'EOF'

Open:
  Grafana: http://localhost:3000
  Podinfo: http://localhost:9898

Grafana login:
  admin / admin

To stop the port-forwards:
  pkill -f 'kubectl.*port-forward.*kube-prometheus-stack-grafana'
  pkill -f 'kubectl.*port-forward.*podinfo'
EOF
