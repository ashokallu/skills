<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-22 (validation effects under autonomy ceilings) -->

# Validation

```text
Type: owning lane
Use when: changed behavior or an explicit verify/build/test/smoke request requires proof
Skip when: no change/claim requires validation or a specialist owns the exact proof
           workflow
Owns: selection and execution/reporting of the narrowest deterministic validation that
      proves the current change and risk
Does not own: implementation, review verdict, publication, or live production mutation
Allowed side effects: declared validation effects within the current environment
                      boundary
Inputs: exact target/change, acceptance criteria, risk, available test surfaces, and
        budgets
Exit states: pass, fail, partial, blocked, not applicable
Outputs: command/context/result evidence and next owner
Re-enter when: target/change/risk/test surface changes or validation modifies state
               unexpectedly
```

Use this lane for validation strategy, test selection, verifying a fix, build,
lint, typecheck, smoke-test choice, or reporting validation results.

## Validation Rules

- Before choosing a command, confirm whether the task needs runtime setup. If
  local services, Docker, env files, generated state, queues, caches, or toolchain
  trust are the blocker, route through
  [environment-tooling.md](environment-tooling.md)
  before treating failures as product regressions.
- For validation claims that will support PR publication, release readiness,
  review verdicts, or production decisions, map the claim to evidence through
  [evidence-and-verification-ledger.md](evidence-and-verification-ledger.md).
- After changes, run the narrowest verified command from `repo.md` command
  discovery: targeted tests, type checks, lint, build, or a smoke test.
- Treat requests like "verify it", "try it", "smoke test", "does it build",
  and "does it compile" as requests to actually run the relevant command.
- Report the command, working directory, result, and key failure lines. If the
  command cannot run, say why and name the next-best check.
- Report the branch, worktree, module root, and relevant head SHA when those
  facts affect whether the validation proves the current target. A passing check
  in another checkout, branch, worktree, or stale head is evidence only for that
  surface.
- Choose validation in lanes:
  - targeted: changed files, focused tests, package checks, or focused smoke
  - standard: full affected-stack test, lint, typecheck, or build gate
  - deep: cross-stack, runtime, E2E, coverage, staging, performance, or
    release-readiness evidence when risk justifies it
- When an active Work Item Profile exists, use its complexity, impact scope,
  reversibility, confidence, and named unknowns as provisional validation
  inputs. Reclassify from the actual changed surface and current evidence. A
  trivial diff can still require deep proof when it changes a production-wide
  default, shared data, infrastructure, or a one-way contract; a complex but
  contained refactor does not require deep runtime proof merely because it has
  many files. Record a material profile delta before changing the validation
  route.
- Review forecast is not validation authority. It cannot waive a repo-pinned
  CI-equivalent check, database or other specialist evidence, or a broader gate
  required by the actual blast radius.
- Start with the smallest check that can fail for the changed behavior. Broaden
  to the standard lane when the changed surface or the owning release/handoff
  contract requires it; finishing a local edit is not itself a release claim.
- Once the relevant required checks pass, stop validation and finish the phase.
  Repeat or broaden only for a new change, failure, unresolved concern, or
  independently required gate. Do not add tests that merely mirror the
  implementation or unrelated full-suite runs for reversible low-impact edits.
- A required lane is not optional. If a relevant validation lane is not run,
  mark the proof `Pending Verification` with a blocker class:
  `environment/tooling`, `missing credentials`, `local services unavailable`,
  `scope intentionally not requested`, `unsafe side effect`, `time bounded by
  user`, or `no repo-local equivalent`. Name the smallest command or evidence
  that would clear the gap.
- If a PR or push will trigger a known GitHub check, run the repo-documented
  local equivalent before pushing when the workflow makes that check
  reasonably reproducible. Do not spend GitHub runner minutes discovering
  lint, formatting, generated-code, or unit-test failures that the local lane
  can catch.
- For backend diffs, run the backend CI parity helper from the exact clean
  worktree, branch, and commit being pushed before claiming CI readiness:

  ```bash
  scripts/dev/run-backend-ci-checks.sh <repo-root>/tmp/worktrees/<slug> --all
  ```

  A helper pass in another checkout, another branch, the repo root, or a
  developer-specific command path does not prove the PR head.
- If validation exposes unrelated pre-existing failures, do not hide or repair
  them by default. Report enough evidence to separate them from your change and
  run narrower validation that still covers your work when possible.
- If the command fails before product code runs because of bootstrap, package
  manager, version-manager, Docker, Testcontainers, missing env, local service,
  or wrapper behavior, route through
  [environment-tooling.md](environment-tooling.md)
  before editing product code or calling the product broken.
- If a validation command fails before it reaches product code because of local
  tool-manager state, shell activation, missing trust, unavailable Docker, or
  environment-variable overrides, classify it as environment setup first. Inspect
  the active binary, wrapper, and environment, then rerun through the smallest
  repo-equivalent command path that removes the local wrapper problem. Do not
  edit product code, repo config, or PR metadata to explain away a local setup
  failure.
- If a command starts services, touches a local database, enqueues jobs, warms
  caches, or regenerates files, record the expected mutation and cleanup path in
  the validation report.
