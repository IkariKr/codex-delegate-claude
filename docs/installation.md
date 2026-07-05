# Installation

## Supported Environment

Public `v1` is designed for Windows with PowerShell.

Tested release flows assume:

- Windows
- PowerShell or Windows PowerShell
- `claude` and/or `opencode` available on `PATH`
- a Codex skills directory where this repo or its generated packages can be installed

## Prerequisites

You need:

- Git
- PowerShell
- Claude Code CLI if you want Claude support
- OpenCode CLI if you want OpenCode support

You do not need both backends installed if you only use one backend explicitly, but `codex-delegate-agent` is most useful when both are available.

## Installation Modes

There are two supported installation paths for `v1`.

### Option 1: Clone The Source Repo Into Your Codex Skills Directory

This is the recommended maintainer and power-user path.

1. Clone the repo under your Codex skills directory so the repo root is:

```powershell
<skills-dir>\codex-delegate-claude
```

2. From the repo root, build generated packages:

```powershell
.\scripts\build-packages.ps1
```

3. Create workspace-visible junctions for the generated packages:

```powershell
.\scripts\install-workspace-skill-links.ps1
```

That creates sibling skill entries for:

- `codex-delegate-agent`
- `codex-delegate-opencode`

The repo root itself continues to be the `codex-delegate-claude` skill.

### Option 2: Copy A Generated Package Directly

If you only want the installable package output, copy one of these folders into your Codex skills directory:

- `packages\codex-delegate-agent`
- `packages\codex-delegate-opencode`

Use this path when you want the generated package without keeping the whole source repository in place.

## Verify Backend Prerequisites

From PowerShell, check backend availability:

```powershell
Get-Command claude
Get-Command opencode
```

Expected result:

- if a backend is installed, PowerShell returns its resolved command
- if it is missing, you must install it or avoid selecting that backend explicitly

## Verify Package Build Output

From the repo root:

```powershell
.\scripts\build-packages.ps1
.\scripts\validate-packages.ps1
```

Expected result:

- packages regenerate without error
- validation ends with `Package validation passed.`

## First Runtime Verification

From the generated unified package root:

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Please review this design doc." -Backend auto -WhatIf
```

Expected result:

- the script resolves a backend
- it prints routing reason and, when applicable, routing rule and config path
- `-WhatIf` prevents a real backend run

## Recommended Post-Install Checks

Run these after installation:

```powershell
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
.\scripts\manage_auto_routing_nl.ps1 -Request 'list current routing rules' -Workdir .
```

Expected result:

- the default routing config is visible
- rules print in top-to-bottom order

## What Gets Installed

For `codex-delegate-agent`, the package includes:

- `SKILL.md`
- `agents\openai.yaml`
- `scripts\run_delegate_agent.ps1`
- `scripts\manage_auto_routing.ps1`
- `scripts\manage_auto_routing_nl.ps1`
- `scripts\run_claude_delegate.ps1`
- `scripts\run_opencode_delegate.ps1`
- `auto-routing.default.json`

## Upgrade Procedure

From the repo root:

```powershell
git pull
.\scripts\build-packages.ps1
.\scripts\validate-packages.ps1
```

If you use workspace junctions created by `install-workspace-skill-links.ps1`, no extra copy step is needed after rebuild.

## If Installation Fails

Check:

- `claude` and `opencode` on `PATH`
- your repo path is actually under the skills directory you intended
- `build-packages.ps1` completed successfully
- `validate-packages.ps1` completed successfully

For common issues and fixes, see `docs/troubleshooting.md`.
