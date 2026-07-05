param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Workdir = (Get-Location).Path,

    [ValidateRange(1, 20)]
    [int]$MaxTurns = 3,

    [ValidateSet("default", "json")]
    [string]$OutputFormat = "json",

    [string]$Model = "",

    [ValidateSet("auto", "small", "coding", "hard", "review", "docs")]
    [string]$ModelIntent = "coding",

    [string[]]$ProviderPreference = @("opencode"),

    [switch]$AllowPaidFallback,

    [switch]$RefreshModels,

    [string]$Agent = "",

    [string[]]$AttachFiles = @(),

    [bool]$AutoApprove = $true,

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

    [switch]$PrintRawJsonTail,

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

function Get-OpencodeIntentPatterns {
    param([Parameter(Mandatory = $true)][string]$Intent)

    switch ($Intent) {
        "small" { return @("flash", "mini", "lite", "fast", "small") }
        "docs" { return @("flash", "mini", "lite", "fast", "small") }
        "review" { return @("flash", "mini", "lite", "fast", "small") }
        "coding" { return @("code", "coder", "deepseek", "qwen", "glm", "kimi") }
        "hard" { return @("code", "coder", "deepseek", "qwen", "glm", "kimi", "pro") }
        default { return @("code", "coder", "deepseek", "qwen", "glm", "kimi", "flash", "mini") }
    }
}

function Get-OpencodeModelScore {
    param(
        [Parameter(Mandatory = $true)][string]$ModelName,
        [Parameter(Mandatory = $true)][string]$Intent
    )

    $score = 0
    $patterns = @(Get-OpencodeIntentPatterns -Intent $Intent)
    for ($i = 0; $i -lt $patterns.Count; $i++) {
        if ($ModelName -like "*$($patterns[$i])*") {
            $score += (100 - $i)
        }
    }

    if ($Intent -eq "hard" -and $ModelName -match "(?i)(flash|mini|lite|free)") {
        $score -= 25
    }

    if ($ModelName -match "(?i)free") {
        $score += 5
    }

    return $score
}

function Get-AvailableOpencodeModels {
    param(
        [Parameter(Mandatory = $true)][string]$OpencodePath,
        [switch]$Refresh
    )

    if ($Refresh) {
        & $OpencodePath models --refresh | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "opencode models --refresh failed with exit code $LASTEXITCODE."
        }
    }

    $models = @(& $OpencodePath models)
    if ($LASTEXITCODE -ne 0) {
        throw "opencode models failed with exit code $LASTEXITCODE."
    }

    @($models | ForEach-Object { $_.Trim() } | Where-Object { $_ -match "^[^/\s]+/[^\s]+$" })
}

function Resolve-OpencodeModelSelection {
    param(
        [Parameter(Mandatory = $true)][string[]]$AvailableModels,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][string[]]$ProviderPreference,
        [Parameter(Mandatory = $true)][bool]$AllowPaidFallback,
        [string]$ExplicitModel = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitModel)) {
        if ($AvailableModels -contains $ExplicitModel) {
            return [pscustomobject]@{
                Model = $ExplicitModel
                Reason = "explicit model"
                Provider = ($ExplicitModel -split "/")[0]
            }
        }

        throw "Explicit OpenCode model not found in visible model list: $ExplicitModel"
    }

    $preferredProviders = @($ProviderPreference | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($preferredProviders.Count -eq 0) {
        $preferredProviders = @("opencode")
    }

    $ranked = New-Object System.Collections.Generic.List[object]

    foreach ($provider in $preferredProviders) {
        foreach ($candidate in ($AvailableModels | Where-Object { $_ -like "$provider/*" })) {
            $ranked.Add([pscustomobject]@{
                Model = $candidate
                Provider = $provider
                Score = (Get-OpencodeModelScore -ModelName $candidate -Intent $Intent)
                Preferred = $true
            })
        }
    }

    if ($AllowPaidFallback) {
        foreach ($candidate in $AvailableModels) {
            if ($ranked.Model -contains $candidate) {
                continue
            }

            $ranked.Add([pscustomobject]@{
                Model = $candidate
                Provider = ($candidate -split "/")[0]
                Score = (Get-OpencodeModelScore -ModelName $candidate -Intent $Intent)
                Preferred = $false
            })
        }
    }

    if ($ranked.Count -eq 0) {
        $providerList = $preferredProviders -join ", "
        if ($AllowPaidFallback) {
            throw "No OpenCode model candidates found. Visible providers did not match preferred providers: $providerList"
        }

        throw "No OpenCode model candidates found for preferred providers: $providerList. Re-run with -AllowPaidFallback or pass -Model explicitly."
    }

    $selected = $ranked | Sort-Object Preferred, Score -Descending | Select-Object -First 1
    $reason = if ($selected.Preferred) {
        "preferred provider '$($selected.Provider)' matched intent '$Intent'"
    }
    else {
        "fallback provider '$($selected.Provider)' matched intent '$Intent'"
    }

    [pscustomobject]@{
        Model = $selected.Model
        Reason = $reason
        Provider = $selected.Provider
    }
}

