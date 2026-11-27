<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (same-actor guard and minimal review-comment submission) -->

# GitHub PR Operations Reference

## Purpose

Use authenticated GitHub capabilities as the source of truth for PR state.
Prefer the repo-configured GitHub MCP or runtime GitHub tools for PR metadata,
files, comments, reviews, statuses, check runs, PR metadata updates, and
review-thread mutation. If the authenticated tool surface does not expose the
needed operation or returns auth-limited data, use `github-workflow` `references/gh-auth-session.md` with `gh`
or `gh api`.

This skill is intentionally self-contained for GitHub PR operations. Agents
running from `main` may not have the latest `AGENTS.md`, `CLAUDE.md`, or
`repo.md`; do not rely on those files for the rules below.

This reference owns authenticated GitHub mutations, not reviewer-facing PR
authoring. For PR title/body creation or refresh, first prepare the content
through the `pr-workflow` publication lane and its
`references/pr-template-guide.md`; then use this reference only to perform the
write and verify the live result.

Do **not** fetch GitHub PR URLs as rendered webpages when the task is about PR
metadata, files, reviews, comments, statuses, check runs, PR body/title updates,
or thread mutation.

Use the narrower skills once the task shape is clear:

- read-only PR metadata/files/reviews/comments/statuses: `github-workflow` `references/pr-read.md`
- read-only comment inspection: the `pr-workflow` comments-read lane
- review-comment fixes in a worktree: the `pr-workflow` comments-worktree lane
- read-only CI state: the `pr-workflow` ci-read lane
- CI reproduction in a worktree: the `pr-workflow` ci-worktree lane
- local PR gate reproduction: the `pr-workflow` local-ci lane
- authenticated `gh` fallback: `github-workflow` `references/gh-auth-session.md`

Do not use this skill for ordinary PR publication, branch push mechanics, or
format-only PR-bound cleanup when the user explicitly says to skip collaborator
review and no live PR metadata, comments, checks, body update, or thread
mutation is needed. Use the `pr-workflow` publication lane and
`worktree-readiness` instead.

## URL Handling

If the user gives a GitHub PR URL, parse owner, repo, and PR number
immediately. Do not ask the user to restate identifiers already present in the
link.

For this repo, GitHub URLs are authenticated surfaces:

- Parse identifiers from the URL.
- Use GitHub MCP first for supported PR operations.
- If one authenticated surface lacks an exact field, fall back to another
  authenticated API path keyed by owner/repo/PR.
- Never use GitHub HTML as the source of truth for PR state.

## Repository PR Baseline

- Repository: `example-org/example-app`.
- Default PR base: `main`, unless the live PR metadata or the user identifies a
  stacked parent branch.
- Local instruction-maintenance branches are local execution context only, not reviewer-facing PR context.
- Use `worktree-readiness` for branch, worktree, push, and hook mechanics.
- Use the `pr-workflow` publication lane when validated local work
  must become a clean `main`-based GitHub PR.
- Use the matching `pr-workflow` local-ci, ci-read, or ci-worktree lane
  for PR-triggered validation and CI reproduction.
- Before creating a PR, follow the `pr-workflow` publication lane and
  its `references/pr-template-guide.md` authoring contract. Treat raw GitHub
  templates as lower-priority source material, not the governing PR-body shape.
- Before updating an existing PR title/body, follow the same publish-lane and
  PR-template authoring contract. Metadata-only updates still need current
  diff, current validation, live head SHA, and reviewer-facing noise checks.
- After `gh pr create` or `gh pr edit`, read the PR back through an
  authenticated GitHub surface and verify the title, base, head, head SHA, and
  body before reporting that the PR is ready.

## Required PR Surfaces

Pull the surfaces that match the task:

- PR metadata: title, state, author, base/head branches, body, changed files.
- CI: status contexts and check runs, including job name, conclusion, URL, and
  details URL when present.
- Comments: issue-style PR comments, review summaries, and inline review
  comments/threads.
