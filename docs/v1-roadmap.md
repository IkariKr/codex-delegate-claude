# Codex Delegate V1 Roadmap

## Document Status

- Status: release-ready working plan
- Target: public v1 release
- Primary package target: `packages/codex-delegate-agent`
- Secondary package target: `packages/codex-delegate-opencode`
- Release recommendation: ship `v1.0.0` only after all release gates in this document are green
- Validation snapshot: required release docs added and release smoke checks passed on July 5, 2026

## Current Release Status

The repository is now in a `v1` release-ready state, meaning:

- the required public release docs exist
- package positioning is documented with `codex-delegate-agent` as the default recommendation
- package build and validation checks pass
- generated-package smoke tests for routing and rule management pass

The remaining release action is operational rather than product-defining:

- tag and publish the release when maintainers are ready

## Goal

Deliver a publicly releasable `v1` of the Codex Delegate skill family with:

- a stable unified entrypoint for `Claude` and `OpenCode`
- transparent, user-manageable auto routing
- predictable install, debug, and upgrade behavior
- documentation and validation quality high enough for external users to self-serve

`v1` is not just "works for us". It means a new user can install it, understand it, route tasks intentionally, debug failures, and upgrade with confidence.

## V1 Product Definition

The `v1` release should present the project as three clear surfaces:

1. `codex-delegate-claude`
   Existing Claude-oriented package kept compatible for users who want the original behavior.
2. `codex-delegate-opencode`
   OpenCode-oriented package for users who want local/provider-driven execution directly.
3. `codex-delegate-agent`
   The flagship unified package and default recommendation for new users.

For public release, `codex-delegate-agent` should be treated as the main product, while the Claude and OpenCode packages remain explicit specialist entrypoints.

## Release Principles

- Transparent: routing, config source, and fallback behavior must always be inspectable.
- Predictable: explicit user choice always wins over automation.
- Recoverable: users can understand failures and fix them without reading source code.
- Upgradable: package generation and sync rules remain one-source-of-truth, avoiding drift.
- Documented: common tasks must be covered by copy-paste-ready docs.

## Definition Of Done

The project is ready for public `v1.0.0` only when all of the following are true:

- `codex-delegate-agent` is the clearly documented default package for new users.
- A new user can install a package, verify prerequisites, and run a first successful command from docs alone.
- Auto routing behavior is transparent, explainable, and user-editable without source changes.
- Structured and natural-language rule management both work from generated package artifacts.
- Generated packages rebuild cleanly and pass validation from source-of-truth files.
- Release docs exist for installation, package selection, quickstart, routing, troubleshooting, and release procedure.
- Known `v1` limitations are documented explicitly instead of being implicit maintainer knowledge.

## Release Gates

All gates below must be green before tagging `v1.0.0`:

1. Product gate
   - Public package recommendation is final.
   - Public script surface is frozen.
   - Routing config schema is frozen.
2. Documentation gate
   - Required release docs are complete.
   - Commands shown in docs are copy-paste verified.
3. Validation gate
   - `build-packages.ps1` passes.
   - `validate-packages.ps1` passes.
   - Release smoke tests pass in generated packages.
4. Supportability gate
   - Troubleshooting coverage exists for PATH, missing backend, config precedence, and routing surprises.
   - At least one maintainer can follow the release checklist from scratch.

## In Scope For V1

### 1. Stable Unified Routing

- `run_delegate_agent.ps1` is the stable public entrypoint for unified delegation.
- Explicit `-Backend claude|opencode` remains highest priority.
- `-Backend auto` remains config-driven, transparent, and explainable.
- Backend availability fallback is visible in output and documented.

### 2. Transparent Routing Configuration

- `auto-routing.default.json` remains the default template and fallback source.
- Workspace-level user config is the primary customization surface.
- Config search order is fixed, documented, and covered by validation.
- Rule table format is treated as a stable public interface for `v1`.

### 3. User Rule Management

- Structured management entrypoint:
  `scripts/manage_auto_routing.ps1`
- Natural-language wrapper entrypoint:
  `scripts/manage_auto_routing_nl.ps1`
- Supported user intents for `v1`:
  - list current rules
  - explain a routing decision
  - initialize workspace config
  - add rule
  - update rule
  - enable rule
  - disable rule
  - remove rule

### 4. OpenCode Backend Practical Usability

- OpenCode model selection behavior must be understandable and documented.
- Provider preference, paid fallback, model intent, and agent defaults must be documented as supported knobs.
- Logs and `WhatIf` output must be sufficient for users to see what would run and why.

