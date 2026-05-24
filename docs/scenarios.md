# Scenarios

The lab contains five repeatable incident scenarios. Each scenario has a short guide under `scenarios/` and a runbook under `runbooks/`.

The trigger scripts create consistent failures. The scenario value comes from the manual investigation path: compare Kubernetes objects, inspect Events and logs, connect metrics to symptoms, and validate recovery.

Before running any scenario:

```bash
scripts/status.sh
scripts/port-forward.sh
```

Open Grafana:

```text
http://localhost:3000
```

Dashboard:

```text
Incident Lab / Podinfo Overview
```

Prometheus alerts:

```text
http://localhost:9090/alerts
```

## Scenario Index

| Scenario | Kubernetes skill demonstrated | Manual evidence | Trigger |
| --- | --- | --- | --- |
| [Readiness Probe Failure](../scenarios/readiness-failure/README.md) | Distinguish Running from Ready and understand Endpoint removal | `get pods`, `describe pod`, Events, `get endpoints` | `scripts/trigger-readiness-failure.sh` |
| [High Error Rate](../scenarios/high-error-rate/README.md) | Separate app failures from Kubernetes health | Grafana error ratio, request rate, Loki logs, Prometheus alert | `scripts/generate-errors.sh` |
| [Pod Self-Healing](../scenarios/pod-self-healing/README.md) | Explain Deployment/ReplicaSet reconciliation | `get pods -w`, ReplicaSet state, Events | `scripts/trigger-pod-self-healing.sh` |
| [OOMKilled](../scenarios/oom-killed/README.md) | Diagnose resource limit failures and restart behavior | `describe pod`, last state, exit code 137, restart count, memory limits | `scripts/trigger-oom-killed.sh` |
| [Service Discovery Broken](../scenarios/service-discovery-broken/README.md) | Debug Service selector, Pod labels, and Endpoint routing | `describe svc`, `get pods --show-labels`, empty Endpoints, curl failure | `scripts/trigger-service-discovery-broken.sh` |

## Investigation Pattern

Use the same incident loop for each scenario:

1. Observe workload state with `kubectl get`.
2. Inspect detail with `kubectl describe`, Events, logs, or metrics.
3. Compare the expected Kubernetes relationship: Deployment to Pods, Service selector to Pod labels, Pod readiness to Endpoints.
4. State the root cause in Kubernetes terms.
5. Restore the workload and prove recovery with rollout status, Endpoints, metrics, or alerts.

## Runbooks

- [Readiness Probe Failure](../runbooks/readiness-failure.md)
- [High Error Rate](../runbooks/high-error-rate.md)
- [Pod Self-healing](../runbooks/pod-self-healing.md)
- [OOMKilled](../runbooks/oom-killed.md)
- [Service Discovery Broken](../runbooks/service-discovery-broken.md)

## Recommended Practice Order

1. Run **Pod Self-Healing** to understand the Deployment controller.
2. Run **Readiness Probe Failure** to understand Ready vs Running.
3. Run **High Error Rate** to practice app-level incidents where Kubernetes still looks healthy.
4. Run **OOMKilled** to understand memory limits and kernel-level termination.
5. Run **Service Discovery Broken** to understand how traffic routing can fail silently.
