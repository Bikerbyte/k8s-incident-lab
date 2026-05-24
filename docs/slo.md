# SLO Dashboard

This document explains the `Incident Lab / SLO` Grafana dashboard, how to read each panel, how the SLO is defined, and why 99.5% was chosen.

## Dashboard Location

```text
Grafana → Incident Lab / SLO
```

The dashboard defaults to a 30-day time range because SLOs are measured over long windows.

---

## Panels

### 1. Availability SLI (30d) — Gauge

**What it shows:**

The proportion of successful (non-5xx) requests over the last 30 days.

**PromQL:**

```promql
1 - (
  sum(rate(http_requests_total{namespace="incident-lab", status=~"5.."}[30d]))
  /
  clamp_min(sum(rate(http_requests_total{namespace="incident-lab"}[30d])), 0.001)
)
```

**How to read it:**

| Color | Meaning |
|---|---|
| Green | At or above 99.5% — within SLO |
| Yellow | Between 99.0% and 99.5% — degraded, consuming budget |
| Red | Below 99.0% — budget depleted, SLO breached |

The `clamp_min(..., 0.001)` prevents division by zero when Podinfo has no traffic.

---

### 2. Error Budget Remaining (30d, SLO=99.5%) — Gauge

**What it shows:**

How much of the allowed error budget has not yet been consumed. An SLO of 99.5% means 0.5% of requests are allowed to fail. This gauge shows what fraction of that 0.5% is still available.

**PromQL:**

```promql
(
  0.005 - (
    sum(rate(http_requests_total{namespace="incident-lab", status=~"5.."}[30d]))
    /
    clamp_min(sum(rate(http_requests_total{namespace="incident-lab"}[30d])), 0.001)
  )
) / 0.005
```

**How to read it:**

| Value | Meaning |
|---|---|
| 100% | No errors in the last 30 days |
| 50% | Half the budget consumed |
| 0% | SLO breached — all allowable errors used up |
| Negative | Over budget — reliability target is not being met |

When the budget is low, new deployments, experiments, and non-critical maintenance should stop until the budget recovers.

---

### 3. Burn Rate (1h vs 6h) — Time Series

**What it shows:**

How fast the error budget is being consumed, expressed as a multiple of the sustainable rate.

A burn rate of 1.0 means errors are arriving at exactly the rate the SLO allows. A burn rate of 14.4 means you will exhaust the monthly budget in 30 days / 14.4 = ~2 days.

**PromQL (1h burn rate):**

```promql
(
  sum(rate(http_requests_total{namespace="incident-lab", status=~"5.."}[1h]))
  /
  clamp_min(sum(rate(http_requests_total{namespace="incident-lab"}[1h])), 0.001)
) / 0.005
```

**How to read it:**

| Burn Rate | Meaning |
|---|---|
| < 1 | Consuming budget slower than allowed — recovering |
| 1 | Sustainable — budget will last exactly 30 days |
| 5 | Elevated — budget exhausted in ~6 days |
| 14.4 | Critical — budget exhausted in ~2 days |

The short window (1h) reacts quickly to incidents. The long window (6h) smooths out spikes. When the short window spikes well above the long window, an incident is in progress.

---

### 4. Availability SLI Trend (30d rolling) — Time Series

**What it shows:**

A rolling 30-day availability trend over the selected time range. Useful for identifying whether reliability is improving or degrading over weeks.

The red threshold line is drawn at 99.5% — crossing below it indicates the SLO is breached for that rolling window.

---

## Why 99.5%?

**99.5% allows ~3.6 hours of downtime per 30 days.**

| SLO | Allowed downtime (30 days) |
|---|---|
| 99.0% | ~7.2 hours |
| 99.5% | ~3.6 hours |
| 99.9% | ~43 minutes |
| 99.95% | ~22 minutes |

99.5% was chosen because:

1. **This is a stateless demo app with no persistence.** A higher SLO like 99.9% would be reasonable for a real user-facing service with a database, SLA, and on-call team.
2. **The lab intentionally injects failures.** Each scenario run temporarily degrades availability. A strict SLO would always show as breached during active lab sessions.
3. **It makes the error budget visible.** At 99.5%, the error budget (0.5%) is large enough that a single readiness failure scenario (~1 minute of unavailability) consumes a measurable but non-catastrophic portion of it. This teaches budget thinking without immediately triggering a breach.

In a real service, the SLO target should be derived from user-facing pain points and business requirements, not from what is technically achievable.

---

## SLI Definition

**SLI (Service Level Indicator):** the fraction of requests that returned a non-5xx response.

```text
SLI = (total requests - 5xx requests) / total requests
```

This is a request-success-rate SLI. It measures availability from the perspective of the application layer, not the infrastructure layer. A pod that is Running but returning 500s would show up here, which is why this complements the infrastructure metrics in the main Podinfo Overview dashboard.
