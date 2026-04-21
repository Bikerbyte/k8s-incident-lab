# Architecture

The lab uses a small Kubernetes workload and a basic observability stack.

## Components

- `Podinfo` runs in the `incident-lab` namespace.
- `Prometheus` scrapes workload and cluster metrics.
- `Grafana` displays app and workload health.
- `Loki` stores centralized logs.
- `Promtail` collects pod logs and sends them to Loki.

## Flow

```text
User / curl
  -> Kubernetes Service
  -> Podinfo pods
  -> metrics scraped by Prometheus
  -> logs collected by Promtail
  -> Grafana dashboards and Loki queries
```

## Namespaces

- `incident-lab`: demo app and incident targets
- `monitoring`: Prometheus, Grafana, Loki, and Promtail

## Design Notes

This MVP intentionally avoids custom application code. Podinfo already exposes HTTP endpoints, health checks, logs, and metrics, which keeps the project focused on SRE workflows instead of application development.
