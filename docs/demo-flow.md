# Demo Flow

Use this sequence when presenting the lab or practicing the scenarios end to end. The goal is to demonstrate Kubernetes troubleshooting, not just to run helper scripts.

## 1. Start the Lab

Confirm your Kubernetes environment is running, then deploy the app and observability stack:

```bash
scripts/lab.sh deploy
scripts/lab.sh monitoring
scripts/lab.sh access
```

Open the console:

```bash
scripts/lab.sh console
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
scripts/lab.sh alerts
```

In Grafana, open:

```text
Incident Lab / Podinfo Overview
```

The normal state should show ready replicas, no unready pods, and a low or zero error ratio.

## 3. Scenario: Pod Self-Healing

Create the failure:

```bash
scripts/lab.sh scenario self-healing trigger
```

Narrative:

- A pod disappears.
- The Deployment controller notices actual state no longer matches desired state.
- Kubernetes creates a replacement pod.
- Ready replicas return to normal.

Evidence:

```bash
kubectl -n incident-lab get pods -w
kubectl -n incident-lab get rs
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Kubernetes point:

The Deployment controller owns desired state. A deleted Pod is replaced because the current state no longer matches the replica count.

## 4. Scenario: Readiness Failure

Create the failure:

```bash
scripts/lab.sh scenario readiness trigger
```

Narrative:

- The new pod is running, but its readiness probe is wrong.
- Kubernetes keeps it out of Service endpoints.
- The rollout stalls while older ready pods continue serving traffic.

Evidence:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab get events --sort-by=.lastTimestamp
```

Kubernetes point:

A Pod can be Running but not Ready. Services route only to ready Endpoints.

Restore:

```bash
scripts/lab.sh scenario readiness restore
```

## 5. Scenario: High Error Rate

Create the failure:

```bash
scripts/lab.sh scenario errors trigger
```

Narrative:

- Kubernetes still sees healthy pods.
- The application is returning HTTP 500s.
- Metrics and logs are the strongest signals.

Evidence:

- `kubectl -n incident-lab get pods`
- `kubectl -n incident-lab logs deploy/podinfo --tail=100`
- Grafana `Error Ratio`
- Grafana `Request Rate`
- Loki query: `{namespace="incident-lab"} |= "500"`
- Prometheus alert: `PodinfoHighErrorRate`

Kubernetes point:

Healthy Pods do not guarantee healthy user experience. Application metrics and logs prove failures that Kubernetes readiness does not catch.

## 6. Scenario: OOMKilled

Create the failure:

```bash
scripts/lab.sh scenario oom trigger
```

Narrative:

- Podinfo gets an unrealistically low memory limit.
- The container is killed by the kernel when it exceeds the limit.
- Kubernetes restarts the container and records the last termination reason.

Evidence:

```bash
kubectl -n incident-lab get pods -w
kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo
kubectl -n incident-lab get deploy podinfo -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

Kubernetes point:

OOMKilled is a resource limit failure. Exit code 137, last state, restart count, and memory limits should be read together.

Restore:

```bash
scripts/lab.sh scenario oom restore
```

## 7. Scenario: Service Discovery Broken

Create the failure:

```bash
scripts/lab.sh scenario service-discovery trigger
```

Narrative:

- Pods are healthy and Ready.
- The Service selector no longer matches Pod labels.
- The Service has no Endpoints, so traffic cannot reach the Pods.

Evidence:

```bash
kubectl -n incident-lab get pods --show-labels
kubectl -n incident-lab describe svc podinfo
kubectl -n incident-lab get endpoints podinfo
curl http://localhost:9898/
```

Kubernetes point:

Services route through label-selected Endpoints. Selector drift can break traffic without breaking Pods.

Restore:

```bash
scripts/lab.sh scenario service-discovery restore
```

## 8. Wrap Up

Run:

```bash
scripts/lab.sh status
```

Optional cleanup:

```bash
scripts/lab.sh cleanup
```

## Presenter Notes

- Start with the console for orientation, then move into Grafana when the question becomes metric-driven.
- Use Kubernetes events for readiness failures because the app may not log useful probe errors.
- Use logs and error ratio for high error rate because Kubernetes readiness can remain healthy.
- Point out that self-healing is reconciliation, not magic: the Deployment owns desired state.
- Use OOMKilled to connect resource limits with runtime behavior.
- Use Service Discovery Broken to show how selectors, labels, and Endpoints form the traffic path.
