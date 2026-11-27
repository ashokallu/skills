<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 (added code-authoring phase boundary for bugfix work) -->

# PR Bugfix Review Repro Reference

Use this skill when a colleague asks for review of a example-app PR that
claims to fix a bug, regression, flaky behavior, or user-visible failure, and
diff review alone may not prove the fix.

This skill owns the decision path from live PR read -> root-cause/fix-shape
review -> reproduction decision -> local proof or reviewer-facing finding. It
does not replace the more specific CI/comment skills.

When the task changes from proving or reviewing a bug fix into writing code,
tests, config, generated artifacts, migrations, scripts, or workflow YAML, stop
before editing and route the implementation todo through the relevant
`code-authoring` lane or lanes. Read those lanes just in time before file
changes, then return here for reproduction proof and reviewer-facing evidence.

## Use For

- PRs that claim `fix`, `bug`, `regression`, `root cause`, `repro`, or
  `stale-or-real` behavior.
- Review requests from a colleague where the important question is whether the
  bug is actually fixed.
- PRs whose correctness depends on local dev behavior, browser/auth/session
  state, database/cache state, route behavior, API contracts, migrations, or
  environment config.
- Deciding whether a reported bug still reproduces on the PR, current `main`,
  or local dev.

## Do Not Use For

- CI-only failures with a named failing lane; use `references/ci-worktree.md`.
- Review-comment triage or fixing valid reviewer comments; use
  `references/comments-worktree.md`.
- Read-only PR summary with no bug-fix correctness question; use
  `github-workflow` read lane.
- Post-implementation local CI selection after a worktree already exists; use
  `references/local-ci-checks.md`.

## Read-First Rule

Parse owner, repo, and PR number immediately. For example-app GitHub PRs, use
authenticated GitHub data first:

1. PR metadata
2. changed files
3. review summaries
4. inline review comments or review threads
5. issue-style PR comments
6. status contexts
7. check runs

Tool-call names are runtime-specific. Use the active runtime's visible GitHub
tool descriptor or schema to choose the callable operation for each data
surface.

If GitHub tools are auth-limited or missing a required field, use
`github-workflow` auth lane for the narrow fallback and mark the MCP gap
`Pending Verification`.

## Bug-Fix Review Contract

Before deciding whether to reproduce locally, answer these from current PR data
and source inspection:

- Ref: PR number, linked issue if any, and affected surface.
- Bug: expected behavior, actual behavior, affected user or system path.
- Root cause: code path and confidence, or exact missing evidence.
- Fix shape: whether the PR fixes the bug at the right ownership boundary or
  only patches a symptom.
- Provenance: for regressions, `introduced by`, `made visible by`, or
  `carried forward by` when bounded history can prove it; otherwise `unknown`
  or `N/A`.
- Proof: tests, local repro, browser/API smoke, CI, source contracts, or
  dependency docs checked.
- Risk: remaining uncertainty and what evidence would close it.

Read past the first touched file. Follow the real call path:

- entrypoint -> validation/parsing -> routing/dispatch -> owner module ->
  shared helper -> persistence/network/runtime boundary
- config/schema/docs -> runtime usage -> doctor/migration/fix path
- tests around the touched surface plus adjacent regression tests

Prefer current source and executable proof over stale comments, old CI, old
release behavior, or generated summaries. Treat those as leads until rechecked.

## Reproduction Decision

Do not create a worktree automatically. Decide first:

- **No repro needed:** deterministic code evidence plus tests or CI prove the
  root cause and fix.
- **Local repro needed:** behavior depends on browser UI, auth/session,
  local services, DB/cache state, routing, requester/API shape, migration,
  feature flags, or environment config.
- **CI skill needed:** the concrete target is a failing check run; switch to
  `references/ci-worktree.md`.
- **Comment skill needed:** the task is to address review threads; switch to
  `references/comments-worktree.md`.
- **External/staging proof needed:** local dev cannot model the integration.
  State why and ask only if the missing proof is high-risk.

## Worktree Reproduction

When local reproduction is needed, create a disposable worktree only under
`<repo-root>/tmp/worktrees/<slug>`. Prefer the PR merge ref for review parity.

Typical setup:

```bash
git fetch origin \
  pull/<number>/head:refs/remotes/origin/pr-<number>-head \
  pull/<number>/merge:refs/remotes/origin/pr-<number>-merge

git worktree add -B pr-<number>-bugfix-review tmp/worktrees/pr-<number>-bugfix-review \
  refs/remotes/origin/pr-<number>-merge
```

After creating the worktree, stop and use `worktree-readiness` before
reading deeply, editing, linting, testing, committing, or pushing from that
worktree.

For `e2e/pd` reproduction from a review worktree, hydrate that worktree's own
`.env` and `.env.local` before running auth bootstrap or Playwright commands.
Read the root checkout only as a reference source, then run from the target
worktree's `e2e/pd/` directory with `E2E_PROJECT_ROOT` set to that directory so
`.auth/`, reports, and test results stay scoped to the reviewed branch.

Keep instruction and agent workflow files out of PR worktrees unless the user
explicitly asks for an instruction-only PR. Never mention a local working branch,
disposable worktree names, or local filesystem paths in reviewer-facing GitHub
text.

## Proof Strategy

Use the narrowest proof that can falsify the bug-fix claim:

- Unit or integration test around the fixed function or API contract.
- Browser route/auth/session check for UI or navigation bugs.
- API call or requester smoke for backend/frontend contract bugs.
- Migration/codegen validation for data or schema bugs.
- Local CI lane via `references/local-ci-checks.md` when matching PR gates matters.

If the failing proof is a UI or E2E assertion and the rendered evidence shows a
possible contract mismatch, read the owning product code in the monorepo before
changing the test or accepting the product regression claim. Use the nearest
page, component, requester, router, or state module as the expected-behavior
source of truth.

Run the bug reproducer red first when practical. If red is not practical,
explain why and use the next strongest proof.
Exercise the bug through the public seam closest to the failure: handler,
service API, requester, rendered route, migration/codegen check, or CI lane.
Avoid tests that only prove a defensive guard exists; verify the user-visible
or operator-visible failure path is fixed.
For regressions, use bounded `git log -S` or `git blame` only when provenance
would change the review verdict; otherwise mark provenance `N/A`.

## Output

Lead with findings if reviewing a PR. Each finding needs file/line/symbol
evidence and a concrete failure scenario.

If no blocking issues were found, say that explicitly and include:

- root cause confidence
- strongest proof checked
- whether local reproduction was run or why it was unnecessary
- residual risk or `Pending Verification`
- whether the fix is the best available shape or a narrower/broader follow-up
  is warranted

Use this compact shape when useful:

```markdown
Ref:
Surface:
Bug:
Root cause:
Provenance:
Fix shape:
Proof:
Risk:
Verdict:
```

Do not approve, comment, close, merge, push, or land unless the user explicitly
asks for that action.
