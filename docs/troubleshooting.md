# Troubleshooting

## Start Here

When something looks wrong, begin with:

```powershell
.\scripts\build-packages.ps1
.\scripts\validate-packages.ps1
```

Then move to the package you are actually using and run:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "diagnostic prompt" -Backend auto -WhatIf
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "diagnostic prompt"
```

Those three commands usually tell you whether the problem is install, routing, or backend availability.

## `claude` Was Not Found On PATH

Symptom:

- explicit Claude runs fail
- auto routing falls away from Claude or errors when Claude is the only expected backend

Check:

```powershell
Get-Command claude
```

Fix:

- install the Claude CLI
- make sure its command is visible on `PATH`
- restart the shell if needed

## `opencode` Was Not Found On PATH

Symptom:

- explicit OpenCode runs fail
- OpenCode routing cannot execute

Check:

```powershell
Get-Command opencode
```

Fix:

- install the OpenCode CLI
- make sure its command is visible on `PATH`
- restart the shell if needed

## Auto Routing Picked The Wrong Backend

Start with:

```powershell
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "your real prompt here"
```

Look for:

- `RoutingConfig`
- `ResolvedBackend`
- `RoutingReason`
- `RoutingRule`

Common causes:

- an earlier rule matched before the rule you expected
- you were using a different config source than you thought
- explicit `-Backend claude|opencode` overrode auto routing

## My New Rule Did Not Take Effect

Most common cause in `v1`:

- new rules are appended at the end
- an earlier enabled rule already matches the same prompt

Fix flow:

1. run `list`
2. run `explain`
3. move the rule upward manually in `.codex-delegate-agent\routing.json` if needed

## The Natural-Language Wrapper Did Not Parse My Request

The `v1` natural-language wrapper is intentionally constrained.

Best practice:

- keep the action clear: `list`, `explain`, `add`, `update`, `disable`, `enable`, `remove`
- use labeled fields such as:
  - `rule:`
  - `backend:`
  - `reason:`
  - `prompt keywords:`
  - `workdir keywords:`

Example:

```powershell
.\scripts\manage_auto_routing_nl.ps1 -Request 'add rule: "quick-local", backend: opencode, reason: quick local routing, prompt keywords: quick, fix, minor' -Workdir . -Apply
```

If you want exact control, switch to `manage_auto_routing.ps1`.

## `validate-packages.ps1` Failed

This usually means generated files are out of sync with source-of-truth files.

Fix:

```powershell
.\scripts\build-packages.ps1
.\scripts\validate-packages.ps1
```

If it still fails, inspect the reported file path and confirm whether a source file changed without regenerating packages.

## A Generated Package Is Missing A Script

Fix:

```powershell
.\scripts\build-packages.ps1
```

Then verify:

```powershell
.\scripts\validate-packages.ps1
```

Generated packages should include the runtime scripts and shared modules they need.

## OpenCode Model Selection Looks Unexpected

The OpenCode backend can choose models based on:

- `-Model`
- `-ModelIntent`
- `-ProviderPreference`
- `-AllowPaidFallback`

Use `-WhatIf` to inspect what would run:

```powershell
.\scripts\run_opencode_delegate.ps1 -Prompt "Implement a quick fix." -WhatIf
```

Or through the unified agent:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "Implement a quick fix." -Backend opencode -WhatIf
```

Look for:

- `Model`
- `ModelIntent`
- `ModelReason`
- `ProviderPreference`
- `AllowPaidFallback`

## Backend Ran But I Need Logs

The runtime scripts print:

- `StdoutLog`
- `StderrLog`

Use those printed paths first.

If you need a longer tail, rerun with:

```powershell
-FullLog
```

or adjust:

```powershell
-TailLines
```

## `No auto-routing config file was found`

This should not happen in a normal generated package install because the package carries `auto-routing.default.json`.

If it does happen:

- confirm you are using a complete generated package
- confirm `auto-routing.default.json` exists next to the package root
- rebuild packages from source if you are in the repo

## PowerShell Script Execution Is Blocked

If your environment blocks local scripts, you may need an execution policy adjustment in your own shell context.

A common local-only approach is:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

Then rerun the command in that shell session.

## I Do Not Know Which Package To Install

Use:

- `codex-delegate-agent` by default
- `codex-delegate-claude` only if you want Claude-only behavior
- `codex-delegate-opencode` only if you want OpenCode-only behavior

See `docs/package-selection.md` for the detailed comparison.

## Still Stuck

Capture these before asking for help:

1. exact command you ran
2. whether you ran from repo root or generated package root
3. output of `Get-Command claude`
4. output of `Get-Command opencode`
5. output of `validate-packages.ps1`
6. output of `manage_auto_routing.ps1 -Action list`
7. output of `manage_auto_routing.ps1 -Action explain`

That set usually shortens diagnosis dramatically.
