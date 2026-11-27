<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-23 (Yarn 1 frontend validation contract) -->

# PR Local CI Checks Reference

## Purpose

Use this skill to reduce CI back-and-forth by reproducing the PR-triggered
GitHub Actions gates locally from the same disposable worktree that will be
pushed or handed off.

This skill owns PR CI command selection. It does not own git worktree creation,
Husky bootstrap, or push/auth mechanics; use `worktree-readiness` for
that setup before running these checks.

When local CI selection or failure classification needs a second pass, ask for
an available reviewer with the relevant workflow snippets, logs, and generated
notes. Do not block local validation when a reviewer is unavailable.

When a local command fails while reproducing PR CI, classify the failure before
editing: product code, test expectation, workflow configuration,
dependency/install, runner/resource, flaky timing, external service,
permission/auth, or unknown. Capture the workflow, job, command, failing step,
primary error text, and file path or test name when available.

This skill is for PR gates, not dispatch-only E2E workflows. If E2E fails on a
live PR or release workflow, use the E2E triage skills after checking whether
the failing workflow is actually triggered by `pull_request`.

## USE FOR

- reproducing `pull_request` GitHub Actions gates from an existing worktree
- choosing frontend, backend, catalog, or coverage validation commands
- checking PR path filters and base-branch diff before handoff or push

## DO NOT USE FOR

- creating or preparing a worktree; use `worktree-readiness`
- live PR CI inspection before local reproduction; use `references/ci-worktree.md`
- dispatch-only E2E workflow triage; use `browser-e2e` plus
  `github-workflow` auth lane

If the user shares a GitHub Actions job URL for `.github/workflows/e2e-*.yml`
triggered by `workflow_dispatch` or `workflow_run`, do not force it into the
PR-gate flow. Pull the live job metadata/logs with `github-workflow` auth lane, classify
the failure with `browser-e2e`, then reproduce the exact
`npm run tests:*` sequence from the workflow file in the target worktree.

For staging dispatch workflows, run a reachability probe before any local
reproduction from the execution surface that will run validation:

```bash
curl -I --max-time 20 https://app.staging.example.com/
```

In a sandboxed agent runtime, a sandboxed DNS or network failure is
inconclusive. Retry the probe from a non-sandbox shell, use browser
tools to open `https://app.staging.example.com/`, or ask the user for the
terminal result if escalation is unavailable. For Docker snapshot or Docker
Playwright runs, also prove the container route before refreshing baselines:

```bash
docker compose -f docker-compose.snapshots.yml run --rm --entrypoint node playwright-snapshots -e "fetch('https://app.staging.example.com/').then(r=>console.log(r.status, r.url)).catch(e=>{console.error(e); process.exit(1)})"
```

Hard-stop only when the execution surface that will run validation cannot reach
staging: the non-sandbox host probe for host-side runs, or the Docker probe for
Docker-based runs. If Chrome/browser or the user's terminal reaches staging but
the agent sandbox cannot, report a sandbox limitation and continue through the
reachable surface. If browser reaches staging but host shell or Docker does not,
report a local routing split for that surface, not Learn Staging downtime.

Concrete example: `.github/workflows/e2e-smoke-stg.yml` runs
this staging sequence from `e2e/pd/`:

```bash
npm run tests:example-app
npm run tests:auth-bootstrap
npm run tests:example-app-e2e-chromium-auth-smoke
npm run tests:coveo-search-smoke-auth
```

If the public smoke command fails first, later auth-result artifacts may still
exist as placeholders. Do not treat a tiny JSON artifact with empty `suites` as
proof that the later Playwright step actually ran.

Concrete example: `.github/workflows/e2e-visual-regression-test-stg.yml` runs
this standard staging sequence from `e2e/pd/`:

```bash
npm run tests:auth-bootstrap
npm run tests:visual-regression-chromium:all
```

The documented staging and production visual-regression workflows are
Chromium-only. Firefox visual-regression package scripts are inactive/manual
surfaces; do not spend time generating Firefox baselines or blocking a PR on
missing Firefox snapshots unless a workflow change activates Firefox or the
user explicitly asks for that lane.

The workflow also has an `optional` matrix leg that overrides the CSV inputs:

```bash
VR_AUTH_DATA_CSV_PATH=tests/e2e/data/visual-regression-auth-optional.csv
VR_DATA_CSV_PATH=tests/e2e/data/visual-regression-optional.csv
```

