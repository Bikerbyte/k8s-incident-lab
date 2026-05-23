# Scenarios

The lab contains three repeatable incident scenarios. Each scenario has a short guide under `scenarios/` and a runbook under `runbooks/`.

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

| Scenario | What it teaches | Trigger | Primary evidence |
| --- | --- | --- | --- |
| [Readiness Probe Failure](../scenarios/readiness-failure/README.md) | Running is not the same as Ready | `scripts/trigger-readiness-failure.sh` | Unready Pods, Unavailable Replicas, Kubernetes events, Prometheus alerts |
| [High Error Rate](../scenarios/high-error-rate/README.md) | Kubernetes can be healthy while the app returns 500s | `scripts/generate-errors.sh` | Error Ratio, Request Rate, Loki logs, Prometheus alert |
| [Pod Self-Healing](../scenarios/pod-self-healing/README.md) | Deployments recreate deleted pods | `scripts/trigger-pod-self-healing.sh` | Pod lifecycle events, replacement pod, ready replica recovery |
| [OOMKilled](../scenarios/oom-killed/README.md) | Container killed by kernel OOM killer when memory limit exceeded | `scripts/trigger-oom-killed.sh` | Exit code 137, CrashLoopBackOff, Pod Restarts, Prometheus alert |
| [Service Discovery Broken](../scenarios/service-discovery-broken/README.md) | Broken Service selector silently drops all traffic despite healthy pods | `scripts/trigger-service-discovery-broken.sh` | Empty endpoints, Ready Service Endpoints=0, Prometheus alert |

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
