# Screenshot Guide

Use this folder for example screenshots from real lab runs.

Current repo screenshots:

- `grafana-normal.png`
- `readiness-failure.png`
- `high-error-rate.png`

## Recommended Files

| File | When to capture | What should be visible |
| --- | --- | --- |
| `grafana-normal.png` | After deploy and monitoring are healthy | Ready Replicas `2`, Unready Pods `0`, Error Ratio near `0` |
| `readiness-failure.png` | After `scripts/trigger-readiness-failure.sh` | Unready Pods `1`, Unavailable Replicas `1`, Ready Service Endpoints still available |
| `readiness-events.png` | During readiness failure | `kubectl get events` showing readiness probe `404` |
| `high-error-rate.png` | While `scripts/generate-errors.sh` is running | Request Rate and Error Ratio rising |
| `loki-500-logs.png` | During high error rate | Loki Explore query for `500` logs |
| `pod-self-healing.png` | During or after deleting a pod | Replacement pod and replica recovery |

## Capture Checklist

Before taking screenshots:

```bash
scripts/status.sh
scripts/port-forward.sh
```

You can also capture the current Grafana dashboard with:

```bash
scripts/capture-grafana-screenshot.sh docs/screenshots/grafana-normal.png
```

Change the time range by setting `TIME_RANGE`:

```bash
TIME_RANGE=now-5m scripts/capture-grafana-screenshot.sh docs/screenshots/high-error-rate.png
```

Open Grafana:

```text
http://localhost:3000
```

Use this dashboard:

```text
Incident Lab / Podinfo Overview
```

For Grafana screenshots, set the time range to:

```text
Last 15 minutes
```

This keeps the incident signal visible without too much old noise.

## Suggested Workflow

1. Capture `grafana-normal.png`.
2. Run `scripts/trigger-readiness-failure.sh`.
3. Capture `readiness-failure.png`.
4. Capture `readiness-events.png`.
5. Run `scripts/restore-readiness.sh`.
6. Run `scripts/generate-errors.sh`.
7. Capture `high-error-rate.png`.
8. Capture `loki-500-logs.png`.
9. Stop the error generator with `Ctrl+C`.
10. Run `scripts/trigger-pod-self-healing.sh`.
11. Capture `pod-self-healing.png`.

## Notes

Screenshots should show the evidence, not just the tool UI. Prefer cropping around the relevant Grafana panels, Loki query results, or terminal output.
