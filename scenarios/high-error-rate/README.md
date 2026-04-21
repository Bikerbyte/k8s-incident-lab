# Scenario: High Error Rate

This scenario generates HTTP 500 responses while the workload remains healthy.

## Trigger

Run a short burst of failing requests:

```bash
scripts/generate-errors.sh
```

The script port-forwards the Podinfo service and calls `/status/500`.

## Observe

```bash
kubectl -n incident-lab logs deploy/podinfo --tail=100
```

In Grafana:

- Open `Incident Lab / Podinfo Overview`.
- Watch request rate and error ratio.
- Use Explore with the Loki datasource.
- Query logs for the `incident-lab` namespace.

## Restore

Stop generating failing requests. No Kubernetes change is required.
