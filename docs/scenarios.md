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

## Scenario Index

| Scenario | What it teaches | Trigger | Primary evidence |
| --- | --- | --- | --- |
| [Readiness Probe Failure](../scenarios/readiness-failure/README.md) | Running is not the same as Ready | `scripts/trigger-readiness-failure.sh` | Unready Pods, Unavailable Replicas, Kubernetes events |
| [High Error Rate](../scenarios/high-error-rate/README.md) | Kubernetes can be healthy while the app returns 500s | `scripts/generate-errors.sh` | Error Ratio, Request Rate, Loki logs |
| [Pod Self-Healing](../scenarios/pod-self-healing/README.md) | Deployments recreate deleted pods | `scripts/trigger-pod-self-healing.sh` | Pod lifecycle events, replacement pod, ready replica recovery |

## Runbooks

- [Readiness Probe Failure](../runbooks/readiness-failure.md)
- [High Error Rate](../runbooks/high-error-rate.md)
- [Pod Self-healing](../runbooks/pod-self-healing.md)

## Recommended Practice Order

1. Run **Pod Self-Healing** to understand the Deployment controller.
2. Run **Readiness Probe Failure** to understand Ready vs Running.
3. Run **High Error Rate** to practice app-level incidents where Kubernetes still looks healthy.
