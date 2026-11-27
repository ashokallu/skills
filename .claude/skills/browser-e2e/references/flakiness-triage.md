<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-05-30 -->

# Flakiness Triage

Use this skill when an E2E failure needs classification before anyone starts "fixing flake" blindly.

## Default posture

Read-only by default. Pull CI evidence, inspect traces, grep the repo, and classify the failure. Do not rewrite specs, retry workflows reflexively, or change product code while using this skill.

When a failure looks like a selector mismatch, route drift, missing card, or
unexpected post-action UI state, read the owning monorepo implementation before
calling it flake. Treat `app/`, requester code, and nearby shared state modules
as the expected-behavior source of truth.

## High-signal instruction files

Before interpreting E2E failures, load these repo instruction files:

- `.github/instructions/e2e-playwright-tests.instructions.md` for fixture,
  import, page-object, auth, visual-regression, and test-convention guidance.
- `.github/instructions/github-workflows.instructions.md` for active workflow
  inventory, worker counts, package scripts, and legacy workflow boundaries.

Treat them as current routing guides, then verify exact scripts and workflow
lines in source before running commands.

## When to use

- A GitHub Actions E2E run is red or flaky
- A local `e2e/pd` spec fails and the user asks for classification before a fix
- A test passes on retry and someone is calling it flake without evidence

## When not to use

- Rewriting the spec itself
- Updating locators, assertions, snapshots, or product code after triage
- Any request whose primary action is "fix", "update", "rewrite", "change",
  or "commit" an E2E test/spec/selector
- Committing a test fix
- Fixing the underlying product bug
- Bringing local E2E infrastructure up from scratch

Use `references/playwright-cli-overlay.md` and `connect-backend-services` for the setup path.

## Repo-specific facts

- The E2E suite lives at `e2e/pd/`
- Main config is `e2e/pd/playwright.config.ts`
- Auth-specific flows also depend on `connect-backend`
- Shared fixtures and page objects can break many specs at once
- CI workflow definitions live under `.github/workflows/e2e-*.yml`

## Active E2E workflow lookup

When the user asks to check or fix an environment-level E2E surface such as
"Staging E2E", "Production E2E", or "hourly E2E", inspect the latest runs for
the active workflow set before choosing a failing job to triage.

Staging active workflows:

- `.github/workflows/e2e-smoke-stg.yml`
- `.github/workflows/e2e-connect-backend-regression-stg.yml`
- `.github/workflows/e2e-visual-regression-test-stg.yml`

Production active workflows:

- `.github/workflows/e2e-connect-backend-smoke-prod.yml`
- `.github/workflows/e2e-connect-backend-regression-prod.yml`
- `.github/workflows/e2e-visual-regression-test-prod.yml`

Hourly E2E workflow:

- `.github/workflows/e2e-hourly-smoke-prod.yml`

Use the file names with `gh run list` so similarly named historical workflows
do not contaminate the result:

```bash
for workflow in \
  e2e-smoke-stg.yml \
  e2e-connect-backend-regression-stg.yml \
  e2e-visual-regression-test-stg.yml
do
  GH_PAGER=cat PAGER=cat LESS=FRX \
  scripts/dev/gh-auth-session.sh gh run list \
    --repo example-org/example-app \
    --workflow "$workflow" \
    --limit 3
done
```

Swap the workflow list for production or hourly when that is the requested
scope. If any latest run is not `success`, inspect that run's jobs and
artifacts before starting a local reproduction. If all latest runs are green,
say so and look for retry-healed failures in JSON artifacts only when the user
asks for deeper health verification.

## Triage sequence

1. Establish blast radius:

    ```bash
    gh run list --repo example-org/example-app --limit 10 --workflow e2e
    gh run view <run-id> --repo example-org/example-app --log-failed | tail -200
    ```

    If the user shares a job URL, parse `/actions/runs/<run-id>/job/<job-id>`
    and inspect job metadata first so you know the failed step name and which
    downstream steps were skipped:

    ```bash
    GH_PAGER=cat PAGER=cat LESS=FRX \
    scripts/dev/gh-auth-session.sh gh api \
       repos/example-org/example-app/actions/runs/<run-id>/jobs \
       > tmp/gha-run-<run-id>-jobs.json

    GH_PAGER=cat PAGER=cat LESS=FRX \
    scripts/dev/gh-auth-session.sh gh run view <run-id> \
       --repo example-org/example-app \
       --job <job-id> \
       --log-failed \
       > tmp/gha-job-<job-id>.log
    ```