function Resolve-OpencodeAgentSelection {
    param([string]$ExplicitAgent, [string]$Intent)

    if (-not [string]::IsNullOrWhiteSpace($ExplicitAgent)) {
        return [pscustomobject]@{
            Agent = $ExplicitAgent
            Reason = "explicit agent"
        }
    }

    $agent = switch ($Intent) {
        "review" { "plan" }
        "docs" { "plan" }
        default { "build" }
    }

    [pscustomobject]@{
        Agent = $agent
        Reason = "intent-based default"
    }
}

function Write-OpencodeJsonSummary {
    param(
        [Parameter(Mandatory = $true)][string]$StdoutPath,
        [Parameter(Mandatory = $true)][int]$TailLines
    )

    if (-not (Test-Path -LiteralPath $StdoutPath)) {
        return
    }

    $records = @()
    foreach ($line in Get-Content -LiteralPath $StdoutPath) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $records += $line | ConvertFrom-Json
        }
        catch {
            Write-Host "OpenCode stdout tail ($TailLines lines):"
            Get-Content -LiteralPath $StdoutPath -Tail $TailLines
            return
        }
    }

    $summaryLines = New-Object System.Collections.Generic.List[string]
    $toolCalls = 0
    $tokensIn = 0
    $tokensOut = 0
    $tokensTotal = 0
    $cost = 0.0

    foreach ($record in $records) {
        switch ($record.type) {
            "text" {
                $text = $record.part.text
                if (-not [string]::IsNullOrWhiteSpace($text)) {
                    $summaryLines.Add("[opencode] $text")
                }
            }
            "tool_use" {
                $tool = $record.part.tool
                $state = $record.part.state
                $status = $state.status
                if ($status -and $status -notin @("completed", "error")) {
                    continue
                }

                $toolCalls++
                $input = $state.input
                switch ($tool) {
                    "read" { $summaryLines.Add("[read] $($input.filePath)") }
                    "edit" {
                        $filePath = $input.filePath
                        $fileDiff = $state.metadata.filediff
                        if ($fileDiff) {
                            $summaryLines.Add("[edit] $filePath (+$($fileDiff.additions)/-$($fileDiff.deletions))")
                        }
                        else {
                            $summaryLines.Add("[edit] $filePath")
                        }
                    }
                    "write" { $summaryLines.Add("[write] $($input.filePath)") }
                    "grep" { $summaryLines.Add("[search] $($input.pattern)") }
                    "search" { $summaryLines.Add("[search] $($input.query)") }
                    "bash" { $summaryLines.Add("[shell] $($input.command)") }
                    default { $summaryLines.Add("[tool] $tool") }
                }

                if ($status -eq "error" -and $state.output) {
                    $summaryLines.Add("[warn] $($state.output)")
                }
            }
            "step_finish" {
                $tokens = $record.part.tokens
                if ($tokens) {
                    $tokensIn += [int]$tokens.input
                    $tokensOut += [int]$tokens.output
                    $tokensTotal += [int]$tokens.total
                }
                if ($null -ne $record.part.cost) {
                    $cost += [double]$record.part.cost
                }
            }
            "error" {
                $message = $record.error.data.message
                if (-not [string]::IsNullOrWhiteSpace($message)) {
                    $summaryLines.Add("[error] $message")
                }
            }
        }
    }

    Write-Host "OpenCode stdout summary:"
    if ($summaryLines.Count -eq 0) {
        Write-Host "(no summarized output)"
    }
    else {
        foreach ($entry in $summaryLines | Select-Object -Last $TailLines) {
            Write-Host $entry
        }
    }

    if ($tokensTotal -gt 0) {
        Write-Host "OpenCode tokens: $tokensTotal total ($tokensIn in / $tokensOut out) cost=$cost"
    }
    Write-Host "OpenCode tool calls observed: $toolCalls"
}

