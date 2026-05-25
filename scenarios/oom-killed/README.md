# Scenario: OOMKilled

## Goal

Simulate a container being killed by the Linux kernel's Out-Of-Memory (OOM) killer due to exceeding its memory limit.

This scenario teaches:

```text
OOMKilled != app crash != readiness failure
```

The pod is not crashing — the kernel terminates it because it crossed a hard boundary set by the Kubernetes resource limit.

## Before You Start

Check the lab:

```bash
scripts/lab.sh status
```

Open Grafana and Podinfo:

```bash
scripts/lab.sh access
```

In Grafana, open:

```text
Incident Lab / Podinfo Overview
```

Note the current **Pod Restarts** value as your baseline.

## Trigger

```bash
scripts/lab.sh scenario oom trigger
```

The script sets the podinfo container memory limit to `15Mi`. Since podinfo's baseline memory use exceeds this, the container will be terminated by the OOM killer shortly after the new pod starts.

## Expected Kubernetes Signal

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
```

Typical pod state shortly after trigger:

```text
NAME                       READY   STATUS      RESTARTS   AGE
podinfo-xxx                0/1     OOMKilled   0          5s
podinfo-xxx                0/1     CrashLoopBackOff   1   15s
```

In `kubectl describe pod`:

```text
Last State: Terminated
  Reason: OOMKilled
  Exit Code: 137
```

Exit code 137 = 128 + 9 (SIGKILL). This distinguishes OOMKill from an application-level panic (which would show a non-zero exit code from the app itself, e.g. 1 or 2).

## Expected Grafana Signal

In `Incident Lab / Podinfo Overview`:

- **Pod Restarts** increases steadily as the container is killed and restarted.
- **Unready Pods** shows `1` while the pod is terminating or in CrashLoopBackOff.

## Expected Prometheus Alerts

Open:

```text
http://localhost:9090/alerts
```

Once the OOMKill occurs, this alert should fire:

- `PodinfoFrequentOOMKills`

You can also run:

```bash
scripts/lab.sh alerts
```

## Restore

```bash
scripts/lab.sh scenario oom restore
```

## Validation

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
```

Expected:

```text
2 pods are 1/1 Running
Last termination reason is no longer OOMKilled
Pod Restarts stabilizes in Grafana
```
