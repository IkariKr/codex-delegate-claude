# Quickstart

## Fastest Path

If you only want the recommended `v1` path:

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Review this API design and point out risks." -Backend auto -WhatIf
```

That uses the unified package, lets routing decide, and prints the backend decision without executing a real backend run.

## Quickstart Scenarios

### 1. Unified Agent With Auto Routing

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Please review this architecture plan." -Backend auto -WhatIf
```

Use this when:

- you want the default `v1` experience
- you want the package to choose Claude or OpenCode based on routing config

### 2. Unified Agent With Explicit Claude

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Review this refactor plan in detail." -Backend claude -WhatIf
```

Use this when:

- you want Claude regardless of routing rules
- you need Claude-specific controls such as permission mode or budget

### 3. Unified Agent With Explicit OpenCode

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\run_delegate_agent.ps1 -Prompt "Make a quick fix in this small module." -Backend opencode -WhatIf
```

Use this when:

- you want OpenCode regardless of routing rules
- you want direct local/provider-oriented execution

### 4. Direct OpenCode Package

```powershell
Set-Location .\packages\codex-delegate-opencode
.\scripts\run_opencode_delegate.ps1 -Prompt "Implement a quick refactor." -WhatIf
```

Use this when:

- you want OpenCode only
- you do not need the unified routing layer

### 5. Inspect Current Routing Rules

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
```

Use this when:

- you want to see the active routing config source
- you want to inspect rule order, enable state, and condition summaries

### 6. Explain Why A Prompt Routes A Certain Way

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "Need a quick fix for this minor bug."
```

Use this when:

- you want to know which rule wins
- you want to inspect the selected backend and routing reason before changing config

### 7. Natural-Language Rule Inspection

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\manage_auto_routing_nl.ps1 -Request 'list current routing rules' -Workdir .
```

Use this when:

- you want a softer entrypoint than the structured action-based script
- you still want transparent output showing the translated command

### 8. Natural-Language Rule Creation

```powershell
Set-Location .\packages\codex-delegate-agent
.\scripts\manage_auto_routing_nl.ps1 -Request 'add rule: "quick-local", backend: opencode, reason: quick local routing, prompt keywords: quick, fix, minor' -Workdir . -Apply
```

Use this when:

- you want to add a rule without hand-editing JSON
- you are comfortable using labeled fields in a natural-language wrapper

## What To Expect From `-WhatIf`

On runtime entrypoints, `-WhatIf` prints:

- selected backend
- routing reason
- selected config path when auto routing is used
- backend-specific arguments that would be executed

This is the recommended first-run mode because it lets you validate installation and routing without spending backend tokens or changing anything.

## Recommended First-Day Workflow

1. Run `run_delegate_agent.ps1` with `-WhatIf`.
2. Run `manage_auto_routing.ps1 -Action list`.
3. Run `manage_auto_routing.ps1 -Action explain` with a prompt that resembles your real usage.
4. Only after that, run a real backend command without `-WhatIf`.

## Where To Go Next

- installation details: `docs/installation.md`
- routing behavior and config: `docs/routing-guide.md`
- package choice help: `docs/package-selection.md`
- troubleshooting: `docs/troubleshooting.md`
