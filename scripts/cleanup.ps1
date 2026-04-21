$ErrorActionPreference = "Stop"

kubectl delete namespace incident-lab --ignore-not-found

helm uninstall promtail --namespace monitoring --ignore-not-found
helm uninstall loki --namespace monitoring --ignore-not-found
helm uninstall kube-prometheus-stack --namespace monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

Write-Host "Incident lab resources removed."
