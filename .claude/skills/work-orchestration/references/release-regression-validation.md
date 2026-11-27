<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 (added merged-PR release and manual-deploy ancestry proof) -->

# Release Regression Validation

```text
Type: owning lane
Use when: the user asks whether a released change behaves correctly in a live
          environment
Skip when: only local/CI validation or pre-release planning is requested
Owns: post-deploy Staging/Production release identity and bounded live regression proof
Does not own: deployment, production writes, code fixes, or pre-apply Terraform advice
Allowed side effects: authorized read-only cloud/data/log/browser/API checks; local
                      setup only under a separately declared write boundary
Inputs: environment, service/job, expected release/commit, changed behavior, access
        boundary, and acceptance criteria
Exit states: pass, fail, partial, blocked
Outputs: release/runtime identity, selected regression evidence, and residual gaps
Re-enter when: release, revision/image/config/traffic, behavior, or environment changes
```

Use this lane after a Staging or Production release deploy when the user asks
to validate that a recently merged feature behaves correctly in the live
environment. This lane owns the validation sequence and evidence boundary. It
routes browser/auth mechanics to `browser-e2e` and read-only database
proof to `readonly-data-access`.

Before live reads, confirm the exact environment, project/account, principal,
release/revision target, time window, and read-only scope through
`external-system-boundaries`; apply `privacy-and-secrets-boundary` to logs,
rows, screenshots, and auth material. Verify tool/auth capability at runtime
when uncertain. This lane never treats access to one environment or project as
permission for another.

## Scope

Use this lane for:

- post-deploy Staging or Production smoke and regression validation
- feature-flag or runtime-env validation on Cloud Run services or jobs
- authenticated API or browser checks against deployed Learn
- read-only DB proof that live data changed, did not change, or stayed scoped
- log checks during the exact validation window
- normal-user negative regression checks where the feature should stay inert

Do not use this lane for:

- PR publication or CI closeout before deploy
- schema or code changes
- production-writing operations, data repair, or cleanup
- ordinary PR review verdicts

## Release And Runtime Proof

Before testing behavior, prove what is deployed:

1. If this follows a PR merge, identify the latest published non-draft release
   and prove whether it contains that PR before accepting it as the target:

   ```bash
   gh release list --limit 10 --json tagName,publishedAt,isDraft,isPrerelease
   gh release view <release-tag> --json tagName,targetCommitish,publishedAt,url
   git merge-base --is-ancestor <pr-head-or-merge-sha> <release-tag>
   ```

   Select by GitHub publication metadata, not lexical or local tag ordering.
   In example-app, a published release is normally associated with the
   Manual Release path to Staging, but this is only release provenance. Keep
   `merged`, `included in release`, and `verified live` as separate states.

2. Check the release tag, target commit, and `origin/main` relationship:

   ```bash
   gh release view <release-tag> --json tagName,targetCommitish,publishedAt,url
   git ls-remote --tags origin refs/tags/<release-tag>
   git ls-remote origin main
   ```

   The tag SHA and the intended branch SHA must match the release story. If
   they do not, stop and explain the mismatch before testing behavior.

3. Check the deployed Cloud Run service or job image tag and commit labels:

   ```bash
   gcloud run services describe <service> \
     --project <project> \
     --region <region> \
     --format yaml

   gcloud run jobs describe <job> \
     --project <project> \
     --region <region> \
     --format yaml
   ```

   Confirm `status.latestReadyRevisionName`, image identity or immutable digest,
   template commit labels, readiness, and traffic. For jobs, verify the job
   template image/commit separately and do not confuse an old
   `latestCreatedExecution` with proof that the new release has run.

   The live commit must equal the release commit or be a proven descendant that
   contains the merged PR. Verify every service or job the PR can affect; one
   matching surface does not prove the others were deployed.

   For a user-declared manual branch deploy, or when the live commit label does
   not correspond to a release tag, resolve the live branch/main commit and
   prove that it contains the PR head or merge commit. Report it as a manual
   deploy, not as the latest release. If neither release ancestry nor live
   commit ancestry can be proven, mark deployment `Pending Verification`.

