#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/k8s-incident-lab"

stop_by_pid_file() {
  local name="$1"
  local pid_file="${STATE_DIR}/${name}.pid"

  if [ ! -f "${pid_file}" ]; then
    return
  fi

  local pid
  pid="$(cat "${pid_file}")"
  if [ -n "${pid}" ] && kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
    echo "Stopped ${name} port-forward."
  fi
  rm -f "${pid_file}"
}

mkdir -p "${STATE_DIR}"

stop_by_pid_file "grafana"
stop_by_pid_file "podinfo"
stop_by_pid_file "prometheus"

pkill -f 'kubectl.*port-forward.*kube-prometheus-stack-grafana' >/dev/null 2>&1 || true
pkill -f 'kubectl.*port-forward.*podinfo' >/dev/null 2>&1 || true
pkill -f 'kubectl.*port-forward.*kube-prometheus-stack-prometheus' >/dev/null 2>&1 || true

echo "Local port-forwards stopped."