For that workflow, use host-side `npm run` or `npx playwright test ... --grep`
runs only for diagnosis. If the fix is a baseline refresh, regenerate the
committed PNGs via `docker compose -f docker-compose.snapshots.yml run --rm ...`
from `e2e/pd/` and finish with a full Docker validation using
`UPDATE_SNAPSHOTS=false`. Do not commit staging VR baselines captured from the
host render surface.

For staging VR compare/update runs, pin the shared static account explicitly:
`AUTH_STATIC_USER_MODE=1`, `E2E_SINGLE_AUTH_USER=1`, and
`TEST_USER_EMAIL=e2e-user@example.com`. If the worktree `.env.local`,
shell, or reusable run metadata points at a different static email, correct that
before trusting the compare/update result.

Before you assume a staging VR branch is missing merged images, diff
`e2e/pd/tests/e2e/__screenshots__` between the branch under test and the branch
receiving the merge. If the committed PNG trees match, keep debugging execution
mode rather than baseline history.

When reproducing from a worktree, inspect `e2e/pd/.env` and `.env.local`
before trusting host-side auth/bootstrap results. If `E2E_PROJECT_ROOT` still
references the root checkout, host runs can mutate or reuse `.auth/` and
`test-results/` from the wrong tree. Point host-side worktree runs at the
worktree's own `e2e/pd` path; keep `E2E_PROJECT_ROOT=/app` for Docker reuse of
bind-mounted worktree auth artifacts.

Before switching the same worktree from staging to production, or production to
staging, clean or isolate `.auth/`, `test-results/`, and run metadata. For
production CI parity, do not source a staging `.env.local`; use `.env` plus the
explicit production tuple, or unset staging-only values before running the
production command.

If a worktree Docker auth subset interrupts with `TargetClosedError` during the
scroll/evaluate phase, rerun only the interrupted auth titles with
`VR_WORKERS=1`, `AUTH_WORKER_COUNT=1`, and `E2E_REUSE_LAST_RUN=0` before you
conclude the branch contents are bad. A passing serial rerun means the earlier
failure was local concurrency/reuse noise.

If Docker compare reproduces a real snapshot mismatch but
`UPDATE_SNAPSHOTS=true` fails inside `auth.setup.spec.ts`, do not assume the
account is bad. Refresh can hit a fresh bootstrap path that compare never used.
Inspect the exported auth screenshot/trace or validate the login path in the VS
Code integrated browser before changing selectors. On staging Learn pages there
can be more than one visible `Sign In` control (hero CTA plus user-menu item),
so a generic `button[name=/sign in/i]` click can target the wrong control.

After a targeted refresh, still rerun the full Docker
`npm run tests:visual-regression-chromium:all` command. The first failure
summary can miss additional auth drift that only appears after the initial
mismatches are refreshed.

If that full Docker rerun ends `status: passed` but reports retry-healed
`flaky` titles, treat the baseline refresh as validated and track the named
retry-healed case separately as residual flake. Do not reopen baseline scope
unless the final attempt still mismatched.

When a VR follow-up PR stays open across multiple validation passes, refresh the
PR body in the same pass as the final validation. Reuse an earlier VR PR body
only as structure; replace the verification section with the latest successful
staging and production visual-regression run URLs for the current PR `head_sha`.
Do not leave stale workflow links from an older branch or prior validation run
in reviewer-facing PR text.

## First Scan CI

Always rescan workflows before choosing commands. Do not rely on memory.

```bash
rg -l "pull_request" .github/workflows
rg -n "name:|pull_request|paths:|node-version|go-version|go-version-file|working-directory|run:|uses:" \
  .github/workflows/*.yml .github/workflows/*.yaml
```

As of 2026-04-25, PR-triggered workflows are:

- `.github/workflows/conventional-commits-lint.yml`
- `.github/workflows/frontend-validate.yml` for `app/**`
- `.github/workflows/backend-validate.yml` for `backend/**`
- `.github/workflows/backend-cover-diff.yml` for `backend/**`
- `.github/workflows/validate_catalog.yaml` for `catalog-info.yaml`

Some Terraform Cloud and SAST/security provider checks only run for PRs whose
base is `main`. They may be absent while a PR is stacked on a parent branch and
appear only after the parent merges and the child is retargeted to `main`.
Local validation can cover formatting and static Terraform source inspection,
but it does not replace those main-base provider checks.

