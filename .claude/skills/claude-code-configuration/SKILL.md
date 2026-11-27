---
name: claude-code-configuration
description: Use when installing, setting up, doctoring, changing, auditing, explaining, or troubleshooting Claude Code settings, local token setup, env vars, MCP context usage, project MCP allowlists, Claude skills/rules/agents, or .claude/settings*.json in example-app.
---

<!-- markdownlint-disable MD013 MD060 -->
<!-- Last verified: 2026-05-28 -->

# Claude Code Configuration

Use this skill for Claude Code configuration work in example-app. Keep the
work split by scope: shared project defaults belong in committed files; secrets
and personal experiments belong in local ignored files.

## Source Order

Start with repo-owned sources, then verify against current Claude docs when the
setting may have changed:

1. `.claude/settings.json` - committed project defaults.
2. `.claude/settings.local.json` - local ignored overrides; never copy secrets.
3. `.mcp.json` - project MCP server inventory.
4. `docs/claude-code-local-configuration.md` - rationale for env and MCP
   defaults.
5. `docs/claude-code-guide.md` - repo Claude layers: `CLAUDE.md`,
   `.claude/rules`, `.claude/agents`, and `.claude/skills`.
6. Current Claude docs for drift-prone settings:
   - `https://code.claude.com/docs/en/settings`
   - `https://code.claude.com/docs/en/env-vars`
   - `https://code.claude.com/docs/en/mcp`
   - `https://code.claude.com/docs/en/statusline`
   - `https://code.claude.com/docs/en/model-config`

If a doc claim affects the change and has not been verified in the current
turn, mark it `Pending Verification` or fetch the current source.

## Scope Rules

- Commit non-sensitive team defaults to `.claude/settings.json`.
- Keep `ANTHROPIC_AUTH_TOKEN` and other secrets only in
  `.claude/settings.local.json`, user settings, shell env, or the relevant
  local secret mechanism.
- Local settings override project settings. Use local overrides for experiments
  such as `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=0`.
- Do not commit machine-specific values unless the team has intentionally
  standardized them. The current shared Claude Code path uses the Claude
  Enterprise plan, so do not add repo-level `ANTHROPIC_BASE_URL` or
  `ANTHROPIC_AUTH_TOKEN` defaults.
- Do not move token names from `.mcp.json` into real token values. MCP headers
  should reference env placeholders such as `${GITHUB_PAT_TOKEN}`.
- When this skill changes, mirror portable Copilot-facing setup guidance in
  `.agents/skills/claude-code-configuration/SKILL.md`.

## Current Project Defaults

The committed Claude project config is optimized for low MCP context cost,
Claude Enterprise compatibility, and repo productivity:

- `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` in project settings because the
  shared default strips beta headers and beta schema fields.
- Local users may set `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=0` to test beta
  behavior and tool-reference support.
- `ENABLE_TOOL_SEARCH=true` keeps MCP tool search available for supported
  models in normal repo sessions.
- `ENABLE_CLAUDEAI_MCP_SERVERS=false` to keep Gmail/Calendar/Drive-style
  account MCPs out of repo sessions.
- `enableAllProjectMcpServers=false` with an explicit allowlist. Enabled by
  default: `github`, `gopls`, `context7_remote`, `parallel-search`, and
  `google-developer-knowledge`.
- Heavy or task-specific MCPs stay disabled by default: Sentry, TypeScript LSP,
  staging Google Cloud, staging Mongo, local SQL, and local Redis.
- `MAX_MCP_OUTPUT_TOKENS`, `MCP_TIMEOUT`, and `MCP_TOOL_TIMEOUT` bound noisy or
  stalled MCP interactions.
- `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` and
  `CLAUDE_CODE_MCP_ALLOWLIST_ENV=1` reduce credential exposure.
- `CLAUDE_CODE_ATTRIBUTION_HEADER=0` keeps Claude Code request metadata small
  and improves prompt-cache stability.