2. Download and inspect the smallest Playwright JSON result artifact first,
   then the HTML report or trace artifact if you still need richer context.
   A green workflow can still contain retry-only passes, so inspect `status`,
   `expectedStatus`, `retry`, and failed/error entries in the JSON result before
   calling the run healthy.

    For `.github/workflows/e2e-smoke-stg.yml`, start with
    `smoke-test-results-json`; it contains exact spec titles and assertion
    failures for the public smoke step. If `smoke-auth-test-results-json` only
    contains a `cliArgs.note` plus `suites: []`, that file is the workflow's
    placeholder output and should not be treated as real auth-step evidence.

    Do not open `playwright show-report`, browser-hosted HTML reports, or other
    interactive report viewers during unattended triage unless lower-friction
    artifacts cannot answer the question. Prefer saved JSON, `error-context.md`,
    traces, and screenshots first.

3. For any local staging reproduction, first check whether Learn Staging is
   reachable from the same execution surface that will run the tests:

    ```bash
    curl -I --max-time 20 https://app.staging.example.com/
    ```

    In Codex or any sandboxed agent runtime, a sandboxed DNS or network failure
    is inconclusive. Retry the probe from the non-sandbox/escalated shell, use
    browser tools to open `https://app.staging.example.com/`, or ask the user
    for the terminal result if escalation is unavailable. For Docker snapshot
    or Docker Playwright runs, also verify the container can reach staging
    before refreshing baselines:

    ```bash
    docker compose -f docker-compose.snapshots.yml run --rm --entrypoint node playwright-snapshots -e "fetch('https://app.staging.example.com/').then(r=>console.log(r.status, r.url)).catch(e=>{console.error(e); process.exit(1)})"
    ```

    Hard-stop only when the execution surface that will run validation cannot
    reach staging: the non-sandbox host probe for host-side runs, or the Docker
    probe for Docker-based runs. If Chrome/browser or the user's terminal can
    reach staging but the agent sandbox cannot, report a sandbox limitation and
    keep using the reachable surface. If browser reaches staging but host shell
    or Docker does not, report a local routing split for that surface, not Learn
    Staging downtime.

4. Match the failure against known signatures
5. Optionally reproduce locally with `--repeat-each=10 --workers=1`
6. Cross-reference recent commits touching the failing spec, page object, fixture, auth path, or product surface
7. Read the owning product code when the failure might be a stale test
   assumption rather than a real regression:

   - page object or selector mismatch -> owning page/component in `app/`
   - navigation or route expectation -> page/router/requester source
   - auth or submission state -> auth helper, requester, or form state source

   Use the product implementation to decide whether the defect is in the spec,
   the page object, or the app.
8. Produce one verdict per failing spec

## Failure-family playbooks

### Smoke workflows

Smoke workflows run public smoke first, then auth smoke, then authenticated
Coveo smoke. Triage them in that order and do not let a later placeholder JSON
artifact hide an earlier failed step.

For authenticated Coveo smoke:

- Start with the failed step log when JSON artifacts are absent or incomplete.
- Distinguish retry-healed tests from final failures. A title that fails first
  and passes on retry is residual flake; the final non-retry failure is the
  blocker.
- If `submitHeaderSearchFromHome()` times out before reaching `/search`, inspect
  screenshot/trace for homepage modal, banner, or header-search readiness before
  changing Coveo assertions.
- If a visible `Load more` button cannot be clicked because a result-card image
  or grid subtree intercepts pointer events, treat it as a layout interaction
  regression unless trace evidence proves the test scrolled to an impossible
  position. Do not fix this by using `{ force: true }`; reproduce with a real
  browser click path or adjust product layout/hit targets.
- If filters, sort, or result-card assertions fail only under `429`/`5xx`
  responses from search/link probes, classify as environment or infra flake and
  add bounded retries only around retryable network probes, not around user
  assertions.

### Regression workflows

