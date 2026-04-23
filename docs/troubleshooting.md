# Troubleshooting

Use this checklist when Grafana or Podinfo looks like it is not running.

## 1. Check Minikube

Start here because `kubectl` needs the Kubernetes API server.

For a full lab overview, run:

```bash
scripts/status.sh
```

For only minikube:

```bash
minikube status
```

Healthy output should include:

```text
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

If `kubelet` or `apiserver` is stopped, restart minikube:

```bash
minikube start
```

Then confirm the node is ready:

```bash
kubectl get nodes
```

Expected:

```text
minikube   Ready
```

## 2. Check the Pods

Podinfo runs in the `incident-lab` namespace:

```bash
kubectl -n incident-lab get pods,svc
```

Expected:

```text
podinfo-...   1/1   Running
service/podinfo
```

Grafana runs in the `monitoring` namespace:

```bash
kubectl -n monitoring get pods,svc
```

Expected:

```text
kube-prometheus-stack-grafana-...   3/3   Running
service/kube-prometheus-stack-grafana
```

If Podinfo is missing, deploy it:

```bash
scripts/deploy-app.sh
```

If monitoring is missing, install it:

```bash
scripts/install-monitoring.sh
```

## 3. Check Port-Forwarding

The services run inside Kubernetes. Browser access through `localhost` only works while `kubectl port-forward` is running.

Check whether local ports are open:

```bash
ss -ltnp | rg ':(3000|9898)\b'
```

If nothing is listening, open Grafana:

```bash
scripts/port-forward.sh
```

This opens:

```text
Grafana -> http://localhost:3000
Podinfo -> http://localhost:9898
```

Then visit:

```text
http://localhost:3000
http://localhost:9898
```

## 4. Verify with Curl

Grafana:

```bash
curl -I http://localhost:3000/login
```

Expected:

```text
HTTP/1.1 200 OK
```

Podinfo:

```bash
curl http://localhost:9898/readyz
```

Expected:

```json
{
  "status": "OK"
}
```

## Quick Diagnosis

Use this table to decide what to fix.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `kubectl` says connection refused | Minikube API server is stopped | `minikube start` |
| Pods are not listed | App or monitoring is not deployed | Run deploy/install scripts |
| Pods are `Running` but browser does not open | Port-forward is not running | `scripts/port-forward.sh` |
| Grafana opens but dashboard is missing | Dashboard ConfigMap was not applied | `kubectl apply -f monitoring/dashboards/podinfo-overview-dashboard.yaml` |
| Podinfo returns OK but Grafana has no data | Prometheus may still be scraping or ServiceMonitor is missing | Wait 1 minute, then re-apply monitoring |
