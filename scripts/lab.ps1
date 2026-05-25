$ErrorActionPreference = "Stop"

function Show-Usage {
  @"
Usage:
  .\scripts\lab.ps1 deploy
  .\scripts\lab.ps1 monitoring
  .\scripts\lab.ps1 status
  .\scripts\lab.ps1 cleanup

  .\scripts\lab.ps1 scenario readiness trigger
  .\scripts\lab.ps1 scenario readiness restore
  .\scripts\lab.ps1 scenario errors trigger
  .\scripts\lab.ps1 scenario self-healing trigger
  .\scripts\lab.ps1 scenario oom trigger
  .\scripts\lab.ps1 scenario oom restore
  .\scripts\lab.ps1 scenario service-discovery trigger
  .\scripts\lab.ps1 scenario service-discovery restore

Aliases:
  mon       monitoring
  st        status
  sc        scenario
  svc       service-discovery
"@
}

function Invoke-LabScript {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [string[]] $RemainingArgs = @()
  )
  & (Join-Path $PSScriptRoot $Path) @RemainingArgs
}

$Command = if ($args.Count -gt 0) { $args[0] } else { "help" }
$Rest = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

switch ($Command) {
  { $_ -in @("help", "-h", "--help") } { Show-Usage }
  "deploy" { Invoke-LabScript "lab\deploy-app.ps1" $Rest }
  { $_ -in @("monitoring", "mon") } { Invoke-LabScript "lab\install-monitoring.ps1" $Rest }
  { $_ -in @("status", "st") } { & bash (Join-Path $PSScriptRoot "lab/status.sh") @Rest }
  "cleanup" { Invoke-LabScript "lab\cleanup.ps1" $Rest }
  { $_ -in @("scenario", "sc") } {
    $Scenario = if ($Rest.Count -gt 0) { $Rest[0] } else { "help" }
    $Action = if ($Rest.Count -gt 1) { $Rest[1] } else { "help" }
    $ScenarioRest = if ($Rest.Count -gt 2) { $Rest[2..($Rest.Count - 1)] } else { @() }

    switch ("${Scenario}:${Action}") {
      { $_ -in @("help:*", "*:help", "-h:*", "--help:*") } { Show-Usage }
      "readiness:trigger" { Invoke-LabScript "scenarios\trigger-readiness-failure.ps1" $ScenarioRest }
      "readiness:restore" { Invoke-LabScript "scenarios\restore-readiness.ps1" $ScenarioRest }
      { $_ -in @("errors:trigger", "error-rate:trigger", "high-error-rate:trigger") } { Invoke-LabScript "scenarios\generate-errors.ps1" $ScenarioRest }
      { $_ -in @("self-healing:trigger", "self:trigger") } { Invoke-LabScript "scenarios\trigger-pod-self-healing.ps1" $ScenarioRest }
      { $_ -in @("oom:trigger", "oom-killed:trigger") } { Invoke-LabScript "scenarios\trigger-oom-killed.ps1" $ScenarioRest }
      { $_ -in @("oom:restore", "oom-killed:restore") } { Invoke-LabScript "scenarios\restore-oom-killed.ps1" $ScenarioRest }
      { $_ -in @("service-discovery:trigger", "svc:trigger") } { Invoke-LabScript "scenarios\trigger-service-discovery-broken.ps1" $ScenarioRest }
      { $_ -in @("service-discovery:restore", "svc:restore") } { Invoke-LabScript "scenarios\restore-service-discovery-broken.ps1" $ScenarioRest }
      default {
        Write-Error "Unknown scenario command: $Scenario $Action"
      }
    }
  }
  default {
    Write-Error "Unknown command: $Command"
  }
}
