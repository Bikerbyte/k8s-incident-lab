# K8s Incident Lab

A lightweight Kubernetes incident lab built on K3s for practicing deployment, observability, troubleshooting, and runbook-driven incident response.

This project is an SRE-style playground. The goal is not to write a large application. The goal is to deploy a small service, observe it, break it in realistic ways, and document how to investigate and recover it.

## What This Demonstrates

- Kubernetes workload deployment with `Deployment`, `Service`, and `Namespace`
- Metrics collection with Prometheus
- Dashboards with Grafana
- Centralized logs with Loki and Promtail
- Repeatable incident scenarios
- Runbooks for troubleshooting and validation

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

On Windows PowerShell, use the matching `.ps1` scripts:

```powershell
.\scripts\deploy-app.ps1
.\scripts\install-monitoring.ps1
```

Open Grafana:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000`.

Default login:

```text
admin / admin
```

Open the dashboard:

```text
Incident Lab / Podinfo Overview
```

## Validate the App

Port-forward Podinfo:

```bash
kubectl -n incident-lab port-forward svc/podinfo 9898:9898
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
- [x] Loki / Promtail Helm values
- [x] Grafana dashboard ConfigMap
- [x] Readiness failure scenario
- [x] High error rate scenario
- [x] Pod self-healing scenario
- [x] Runbooks
- [x] Helper scripts
- [ ] Screenshots from a real cluster run

## Future Improvements

- Alertmanager rules
- Ingress and TLS
- GitHub Actions validation
- More detailed Grafana dashboard panels
- Optional custom API service for richer failure modes
