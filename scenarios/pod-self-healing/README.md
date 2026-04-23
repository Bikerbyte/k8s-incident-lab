# Scenario: Pod Self-Healing

## Goal

Delete one Podinfo pod and observe the Deployment controller creating a replacement.

This scenario teaches the basic Kubernetes reconciliation loop:

```text
desired replicas = 2
actual replicas drops to 1
Deployment creates a replacement pod
actual replicas returns to 2
```

## Before You Start

Check the lab:

```bash
scripts/status.sh
```

Open Grafana:

```bash
scripts/port-forward.sh
```

In Grafana, open:

```text
Incident Lab / Podinfo Overview
```

## Trigger

```bash
scripts/trigger-pod-self-healing.sh
```

The script deletes one Podinfo pod.

## Expected Kubernetes Signal

Watch pods:

```bash
kubectl -n incident-lab get pods -w
```

Expected sequence:

```text
one old pod enters Terminating
a new pod is created
the new pod becomes 1/1 Running
```

Check events:

```bash
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Typical signals:

```text
Killing pod
SuccessfulCreate
Started container podinfo
```

## Expected Grafana Signal

In `Incident Lab / Podinfo Overview`:

- **Ready Replicas** may briefly dip, then return to `2`.
- **Unready Pods** may briefly become `1`, then return to `0`.
- **Ready Service Endpoints** may briefly change.
- **Pod Restarts** may not increase.

## Expected Loki Signal

Loki may show startup logs from the replacement pod:

```logql
{namespace="incident-lab", app="podinfo"}
```

If labels differ in your view, use:

```logql
{namespace="incident-lab"}
```

## Restore

No manual restore is required. Kubernetes should create the replacement pod automatically.

## Validation

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get deploy podinfo
```

Expected:

```text
2 pods are 1/1 Running
deployment podinfo is 2/2 available
```

## Common Confusion

Deleting a pod is not the same as a container crash.

Because the pod was deleted, **Pod Restarts** may not increase. Watch pod names, events, and ready replica counts instead.
