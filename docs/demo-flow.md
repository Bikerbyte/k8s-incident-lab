# Demo Flow

Use this sequence when presenting the lab or practicing the scenarios end to end.

## 1. Start the Lab

Confirm your Kubernetes environment is running, then deploy the app and observability stack:

```bash
scripts/deploy-app.sh
scripts/install-monitoring.sh
scripts/port-forward.sh
```

Open the console:

```bash
scripts/run-console.sh
```

Browser entry points:

- Lab Console: `http://127.0.0.1:8787` or the URL printed by the script
- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`
- Podinfo: `http://localhost:9898`

Grafana login:

```text
admin / admin
```

## 2. Establish Normal State

In the console, confirm:

- Minikube or Kubernetes API is reachable.
- Podinfo pods are ready.
- Monitoring pods are healthy.
- Grafana, Prometheus, and Podinfo local access are open.

Check Prometheus alerts:

```bash
scripts/show-alerts.sh
```

In Grafana, open:

```text
Incident Lab / Podinfo Overview
```

The normal state should show ready replicas, no unready pods, and a low or zero error ratio.

## 3. Scenario: Pod Self-Healing

Run:

```bash
scripts/trigger-pod-self-healing.sh
```

Narrative:

- A pod disappears.
- The Deployment controller notices actual state no longer matches desired state.
- Kubernetes creates a replacement pod.
- Ready replicas return to normal.

Evidence:

```bash
kubectl -n incident-lab get pods -w
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

## 4. Scenario: Readiness Failure

Run:

```bash
scripts/trigger-readiness-failure.sh
```

Narrative:

- The new pod is running, but its readiness probe is wrong.
- Kubernetes keeps it out of Service endpoints.
- The rollout stalls while older ready pods continue serving traffic.

Evidence:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Restore:

```bash
scripts/restore-readiness.sh
```

## 5. Scenario: High Error Rate

Run:

```bash
scripts/generate-errors.sh
```

Narrative:

- Kubernetes still sees healthy pods.
- The application is returning HTTP 500s.
- Metrics and logs are the strongest signals.

Evidence:

- Grafana `Error Ratio`
- Grafana `Request Rate`
- Loki query: `{namespace="incident-lab"} |= "500"`
- Prometheus alert: `PodinfoHighErrorRate`

## 6. Wrap Up

Run:

```bash
scripts/status.sh
```

Optional cleanup:

```bash
scripts/cleanup.sh
```

## Presenter Notes

- Start with the console for orientation, then move into Grafana when the question becomes metric-driven.
- Use Kubernetes events for readiness failures because the app may not log useful probe errors.
- Use logs and error ratio for high error rate because Kubernetes readiness can remain healthy.
- Point out that self-healing is reconciliation, not magic: the Deployment owns desired state.