Regression workflows have multiple lanes in one job: localization/public
regression, auth bootstrap, auth regression, search-sorting auth, my-learning
auth, and unpublished-content regression. Identify the first failed lane from
job steps, then download that lane's raw JSON artifact. A skipped workflow-run
regression job after a manual release is not a failing E2E test.

For auth regression, keep worker counts conservative. Shared learner progress
mutation means parallel failures are often test isolation issues until proven
otherwise.

### Visual-regression workflows

Visual-regression workflows have `standard` and `optional` matrix legs. The
optional leg is allowed to continue on error; the standard leg is the release
blocker unless the user explicitly asks about optional drift.

Always download `vr-test-results-json-standard` first. Parse failing titles,
projects, snapshot filenames, and dimensions before deciding whether this is
snapshot drift or an app regression.

Classify common VR shapes this way:

- Small stable height-only deltas across the same public/auth page family, such
  as desktop pages moving by a few pixels or mobile pages by tens of pixels,
  are snapshot drift until diff images prove a product defect.
- Broad production homepage/pathway/tutorial/quiz drift with large pixel ratios
  can still be snapshot drift after a real content/layout change, but inspect
  the HTML report or diff images before refreshing baselines.
- A missing snapshot is not the same as a visual mismatch. Confirm the baseline
  exists under the correct `stg/` or `prod/` directory before regenerating.
- Auth and public baselines are separate when the authenticated experience
  diverges. Do not reuse one `imageFilename` for both public and auth rows.

For a baseline refresh, use the Docker snapshot container from `e2e/pd`, not a
host-side Playwright run, and run it from a dedicated `origin/main`-based
worktree instead of `local-dev-reference`. Use `local-dev-reference` only as the
source for instructions, skills, rules, and env values copied into that E2E
worktree. After `UPDATE_SNAPSHOTS=true`, inspect `git diff` and restore
unrelated regenerated PNGs before committing. Finish with the same Docker
compare command using `UPDATE_SNAPSHOTS=false`.

## Known signatures

| Signature                                                                                                                                         | Likely verdict                                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Timeout on fragile copy-based selector                                                                                                            | Test bug                                                                                  |
| `expect(page).toHaveURL` immediately after navigation                                                                                             | Test bug                                                                                  |
| `ECONNREFUSED` or backend fetch failure                                                                                                           | Infra outage or environment issue                                                         |
| Sandboxed `curl -I --max-time 20 https://app.staging.example.com/` cannot resolve or connect, but non-sandbox shell/browser/manual terminal works | Inconclusive sandbox network limitation; use the reachable execution surface              |
| Non-sandbox host probe or Docker container probe cannot reach staging before a local staging run                                                  | Blocked for that execution surface: local VPN/routing/DNS issue or Learn Staging downtime |
| `401` after successful login                                                                                                                      | Auth race                                                                                 |
| `Target page, context or browser has been closed`                                                                                                 | Test bug                                                                                  |
| Intermittent TLS trust failure on local env                                                                                                       | Environment issue                                                                         |
| Tiny screenshot diff with no product behavior change                                                                                              | Snapshot drift                                                                            |
| Stale Sanity content                                                                                                                              | Cache invalidation issue; use Sanity lane                                                 |
| Search/results page loads but the asserted control role or heading copy drifted (`searchbox` vs labeled `combobox`, exact heading text changed)   | Test bug                                                                                  |
| CMS-driven section renders cards but omits optional CTAs such as download buttons                                                                 | Test bug                                                                                  |
| `EACCES` under `e2e/pd/test-results`, `.auth`, or report directories after Docker-based runs                                                      | Environmental flake                                                                       |
| `browserType.launch: Executable doesn't exist` before test logic runs                                                                             | Environmental flake                                                                       |
| Stable visual geometry drift across many cases when baselines were refreshed from host instead of Docker/CI surface                               | Snapshot drift                                                                            |
| Generic completion text such as `/complete/i` matches progress copy, action copy, or unrelated CTAs                                               | Test bug                                                                                  |
| Pathway/course completion code clicks `Mark step as incomplete` while trying to progress                                                          | Test bug                                                                                  |
| Sidebar or page chrome text such as `the organization Version:` is used as proof of pathway/mission progress                                                 | Test bug                                                                                  |
| Optional modal or chooser probes burn the full expect timeout inside repeat loops while the optional state is usually absent                      | Test bug                                                                                  |
| A workflow finishes green but Playwright JSON contains `flaky` tests or retry-healed failures                                                     | Flaky until classified from final attempt evidence                                        |
| Missing Firefox visual baselines while the active workflow runs only Chromium visual projects                                                     | Not an active CI blocker unless Firefox is enabled                                        |
| Staging and production reruns share a reused `.auth` run or stale `E2E_PROJECT_ROOT` from another checkout                                        | Environmental flake                                                                       |
| Auth visual-regression runs use ephemeral users or mismatched static credential env vars                                                          | Environmental flake                                                                       |
| A staging auth VR title times out in `page.goto()` once, then passes on retry after the refreshed Docker compare ends `status: passed`            | Environmental flake                                                                       |
| Coveo `Load more` is visible but a result-card image/grid subtree intercepts pointer events                                                       | Layout regression unless trace proves an impossible test scroll position                  |
| VR failures are stable height-only deltas across the same page family                                                                             | Snapshot drift until diff images prove a product defect                                   |
| VR optional matrix leg fails while the standard leg passes                                                                                        | Non-blocking optional drift unless the user asks to fix optional baselines                |