- The status line should stay short and context-oriented.

## MCP Context Workflow

When `/context` shows high MCP usage:

1. Inspect `tmp/context.md` or the user's captured `/context` output.
2. Separate upfront tool-schema cost from actual MCP tool result output.
3. Check `.claude/settings.json` for `ENABLE_TOOL_SEARCH`, project MCP
   allowlist, disabled MCPs, and timeout/output caps.
4. Check `.claude/settings.local.json` for local overrides that may re-enable
   heavy MCPs or beta behavior.
5. Check `~/.claude.json` only when user/global MCP duplicates are suspected;
   do not edit it without explicit user approval.
6. If using Haiku, note that MCP tool search may not apply; prefer Sonnet or
   Opus for tool-search testing.
7. Restart Claude Code before judging startup-context changes. Existing
   sessions do not reload settings.
8. Verify with `/status`, `/context`, and `/mcp`.

## Config Change Workflow

Before editing:

- Run `git status --short`.
- Parse current JSON before and after edits.
- Preserve unrelated user changes.
- Read the relevant setting in current Claude docs if behavior is unstable or
  recently added.

After editing:

```bash
node -e "for (const f of ['.claude/settings.json','.claude/settings.local.json']) JSON.parse(require('fs').readFileSync(f,'utf8'))"
markdownlint-cli2 docs/claude-code-local-configuration.md
git diff --check -- .claude/settings.json docs/claude-code-local-configuration.md
```

Run the Markdown lint only when the doc changed. If `markdownlint-cli2` is not
available, say so and use `git diff --check` plus careful review.

Secret scan commit-ready files before handoff:

```bash
rg -n "sk-[A-Za-z0-9]{20,}|ANTHROPIC_AUTH_TOKEN\\\": \\\"sk|GITHUB_PAT_TOKEN|GOOGLE_MCP_ACCESS_TOKEN|CONTEXT7_API_KEY|PARALLEL_SEARCH_API_TOKEN|DEVELOPERKNOWLEDGE_API_KEY" .claude/settings.json docs/claude-code-local-configuration.md
```

This scan should not inspect `.claude/settings.local.json` unless the user asks;
that file is allowed to contain local secrets and should remain untracked.

## Local Setup And Doctor Workflow

When asked to install, set up, or doctor Claude Code for a user:

1. Install Claude Code on macOS or Linux when `claude --version` is missing.
2. Do not require `scripts/dev/agent-collab-vpn-smoke.sh` before Claude Code
   checks. Claude Code uses the Claude Enterprise plan for this repo. VPN can
   still be required for repo services, staging, or Copilot LiteLLM calls, but
   it is not a Claude Code auth prerequisite.
3. Preserve `.claude/settings.local.json` if it exists, but do not create a
   dummy `ANTHROPIC_AUTH_TOKEN` file for Enterprise setup. If a local file still
   contains `ANTHROPIC_AUTH_TOKEN`, treat it as sensitive local state and do not
   print it. Tell the user that a stale local token can shadow Claude Enterprise
   auth and may need to be removed locally if Enterprise login keeps failing.
4. Run a small Enterprise smoke test before doctoring when possible:

   ```bash
   scripts/dev/agent-call-claude.sh --profile haiku --tool-mode none \
     --timeout-sec 180 --no-session-persistence \
     --prompt 'Smoke test only. Reply exactly: claude-enterprise-haiku-ok'
   ```

   Treat exit code 0 plus the exact `claude-enterprise-haiku-ok` response as
   the smoke pass condition.

   If the smoke hangs or fails, inspect the wrapper diagnostic before
   concluding Claude is unavailable.
