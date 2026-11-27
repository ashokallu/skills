<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (advice versus execution boundary) -->

# Release Terraform Plan Analysis

```text
Type: owning lane
Use when: the user asks whether a release and Terraform plan are aligned or safe to
          sequence
Skip when: only execution of apply, approval, unlock, cancellation, discard,
           deployment, or rollback is requested, with no read-only analysis or advice
Owns: read-only comparison of release intent, live runtime, Terraform source/state, and
      a complete plan before human apply
Does not own: Terraform/apply/deploy mutation or post-deploy behavior validation
Allowed side effects: read-only UI/artifact/source/cloud inspection
Inputs: workspace/run/plan, expected commit/release, environment, and review question
Exit states: summary-only, proceed, refresh plan, do not apply, blocked
Outputs: evidence-backed release/plan recommendation and post-action proof requirements
Re-enter when: plan/run/config version, live state, commit, or scope changes
```

Use this lane when the user asks whether to deploy a Learn release and apply a
Terraform plan, or asks to analyze, summarize, validate, or advise on a
Terraform plan in relation to a release.

This lane is pre-apply advisory. It does not apply Terraform, mutate Cloud Run,
or replace post-deploy validation. It decides whether the release and Terraform
sequence is coherent enough to proceed.

Before reading Terraform Cloud, GitHub, or cloud runtime state, establish the
exact environment/workspace, project/account, principal, run/resource IDs,
pagination/scope, and read-only boundary through `external-system-boundaries`.
Apply `privacy-and-secrets-boundary` to state, plan, env, and secret-derived
evidence; summarize sensitive values instead of reproducing them.

Assume the user is asking for analysis only. The expected operator model is
that the user has authenticated Terraform Cloud UI access but not an
authenticated Terraform CLI path. Do not suggest Terraform CLI apply, plan,
state, run, cancel, discard, unlock, variable, or workspace mutation commands
from this lane. Use the Terraform Cloud UI/page source, a user-provided state
file, and read-only cloud/source evidence.

Terraform apply is manual in Test/Integration, Staging, and Production. A
merge, GitHub release, Manual Release run, Manual Deploy run, Terraform Cloud
plan, or successful plan check does not apply infrastructure. The expected
order is:

1. deploy through Manual Release, which creates a release tag, or Manual
   Deploy, the no-tag escape hatch for pre-PR testing or urgent hotfixes
2. create a fresh Terraform plan after deployment so refresh reads the new live
   GCP state
3. inspect the plan against the release, source, state, and live resources
4. apply only through an explicit human action

Never describe plan creation as auto-apply, apply authorization, or proof that
runtime config changed. If deployment changes after plan creation, invalidate
the plan and require a new one.

## Scope

Use this lane for Test/Integration, Staging, and Production when the question
connects any of these:

- a GitHub release tag or pending release
- a Terraform plan log, Terraform state file, or Terraform Cloud run
- Cloud Run service or job runtime configuration
- feature flags, env vars, secrets, images, revisions, traffic, or labels
- "should I deploy first or apply TF first?" decisions
- "what if the release happens but TF is not applied?" fallback checks

Do not use this lane for:

- ordinary post-deploy smoke or regression testing after the sequence is
  complete, use `release-regression-validation`
- code authoring or Terraform edits, use `code-authoring`
- static PR review verdicts, use `pr-workflow` or `reviewer`
- Terraform apply execution, which requires explicit user approval and the
  owning operational runbook
- Terraform CLI operations that require authenticated Terraform Cloud access;
  this lane uses UI/page-source inspection or provided artifacts instead

## Required Inputs

First classify the requested claim:

- **Descriptive summary:** explain what a complete plan proposes, without
  claiming release alignment, apply safety, or sequencing readiness.
- **Alignment/sequencing/safety advice:** compare the plan with release intent,
  current state, source, fallback behavior, and post-action proof.
- **Partial text-log summary:** summarize only what an incomplete log visibly
  contains and label omitted attribute-level evidence.

For alignment, sequencing, or safety advice, gather each item below:

