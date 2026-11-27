<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# DX Tooling Authoring

Use this lane when code authoring changes developer workflow, repo scripts,
task runner config, local Docker compose, helper scripts, local environment
templates, lint/format commands, or validation tooling.

This lane preserves the useful workflow from the Copilot DX and lint agents.
It does not preserve Copilot-specific tool names, phase packets, or agent
handoff mechanics.

## Ownership

This lane owns local developer tooling and validation ergonomics outside the CI
workflow file itself. If the edit changes GitHub Actions workflow YAML, path
filters, matrices, caches, artifacts, runner settings, or workflow permissions,
use `ci-workflow-authoring.md` instead or alongside this lane.

## Mission

Make developer workflows faster, more reliable, and less surprising without
creating new setup debt.

Follow this sequence:

1. Discover existing commands and patterns before adding a new one:
   `.mise.toml`, package scripts, `scripts/`, Docker compose, Makefiles, and
   CI workflows.
2. Identify the gap: broken command, missing helper, slow path, confusing
   setup, or stale validation.
3. Make the smallest change that follows existing naming, location, and
   package-manager conventions.
4. Verify the command, config, or script actually works.
5. Update help text, README snippets, env examples, or inline comments only
   when the workflow changed.
6. Check CI alignment when local commands overlap with workflow commands.

## Repo Conventions

- Task runner: `.mise.toml`, names usually follow `<scope>:<action>` or
  `<scope>:<category>:<action>`.
- Primary local compose file: `docker-compose.dev.connect.yml`.
- Frontend package manager: Yarn v1 under `app/`.
- Backend tooling: Go under `backend/`; generated code comes from source plus
  repo generators.
- E2E package manager: npm under `e2e/pd/`.
- Scripts should use `#!/usr/bin/env bash`, clear exit codes, timeouts where
  appropriate, and no hardcoded secrets.

## Validation Tiers

- Script/task comment or naming: syntax or shellcheck-equivalent validation
  when available.
- New or modified task: run the task, or mark exact blocker and command
  `Pending Verification`.
- Docker compose change: run `docker compose -f docker-compose.dev.connect.yml config`; start only the affected service when runtime proof is required, then clean up.
- Cross-stack workflow: run affected stack checks and compare with CI command
  references.
- New dev tool integration: verify install/discovery path, usage command,
  documentation, and rollback.

## Lint And Formatting Safety

- Lint-only work must be zero behavior change.
- Prefer repo tasks such as `mise run app:lint`, `mise run backend:lint`, or
  `mise run backend:lint:fix` when they exist.
- Use targeted formatter or lint fixes. Do not drive-by format unrelated files
  unless the repo's formatter owns whole-file changes for that file type.
- If a lint finding requires changing logic, stop treating it as lint-only and
  route through implementation plus the relevant risk lane.
- Do not relax rules, add blanket disables, or suppress warnings without a
  reason tied to a concrete false positive or required follow-up.

## Safety

- Do not break existing task names without migration guidance.
- Do not introduce manual setup steps without documenting them.
- Do not leave background processes running after validation.
- Do not expose new ports, credentials, or local services without documenting
  purpose and scope.
- Do not use bare `docker compose` when the intended target is the learn
  local-dev compose file.

## Output

```text
DX tooling authoring:
- workflow changed: <task/script/config>
- compatibility: <preserved | breaking with migration>
- verification: <command/result or Pending Verification>
- CI/docs alignment: <checked | not applicable | Pending Verification>
```
