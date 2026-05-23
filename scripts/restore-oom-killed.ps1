$ErrorActionPreference = "Stop"

Write-Host "Restoring podinfo memory limit to 128Mi..."
kubectl -n incident-lab set resources deployment/podinfo --containers=podinfo --limits=memory=128Mi
kubectl -n incident-lab rollout status deploy/podinfo
Write-Host "Memory limits restored."
