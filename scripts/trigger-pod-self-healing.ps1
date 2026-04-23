$ErrorActionPreference = "Stop"

$podName = kubectl -n incident-lab get pod -l app.kubernetes.io/name=podinfo -o jsonpath='{.items[0].metadata.name}'

if ([string]::IsNullOrWhiteSpace($podName)) {
  Write-Error "No podinfo pod found."
}

kubectl -n incident-lab delete pod $podName
Write-Host "Deleted $podName. Watch recovery with: kubectl -n incident-lab get pods -w"