1. Target environment: Test/Integration, Staging, or Production.
2. Target release tag, if one is planned.
3. Terraform Cloud run URL for the same environment, or a full JSON plan
   artifact exported from that run.
4. Terraform state file for the same environment.
5. Current live Cloud Run services/jobs that the release or plan can touch.
6. Current live commit labels, image digests/tags, latest ready revisions, and
   traffic for those services/jobs.
7. Current `origin/main` commit and the release tag commit.
8. GitHub release notes and commit/file diff from the currently live commit to
   the target release commit.
9. Current source desired config from `origin/main`, including module callers
   and shared module files.
10. Runtime code defaults for any new or changed env var or flag.

The Terraform Cloud run URL or a full JSON plan artifact is mandatory for a
**complete plan summary** and for any alignment/sequencing/safety verdict. The
state file and live/source/release evidence are additionally mandatory for an
alignment/sequencing/safety verdict. Missing state or baseline evidence does
not block a purely descriptive complete-plan summary, but that output must say
`SUMMARY ONLY` and must not recommend apply order or safety.

When the user asks for validation, risk, release sequencing, apply advice, or
another safety-dependent operation without the full plan evidence, return
`BLOCKED` for that verdict and ask for the missing run URL or artifact. Do not
suggest apply or substitute memory, source-only inspection, live GCP reads, or
a plan action-count summary for the missing attribute-level plan.

If the user provides only a text plan log and it lacks attribute-level diffs,
say so. You may return a `PARTIAL SUMMARY` of visible resource names, actions,
and obvious blockers, but alignment/safety/apply advice remains `BLOCKED` until
the Terraform Cloud run UI is inspected or the JSON/full plan artifact is
provided. The user may accept the text log as sufficient for a limited summary;
that acceptance does not convert it into complete plan evidence.

If a Terraform Cloud run URL is provided but the browser cannot access it,
return `BLOCKED` for complete-plan or apply advice and name the auth/access blocker. Ask for an
authenticated browser session, screenshots that show every changed resource
diff, or the full JSON plan artifact. Do not pivot to authenticated Terraform
CLI commands unless a separate operational workflow explicitly provides that
path. Do not continue the workflow as a guessing exercise from the incomplete
raw log.

When the run must be inspected through an authenticated browser, route the
browser interaction through `browser-e2e` and use the least-sensitive
available evidence path, in this order:

1. Attach to an already authenticated, CDP-enabled session dedicated to the
   task.
2. Start a fresh temporary browser profile and let the user authenticate to it
   interactively.
3. Ask for the full JSON plan artifact or screenshots that cover every changed
   resource and attribute-level diff.

Do not copy or clone the user's normal browser profile, cookie database, local
storage, session storage, or other credential-bearing browser data as a generic
fallback. A security-approved runbook may authorize a narrower credential
transport procedure, but only after the privacy boundary approves the exact
source, destination, retention, permissions, and cleanup steps and the user
explicitly authorizes that transport. Without that authorization, return
`BLOCKED` rather than weakening the credential boundary.

Never take any action that changes Terraform Cloud, Terraform state, workspace
configuration, run status, policy state, variables, comments, locks, applies,
discards, cancels, or run confirmation. This lane is read-only advisory only;
even an explicit user request to mutate Terraform must leave this lane and
enter the owning operational runbook with fresh approval and rollback evidence.

## Terraform Cloud UI Extraction Checklist

When a Terraform Cloud run URL is the full-plan evidence source, do not stop at
the run header, action counts, raw text snippets, or the first visible body
text. The rendered UI is authoritative only after the changed-resource tree has
been opened and inspected.

Use this checklist before answering:

1. Confirm the run URL, workspace, status, plan timing, action summary, policy
   summary, and pending/apply state from the rendered page.
2. Enumerate every visible changed resource address from the rendered resource
   list, including create, update, delete, replace, and moved-address rows.
