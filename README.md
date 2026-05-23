# K8s Incident Lab

This project simulates production-grade incident response on Kubernetes. It demonstrates observability-driven debugging, runbook-driven recovery, and reproducible failure injection — the core daily work of an SRE.

Stack: K3s · Podinfo · Prometheus · Grafana · Loki · Promtail · Helm · kube-prometheus-stack.

![Grafana Podinfo Overview](docs/screenshots/grafana-normal.png)

## What This Demonstrates

| Capability | What I Built | Why It Matters in Production |
|---|---|---|
| Observability stack design | Prometheus + Grafana + Loki + Promtail, deployed via Helm | First-line evidence during any incident |
| Runbook-driven incident response | 5 reproducible failure scenarios with paired runbooks | Reduces MTTR and shortens on-call ramp-up |
| Metrics dashboard authoring | 9-panel Grafana dashboard covering replica health, error ratio, request rate, and restarts | Turns abstract failures into visible signals |
| Alert authoring | 5 PrometheusRule alerts with `for` duration thresholds and runbook links | Separates signal from noise |
| Self-service operator console | Browser-based console with 12 lab actions and real-time audit log | Lowers barrier for new SRE team members |
| Cross-platform automation | 7 operations scripted in both bash and PowerShell | Lab runs identically on Linux and Windows |

## Outcomes

- Codified 5 incident scenarios (readiness failure, high error rate, pod self-healing, OOMKilled, service discovery broken) into reproducible runbooks, each paired with trigger and restore scripts.
- Built a full observability stack (Prometheus + Grafana + Loki + Promtail) with 15-second metric scrape interval, deployable from a single Helm values file.
- Authored a 9-panel Grafana dashboard covering replica health, error ratio, request rate, and pod restarts — the key signals needed to diagnose each scenario.
- Wrote 5 PrometheusRule alerts with `for` duration thresholds and `runbook_url` annotations, reducing mean-time-to-detect from manual inspection.
- Built a 12-action browser console with real-time terminal output and per-job audit log, making the lab self-service for new team members.
- Maintained bash + PowerShell parity across all 7 core operations, making the lab reproducible on both Linux and Windows.

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

### 4. OOMKilled

```bash
scripts/trigger-oom-killed.sh
kubectl -n incident-lab get pods -w
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
```

Restore:

```bash
scripts/restore-oom-killed.sh
```

Runbook: [runbooks/oom-killed.md](runbooks/oom-killed.md)

### 5. Service Discovery Broken

```bash
scripts/trigger-service-discovery-broken.sh
kubectl -n incident-lab get endpoints podinfo
```

Restore:

```bash
scripts/restore-service-discovery-broken.sh
```

Runbook: [runbooks/service-discovery-broken.md](runbooks/service-discovery-broken.md)

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

- Alertmanager rules and notification routing
- Ingress and TLS
- GitHub Actions CI validation
- OOMKilled scenario
- Service discovery broken scenario
- SLO dashboard (availability SLI + error budget)
