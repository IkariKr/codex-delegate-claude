param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [ValidateSet("auto", "claude", "opencode")]
    [string]$Backend = "auto",

    [ValidateSet("config", "prefer-claude", "prefer-opencode")]
    [string]$AutoStrategy = "config",

    [string]$AutoConfigPath = "",

    [string]$Workdir = (Get-Location).Path,

    [ValidateRange(1, 20)]
    [int]$MaxTurns = 3,

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

    [switch]$WhatIf,

    [ValidateSet("acceptEdits", "bypassPermissions", "default", "delegate", "dontAsk", "plan")]
    [string]$ClaudePermissionMode = "acceptEdits",

    [ValidateSet("json", "stream-json")]
    [string]$ClaudeOutputFormat = "json",

    [string[]]$ClaudeAllowedTools = @(),

    [string[]]$ClaudeDisallowedTools = @("Bash"),

    [switch]$ClaudeAllowBash,

    [double]$ClaudeMaxBudgetUsd = 0,

    [ValidateSet("default", "json")]
    [string]$OpencodeOutputFormat = "json",

    [string]$OpencodeModel = "",

    [ValidateSet("auto", "small", "coding", "hard", "review", "docs")]
    [string]$OpencodeModelIntent = "coding",

    [string[]]$OpencodeProviderPreference = @("opencode"),

    [switch]$OpencodeAllowPaidFallback,

    [switch]$OpencodeRefreshModels,

    [string]$OpencodeAgent = "",

    [string[]]$OpencodeAttachFiles = @(),

    [bool]$OpencodeAutoApprove = $true,

    [switch]$OpencodePrintRawJsonTail
)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path $PSScriptRoot "AutoRoutingCommon.psm1"
Import-Module $modulePath -Force -DisableNameChecking

