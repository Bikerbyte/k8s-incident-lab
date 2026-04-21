$ErrorActionPreference = "Stop"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values monitoring/helm-values/kube-prometheus-stack-values.yaml

helm upgrade --install loki grafana/loki `
  --namespace monitoring `
  --values monitoring/helm-values/loki-values.yaml

helm upgrade --install promtail grafana/promtail `
  --namespace monitoring `
  --values monitoring/helm-values/promtail-values.yaml

kubectl -n monitoring rollout status deploy/kube-prometheus-stack-grafana
kubectl apply -f monitoring/servicemonitors/podinfo-servicemonitor.yaml
kubectl apply -f monitoring/dashboards/podinfo-overview-dashboard.yaml

Write-Host "Monitoring stack installed."
Write-Host "Open Grafana with:"
Write-Host "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
Write-Host "Login: admin / admin"