3. For every changed resource row:
   - expand the row
   - click all hidden-attribute controls such as
     `<n> unchanged attributes hidden`
   - capture the row-local rendered text, not only whole-page text
   - preserve the resource address beside the extracted evidence
4. For Cloud Run service and job rows, explicitly inspect the expanded
   `template`, `containers`, `env`, `labels`, `image`, `traffic`,
   `service_account`, VPC, timeout, retries, CPU, memory, and client metadata
   surfaces when present.
5. Treat Cloud Run env var arrays as noisy when Terraform shows positional
   delete/create/reorder rows. Derive semantic env transitions by locating the
   final named env blocks and their values or secret references, not by reading
   the first positional `name -> name` row as the actual business change.
6. Produce a per-resource extraction ledger before the final answer:
   - address
   - action type
   - release-intent changes
   - drift-cleanup changes
   - explicit no-op checks for image and traffic when those surfaces appear
   - `Pending Verification` for any collapsed or inaccessible detail
7. Always list false, empty-string, and secret-reference env transitions
   explicitly. These are easy to miss because the UI often presents them as
   row reordering or delete/create blocks.
8. If policy checks show advisory failures but the policy names or details are
   not visible without further navigation, keep plan alignment separate from
   policy acceptance and mark the policy details `Pending Verification`.

If the agent cannot complete this checklist because the browser, page, or UI
does not expose the needed details, the recommendation must stay `BLOCKED` or
`Pending Verification` for the affected claim. Do not fill UI extraction gaps
from memory, source diffs, or an older run.

## Analysis Order

Follow this order. Do not start from the plan summary.

1. **Release inventory**
   - Fetch live Cloud Run commit labels for the current production services or
     jobs before reading the planned release diff.
   - Treat the live commit label as the baseline. Resolve the nearest release
     tag only as explanatory context; do not pretend the live deployment is on
     an exact tag unless the commit exactly matches that tag.
   - Read the target release metadata and resolve the tag SHA.
   - Compare the tag SHA with `origin/main`.
   - Compare the target release SHA with the live Cloud Run commit labels.
   - Read the release notes and changed files between the live commit and
     target release.
   - Identify Terraform source changes in that exact live-commit-to-target-tag
     range before judging plan alignment.

2. **Live runtime inventory**
   - Inspect every Cloud Run service/job the release or Terraform plan can
     touch.
   - Capture image digest or tag, commit label, latest created/ready revision,
     traffic, env var names and non-secret values, timeout, retries, CPU/memory
     when relevant, and service account or VPC settings when the plan touches
     them.
   - Do not print secret payloads.

3. **Terraform source and state inventory**
   - Read `origin/main` for the relevant environment caller and shared module
     files.
   - Read the provided Terraform state for the same resources.
   - If state is not provided, first use an already-authorized read-only state
     source named by current repo/runbook evidence. Otherwise request the exact
     environment state file once and mark analysis blocked on that input:
     - Test/Integration:
       `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-test/states`
     - Staging:
       `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-stg/states`
     - Production:
       `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-prd/states`

4. **Plan-to-release alignment**
   - Inspect the Terraform Cloud run UI or full JSON plan for every changed
     resource, including collapsed Cloud Run env var, label, image, template,
     and moved-resource details.
   - When using Terraform Cloud UI, complete the UI extraction checklist before
     forming the recommendation. The checklist is part of the evidence gate,
     not an optional debugging technique.
   - For each planned create/update/move/delete/replace, explain whether it
     matches the Terraform source changes from the live production commit to
     the target release commit.
   - For Cloud Run updates, compare source desired config, Terraform state,
     live runtime, and planned action for images, env vars, flags, labels,
     revisions, traffic, and secrets.
   - Explicitly list every planned feature flag/env var transition, including
     false or empty-string changes, even when the plan UI represents them as
     delete/create or env-block reordering.
   - Treat plan actions that only remove deployment metadata, labels, client
     fields, or GitHub-managed drift as separate operational drift cleanup; do
     not mix them with release-intent changes.
   - A summary such as `0 to destroy` is never enough to call the plan safe.

