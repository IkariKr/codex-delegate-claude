Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$requiredFiles = @(
    "shared\scripts\DelegateCommon.psm1",
    "scripts\run_claude_delegate.ps1",
    "backends\opencode\run_opencode_delegate.ps1",
    "backends\agent\run_delegate_agent.ps1",
    "backends\agent\manage_auto_routing.ps1",
    "backends\agent\AutoRoutingCommon.psm1",
    "backends\agent\auto-routing.default.json",
    "packages\codex-delegate-opencode\scripts\run_opencode_delegate.ps1",
    "packages\codex-delegate-opencode\shared\scripts\DelegateCommon.psm1",
    "packages\codex-delegate-agent\scripts\run_delegate_agent.ps1",
    "packages\codex-delegate-agent\scripts\manage_auto_routing.ps1",
    "packages\codex-delegate-agent\scripts\AutoRoutingCommon.psm1",
    "packages\codex-delegate-agent\scripts\run_claude_delegate.ps1",
    "packages\codex-delegate-agent\scripts\run_opencode_delegate.ps1",
    "packages\codex-delegate-agent\shared\scripts\DelegateCommon.psm1",
    "packages\codex-delegate-agent\auto-routing.default.json",
    "SKILL.md",
    "agents\openai.yaml",
    "packages\codex-delegate-opencode\SKILL.md",
    "packages\codex-delegate-opencode\agents\openai.yaml",
    "packages\codex-delegate-agent\SKILL.md",
    "packages\codex-delegate-agent\agents\openai.yaml"
)

$missing = @()
foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        $missing += $relativePath
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Missing required files:`n$($missing -join "`n")"
}

$rootModule = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "shared\scripts\DelegateCommon.psm1")
$packageModule = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-opencode\shared\scripts\DelegateCommon.psm1")
if ($rootModule -ne $packageModule) {
    Write-Error "Shared module copy is out of sync. Run scripts/build-packages.ps1."
}

$agentModule = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-agent\shared\scripts\DelegateCommon.psm1")
if ($rootModule -ne $agentModule) {
    Write-Error "Unified agent shared module copy is out of sync. Run scripts/build-packages.ps1."
}

$opencodeSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "backends\opencode\run_opencode_delegate.ps1")
$opencodePackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-opencode\scripts\run_opencode_delegate.ps1")
if ($opencodeSource -ne $opencodePackage) {
    Write-Error "OpenCode package script is out of sync. Run scripts/build-packages.ps1."
}

$agentSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "backends\agent\run_delegate_agent.ps1")
$agentPackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-agent\scripts\run_delegate_agent.ps1")
if ($agentSource -ne $agentPackage) {
    Write-Error "Unified agent package script is out of sync. Run scripts/build-packages.ps1."
}

$agentManageSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "backends\agent\manage_auto_routing.ps1")
$agentManagePackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-agent\scripts\manage_auto_routing.ps1")
if ($agentManageSource -ne $agentManagePackage) {
    Write-Error "Unified agent routing management script is out of sync. Run scripts/build-packages.ps1."
}

$agentRoutingModuleSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "backends\agent\AutoRoutingCommon.psm1")
$agentRoutingModulePackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-agent\scripts\AutoRoutingCommon.psm1")
if ($agentRoutingModuleSource -ne $agentRoutingModulePackage) {
    Write-Error "Unified agent routing module is out of sync. Run scripts/build-packages.ps1."
}

$routingSource = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "backends\agent\auto-routing.default.json")
$routingPackage = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "packages\codex-delegate-agent\auto-routing.default.json")
if ($routingSource -ne $routingPackage) {
    Write-Error "Unified agent routing config is out of sync. Run scripts/build-packages.ps1."
}

Write-Host "Package validation passed."