- Thread mutation: use `get_review_comments` for inline thread state first.
  Some authenticated GitHub tool surfaces expose resolved/outdated state and
  comment URLs without the `PRRT_...` thread node ID or numeric root comment ID
  needed for mutation. Fetch missing IDs through `github-workflow` `references/gh-auth-session.md` and GitHub
  API/GraphQL before replying or resolving.
  If a GraphQL query fails because its syntax, fields, or variables are
  malformed, classify the failure before retrying. Permit one retry only after
  naming and correcting a concrete defect in the query or variables.
  Never resend a materially identical query; after two non-narrowing failures,
  stop and route through `loop-control-and-escalation`.

Do **not** infer "no actionable comments" from issue comments alone. Inline
review threads are often the actionable surface.

## Actions CI Read Path

For example-app GitHub Actions CI, never call `gh pr checks` or request
GraphQL `statusCheckRollup`, including through a `gh pr view --json` field
list. They are known token-restricted surfaces, not primary, secondary, or
fallback reads. Start with the branch workflow-run path. REST check-run and
annotation reads are optional secondary surfaces only when workflow runs lack
required evidence; a permission failure closes that path. Resolve
`<gh-auth-session-helper>` through the `github-workflow`
`references/gh-auth-session.md` skill, get the PR head branch/SHA, then use
workflow-run list/watch as the primary path:

The available GitHub token may be able to read PR metadata and workflow runs
but still fail on check-run/status-rollup details. Common failures if those
restricted surfaces are called anyway:

- `gh pr checks` or `statusCheckRollup` returns GraphQL `Resource not
accessible by personal access token`.
- REST check-runs return `403 Resource not accessible by personal access
token`.
- Actions runs API returns `404 Not Found` for endpoints the token cannot see.
- `gh run watch` prints live job/step state but also prints
  `requesting annotations returned 403 Forbidden`; that annotations warning is
  a token-scope limitation, not a failed workflow.

```bash
<gh-auth-session-helper> gh pr view <pr-number> \
  --repo example-org/example-app \
  --json headRefName,headRefOid

<gh-auth-session-helper> gh run list \
  --repo example-org/example-app \
  --branch <head-branch> \
  --limit 10

<gh-auth-session-helper> gh run watch <run-id> \
  --repo example-org/example-app \
  --exit-status
```

Before citing a run, read `actions/runs/<run-id>` and confirm its `head_sha`
matches the PR `headRefOid`.

`gh run watch` can show job and step progress even when annotations/check-run
details are forbidden. If a watched run fails and annotations are unavailable,
use job IDs printed by the watcher or `gh run view <run-id> --json jobs` when
available, then fetch logs with `gh run view --job <job-id> --log-failed`.
Report the permission gap explicitly instead of saying CI cannot be checked.

For stacked PRs, check the branch-specific latest runs after every rebase or
force-push. A previous successful run on the same branch is not evidence for
the newly pushed head SHA.

After editing a PR body, title, or other metadata, re-check branch-specific
workflow runs for the same head SHA before final closeout. Metadata-only edits
can trigger fresh lightweight workflows, especially Conventional Commits Lint;
do not report current-head CI as green while a newer run for that same head is
queued or in progress.

When grouping workflow runs by branch, ignore stale runs from older head SHAs
and, for duplicate runs of the same workflow on the same head, use the latest
`createdAt` run. If the check-rollup APIs are auth-limited, a grouped
`gh run list --branch <head-branch> --json headSha,status,conclusion,workflowName,event,createdAt,url`
inventory is the source of truth, with any unobservable required-check mapping
marked `Pending Verification`.

For artifact-producing workflow runs, a green workflow conclusion proves only
that the runner finished successfully. Before using the run as reviewer-facing
evidence, inspect the run metadata for the expected `head_sha`, list the
artifacts, and read the smallest relevant summary or JSON artifact. If the
artifact cannot be inspected, keep the artifact-derived claim as `Pending
Verification` even when the workflow itself is green.

When creating a temporary smoke PR, do not reuse an active PR's exact head SHA
unless you are prepared to clean up check-run side effects. GitHub attaches
workflow runs to the commit, so a failing smoke PR check can appear on the
active PR that shares the same head SHA. Prefer a unique smoke commit with a
valid Conventional Commit PR title; if contamination happens, close the smoke
PR, delete its branch, create or rerun a passing replacement check when
possible, and delete the obsolete failed workflow run only when it belongs to
the disposable smoke PR.

