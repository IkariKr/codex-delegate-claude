Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-OrderedRoutingValue {
    param([Parameter(ValueFromPipeline = $true)]$InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [string] -or $InputObject -is [ValueType]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputObject.Keys) {
            $result[$key] = ConvertTo-OrderedRoutingValue $InputObject[$key]
        }
        return $result
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $result = @()
        foreach ($item in $InputObject) {
            $result += ,(ConvertTo-OrderedRoutingValue $item)
        }
        return $result
    }

    $propertyBag = [ordered]@{}
    foreach ($property in $InputObject.PSObject.Properties) {
        $propertyBag[$property.Name] = ConvertTo-OrderedRoutingValue $property.Value
    }
    return $propertyBag
}

function Get-DelegateAgentPackageRoot {
    $localCandidate = Join-Path $PSScriptRoot "auto-routing.default.json"
    if (Test-Path -LiteralPath $localCandidate) {
        return (Resolve-Path -LiteralPath $PSScriptRoot).Path
    }

    $parentPath = Resolve-Path (Join-Path $PSScriptRoot "..")
    $parentCandidate = Join-Path $parentPath "auto-routing.default.json"
    if (Test-Path -LiteralPath $parentCandidate) {
        return $parentPath.Path
    }

    throw "Unable to locate delegate agent package root from '$PSScriptRoot'."
}

function Get-DefaultUserRoutingConfigPath {
    param([Parameter(Mandatory = $true)][string]$Workdir)

    return (Join-Path $Workdir ".codex-delegate-agent\routing.json")
}

function Get-DefaultAutoConfigSearchPaths {
    param([Parameter(Mandatory = $true)][string]$PackageRoot, [Parameter(Mandatory = $true)][string]$Workdir)

    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add((Get-DefaultUserRoutingConfigPath -Workdir $Workdir))
    $paths.Add((Join-Path $Workdir ".codex-delegate-agent.json"))
    $paths.Add((Join-Path $PackageRoot "auto-routing.json"))
    $paths.Add((Join-Path $PackageRoot "auto-routing.default.json"))
    return $paths
}

function Get-DefaultTemplateRoutingConfig {
    return [ordered]@{
        version = 1
        defaults = [ordered]@{
            preferred_backend = "claude"
            fallback_backend = "opencode"
            on_no_match = "preferred_backend"
        }
        rules = @()
    }
}

function Normalize-RoutingRule {
    param([Parameter(Mandatory = $true)]$Rule)

    $data = ConvertTo-OrderedRoutingValue $Rule
    $when = if ($data.Contains("when")) { ConvertTo-OrderedRoutingValue $data.when } else { [ordered]@{} }
    $promptAny = if ($when.Contains("prompt_any_regex")) { @($when["prompt_any_regex"]) } else { @() }
    $promptAll = if ($when.Contains("prompt_all_regex")) { @($when["prompt_all_regex"]) } else { @() }
    $workdirAny = if ($when.Contains("workdir_any_regex")) { @($when["workdir_any_regex"]) } else { @() }
    $workdirAll = if ($when.Contains("workdir_all_regex")) { @($when["workdir_all_regex"]) } else { @() }

    return [ordered]@{
        name = if ($data.Contains("name")) { [string]$data.name } else { "" }
        enabled = if ($data.Contains("enabled")) { [bool]$data.enabled } else { $true }
        backend = if ($data.Contains("backend")) { [string]$data.backend } else { "claude" }
        reason = if ($data.Contains("reason")) { [string]$data.reason } else { "" }
        when = [ordered]@{
            prompt_any_regex = @($promptAny | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            prompt_all_regex = @($promptAll | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            workdir_any_regex = @($workdirAny | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            workdir_all_regex = @($workdirAll | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
    }
}

function Normalize-AutoRoutingConfig {
    param($Config)

    $data = if ($null -eq $Config) { Get-DefaultTemplateRoutingConfig } else { ConvertTo-OrderedRoutingValue $Config }
    $defaults = if ($data.Contains("defaults")) { ConvertTo-OrderedRoutingValue $data.defaults } else { [ordered]@{} }
    $rules = @()
    $inputRules = if ($data.Contains("rules")) { @($data["rules"]) } else { @() }
    foreach ($rule in $inputRules) {
        $rules += ,(Normalize-RoutingRule -Rule $rule)
    }

    return [ordered]@{
        version = if ($data.Contains("version")) { [int]$data.version } else { 1 }
        defaults = [ordered]@{
            preferred_backend = if ($defaults.Contains("preferred_backend")) { [string]$defaults.preferred_backend } else { "claude" }
            fallback_backend = if ($defaults.Contains("fallback_backend")) { [string]$defaults.fallback_backend } else { "opencode" }
            on_no_match = if ($defaults.Contains("on_no_match")) { [string]$defaults.on_no_match } else { "preferred_backend" }
        }
        rules = $rules
    }
}

function Load-AutoRoutingConfig {
    param(
        [string]$AutoConfigPath,
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)][string]$Workdir
    )

    $candidatePaths = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($AutoConfigPath)) {
        $candidatePaths.Add($AutoConfigPath)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:CODEX_DELEGATE_AGENT_CONFIG)) {
        $candidatePaths.Add($env:CODEX_DELEGATE_AGENT_CONFIG)
    }

    foreach ($path in (Get-DefaultAutoConfigSearchPaths -PackageRoot $PackageRoot -Workdir $Workdir)) {
        $candidatePaths.Add($path)
    }

    foreach ($candidate in $candidatePaths) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return [pscustomobject]@{
                Path = (Resolve-Path -LiteralPath $candidate).Path
                Config = (Normalize-AutoRoutingConfig (Get-Content -Raw -LiteralPath $candidate | ConvertFrom-Json))
            }
        }
    }

    throw "No auto-routing config file was found."
}

