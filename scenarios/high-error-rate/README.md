# Scenario: High Error Rate

## Goal

Generate HTTP `500` responses while Kubernetes still considers the workload healthy.

This scenario teaches an important incident pattern:

```text
Pods are Running and Ready, but the application is returning errors.
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

Run a short burst of failing requests:

```bash
scripts/generate-errors.sh
```

The script opens a temporary port-forward to Podinfo and calls:

```text
/status/500
```

## Expected Kubernetes Signal

The pods should remain healthy:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
```

Expected:

```text
podinfo-...   1/1   Running
```

This is the point of the scenario: Kubernetes readiness does not necessarily mean the app is error-free.

## Expected Grafana Signal

In `Incident Lab / Podinfo Overview`:

- **Request Rate** increases.
- **Error Ratio** rises above `0`.
- **Ready Replicas** stays at `2`.
- **Unready Pods** stays at `0`.
- **Unavailable Replicas** stays at `0`.

## Expected Loki Signal

Open **Explore**, choose **Loki**, and query:

```logql
{namespace="incident-lab"} |= "500"
```

If this is too narrow, start with:

```logql
{namespace="incident-lab"}
```

Then inspect labels or log lines for Podinfo.

## Restore

Stop the generator:

```text
Ctrl+C
```

No Kubernetes change is required.

## Validation

After the generator stops:

- **Error Ratio** should return toward `0`.
- **Request Rate** should drop back to normal.
- Pods should still be `1/1 Running`.

```bash
kubectl -n incident-lab get pods
```

## Common Confusion

It is normal for Kubernetes to look healthy during this incident.

This scenario is an application-level failure, not an infrastructure-level failure. Use Grafana and Loki to see the error behavior.