After rebasing or force-pushing a stacked PR, re-read the live base/head refs,
merge state, latest branch-specific runs, and open review threads before
declaring the PR ready. Review comments and CI status from the pre-rebase head
are stale leads until they are checked against the new head SHA.

## Required Collaborator Attempt Before Code Changes

When the user shares a GitHub PR link for review and the task may lead to code
changes, the parent agent should try to get collaborator review before editing,
but collaborator availability must not block progress. First:

1. Read the required PR surfaces and draft review findings or review notes.
2. Share the review notes through the repo-approved collaborator workflow,
   including any generated notes or artifacts as context, and wait for the
   review.
3. If the collaborator call hangs or fails, inspect the wrapper diagnostic
   before declaring the collaborator unavailable.
4. If collaborator review returns, incorporate it before deciding and making
   code changes.
5. If the collaborator is down or the call times out, do not block. Record the
   collaborator review as `Pending Verification`, explain the reason, and
   continue with parent-owned review, implementation, and validation.

Follow the collaboration skill for current VPN and wrapper-specific preflight
rules.

## Runtime Tool Mapping

Tool-call names are runtime-specific. Use the active runtime's visible GitHub
tool descriptor or schema to choose the callable operation for the task. The
logical operations used in this skill are:

- PR metadata, changed files, comments, reviews, inline review comments, status
  contexts, and check runs for reads.
- Review-thread replies, resolve or unresolve operations, PR title/body updates,
  and issue-style comments for writes.

Do not assume a specific callable naming form is available until the active
runtime shows it. If multiple authenticated GitHub surfaces are available,
prefer the repo-configured GitHub MCP or runtime GitHub tooling for
`example-org/example-app`; use `github-workflow` `references/gh-auth-session.md` only when the active
authenticated tool surface lacks the needed field or operation.

## Practical Fallback

Use `github-workflow` `references/gh-auth-session.md` when:

- the project GitHub MCP is unavailable in the current runtime
- a private PR returns auth-limited data
- a required field or mutation is missing from the available tool surface
- an Actions job log or artifact requires `gh run` / `gh api`
- check-run/status-rollup APIs are forbidden but `gh run list` / `gh run watch`
  can still show workflow state

Examples:

```bash
<gh-auth-session-helper> gh pr view <pr-number> \
  --repo example-org/example-app --json title,state,body,files

<gh-auth-session-helper> gh api \
  repos/example-org/example-app/pulls/<pr-number>/reviews
```

`gh api graphql` is needed when MCP output does not expose mutation IDs.
Resolved/outdated state is available through inline review-comment reads;
thread node IDs and numeric root comment IDs may be missing from the active
read surface and may require `github-workflow` `references/gh-auth-session.md`.

## PR Body History Recovery

Use this when a PR description was rewritten incorrectly, especially when the
PR was later closed and the closure rationale belongs in a timeline comment
instead of the body.

1. Read the live PR first: number, title, state, body, base, head, and recent
   comments. Do not assume the current body is the intended body.
2. Check whether normal timeline or issue events expose the needed edit. If
   not, use GraphQL `userContentEdits`; GitHub stores PR body edit snapshots
   there when the token has access.
3. Choose the latest historical body before the bad rewrite, or another body
   only when the user names the target timestamp or content. Do not reconstruct
   old descriptions from memory, review summaries, branch names, or copied
   fragments.
4. Restore the PR body with the verified historical text. If the exact old body
   cannot be recovered, leave the body unchanged and mark the restore as
   `Pending Verification`.
5. Add or repair the PR timeline comment that explains the durable closure
   reason. For already-closed PRs, add the comment after restoring the body;
   for PRs about to be closed, add the comment before closing.
6. Read the PR back and verify state, body prefix or normalized body equality,
   and the presence of the closure comment before reporting completion.

Generic GraphQL body-history read:

```bash
<gh-auth-session-helper> gh api graphql \
  -f query='
    query($owner:String!, $repo:String!, $number:Int!) {
      repository(owner:$owner, name:$repo) {
        pullRequest(number:$number) {
          number
          title
          state
          lastEditedAt
          editor { login }
          userContentEdits(first:50) {
            nodes {
              editedAt
              deletedAt
              editor { login }
              diff
            }
          }
        }
      }
    }' \
  -F owner=<owner> \
  -F repo=<repo> \
  -F number=<pr-number>
```

## Request Copilot Review

Copilot review requests are paid and slow enough to be treated as explicit
review gates, not routine confirmation checks. Before requesting or rerunning
Copilot, the owning PR or publish workflow must have established one of these
conditions:

- the user explicitly asked for Copilot review
- the PR is at the final ready-for-human-review gate after current-head
  validation
- a loaded workflow marks Copilot as required for the current head

If none of those conditions holds, do not request Copilot. Inspect existing
review threads, reply with verified fix evidence, resolve eligible bot threads,
and mark any missing optional review as `Pending Verification` instead of
spending another review.

For example-app PRs whose base is `main`, repo settings normally request
the first Copilot review automatically. Do not manually request that first
Copilot pass just because the PR was opened, retargeted to `main`, or because
GitHub CI is still running. Wait for the automatic current-head review to
complete: use Luna as a bounded read-only monitor when available, or poll
every three minutes for the Copilot workflow/review state and live review
threads. Only use the manual request path below for an explicit rerun, an
extra pass after fixes, or a missing current-head auto-review at the final
review gate.

If the owning PR or publish workflow has already run every applicable
deterministic local PR-triggered gate against the exact head being pushed, it
may request or monitor Copilot while GitHub CI is still running. This is only
sequencing overlap. It does not weaken the closeout proof: the owning workflow
must keep both `current-head GitHub CI` and `current-head Copilot
review/thread state` open until both are terminal and clean for the same head.

When requesting a GitHub Copilot PR review, do not use `gh pr review
--comment`, `gh pr review --approve`, `gh pr review --request-changes`,
`gh pr edit --add-reviewer copilot`, `gh pr edit --add-reviewer
github-copilot`, `gh pr edit --add-reviewer
copilot-pull-request-reviewer[bot]`, GraphQL reviewer-request mutations, or
normal-user reviewer paths. `gh pr review` creates a submitted author review on
the PR; it does not request Copilot. A submitted author review is a public
timeline artifact and cannot be deleted through the normal pending-review
delete endpoint, so treat this as a hard pre-mutation guard rather than a
recoverable typo. The reviewer-edit paths resolve the bot slug incorrectly or
fail as a non-collaborator user request.

Use the REST requested-reviewers endpoint instead:

```bash
<gh-auth-session-helper> gh api \
  repos/example-org/example-app/pulls/<pr-number>/requested_reviewers \
  -X POST \
  -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
```

Verify the request through the same endpoint. GitHub may display the requested
reviewer as `Copilot` even though the accepted API slug is
`copilot-pull-request-reviewer[bot]`.

After requesting Copilot, the owning PR lane must wait for terminal review
state before handoff. If `gh pr view --json reviewRequests` does not show the
bot after the REST call, do not assume the request failed; inspect the
current-head Copilot workflow/review state and live review threads. A queued or
running Copilot workflow is progress only, not a completed review gate.

When the user says "request Copilot review", "request one more Copilot
review", or equivalent, treat that as shorthand for the full Copilot review
gate unless the user explicitly says to only send the request. The full gate is:
request through the documented REST endpoint, wait for the Copilot workflow or
review to finish for the current head, fetch the attached review objects and
GraphQL review threads, classify every new comment, fix actionable findings,
reply on each eligible bot thread with the verified fix or classification,
resolve eligible bot threads, push any required code or docs changes, wait for
current-head CI to become green for the same head, then reread PR head, CI, and
thread state before handoff. If Copilot and CI were running in parallel, do not
handoff when the first one completes; both gates must be closed. Do not hand
off immediately after the request API returns.

