# Alerts

The lab includes a small set of Prometheus alerting rules for the incident scenarios.

Alertmanager is disabled in this MVP, so these alerts are meant to be observed in Prometheus rather than routed as notifications.

Open Prometheus:

```bash
scripts/lab.sh access
```

Then visit:

```text
http://localhost:9090/alerts
```

You can also query alerts from the terminal:

```bash
scripts/lab.sh alerts
```

## Alert Rules

The rules live in:

```text
monitoring/alerts/podinfo-alerts.yaml
```

| Alert | Scenario | Meaning |
| --- | --- | --- |
| `PodinfoHighErrorRate` | High Error Rate | More than 5% of Podinfo requests are HTTP 5xx for at least 1 minute |
| `PodinfoUnavailableReplicas` | Readiness Probe Failure | Podinfo has unavailable Deployment replicas for at least 1 minute |
| `PodinfoUnreadyPods` | Readiness Probe Failure | At least one lab pod is Not Ready for at least 1 minute |

## How to Trigger

High error rate:

```bash
scripts/lab.sh scenario errors trigger
```

Readiness failure:

```bash
scripts/lab.sh scenario readiness trigger
```

Restore readiness:

```bash
scripts/lab.sh scenario readiness restore
```

## Notes

- Alerts may take 1 to 2 minutes to move from pending to firing because each rule has a `for` duration.
- If Prometheus shows no rules, re-run `scripts/lab.sh monitoring` or apply `monitoring/alerts/podinfo-alerts.yaml`.
- If Prometheus is unreachable from your browser, restart local access with `scripts/lab.sh access`.
