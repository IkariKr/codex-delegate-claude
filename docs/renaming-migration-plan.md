# Relay Renaming Migration Plan

This document captures the approved naming migration from the current `codex-delegate-*` family to the new `Relay` brand and `relay-*` skill/package names.

## Naming Goals

- Move from a Codex-specific brand to a backend-neutral platform name.
- Keep the public surface short, memorable, and easy to spread.
- Preserve clear separation between:
  - the product name
  - the unified entry skill
  - backend-specific skills and packages

## Approved Target Names

- Repository name: `relay-agent-platform`
- Project name: `Relay`
- Unified entry skill: `relay-agent`
- Backend skills:
  - `relay-claude`
  - `relay-opencode`
  - `relay-antigravity`

## Core Rename Mapping

### Repository

| Current | Target |
| --- | --- |
| `codex-delegate-claude` | `relay-agent-platform` |

### Project / Display Name

| Current | Target |
| --- | --- |
| `Codex Delegate` | `Relay` |
| `Codex Delegate Agent` | `Relay` |
| `Codex Delegate Claude` | `Relay Claude` |
| `Codex Delegate OpenCode` | `Relay OpenCode` |
| `Codex Delegate Antigravity` | `Relay Antigravity` |

### Skills

| Current | Target |
| --- | --- |
| `codex-delegate-agent` | `relay-agent` |
| `codex-delegate-claude` | `relay-claude` |
| `codex-delegate-opencode` | `relay-opencode` |
| `codex-delegate-antigravity` | `relay-antigravity` |

### Packages / Generated Package Roots

| Current | Target |
| --- | --- |
| `packages/codex-delegate-agent` | `packages/relay-agent` |
| `packages/codex-delegate-opencode` | `packages/relay-opencode` |
| `packages/codex-delegate-antigravity` | `packages/relay-antigravity` |

### Manifest Package Names

| Current | Target |
| --- | --- |
| `package_name: codex-delegate-agent` | `package_name: relay-agent` |
| `package_name: codex-delegate-claude` | `package_name: relay-claude` |
| `package_name: codex-delegate-opencode` | `package_name: relay-opencode` |
| `package_name: codex-delegate-antigravity` | `package_name: relay-antigravity` |

## Docs Title Mapping

| Current / Generic Title | Target Title |
| --- | --- |
| `README` title | `Relay` |
| `Architecture` | `Relay Architecture` |
| `Platform Architecture v2` | `Relay Platform Architecture v2` |
| `Quickstart` | `Relay Quickstart` |
| `Routing Guide` | `Relay Routing Guide` |
| `Package Selection` | `Relay Package Guide` |
| `Installation` | `Install Relay` |
| `Backend Development Guide` | `Relay Backend Development Guide` |
| `Surface Development Guide` | `Relay Surface Development Guide` |

## README Positioning

### Primary title

- `Relay`

### Primary slogan

- `A unified agent delegation platform for routing coding tasks across Claude, OpenCode, Antigravity, and more.`

### Short alternative slogan

- `Use one skill, route to the right coding agent, and keep control of review and verification.`

## Strings to Replace

The following public-facing names should be treated as migration targets across docs, manifests, generated packages, metadata, and install instructions.

| Current | Target |
| --- | --- |
| `codex-delegate-agent` | `relay-agent` |
| `codex-delegate-claude` | `relay-claude` |
| `codex-delegate-opencode` | `relay-opencode` |
| `codex-delegate-antigravity` | `relay-antigravity` |
| `Codex Delegate Agent` | `Relay` |
| `Codex Delegate Claude` | `Relay Claude` |
| `Codex Delegate OpenCode` | `Relay OpenCode` |
| `Codex Delegate Antigravity` | `Relay Antigravity` |

## Suggested Compatibility Strategy

Do not remove old names abruptly if users may already reference them.

### Recommended compatibility window

- Keep one migration cycle where the old names are still documented as renamed.
- Add a migration note in the README and installation docs.
- If old install paths or old skill references still exist, make them fail with a clear rename message instead of silently breaking.

### Suggested migration message

- `Relay is the new name for the former codex-delegate-* skill family.`

## Recommended Migration Order

1. Update docs, manifest display names, and `package_name` values.
2. Rename generated package directories under `packages/`.
3. Update README, installation docs, quickstart examples, and routing examples.
4. Update skill metadata and any generated OpenAI/Codex-facing descriptors.
5. Add migration notes and compatibility guidance.
6. Only then remove or stop advertising the legacy `codex-delegate-*` names.

## Areas That Should Stay Stable

These architecture terms do not need renaming as part of branding migration:

- `backends/`
- `surfaces/`
- `platform/`
- `registry/`
- `runtime/`
- `contracts/`

Keeping these stable reduces churn and avoids unnecessary architecture noise.

## Final Target State

### Repository

- `relay-agent-platform`

### Product

- `Relay`

### Public skill family

- `relay-agent`
- `relay-claude`
- `relay-opencode`
- `relay-antigravity`

### Package roots

- `packages/relay-agent`
- `packages/relay-claude`
- `packages/relay-opencode`
- `packages/relay-antigravity`

## Execution Note

This file is the naming source of truth for the branding migration. Future rename work should follow this mapping unless a newer decision document explicitly replaces it.
