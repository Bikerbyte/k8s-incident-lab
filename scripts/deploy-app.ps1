$ErrorActionPreference = "Stop"

kubectl apply -f app/manifests/namespace.yaml
kubectl apply -f app/manifests/podinfo.yaml
kubectl -n incident-lab rollout status deploy/podinfo

Write-Host "Podinfo is deployed in namespace incident-lab."
