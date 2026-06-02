param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Workdir = (Get-Location).Path,

    [ValidateRange(1, 20)]
    [int]$MaxTurns = 3,

    [ValidateSet("acceptEdits", "bypassPermissions", "default", "delegate", "dontAsk", "plan")]
    [string]$PermissionMode = "acceptEdits",

    [ValidateSet("json", "stream-json")]
    [string]$OutputFormat = "json",

    [string[]]$AllowedTools = @(),

    [string[]]$DisallowedTools = @("Bash"),

    [switch]$AllowBash,

    [double]$MaxBudgetUsd = 0,

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

    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Resolve-CommandPath {
    param([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Required command '$CommandName' was not found on PATH."
    }

    return $command.Source
}

function Stop-ProcessTree {
    param([int]$ProcessId)

    $taskkill = Get-Command taskkill.exe -ErrorAction SilentlyContinue
    if ($taskkill) {
        & $taskkill.Source /PID $ProcessId /T /F | Out-Host
        return
    }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $ProcessId -Force
    }
}

function Join-ProcessArguments {
    param([string[]]$Arguments)

    $escaped = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        } else {
            $argument
        }
    }

    return ($escaped -join " ")
}

function Invoke-ClaudeAttempt {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$StdoutPath,
        [string]$StderrPath,
        [int]$Timeout,
        [int]$IdleTimeout,
        [int]$Poll,
        [int]$StatusInterval
    )

    $startTime = Get-Date
    $lastActivityTime = $startTime
    $lastStatusTime = $startTime
    $lastStdoutLength = 0
    $lastStderrLength = 0

    try {
        $argumentLine = Join-ProcessArguments -Arguments $Arguments
        $process = Start-Process `
            -FilePath $FilePath `
            -ArgumentList $argumentLine `
            -WorkingDirectory (Get-Location).Path `
            -RedirectStandardOutput $StdoutPath `
            -RedirectStandardError $StderrPath `
            -NoNewWindow `
            -PassThru

        Write-Host "Claude PID: $($process.Id)"

        while (-not $process.HasExited) {
            $waitMilliseconds = [Math]::Min($Poll * 1000, 1000)
            [void]$process.WaitForExit($waitMilliseconds)

            $now = Get-Date
            $elapsedSeconds = [int]($now - $startTime).TotalSeconds
            $stdoutLength = if (Test-Path -LiteralPath $StdoutPath) { (Get-Item -LiteralPath $StdoutPath).Length } else { 0 }
            $stderrLength = if (Test-Path -LiteralPath $StderrPath) { (Get-Item -LiteralPath $StderrPath).Length } else { 0 }

            if ($stdoutLength -ne $lastStdoutLength -or $stderrLength -ne $lastStderrLength) {
                $lastActivityTime = $now
                $lastStdoutLength = $stdoutLength
                $lastStderrLength = $stderrLength
            }

            $idleSeconds = [int]($now - $lastActivityTime).TotalSeconds

            if (($now - $lastStatusTime).TotalSeconds -ge $StatusInterval) {
                Write-Host "Claude still running: elapsed=${elapsedSeconds}s idle=${idleSeconds}s pid=$($process.Id)"
                $lastStatusTime = $now
            }

            if ($Timeout -gt 0 -and $elapsedSeconds -ge $Timeout) {
                Write-Warning "Claude exceeded TimeoutSeconds=$Timeout. Killing process tree and returning exit code 124."
                Stop-ProcessTree -ProcessId $process.Id
                return 124
            }

            if ($idleSeconds -ge $IdleTimeout) {
                Write-Warning "Claude produced no output for IdleTimeoutSeconds=$IdleTimeout. Killing process tree and returning exit code 125."
                Stop-ProcessTree -ProcessId $process.Id
                return 125
            }
        }

        $process.WaitForExit()
        return $process.ExitCode
    }
    finally {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-ProcessTree -ProcessId $process.Id
        }
    }
}

$resolvedWorkdir = (Resolve-Path -LiteralPath $Workdir).Path
$claudePath = Resolve-CommandPath -CommandName "claude"
$gitPath = Get-Command git -ErrorAction SilentlyContinue
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runId = [System.Guid]::NewGuid().ToString("N").Substring(0, 12)
$logRoot = Join-Path ([System.IO.Path]::GetTempPath()) "codex-delegate-claude"
$stdoutLog = Join-Path $logRoot "claude-$timestamp-$runId.stdout.log"
$stderrLog = Join-Path $logRoot "claude-$timestamp-$runId.stderr.log"

$effectiveDisallowedTools = @($DisallowedTools | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if ($AllowBash) {
    $effectiveDisallowedTools = @($effectiveDisallowedTools | Where-Object { $_ -ne "Bash" })
}

$claudeArgs = @(
    "-p",
    "--permission-mode", $PermissionMode,
    "--output-format", $OutputFormat
)

if ($OutputFormat -eq "stream-json") {
    $claudeArgs += "--verbose"
    $claudeArgs += "--include-partial-messages"
}

if ($AllowedTools.Count -gt 0) {
    $claudeArgs += "--tools=$($AllowedTools -join ',')"
}

if ($effectiveDisallowedTools.Count -gt 0) {
    $claudeArgs += "--disallowedTools=$($effectiveDisallowedTools -join ',')"
}

if ($MaxBudgetUsd -gt 0) {
    $claudeArgs += "--max-budget-usd"
    $claudeArgs += ([string]::Format([Globalization.CultureInfo]::InvariantCulture, "{0}", $MaxBudgetUsd))
}

$claudeArgs += $Prompt

Write-Host "Workdir: $resolvedWorkdir"
Write-Host "Claude: $claudePath"
Write-Host "RunId: $runId"
Write-Host "PermissionMode: $PermissionMode"
Write-Host "OutputFormat: $OutputFormat"
Write-Host "AllowedTools: $(if ($AllowedTools.Count -gt 0) { $AllowedTools -join ',' } else { 'default' })"
Write-Host "DisallowedTools: $(if ($effectiveDisallowedTools.Count -gt 0) { $effectiveDisallowedTools -join ',' } else { 'none' })"
Write-Host "MaxBudgetUsd: $(if ($MaxBudgetUsd -gt 0) { [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $MaxBudgetUsd) } else { 'disabled' })"
Write-Host "MaxTurns: $MaxTurns"
if ($TimeoutSeconds -gt 0) {
    Write-Host "TimeoutSeconds: $TimeoutSeconds"
} else {
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
    Write-Host "WhatIf: would run claude with arguments:"
    $claudeArgs | ForEach-Object { Write-Host "  $_" }
    exit 0
}

if (-not (Test-Path -LiteralPath $logRoot)) {
    New-Item -ItemType Directory -Path $logRoot | Out-Null
}

Push-Location -LiteralPath $resolvedWorkdir
try {
    $attempt = 1
    $exitCode = 1

    while ($attempt -le $MaxTurns) {
        Write-Host "Claude attempt $attempt of $MaxTurns"

        $exitCode = Invoke-ClaudeAttempt `
            -FilePath $claudePath `
            -Arguments $claudeArgs `
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
            Write-Warning "Claude was stopped due to timeout/idle detection. Codex should inspect the diff before deciding whether to continue."
            break
        }

        Write-Warning "Claude exited with code $exitCode."
        if ($attempt -lt $MaxTurns) {
            Write-Host "Retrying the same bounded prompt. Codex should prefer targeted correction prompts for semantic failures."
        }

        $attempt++
    }

    Write-Host ""
    if ($FullLog) {
        Write-Host "Claude stdout:"
    } else {
        Write-Host "Claude stdout tail ($TailLines lines):"
    }
    if (Test-Path -LiteralPath $stdoutLog) {
        if ($FullLog) {
            Get-Content -LiteralPath $stdoutLog
        } else {
            Get-Content -LiteralPath $stdoutLog -Tail $TailLines
        }
    }

    Write-Host ""
    if ($FullLog) {
        Write-Host "Claude stderr:"
    } else {
        Write-Host "Claude stderr tail ($TailLines lines):"
    }
    if (Test-Path -LiteralPath $stderrLog) {
        if ($FullLog) {
            Get-Content -LiteralPath $stderrLog
        } else {
            Get-Content -LiteralPath $stderrLog -Tail $TailLines
        }
    }

    Write-Host ""
    Write-Host "Post-run git status:"
    if ($gitPath) {
        & $gitPath.Source status --short
    } else {
        Write-Host "git not found on PATH."
    }

    exit $exitCode
}
finally {
    Pop-Location
}
