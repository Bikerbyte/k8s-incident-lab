# Scenario: Pod Self-healing

This scenario demonstrates how the Deployment controller replaces a deleted pod.

## Trigger

```bash
scripts/trigger-pod-self-healing.sh
```

The script deletes one Podinfo pod.

## Observe

```bash
kubectl -n incident-lab get pods -w
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Expected signals:

- One pod enters `Terminating`.
- A replacement pod is created.
- The Deployment returns to the desired replica count.
- Grafana may show a brief workload change.

## Restore

No manual restore is required. Kubernetes should create the replacement pod automatically.
