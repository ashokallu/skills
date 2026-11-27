# Agent Skills

A library of **30 skills** for coding agents that plan changes, review pull
requests, debug browsers, inspect databases, and coordinate work across agent
runtimes. Each skill packages a procedure with the inputs it needs, the checks
it makes, and the evidence it should produce. Many include focused reference
guides, examples, or scripts that an agent can load as the task calls for them.

Start with the catalog below. Open the linked `SKILL.md` for the complete
workflow and its prerequisites.

## Install skills in a project

Clone this library once, then change into the Git checkout where your agent
will work. These commands use a Bash-compatible shell. Adjust the paths to
match your machine.

```sh
git clone https://github.com/ashokallu/skills.git ./agent-skills-library
skills_library="$(cd ./agent-skills-library && pwd)"
cd /path/to/your/project
```

### 1. Choose your runtime

Set the source and destination from the row for your runtime. For example, in
Codex use `skill_source="$skills_library/.codex/skills"` and
`skill_target=".agents/skills"`.

| Runtime | `skill_source` relative to `$skills_library` | `skill_target` relative to your project | Verify in a fresh session |
| --- | --- | --- | --- |
| Codex | `.codex/skills` | `.agents/skills` | Open `/skills` in the CLI or select the skill by name. |
| Claude Code | `.claude/skills` | `.claude/skills` | Type the skill's slash command, such as `/reviewer`. |
| Gemini CLI | `.agents/skills` | `.gemini/skills` or `.agents/skills` | Run `/skills list`, then ask Gemini to use the skill by name. |
| Google Antigravity | `.agents/skills` | `.agents/skills` | Open `/skills` in the CLI or find the skill in the app's workspace customization settings. |

The first path is the **edition stored in this library**. The second is where
the client discovers it. For a skill listed as Shared in the catalog, use
`skill_source="$skills_library/.agents/skills"` when no client-specific copy
is available and the skill's requirements fit your client. Use one copy per
skill name. Codex and Antigravity share `.agents/skills` for project skills.
If both work in the same checkout, use the shared editions there. Gemini CLI
also reads `.agents/skills` and gives it precedence over `.gemini/skills`
when both contain the same skill.

