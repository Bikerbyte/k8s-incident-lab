# Architecture

The lab uses a small Kubernetes workload and a compact observability stack. It is designed for local incident practice: deploy a real workload, expose it through local port-forwards, observe it with Grafana and Prometheus, then trigger controlled failures.

## Components

| Component | Namespace | Purpose |
| --- | --- | --- |
| Podinfo | `incident-lab` | Demo workload and incident target |
| ServiceMonitor | `monitoring` | Tells Prometheus how to scrape Podinfo metrics |
| Prometheus | `monitoring` | Stores workload and cluster metrics |
| PrometheusRule | `monitoring` | Defines scenario alert conditions |
| Grafana | `monitoring` | Displays dashboards and Explore views |
| Loki | `monitoring` | Stores centralized logs |
| Promtail | `monitoring` | Collects pod logs and ships them to Loki |
| Lab Console | local process | Browser control plane for scripts, status, screenshots, and docs |

## Traffic Flow

```text
User / curl
  -> Kubernetes Service
  -> Podinfo pods
  -> metrics scraped by Prometheus
  -> logs collected by Promtail
  -> Grafana dashboards and Loki queries
```

## Local Access Flow

The Kubernetes services stay internal to the cluster. Local browser access is created with `kubectl port-forward`:

```text
localhost:3000 -> monitoring/kube-prometheus-stack-grafana:80
localhost:9090 -> monitoring/kube-prometheus-stack-prometheus:9090
localhost:9898 -> incident-lab/podinfo:9898
```

Use:

```bash
scripts/lab.sh access
scripts/lab.sh stop-access
```

## Operational Flow

```text
scripts/lab.sh deploy
  -> apply namespace and Podinfo manifests

scripts/lab.sh monitoring
  -> install kube-prometheus-stack, Loki, and Promtail
  -> apply ServiceMonitor, Grafana dashboard ConfigMap, and PrometheusRule alerts

scripts/lab.sh console
  -> start the local browser console
  -> expose actions, status, docs, and screenshots
```

## Namespaces

- `incident-lab`: demo app and incident targets
- `monitoring`: Prometheus, Grafana, Loki, and Promtail

## Incident Paths

| Scenario | What changes | Main signal |
| --- | --- | --- |
| Readiness Probe Failure | Deployment readiness path is patched to a broken endpoint | Unready pod, unavailable replica, Kubernetes events, Prometheus alerts |
| High Error Rate | Podinfo receives repeated `/status/500` requests | Error ratio, request rate, Loki logs, Prometheus alert |
| Pod Self-Healing | One pod is deleted | Replacement pod lifecycle and ready replica recovery |

## Design Notes

This MVP intentionally avoids custom application code. Podinfo already exposes HTTP endpoints, health checks, logs, and metrics, which keeps the project focused on SRE workflows instead of application development.

The console is intentionally local-only and binds to `127.0.0.1`. It is a convenience layer over the existing scripts, not an in-cluster controller.
