---
name: browser-e2e
description: Use for example-app E2E, Playwright, browser, local UI or auth, visual-regression, screenshot, trace, selector, snapshot, red or retry-healed GitHub Actions Playwright runs, failed-then-passed flake classification, regression or test-bug artifact triage, e2e/pd Playwright test authoring, locator proof, playwright-cli app-local exploration, and Playwright MCP browser workflows.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-28 (added branch-tip scratch worktrees, monorepo leverage, and local route dependency guidance) -->

# Browser E2E

Use this skill as the single first-class example-app route for browser
automation, E2E failures, Playwright test work, local UI/auth verification, and
visual-regression evidence. Keep this file small; load only the reference that
matches the selected lane.

Load the lane-specific detailed workflows from `references/`.

## Route First

Before loading a detailed reference, classify the request:

| Request shape                                                                                                                                         | Load                                                                                                              | Why                                                                                                                 |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| GitHub Actions E2E run is red/flaky, retry-healed, or needs classification before a fix                                                               | `references/flakiness-triage.md`                                                                                  | Read-only evidence gathering and failure-family classification should happen before changing specs or product code. |
| User asks to write/update Playwright specs, inspect selectors, generate test code, use `playwright-cli`, or work directly in `e2e/pd/`                | `references/playwright-cli-overlay.md` plus `.codex/skills/playwright-cli/SKILL.md` when command syntax is needed | The overlay owns example-app routing/auth/TLS; the base skill owns generic `playwright-cli` commands.            |
| Playwright MCP/browser tools are available and the task needs local login, authenticated UI proof, MCP screenshots, snapshots, or browser interaction | `references/playwright-mcp.md`                                                                                    | MCP browser workflows have different auth and secret-handling constraints from `playwright-cli`.                    |
| Unknown root cause spans browser/E2E plus non-browser systems                                                                                         | Start with the `work-orchestration` diagnose lane, then return here for the browser/E2E lane                | The diagnose lane owns general root-cause loops; this skill owns browser/E2E mechanics.                             |

If the task mixes lanes, load the narrowest set that covers the work. For
example, a CI visual-regression failure that needs local selector inspection
usually needs `flakiness-triage.md` first, then `playwright-cli-overlay.md`
only after the failing titles and artifacts are known.

## Shared Rules

- Do not run, fix, refresh, or validate E2E tests from `local-dev-reference`.
  Create or reuse a dedicated `origin/main`-based worktree under
  `tmp/worktrees/<slug>` for any smoke, regression, auth, Playwright, or visual
  regression command. Use `local-dev-reference` only as a reference for current
  instructions, skills, rules, and `.env` / `.env.local` values, copied or
  recreated into the E2E worktree before running commands.
- If the user explicitly asks to validate E2E changes that currently live on a
  non-`main` branch, still do not run from that branch's root checkout. Create
  a sibling scratch worktree from that branch tip (for example
  `tmp/worktrees/local-dev-reference-e2e`) and run the E2E/auth commands there.
- Choose the `e2e/pd` env file by target environment before copying or sourcing
  anything into a worktree: Staging uses `.env.local`, Production uses `.env`,
  and local Learn auth uses the local bootstrap flow. Do not let a copied file,
  shell-exported variable, or "latest" auth run silently decide the target
  environment. State which env file was used without printing its contents.
- Before a Production or Staging auth/browser run, perform an explicit env
  preflight in the target worktree:
  - confirm the worktree is not `local-dev-reference`
  - confirm the intended env file exists in `e2e/pd/`
  - confirm the opposite env file is not accidentally driving the run
  - confirm the Playwright command is run from that worktree's `e2e/pd/`
    directory
  If the target worktree lacks the ignored env file, copy only the intended
  local env file from the trusted checkout or stop with `Pending Verification`.
  Do not print env contents.
- Leverage the monorepo intentionally: use the repo root as a read-only source
  of truth for `app/env/**`, `e2e/pd/.env*`, and `infrastructure/caddy/Caddyfile`,
  then copy only the needed non-secret values into the target E2E worktree and
  run from that worktree's `e2e/pd/` directory.
- Before treating local `/u/` / My Learning failures as product regressions or
  adding local-only skips, verify the sibling connect-backend `dev_server`
  view-server path is actually running. Missing view-server processes can cause
  404/500 shells that look like app failures but are really local setup issues.
- Reuse a recent compatible `e2e/pd/.auth` run when it already proves the
  target environment, base URL, and user state needed for the scenario. Create
  a new Genesis user only when no compatible run exists, the previous auth is
  expired or polluted for the scenario, or the test explicitly needs user
  isolation.
- Load `.github/instructions/e2e-playwright-tests.instructions.md` before
  changing or judging E2E specs, fixtures, page objects, auth helpers, or visual
  baselines.
- Load `.github/instructions/github-workflows.instructions.md` before
  interpreting CI parity, active E2E workflows, workflow steps, or artifact
  names.
- Verify exact scripts in `e2e/pd/package.json` and exact workflow lines before
  running or recommending commands.
- Treat `.auth/` storage state, cookies, passwords, and tokens as sensitive.
  Never print or paste raw secret material.
- For read-only triage, do not update specs, snapshots, selectors, product
  code, or retry workflows reflexively. Produce classification and evidence.
- For implementation or validation requests, run the narrowest repo-proven
  command that exercises the changed browser/E2E surface.
- When a spec explicitly targets a named tutorial, course, or pathway, do not
  silently fall back to unrelated content. Fail explicitly with the missing
  item name, or make the env-specific route choice explicit in the spec when
  local behavior genuinely differs.
- Put reusable local evidence under repo-local `tmp/`; do not reference
  disposable `tmp/` artifacts from durable docs.
- For model-driven browser MCP executors in CI, use Claude models only unless
  a repo-owned workflow explicitly adds a budget cap, turn cap, and schema
  compliance guard for another provider. Non-Claude browser MCP executor runs
  can become disproportionately expensive and may fail to satisfy recorder
  contracts even when the action exits successfully. Non-Claude model
  comparison belongs in planning or acceptance-criteria generation, not in
  browser MCP execution, until those guards exist.

## Base Tool Reference

Do not edit `.codex/skills/playwright-cli/SKILL.md` as part of example-app
workflow tuning. It is the base command manual. This skill and
`references/playwright-cli-overlay.md` provide the example-app overlay.

## Closeout

Report the selected lane, evidence inspected, commands run with working
directory, and remaining `Pending Verification`. If the task was read-only
triage, hand off the smallest actionable next owner rather than silently
switching into edits.
