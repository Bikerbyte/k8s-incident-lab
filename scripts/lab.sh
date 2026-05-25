#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage:
  scripts/lab.sh deploy
  scripts/lab.sh monitoring
  scripts/lab.sh access
  scripts/lab.sh stop-access
  scripts/lab.sh status
  scripts/lab.sh alerts
  scripts/lab.sh console
  scripts/lab.sh cleanup
  scripts/lab.sh validate
  scripts/lab.sh screenshot [output-path]

  scripts/lab.sh scenario readiness trigger
  scripts/lab.sh scenario readiness restore
  scripts/lab.sh scenario errors trigger
  scripts/lab.sh scenario self-healing trigger
  scripts/lab.sh scenario oom trigger
  scripts/lab.sh scenario oom restore
  scripts/lab.sh scenario service-discovery trigger
  scripts/lab.sh scenario service-discovery restore

Aliases:
  mon       monitoring
  pf        access
  stop      stop-access
  st        status
  ui        console
  sc        scenario
  svc       service-discovery
EOF
}

run_script() {
  local script="$1"
  shift
  exec "${SCRIPT_DIR}/${script}" "$@"
}

command="${1:-help}"
case "${command}" in
  help|-h|--help)
    usage
    ;;
  deploy)
    shift
    run_script "lab/deploy-app.sh" "$@"
    ;;
  monitoring|mon)
    shift
    run_script "lab/install-monitoring.sh" "$@"
    ;;
  access|pf)
    shift
    run_script "lab/port-forward.sh" "$@"
    ;;
  stop-access|stop)
    shift
    run_script "lab/stop-port-forward.sh" "$@"
    ;;
  status|st)
    shift
    run_script "lab/status.sh" "$@"
    ;;
  alerts)
    shift
    run_script "lab/show-alerts.sh" "$@"
    ;;
  console|ui)
    shift
    run_script "lab/run-console.sh" "$@"
    ;;
  cleanup)
    shift
    run_script "lab/cleanup.sh" "$@"
    ;;
  validate)
    shift
    run_script "tools/validate.sh" "$@"
    ;;
  screenshot)
    shift
    run_script "tools/capture-grafana-screenshot.sh" "$@"
    ;;
  scenario|sc)
    shift
    scenario="${1:-help}"
    action="${2:-help}"
    shift 2 2>/dev/null || true
    case "${scenario}:${action}" in
      help:*|*:help|-h:*|--help:*)
        usage
        ;;
      readiness:trigger)
        run_script "scenarios/trigger-readiness-failure.sh" "$@"
        ;;
      readiness:restore)
        run_script "scenarios/restore-readiness.sh" "$@"
        ;;
      errors:trigger|error-rate:trigger|high-error-rate:trigger)
        run_script "scenarios/generate-errors.sh" "$@"
        ;;
      self-healing:trigger|self:trigger)
        run_script "scenarios/trigger-pod-self-healing.sh" "$@"
        ;;
      oom:trigger|oom-killed:trigger)
        run_script "scenarios/trigger-oom-killed.sh" "$@"
        ;;
      oom:restore|oom-killed:restore)
        run_script "scenarios/restore-oom-killed.sh" "$@"
        ;;
      service-discovery:trigger|svc:trigger)
        run_script "scenarios/trigger-service-discovery-broken.sh" "$@"
        ;;
      service-discovery:restore|svc:restore)
        run_script "scenarios/restore-service-discovery-broken.sh" "$@"
        ;;
      *)
        echo "Unknown scenario command: ${scenario} ${action}" >&2
        echo >&2
        usage >&2
        exit 2
        ;;
    esac
    ;;
  *)
    echo "Unknown command: ${command}" >&2
    echo >&2
    usage >&2
    exit 2
    ;;
esac