$resolvedWorkdir = (Resolve-Path -LiteralPath $Workdir).Path
$opencodePath = Resolve-DelegateCommandPath -CommandName "opencode"
$runContext = New-DelegateRunContext -BackendName "codex-delegate-opencode"
$stdoutLog = Join-Path $runContext.LogRoot "opencode-$($runContext.Timestamp)-$($runContext.RunId).stdout.log"
$stderrLog = Join-Path $runContext.LogRoot "opencode-$($runContext.Timestamp)-$($runContext.RunId).stderr.log"

$availableModels = Get-AvailableOpencodeModels -OpencodePath $opencodePath -Refresh:$RefreshModels
$modelSelection = Resolve-OpencodeModelSelection `
    -AvailableModels $availableModels `
    -Intent $ModelIntent `
    -ProviderPreference $ProviderPreference `
    -AllowPaidFallback ([bool]$AllowPaidFallback) `
    -ExplicitModel $Model
$agentSelection = Resolve-OpencodeAgentSelection -ExplicitAgent $Agent -Intent $ModelIntent

$opencodeArgs = @(
    "run",
    "--dir", $resolvedWorkdir,
    "--format", $OutputFormat,
    "--model", $modelSelection.Model,
    "--agent", $agentSelection.Agent
)

if ($AutoApprove) {
    $opencodeArgs += "--auto"
}

foreach ($file in $AttachFiles) {
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        $opencodeArgs += "--file"
        $opencodeArgs += $file
    }
}

$opencodeArgs += $Prompt

Write-Host "Workdir: $resolvedWorkdir"
Write-Host "OpenCode: $opencodePath"
Write-Host "RunId: $($runContext.RunId)"
Write-Host "OutputFormat: $OutputFormat"
Write-Host "AutoApprove: $AutoApprove"
Write-Host "Model: $($modelSelection.Model)"
Write-Host "ModelIntent: $ModelIntent"
Write-Host "ModelReason: $($modelSelection.Reason)"
Write-Host "Agent: $($agentSelection.Agent)"
Write-Host "AgentReason: $($agentSelection.Reason)"
Write-Host "ProviderPreference: $($ProviderPreference -join ',')"
Write-Host "AllowPaidFallback: $AllowPaidFallback"
Write-Host "AttachFiles: $(if ($AttachFiles.Count -gt 0) { $AttachFiles -join ',' } else { 'none' })"
Write-Host "MaxTurns: $MaxTurns"
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
    Write-Host "WhatIf: would run opencode with arguments:"
    $opencodeArgs | ForEach-Object { Write-Host "  $_" }
    exit 0
}

Push-Location -LiteralPath $resolvedWorkdir
try {
    $attempt = 1
    $exitCode = 1

    while ($attempt -le $MaxTurns) {
        Write-Host "OpenCode attempt $attempt of $MaxTurns"

        $exitCode = Invoke-DelegateAttempt `
            -Label "OpenCode" `
            -FilePath $opencodePath `
            -Arguments $opencodeArgs `
            -StdoutPath $stdoutLog `
            -StderrPath $stderrLog `
            -Timeout $TimeoutSeconds `
            -IdleTimeout $IdleTimeoutSeconds `
            -Poll $PollSeconds `
            -StatusInterval $StatusSeconds

        if ($exitCode -eq 0) {
            break
        }

        if ($exitCode -eq 124 -or $exitCode -eq 125) {
            Write-Warning "OpenCode was stopped due to timeout/idle detection. Codex should inspect the diff before deciding whether to continue."
            break
        }

        Write-Warning "OpenCode exited with code $exitCode."
        if ($attempt -lt $MaxTurns) {
            Write-Host "Retrying the same bounded prompt. Codex should prefer targeted correction prompts for semantic failures."
        }

        $attempt++
    }

    if ($FullLog -or $OutputFormat -ne "json" -or $PrintRawJsonTail) {
        Write-DelegateLogs -Label "OpenCode" -StdoutPath $stdoutLog -StderrPath $stderrLog -TailLines $TailLines -FullLog ([bool]$FullLog)
    }
    else {
        Write-Host ""
        Write-OpencodeJsonSummary -StdoutPath $stdoutLog -TailLines $TailLines
        Write-Host ""
        Write-Host "OpenCode stderr tail ($TailLines lines):"
        if (Test-Path -LiteralPath $stderrLog) {
            Get-Content -LiteralPath $stderrLog -Tail $TailLines
        }
    }
    Write-DelegatePostRunStatus -Workdir $resolvedWorkdir

    exit $exitCode
}
finally {
    Pop-Location
}
