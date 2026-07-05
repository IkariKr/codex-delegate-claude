param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("list", "explain", "init-user-config", "add", "update", "enable", "disable", "remove")]
    [string]$Action,

    [string]$Workdir = (Get-Location).Path,

    [string]$ConfigPath = "",

    [string]$Prompt = "",

    [string]$RuleName = "",

    [ValidateSet("claude", "opencode")]
    [string]$Backend = "",

    [string]$Reason = "",

    [string[]]$PromptAnyRegex = @(),

    [string[]]$PromptAllRegex = @(),

    [string[]]$WorkdirAnyRegex = @(),

    [string[]]$WorkdirAllRegex = @(),

    [Nullable[bool]]$Enabled = $null,

    [switch]$Force
)

$ErrorActionPreference = "Stop"
$modulePath = Join-Path $PSScriptRoot "AutoRoutingCommon.psm1"
Import-Module $modulePath -Force -DisableNameChecking

function Test-AvailableCommand {
    param([Parameter(Mandatory = $true)][string]$CommandName)

    return $null -ne (Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Assert-RuleNameRequired {
    param([string]$Value, [string]$ActionName)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "RuleName is required for action '$ActionName'."
    }
}

function New-UserManagedRule {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Backend,
        [string]$Reason,
        [string[]]$PromptAnyRegex,
        [string[]]$PromptAllRegex,
        [string[]]$WorkdirAnyRegex,
        [string[]]$WorkdirAllRegex,
        [Nullable[bool]]$Enabled
    )

    return (Normalize-RoutingRule @{
        name = $Name
        enabled = if ($null -eq $Enabled) { $true } else { [bool]$Enabled }
        backend = $Backend
        reason = if ([string]::IsNullOrWhiteSpace($Reason)) { "user-defined rule" } else { $Reason }
        when = @{
            prompt_any_regex = $PromptAnyRegex
            prompt_all_regex = $PromptAllRegex
            workdir_any_regex = $WorkdirAnyRegex
            workdir_all_regex = $WorkdirAllRegex
        }
    })
}

function Write-RoutingConfigList {
    param([Parameter(Mandatory = $true)]$LoadedConfig)

    Write-Host "RoutingConfig: $($LoadedConfig.Path)"
    Write-Host "Defaults: preferred=$($LoadedConfig.Config.defaults.preferred_backend) fallback=$($LoadedConfig.Config.defaults.fallback_backend) on_no_match=$($LoadedConfig.Config.defaults.on_no_match)"
    Write-Host "Rules:"

    $rules = @($LoadedConfig.Config.rules)
    if ($rules.Count -eq 0) {
        Write-Host "  (no rules)"
        return
    }

    for ($i = 0; $i -lt $rules.Count; $i++) {
        $rule = Normalize-RoutingRule $rules[$i]
        $status = if ($rule.enabled) { "enabled" } else { "disabled" }
        $summary = Get-RoutingRuleConditionSummary -Rule $rule
        Write-Host "  [$($i + 1)] $status $($rule.backend) $($rule.name)"
        Write-Host "      reason: $($rule.reason)"
        Write-Host "      when:   $summary"
    }
}