function Save-AutoRoutingConfig {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Config
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $normalized = Normalize-AutoRoutingConfig $Config
    $json = $normalized | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $Path -Value $json
}

function New-DefaultUserRoutingConfig {
    param(
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [switch]$Force
    )

    if ((Test-Path -LiteralPath $DestinationPath) -and -not $Force) {
        throw "Routing config already exists: $DestinationPath"
    }

    $templatePath = Join-Path $PackageRoot "auto-routing.default.json"
    if (-not (Test-Path -LiteralPath $templatePath)) {
        throw "Routing template not found: $templatePath"
    }

    $template = Normalize-AutoRoutingConfig (Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json)
    Save-AutoRoutingConfig -Path $DestinationPath -Config $template
    return (Resolve-Path -LiteralPath $DestinationPath).Path
}

function Get-EditableRoutingConfigPath {
    param(
        [string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$Workdir
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        return $ConfigPath
    }

    return (Get-DefaultUserRoutingConfigPath -Workdir $Workdir)
}

function Get-OrCreateEditableRoutingConfig {
    param(
        [string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [Parameter(Mandatory = $true)][string]$Workdir
    )

    $targetPath = Get-EditableRoutingConfigPath -ConfigPath $ConfigPath -Workdir $Workdir
    if (-not (Test-Path -LiteralPath $targetPath)) {
        $null = New-DefaultUserRoutingConfig -PackageRoot $PackageRoot -DestinationPath $targetPath
    }

    return [pscustomobject]@{
        Path = (Resolve-Path -LiteralPath $targetPath).Path
        Config = (Normalize-AutoRoutingConfig (Get-Content -Raw -LiteralPath $targetPath | ConvertFrom-Json))
    }
}

function Find-RoutingRuleIndex {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)][string]$RuleName
    )

    for ($i = 0; $i -lt @($Config.rules).Count; $i++) {
        if ([string]$Config.rules[$i].name -eq $RuleName) {
            return $i
        }
    }
    return -1
}

function Get-RoutingRuleConditionSummary {
    param([Parameter(Mandatory = $true)]$Rule)

    $parts = @()
    if (@($Rule.when.prompt_any_regex).Count -gt 0) {
        $parts += "prompt_any=" + (@($Rule.when.prompt_any_regex) -join ", ")
    }
    if (@($Rule.when.prompt_all_regex).Count -gt 0) {
        $parts += "prompt_all=" + (@($Rule.when.prompt_all_regex) -join ", ")
    }
    if (@($Rule.when.workdir_any_regex).Count -gt 0) {
        $parts += "workdir_any=" + (@($Rule.when.workdir_any_regex) -join ", ")
    }
    if (@($Rule.when.workdir_all_regex).Count -gt 0) {
        $parts += "workdir_all=" + (@($Rule.when.workdir_all_regex) -join ", ")
    }

    if ($parts.Count -eq 0) {
        return "(no conditions)"
    }

    return ($parts -join " | ")
}

