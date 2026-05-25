$ErrorActionPreference = "Stop"

Write-Host "Setting podinfo memory limit to 15Mi to trigger OOMKill..."
kubectl -n incident-lab set resources deployment/podinfo --containers=podinfo --limits=memory=15Mi

Write-Host "Watch for OOMKill: kubectl -n incident-lab get pods -w"
