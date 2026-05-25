# Scenario: Service Discovery Broken

## Goal

Simulate a broken Service selector that silently drops all traffic — while every pod remains healthy.

This scenario teaches:

```text
Healthy pods + existing Service != traffic reaching the app
```

The Service is in the cluster and the pods are running and Ready, but the selector no longer matches any pod labels. The Endpoints object becomes empty, so kube-proxy has no destination to forward traffic to.

## Before You Start

Check the lab:

```bash
scripts/lab.sh status
```

Open Grafana and Podinfo:

```bash
scripts/lab.sh access
```

Confirm Podinfo responds at `http://localhost:9898`.

## Trigger

```bash
scripts/lab.sh scenario service-discovery trigger
```

The script patches the podinfo Service selector from:

```text
app.kubernetes.io/name: podinfo
```

to:

```text
app.kubernetes.io/name: podinfo-typo
```

No pods carry this label, so the Endpoints object is immediately cleared.

## Expected Kubernetes Signal

```bash
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab describe svc podinfo
kubectl -n incident-lab get pods
```

Typical endpoint state after trigger:

```text
NAME      ENDPOINTS   AGE
podinfo   <none>      5m
```

Pod state is unchanged — all pods remain `1/1 Running`:

```text
NAME                  READY   STATUS    RESTARTS
podinfo-xxx           1/1     Running   0
podinfo-xxx           1/1     Running   0
```

This is the critical insight: **all pod-level health checks pass**, but traffic cannot reach them.

## Expected Grafana Signal

In `Incident Lab / Podinfo Overview`:

- **Ready Service Endpoints** drops to `0`.
- **Ready Replicas** and **Unready Pods** remain unchanged (pods are still healthy).
- **Request Rate** drops to `0` if Podinfo is receiving external traffic.

The divergence between pod health (green) and endpoint count (0) is the key diagnostic signal.

## Expected Prometheus Alerts

Open:

```text
http://localhost:9090/alerts
```

After about 1 minute:

- `PodinfoServiceHasNoEndpoints` should fire.

You can also run:

```bash
scripts/lab.sh alerts
```

## Restore

```bash
scripts/lab.sh scenario service-discovery restore
```

## Validation

```bash
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab describe svc podinfo
```

Expected:

```text
NAME      ENDPOINTS                     AGE
podinfo   10.x.x.x:9898,10.x.x.x:9898  5m
```

Confirm `http://localhost:9898` responds again.