function Test-AvailableCommand {
    param([Parameter(Mandatory = $true)][string]$CommandName)

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-DelegateBackendScriptPath {
    param([Parameter(Mandatory = $true)][string]$BackendName)

    $scriptName = "run_{0}_delegate.ps1" -f $BackendName
    $candidates = @(
        (Join-Path $PSScriptRoot $scriptName),
        (Join-Path (Join-Path $PSScriptRoot "..\$BackendName") $scriptName),
        (Join-Path (Join-Path $PSScriptRoot "..\..\scripts") $scriptName)
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Unable to locate backend runner script '$scriptName' from '$PSScriptRoot'."
}

function Resolve-DelegateBackend {
    param(
        [Parameter(Mandatory = $true)][string]$RequestedBackend,
        [Parameter(Mandatory = $true)][string]$AutoStrategy,
        [string]$AutoConfigPath,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Workdir,
        [Parameter(Mandatory = $true)][string]$PackageRoot
    )

    $hasClaude = Test-AvailableCommand -CommandName "claude"
    $hasOpenCode = Test-AvailableCommand -CommandName "opencode"

    if ($RequestedBackend -ne "auto") {
        if ($RequestedBackend -eq "claude" -and -not $hasClaude) {
            throw "Claude was explicitly requested, but 'claude' was not found on PATH."
        }
        if ($RequestedBackend -eq "opencode" -and -not $hasOpenCode) {
            throw "OpenCode was explicitly requested, but 'opencode' was not found on PATH."
        }

        return [pscustomobject]@{
            Backend = $RequestedBackend
            Reason = "explicit backend requested"
            Rule = ""
            ConfigPath = ""
        }
    }

    if ($AutoStrategy -eq "config") {
        $routingConfig = Load-AutoRoutingConfig -AutoConfigPath $AutoConfigPath -PackageRoot $PackageRoot -Workdir $Workdir
        return (Resolve-AutoConfiguredBackend `
            -RoutingConfig $routingConfig `
            -Prompt $Prompt `
            -Workdir $Workdir `
            -HasClaude $hasClaude `
            -HasOpenCode $hasOpenCode)
    }

    switch ($AutoStrategy) {
        "prefer-opencode" {
            if ($hasOpenCode) {
                return [pscustomobject]@{
                    Backend = "opencode"
                    Reason = "auto strategy prefer-opencode"
                    Rule = ""
                    ConfigPath = ""
                }
            }
            if ($hasClaude) {
                return [pscustomobject]@{
                    Backend = "claude"
                    Reason = "auto strategy prefer-opencode fell back to Claude"
                    Rule = ""
                    ConfigPath = ""
                }
            }
        }
        default {
            if ($hasClaude) {
                return [pscustomobject]@{
                    Backend = "claude"
                    Reason = "auto strategy prefer-claude"
                    Rule = ""
                    ConfigPath = ""
                }
            }
            if ($hasOpenCode) {
                return [pscustomobject]@{
                    Backend = "opencode"
                    Reason = "auto strategy prefer-claude fell back to OpenCode"
                    Rule = ""
                    ConfigPath = ""
                }
            }
        }
    }

    throw "Neither Claude nor OpenCode was found on PATH."
}

$packageRoot = Get-DelegateAgentPackageRoot
$resolvedWorkdir = (Resolve-Path -LiteralPath $Workdir).Path
$resolution = Resolve-DelegateBackend `
    -RequestedBackend $Backend `
    -AutoStrategy $AutoStrategy `
    -AutoConfigPath $AutoConfigPath `
    -Prompt $Prompt `
    -Workdir $resolvedWorkdir `
    -PackageRoot $packageRoot
$claudeScript = Get-DelegateBackendScriptPath -BackendName "claude"
$opencodeScript = Get-DelegateBackendScriptPath -BackendName "opencode"

Write-Host "Resolved backend: $($resolution.Backend)"
Write-Host "AutoStrategy: $AutoStrategy"
Write-Host "RoutingReason: $($resolution.Reason)"
if (-not [string]::IsNullOrWhiteSpace($resolution.Rule)) {
    Write-Host "RoutingRule: $($resolution.Rule)"
}
if (-not [string]::IsNullOrWhiteSpace($resolution.ConfigPath)) {
    Write-Host "RoutingConfig: $($resolution.ConfigPath)"
}

if ($resolution.Backend -eq "claude") {
    $claudeParams = @{
        Prompt = $Prompt
        Workdir = $resolvedWorkdir
        MaxTurns = $MaxTurns
        PermissionMode = $ClaudePermissionMode
        OutputFormat = $ClaudeOutputFormat
        AllowedTools = $ClaudeAllowedTools
        DisallowedTools = $ClaudeDisallowedTools
        MaxBudgetUsd = $ClaudeMaxBudgetUsd
        TimeoutSeconds = $TimeoutSeconds
        IdleTimeoutSeconds = $IdleTimeoutSeconds
        PollSeconds = $PollSeconds
        StatusSeconds = $StatusSeconds
        TailLines = $TailLines
        FullLog = $FullLog
        WhatIf = $WhatIf
    }

    if ($ClaudeAllowBash) {
        $claudeParams.AllowBash = $true
    }

    & $claudeScript @claudeParams
    exit $LASTEXITCODE
}

$opencodeParams = @{
    Prompt = $Prompt
    Workdir = $resolvedWorkdir
    MaxTurns = $MaxTurns
    OutputFormat = $OpencodeOutputFormat
    Model = $OpencodeModel
    ModelIntent = $OpencodeModelIntent
    ProviderPreference = $OpencodeProviderPreference
    Agent = $OpencodeAgent
    AttachFiles = $OpencodeAttachFiles
    AutoApprove = $OpencodeAutoApprove
    TimeoutSeconds = $TimeoutSeconds
    IdleTimeoutSeconds = $IdleTimeoutSeconds
    PollSeconds = $PollSeconds
    StatusSeconds = $StatusSeconds
    TailLines = $TailLines
    FullLog = $FullLog
    WhatIf = $WhatIf
    PrintRawJsonTail = $OpencodePrintRawJsonTail
}

if ($OpencodeAllowPaidFallback) {
    $opencodeParams.AllowPaidFallback = $true
}

if ($OpencodeRefreshModels) {
    $opencodeParams.RefreshModels = $true
}

& $opencodeScript @opencodeParams
exit $LASTEXITCODE