function Test-RegexListMatch {
    param(
        [string]$Value,
        [object[]]$Patterns,
        [string]$Mode = "any"
    )

    if ($null -eq $Patterns -or $Patterns.Count -eq 0) {
        return $true
    }

    $matched = @($Patterns | Where-Object { $Value -match $_ })
    if ($Mode -eq "all") {
        return $matched.Count -eq $Patterns.Count
    }

    return $matched.Count -gt 0
}

function Test-RuleMatches {
    param(
        $Rule,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Workdir
    )

    $ruleData = Normalize-RoutingRule -Rule $Rule
    if (-not $ruleData.enabled) {
        return $false
    }

    if (-not (Test-RegexListMatch -Value $Prompt -Patterns $ruleData.when.prompt_any_regex -Mode "any")) {
        return $false
    }
    if (-not (Test-RegexListMatch -Value $Prompt -Patterns $ruleData.when.prompt_all_regex -Mode "all")) {
        return $false
    }
    if (-not (Test-RegexListMatch -Value $Workdir -Patterns $ruleData.when.workdir_any_regex -Mode "any")) {
        return $false
    }
    if (-not (Test-RegexListMatch -Value $Workdir -Patterns $ruleData.when.workdir_all_regex -Mode "all")) {
        return $false
    }

    return $true
}

function Resolve-AutoConfiguredBackend {
    param(
        [Parameter(Mandatory = $true)]$RoutingConfig,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Workdir,
        [Parameter(Mandatory = $true)][bool]$HasClaude,
        [Parameter(Mandatory = $true)][bool]$HasOpenCode
    )

    $config = Normalize-AutoRoutingConfig $RoutingConfig.Config
    $ruleHit = $null
    foreach ($rule in @($config.rules)) {
        if (Test-RuleMatches -Rule $rule -Prompt $Prompt -Workdir $Workdir) {
            $ruleHit = $rule
            break
        }
    }

    $preferredBackend = $config.defaults.preferred_backend
    $fallbackBackend = $config.defaults.fallback_backend
    $noMatchAction = $config.defaults.on_no_match

    $selectedBackend = $null
    $reason = $null
    if ($ruleHit) {
        $selectedBackend = $ruleHit.backend
        $reason = if ($ruleHit.reason) { [string]$ruleHit.reason } else { "matched rule '$($ruleHit.name)'" }
    }
    else {
        switch ($noMatchAction) {
            "fallback_backend" {
                $selectedBackend = $fallbackBackend
                $reason = "no rule matched; using configured fallback backend"
            }
            default {
                $selectedBackend = $preferredBackend
                $reason = "no rule matched; using configured preferred backend"
            }
        }
    }

    $available = @{
        claude = $HasClaude
        opencode = $HasOpenCode
    }

    if ($available[$selectedBackend]) {
        return [pscustomobject]@{
            Backend = $selectedBackend
            Reason = $reason
            Rule = if ($ruleHit) { $ruleHit.name } else { "" }
            ConfigPath = $RoutingConfig.Path
        }
    }

    $fallbackCandidate = if ($selectedBackend -eq "claude") { "opencode" } else { "claude" }
    if ($available[$fallbackCandidate]) {
        return [pscustomobject]@{
            Backend = $fallbackCandidate
            Reason = "$reason; selected backend unavailable, fell back to $fallbackCandidate"
            Rule = if ($ruleHit) { $ruleHit.name } else { "" }
            ConfigPath = $RoutingConfig.Path
        }
    }

    throw "Neither Claude nor OpenCode was found on PATH."
}

Export-ModuleMember -Function `
    ConvertTo-OrderedRoutingValue, `
    Get-DelegateAgentPackageRoot, `
    Get-DefaultUserRoutingConfigPath, `
    Get-DefaultAutoConfigSearchPaths, `
    Get-DefaultTemplateRoutingConfig, `
    Normalize-RoutingRule, `
    Normalize-AutoRoutingConfig, `
    Load-AutoRoutingConfig, `
    Save-AutoRoutingConfig, `
    New-DefaultUserRoutingConfig, `
    Get-EditableRoutingConfigPath, `
    Get-OrCreateEditableRoutingConfig, `
    Find-RoutingRuleIndex, `
    Get-RoutingRuleConditionSummary, `
    Test-RegexListMatch, `
    Test-RuleMatches, `
    Resolve-AutoConfiguredBackend
