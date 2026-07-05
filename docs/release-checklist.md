# Release Checklist

## Versioning Convention

Public releases use semantic versioning with a `v` prefix:

- `v1.0.0`: first public stable release
- `v1.0.1`: backward-compatible fix release
- `v1.1.0`: backward-compatible feature or documentation release
- `v2.0.0`: breaking public-surface change

For `v1`, the public surface includes:

- package names
- primary runtime and rule-management scripts
- routing config schema documented in `docs/routing-guide.md`

## Release Notes Convention

Each public release should ship notes that include:

1. what the release is
2. default package recommendation
3. key user-facing features
4. installation or migration notes
5. known limitations

For `v1.0.0`, use `docs/v1.0.0-release-notes.md`.

## Pre-Release Sanity

Before starting the release sequence:

- confirm `main` is the intended release branch
- confirm no unrelated working tree changes exist
- confirm required docs exist

## Required Documents

These docs must exist before `v1.0.0`:

- `docs/v1-roadmap.md`
- `docs/package-selection.md`
- `docs/installation.md`
- `docs/quickstart.md`
- `docs/routing-guide.md`
- `docs/troubleshooting.md`
- `docs/release-checklist.md`
- `docs/v1.0.0-release-notes.md`

## Build And Validation

From the repo root:

```powershell
.\scripts\build-packages.ps1
.\scripts\validate-packages.ps1
```

Expected result:

- package generation succeeds
- validation ends with `Package validation passed.`

## Release Smoke Tests

Run these from a clean generated package path.

### 1. Unified Agent Auto Routing

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Please review this architecture plan." -Backend auto -WhatIf
```

Pass criteria:

- backend resolves successfully
- routing reason prints
- config path prints when auto routing is used

### 2. Explicit Claude Override

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "Review this design." -Backend claude -WhatIf
```

Pass criteria:

- runtime reports Claude as selected backend
- reason reports explicit backend selection

### 3. Explicit OpenCode Override

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "Make a quick fix." -Backend opencode -WhatIf
```

Pass criteria:

- runtime reports OpenCode as selected backend
- backend-specific preview prints

### 4. Structured Routing Inspection

```powershell
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "Need a quick fix for this minor bug."
```

Pass criteria:

- current config source prints
- matched rule and resolved backend print

### 5. Natural-Language Routing Inspection

```powershell
.\scripts\manage_auto_routing_nl.ps1 -Request 'list current routing rules' -Workdir .
.\scripts\manage_auto_routing_nl.ps1 -Request 'explain prompt: "Need a quick fix for this minor bug."' -Workdir .
```

Pass criteria:

- interpreted action prints
- translated management command prints
- downstream result matches structured behavior

### 6. Workspace Config Mutation

Use a temporary workdir:

```powershell
.\scripts\manage_auto_routing_nl.ps1 -Request 'add rule: "quick-local", backend: opencode, reason: quick local routing, prompt keywords: quick, fix, minor' -Workdir <temp-workdir> -Apply
.\scripts\manage_auto_routing.ps1 -Action list -Workdir <temp-workdir>
```

Pass criteria:

- rule is written to workspace config
- rule appears in the list output

## Documentation Verification

Check:

- commands in docs use real script names
- commands align with current parameter names
- package-selection guidance clearly recommends `codex-delegate-agent` by default
- install docs mention `build-packages.ps1` and `validate-packages.ps1`
- troubleshooting docs cover PATH, routing precedence, appended rule order, and PowerShell execution policy

## Release Decision

`v1.0.0` is ready only when:

- all release smoke tests pass
- all required docs exist and were reviewed
- no release-critical drift remains between source and generated packages

## Tag And Publish

When everything is green:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

Then publish the release notes based on `docs/v1.0.0-release-notes.md`.

## Post-Release Follow-Up

After release:

- record any user-reported install friction
- record any routing confusion points
- move deferred ideas into the post-`v1` backlog instead of widening `v1`
