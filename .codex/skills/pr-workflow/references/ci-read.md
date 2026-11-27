<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-31 (workflow-run CI read boundary) -->

# PR CI Read Reference

## Purpose

Use this skill for read-only CI triage on example-app PRs.

This is the read path counterpart to the heavier `references/ci-worktree.md`
workflow. It should answer the current CI state before any local reproduction,
worktree setup, or code change.

## When To Use

Apply this skill when the user asks:

- is this PR failing
- what checks ran
- what is the current CI state
- smoke-test GitHub Checks access on a PR
- inspect PR checks without fixing them yet

## Baseline Batch

For a specific PR URL or number, read these surfaces together:

1. PR metadata, current head branch, and current head SHA.
2. Workflow runs for the PR head branch, filtered to the current head SHA by
   run details.
3. Commit status contexts for that head SHA, when visible without delaying the
   primary workflow-run path.

For example-app GitHub Actions CI, use the `github-workflow` auth lane
as the primary path:

```bash
<github-workflow-helper> gh pr view <pr-number> \
  --repo example-org/example-app \
  --json headRefName,headRefOid

<github-workflow-helper> gh run list \
  --repo example-org/example-app \
  --branch <head-branch> \
  --limit 10

<github-workflow-helper> gh api \
  repos/example-org/example-app/actions/runs/<run-id> \
  --jq '{id,name,status,conclusion,head_sha,html_url}'
```

Only cite runs whose `head_sha` exactly matches the PR `headRefOid`.

Terraform Cloud and SAST/security provider checks can be base-gated in this
repo. Some of those checks run only when the PR base is `main`; stacked child
PRs that target a parent branch may not run them until the parent merges and
GitHub retargets the child PR to `main`. When a base changes to `main`, re-read
the current head's CI from scratch and treat newly-created Terraform/SAST
checks as current required evidence.

Never call `gh pr checks` or request GraphQL `statusCheckRollup` for
example-app GitHub Actions CI, including through a `gh pr view --json` field
list. They are known token-restricted surfaces, not primary, secondary, or
fallback reads. Use the workflow-run path. REST check-run reads are optional
secondary evidence only when workflow runs lack required evidence, and a
permission failure closes that path.

If the authenticated tool surface is unavailable, auth-limited, or missing a
required field, use `github-workflow` auth lane instead of scraping GitHub HTML.

Provider-detail limitation: GitHub APIs, GitHub MCP, the GitHub connector, and
the user's GitHub token do not authenticate into Terraform Cloud or SAST
provider UIs that require Okta. If a Terraform/SAST status is visible in GitHub
but the details URL cannot be opened or logs cannot be read, report provider
details as `Pending Verification` and ask the user for copied logs,
screenshots, or exported artifacts.

## Interpretation Rules

- Report live state only. Do not trust stale user descriptions of failing CI.
- For failures, extract the smallest useful error signature: workflow name, job
  name, failing step, primary error text, file path or test name when present,
  timeout/resource signal, dependency or tool version, and run URL.
- Classify the failure before suggesting a fix: product code, test expectation,
  workflow configuration, dependency/install, runner or resource, flaky timing,
  external service, permission/auth, or unknown.
- Search current PR comments or recent known issues only when the signature
  looks recurring; do not open or update issues from this read-only lane.
- Commit statuses are useful but are not the full Checks API.
- Check runs are the best source for named jobs such as GitHub Actions lanes
  and third-party checks.
- For stacked PRs after a rebase or force-push, only the latest run for the
  newest head SHA counts; older successful runs on the same branch are stale.
- Note that `gh run list` is not head-pinned. Check each run via details (such
  as `actions/runs/<run-id>` with `gh api` or helper) to confirm that its
  `head_sha` matches the target head SHA before citing it as evidence.
- If status reads work but check-run reads fail with a permission error, the
  likely root cause is token/tool permissions, not missing repo access.
- If `gh run watch` reports `requesting annotations returned 403 Forbidden`,
  treat that as an annotations permission gap. The watcher can still prove job
  and step success or failure.
- If all current checks are green, say so plainly.
- If Terraform/SAST checks are absent on a stacked non-`main` base, do not call
  the PR fully CI-covered. Say those provider checks are pending until the PR
  targets `main` or until the user supplies provider evidence.

## What Not To Do

- Do not create a worktree.
- Do not inspect local diffs.
- Do not propose a fix until a concrete failing lane exists.
- Do not infer job names from commit statuses alone when check runs or workflow
  runs are available.
- Do not use rendered GitHub HTML as the source of truth.

## Read-Only Stop Condition

If the head-pinned workflow runs all show success for the current head SHA, say
so plainly and stop. If failures exist, use the failing name, conclusion, URL,
and details URL fields as the minimal triage surface before moving into
`references/ci-worktree.md`.

## Failure Triage Output

```text
CI read:
- head: <sha>
- failing workflow/job: <name or none>
- signature: <step/error/test/file>
- category: <product | test | workflow | dependency | runner | flake | external | permission | unknown>
- next route: <ci-worktree | local-ci-checks | browser-e2e | code-authoring | Pending Verification>
```
