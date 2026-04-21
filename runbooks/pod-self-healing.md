# Runbook: Pod Self-healing

## Symptoms

- A pod is deleted or disappears.
- A new pod is created automatically.
- The Deployment eventually returns to the desired replica count.

## Where to Look

```bash
kubectl -n incident-lab get pods -w
kubectl -n incident-lab get deploy podinfo
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Grafana:

- Dashboard: `Incident Lab / Podinfo Overview`

## Possible Cause

- Manual pod deletion.
- Node disruption.
- Container crash or eviction.

## Troubleshooting Steps

1. Confirm the Deployment desired replica count.
2. Watch pod lifecycle events.
3. Confirm the replacement pod becomes ready.
4. Check whether the Service still has ready endpoints.
5. Review restart and event history if replacement fails.

## Resolution

No action is needed if the Deployment replaces the pod successfully.

If replacement fails, inspect scheduling events, image pull status, resource pressure, and probe failures.

## Validation

```bash
kubectl -n incident-lab rollout status deploy/podinfo
kubectl -n incident-lab get pods
```

Confirm the desired number of pods is ready.