Do not run Terraform CLI commands that require Terraform Cloud auth, private
module registry access, remote state, plan, or apply unless the user supplies a
working authenticated path for this session. `terraform fmt -check` and
source-only inspection are allowed. If validation requires state comparison and
no local state path was supplied, stop the state-dependent work, ask the user to
manually download the relevant Terraform Cloud state file, and resume only
after the user provides the local file path. Test states are at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-test/states`;
Staging states are at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-stg/states`;
Production states are at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-prd/states`.

Use the PR base branch when deciding path filters:

```bash
git fetch origin main
git diff --name-only origin/main...HEAD
```

If the PR targets a branch other than `main`, replace `origin/main` with the
actual base ref from the PR metadata.

## Worktree Setup

Run checks from the PR worktree, not from another checkout, unless the user
explicitly asks for local-only validation. Before these checks, complete
`worktree-readiness` for any worktree creation, branch-local dependency
install, Husky setup, or push/auth preparation.

```bash
git status --short --branch
```

If local Node differs from the workflow version, report the mismatch. Continue
with local checks when no matching Node manager is available, but label the
result as locally approximate rather than exact CI parity.

If a Docker snapshot refresh left `test-results/visual-regression`,
`.last-run.json`, `playwright-report`, `.auth`, or `.snapshots-artifacts`
root-owned in the worktree, repair ownership before rerunning host-side
`npm run tests:*` commands. Otherwise follow-up auth/bootstrap checks can fail
with `EACCES` before the real workflow logic starts.

For clean push-grade proof from the current worktree, do not trust reuse
defaults from `.env.local`. Override them explicitly for host-side auth or
smoke verification:

```bash
E2E_PROJECT_ROOT="$PWD" \
E2E_REUSE_LAST_RUN=0 \
E2E_FORCE_NEW_RUN=1 \
npm run tests:auth-bootstrap
```

If this still logs a different checkout's `E2E_PROJECT_ROOT` or hydrates an
older `RUN_ID`, the result is contaminated and should not be treated as
push-ready proof.

Docker snapshot runs can recreate the full `test-results/` tree as root-owned,
not just `test-results/visual-regression/.last-run.json`. Before rerunning
host-side smoke/auth commands, remove or `chown` the whole directory so the
reporters can write normally.

If the branch is a stacked staging-fixes branch on top of another E2E branch,
diff the child against the base before push for the protected auth-surface
files:

```bash
git diff --name-status <base-ref>..HEAD -- \
  e2e/pd/config.ts \
  e2e/pd/page-objects/connect-backend/LoginView.component.ts \
  e2e/pd/page-objects/example-app/LoginView.component.ts \
  e2e/pd/fixtures/authManager.ts \
  e2e/pd/tests/auth.setup.spec.ts \
  e2e/pd/utils/learnLogin.ts \
  e2e/pd/utils/legacyIframeLogin.ts