4. Check runtime environment variables or feature flags that decide whether the
   feature is active. For flag-driven changes, state each required flag and its
   live value. If a feature is meant to be wired but disabled, prove both the
   supporting config and disabled flag.

   For Cloud Run, keep code release and runtime configuration separate:

   - A release deploy proves which image and commit are running.
   - Terraform or service configuration proves which env vars, secrets,
     resources, scaling, and traffic policy wrap that image.
   - A Terraform-only env-var change should create a new Cloud Run revision
     using the currently deployed image. Do not call for a new app release
     unless the live image lacks the required code.
   - If Terraform shows a container name such as `<service>-1`, verify whether
     that is the container block name rather than a service rename before
     treating it as drift.
   - If Terraform preserves the live image because image changes are ignored
     by lifecycle rules, state that explicitly instead of implying Terraform
     rebuilt or rewrote the Docker image.

   Cloud Run has a stale-plan footgun when Terraform manages the service
   template while release automation also deploys images:

   - A Terraform plan created before an app release can carry the older image
     in the planned service template, even when image drift is ignored in
     lifecycle rules.
   - If that stale plan is applied after a newer release deploy, Cloud Run may
     create a new revision using the older image and route traffic to it.
   - Treat any saved Terraform plan as invalid after a Cloud Run app release,
     manual deploy, rollback, or traffic change. Create a fresh plan after the
     latest deploy and inspect the planned service template before apply.
   - Before approving or recommending a Terraform apply that touches Cloud Run,
     compare the intended release tag with the live service image and the image
     shown in the plan or apply preview. If they differ, stop and refresh the
     plan.
   - After Terraform apply, verify live Cloud Run image tags for every touched
     service or job before claiming the release is still intact.
   - If Terraform has already replayed an older image but the runtime config is
     now correct, recommend that the owning release/deployment workflow evaluate
     an image-only Cloud Run redeploy of the intended tag. This lane must not
     perform the redeploy. Do not recommend reapplying the stale Terraform plan;
     require fresh approval, rollback/readback evidence, then verify both the
     image and Terraform-managed env vars on the resulting revision.

5. Check readiness and recent error logs for the relevant services:

   ```bash
   gcloud run services describe <service> \
     --project <project> \
     --region <region> \
     --format 'value(status.conditions[0].type,status.conditions[0].status)'

   gcloud logging read '<service/revision filter> AND severity>=ERROR' \
     --project <project> \
     --freshness 2h \
     --limit 20
   ```

If the release tag, deployed image, commit label, or feature flag cannot be
verified, keep behavior claims under `Pending Verification`.

After a Terraform apply that changes Cloud Run runtime config, prove the new
revision state before testing product behavior:

- `status.latestReadyRevisionName` equals the revision receiving traffic
- traffic is on the intended revision and percent
- the revision image tag and commit label still contain the expected code
- required runtime env vars or Secret Manager references have the expected
  values or secret aliases, without printing secret payloads
- readiness/health checks pass on the deployed service or job

Do not rely on the Terraform plan alone as post-apply proof. The live Cloud Run
revision is the source of truth for what users are hitting.

## Worktree And Env Setup

When browser or E2E validation requires an isolated checkout, route creation
through `worktree-readiness` and use a dedicated, explicitly authorized
`origin/main`-based worktree under `tmp/worktrees/<slug>`. Do not run live
release validation from `local-dev-reference`. A read-only release-status request
does not by itself authorize worktree creation or dependency installation.

Never use `local-dev-reference` to infer Staging or Production package versions,
tool versions, workflow pins, runtime config, feature flags, or dependency
behavior. It may be ahead of `main` and ahead of the deployed release. For
environment validation, derive versions and behavior from the deployed release
tag commit, live Cloud Run service or job metadata, Terraform plan/state for
that environment, and the workflow files at the release commit.

After `worktree-readiness` returns an authorized checkout and exact
branch/path contract, the owning setup phases may use this illustrative shape.
Do not execute the git commands merely because this lane was loaded:

```bash
git fetch origin main --prune
git worktree add -B <validation-branch> tmp/worktrees/<validation-slug> origin/main
cd tmp/worktrees/<validation-slug>/e2e/pd
npm ci
```

