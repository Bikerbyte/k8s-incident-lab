# Scenario: Readiness Probe Failure

This scenario simulates a pod that is still running but no longer ready to receive traffic.

## Trigger

```bash
scripts/trigger-readiness-failure.sh
```

The script patches the Podinfo readiness probe to an invalid path.

## Observe

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
kubectl -n incident-lab get endpoints podinfo
```

Expected signals:

- Pods move to `0/1` ready.
- The Service has no ready endpoints.
- Grafana shows ready replicas dropping.
- Pod logs and Kubernetes events show readiness probe failures.

## Restore

```bash
scripts/restore-readiness.sh
```