5. Run `claude doctor` after Claude Code is installed and the smoke path is
   reachable. If the user is not logged in to Claude Enterprise, stop and ask
   them to complete `claude auth` or the interactive login flow locally.
   Claude Code 2.1.140 does not expose a `claude doctor --yes` or
   `--non-interactive` flag. If the runtime provides terminal control tools,
   run `claude doctor` in async/background terminal mode so the agent receives a
   terminal ID immediately. Do not run it as a sync terminal command in Copilot
   because Claude Code may print diagnostics and then wait at
   `Enter to continue`, which can freeze the agent harness.

   After starting the command, collect output from the terminal ID. If the
   output contains the diagnostics and is only waiting on `Enter to continue`,
   capture and summarize that output, then send exactly one empty or whitespace
   input to press Enter. Collect output again to confirm the terminal completed.
   If the terminal is still blocked after that single newline, or if the
   diagnostic output was already complete and the terminal no longer needs to
   keep running, kill the terminal and report the captured doctor result.

   Do not use `yes`, do not pipe input into `claude doctor`, do not blindly
   answer multiple prompts, and do not answer prompts that request a login
   method, token, permission change, install, or destructive action. Any prompt
   other than the final `Enter to continue` continuation requires human input.

## Choosing Where To Put Settings

Use `.claude/settings.json` for:

- team-wide permissions, hooks, status line, cleanup, and shared env defaults
- project MCP allowlist/denylist
- settings that every developer should inherit
- non-secret gateway or runtime defaults intentionally standardized by the repo

Use `.claude/settings.local.json` for:

- `ANTHROPIC_AUTH_TOKEN`
- temporary beta experiments
- personal model, effort, UI, or notification preferences
- local-only MCP approvals or removals; if the user asks to enable a declared
  project MCP for themselves, update local settings rather than committing a
  personal enablement change

Optional MCP implementations that are deliberately absent from `.mcp.json`
need both a client-local registration and local enablement. Reuse the repo
launcher or disabled Codex definition as the wiring source; do not commit a
personal opt-in.

Use user/global settings for:

- preferences that should apply outside example-app
- user-level MCPs unrelated to this repository
- personal plugin choices

## Claude Code Project Layers

Keep configuration changes aligned with the repo's Claude layering:

- `CLAUDE.md` is the global project guidance loaded every session.
- `.claude/rules/` contains path-scoped domain rules.
- `.claude/agents/` contains Claude project subagents.
- `.claude/skills/` contains reusable workflows. Add a skill here only when the
  workflow is durable and Claude-specific.
- `.github/instructions` and `.agents/skills` remain valid for other runtimes;
  keep shared Claude setup guidance aligned when the workflow is portable.

When adding or editing a Claude skill, keep `SKILL.md` concise, use a trigger
description that says when to use it, and avoid extra README-style files unless
a reference file is necessary.

## Settings Worth Considering Carefully

These are useful but should not be changed blindly:

- `includeGitInstructions=false` can save context but removes built-in git and
  PR workflow context.
- `skipWebFetchPreflight=true` may help restrictive egress setups but weakens
  WebFetch safety checks.
- `sandbox.enabled`, `allowUnsandboxedCommands=false`, and
  `disableBypassPermissionsMode="disable"` improve safety but can break normal
  repo commands without workflow testing.
- `model` and `effortLevel` affect cost, speed, and reasoning quality; treat
  them as personal or deliberately reviewed team choices.
- `spinnerTipsEnabled=false`, `showTurnDuration`, `viewMode`, and
  `preferredNotifChannel` are mostly user experience preferences.

## Common Mistakes

- Do not commit auth tokens, API keys, cookies, browser state, or private
  endpoints that are not intentionally shared.
- Do not assume `.claude/settings.local.json` changes are commit-ready; the file
  is ignored and local-only.
- Do not judge MCP schema savings from an already-running Claude session.
- Do not use rendered GitHub HTML as the source of truth for PRs; use the
  enabled GitHub MCP or authenticated `gh`.
- Do not enable every project MCP by default just because it exists in
  `.mcp.json`; tool schemas are part of the context budget.
- Do not copy Codex or Copilot MCP tool names into Claude docs without checking
  the Claude-exposed tool names.
