# Scenario: Readiness Probe Failure

## Goal

Simulate a rollout where a new pod is running but cannot become Ready.

This scenario teaches the difference between:

```text
Running container != Ready pod != Service endpoint
```

## Before You Start

Check the lab:

```bash
scripts/status.sh
```

Open Grafana and Podinfo:

```bash
scripts/port-forward.sh
```

In Grafana, open:

```text
Incident Lab / Podinfo Overview
```

## Trigger

```bash
scripts/trigger-readiness-failure.sh
```

The script patches the Podinfo readiness probe from:

```text
/readyz
```

to:

```text
/broken-readyz
```

The rollout timeout is expected. The new pod cannot become Ready.

## Expected Kubernetes Signal

Check pods and endpoints:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Typical pod state:

```text
podinfo-old   1/1   Running
podinfo-old   1/1   Running
podinfo-new   0/1   Running
```

Typical event:

```text
Readiness probe failed: HTTP probe failed with statuscode: 404
```

The Service endpoints may still show the old ready pods. That means traffic can still be served while the rollout is stuck.

## Expected Grafana Signal

In `Incident Lab / Podinfo Overview`:

- **Unready Pods** becomes `1`.
- **Unavailable Replicas** becomes `1`.
- **Ready Replicas** may stay at `2` if the old pods remain ready.
- **Ready Service Endpoints** may stay at `2`.
- **Deployment Replica State** shows total replicas higher than ready replicas.

This is why `Unready Pods` and `Unavailable Replicas` are the most useful panels for this scenario.

## Expected Loki Signal

Loki may not show a clear error for this scenario.

Readiness probe failures are primarily Kubernetes events from kubelet. Podinfo does not always write a useful application log for a failing readiness probe.

Use Kubernetes events as the primary evidence:

```bash
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

## Restore

```bash
scripts/restore-readiness.sh
```

## Validation

Check:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get deploy podinfo
kubectl -n incident-lab get endpoints podinfo
```

Expected:

```text
2 pods are 1/1 Running
deployment podinfo is 2/2 available
Unready Pods returns to 0 in Grafana
```

## Common Confusion

If **Ready Replicas** stays at `2`, the scenario can still be working.

That means the old ReplicaSet is still serving traffic while the new ReplicaSet is stuck. Look at **Unready Pods**, **Unavailable Replicas**, and Kubernetes events.
