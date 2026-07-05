# Package Selection

## Default Recommendation

If you are new to this repository, install and use `codex-delegate-agent` first.

It is the main `v1` package because it gives you:

- one stable entrypoint
- explicit backend override when you want it
- transparent auto routing when you do not
- both structured and natural-language rule management

## Package Overview

| Package | Best for | Default recommendation |
| --- | --- | --- |
| `codex-delegate-agent` | Users who want one entrypoint that can route to Claude or OpenCode | Yes |
| `codex-delegate-claude` | Users who only want Claude-oriented delegation behavior | Conditional |
| `codex-delegate-opencode` | Users who only want direct OpenCode/local-provider delegation | Conditional |

## Which Package Should I Choose?

### Choose `codex-delegate-agent` if:

- you want the public `v1` default
- you want to start with auto routing
- you expect to use both Claude and OpenCode over time
- you want rule management and routing explainability

### Choose `codex-delegate-claude` if:

- you want behavior closest to the original project shape
- you only plan to use Claude Code
- you care about Claude-specific permission or budget controls and do not need OpenCode

### Choose `codex-delegate-opencode` if:

- you want direct OpenCode execution without unified routing
- you mainly use local/provider-driven models
- you want to tune provider preference, model intent, paid fallback, or agent choice directly

## Decision Shortcut

Use this quick rule:

1. Start with `codex-delegate-agent`.
2. Move to `codex-delegate-claude` only if you want Claude-only behavior.
3. Move to `codex-delegate-opencode` only if you want OpenCode-only behavior.

## Why `codex-delegate-agent` Is The V1 Flagship

`v1` treats `codex-delegate-agent` as the main product because it combines:

- stable explicit backend control through `-Backend claude|opencode`
- transparent auto routing through `-Backend auto`
- inspectable routing via `manage_auto_routing.ps1`
- beginner-friendly routing management via `manage_auto_routing_nl.ps1`

That makes it the best default for public release, while the specialist packages remain available for focused usage.

## Package Layout

From the repository root:

- root folder: `codex-delegate-claude`
- generated OpenCode package: `packages/codex-delegate-opencode`
- generated unified package: `packages/codex-delegate-agent`

If you clone the repo into your Codex skills directory, the root repo already acts as the Claude package, while the generated packages can be linked in as sibling skills.

## Public V1 Surface

The public `v1` recommendation is:

- install `codex-delegate-agent`
- treat `scripts/run_delegate_agent.ps1` as the primary runtime entrypoint
- treat `scripts/manage_auto_routing.ps1` and `scripts/manage_auto_routing_nl.ps1` as the supported rule-management entrypoints

For more detail:

- installation: `docs/installation.md`
- first-run examples: `docs/quickstart.md`
- routing behavior and config: `docs/routing-guide.md`