Copilot has two evidence surfaces: the Actions workflow run and the attached PR
review/thread state. A successful workflow run is not enough for handoff. Verify
requested reviewers, recent reviews, and GraphQL `reviewThreads` for the
current head. If a Copilot run completed but no current-head review or thread is
attached, treat the review as `Pending Verification`; inspect the run logs for
stored-comment evidence and recover any actionable concern before handoff.

If Copilot remains as a stale requested reviewer after a completed run and no
current-head review/thread surface is attached, clear the stale display-name
request and re-request once:

```bash
<gh-auth-session-helper> gh api \
  repos/example-org/example-app/pulls/<pr-number>/requested_reviewers \
  -X DELETE \
  -f 'reviewers[]=Copilot'

<gh-auth-session-helper> gh api \
  repos/example-org/example-app/pulls/<pr-number>/requested_reviewers \
  -X POST \
  -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
```

Use `Copilot` for the stale-request delete because GitHub may reject the bot
slug on removal even though the bot slug is required for the POST request.

Do not retry paid Copilot requests in a loop. Retry only when the REST request
failed or current-head evidence shows no requested reviewer, no Copilot
workflow, and no Copilot review/comment surface.

## Thread Resolution Discipline

When the task includes resolving a PR review thread or comment:

0. Check who authored the review thread before any resolution mutation. Do not
   automatically resolve human reviewer threads, even after replying with a fix
   or rationale. Human reviewers own final resolution after they check the
   result. Automatic resolution is allowed only for Copilot-generated review
   comments when the fix or rationale is complete.
1. Use the active runtime's PR inline-comment read operation to get live thread
   state and comment context. In the project GitHub MCP API shape, this maps to
   `pull_request_read(method="get_review_comments")`.
2. If the MCP output does not include the `PRRT_...` thread node ID and numeric
   root review comment ID, fetch only those missing IDs via `github-workflow` `references/gh-auth-session.md`
   with GitHub API/GraphQL keyed by owner/repo/PR.
3. Before resolving, post a thread-specific reply with the runtime GitHub reply
   tool using the numeric `commentId` of the root comment in the thread:
    - direct answer, changed behavior, or rationale for the reviewer's concern
    - exact file(s), behavior, or dependency involved
    - no-change rationale when no code change was needed
    - validation evidence when a fix was applied
    - usually 1-4 sentences
    - reviewer-relevant context only, not an execution log
      If you must fall back to `gh api`, use the PR-specific REST path
      `repos/<owner>/<repo>/pulls/<pr-number>/comments/<comment-id>/replies`.
      The shorter `repos/<owner>/<repo>/pulls/comments/<comment-id>/replies`
      variant can return `404 Not Found` for valid review comment ids.
      Do not use a create-review, submit-review, or top-level PR comment
      mutation for this step. Those create a separate submitted review instead
      of a thread reply, and GitHub usually rejects deletion after submission.
4. Only after the reply is posted, mark the thread resolved with the runtime
   GitHub review-thread resolution tool and the `PRRT_...` thread id.
5. Never resolve silently, and never reply with content-free text like `fixed`
   or `done`.
6. If correcting inaccurate or noisy wording, inspect the authored reply batch
   and edit every affected owned reply in place. Do not stack correction
   comments or repair only the first occurrence of a repeated pattern.
7. Fall back to `github-workflow` `references/gh-auth-session.md` with `gh api` only when MCP returns an auth
   error or lacks the specific mutation field needed.
8. After replying and resolving, re-read the thread. The closeout proof is the
   reply appearing under the exact thread plus `isResolved = true`, not the
   presence of a same-text PR-level review body.

## New Reviewer Feedback Submission

Use this boundary only after the review lane has produced a final set of
surviving findings and the user has authorized GitHub review comments.

