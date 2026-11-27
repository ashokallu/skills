# Repository guide

This repository contains reusable agent instructions, standalone skills, and
MCP configuration examples.

## Layout

| Path | Purpose |
| --- | --- |
| `.agents/skills/` | Skills for runtimes that use the shared agent directory |
| `.codex/skills/` | Codex skill copies |
| `.claude/skills/` | Claude skill copies |
| [examples/mcp/](examples/mcp/README.md) | Opt-in MCP configuration examples |

Each skill has a `SKILL.md` with a name and description. Use the copy provided
by the active runtime, or read the shared copy when working without discovery.

## Skill routing

| Task | Skill |
| --- | --- |
| Multi-step work or a handoff | `work-orchestration` |
| Implementation or refactoring | `code-authoring` |
| Review of a stable change | `code-review` |
| Database change or rollout review | `database-reviewer` |
| Browser testing or E2E triage | `browser-e2e` |
| PR preparation, review, or check triage | `pull-request-workflow` |
| GitHub operations | `github-workflow` |
| Jira issues | `jira-workflow` |
| Confluence documentation | `confluence-workflow` |

## Commands and validation

In a repository that adopts these files, discover build, test, and generation
commands from its current manifests, task definitions, and CI workflows.
Check the working directory and choose the narrowest check that covers the
affected behavior.

For changes here, verify relative links, skill names, and matching skill copies.
Parse edited MCP examples as JSON or TOML and check them for private endpoints,
literal credentials, machine-specific paths, and references to missing scripts.
Use `git diff --check` before committing.
