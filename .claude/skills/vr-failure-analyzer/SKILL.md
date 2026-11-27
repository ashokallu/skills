---
name: vr-failure-analyzer
description: Use when a example-app visual-regression GitHub Actions run fails and you need to download VR artifacts, inspect Playwright expected/actual/diff images, and prepare release-management/Jira-ready evidence. If you have image-analysis tools or are a vision-language model, use them to summarize UI differences and classify the likely cause, such as Sanity content drift, frontend layout regression, baseline drift, or test instability.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-13 -->

# VR Failure Analyzer

Use this skill for intelligent visual-regression failure triage. It is designed
for local analysis now and for CI/managed-agent automation later.

## Required Context

- Read `browser-e2e` first when the work needs E2E mechanics, Playwright
  command selection, artifact classification, browser screenshots, local repro,
  auth handling, or baseline updates. Load only the narrow lane needed for the
  current VR task.
- Read `.claude/rules/e2e/playwright.md` before judging VR specs, Playwright
  fixtures, CSV data, auth setup, visual baselines, local repro commands, or
  any E2E code changes.
- Read `.github/instructions/github-workflows.instructions.md` before changing
  workflow behavior or relying on workflow artifact names, runner parity,
  permissions, or CI step ordering.
- When classifying a failing run, use the `browser-e2e`
  `references/flakiness-triage.md` verdict vocabulary as the shared taxonomy:
  `Regression`, `Test bug`, `Environmental flake`, `Infra outage`, or
  `Snapshot drift`. VR-specific labels such as content drift, baseline drift,
  frontend layout regression, and test instability are evidence notes or owner
  hints, not replacement verdicts.

## Worktree Safety

Do not reproduce failures, run Playwright, refresh baselines, or write VR
images from `local-dev-reference`. Create or reuse a dedicated worktree branch
cut from `origin/main` under `tmp/worktrees/<slug>` for all VR and E2E commands.
Use `local-dev-reference` only to read the latest instructions, skills, rules,
and `.env` / `.env.local` values; copy or recreate needed env values inside the
E2E worktree before running commands.

## Default Workflow

1. If the CI run produced a `staging-vr-failure-scout` artifact, download and
   read these files first:

   - `agent-brief.md`
   - `agent-context.json`
   - `summary.json`
   - `release-summary.md` when present

   Treat them as the starting point for local analysis. The CI-generated
   preliminary decision is advisory, not final, until image evidence is
   inspected.

   If a user-provided run URL turns out to be a helper/analyzer workflow
   rather than the failed VR workflow itself, trust the scout artifact to name
   the target failed run and switch all later job, artifact, and log reads to
   that target run instead of continuing to inspect the wrapper run.

   Prefer `release-summary.md` for reviewer-facing synthesis when it exists,
   then fall back to `summary.md` and raw JSON. It is the best home for durable
   fields like target failed run URL, recommended owner, expected changed-file
   scope, and ready-to-share release notes.

2. Start with the smallest raw artifacts:

   - `vr-test-results-json-standard`
   - `vr-diagnostics-standard`
   - `auth-events-standard`
   - jobs and artifact metadata from the GitHub Actions run

3. Parse Playwright JSON before downloading large artifacts. Extract:

   - failed test title and project
   - snapshot filename
   - expected, actual, diff, screenshot, and trace attachment paths
   - pixel or dimension delta
   - retry number used for the final failure

4. Download the HTML report only when image files are not already available or
   the report UI is needed to inspect context. The standard report can be
   hundreds of megabytes, so do not make it the default path.
5. If the HTML report download is too slow or unavailable, reproduce one or two
   representative public failures locally with the same Playwright command and
   environment to generate actual/diff PNGs.
6. Prepare compact visual evidence for the vision-language model:
   - full-page thumbnail contact sheet
   - top diff bands by row-level pixel difference
   - expected/actual/diff crops side by side
   - enough surrounding vertical context to identify the changed component or
     content block
7. Ask the vision-language model for a human-readable cause summary. Require it
   to describe visible differences first, then infer cause only after checking
   repo and artifact evidence.
8. Correlate with code and content evidence:
   - inspect VR CSV rows under `e2e/pd/tests/e2e/data/`
   - verify checked-in baselines under
     `e2e/pd/tests/e2e/__screenshots__/`
   - compare the failed run `head_sha` with current `origin/main`
   - search app/frontend changes only for commits between the failed SHA and
     target branch
   - compare the files you actually changed with the scout artifact's expected
     changed-file scope before claiming the fix is complete; a baseline-only
     drift fix should usually stay within committed screenshot PNGs and avoid
     opportunistic test or workflow edits
   - treat Sanity/content changes as likely when actual screenshots show
     different tutorial, quiz, pathway, or course body content but no matching
     frontend code or staging baseline change exists
