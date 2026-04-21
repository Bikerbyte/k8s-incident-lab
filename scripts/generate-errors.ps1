$ErrorActionPreference = "Stop"

$LocalPort = if ($env:LOCAL_PORT) { $env:LOCAL_PORT } else { "9898" }
$Requests = if ($env:REQUESTS) { [int]$env:REQUESTS } else { 60 }
$SleepSeconds = if ($env:SLEEP_SECONDS) { [int]$env:SLEEP_SECONDS } else { 1 }

$process = Start-Process -FilePath "kubectl" `
  -ArgumentList "-n", "incident-lab", "port-forward", "svc/podinfo", "$LocalPort`:9898" `
  -PassThru `
  -WindowStyle Hidden

try {
  Start-Sleep -Seconds 2

  for ($i = 1; $i -le $Requests; $i++) {
    try {
      $response = Invoke-WebRequest -Uri "http://127.0.0.1:$LocalPort/status/500" -UseBasicParsing
      Write-Host "request ${i}: HTTP $($response.StatusCode)"
    } catch {
      $statusCode = $_.Exception.Response.StatusCode.value__
      if ($statusCode) {
        Write-Host "request ${i}: HTTP $statusCode"
      } else {
        Write-Host "request ${i}: failed"
      }
    }
    Start-Sleep -Seconds $SleepSeconds
  }

  Write-Host "Generated $Requests failing requests."
} finally {
  if ($process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
  }
}