The fetch/worktree actions belong to `worktree-readiness`; dependency
installation belongs to the authorized environment/validation setup and may
have network, cache, lockfile, or generated-output effects that must be recorded.

Use a descriptive branch and slug such as `<env>-<feature>-regression`. This
worktree is a validation surface, not a PR branch, unless the user explicitly
asks for publication.

Before using E2E auth or Playwright:

- load `browser-e2e` for auth, browser, or Playwright mechanics
- install dependencies in the worktree when needed
- choose the target env file explicitly:
  - Staging uses `e2e/pd/.env.local`
  - Production uses `e2e/pd/.env`
- use the repo-approved secret-loading mechanism for the chosen environment;
  copy/recreate an env file only when the privacy boundary authorizes the exact
  source, destination, permissions, retention, and cleanup, and never print or
  stage its contents
- set `E2E_PROJECT_ROOT="$PWD"` for worktree-local host-side runs
- reuse a recent compatible `.auth` run when it matches the target
  environment, base URL, and scenario
- prefer an existing dedicated test identity whose use is authorized for the
  target environment; this lane does not create users or test data

Never print passwords, cookies, storage-state JSON, tokens, or full env files.

For auth bootstrap, first determine whether the repo's E2E auth setup path only
logs in an existing identity or also provisions users/data. The command below
is illustrative and may run only when `browser-e2e` confirms its current
behavior and the active boundary authorizes every external effect. A local
worktree command can still mutate Staging or Production. If the setup provisions
a user, changes data, sends email, or performs another shared-environment write,
leave this lane and route that operation through `external-system-boundaries`,
`risk-and-side-effects`, and the environment's approved test-data workflow. In
Production, do not provision test identities without an explicit production
runbook and current approval.

When the setup is authorized, keep it worktree-local and make the run
intentionally single-user when one identity is enough:

```bash
E2E_PROJECT_ROOT="$PWD" \
AUTH_WORKER_COUNT=1 \
E2E_WORKER_COUNT=1 \
E2E_SINGLE_AUTH_USER=1 \
AUTH_BOOTSTRAP_BROWSER=chromium \
npx playwright test tests/auth.setup.spec.ts --config=auth.config.ts
```

If the selected config has no named Playwright project, do not add a
`--project` filter. Let the config own project selection.

## Regression Matrix

Pick the smallest matrix that proves the deployed risk. Prefer one negative
regression and one positive regression when both are feasible.

Normal-user negative checks:

- pick an existing authorized test user that is not eligible for the
  feature-specific data path; do not create one in this lane
- record the validation window start timestamp before the request
- call the same public API or UI surface users exercise
- capture status code and the small response fields that prove behavior
- prove the feature made no visible change
- prove no feature-specific impact log was emitted
- prove no warning or error logs appeared during the request window
- use read-only DB evidence to prove the user has no matching feature rows when
  the behavior depends on database membership

For Learn authenticated API checks, prefer a small script or Playwright request
context using the saved storage state instead of manual browser clicking when
UI rendering is not the risk. Use the deployed API prefix from the env file or
observed app routes; do not invent `/api` paths.

Positive-path checks:

- pick an existing authorized user and a read-only or already-approved action
  that should activate the feature
- prove the user-visible output changes exactly as expected
- prove the underlying source rows, derived rows, or read model match the
  response
- prove feature-specific logs are present only when useful and not noisy
- include a fallback or fail-open check when the feature is designed to avoid
  user-facing breakage

If positive-path proof requires creating data, completing content, changing a
profile, triggering a job, or another state-changing user action, route that
action as a separate shared-environment write with target, rollback/cleanup,
and readback. When no approved write path exists, keep the positive path
`Pending Verification` rather than performing it implicitly.

Cross-surface checks:

- test every public surface touched by the deployed path, such as experience,
  aggregated stats, profile, dashboard, or completion endpoints
- when a feature flag is disabled in an environment, prove the disabled path is
  inert even if supporting config such as a run ID is present
- when a feature flag is enabled, prove normal users are not incorrectly
  affected

For lookup-based features, distinguish "the system checked the feature table"
from "the feature affected the user." A normal user may still perform an
indexed lookup so the service can know no rows exist. The regression claim
should be that no deltas, writes, logs, or user-visible effects occurred unless
the design explicitly promises no lookup at all.

