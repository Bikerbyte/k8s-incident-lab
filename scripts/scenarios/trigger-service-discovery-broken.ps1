$ErrorActionPreference = "Stop"

$patch = @'
[{"op":"replace","path":"/spec/selector/app.kubernetes.io~1name","value":"podinfo-typo"}]
'@

Write-Host "Breaking podinfo Service selector..."
kubectl -n incident-lab patch svc podinfo --type=json -p $patch

Write-Host "Current endpoints (should be empty):"
kubectl -n incident-lab get endpoints podinfo
Write-Host "Restore with: .\scripts\lab.ps1 scenario service-discovery restore"