- Before running a non-hermetic command, verify that its network, filesystem,
  container, local-data, shared-environment, and notification effects fit the
  active boundary. Shared or Production data writes are external operations,
  not ordinary local validation. Cleanup may remove only artifacts proven to
  be created and owned by the current validation run.
- When a task autonomy envelope is active, validation must fit both its own
  action-specific authorization and every envelope ceiling. A newly discovered
  network target, shared environment, sensitive read, generated mutation,
  paid/resource cost, or monitoring dependency is an upward delta: stop before
  running it and return to the dispatcher. Do not classify a smoke test as
  local merely because the command starts in the local shell.
- When a CI-equivalent command requires an environment override, verify the
  override is visible to the actual tool, not only to the shell prefix. If the
  tool still reports the old value, inspect wrappers such as `mise`, direct
  shims, or login-shell startup files before declaring the validation blocked.
- For lint and formatting work, verify the repo-owned command or config before
  choosing a fixer. Keep the diff scoped to files or lines with violations
  unless the repo's normal formatter intentionally rewrites the whole file.
- Treat lint-only work as zero-behavior-change by default. If a lint warning
  requires changing control flow, data shape, error handling, query behavior, or
  complexity, stop treating it as mechanical cleanup and route it through the
  owning implementation or diagnosis lane.
- Do not relax lint, typecheck, formatter, spellcheck, or Markdown rules unless
  the user explicitly asked for a rules change or the existing rule is proven
  wrong for the codebase. Any suppression should name the rule and reason.
- When tests fail, assume the implementation may be wrong before changing the
  test. Edit tests only when the user asked for a test change, product behavior
  intentionally changed, or current code proves the expectation is stale.
- For bug fixes, prefer a failing test or reproducer first. Run it red when
  practical, then make it pass.
- When writing or changing tests, first read nearby test utilities, fixtures,
  and conventions. The new test should fail for the intended behavior, not for
  syntax, import, fixture, or setup errors.
- Let test coverage scale with risk and blast radius. Keep tests focused for
  narrow changes; broaden coverage for shared contracts, migrations, auth,
  imports, payments, or user-facing workflows.
- Prefer tests that exercise real behavior through public surfaces. Avoid
  copying production logic into assertions or mocks.
- Assert concrete behavior. Assertions like `toBeTruthy`, `toBeDefined`,
  `not.toBeNull`, or existence-only checks are valid only when existence itself
  is the behavior under test.
- Treat vacuous tests, over-mocked tests, fixed sleeps, implementation-detail
  assertions, and tests that only verify mocked behavior as validation smells.
  Prefer a higher-level seam when a unit test needs heavy mocking.
- Classify expensive, flaky, nondeterministic, or external-service tests
  separately from deterministic safety gates. Fast local gates should protect
  merges; slower quality, model, browser, or paid checks should have an
  explicit trigger and a clear reason to run.
- For UI or visual changes, validate the rendered surface with screenshots,
  browser automation, or an equivalent local check when layout, styling,
  interaction, image detail, or responsive behavior matters.
- For UI navigation instructions, include exact control names, visible labels,
  location cues, and the expected result of each step.
- For user-facing changes, do not treat passing tests as value delivery by
  itself. Tie validation back to the value statement, acceptance criteria, or
  user outcome. If runtime proof is unavailable, mark the exact gap `Pending
  Verification` and provide the smallest manual or automated path that would
  prove it.
- For release-readiness input, report scope, risk, verification evidence,
  known gaps, and rollback viability. Issue `GO`, `NO-GO`, or `GO WITH
  CONDITIONS` only when the owning release/incident workflow explicitly assigns
  that advisory decision to this lane; otherwise leave the final readiness
  judgment to that owner. Never call a release ready when rollback is unknown or
  a required verification lane is failing or unrun.

## Reporting Local Validation

- Separate targeted, standard, and deep validation in the report. A focused
  package test can prove a narrow regression, but it does not replace a
  workflow-pinned backend, frontend, browser, or generated-source gate when that
  gate is required before a PR push or handoff.
- For dirty local worktrees, distinguish commands that are expected to leave the
  intended patch present from commands that must leave the tree clean. Use
  path-scoped diff checks for dependency files or generated outputs while the
  main change is uncommitted, and reserve whole-tree clean checks for after the
  patch is committed or when the validation branch is expected to be clean.
- Do not put machine-specific workaround commands in PR bodies. If local
  validation needed a wrapper bypass, direct binary path, or shell workaround,
  report it in the agent handoff only. PR verification should use portable
  repo-relative commands, with any local-only deviation marked separately.

## Output

```text
Validation outcome: PASS | FAIL | PARTIAL | BLOCKED | NOT APPLICABLE
Target and freshness:
Declared effects and actual side effects:
Checks run: <command, working directory, environment, result>
Behavior/claim proved:
Failures or unrelated pre-existing failures:
Cleanup/readback:
Pending Verification and skipped checks:
Next owner:
```

A `PASS` applies only to the named target and claims covered by the checks. A
`PARTIAL` result must state what is proven and the smallest remaining proof.
