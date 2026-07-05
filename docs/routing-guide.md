# Routing Guide

## Purpose

`codex-delegate-agent` routes work to Claude or OpenCode through a transparent rule table.

The `v1` routing contract is intentionally simple:

- explicit backend selection always wins
- otherwise routing follows config precedence
- rules are evaluated from top to bottom
- the first enabled matching rule wins

## Runtime Entry Point

Main unified entrypoint:

```powershell
.\scripts\run_delegate_agent.ps1
```

Most important parameter:

- `-Backend auto|claude|opencode`

## Routing Priority

### Highest Priority: Explicit Backend

If you run:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "..." -Backend claude
```

or:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "..." -Backend opencode
```

the selected backend overrides all auto-routing rules.

### Auto Routing

If you run:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "..." -Backend auto
```

the script loads the first routing config it can find and resolves the backend from that config.

## Config Search Order

When `-Backend auto` and `-AutoStrategy config` are used, config lookup order is:

1. `-AutoConfigPath`
2. `CODEX_DELEGATE_AGENT_CONFIG`
3. `<workdir>\.codex-delegate-agent\routing.json`
4. `<workdir>\.codex-delegate-agent.json`
5. package `auto-routing.json`
6. package `auto-routing.default.json`

The first file found wins.

## Rule Table Schema

Top-level fields:

- `version`
- `defaults.preferred_backend`
- `defaults.fallback_backend`
- `defaults.on_no_match`
- `rules`

Per-rule fields:

- `name`
- `enabled`
- `backend`
- `reason`
- `when.prompt_any_regex`
- `when.prompt_all_regex`
- `when.workdir_any_regex`
- `when.workdir_all_regex`

## Matching Semantics

`v1` uses these rules:

- disabled rules are skipped completely
- `prompt_any_regex` means any one pattern may match
- `prompt_all_regex` means every listed pattern must match
- `workdir_any_regex` means any one workdir pattern may match
- `workdir_all_regex` means every listed workdir pattern must match
- the first enabled rule that matches wins

There is no scoring, weighting, or priority field in `v1`.

## Default Fallback Behavior

If no rule matches:

- the script uses `defaults.on_no_match`
- current default template uses `preferred_backend`

If the chosen backend is unavailable:

- the script falls back to the other available backend
- the fallback reason is printed in output

## Example Default Rules

The default config currently includes patterns such as:

- review, explain, plan, docs, architecture, design -> Claude
- small, quick, simple, tiny, minor, fast, fix, refactor -> OpenCode
- explicit `claude` prompt hints -> Claude
- explicit `opencode` or local/provider hints -> OpenCode

## Inspect Current Routing

List active rules:

```powershell
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
```

Explain a prompt:

```powershell
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "Need a quick fix for this minor bug."
```

Natural-language wrapper:

```powershell
.\scripts\manage_auto_routing_nl.ps1 -Request 'explain prompt: "Need a quick fix for this minor bug."' -Workdir .
```

## Create A Workspace Config

Initialize a workspace-local routing config:

```powershell
.\scripts\manage_auto_routing.ps1 -Action init-user-config -Workdir .
```

That creates:

```text
<workdir>\.codex-delegate-agent\routing.json
```

This is the recommended customization point for `v1`.

## Add A Rule Structurally

Example:

```powershell
.\scripts\manage_auto_routing.ps1 `
  -Action add `
  -Workdir . `
  -RuleName "quick-local" `
  -Backend opencode `
  -Reason "quick local routing" `
  -PromptAnyRegex "(?i)\bquick\b","(?i)\bfix\b","(?i)\bminor\b"
```

## Add A Rule Through The Natural-Language Wrapper

Example:

```powershell
.\scripts\manage_auto_routing_nl.ps1 `
  -Request 'add rule: "quick-local", backend: opencode, reason: quick local routing, prompt keywords: quick, fix, minor' `
  -Workdir . `
  -Apply
```

## Important V1 Rule-Order Behavior

New rules added through management scripts are appended to the end of the rules list.

That means a newly added rule may not win if an earlier enabled rule already matches the same prompt.

If that happens:

1. run `list` to confirm actual order
2. run `explain` to confirm which earlier rule is winning
3. move the rule upward manually in `routing.json` if you want it to have higher priority

This is expected `v1` behavior.

## When To Use Structured vs Natural-Language Management

Use `manage_auto_routing.ps1` when:

- you want exact field control
- you want predictable scripting behavior
- you want to automate config changes

Use `manage_auto_routing_nl.ps1` when:

- you want a friendlier entrypoint
- you are comfortable providing labeled fields like `rule:`, `backend:`, and `prompt keywords:`

The natural-language wrapper is still intentionally constrained in `v1`; it is not a free-form conversational editor.

## Debugging Routing

Start with these commands:

```powershell
.\scripts\manage_auto_routing.ps1 -Action list -Workdir .
.\scripts\manage_auto_routing.ps1 -Action explain -Workdir . -Prompt "your real prompt here"
```

If runtime behavior is still surprising, run:

```powershell
.\scripts\run_delegate_agent.ps1 -Prompt "your real prompt here" -Backend auto -WhatIf
```

That prints the selected backend, reason, and config source without executing the backend.