For XP overlay read regressions specifically:

- normal users are expected to perform an indexed overlay lookup when overlay
  reads are enabled
- normal users must not receive overlay deltas, overlay writes, or `xp overlay
  applied to user read` logs when they have no overlay rows
- check both `/users/me/experience` and `/users/me/aggregated-stats`
- prove the user has zero rows for the active overlay population run before
  claiming the no-op behavior is correct
- for positive overlay validation, use a historical overlay user only when a
  safe authenticated session exists; otherwise mark positive-path validation
  `Pending Verification` instead of fabricating a fixture in live data

## Data And Log Proof

Load `readonly-data-access` before Cloud SQL, Mongo, or other datastore
inspection. Keep queries bounded and read-only.

For DB-backed regression proof:

- query by target user ID, run ID, content ID, category ID, or another narrow
  key
- record row counts and aggregate values, not large raw payloads
- inspect temporary or migration-report table columns before sampling rows when
  column names may have changed since the last run
- sample only concise projections such as IDs, statuses, counts, and amounts;
  do not paste large arrays, JSON payloads, document lists, or secret-bearing
  fields into chat
- check indexes or query shape when performance risk matters
- prefer replica or secondary reads when the data-access lane requires it
- use the primary read-only workaround only under that lane's rules when
  temporary tables lack replica-reader grants

Shape SQL as small evidence queries. Prefer this pattern:

```sql
SELECT
  COUNT(*) AS matching_rows,
  COALESCE(SUM(<amount_column>), 0) AS matching_total
FROM <table>
WHERE <run_or_feature_key> = '<run-id>'
  AND user_id = '<user-id>';
```

For performance-sensitive lookup paths, prove the expected index exists:

```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = '<table>'
ORDER BY indexname;
```

For log proof:

- capture the request window before making the call
- filter by service revision, user ID, request ID, feature log message, and
  severity
- report absence of errors separately from absence of feature-impact logs
- do not paste secret-bearing log fields

Use bounded log windows around the request, not broad all-day searches, unless
the user asks for trend analysis. A typical first pass is two minutes before
to two minutes after the request:

```bash
gcloud logging read '<revision filter> AND timestamp>="<start>" AND timestamp<="<end>" AND severity>=ERROR' \
  --project <project> \
  --limit 50

gcloud logging read '<revision filter> AND timestamp>="<start>" AND timestamp<="<end>" AND ("<user-id>" OR "<feature-log-message>")' \
  --project <project> \
  --limit 50
```

If a feature emits an impact log only when it changes output, absence of that
log is positive evidence for a normal-user no-op regression. If a feature is
expected to log every lookup, absence is not proof; check the code before using
log absence as evidence.

## Cleanup

Before handoff:

- inventory local artifacts created by this validation run and clean only those
  artifacts whose ownership and cleanup authorization are proven;
- never delete a pre-existing cache, auth artifact, env file, report, trace, or
  another actor's work merely because it appears disposable;
- check the validation worktree status;
- check the root checkout status separately;
- retain or remove `.auth`/sensitive artifacts only under the privacy boundary
  and the owning browser/worktree workflow;
- never stage env files, storage state, `node_modules`, reports, traces, or
  worktree-local generated auth artifacts.

Use read-only status checks directly. Route any non-trivial cleanup through the
owner that created the artifact:

```bash
git status --short --branch
git -C tmp/worktrees/<validation-slug> status --short --branch
```

## Output

```text
Release regression result: PASS | FAIL | PARTIAL | BLOCKED
Environment and target release/revision:
Runtime image/config/flag identity:
Worktree/env source used: <or none; never include secrets>
Scenario/test identity: <redacted as needed>
API/browser evidence:
Read-only database evidence:
Log window and evidence:
Local/shared side effects performed:
Cleanup and rollback state:
Remaining useful cases:
Next owner / re-entry condition:
Pending Verification:
```

Do not claim a release regression is complete until every required evidence
surface for the selected matrix is either verified or explicitly marked
`Pending Verification`. A `PARTIAL` result must name which claim the missing
surface prevents.
