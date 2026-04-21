# Scenarios

The MVP contains three repeatable incident scenarios.

## Readiness Probe Failure

Purpose:

Show that a pod can be running but removed from Service traffic because readiness checks fail.

Trigger:

```bash
scripts/trigger-readiness-failure.sh
```

Primary signals:

- Pod ready state
- Service endpoints
- Kubernetes events
- Ready replicas in Grafana

Runbook:

- [Readiness Probe Failure](../runbooks/readiness-failure.md)

## High Error Rate

Purpose:

Show that an app can remain healthy at the Kubernetes level while returning HTTP 500 responses.

Trigger:

```bash
scripts/generate-errors.sh
```

Primary signals:

- Request rate
- Error ratio
- App logs in Loki
- Pod status remains ready

Runbook:

- [High Error Rate](../runbooks/high-error-rate.md)

## Pod Self-healing

Purpose:

Show that the Deployment controller recreates a deleted pod.

Trigger:

```bash
scripts/trigger-pod-self-healing.sh
```

Primary signals:

- Pod lifecycle events
- Replacement pod creation
- Deployment ready replicas

Runbook:

- [Pod Self-healing](../runbooks/pod-self-healing.md)
