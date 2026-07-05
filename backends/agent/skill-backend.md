## Unified Backend Notes

- Preferred wrapper:
  `scripts/run_delegate_agent.ps1`
- This wrapper is a routing layer for multi-backend delegation.
- Start with `-Backend auto`; the default strategy is now `config`.
- The default routing config lives at `auto-routing.default.json`, and local overrides can come from:
  - `-AutoConfigPath <path>`
  - `CODEX_DELEGATE_AGENT_CONFIG`
  - `<workdir>/.codex-delegate-agent/routing.json`
  - `<workdir>/.codex-delegate-agent.json`
- Rules are a transparent ordered table with `enabled`, `backend`, `reason`, and `when.*` match fields.
- The first enabled matching rule wins.
- Use `-Backend opencode` when you explicitly want OpenCode's local model/provider pipeline.
- Use `-Backend claude` when you want the existing Claude behavior or need Claude-specific permission controls.
- Explicit backend selection always wins over auto routing.
- If auto routing selects an unavailable backend, the wrapper falls back to the other available backend and prints the reason.
- Use `scripts/manage_auto_routing.ps1` to list, explain, add, update, enable, disable, remove, or initialize user routing rules.
- Common management commands:
  - `scripts/manage_auto_routing.ps1 -Action list -Workdir <path>`
  - `scripts/manage_auto_routing.ps1 -Action explain -Workdir <path> -Prompt "<text>"`
  - `scripts/manage_auto_routing.ps1 -Action add -Workdir <path> -RuleName "<name>" -Backend opencode -Reason "<why>" -PromptAnyRegex "(?i)\bquick\b"`
  - `scripts/manage_auto_routing.ps1 -Action update -Workdir <path> -RuleName "<name>" -Backend claude`