[Codex skills](https://developers.openai.com/codex/skills) ·
[Claude Code skills](https://code.claude.com/docs/en/skills) ·
[Gemini CLI skills](https://geminicli.com/docs/cli/skills/) ·
[Antigravity skills](https://antigravity.google/docs/skills)

### 2. Install one skill or the full edition

**Single skill.** Set `skill_source` and `skill_target` from the table, then
choose a skill from that edition. Copy its whole folder so the references,
scripts, and metadata stay alongside `SKILL.md`.

```sh
skill=reviewer
(
  set -e
  test -f "$skill_source/$skill/SKILL.md"
  mkdir -p "$skill_target"
  test ! -e "$skill_target/$skill"
  cp -R "$skill_source/$skill" "$skill_target/"
)
```

If the skill refers to another skill for the workflow you need, install that
companion the same way. If a folder already exists, compare the two copies
before updating it.

**Full edition.** Set the same variables, then run this loop to install every
skill shipped for your chosen runtime. It skips existing skill folders.

```sh
(
  set -e
  test -d "$skill_source"
  mkdir -p "$skill_target"
  for skill_dir in "$skill_source"/*; do
    test -f "$skill_dir/SKILL.md" || continue
    skill=${skill_dir##*/}
    if test -e "$skill_target/$skill"; then
      printf 'Skipping existing skill: %s\n' "$skill"
      continue
    fi
    cp -R "$skill_dir" "$skill_target/"
  done
)
```

This installs the full **runtime edition**. The catalog marks skills available
only in another edition, such as Codex Desktop's `peer-result-propagation`.
Reopen the intended project in your client and verify discovery with the
command or UI in the table before using the skills.

### 3. Add shared scripts when a workflow calls them

Scripts packaged inside a skill stay in that skill folder. Commands such as
`scripts/dev/agent-call-codex.sh` expect the shared helpers at
`scripts/dev/` **relative to the target project's root**. Install that bundle
for workflows that call it, including cross-harness collaboration. Preserve
its subdirectories and executable bits so wrappers can find their dependencies.

For a project without a `scripts/dev` directory:

```sh
(
  set -e
  test ! -e scripts/dev
  mkdir -p scripts
  cp -Rp "$skills_library/scripts/dev" scripts/
)
```

If the project already has `scripts/dev`, review and merge the helper files
instead of overwriting its scripts. Run the helpers from the intended
checkout. The [script setup guide](scripts/dev/README.md) lists CLI, package,
and environment requirements, including the pinned dependency for Muse MSP.

### 4. Configure MCP only when the task needs an MCP server

Skills can be loaded from disk without MCP. Local planning, reading a diff,
and running an installed CLI can use the client's existing tools. Set up MCP
when a selected workflow calls a server that your client does not already
provide, such as a Jira or Confluence server, a read-only database server, or
the search server used by `parallel-search-mcp`.

Merge the needed server entry into the client's project configuration. Use
the server's documented transport and authentication settings. Keep
credentials in your local environment or the client's sign-in flow.

| Client | Project MCP configuration | Verify the server |
| --- | --- | --- |
| Codex | Trusted project `.codex/config.toml`, under `[mcp_servers.<name>]`. [Codex example](examples/mcp/codex.config.toml) | Run `codex mcp list` or open `/mcp` in the CLI. |
| Claude Code | Project root `.mcp.json`, under `mcpServers`. [Claude example](examples/mcp/claude.mcp.json) | Review and approve the server in Claude Code, then check `/mcp`. |
| Gemini CLI | Project `.gemini/settings.json`, under `mcpServers`. | Open `/mcp` to check the server and its tools. |
| Google Antigravity | Workspace `.agents/mcp_config.json`, under `mcpServers`. | Check the workspace's MCP server list in the client. |

The [MCP examples](examples/mcp/README.md) show configuration shapes. Add the
actual server required by the skill, then verify it exposes the needed tool
before using that workflow.

[Codex MCP](https://developers.openai.com/codex/mcp) ·
[Claude Code MCP](https://code.claude.com/docs/en/mcp) ·
[Gemini CLI MCP](https://geminicli.com/docs/tools/mcp-server/) ·
[Antigravity MCP](https://antigravity.google/docs/mcp)

In the catalog, **Shared** means an edition is shipped under `.agents/skills/`,
**Codex** under `.codex/skills/`, and **Claude** under `.claude/skills/`.

## Skill catalog

### Planning, implementation, and coordination

| Skill | Available in | Capabilities and value |
| --- | --- | --- |
| [work-orchestration](.agents/skills/work-orchestration/SKILL.md) | Shared, Codex, Claude | Routes a request into research, planning, implementation, validation, review, or handoff. Tracks ownership, side effects, and completion evidence so a multi-step task keeps its scope as it moves between phases. |
| [code-authoring](.agents/skills/code-authoring/SKILL.md) | Shared, Codex, Claude | Guides implementation and refactoring across APIs, auth, generated code, tests, migrations, configuration, and rollout controls. Selects the domain procedures and verification that fit the actual change. |
| [improve](.agents/skills/improve/SKILL.md) | Shared, Codex, Claude | Audits an area, prioritizes improvement opportunities, and turns selected work into implementation plans and a maintained backlog. A fresh agent can pick up a plan with its scope, evidence, and acceptance criteria already recorded. |
| [worktree-readiness](.agents/skills/worktree-readiness/SKILL.md) | Shared, Codex, Claude | Prepares and verifies Git worktrees for implementation, review, commits, history edits, and publication. Checks the target revision, branch, and local tool readiness before work starts in the wrong checkout or on a stale branch. |
| [cross-harness-workflow](.agents/skills/cross-harness-workflow/SKILL.md) | Shared, Codex, Claude | Coordinates explicit collaboration across agent runtimes. Covers independent critiques, council planning, wrapper calls, persistent sessions, and consolidation. Gives each participant a bounded assignment and lets the parent reconcile evidence and disagreements. |
| [peer-result-propagation](.codex/skills/peer-result-propagation/SKILL.md) | Codex Desktop | Delivers an accepted result to a verified existing peer task when it changes that task's next decision. Records delivery and acknowledgement so dependent work can proceed with the right evidence. Requires native task messaging. |
| [agent-personality](.agents/skills/agent-personality/SKILL.md) | Shared, Codex, Claude | Shapes technical explanations, plans, handoffs, and constructive pushback. Helps the agent choose how much detail to give and communicate uncertainty or disagreement directly. |

### Review, pull requests, and quality

| Skill | Available in | Capabilities and value |
| --- | --- | --- |
| [reviewer](.agents/skills/reviewer/SKILL.md) | Shared, Codex, Claude | Reviews a stable diff, commit, or PR in read-only mode. Selects lenses for the affected surfaces, such as API compatibility, permissions, reliability, data, or tests, and ties findings to concrete evidence. |
| [database-reviewer](.agents/skills/database-reviewer/SKILL.md) | Shared, Codex, Claude | Independently assesses SQL, migrations, indexes, backfills, cutovers, locking, and rollback. Connects correctness findings to deployment order and operational evidence that can change the verdict. |
| [clawpatch-review](.agents/skills/clawpatch-review/SKILL.md) | Shared, Codex, Claude | Configures a scoped Clawpatch pass on a branch, PR worktree, or code area. Helps validate mapper coverage and reconcile tool findings with the actual diff. Requires Clawpatch. |
| [oracle](.codex/skills/oracle/SKILL.md) | Codex | Runs a focused second-model review through Oracle browser mode, with a bounded prompt, selected file attachments, and session tracking. Requires Oracle and access to a signed-in Chrome CDP session. |
| [pr-workflow](.agents/skills/pr-workflow/SKILL.md) | Shared, Codex, Claude | Drives PR review, preparation, publication, re-review, check triage, and bug reproduction from a specific PR or branch. Keeps findings and verification tied to the exact PR revision. |
| [github-workflow](.agents/skills/github-workflow/SKILL.md) | Shared, Codex, Claude | Handles focused GitHub operations such as reading PR fields, fetching Actions logs or artifacts, updating metadata, and handling review threads. Routes between configured GitHub MCP and the authenticated CLI when a capability is missing. |
| [gh-stack](.claude/skills/gh-stack/SKILL.md) | Claude | Splits multi-part changes into dependent PRs and guides stack creation, submission, synchronization, rebase, and merge. Makes each layer reviewable while preserving its dependency order. Requires `gh-stack`. |
| [skill-quality-evals](.agents/skills/skill-quality-evals/SKILL.md) | Shared, Codex, Claude | Checks skill routing, instructions, mirrored files, and behavioral evals. Combines static checks and real-model scenarios to catch cases where an agent selects the wrong workflow or skips a required step. |

### Browser automation and local development

| Skill | Available in | Capabilities and value |
| --- | --- | --- |
| [agent-browser](.agents/skills/agent-browser/SKILL.md) | Shared, Claude | Uses the `agent-browser` CLI to inspect pages, navigate, fill forms, capture screenshots, and reuse authenticated state. Supports fast exploratory checks with element references and separate browser sessions. |
| [playwright-cli](.agents/skills/playwright-cli/SKILL.md) | Shared, Codex, Claude | Drives Playwright browser sessions, snapshots, element actions, tabs, and screenshots. Helps reproduce UI behavior and gather browser evidence with repeatable commands. Requires the Playwright CLI. |
| [browser-e2e](.agents/skills/browser-e2e/SKILL.md) | Shared, Codex, Claude | Routes Playwright test authoring, locator debugging, auth verification, CI failure triage, and trace inspection. Uses first failures and retry evidence to distinguish likely regressions from flaky tests or setup problems. |
| [local-browser-workflow](.agents/skills/local-browser-workflow/SKILL.md) | Shared, Claude | Diagnoses local UI failures across service readiness, routing, TLS, cookies, login, and API behavior before exploring the page with `agent-browser`. Useful when a browser symptom could originate in the local stack. |
| [vscode-integrated-browser](.agents/skills/vscode-integrated-browser/SKILL.md) | Shared | Verifies local login and UI behavior through VS Code's integrated browser tools. Provides a repeatable route from session setup to evidence that the authenticated page actually loaded. |
| [vr-failure-analyzer](.agents/skills/vr-failure-analyzer/SKILL.md) | Shared, Codex, Claude | Collects visual regression artifacts and compares expected, actual, and diff images. Turns a failed screenshot check into a release- or ticket-ready diagnosis with likely causes and evidence. |
| [connect-backend-services](.agents/skills/connect-backend-services/SKILL.md) | Shared, Codex, Claude | Starts, stops, and checks the documented Docker-based backend and view-server layout. Confirms the app processes and logs are healthy before depending on them for browser, auth, or API verification. Requires a compatible local stack. |

### Data, research, and collaboration tools

| Skill | Available in | Capabilities and value |
| --- | --- | --- |
| [readonly-data-access](.agents/skills/readonly-data-access/SKILL.md) | Shared, Codex, Claude | Plans and runs authorized read-only Cloud SQL and MongoDB inspection through configured replicas, secondaries, or MCP tools. Helps verify the data source, bound the query, and keep sensitive data out of evidence. |
| [jira-agent-workflow](.agents/skills/jira-agent-workflow/SKILL.md) | Shared, Codex, Claude | Handles Jira searches, assigned-work selection, issue drafting, updates, and PR linkage. Connects an issue to a branch and PR while keeping project settings and write approvals explicit. |
| [jira-ticket-writer](.claude/skills/jira-ticket-writer/SKILL.md) | Claude | Chooses an issue type and turns a rough request into a structured Jira draft with acceptance criteria, risks, and open questions. Supports filing and readback after approval. |
| [confluence-workflow](.agents/skills/confluence-workflow/SKILL.md) | Shared, Codex, Claude | Searches and reads pages, updates content, and works with comments, labels, history, or attachments when supported by the configured MCP server. Uses the current page version and readback to verify documentation edits. |
| [gws](.agents/skills/gws/SKILL.md) | Shared, Codex, Claude | Guides Google Workspace CLI tasks such as Drive searches, uploads, shared-drive navigation, and Docs edits. Includes auth, schema discovery, and quota-project troubleshooting alongside the workflows. |
| [parallel-search-mcp](.claude/skills/parallel-search-mcp/SKILL.md) | Claude | Uses the configured search MCP to find current sources, fetch pages, and compare evidence. Helps narrow queries and corroborate results when the answer depends on external information. |

### Runtime setup

| Skill | Available in | Capabilities and value |
| --- | --- | --- |
| [antigravity-operating-contract](.agents/skills/antigravity-operating-contract/SKILL.md) | Shared | Gives Antigravity and Gemini tasks a consistent startup, evidence, and handoff procedure for reviews, planning, and implementation. Catches missing context and incomplete reviewer handoffs before downstream work relies on them. |
| [claude-code-configuration](.agents/skills/claude-code-configuration/SKILL.md) | Shared, Claude | Diagnoses and configures Claude Code settings, MCP servers, and local setup. Traces which settings layer owns a behavior so a fix lands at the intended project or user scope. |

## Run the skill evaluations

The [Waza evaluation guide](evals/README.md) explains how to run the 21
offline trigger suites and six model-backed behavior suites. Run an offline
suite first to verify skill routing and fixture wiring.

```sh
waza --no-update-check run evals/work-orchestration/eval.yaml -v
```

## How the skills work together

- **Review a migration PR.** Start with `pr-workflow` to establish the exact
  revision. Use `reviewer` for change-wide findings and `database-reviewer`
  for locks, compatibility, rollout, and recovery.
- **Investigate a failed visual test.** Use `browser-e2e` to classify the run,
  `vr-failure-analyzer` to compare artifacts, and `local-browser-workflow`
  if reproduction depends on local routing or login.
- **Plan a multi-agent change.** Use `work-orchestration` to define scope and
  ownership, `cross-harness-workflow` when independent perspectives are
  requested, and `code-authoring` for implementation and validation.

[Shared agent instructions](AGENTS.md) · [Repository guide](repo.md) ·
[Claude guidance](CLAUDE.md) · [Gemini guidance](GEMINI.md)
