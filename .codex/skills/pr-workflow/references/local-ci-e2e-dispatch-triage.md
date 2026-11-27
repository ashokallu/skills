# Dispatch-Only E2E Triage Reference

Use this only after confirming the failing workflow is triggered by
`workflow_dispatch` or `workflow_run`, not `pull_request`.

If the user shares a GitHub Actions job URL for `.github/workflows/e2e-*.yml`,
pull live job metadata/logs with `github-workflow` auth lane, classify the failure with
`browser-e2e`, then reproduce the exact `npm run tests:*` sequence from
the workflow file in the target worktree.

`.github/workflows/e2e-smoke-stg.yml` runs this staging
sequence from `e2e/pd/`:

```bash
npm run tests:example-app
npm run tests:auth-bootstrap
npm run tests:example-app-e2e-chromium-auth-smoke
npm run tests:coveo-search-smoke-auth
```

If the public smoke command fails first, later auth-result artifacts may still
exist as placeholders. Do not treat a tiny JSON artifact with empty `suites` as
proof that the later Playwright step actually ran.

`.github/workflows/e2e-visual-regression-test-stg.yml` runs this standard
staging sequence from `e2e/pd/`:

```bash
npm run tests:auth-bootstrap
npm run tests:visual-regression-chromium:all
```

The documented staging and production visual-regression workflows are
Chromium-only. Firefox visual-regression package scripts are inactive/manual
surfaces; do not generate Firefox baselines or block a PR on missing Firefox
snapshots unless a workflow change activates Firefox or the user asks for that
lane.

The optional matrix leg overrides the CSV inputs:

```bash
VR_AUTH_DATA_CSV_PATH=tests/e2e/data/visual-regression-auth-optional.csv
VR_DATA_CSV_PATH=tests/e2e/data/visual-regression-optional.csv
```

For visual-regression workflows, use host-side `npm run` or
`npx playwright test ... --grep` only for diagnosis. If the fix is a baseline
refresh, regenerate committed PNGs through
`docker compose -f docker-compose.snapshots.yml run --rm ...` from `e2e/pd/`
and finish with Docker validation using `UPDATE_SNAPSHOTS=false`.

Before assuming a staging VR branch is missing merged images, diff
`e2e/pd/tests/e2e/__screenshots__` between the branch under test and the branch
receiving the merge. If committed PNG trees match, debug execution mode instead
of baseline history.

When reproducing from a worktree, inspect `e2e/pd/.env` and `.env.local`.
If `E2E_PROJECT_ROOT` points at the root checkout, host runs can mutate or
reuse `.auth/` and `test-results/` from the wrong tree. Point host-side runs at
the worktree's own `e2e/pd`; keep `E2E_PROJECT_ROOT=/app` for Docker reuse of
bind-mounted worktree auth artifacts.

Before switching the same worktree between staging and production, clean or
isolate `.auth/`, `test-results/`, and run metadata. For production CI parity,
do not source a staging `.env.local`; use `.env` plus the explicit production
tuple, or unset staging-only values.

If a Docker auth subset interrupts with `TargetClosedError`, rerun only the
interrupted auth titles with `VR_WORKERS=1`, `AUTH_WORKER_COUNT=1`, and
`E2E_REUSE_LAST_RUN=0` before concluding branch contents are bad. A passing
serial rerun means the earlier failure was local concurrency or reuse noise.

If Docker compare reproduces a real snapshot mismatch but
`UPDATE_SNAPSHOTS=true` fails inside `auth.setup.spec.ts`, do not assume the
account is bad. Inspect the exported auth screenshot/trace or validate the
login path in the VS Code integrated browser before changing selectors. On
staging Learn pages there can be more than one visible `Sign In` control.

After a targeted refresh, still rerun the full Docker
`npm run tests:visual-regression-chromium:all` command. The first failure
summary can miss additional auth drift.
