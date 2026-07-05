# Codex Delegate Architecture

This repository keeps one live Claude skill at the root, while adding shared sources for multiple delegation backends.

## Layout

- `shared/`: single source of truth for reusable docs and PowerShell helpers.
- `backends/`: backend-specific metadata and behavior notes.
- `packages/codex-delegate-opencode/`: installable OpenCode package generated and validated from shared sources.
- `packages/codex-delegate-agent/`: unified multi-backend entrypoint package generated from shared and backend sources.
- `scripts/build-packages.ps1`: regenerates skill metadata and shared runtime copies.
- `scripts/validate-packages.ps1`: lightweight consistency checks for generated outputs.
- `scripts/connect-fork.ps1`: switches the repository to `origin=<your fork>` and `upstream=<source repo>` when the fork URL is available.
- `scripts/install-workspace-skill-links.ps1`: creates workspace-visible junctions for generated skill packages.

## Branching

- `main`: stable branch that tracks the upstream Claude repository shape.
- `feat/opencode-shared-core`: current integration branch for shared-core extraction and the first OpenCode package.
- Future recommendation:
  - `sync/upstream-claude` for upstream pulls and conflict resolution.
  - `feat/multi-backend-skill` when introducing a unified entrypoint for Claude and OpenCode.

## Sync Strategy

- Shared content is edited once under `shared/`.
- Backend metadata is edited once under `backends/<backend>/`.
- Backend package scripts are edited once under `backends/<backend>/` and copied into generated packages.
- Unified auto-routing defaults are edited once under `backends/agent/auto-routing.default.json`.
- Unified routing management logic is shared through `backends/agent/AutoRoutingCommon.psm1` and consumed by both route execution and rule management scripts.
- Generated package files are refreshed through `scripts/build-packages.ps1`.
- Installable packages stay self-contained because the build copies the shared PowerShell module into each package.
