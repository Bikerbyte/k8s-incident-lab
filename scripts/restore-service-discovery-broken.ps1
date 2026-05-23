$ErrorActionPreference = "Stop"

$patch = @'
[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"podinfo"}]
'@

Write-Host "Restoring podinfo Service selector..."
kubectl -n incident-lab patch svc podinfo --type=json -p $patch

Write-Host "Current endpoints:"
kubectl -n incident-lab get endpoints podinfo
Write-Host "Service selector restored."