1. Re-read the live PR head and unresolved review threads immediately before
   creating the review. If the head changed or a dependency, caller, route, or
   config fact invalidates a candidate, return to the review lane and
   reassess before writing. Identify the posting GitHub actor before any
   create-review or submit-review mutation: the authenticated login of this
   posting session from the GitHub surface that will mutate. Normalize a
   login for comparison by ASCII case-folding and stripping one trailing
   `[bot]` suffix, so `foo` and `foo[bot]` are the same actor. If that login
   cannot be established, fail closed: make no create-review or submit-review
   mutation and report `Pending Verification` for the missing posting login.
   Treat the root review comment (the non-reply comment that opened the thread)
   as the thread owner. The unresolved-thread guard blocks a new review only
   when that root comment's normalized author login matches the posting actor
   and the thread remains unresolved and unaddressed. If the root-author login
   is missing, fail closed because the thread cannot be proved foreign and
   report `Pending Verification` for the missing root-author login.
   Reply-author identities never transfer thread ownership: a foreign-root
   thread remains non-blocking even when the posting actor replied or a reply
   author login is missing, and a same-actor-root thread remains blocking
   regardless of reply authors. Other actors' unresolved threads do not block a
   first review from this posting actor. A request to
   post, add, or submit remaining or unique findings authorizes the comment
   content; it does not waive this guard. Report the split explicitly:
   `Content authorization: yes; new-review authorization: no.` Hold the unique
   finding until the guard clears. Do not publish it as a reply on an unrelated
   existing thread; existing threads carry only their own existing concerns.
2. Before any create-review or submit-review mutation, require an accepted
   current reviewer packet whose `Review comments:` section supplies the
   reviewer-owned selected event, pipe-prefixed UTF-8 Summary, and one
   canonical anchor plus pipe-prefixed UTF-8 Body for every inline formal
   finding. `Unanchored findings` accounts for formal findings that cannot be
   placed on a real current diff line; never fabricate an anchor. Inline and
   unanchored ordinals must be disjoint and together cover every formal finding
   exactly once. Inline advisories are outside this default contract.
   Packet acceptance parses each literal once and verifies valid UTF-8,
   finding coverage, canonical anchor JSON, event/severity consistency, and
   required Conventional Comment decorations. Retain the accepted decoded
   inline body and summary bytes. At the publication boundary, repeat only
   mutable live-head, anchor, thread/duplicate, authorization, and active-tool
   capability checks. Do not re-parse unchanged accepted
   bytes.
   If any transport, coverage, freshness, or capability check fails, make no review
   mutation. Mechanical transport or mutable-state failures return
   through the owning workflow; semantic ambiguity or wording repair returns
   to the same reviewer. The parent must not reread code to redraft, change
   severity, invent summary prose, or silently omit an accepted publishable
   comment. Never post first and repair later. Existing user content authorization remains valid after reviewer
   repair when the target, finding
   set, and side-effect class have not expanded. Any body, summary, event,
   target, or anchor change invalidates packet acceptance and requires renewed
   acceptance before mutation.
3. Use only a GitHub publication primitive proven to preserve the selected
   `REQUEST_CHANGES` or `COMMENT` event, exact reviewer-owned summary and
   inline body bytes, anchors, and reviewed head. Prefer one event-compatible
   review submission for multiple inline comments. If the active surface cannot
   preserve that contract, try another repo-sanctioned authenticated primitive.
   If none can, make no mutation and report publication as `Pending
   Verification`. Never downgrade the event, substitute standalone inline
   comments, invent a review body, or resume the reviewer solely to obtain
   missing summary bytes. Ordinary and database sibling verdict packets remain
   separate semantic units, but their accepted comment payloads use one review
   event when both are present. Follow the deterministic join in
   `review-control-plane.md`: `REQUEST_CHANGES` takes precedence, ordinary
   bodies precede database bodies, exact anchor-and-body duplicates appear
   once, same-anchor different bodies remain, and the combined Summary uses
   the fixed application/database framing. A one-sided payload is unchanged.
4. Keep each inline body in Conventional Comments form and anchored to the
   narrowest current diff line that proves the concern. Do not submit packet
   fields, local workflow evidence, rejected candidates, or duplicate comments.
5. After submission, re-read the stored review object and inline review
   comment or thread surfaces through authenticated GitHub APIs. Verify the
   event, reviewed commit, number of comments, paths and lines, complete stored
   bodies, Conventional Comments labels, and absence of unexpected duplicates
   or truncation. Rendered HTML is not the state authority.
