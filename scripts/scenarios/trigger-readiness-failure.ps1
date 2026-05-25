$ErrorActionPreference = "Stop"

$patch = @'
[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/path",
    "value": "/broken-readyz"
  }
]
'@

kubectl -n incident-lab patch deployment podinfo --type=json -p $patch
kubectl -n incident-lab rollout status deploy/podinfo

Write-Host "Readiness failure triggered. Check: kubectl -n incident-lab get pods"
