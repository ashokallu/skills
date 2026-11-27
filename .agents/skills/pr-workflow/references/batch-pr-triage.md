<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-17 -->

# Batch PR Triage

Use this lane when the user asks to triage, prioritize, risk-sort, or get a
first pass over multiple pull requests. The output helps allocate reviewer
attention. It is not a merge approval and does not replace full PR review.

## Boundary

Default to read-only GitHub state. Do not create local worktrees, run
validation, post comments, resolve threads, push, or mutate PR metadata unless
the user explicitly changes the task.

Use authenticated GitHub surfaces through `github-workflow` when
available. If a PR needs full code review, route that single PR to
`references/review-worktree.md` after triage rather than doing an incomplete
review in this lane.

## Inputs

Accept any of these:

- a list of PR URLs or numbers
- a repo query such as open PRs by author, label, milestone, branch, or review
  state
- a queue objective such as "which look low queue risk", "which need human
  review", "which are risky", or "which are blocked"

If the input is broad, cap the batch to the smallest useful set and state the
cap. Prefer current open PRs over stale closed or merged PRs unless the user
asks for history.

## Triage Evidence

For each PR, gather only the evidence needed for queue-level sorting:

- PR number, title, author, base/head, current head SHA, draft state, age, and
  dependency or stack relationship when available
- changed-file count and high-risk path categories, not full source review
- CI/check state pinned to the current head
- review state, unresolved thread count when available, and whether human
  reviewer attention is already requested
- labels, linked issue/Jira key, rollout or migration wording, and PR body
  warnings that change blast radius

Treat missing GitHub fields as `Pending Verification`; do not infer safety from
missing data.

## Risk Buckets

Classify each PR into one of these buckets:

- **Low queue risk**: small, contained, current-head checks green or clearly
  non-required, no auth/data/migration/infra/generated/public API surface, and
  no unresolved human concern found.
- **Needs focused review**: moderate behavior change, tests/docs/workflow
  surface, unclear validation, stale PR body, or ordinary unresolved comments.
- **High-risk review first**: auth, permissions, tenant/user data, production
  mutation, migration, infra/deploy, generated contracts, public API, broad AI
  refactor, large diff, flaky or failing required checks, contested findings, or
  unresolved human blocker.
- **Blocked before review**: missing current-head metadata, draft/not ready,
  stale base or stack dependency, required checks failing without logs, branch
  inaccessible, or GitHub data unavailable enough that queue risk cannot be
  judged.

## Output Shape

Report:

- sorted queue with bucket, one-line reason, and next route for each PR
- highest-risk surfaces that deserve human or full reviewer attention
- stale or missing evidence under `Pending Verification`
- recommended next action: full review, comment read, CI lane, rebase/update,
  owner question, or defer

Do not say "safe to merge" unless a full review and required merge gates were
actually completed. Say "low queue risk" for triage-only results.