```

That diff should be empty when the child branch is only carrying staging smoke,
visual-regression helpers, and PNG refreshes.

## Conventional Commits

This workflow always runs on PRs. Validate both the PR title and commit
subjects.

Allowed subject pattern:

```text
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([A-Za-z0-9-]+)\))?(!)?: .+
```

Local checks:

```bash
git log --format=%s origin/main..HEAD
```

Confirm every non-merge, non-default-revert subject matches the pattern. If the
PR already exists, read the live PR title and check it too. If the PR does not
exist yet, check the intended title before opening it.

## Frontend Validate

Run this when `git diff --name-only <base>...HEAD` includes `app/**`.

Workflow parity:

- working directory: `app`
- Node: `22`
- setup: `cp app/.env.test app/.env`
- install: `yarn install --frozen-lockfile --non-interactive`
- commands: `yarn lint`, `yarn prettier`, `yarn type-check`,
  `yarn test-no-report`, `yarn build`

Local reproduction from repo root:

```bash
cp app/.env.test app/.env
yarn --cwd app install --frozen-lockfile --non-interactive
git diff --exit-code -- app/yarn.lock
yarn --cwd app lint
yarn --cwd app prettier
yarn --cwd app type-check
yarn --cwd app test-no-report
yarn --cwd app build
```

Important frontend details:

- `yarn lint` runs ESLint without `--fix`; use a separate explicit fix command
  only for files owned by the current task.
- `next build` can rewrite `app/next-env.d.ts` locally. Restore
  that generated side effect unless it is the intended change.
- If generated `app/.next` ownership blocks validation, re-enter
  `worktree-readiness` for the exact-path preflight. Do not recursively
  change app ownership or delete broader app/repository paths.
- `yarn prettier` checks the whole app. For focused checks or fixes, use the
  argument-forwarding scripts so Yarn 1 does not combine the target files with
  the whole-app `.` argument:

```bash
yarn --cwd app prettier:files path/to/file.tsx
yarn --cwd app prettier:fix:files path/to/file.tsx
```

- Do not count a Prettier exit code as proof when it warns that configured
  options or plugins were ignored. Repair the dependency/config path first.
- `yarn build` may need network access for `next/font` Google Fonts. If it
  fails only with `Failed to fetch Inter from Google Fonts`, rerun with network
  access before calling it a code failure.
- Existing warnings, such as the `@next/next/no-img-element` warning in
  `TutorialHeader.tsx`, are not failures unless the command exits non-zero.

## Backend Validate

Run this when changed files include `backend/**`.

This is a pre-PR-create, pre-PR-update, pre-push, and pre-review-fix gate for
backend diffs. Remote backend CI failures cost too much review time to treat
this as optional. Before any GitHub-visible update for a backend PR, run the
repo-owned backend CI parity helper from the exact clean worktree and commit
that will be pushed or described:

```bash
scripts/dev/run-backend-ci-checks.sh <repo-root>/tmp/worktrees/<slug> --all
```

`--all` is push-grade parity for `Backend - Validate`: setup, branch-pinned
lint, race/Testcontainers tests, migration order, generated-source drift, and
build. It calls `prepare-worktree-readiness.sh` first, uses the target
worktree's workflow pins, installs tools into that worktree's `backend/bin`,
and fails if tracked files become dirty. Do not replace this gate with
targeted package tests, a local build, a global linter, or manual command
assembly. If it cannot run locally, stop and report the exact `Pending
Verification` blocker before the GitHub write.

This helper requires clean tracked state. For pre-commit exploration with dirty
intended source edits, use focused package commands as local development aids,
then commit or otherwise produce the push candidate and run the helper before
PR publication, push, reviewer request, or PR-body readiness claims.

For stacked backend PRs, run the helper from the child worktree after every
child rebase, not only from the parent that changed. A clean parent run or an
older child run is not proof for the child commit GitHub will test.

Backend race tests use Testcontainers. If the helper fails before product code
runs because Docker or Testcontainers is unavailable, classify it as local
setup and mark the backend gate `Pending Verification`; do not call the product
broken or spend GitHub runner minutes unless local execution is genuinely
blocked.

If live CI fails a backend gate that was not reproduced locally, run the helper
or the specific failed helper mode before pushing another fix. Do not repair
the code, push immediately, and describe the PR as fixed based only on a
targeted test; the failed workflow has already proven the missing validation
surface matters for this PR.

Backend race tests use Testcontainers; verify Docker is available before
treating container startup failures as code failures.

Backend integration tests that use the shared Testcontainers database pool need
explicit isolation when they bypass the suite runner. If a test creates or drops
triggers, functions, tables, indexes, extensions, or other database-wide DDL
through a shared pool, do not leave it as an unconstrained `t.Parallel()` test.
Use the repository's database-suite runner, semaphore, cleanup boundary, or a
package-level mutex around the direct-pool section. Validate the whole touched
package after adding that isolation, because a focused single-test pass can
miss cross-test interference.

## Backend Cover Diff

Run this when changed files include `backend/**` and coverage changed or the PR
will receive a coverage comment.

Cover diff is separate from `--all` because it is slower and its GitHub-only
side effect is the PR comment. Use the helper explicitly:

```bash
scripts/dev/run-backend-ci-checks.sh <repo-root>/tmp/worktrees/<slug> --cover
```

For local head-vs-base comparison, pass the exact PR base ref or SHA:

```bash
scripts/dev/run-backend-ci-checks.sh <repo-root>/tmp/worktrees/<slug> --cover --base <base-ref-or-sha>
```

The helper writes coverage artifacts under repo `tmp/`, not into the target
worktree, and never posts the GitHub PR comment. A local cover pass is mostly
evidence for the PR comment; `Backend - Validate` remains the harder pass/fail
gate.

## Catalog Validation

Run this when changed files include `catalog-info.yaml`.

The PR workflow uses `RoadieHQ/backstage-entity-validator@v0.3.2`. There is no
repo-pinned local wrapper today. Prefer a real local action runner if available,
or run the same validator version directly only after confirming the CLI
invocation in the current environment. If neither is available, mark catalog
validation `Pending Verification` and call out that this gate was not locally
reproduced.

## Completion Checklist

Before handoff or push:

- rerun `git status --short`
- rerun `git diff --check`
- list exactly which PR workflows were reproduced and which were skipped by path
  filter
- say whether each result is CI-matching or locally approximate
- do not leave generated files, coverage files, or helper artifacts in the diff
  unless they are intended changes