## E2E selector and completion triage notes

- Treat copy-only selectors as suspicious when the same words appear in
  sidebars, progress text, CTAs, or toggles. In traces, confirm the matched
  locator is the intended control before calling it an app regression.
- For course, mission, and pathway completion, terminal proof should be a
  terminal-only signal: completion dialog, rating prompt, next-item or summary
  CTA, explicit "mark all complete" variant, or a completed-step toggle used
  only as read-only evidence. A visible `Mark step as incomplete` means the
  current step is already completed; do not recommend clicking it.
- `the organization Version:` and other sidebar/chrome labels do not prove that a version
  chooser, mission step, or pathway progress state is active. Require
  chooser-scoped copy, a chooser-scoped Continue CTA, a content step marker
  such as `Step x of y`, `Get Started`, or `Mark step as complete`.
- If an optional overlay, version chooser, or dashboard tile is absent in most
  iterations, classify long `expect.poll` or full-timeout `isVisible()` probes
  inside loops as test bugs. Optional probes should be short; longer waits
  belong immediately after the navigation or click that can reveal the state.
- Before treating a declared `package.json` script as CI-supported, inspect the
  actual active workflow. Firefox visual-regression scripts exist, but the
  documented staging/production VR workflows run Chromium only.
- When switching a local worktree between staging and production triage, clear
  or isolate `.auth/`, `test-results/`, and run metadata first. For production
  parity, avoid sourcing a staging `.env.local`; use `.env` plus explicit prod
  tuple overrides.

## Verdicts

Choose exactly one per failing spec:

- `Regression`
- `Test bug`
- `Environmental flake`
- `Infra outage`
- `Snapshot drift`

## Findings format

```text
## E2E Triage: <PR / run URL>
**Date:** YYYY-MM-DD
**Run:** <run id>
**Scope:** <specs reviewed>

### Per-spec verdicts

#### <spec path>::<test name>
- **Verdict:** Regression | Test bug | Environmental flake | Infra outage | Snapshot drift
- **Confidence:** Low | Medium | High
- **Evidence:** Trace line, console log, network entry, or repo diff
- **Reproducibility:** N/M local runs failed
- **Recommended action:** Concrete next step + owner

### Systemic observations
- <cross-spec patterns>

### Out of Scope
- <anything skipped>
```

## Non-goals

- Do not hide regressions with blanket retries
- Do not suggest `test.skip` as a first-line response
- Do not modify snapshots or specs during classification

If the user explicitly asks you to continue from classification into a fix,
handoff to the `work-orchestration` diagnose lane (or the implementation
skill) after you record the verdicts and evidence.

## References

- `e2e/pd/playwright.config.ts`
- `e2e/pd/global.setup.ts`
- `e2e/pd/global.teardown.ts`
- `.github/instructions/e2e-playwright-tests.instructions.md`
- `.github/instructions/github-workflows.instructions.md`
- `.github/workflows/e2e-*.yml`
- `.claude/skills/code-authoring/references/sanity-schema.md`
- `.claude/rules/e2e/playwright.md`