### 5. Build, Sync, and Validation Reliability

- `scripts/build-packages.ps1` remains the only supported generation path.
- `scripts/validate-packages.ps1` must catch missing generated files and sync drift.
- Generated packages must be self-contained and installable.

### 6. Public-Facing Documentation

- Architecture overview
- Installation and prerequisites
- Quickstart
- Routing and config reference
- Rule management guide
- Troubleshooting and diagnostics
- Release notes for `v1`

## Out Of Scope For V1

These are intentionally deferred unless they become release blockers:

- dynamic learning or telemetry-driven routing
- weighted scoring or multi-rule merge logic
- automatic rule reordering or priority UI
- full conversational rule editing without labeled fields
- remote service layer, hosted control plane, or cloud sync
- third backend beyond Claude and OpenCode
- GUI or visual configuration editor
- analytics, usage dashboards, or historical routing reports

## Known V1 Gaps To Close

### Product Gaps

- We still need a clean public story for "which package should I install first".
- We need a better first-run path for users who do not know whether to choose Claude, OpenCode, or auto.
- We need clearer guidance on when new rules fail to win because they were appended after earlier matching rules.

### Documentation Gaps

- Closed in current repo state through:
  - `docs/installation.md`
  - `docs/troubleshooting.md`
  - `docs/v1.0.0-release-notes.md`
  - `docs/package-selection.md`

### Release Process Gaps

- Closed in current repo state through `docs/release-checklist.md`.
- No explicit compatibility matrix is documented yet.

## Workstreams

The `v1` plan should be executed as four parallel workstreams with a fixed priority order.

### Workstream A: Product Surface

Priority: `P0`

- freeze package positioning
- freeze public scripts and public config schema
- finalize first-run recommendation for new users
- finalize documented behavior for auto routing and fallback

### Workstream B: User Documentation

Priority: `P0`

- write installation, package selection, quickstart, routing, and troubleshooting docs
- ensure examples match generated package paths and actual script behavior
- document supported and unsupported scenarios

### Workstream C: Verification And Release Ops

Priority: `P0`

- define release smoke tests
- define release checklist
- define versioning and tagging convention
- define release notes structure

### Workstream D: Post-V1 Backlog Shaping

Priority: `P1`

- capture future routing enhancements without changing `v1` scope
- record deferred ideas for rule ordering UX, freer natural-language parsing, and richer backend selection
- keep post-`v1` items visible so release discipline does not erase future plans

## V1 Milestones

## Milestone 1: Product Hardening

Objective: make the current implementation safe and understandable enough for external use.

Deliverables:

- unified package positioning finalized
- public CLI surface frozen for `v1`
- routing config schema frozen for `v1`
- natural-language wrapper syntax contract documented
- consistent debug output across routing and backend execution paths

Acceptance criteria:

- a new user can choose a package and run a first successful delegation
- a user can explain why a prompt routed to a backend
- a user can add or modify a routing rule without editing source code
- all supported management commands work in generated package form

## Milestone 2: Documentation Completion

Objective: make the project externally understandable without repository archaeology.

Deliverables:

- `docs/quickstart.md`
- `docs/installation.md`
- `docs/routing-guide.md`
- `docs/troubleshooting.md`
- `docs/package-selection.md`
- `docs/release-checklist.md`

Acceptance criteria:

- install steps are copy-pasteable
- each public script has examples
- config source precedence is documented once and reused consistently
- common failure modes have actionable fixes

## Milestone 3: Verification And Compatibility

Objective: raise confidence from "manual confidence" to "release confidence".

Deliverables:

- regression checklist for routing behaviors
- regression checklist for package generation
- compatibility notes for Windows PowerShell environments
- documented assumptions for Claude and OpenCode CLIs on PATH

Acceptance criteria:

- all release-critical flows are covered by repeatable manual or scriptable checks
- generated packages pass validation from a clean rebuild
- package docs match actual script behavior

## Milestone 4: Release Packaging And Messaging

Objective: make `v1` ready to publish and announce.

Deliverables:

- versioning convention documented
- `v1.0.0` release notes drafted
- install recommendation for new users finalized
- supported/non-supported scenarios listed

Acceptance criteria:

- a public reader can tell what the project is, which package to install, and how to get started in under five minutes
- a maintainer can cut a release without remembering hidden steps

## Major Risks

### Risk 1: Product Positioning Confusion

Users may not understand whether to install `claude`, `opencode`, or `agent`.

