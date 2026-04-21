# App Manifests

This directory contains the demo workload for the incident lab.

Apply the namespace and Podinfo workload:

```bash
kubectl apply -f app/manifests/namespace.yaml
kubectl apply -f app/manifests/podinfo.yaml
```

Verify the app:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab port-forward svc/podinfo 9898:9898
curl http://localhost:9898/
curl http://localhost:9898/metrics
```
