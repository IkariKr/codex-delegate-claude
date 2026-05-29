---
name: codex-delegate-claude
description: Delegate coding implementation to Claude Code while Codex keeps responsibility for task decomposition, review, verification, retry prompts, and git commits. Use when the user asks Codex to break down a coding task, have Claude Code execute the concrete changes, inspect Claude's diff, ask Claude for fixes if needed, and commit only reviewed changes.
---

# Codex Delegate Claude

Use this skill when Codex should be the planner, reviewer, verifier, and committer, while Claude Code performs bounded implementation attempts.

## Workflow

1. Define the finish line.
   - Restate the user goal, deliverable, success criteria, and constraints.
   - Identify the relevant files, commands, and likely tests before asking Claude to edit.
   - Keep implementation instructions specific enough that Claude does not need to infer scope.

2. Record the baseline.
   - Run `git status --short` before delegation.
   - Record pre-existing dirty files separately from files expected to change.
   - If the repository is not a git worktree, continue without commit behavior and state that limitation.

3. Delegate one bounded implementation attempt.
   - Prefer the bundled wrapper:
     ```powershell
     & "$env:CODEX_HOME\skills\codex-delegate-claude\scripts\run_claude_delegate.ps1" -Prompt "<implementation prompt>"
     ```
   - If `CODEX_HOME` is unset, use the absolute skill path or the discovered skill directory.
   - The wrapper calls Claude with `claude -p --permission-mode acceptEdits --output-format json`.
   - The prompt to Claude must include:
     - the exact user goal,
     - files or areas Claude may edit,
     - relevant constraints,
     - verification commands Claude should run when appropriate,
     - an instruction not to commit.
   - Use timeout controls for non-trivial tasks:
     ```powershell
     & "$env:CODEX_HOME\skills\codex-delegate-claude\scripts\run_claude_delegate.ps1" -Prompt "<implementation prompt>" -IdleTimeoutSeconds 600 -PollSeconds 30 -StatusSeconds 180
     ```
   - Prefer idle timeout over total timeout for large tasks. Use `-TimeoutSeconds` only when there is a real wall-clock budget.
   - Keep status output sparse. Frequent heartbeats increase Codex-visible token usage without improving the task.

4. Handle stalled Claude runs.
   - Treat exit code `124` as optional total timeout and exit code `125` as idle timeout.
   - When Claude times out or produces no output past the idle limit, the wrapper kills the Claude process tree.
   - After a timeout, immediately inspect `git status --short` and `git diff`.
   - If Claude produced useful partial edits, review and verify them before deciding whether to continue.
   - If partial edits are unsafe, incomplete, or hard to separate from unrelated work, stop and report the blocker.
   - If continuing, send a narrower correction prompt that mentions the timeout and constrains the next attempt.

5. Review Claude's changes.
   - Inspect `git status --short` and `git diff`.
   - Check for scope drift, unrelated edits, missing tests, broken public interfaces, and unsafe behavior.
   - Run the smallest meaningful verification commands that can prove the change.
   - Treat Claude's summary as advisory only; Codex must verify from the working tree.

6. Retry only with concrete findings.
   - If the result is incorrect or incomplete, send Claude a targeted correction prompt.
   - Include exact review findings, failing commands, and the expected fix.
   - Keep a default limit of 3 total Claude attempts unless the user requested a longer loop.
   - Stop and report the blocker if repeated attempts fail for the same reason.

7. Commit only after Codex approval.
   - Stage only files from the current delegation cycle that Codex has reviewed.
   - Do not stage unrelated pre-existing dirty files.
   - If Claude touched a file that was already dirty before the cycle, inspect hunks carefully.
   - Commit that file only when the delegation changes can be isolated safely.
   - If isolation is ambiguous, stop and ask the user instead of committing.
   - Use this commit message form:
     ```text
     <short imperative summary>

     Implemented by Claude Code, reviewed by Codex.
     ```

## Claude Prompt Template

```text
You are Claude Code executing a bounded implementation task for Codex.

Goal:
<user goal and Codex decomposition>

Allowed scope:
<files, modules, or directories Claude may edit>

Constraints:
- Do not commit changes.
- Preserve unrelated worktree changes.
- Follow existing project style and tests.
- Keep the change minimal and focused.

Verification:
<commands to run, or state "Codex will run verification" if not safe to run here>

After editing, summarize changed files, verification run, and any remaining risks.
```

## Review Checklist

Before accepting Claude's result, verify:
- The diff directly satisfies the stated goal.
- No unrelated files or generated noise are included.
- Existing dirty files were not accidentally folded into the delegated change.
- Tests or checks cover the changed behavior, or the remaining risk is explicitly acceptable.
- The final commit contains only reviewed, intended changes from this delegation cycle.
- Timeout or idle-stop runs were followed by diff inspection before any retry or commit.

## Bundled Script

Use `scripts/run_claude_delegate.ps1` for repeatable Claude invocation. It prints Claude output, captures stdout/stderr logs under the system temp directory, returns Claude's exit code, and prints the post-run git status summary. It never stages or commits files.

Script status behavior:
- `0`: Claude completed successfully.
- `124`: Claude exceeded `-TimeoutSeconds`; the wrapper killed the process tree.
- `125`: Claude produced no stdout/stderr for `-IdleTimeoutSeconds`; the wrapper killed the process tree.
- Any other non-zero code: Claude failed or was interrupted.

Default controls:
- `-TimeoutSeconds 0` disables total wall-clock timeout.
- `-IdleTimeoutSeconds 600` allows up to 10 minutes without stdout/stderr before stopping Claude.
- `-PollSeconds 30` controls log activity checks; process exit is still detected quickly.
- `-StatusSeconds 180` prints one heartbeat every 3 minutes.
- `-TailLines 200` prints only the tail of stdout/stderr by default.
- `-MaxTurns 3`

Use `-FullLog` only when the full Claude transcript is necessary. Prefer reading the saved log file directly for detailed diagnosis so Codex does not spend tokens on large logs.
For simple tasks, Claude completion should return control to Codex promptly; do not wait for `PollSeconds` or `StatusSeconds` before reviewing the diff and continuing.