Mitigation:

- write `package-selection.md` early
- make `codex-delegate-agent` the explicit default recommendation
- keep the specialist packages documented as opt-in choices

### Risk 2: Routing Looks Powerful But Feels Unpredictable

If users cannot tell why a rule did or did not win, trust drops quickly.

Mitigation:

- keep "first enabled matching rule wins" as the simple `v1` contract
- document config precedence and append-order behavior clearly
- keep `list` and `explain` as first-class support flows

### Risk 3: Public Release Fails On Setup, Not Capability

External users are more likely to fail on PATH, prerequisites, or package installation than on core routing logic.

Mitigation:

- prioritize install and troubleshooting docs ahead of more feature work
- verify commands from a clean generated package path
- document expected backend prerequisites explicitly

### Risk 4: Source And Generated Packages Drift

Because the project uses generated packages, documentation or scripts can silently diverge.

Mitigation:

- treat `build-packages.ps1` as the only generation path
- keep `validate-packages.ps1` strict
- review generated docs and scripts as part of release gates

## Recommended Execution Order

1. Freeze the `v1` public surface.
   Decide exactly which scripts, config fields, and package names are public and stable.
2. Finish release docs before adding more smart behavior.
   The current functionality is already meaningful; docs now unblock public usage faster than more features.
3. Close troubleshooting and install gaps.
   Public release fails more often on setup and debugging than on core capability.
4. Run a release-candidate pass.
   Rebuild packages, validate, perform clean-environment install checks, then write release notes.

## Proposed Public Surface Freeze For V1

The following should be treated as stable in `v1` unless a blocker appears:

- package names:
  - `codex-delegate-claude`
  - `codex-delegate-opencode`
  - `codex-delegate-agent`
- primary scripts:
  - `scripts/run_delegate_agent.ps1`
  - `scripts/manage_auto_routing.ps1`
  - `scripts/manage_auto_routing_nl.ps1`
- routing config fields:
  - `version`
  - `defaults.preferred_backend`
  - `defaults.fallback_backend`
  - `defaults.on_no_match`
  - `rules[].name`
  - `rules[].enabled`
  - `rules[].backend`
  - `rules[].reason`
  - `rules[].when.prompt_any_regex`
  - `rules[].when.prompt_all_regex`
  - `rules[].when.workdir_any_regex`
  - `rules[].when.workdir_all_regex`

The following are explicitly not part of the frozen `v1` public contract:

- automatic rule reordering
- scoring or weighted rule competition
- rule analytics or historical routing data
- fully free-form natural-language parsing without labeled fields

## Proposed V1 Documentation Set

Minimum required docs for release:

- `docs/architecture.md`
  Maintainer-oriented structure and generation model.
- `docs/v1-roadmap.md`
  Release scope and milestone contract.
- `docs/package-selection.md`
  Which package to use and why.
- `docs/installation.md`
  Prerequisites, install steps, verification steps.
- `docs/quickstart.md`
  First-run examples for Claude, OpenCode, and Agent.
- `docs/routing-guide.md`
  Auto routing behavior, config precedence, rule format, examples.
- `docs/troubleshooting.md`
  PATH issues, missing backend, config mismatch, routing surprises, encoding concerns.
- `docs/release-checklist.md`
  Rebuild, validate, smoke test, tag, and publish checklist.

Nice-to-have if time allows:

- `docs/faq.md`
- `docs/migration.md`
- `docs/examples.md`

## Release Checklist Summary

Before calling `v1.0.0` ready:

1. Rebuild packages from source.
2. Run package validation.
3. Verify unified agent flow in generated package.
4. Verify structured routing management flow.
5. Verify natural-language routing management flow.
6. Verify explicit backend override behavior.
7. Verify config precedence behavior.
8. Verify backend unavailable fallback behavior.
9. Review docs against actual command output.
10. Draft and review release notes.

## Recommended Next Step

The next execution step should be documentation-first, not feature-first:

1. write `package-selection.md`
2. write `installation.md`
3. write `quickstart.md`
4. write `routing-guide.md`
5. write `troubleshooting.md`
6. write `release-checklist.md`

That sequence turns the current implementation into a releasable `v1` candidate faster than adding more backend intelligence.

## Execution Decision

For the next phase, the project should operate under this rule:

- no new backend capability work unless it is required to unblock one of the `v1` release gates
- release documentation, validation, and package positioning now take precedence over new routing intelligence

This keeps the project on a realistic path to a public `v1` instead of drifting into an open-ended feature cycle.
