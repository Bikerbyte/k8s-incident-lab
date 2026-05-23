# Runbook: OOMKilled

## Symptoms

- Pod status cycles through `OOMKilled` → `CrashLoopBackOff`.
- Exit code is `137` in `kubectl describe pod`.
- **Pod Restarts** rises in Grafana.
- `PodinfoFrequentOOMKills` alert firing in Prometheus.

## Where to Look

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Look for:

```text
Last State: Terminated
  Reason:    OOMKilled
  Exit Code: 137
```

In Grafana:

- Dashboard: `Incident Lab / Podinfo Overview`
- Panel: `Pod Restarts`

In Prometheus:

```text
kube_pod_container_status_last_terminated_reason{namespace="incident-lab", reason="OOMKilled"}
container_memory_working_set_bytes{namespace="incident-lab", container="podinfo"}
```

## Distinguishing OOMKilled from an Application Crash

| Signal | OOMKilled | App crash |
|---|---|---|
| Exit code | 137 (128 + SIGKILL) | App-defined (1, 2, non-zero) |
| `reason` in describe | `OOMKilled` | `Error` or `Completed` |
| Kernel involvement | Yes — Linux OOM killer | No — process exits on its own |
| App logs before termination | Often none (killed mid-execution) | Usually present |

If `kubectl describe pod` shows `Reason: OOMKilled`, the kernel killed the process — not the app itself. Application crashes show a different exit code and often leave log output.

## Requests vs Limits

| Field | What it does |
|---|---|
| `resources.requests.memory` | Scheduler uses this to find a node with enough memory. Does not enforce a cap. |
| `resources.limits.memory` | Hard ceiling. If the container exceeds this, the OOM killer terminates it. |

A pod with no `limits` can grow until it starves the node. A pod with a `limits` too low will OOMKill repeatedly.

## Investigate Memory Usage

Check live usage with `kubectl top`:

```bash
kubectl -n incident-lab top pod -l app.kubernetes.io/name=podinfo --containers
```

Query the working set in Prometheus:

```text
container_memory_working_set_bytes{namespace="incident-lab", container="podinfo"}
```

Working set memory = RSS + file-backed pages. This is the figure Kubernetes compares against `limits.memory`.

Compare the current working set to the configured limit:

```bash
kubectl -n incident-lab get pod -l app.kubernetes.io/name=podinfo \
  -o jsonpath='{.items[0].spec.containers[0].resources.limits.memory}'
```

## When to Raise the Limit vs Find a Memory Leak

**Raise the limit** if:
- Memory usage is stable and predictable (e.g. JVM heap, buffer cache).
- The limit was set too conservatively and usage is within expected range for the workload.

**Investigate for a memory leak** if:
- Memory usage grows continuously without stabilizing.
- Usage climbs after specific operations (load spikes, batch jobs, specific API calls).
- The container ran for hours before OOMKilling, not immediately on startup.

A leak is characterized by unbounded growth over time. A misconfigured limit is characterized by the container failing almost immediately after startup or under predictable load.

## Resolution

In this lab scenario, the trigger set an artificially low limit. Restore it:

```bash
scripts/restore-oom-killed.sh
```

In a real incident, find the appropriate limit from historical data and update the Deployment manifest:

```yaml
resources:
  requests:
    memory: 64Mi
  limits:
    memory: 128Mi
```

## Validation

```bash
kubectl -n incident-lab rollout status deploy/podinfo
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
```

Confirm:

- All pods are `1/1 Running`.
- `Last State` no longer shows `OOMKilled`.
- `Pod Restarts` stabilizes in Grafana.
- `PodinfoFrequentOOMKills` alert clears in Prometheus.