9. Produce a release-facing verdict:
   - blocker level based on workflow/test labels when available
   - affected snapshots and page paths
   - likely owner: QA/content for content or baseline drift, engineering for
     frontend/layout regressions, E2E owner for test instability
   - confidence and `Pending Verification` items

## GitHub Artifact Commands

Use authenticated GitHub access. In local example-app checkouts, prefer the
repo helper when available:

```bash
scripts/dev/gh-auth-session.sh gh run list \
  --repo example-org/example-app \
  --workflow e2e-visual-regression-test-stg.yml \
  --status completed \
  --limit 30

scripts/dev/gh-auth-session.sh gh api \
  repos/example-org/example-app/actions/runs/<run-id>/artifacts \
  > tmp/gha-vr-<run-id>/artifacts.json

scripts/dev/gh-auth-session.sh gh run download <run-id> \
  --repo example-org/example-app \
  --name staging-vr-failure-scout \
  --dir tmp/gha-vr-<run-id>/staging-vr-failure-scout
```

After reading the scout artifact, download `vr-html-report-standard` only when
JSON triage and local repro cannot provide image evidence. If the artifact is
too slow to download, run a targeted local public repro instead.

If the GitHub Actions URL came from a scout/helper run, preserve both IDs in
your notes: the wrapper run for analyzer provenance and the target failed run
for all fix, log, and artifact evidence. Do not blur them together in the
final report.

## Local Public Repro

For public staging pages, reproduce a single failing snapshot without auth:

```bash
BASE_URL=https://app.staging.example.com ENV=stg \
npx playwright test tests/e2e/visual-regression.spec.ts \
  --config=visual-regression.config.ts \
  --project=chromium \
  --grep "<test title>" \
  --workers=1 \
  --reporter=line
```

Use auth repro only when valid test credentials and storage-state setup are
available. Never print credentials or `.auth/` contents.

For any baseline you expect to commit, reproduce or refresh on the Linux Docker
snapshot surface before trusting a host-rendered PNG. Host repro is fine for
fast diagnosis; committed baselines need the same render family as CI.

## Snapshot Container Pathing

- For public-only compare or refresh loops, keep `E2E_PROJECT_ROOT` on the
  temp run root such as `/tmp/e2e-playwright`. That keeps `.auth`,
  `test-results`, and exported artifacts out of the bind-mounted workspace.
- For authenticated Docker runs that intentionally reuse a worktree's existing
  `.auth/run-*`, `E2E_PROJECT_ROOT=/app` is valid, but the snapshot entrypoint
  will then export from the whole bind-mounted workspace by default. Override
  `SNAPSHOT_EXPORT_DIR` to a dedicated `/tmp/<name>` path or another isolated
  export directory so the success-artifact mirror does not obscure what changed
  in the tracked baselines.

## Image Analysis Rules

- Compare expected, actual, and diff images together. A diff image alone can
  exaggerate harmless antialiasing or hide the semantic UI change.
- For very tall screenshots, create contact sheets and row-diff crops. Do not
  send full 20k-plus-pixel pages to a vision model as the only evidence.
- Prefer representative failures over every failed snapshot when many failures
  share the same page family or content source.
- Classify likely causes conservatively:
  - changed lesson text, video blocks, screenshots, steps, or completion cards:
    likely Sanity/content drift or baseline refresh need
  - shifted header, navigation, footer, global spacing, or reusable component
    styling across unrelated pages: likely frontend regression
  - one or two pixel height-only deltas with otherwise identical content:
    likely baseline or rendering drift
  - changing dimensions between retries, missing network resources, or
    diagnostics errors: possible test/environment instability

## Vision Prompt Shape

Give the model the artifact summary plus image crops. Use a prompt like:

```text
You are triaging a example-app visual-regression failure.
Describe visible differences between expected, actual, and diff images.
Then infer the most likely cause: content drift, frontend regression,
baseline drift, or test/environment instability.
Separate observed facts from inference. Include confidence and owner.
Do not recommend refreshing baselines unless the visible actual UI is valid.
```

## Output Template

```text
Verdict: <Regression | Test bug | Environmental flake | Infra outage | Snapshot drift>
VR evidence notes: <content drift | frontend regression | baseline drift | test instability | inconclusive>
Priority: <P0-P4, based on release/test labels when available>
Confidence: <high | medium | low>
Affected run: <run URL>
Failed snapshots: <count and representative list>
Visible change:
- <what changed in the UI>
Evidence:
- <artifact, image, repo, or command evidence>
Likely owner: <QA/content | engineering | E2E>
Recommended action:
- <next action>
Pending Verification:
- <only unresolved consequential gaps>
```

## Closeout

Report commands run, artifacts inspected, visual evidence generated, whether a
vision model was used, and remaining `Pending Verification`.