6. If the mutation succeeded but exact readback is unavailable or differs from
   the intended review, report the write and the mismatch as `Pending
   Verification`. Do not claim that the review comments were posted correctly.

## Reviewer And Author Comment Style

`docs/agents/pr-comment-conventions.md` is the single canonical owner of comment
wording and shape for reviewer inline comments, reviewer replies, author
replies, and the main PR review body or summary. Read it before authoring or
submitting any of them, and do not restate its rules here or paste them into a
reviewer dispatch prompt. A reviewer reaches it through the read order in
`docs/agents/pr-review-packet-format.md`, and its mechanical subset is enforced
as `RPPA-011` during reviewer packet acceptance, so a non-conforming publishable
body fails before it can reach GitHub.

This lane keeps only the submission-mechanics rule below, because it depends on
live GitHub thread state rather than on wording:

- Do not create or submit a new review when the same-actor unresolved-thread
  guard in New Reviewer Feedback Submission step 1 blocks it. Identify the
  posting GitHub actor as this session's authenticated login; treat `foo` and
  `foo[bot]` as one actor; fail closed if the login is unknown. Other actors'
  unresolved threads do not block a new review. When an unresolved and
  unaddressed thread's root review comment belongs to the posting actor, continue
  using the existing thread surface to avoid duplicate review pollution. Do
  not infer an exception from a request to post additional, remaining, or
  unique comments; report the conflict before mutation. Since submitted
  reviews are permanent public timeline artifacts that cannot be deleted or
  cleaned up once posted (resulting in irreversible timeline clutter), verify
  the current same-actor thread resolution state before calling the create
  review API.

## PR Description Drift Discipline

Review-comment follow-up commits often make the original PR body stale.

- GitHub is the mutation surface, not the owner of review-fix topology. Follow
  the active PR workflow's provenance decision: human feedback and internal
  scoped re-review use a new ancestral finding-directed commit or exact range;
  a simple Copilot-only fix may amend only when the narrow no-human-change,
  no-scoped-review, and no-immutable-target exception is proved. Do not rewrite
  a boundary while scoped review is pending.
- If the task includes addressing reviewer comments and preparing or performing
  a follow-up push, re-read the live PR title/body before treating the push as
  done.
- If the task includes applying internal council, Codex, Claude, AGY, Grok,
  Copilot, Clawpatch, or other reviewer findings, perform the same live
  title/body drift check before final handoff, even when no human GitHub review
  thread was involved.
- Compare the current PR title/body against the post-fix diff, resolved
  comments, and changed validation or rollout notes.
- If the PR description has drifted, update it in the same pass with the runtime
  GitHub PR update tool.
- When a PR body has a generated or manually maintained status block, refresh
  the head SHA, CI summary, stack/base status, and last-refreshed date after the
  final push instead of leaving stale reviewer-facing metadata.
- If the user asks to base a PR description on another PR, read both PR bodies
  through authenticated GitHub tooling.
  Treat the older PR as a structure/template only; replace dependencies, issue
  links, workflow URLs, and rollout notes with values that are true for the
  target PR.
- When using an example PR body as the standard, preserve only the durable
  structure and section intent. Do not copy stale branch names, issue links,
  workflow URLs, validation claims, or implementation history from the example.
- If the user also supplies GitHub Actions run URLs for reviewer-facing proof,
  read those runs through authenticated GitHub tooling and confirm the run
  `head_sha` matches the target PR before linking them in the body.
- Treat the PR title/body as reviewer-facing state, not frozen text from when
  the PR was first opened.
- When you write or edit a PR title or body here, follow the body shape and
  wording rules in the `pr-workflow` publication lane's PR template
  guide: fill the template sections instead of freeforming, keep the
  changed-surface list and verification scope matched to the current diff, and
  use plain hyphens rather than em dashes.

## Reviewer-Facing Discipline

- Internal agent and collaborator review passes are local development checks,
  not reviewer-facing project evidence. Never mention hidden local review
  gates, model output, collaborator process notes, subagent names, or local
  AI-tool verdicts in PR titles, PR bodies, issue comments, or review replies.
  Translate any useful outcome into concrete code changes, validation commands,
  CI state, or remaining risk instead.

