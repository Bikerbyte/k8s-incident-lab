# Runbook: Readiness Probe Failure

## Symptoms

- Pod is `Running` but not `Ready`.
- Service endpoints are missing or reduced.
- Requests through the Service fail or stop routing to the affected pods.
- Grafana shows ready replicas dropping.

## Where to Look

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab logs deploy/podinfo --tail=100
```

Grafana:

- Dashboard: `Incident Lab / Podinfo Overview`
- Loki query: `{namespace="incident-lab"}`

## Possible Cause

- Readiness probe path is wrong.
- The app's readiness endpoint is returning non-200 responses.
- The app is overloaded or unable to reach a dependency required for readiness.

## Troubleshooting Steps

1. Check pod readiness with `kubectl get pods`.
2. Inspect events with `kubectl describe pod`.
3. Confirm whether the Service has ready endpoints.
4. Check app logs for health-check failures.
5. Compare the Deployment readiness probe path with the app's real endpoint.

## Resolution

Restore the readiness probe path to `/readyz`:

```bash
scripts/restore-readiness.sh
```

## Validation

```bash
kubectl -n incident-lab rollout status deploy/podinfo
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
```

Confirm Grafana shows ready replicas returning to the desired count.
