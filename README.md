# K8s Incident Lab

A lightweight Kubernetes incident lab built on K3s for practicing deployment, observability, troubleshooting, and runbook-driven incident response.

This project is an SRE-style playground. The goal is not to write a large application. The goal is to deploy a small service, observe it, break it in realistic ways, and document how to investigate and recover it.

## What This Demonstrates

- Kubernetes workload deployment with `Deployment`, `Service`, and `Namespace`
- Metrics collection with Prometheus
- Prometheus alert rules for incident signals
- Dashboards with Grafana
- Centralized logs with Loki and Promtail
- Repeatable incident scenarios
- Runbooks for troubleshooting and validation
- Browser-based lab console for local operation

## Stack

- K3s / Kubernetes
- Podinfo demo app
- Helm
- Prometheus via `kube-prometheus-stack`
- Grafana
- Loki
- Promtail

## Repository Structure

```text
k8s-incident-lab/
+-- app/
|   +-- manifests/
+-- docs/
|   +-- architecture.md
|   +-- scenarios.md
|   +-- screenshots/
+-- monitoring/
|   +-- dashboards/
|   +-- helm-values/
|   +-- servicemonitors/
+-- runbooks/
+-- scenarios/
+-- scripts/
+-- console/
```

## Prerequisites

- A working K3s or Kubernetes cluster
- `kubectl`
- `helm`
- `curl`

Confirm cluster access:

```bash
kubectl get nodes
```

## Quick Start

Deploy the demo app:

```bash
scripts/deploy-app.sh
```

Install monitoring and logging:

```bash
scripts/install-monitoring.sh
```

Check the lab status:

```bash
scripts/status.sh
```

Run the local lab console:

```bash
scripts/run-console.sh
```

Then open the printed local URL in your browser.

Common shortcuts are also available through `make`:

```bash
make deploy
make monitoring
make port-forward
make stop-port-forward
make console
make status
make alerts
```

On Windows PowerShell, use the matching `.ps1` scripts:

```powershell
.\scripts\deploy-app.ps1
.\scripts\install-monitoring.ps1
```

Open Grafana:

```bash
scripts/port-forward.sh
```

Then open:

```text
Grafana:    http://localhost:3000
Prometheus: http://localhost:9090
Podinfo:    http://localhost:9898
```

Stop local port-forwards:

```bash
scripts/stop-port-forward.sh
```

Default login:

```text
admin / admin
```

Open the dashboard:

```text
Incident Lab / Podinfo Overview
```

Grafana usage guide:

- [docs/grafana-guide.md](docs/grafana-guide.md)

Troubleshooting:

- [docs/troubleshooting.md](docs/troubleshooting.md)

Alerts:

- [docs/alerts.md](docs/alerts.md)

Demo flow:

- [docs/demo-flow.md](docs/demo-flow.md)

Screenshot guide:

- [docs/screenshots/README.md](docs/screenshots/README.md)

## Validate the App

Port-forward Podinfo:

```bash
scripts/port-forward.sh
```

Test it:

```bash
curl http://localhost:9898/
curl http://localhost:9898/readyz
curl http://localhost:9898/metrics
```

## Incident Scenarios

### 1. Readiness Probe Failure

```bash
scripts/trigger-readiness-failure.sh
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
```

Restore:

```bash
scripts/restore-readiness.sh
```

PowerShell equivalents are available under `scripts/*.ps1`.

Runbook: [runbooks/readiness-failure.md](runbooks/readiness-failure.md)

### 2. High Error Rate

```bash
scripts/generate-errors.sh
```

Watch Grafana request rate and error ratio, then inspect logs in Loki.

Runbook: [runbooks/high-error-rate.md](runbooks/high-error-rate.md)

### 3. Pod Self-healing

```bash
scripts/trigger-pod-self-healing.sh
kubectl -n incident-lab get pods -w
```

Runbook: [runbooks/pod-self-healing.md](runbooks/pod-self-healing.md)

## Useful Commands

Validate the repository:

```bash
scripts/validate.sh
```

Show Prometheus alerts:

```bash
scripts/show-alerts.sh
```

Check app state:

```bash
kubectl -n incident-lab get all
kubectl -n incident-lab describe deploy podinfo
kubectl -n incident-lab logs deploy/podinfo --tail=100
```

Check monitoring state:

```bash
kubectl -n monitoring get pods
kubectl -n monitoring get svc
```

Query recent events:

```bash
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

## Cleanup

```bash
scripts/cleanup.sh
```

## MVP Status

- [x] Demo app manifests
- [x] Prometheus / Grafana Helm values
- [x] Prometheus alert rules
- [x] Loki / Promtail Helm values
- [x] Grafana dashboard ConfigMap
- [x] Local lab console
- [x] Readiness failure scenario
- [x] High error rate scenario
- [x] Pod self-healing scenario
- [x] Runbooks
- [x] Helper scripts
- [x] Screenshots from a real cluster run

## Future Improvements

- Alertmanager rules
- Notification routing
- Ingress and TLS
- GitHub Actions validation
- More detailed Grafana dashboard panels
- Optional custom API service for richer failure modes