- Local instruction branches are execution context, not reviewer-facing PR context.
- Never mention local branch names, disposable worktree names, or local
  filesystem paths in PR titles, PR bodies, issue comments, or review replies.
- Do not include local worktree or tooling repair details in reviewer-facing
  text, such as Husky bootstrap or repair, nvm/mise prefix workarounds,
  branch-local dependency install issues, or fresh-worktree setup failures.
  Report the actual validation command and result; keep local environment
  repair noise out of PR descriptions, issue comments, and review replies.
- Verify dependency/package-version claims from the PR branch or worktree that
  will actually be pushed, not from an unrelated local branch.
- Treat Copilot, human, and local reviewer comments as leads after base changes
  or conflict resolution. Verify the cited line and behavior on the current PR
  head, then either fix it or reply with the current-code rationale before
  resolving the thread.
- When repeated reviewers flag a dependency edge, approval gate, scope boundary,
  or other shape that is a deliberate product/operational decision, do not keep
  changing code to satisfy the reviewer assumption. Add the smallest durable
  rationale at the code or workflow boundary reviewers inspect, mirror the same
  intent in the PR body when it affects release/rollout understanding, then
  reply with that rationale before resolving.
- Stand ground only from evidence, not preference. Decline a reviewer
  suggestion when the current code, product requirement, operational model, or
  user decision proves the reviewer assumption is wrong or out of scope; when
  the suggested change would add redundant gates, unsafe coupling, broader
  blast radius, stale behavior, or unrelated cleanup; and when the no-change
  path can be explained in concrete runtime terms. If that evidence is missing,
  verify cheaply or treat the comment as actionable.
- When a review-driven fix is later judged outside the PR scope, remove it from
  the follow-up change and update the PR body so changed files, risks, and
  verification describe the final scoped diff instead of the intermediate
  review attempt.

## Validation Fixtures

Use the PR the user provided or another current read-only fixture named by the
maintainer for tool validation in this repo.

Do not perform live write-operation validation unless the user's target task
already requires that exact mutation. If a future user explicitly designates a
PR for an experiment, keep mutations reversible and report exactly what
changed.

## Recommended Workflows

### What changed in PR `<number>`?

1. Read PR metadata and changed files.
2. Summarize title, author, state, body, and changed files.
3. If asked whether it is merge-ready, read live checks too.

### What comments are on PR `<number>`?

1. Read PR metadata.
2. Read issue comments, review summaries, and inline review threads.
3. Separate those surfaces in the output.
4. Use `get_review_comments` for inline thread state and context. If mutation
   IDs are needed and absent, fetch them through `github-workflow` `references/gh-auth-session.md` with GitHub
   API/GraphQL before replying or resolving.

### Is PR `<number>` failing?

1. Read live status contexts and check runs.
2. Report only live failing contexts.
3. If nothing is failing, say so explicitly even if the user prompt described
   an earlier failure.

### Here is a PR URL

1. Parse owner, repo, and PR number.
2. Read PR metadata and live checks together.
3. If the task mentions comments, read all comment surfaces too.
4. If code changes may follow from the review, apply the collaborator review
   attempt before editing files, but continue if the collaborator is
   unavailable.
5. Route to the narrower skill that owns the next action.

## Do

- use authenticated GitHub state before local reproduction or reviewer replies
- fetch all comment surfaces for comment tasks
- keep review replies crisp and reviewer-facing
- re-check the PR body before follow-up push after review-comment work
- re-check base/head refs, merge state, CI runs, and review threads after a
  rebase or force-push
- verify version claims from the branch that reviewers and CI will see

## Do Not

- scrape GitHub HTML for PR state
- report "no comments" from only one comment surface
- resolve review threads without a substantive thread-specific reply first
- mention local-only branch/worktree/path context, internal reviewer tools, or
  local agent names in reviewer-facing text
- leave a stale PR description after review-comment fixes changed scope,
  behavior, or validation story
- mutate a read-only validation fixture
- dump raw JSON when a summary will do