5. **Stale-plan gate**
   - If any Cloud Run release, manual deploy, rollback, or traffic change
     happened after the plan was created, invalidate the saved plan.
   - The correct advice is to deploy or rollback first, then create a fresh
     Terraform plan and inspect that fresh plan.
   - Do not recommend applying a pre-release plan after the release.
   - All environments require explicit human apply after plan review. A plan
     becoming available or successful is not evidence that it was applied.

6. **Release-without-Terraform fallback**
   - Check the code defaults for every new env var or feature flag.
   - Classify whether a release without Terraform:
     - starts safely with old runtime config
     - defaults safely but leaves the feature disabled
     - fails closed for the affected mode
     - panics or risks live-user failure
   - Include this answer in the recommendation. Teams can deploy code and miss
     the matching Terraform apply; the code must tolerate that gap or the
     handoff must call it out.

7. **Recommendation**
   - Give an explicit `Proceed`, `Do not apply`, `Refresh plan first`, or
     `BLOCKED`
     recommendation.
   - Separate release recommendation from Terraform recommendation.
   - Name the exact verification that must happen after deploy and after apply.

## Output Shape

Use this compact structure:

```text
Verdict: <SUMMARY ONLY | PARTIAL SUMMARY | Proceed | Refresh plan first |
          Do not apply | BLOCKED>

Current live state:
- <services/jobs, live commit, images, traffic>

Target release:
- <tag, commit, important changes>

Terraform plan:
- <adds/changes/destroys, important planned resources>

Alignment:
- <what matches the release intent>
- <what conflicts or is stale>

Release-without-TF fallback:
- <safe defaults or failure mode>

Recommendation:
- <ordered release/plan/apply sequence>
- <do-not-run boundary>
- <post-deploy/post-apply proof>
No-mutation statement:
Next owner / recheck trigger:
Pending Verification:
```

Keep evidence tied to the claim beside it. If a value is not checked, mark it
`Pending Verification` instead of filling the gap with assumption.

For production release/Terraform Cloud UI verdicts, agents must answer in this
style: concise verdict first, then current production evidence, TFC plan
summary, explicit env/flag changes, non-release drift cleanup, and caveats.
Use the example below as the final-answer shape after the UI extraction
checklist has been completed.

```text
Verdict

The fresh Prod TFC run <run-id> looks aligned with the just-completed
<release-tag> release. I did not take any Terraform-mutating action. I only
inspected the rendered TFC UI/page state and read-only Cloud Run/GitHub
evidence.

Current Prod Evidence

Live Cloud Run services/jobs are already at release commit:

<release-sha> = <release-tag>

Services checked:

- <service-a>: 100% latest revision, image no-op in plan
- <service-b>: 100% latest revision, image no-op in plan
- <service-c>: 100% latest revision, image no-op in plan

Jobs checked by labels:

- <job-a>
- <job-b>
- <job-c>

TFC Plan

Rendered UI shows:

<adds> to add, <changes> to change, <destroys> to destroy

Adds:

- <resource-address-a>
- <resource-address-b>

Changes:

- <resource class summary>
- Images are no-op
- Traffic remains latest-revision target in the rendered diff

Important Env/Flag Changes Found

Yes, these are in the plan:

- <FLAG_NAME>: <service> ends at "<value>"
- <FLAG_NAME>: <service> changes "<old>" -> "<new>"

<Feature area> changes are also present:

- <ENV_NAME>: added from Secret Manager
- <ENV_NAME>: "<value>"
- Secret accessor IAM added for <secret summary>.

Non-Release Drift Cleanup

The plan also removes or normalizes deployment metadata from Cloud Run-managed
resources:

- <label-or-field-a>
- <label-or-field-b>

That matches the known Terraform-vs-deploy drift pattern, not a new app
behavior change. State what operator-visible metadata may disappear or be
rewritten if the plan is applied.

Caveats

List advisory policy failures, inaccessible policy details, missing state
exports, inaccessible collapsed UI details, or any other material evidence gap.
Keep these separate from release/plan alignment.
```
