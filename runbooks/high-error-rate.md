# Runbook: High Error Rate

## Symptoms

- Pod remains `Running` and `Ready`.
- Request volume continues.
- 5xx responses increase.
- Grafana error ratio rises.

## Where to Look

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab logs deploy/podinfo --tail=100
```

Grafana:

- Dashboard: `Incident Lab / Podinfo Overview`
- Loki query: `{namespace="incident-lab"}`
- Prometheus alert: `PodinfoHighErrorRate`

## Possible Cause

- A failing endpoint is being called.
- A dependency is returning errors.
- A bad configuration or release changed app behavior.

## Troubleshooting Steps

1. Confirm pods are still ready.
2. Check request and error panels in Grafana.
3. Check Prometheus alerts at `http://localhost:9090/alerts`.
4. Use Loki to inspect recent application logs.
5. Identify which route or client is generating 5xx responses.
6. Stop the failing traffic source or roll back the bad change.

## Resolution

For this lab scenario, stop the error generator:

```bash
Ctrl+C
```

No Kubernetes deployment change is required.

## Validation

- Error ratio returns toward zero.
- Logs stop showing repeated 500 responses.
- Pods remain healthy.
