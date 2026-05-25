# Runbook: Service Discovery Broken

## Symptoms

- Requests to the Service return connection refused or time out.
- All pods are `1/1 Running` with no restarts.
- `kubectl get endpoints` shows `<none>` for the affected Service.
- `PodinfoServiceHasNoEndpoints` alert firing in Prometheus.

## Why "Pod Healthy + Service Exists" Still Breaks Traffic

A Kubernetes Service does not forward traffic directly to pods by IP. It works through the Endpoints object:

```text
Service → selector matches pod labels → Endpoints object → kube-proxy rules → pod IP
```

If the selector no longer matches any pod labels, the Endpoints object is empty. kube-proxy removes the destination rules. Traffic sent to the Service ClusterIP has nowhere to go.

The pods themselves are unaffected — their readiness probes still pass, kubelet still marks them Ready. The problem lives entirely in the Service ↔ Endpoint ↔ pod-label chain.

## Where to Look

Check endpoints first:

```bash
kubectl -n incident-lab get endpoints podinfo
kubectl -n incident-lab describe svc podinfo
```

Look for empty `Endpoints:` or `<none>`.

Then compare the Service selector to the pod labels:

```bash
# What the Service is selecting for
kubectl -n incident-lab get svc podinfo -o jsonpath='{.spec.selector}'

# What labels the pods actually have
kubectl -n incident-lab get pods -l app.kubernetes.io/name=podinfo --show-labels
```

If the selector does not match any pod label, that is the root cause.

## Diagnosing with kubectl

Full diagnostic sequence:

```bash
# 1. Is the service present?
kubectl -n incident-lab get svc podinfo

# 2. Does it have endpoints?
kubectl -n incident-lab get endpoints podinfo

# 3. What selector is the service using?
kubectl -n incident-lab describe svc podinfo

# 4. What labels do the pods have?
kubectl -n incident-lab get pods --show-labels

# 5. Cross-reference: does the selector match?
kubectl -n incident-lab get pods -l app.kubernetes.io/name=podinfo
```

If step 5 returns no pods, the selector is broken.

## Common Root Causes in Production

| Cause | How it happens |
|---|---|
| Manual label change | Operator runs `kubectl label pod ... app=new-value` without updating the Service |
| Helm template bug | A chart upgrade changes the label key or value but the Service selector is not updated in sync |
| ArgoCD sync drift | The Service and Deployment live in different sync waves; Service updates first with a new selector before new pods are ready |
| Copy-paste error | New service or deployment written from a template with the wrong app name |
| Namespace migration | Pods moved to a new namespace but the Service selector still references the old one |

All of these share the same root cause: the Service selector and the pod labels diverge.

## Resolution

Patch the Service selector to match the pod labels:

```bash
kubectl -n incident-lab patch svc podinfo --type='json' \
  -p='[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"podinfo"}]'
```

In a real incident, fix the source of truth (Helm values, manifest, or ArgoCD config) instead of patching directly.

In this lab:

```bash
scripts/lab.sh scenario service-discovery restore
```

## Validation

```bash
kubectl -n incident-lab get endpoints podinfo
```

Expected:

```text
NAME      ENDPOINTS                     AGE
podinfo   10.x.x.x:9898,10.x.x.x:9898  5m
```

Confirm traffic flows:

```bash
curl http://localhost:9898/
```

Confirm `PodinfoServiceHasNoEndpoints` clears in Prometheus within 1 minute.
