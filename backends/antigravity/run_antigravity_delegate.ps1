param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Workdir = (Get-Location).Path,

    [ValidateRange(1, 20)]
    [int]$MaxTurns = 3,

    [string]$Model = "",

    [ValidateRange(0, 604800)]
    [int]$PrintTimeoutSeconds = 0,

    [bool]$DangerouslySkipPermissions = $true,

    [bool]$Sandbox = $false,

    [AllowEmptyCollection()]
    [string[]]$AddDir = @(),

    [ValidateRange(0, 604800)]
    [int]$TimeoutSeconds = 0,

    [ValidateRange(30, 86400)]
    [int]$IdleTimeoutSeconds = 600,

    [ValidateRange(1, 300)]
    [int]$PollSeconds = 30,

    [ValidateRange(1, 3600)]
    [int]$StatusSeconds = 180,

    [ValidateRange(1, 10000)]
    [int]$TailLines = 200,

    [switch]$FullLog,

    [string]$BackendConfigPath = "",

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Get-DelegateCommonModulePath {
    $candidates = @(
        (Join-Path $PSScriptRoot "..\shared\scripts\DelegateCommon.psm1"),
        (Join-Path $PSScriptRoot "..\..\shared\scripts\DelegateCommon.psm1")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Unable to locate DelegateCommon.psm1 from '$PSScriptRoot'."
}

$modulePath = Get-DelegateCommonModulePath
Import-Module $modulePath -Force

function Get-RunnerBackendConfig {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Backend config file not found: $Path"
    }

    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

$runnerBackendConfig = Get-RunnerBackendConfig -Path $BackendConfigPath
if ($null -ne $runnerBackendConfig) {
    if (-not $PSBoundParameters.ContainsKey("Model") -and $null -ne $runnerBackendConfig.model) {
        $Model = [string]$runnerBackendConfig.model
    }
    if (-not $PSBoundParameters.ContainsKey("PrintTimeoutSeconds") -and $null -ne $runnerBackendConfig.print_timeout_seconds) {
        $PrintTimeoutSeconds = [int]$runnerBackendConfig.print_timeout_seconds
    }
    if (-not $PSBoundParameters.ContainsKey("DangerouslySkipPermissions") -and $null -ne $runnerBackendConfig.dangerously_skip_permissions) {
        $DangerouslySkipPermissions = [bool]$runnerBackendConfig.dangerously_skip_permissions
    }
    if (-not $PSBoundParameters.ContainsKey("Sandbox") -and $null -ne $runnerBackendConfig.sandbox) {
        $Sandbox = [bool]$runnerBackendConfig.sandbox
    }
    if (-not $PSBoundParameters.ContainsKey("AddDir") -and $null -ne $runnerBackendConfig.add_dirs) {
        $AddDir = @($runnerBackendConfig.add_dirs | ForEach-Object { [string]$_ })
    }
}

$resolvedWorkdir = (Resolve-Path -LiteralPath $Workdir).Path
$agyPath = Resolve-DelegateCommandPath -CommandName "agy"
$runContext = New-DelegateRunContext -BackendName "relay-antigravity"
$stdoutLog = Join-Path $runContext.LogRoot "antigravity-$($runContext.Timestamp)-$($runContext.RunId).stdout.log"
$stderrLog = Join-Path $runContext.LogRoot "antigravity-$($runContext.Timestamp)-$($runContext.RunId).stderr.log"

$workspaceDirs = New-Object System.Collections.Generic.List[string]
$workspaceDirs.Add($resolvedWorkdir)
foreach ($dir in @($AddDir)) {
    if ([string]::IsNullOrWhiteSpace($dir)) {
        continue
    }

    $resolvedDir = (Resolve-Path -LiteralPath $dir).Path
    if (-not $workspaceDirs.Contains($resolvedDir)) {
        $workspaceDirs.Add($resolvedDir)
    }
}

$effectivePrintTimeoutSeconds = if ($PrintTimeoutSeconds -gt 0) { $PrintTimeoutSeconds } elseif ($TimeoutSeconds -gt 0) { $TimeoutSeconds } else { 0 }
$agyArgs = @()
if (-not [string]::IsNullOrWhiteSpace($Model)) {
    $agyArgs += "--model"
    $agyArgs += $Model
}
if ($effectivePrintTimeoutSeconds -gt 0) {
    $agyArgs += "--print-timeout"
    $agyArgs += ("{0}s" -f $effectivePrintTimeoutSeconds)
}
if ($DangerouslySkipPermissions) {
    $agyArgs += "--dangerously-skip-permissions"
}
if ($Sandbox) {
    $agyArgs += "--sandbox"
}
foreach ($dir in $workspaceDirs) {
    $agyArgs += "--add-dir"
    $agyArgs += $dir
}
$agyArgs += "--print"
$agyArgs += $Prompt

Write-Host "Workdir: $resolvedWorkdir"
Write-Host "Antigravity: $agyPath"
Write-Host "RunId: $($runContext.RunId)"
Write-Host "Model: $(if (-not [string]::IsNullOrWhiteSpace($Model)) { $Model } else { 'default' })"
Write-Host "DangerouslySkipPermissions: $DangerouslySkipPermissions"
Write-Host "Sandbox: $Sandbox"
Write-Host "AddDir: $($workspaceDirs -join ',')"
Write-Host "MaxTurns: $MaxTurns"
Write-Host "PrintTimeoutSeconds: $(if ($effectivePrintTimeoutSeconds -gt 0) { $effectivePrintTimeoutSeconds } else { 'disabled' })"
if ($TimeoutSeconds -gt 0) {
    Write-Host "TimeoutSeconds: $TimeoutSeconds"
}
else {
    Write-Host "TimeoutSeconds: disabled"
}
Write-Host "IdleTimeoutSeconds: $IdleTimeoutSeconds"
Write-Host "PollSeconds: $PollSeconds"
Write-Host "StatusSeconds: $StatusSeconds"
Write-Host "TailLines: $TailLines"
Write-Host "FullLog: $FullLog"
Write-Host "StdoutLog: $stdoutLog"
Write-Host "StderrLog: $stderrLog"

if ($WhatIf) {
    Write-Host "WhatIf: would run agy with arguments:"
    $agyArgs | ForEach-Object { Write-Host "  $_" }
    exit 0
}

Push-Location -LiteralPath $resolvedWorkdir
try {
    $attempt = 1
    $exitCode = 1

    while ($attempt -le $MaxTurns) {
        Write-Host "Antigravity attempt $attempt of $MaxTurns"

        $exitCode = Invoke-DelegateAttempt `
            -Label "Antigravity" `
            -FilePath $agyPath `
            -Arguments $agyArgs `
            -StdoutPath $stdoutLog `
            -StderrPath $stderrLog `
            -Timeout $TimeoutSeconds `
            -IdleTimeout $IdleTimeoutSeconds `
            -Poll $PollSeconds `
            -StatusInterval $StatusSeconds

        if ($exitCode -eq 0) {
            break
        }

        if ($attempt -lt $MaxTurns) {
            Write-Warning "Antigravity attempt $attempt exited with code $exitCode. Retrying."
        }

        $attempt++
    }

    exit $exitCode
}
finally {
    Pop-Location
    Write-DelegateLogs -Label "Antigravity" -StdoutPath $stdoutLog -StderrPath $stderrLog -TailLines $TailLines -FullLog ([bool]$FullLog)
    Write-DelegatePostRunStatus -Workdir $resolvedWorkdir
}
