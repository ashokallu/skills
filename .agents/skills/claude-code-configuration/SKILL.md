---
name: claude-code-configuration
description: Use when an agent is asked to install, configure, doctor, or repair Claude Code setup for example-app, including local settings.local.json and user ~/.claude/settings.json.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-05-28 -->

# Claude Code Configuration

Use this skill when an agent is asked to set up Claude Code for a user. The
current repo path uses the Claude Enterprise plan, not the the organization LiteLLM
gateway.

Mirrored counterpart: `.claude/skills/claude-code-configuration/SKILL.md`.
Keep secret-handling, token-placeholder, and MCP-scope rules aligned between
the two skills even though this file is agent-specific.

## Safety Rules

- Never print, commit, log, or paste the real `ANTHROPIC_AUTH_TOKEN`.
- Do not require `scripts/dev/agent-collab-vpn-smoke.sh` before Claude Code
  checks. VPN may still be needed for staging, repo services, or Copilot
  LiteLLM calls, but it is not a Claude Code prerequisite.
- Never run generated all-in-one Python, Node, shell, or heredoc verifier
  scripts for setup. Use small explicit commands so the user can see what is
  happening and stop a stuck step safely.
- Create `.claude/settings.local.json` as a local ignored file. Do not stage it.
- Do not write gateway defaults into `~/.claude/settings.json`. Claude Code
  uses Enterprise auth here; Copilot has its own LiteLLM-backed routing.
- Treat MCP enablement as live state. Inspect `.claude/settings.json`,
  `.claude/settings.local.json`, and user settings before reporting whether an
  MCP is enabled or disabled.
- Enable a declared MCP for Claude Code only when the user explicitly asks and
  the needed local credential or wrapper exists. Put that enablement in
  `.claude/settings.local.json`, not committed project settings.

## Setup Steps

1. Confirm Claude Code is installed:

   ```bash
   claude --version
   ```

   If the command is missing, detect the OS and install Claude Code on macOS or
   Linux with the official installer. This is the preferred path because it can
   install the native build and handle Claude Code updates:

   ```bash
   curl -fsSL https://claude.ai/install.sh -o install.sh
   ls -lh install.sh
   bash install.sh
   rm install.sh
   ```

   On Windows or an unsupported shell, stop and point the user to
   `docs/claude-code-local-configuration.md` for manual setup, then rerun the
   doctor after installation.

2. Do not run a VPN preflight for Claude Code setup. Claude Code uses the
   Claude Enterprise plan here.

3. If Claude Code is already installed and `.claude/settings.local.json`
   exists, do not reinstall Claude Code and do not rewrite the local settings
   file. Validate the existing setup only: parse local/project settings without
   printing secrets, inspect MCP state, run a small Haiku Enterprise smoke test,
   and run `claude doctor` when Claude is logged in.

4. Do not create a dummy `ANTHROPIC_AUTH_TOKEN` file for Enterprise setup. If
   `.claude/settings.local.json` already exists, preserve it as local ignored
   state and never print any token-like value from it. Tell the user that a
   stale local token can shadow Claude Enterprise auth and may need to be
   removed locally if Enterprise login keeps failing.

5. Verify the committed project settings do not contain repo-level
   `ANTHROPIC_BASE_URL` or `ANTHROPIC_AUTH_TOKEN` defaults.

6. Repair empty user Claude settings only when needed.

   Claude Code user settings live at `~/.claude/settings.json` on macOS and
   Linux. Resolve `~` from the current user's home directory. During first-time
   installation, Claude Code may leave that file empty, which can break startup
   or doctor checks.

   If `~/.claude/settings.json` exists and has zero bytes or only whitespace,
   initialize it with this minimal JSON:

   ```json
   {
     "$schema": "https://json.schemastore.org/claude-code-settings.json",
     "theme": "dark"
   }
   ```

   Do not overwrite a non-empty `~/.claude/settings.json`. If the file is
   non-empty but invalid JSON, stop and ask the user before editing global
   settings.

7. Validate JSON without printing secrets:

   ```bash
   node -e "JSON.parse(require('fs').readFileSync('.claude/settings.local.json', 'utf8')); console.log('local settings json ok')"
   node -e "JSON.parse(require('fs').readFileSync('.claude/settings.json', 'utf8')); console.log('project settings json ok')"
   ```

   Do not print `.claude/settings.local.json`; it may contain local secrets.

8. Doctor check:

   ```bash
   claude --version
   claude doctor
   ```

   Before doctoring, run a small Enterprise smoke test when possible:

   ```bash
   scripts/dev/agent-call-claude.sh --profile haiku --tool-mode none \
     --timeout-sec 180 --no-session-persistence \
     --prompt 'Smoke test only. Reply exactly: claude-enterprise-haiku-ok'
   ```

   Treat exit code 0 plus the exact `claude-enterprise-haiku-ok` response as
   the smoke pass condition.

   Run `claude doctor` after Claude is logged in. If Claude prompts for login,
   stop and ask the user to complete `claude auth` or the interactive login
   flow locally.

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

   If `claude doctor` hangs or produces no output, stop the command and report
   that the doctor check is stuck. Do not replace it with a larger generated
   diagnostic script.

## Project MCPs

The committed `.mcp.json` declares default project MCP servers. Optional MCP
implementations may remain available through repo launchers or disabled Codex
definitions without being registered to Claude by default. The core Claude
Code setup path cares about:

- `github`
- `gopls`

Other project MCPs may exist for local-dev workflows. Do not hard-code whether
any MCP is currently enabled. Read the current Claude settings in this order:

1. `.claude/settings.local.json`
2. `.claude/settings.json`
3. `~/.claude/settings.json`

If the user asks to enable one of the declared MCPs, update the appropriate
local project settings file, `.claude/settings.local.json`, by adding the server
to `enabledMcpjsonServers`. Preserve unrelated settings and never enable
undeclared MCPs as a side effect. Do not commit MCP enablement changes; they are
user-specific.

If the requested optional MCP is not declared in `.mcp.json`, add its server
registration only to the active client's local MCP configuration, then enable
it locally. Reuse the repo launcher or disabled Codex definition as the wiring
source and do not commit that personal opt-in.

## Report Back

Return:

- whether Claude Code is installed
- whether the Enterprise Haiku smoke passed, failed, or was skipped
- whether local and project settings parsed successfully
- whether `~/.claude/settings.json` was missing, valid, repaired because it was
  empty, or invalid-but-left-unchanged
- whether `claude doctor` passed, failed, or was skipped until Enterprise login
- which declared MCPs are currently enabled, disabled, or unconfigured based on
  live settings
- confirmation that `.claude/settings.local.json` was not staged
- when setup hard-stopped or errored, the OS-specific manual recovery workflow
  the user can follow next
