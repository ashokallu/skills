<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 (added code-authoring phase boundary for CI fixes) -->

# pr-ci-worktree

## Purpose

Use this skill when a task starts from a GitHub PR and needs CI repair work in
an isolated worktree. It owns the CI failure diagnosis and fix path. It does
not own generic PR reading, comment-only review triage, worktree mechanics, or
local PR-gate command selection.

## USE FOR

- investigating failing or allegedly failing CI on a example-app PR
- reading live PR checks before local reproduction
- reproducing a concrete failing Actions lane in a disposable worktree
- keeping dirty local checkouts out of the PR-fix diff
- preparing a scoped CI fix that may later be pushed or transplanted

## DO NOT USE FOR

- read-only PR CI status with no local reproduction; use `references/ci-read.md`
- read-only review comments, requested changes, unresolved threads, or replies
- fixing review feedback without a concrete failing CI lane
- creating or preparing a generic worktree; use `worktree-readiness`
- choosing local PR-gate commands after setup; use `references/local-ci-checks.md`

If the prompt only asks to read review threads, requested changes, unresolved
comments, or replies and does not mention failing CI, check runs, Actions jobs,
or local reproduction, stop and use the runtime's PR comments read or worktree
skill instead.

## Related Skills

- `github-workflow` `references/pr-operations.md`: PR metadata, changed files, comments, and status
  primitives.
- `code-authoring`: code, test, config, generated artifact, migration,
  script, or workflow changes after a CI root cause is understood.
- the runtime's PR comments skill: read-only comment/thread triage or
  review-feedback fixes when no concrete CI lane is involved.
- `worktree-readiness`: repo-local worktree path policy, slug naming,
  branch-local dependencies, Husky setup, push/auth boundaries.
- `references/local-ci-checks.md`: rescan `.github/workflows` and reproduce the
  matching `pull_request` gates from an already prepared worktree.
- external reviewer: required collaborator attempt for non-trivial CI root
  cause, risky fixes, multi-file changes, auth/security concerns, or broad
  validation strategy. Collaborator availability is not a blocker by itself;
  record unavailable review as `Pending Verification`.

## Rules

- Parse owner, repo, and PR number from the URL immediately.
- Treat GitHub as authenticated. Use the runtime's available authenticated
  GitHub tools first; fall back to `github-workflow` `references/gh-auth-session.md` when the tool surface is
  unavailable, auth-limited, or missing a required field.
- Do not use rendered GitHub HTML as the source of truth.
- Do not create a worktree until live GitHub data shows a concrete failing or
  suspect CI lane.
- Prefer the PR merge ref for reproduction when matching GitHub CI.
- Keep the root checkout and disposable worktree separate.
- Create worktrees only under `<repo-root>/tmp/worktrees/<slug>`.
- Use a slug such as `pr-<number>-ci-fix` for a short-lived PR reproduction
  worktree unless maintaining the real PR head branch.
- Keep instruction and agent workflow updates on a dedicated instruction branch; do not
  transplant `AGENTS.md`, `.github/instructions/**`, or `.claude/skills/**`
  into CI-fix PR branches unless the
  user explicitly asks for an instruction-only PR.
- Do not push, merge, force-push, reset, or resolve review threads unless the
  user explicitly asks.
- Never mention local branch names, disposable worktree names, or local
  filesystem paths in reviewer-facing PR text.

## Workflow

1. Read live PR state.
   Fetch PR metadata, files, head SHA, base branch, status contexts, check runs,
   and relevant workflow run URLs. If the user mentions comments or review
   activity, also read comments/reviews before creating a worktree.

2. Decide whether CI reproduction is needed.
   If no failing or suspect lane exists, say so and stop. If the task is really
   comment-only, route to the PR comments skill. If the exact failing lane,
   dependency, file, or step is unknown, collect logs before proposing a fix.
   Extract the primary error signature and classify the failure as product code,
   test expectation, workflow configuration, dependency/install, runner/resource,
   flaky timing, external service, permission/auth, or unknown.

3. Create or reuse the right worktree.
   Use `worktree-readiness` for the mechanics. For CI parity, base the
   worktree on `main` or the verified PR base/merge ref according to the live
   PR shape. Do not switch the root checkout.

4. Reproduce the failing lane.
   Inspect `.github/workflows` and package manifests from the worktree, then use
   `references/local-ci-checks.md` to choose the narrowest local command that matches
   the failing `pull_request` gate. Capture the key failing lines.

5. Fix the root cause.
   If the fix requires code, tests, config, generated artifacts, migrations,
   scripts, or workflow YAML, stop before editing and map that todo to the
   relevant `code-authoring` lane or lanes with rationale. Read those
   lanes just in time before touching files. Use `ci-workflow-authoring` when
   the fix changes `.github/workflows/**`, path filters, matrices, caches,
   artifacts, runner settings, or workflow permissions. Make the smallest
   change that explains the failure, preserve ownership boundaries, and avoid
   unrelated cleanup. Return here for CI reproduction, validation, publication
   mechanics, and current-head check watching.

6. Validate.
   Run the failing command again. Broaden only when the touched surface is
   shared, generated, auth-sensitive, migration-related, or otherwise risky.

7. Sync or publish only when asked.
   If the user wants the fix copied back to another checkout, copy only the touched
   files, then run narrow validation from that destination. If the user asks to
   push from the worktree, use `worktree-readiness` for push/auth/Husky
   mechanics and refresh PR text only when the reviewer-facing story changed.

8. Watch the pushed head to completion.
   After a CI fix is pushed, re-read the PR head SHA and watch required checks
   for that exact SHA. Do not report the PR as fixed while any required check is
   queued or in progress. If a current-head required check fails, collect the
   failed job logs, fix only the proven cause, rerun the matching local gate,
   push again, and repeat the current-head watch.

## Security And Scanner Failures

For dependency, security, or package-API lanes, collect the failing package,
advisory/vulnerability id, severity, current version, fixed version, lockfile
state, and package-manager evidence before changing anything. Validate both the
main-based PR worktree and local environment behavior when the package is shared across
those surfaces.

## Troubleshooting

- If GitHub check-run APIs are auth-limited, use `github-workflow` `references/gh-auth-session.md` workflow-run
  reads for the current head SHA instead of stopping.
- If the prompt mentions only review comments, route away from this skill even
  when the PR also has CI history.
- If local reproduction cannot match CI, report the mismatch and keep the fix
  `Pending Verification` instead of broadening into unrelated cleanup.
- If the failure appears recurring, record the stable signature in the handoff
  or PR text only when it helps reviewers reproduce or recognize the issue.
  Do not create a separate issue from this lane unless the user asks.

## Closeout

Report:

- PR and current head SHA inspected
- failing lane and evidence
- worktree path only in local chat, never reviewer-facing text
- files changed
- validation commands and results
- current-head required-check conclusions after push, or `Pending Verification`
  if the user explicitly stopped before checks completed
- whether anything remains `Pending Verification`