function Write-RoutingExplanation {
    param(
        [Parameter(Mandatory = $true)]$LoadedConfig,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Workdir
    )

    $decision = Resolve-AutoConfiguredBackend `
        -RoutingConfig $LoadedConfig `
        -Prompt $Prompt `
        -Workdir $Workdir `
        -HasClaude (Test-AvailableCommand -CommandName "claude") `
        -HasOpenCode (Test-AvailableCommand -CommandName "opencode")

    Write-Host "RoutingConfig: $($decision.ConfigPath)"
    Write-Host "ResolvedBackend: $($decision.Backend)"
    Write-Host "RoutingReason: $($decision.Reason)"
    if (-not [string]::IsNullOrWhiteSpace($decision.Rule)) {
        Write-Host "RoutingRule: $($decision.Rule)"
    }
}

$packageRoot = Get-DelegateAgentPackageRoot
$resolvedWorkdir = (Resolve-Path -LiteralPath $Workdir).Path

switch ($Action) {
    "list" {
        $loaded = Load-AutoRoutingConfig -AutoConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        Write-RoutingConfigList -LoadedConfig $loaded
        break
    }
    "explain" {
        if ([string]::IsNullOrWhiteSpace($Prompt)) {
            throw "Prompt is required for action 'explain'."
        }
        $loaded = Load-AutoRoutingConfig -AutoConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        Write-RoutingExplanation -LoadedConfig $loaded -Prompt $Prompt -Workdir $resolvedWorkdir
        break
    }
    "init-user-config" {
        $targetPath = Get-EditableRoutingConfigPath -ConfigPath $ConfigPath -Workdir $resolvedWorkdir
        $createdPath = New-DefaultUserRoutingConfig -PackageRoot $packageRoot -DestinationPath $targetPath -Force:$Force
        Write-Host "Created routing config: $createdPath"
        break
    }
    "add" {
        Assert-RuleNameRequired -Value $RuleName -ActionName $Action
        if ([string]::IsNullOrWhiteSpace($Backend)) {
            throw "Backend is required for action 'add'."
        }
        $editable = Get-OrCreateEditableRoutingConfig -ConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        if ((Find-RoutingRuleIndex -Config $editable.Config -RuleName $RuleName) -ge 0) {
            throw "Rule already exists: $RuleName"
        }

        $rule = New-UserManagedRule `
            -Name $RuleName `
            -Backend $Backend `
            -Reason $Reason `
            -PromptAnyRegex $PromptAnyRegex `
            -PromptAllRegex $PromptAllRegex `
            -WorkdirAnyRegex $WorkdirAnyRegex `
            -WorkdirAllRegex $WorkdirAllRegex `
            -Enabled $Enabled
        $editable.Config.rules = @($editable.Config.rules) + @($rule)
        Save-AutoRoutingConfig -Path $editable.Path -Config $editable.Config
        Write-Host "Added rule '$RuleName' to $($editable.Path)"
        break
    }
    "update" {
        Assert-RuleNameRequired -Value $RuleName -ActionName $Action
        $editable = Get-OrCreateEditableRoutingConfig -ConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        $index = Find-RoutingRuleIndex -Config $editable.Config -RuleName $RuleName
        if ($index -lt 0) {
            throw "Rule not found: $RuleName"
        }

        $rule = Normalize-RoutingRule $editable.Config.rules[$index]
        if ($PSBoundParameters.ContainsKey("Backend") -and -not [string]::IsNullOrWhiteSpace($Backend)) {
            $rule.backend = $Backend
        }
        if ($PSBoundParameters.ContainsKey("Reason")) {
            $rule.reason = $Reason
        }
        if ($PSBoundParameters.ContainsKey("PromptAnyRegex")) {
            $rule.when.prompt_any_regex = @($PromptAnyRegex)
        }
        if ($PSBoundParameters.ContainsKey("PromptAllRegex")) {
            $rule.when.prompt_all_regex = @($PromptAllRegex)
        }
        if ($PSBoundParameters.ContainsKey("WorkdirAnyRegex")) {
            $rule.when.workdir_any_regex = @($WorkdirAnyRegex)
        }
        if ($PSBoundParameters.ContainsKey("WorkdirAllRegex")) {
            $rule.when.workdir_all_regex = @($WorkdirAllRegex)
        }
        if ($PSBoundParameters.ContainsKey("Enabled")) {
            $rule.enabled = [bool]$Enabled
        }

        $editable.Config.rules[$index] = Normalize-RoutingRule $rule
        Save-AutoRoutingConfig -Path $editable.Path -Config $editable.Config
        Write-Host "Updated rule '$RuleName' in $($editable.Path)"
        break
    }
    "enable" {
        Assert-RuleNameRequired -Value $RuleName -ActionName $Action
        $editable = Get-OrCreateEditableRoutingConfig -ConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        $index = Find-RoutingRuleIndex -Config $editable.Config -RuleName $RuleName
        if ($index -lt 0) {
            throw "Rule not found: $RuleName"
        }
        $rule = Normalize-RoutingRule $editable.Config.rules[$index]
        $rule.enabled = $true
        $editable.Config.rules[$index] = $rule
        Save-AutoRoutingConfig -Path $editable.Path -Config $editable.Config
        Write-Host "Enabled rule '$RuleName' in $($editable.Path)"
        break
    }
    "disable" {
        Assert-RuleNameRequired -Value $RuleName -ActionName $Action
        $editable = Get-OrCreateEditableRoutingConfig -ConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        $index = Find-RoutingRuleIndex -Config $editable.Config -RuleName $RuleName
        if ($index -lt 0) {
            throw "Rule not found: $RuleName"
        }
        $rule = Normalize-RoutingRule $editable.Config.rules[$index]
        $rule.enabled = $false
        $editable.Config.rules[$index] = $rule
        Save-AutoRoutingConfig -Path $editable.Path -Config $editable.Config
        Write-Host "Disabled rule '$RuleName' in $($editable.Path)"
        break
    }
    "remove" {
        Assert-RuleNameRequired -Value $RuleName -ActionName $Action
        $editable = Get-OrCreateEditableRoutingConfig -ConfigPath $ConfigPath -PackageRoot $packageRoot -Workdir $resolvedWorkdir
        $index = Find-RoutingRuleIndex -Config $editable.Config -RuleName $RuleName
        if ($index -lt 0) {
            throw "Rule not found: $RuleName"
        }
        $editable.Config.rules = @(
            for ($i = 0; $i -lt @($editable.Config.rules).Count; $i++) {
                if ($i -ne $index) {
                    $editable.Config.rules[$i]
                }
            }
        )
        Save-AutoRoutingConfig -Path $editable.Path -Config $editable.Config
        Write-Host "Removed rule '$RuleName' from $($editable.Path)"
        break
    }
}
