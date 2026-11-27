---
name: pr-comments-worktree
description: Use when routed here by pr-workflow for a example-app task that starts from a GitHub pull request URL and specifically asks to inspect, classify, reply to, resolve, or fix PR review comments or unresolved review threads.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-28 (tightened explicit review-comment workflow gates) -->

# pr-comments-worktree

## Purpose

Use this skill when a task starts from a GitHub pull request link and the goal is
to work through review feedback safely while the root checkout may be a dirty
root checkout with unrelated local work.

This skill combines:

- PR-link triage
- review-thread extraction
- validity assessment for each comment
- isolated `git worktree` reproduction from the PR merge ref
- targeted validation of fixes
- scoped transplanting of touched files back into a local working branch

It exists to avoid two recurring mistakes:

1. blindly implementing every PR comment without checking whether it is still
   valid, outdated, or already addressed
2. doing review-comment fixes directly in a dirty root checkout
   and accidentally dragging unrelated local work into the PR fix

## When to apply

Apply this skill when the task is about review-comment work and mentions any of
these:

- "pull the comments" or "review comments" from a PR
- unresolved review threads, change requests, or Copilot review comments
- validating whether PR comments are valid before changing code
- `git worktree`
- preserving unrelated local changes
- "fix PR comments locally but don't push"
- "copy the reviewed fix back into my local dev branch"

Do not apply this skill for a PR URL alone. Do not apply it for CI-only
failures, check-run failures, scanner failures, or validation-lane reproduction
when no review feedback is involved; route those to the PR CI worktree skill.

## Relationship to other skills

Use this skill as a workflow-specific layer on top of:

- `github-workflow` `references/pr-operations.md` — PR metadata, changed files, status checks
- `references/comments-read.md` — read-only review-comment inspection and
  summary when no fixes, replies, or resolutions are needed
- `worktree-readiness` — shared git worktree setup, Husky, dependencies,
  push/auth boundaries, and sync-back discipline
- `references/local-ci-checks.md` — PR-triggered local CI gate reproduction before
  handoff or push

Use `references/comments-worktree.md` when the task is specifically about review
comments from a PR link, not just CI failures.

## Code-Change Phase Boundary

This lane owns the review-thread workflow, not the code-authoring discipline.
After live thread discovery and comment classification, split accepted fixes by
work shape before editing:

- Backend code, datasources, Go tests, generated artifacts, migrations, SQL, or
  test utilities: route to `code-authoring` with the backend-go,
  backend-codegen, implementation, test-quality, TDD/regression, production data
  safety, or engineering-judgment lanes as appropriate.
- Frontend code, React/Next.js, TypeScript contracts, UI tests, styling, or
  browser-visible behavior: route to `code-authoring` with the
  frontend-ui, typescript-contracts, implementation, test-quality,
  TDD/regression, or simplification lanes as appropriate.
- Scripts, workflow YAML, config, dependencies, docs/operator text, or release
  readiness changes: route to the matching `code-authoring` lane before
  editing, then return here for PR-thread replies and publication mechanics.

The todo ledger must name the selected `code-authoring` lane or lanes and
the rationale before implementation starts. Read those lanes just in time before
touching files. Do not let `comments-worktree`, `local-ci-checks`, or
`worktree-readiness` substitute for code-authoring guidance.

## Non-negotiable rules

- If the user gives a PR URL, parse owner, repo, and PR number immediately.
- Start with `github-workflow` `references/pr-operations.md` so you can correlate PR metadata, live
  CI, issue comments, review summaries, and inline review threads before
  creating a worktree.
- Treat every GitHub URL as an authenticated surface. Parse identifiers from
  the URL and use authenticated GitHub PR tools as the source of truth.
- Do **not** fetch GitHub URLs with webpage tools.
- Use the active runtime's inline review-comment read operation for live thread
  state and context. If the read output does not expose the `PRRT_kwDOxxx`
  thread node ID or numeric root review comment ID needed for mutation, fetch
  only those missing IDs through `github-workflow` `references/gh-auth-session.md` with GitHub API/GraphQL
  before replying or resolving.
- Do not use a top-level PR review submission to answer an existing inline
  review thread. Author replies to reviewer or Copilot feedback must be posted
  as replies to the root inline review comment, because submitted top-level
  review comments are not the same thread and usually cannot be deleted after
  submission.
- When the feedback is a review-summary comment rather than an inline thread,
  preserve context by quoting the exact relevant reviewer sentence or paragraph
  at the top of the PR comment before the reply. Do not post a standalone
  answer that forces readers to match it back to the review summary manually.
- Do **not** treat issue comments as the complete review-comment surface.
- Inline review threads are the primary actionable comment surface.
- If issue comments are empty or only contain low-value bot comments, read
  review summaries and inline threads before reporting "no actionable comments".
- Do **not** create a worktree until the actionable comment set is identified.
- If a review thread and a live failing scanner lane point at the same
  dependency or file, treat them as one root cause instead of triaging them
  separately.
- If the root checkout is a local working branch, do **not** use it as the primary
  reproduction surface.
- Treat the local working branch as a local validation surface and the
  main-based worktree as the PR publication surface.
- Do **not** inspect or summarize unrelated diffs on a local working branch unless
  the user explicitly asks.
- Keep instruction and agent workflow updates on a dedicated instruction branch only.
  Never transplant, cherry-pick, commit, push, or include `AGENTS.md`,
  `.github/copilot-instructions.md`, `.github/instructions/**`,
  `.agents/skills/**` or other agent guidance files in a review-comment worktree branch unless the user explicitly asks for an
  instruction-only PR.
- Use `worktree-readiness` for worktree path policy, slug naming,
  branch-local dependencies, Husky setup, and push/auth mechanics.
- Prefer `pull/<number>/merge` when reproducing comment applicability against the
  latest merge result.
- After creating the worktree, run `worktree-readiness` before reading or
  editing code in that worktree.
- Do not push, commit, merge, reset, or discard changes unless the user asks.
- Before editing owner-PR comments, classify the fix topology from the review
  that must consume it:
  - human feedback, mixed human and bot feedback, or findings from an internal
    reviewer that must verify its own fixes use one new ancestral,
    finding-directed commit or exact range;
  - a simple Copilot-only fix may amend only when the human-review baseline is
    unchanged, no scoped internal re-review is required, and no immutable
    reviewed target must be preserved;
  - uncertain or mixed provenance fails closed to a new commit.
  Do not amend, squash, or otherwise rewrite a finding-directed boundary while
  its scoped review is planned, queued, running, or unresolved. After scoped
  resolution, follow the active topology policy or explicit user direction;
  rewriting invalidates SHA-bound review and CI evidence even when the tree is
  equivalent.
- Before rewriting PR history, explicitly map the live commit stack to the
  user's request. Name the base commit or base branch, the commit range being
  rewritten, and the commit subjects expected after the rewrite. Do this before
  running `reset --soft`, `rebase -i`, `commit --amend`, or any force-push.
- Preserve intentional history boundaries. Do not squash the original feature
  commit with later review-fix commits unless the user explicitly asks to
  squash the whole PR. When the request says "top two commits", "latest two",
  "Copilot comments", or "review-fix commits", rewrite only that adjacent
  range and leave lower feature or implementation commits separate.
- For a history-only cleanup, verify the resulting tree is identical to the
  pre-rewrite head with `git diff --quiet <old-head>..HEAD` before pushing.
  If the tree differs, stop and inspect before publishing; otherwise report the
  rewrite as history-only, not as a code change.
- After any history rewrite and push, re-read the live PR commits and confirm
  the visible GitHub commit list matches the intended topology. Do not rely on
  local `git log` alone.
- Handling Copilot comments means inspecting the existing live review threads,
  validating each actionable point, fixing only accepted findings, replying
  with verified evidence, and resolving eligible bot threads. It does not mean
  requesting a fresh Copilot review after every small fix. Escalate to a new
  Copilot request only when the user explicitly asks or the PR has reached the
  final review gate defined by the publish workflow.
- When the user gives a complete review-comment workflow, asks to repeat the
  same workflow used for another PR, or says "you know the drill", convert that
  workflow into a checked phase ledger before edits start. Keep separate items
  for live target/base confirmation, comment discovery, accepted fixes,
  validation, PR metadata refresh, council or sidecar review, requested
  Copilot or reviewer passes, thread replies, thread resolution, current-head
  CI, and final handoff. Do not skip a named phase because another phase is
  green. If a phase becomes impossible, mark that exact phase `Pending
  Verification` or blocked and keep the remaining safe phases moving.
- Author replies follow the shared
  [Author Replies conventions](../../../../docs/agents/pr-comment-conventions.md#author-replies).
  Before closing review-comment work, scan PR
  issue comments and review comments authored by the current GitHub user for
  7+ character SHA-like references and edit only owned comments to remove
  stale commit IDs.
- When review-comment fixes are going to be pushed, treat the PR description as
  part of the reviewer-facing surface. Re-read the live PR title/body and, if
  it drifted from the final diff or resolved feedback, update it with the
  active runtime's GitHub PR update tool in the same pass before treating the
  push as complete.
- When only the PR body or title is wrong after review-comment work, perform a
  metadata-only GitHub update instead of creating another commit. Verify the
  updated live text, and scan it for absolute paths, local tool shims, worktree
  names, `tmp/` artifacts, internal agent names, and stale validation claims.
- After checking the PR description, verify the current PR head directly. Do
  not close comment-fix work as complete while required checks for the pushed
  head are queued or in progress. Watch them to completion unless the user
  explicitly stops the task; if they fail, inspect the failing job logs, fix the
  proven cause, rerun the matching local gate, push, refresh PR body status if
  needed, and repeat the current-head watch.
- Current-head status is the only closeout status. Older green runs may explain
  history, but they do not prove the pushed fix is ready.
- Never mention local branch names, local filesystem paths, or disposable
  worktree names in PR bodies, issue comments, or review replies.
- Do not blindly fix every comment. First classify each one as **valid**,
  **invalid**, **already addressed**, **outdated**, or **non-actionable**.
- Before resolving any review thread, post an on-thread reply first and only
  then mark the thread resolved.
- That reply should be short, readable, and straight to the point about what
  the reviewer or Copilot called out.
- State the relevant fact, changed behavior, or rationale directly, with only
  validation evidence that materially helps the reviewer. Keep internal triage
  classifications out of the reply.
- Do not auto-resolve human reviewer threads unless the user explicitly asks.
  For bot-authored review threads such as Copilot, after verifying the comment
  is valid, applying and pushing the fix, and posting a concise author reply,
  resolve the bot thread unless the user asked to leave threads open.
- Conventional Comments labels belong only to review feedback you author as a
  reviewer. Do not use labels such as `` `issue(blocking)` ``,
  `` `suggestion(non-blocking)` ``, or similar decorations when replying as the
  PR author to an existing review thread.
- Apply the shared Author Replies conventions to every reply in the batch.
  Use short paragraphs for separate points rather than forcing headings or
  labeled parts onto a simple answer.
- Never use emojis anywhere in PR reviews, summaries, replies, or
  developer-facing comments—they look automated and unprofessional.
- When writing the main PR review body or summary, keep the tone direct,
  professional, and warmly conversational. Avoid machine-like boilerplate
  (e.g. "I have completed a thorough, maintainer-grade code review..."). Break
  the summary down into clean, highly scannable sections using clear headers
  and bullet points (e.g. Verdict, What I Checked, and Pending Verification)
  rather than dense paragraphs of text. This summary structure does not apply
  to ordinary author replies.
- When a PR comment depends on code evidence, cite the repository-relative
  path and include the most useful file, symbol, constant, query, or endpoint
  reference. Always use repository-relative paths (e.g. `app/data/quiz.ts`)
  rather than absolute local file paths (e.g. `file:///home/...`), which leak
  machine-local details and create dead links on GitHub.
- When referencing files alongside line numbers, wrap the entire file path and
  line numbers together inside a single backtick block (e.g.
  `` `app/components/templates/QuizContent/QuizAnswerList.tsx:74, 100` ``) so it
  formats and highlights neatly as a single code unit.
- Reply via the active runtime's GitHub review-comment reply tool using the
  numeric `commentId` of the root comment in the thread. Resolve via the active
  runtime's GitHub review-thread resolution tool using the `PRRT_...` thread
  node ID. If those IDs are absent from `get_review_comments`, fetch them
  through `github-workflow` `references/gh-auth-session.md` with GitHub API/GraphQL before mutating.
- If MCP reply mutation is unavailable and you fall back to `gh api`, use the
  PR-specific REST path
  `repos/<owner>/<repo>/pulls/<pr-number>/comments/<comment-id>/replies`.
  The shorter `repos/<owner>/<repo>/pulls/comments/<comment-id>/replies`
  variant can 404 even when the review comment id is valid.
- Never resolve a thread silently or with a low-information reply like `fixed`.
- Never create a submitted PR review just to acknowledge an existing review
  thread. A submitted review is durable reviewer-facing noise and GitHub
  rejects deletion once it is no longer pending.
- An author reply is **not** an execution log: do **not** include local
  filesystem paths, worktree names, branch names, raw command lists, or other
  machine-local details unless the reviewer explicitly asked for them or they
  are essential to explain the comment outcome.
- Ignore non-actionable bot comments (for example coverage summary comments)
  unless the user explicitly asks to act on them.
- When syncing fixes back into a local working branch, use absolute source and
  destination paths so relative paths do not accidentally target the worktree.
- After syncing fixes back into a local working branch, run narrow validation from
  the root checkout and stop there; the user owns the commit and cherry-pick.

## Comment source of truth

GitHub PR review data can show up in several places:

1. **PR metadata** — title, body, changed files
2. **Issue comments** — general discussion comments on the PR
3. **Review summaries** — high-level review body text
4. **Inline review threads** — file/path/line-specific comments; these are often
   the most actionable

For a specific PR URL in this repo:

- Use authenticated GitHub tools for baseline PR metadata, issue comments,
  review summaries, and inline review threads.
- Use the active runtime's inline review-comment read operation for live thread
  state and comment context.
- If the MCP output does not expose thread node IDs or numeric root comment
  IDs, use `github-workflow` `references/gh-auth-session.md` with GitHub CLI/API GraphQL `reviewThreads`
  queries to fetch those fields before replying or resolving.
- Do **not** use GitHub webpage fetches for PR/comment state.

Common comment-surface limitation patterns in this repo:

- empty or low-value issue-comment output is **not** enough to conclude there
  are no actionable PR comments; actionable inline review activity can still
  exist
- inline review threads are the primary file/path/line-specific surface
- inline review-comment reads may omit IDs needed for reply and resolution;
  GraphQL is the fallback for missing mutation IDs or mutation auth errors
- GitHub webpage fetches can fail to extract useful PR comment state and should
  not replace authenticated PR tooling

Reply-style lesson:

- keep reviewer replies sharp and to the point
- answer the reviewer's point directly, without triage labels or workflow narration
- if validation matters, summarize the result briefly instead of pasting the
  full command history
- if an earlier reply was inaccurate or bloated, edit it down instead of
  layering another verbose correction

### Thread reply and resolution

Use the active runtime's inline review-comment read operation to retrieve live
thread state and comment context. If mutation IDs are absent, fetch them
through `github-workflow` `references/gh-auth-session.md` with GitHub API/GraphQL:

- `threadId` node ID (`PRRT_kwDOxxx`) -> pass to the runtime's thread-resolve tool
- root review comment numeric `databaseId` -> pass as the runtime's reply `commentId`

```text
<runtime inline review-comment read>              # get thread state/context
<gh-auth-session-helper> gh api graphql ...       # missing IDs only
<runtime review-comment reply>(commentId=<numeric-id>, body=...)
<runtime review-thread resolve>(threadId="PRRT_kwDO...")
```

### GraphQL fallback — missing mutation IDs or auth errors

If authenticated GitHub tools do not expose mutation IDs, or if a mutation
returns an auth error, fall back to authenticated GraphQL:

```bash
AFTER_ARGS=()
[[ -n "${END_CURSOR:-}" ]] && AFTER_ARGS=(-f after="${END_CURSOR}")

gh api graphql \
  -f owner='example-org' \
  -f repo='example-app' \
  -F number=<pr-number> \
  "${AFTER_ARGS[@]}" \
  -f query='query($owner: String!, $repo: String!, $number: Int!, $after: String) { repository(owner: $owner, name: $repo) { pullRequest(number: $number) { reviewThreads(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { id isResolved isOutdated path line originalLine comments(first: 50) { nodes { id databaseId author { login } body createdAt state url } } } } } } }'
```

## Root checkout vs disposable worktree

This workflow has two distinct surfaces:

1. **Root checkout** — usually `<repo-root>` on branch
   a local working branch; may contain unrelated local development work.
2. **Disposable PR worktree** — usually
   `tmp/worktrees/pr-<number>-comments-fix/`; used to assess and fix PR
   comments cleanly against `main` or the PR merge ref.

Rules:

- Pull and assess comments using the PR URL and API-backed review data.
- Reproduce comment applicability and implement fixes in the disposable worktree.
- If local environment validation is required to understand or prove the
  fix, do that on a local validation branch, then keep the main-based worktree as the
  only branch that gets pushed or opened as a PR.
- If a formatting-only review-fix commit is followed by unsolicited worktree
  churn (for example a formatter or editor rewrites the file after commit),
  verify the committed blob with `git show HEAD:<path>` instead of trusting the
  dirty working-tree copy. Restore the file back to `HEAD` before push so the
  branch state matches the reviewed commit.
- Never rely on the terminal's current directory to decide which checkout you
  are editing; prefer explicit absolute paths or `git -C <path>`.
- When returning the fix to a local working branch, copy only the touched files and
  verify they match the worktree versions.
- Do not copy local instruction or skill documentation changes into the disposable PR worktree unless the PR is explicitly about those files.
- Leave commit creation and cherry-picking to the user unless they explicitly
  ask you to do more.

### Worktree readiness

After `git worktree add`, stop and run `worktree-readiness` before
reading, editing, linting, testing, committing, replying, resolving, or pushing
from the new worktree. This review-comment skill owns comment classification
and reviewer-facing replies; the shared readiness skill owns path policy,
branch-local dependencies, Husky repair, GitHub auth fallback, and push
boundaries.

## Recommended workflow

### 1. Parse the PR link and fetch baseline PR metadata

1. Parse owner, repo, and PR number.
2. Use GitHub PR tooling for the actual metadata, changed-file surface, live
   status checks, and review-thread surface.
3. Note whether the root checkout is a local working branch.
4. If review-thread ids are required for resolution and are not exposed by the
   MCP read surface, fetch them with authenticated GraphQL keyed by the parsed
   PR identifiers.

### 2. Extract the actionable comment set

1. Collect review summaries, issue comments, and inline review threads.
2. If issue-style PR comments are empty, or only show bot noise, read inline
   review threads before classifying the PR as comment-free.
3. Prefer unresolved, non-outdated, line-specific comments first.
4. Ignore or separately label comments that are:
    - already resolved
    - outdated against the current PR head/merge ref
    - general praise/summary with no requested change
    - issue comments that are pure coverage/status bot output unless the user
      asked for them
5. Treat security-review threads and Copilot inline review threads as
   potentially actionable until classified.
6. If a live scanner/security failure exists, correlate it with unresolved
   security review threads so the same root cause is not triaged twice.
7. Group actionable comments by file so fixes stay scoped.
8. When a thread is fixed, first add a concise author reply via the active runtime's
   GitHub review-comment reply tool using the numeric `commentId`, then resolve
   it via the active runtime's GitHub review-thread resolution tool using the
   thread node ID. If authenticated GitHub reads omit those IDs, fetch them
   through `github-workflow` `references/gh-auth-session.md` with GitHub API/GraphQL before mutating.
   Do not substitute a PR-level review body or summary comment for this reply;
   re-read the thread afterward and verify the new comment appears under that
   exact `PRRT_...` thread before resolving.

### 3. Assess validity before coding

For each actionable comment:

1. Use PR metadata, diffs, and review-thread context to decide whether the
   comment is plausibly still relevant.
2. Do not read or edit code in the new worktree until the worktree has been
   created and the readiness checklist above has passed.
3. After readiness passes, read the referenced file section in the PR worktree
   and check nearby repo patterns before making a code change.
4. Label the comment as one of:
    - **valid** — change needed
    - **invalid** — review suggestion is incorrect
    - **already addressed** — current code already satisfies it
    - **outdated** — comment referred to an older diff state
    - **non-actionable** — no code change required
5. Only valid comments should produce code changes.

Important:

- If a comment targets generated code, prefer fixing the source input or
  generation cause instead of editing generated files directly when practical.
- If a comment is unclear, contradictory, or too broad, report that instead of
  improvising a speculative refactor.

### 4. Create an isolated worktree

When the root checkout is a local working branch, keep that checkout clean and do
comment work in a separate worktree.

Typical flow:

```bash
git fetch origin \
  pull/<number>/head:refs/remotes/origin/pr-<number>-head \
  pull/<number>/merge:refs/remotes/origin/pr-<number>-merge

git worktree add -B pr-<number>-comments-fix tmp/worktrees/pr-<number>-comments-fix \
  refs/remotes/origin/pr-<number>-merge
```

Guidance:

- Use repo `tmp/` for helper scripts and temporary artifacts.
- Use repo `tmp/worktrees/` for worktrees too. The standard PR comment path is
  `<repo-root>/tmp/worktrees/pr-<number>-comments-fix`; do not create ad hoc
  sibling checkouts outside `<repo-root>` or under hidden temp paths.
- If the branch has no PR yet, use
  `<repo-root>/tmp/worktrees/<branch-slug>`, where
  `<branch-slug>` is the branch name with `/` replaced by `-`.
- Prefer the merge ref for comment applicability because the review should be
  evaluated against the same merge result GitHub shows to reviewers.
- If local environment validation is needed, do that on
  the local working branch first, then transplant the finalized fix into the
  main-based worktree branch that will be pushed and reviewed.

Before editing files, apply `github-workflow` `references/pr-operations.md`'s
"Required Collaborator Attempt Before Code Changes": gather the review
findings/notes for the valid comments, attempt to share them with the
repo-approved collaborator, and proceed with `Pending Verification` recorded
if the collaborator is unavailable. Collaborator availability does not block
this workflow.

### 5. Fix only the valid comments

- Make the smallest durable fix for each valid comment.
- Keep scope tight to the files implicated by the comment set.
- Avoid opportunistic refactors.
- Re-read file contents before editing if any validation step may have changed
  generated output or derived files.
- Add or update tests when a regression risk is real and the change is worth
  pinning down.

### 6. Validate in the worktree

Validate in this order:

1. the exact touched package or file lane
2. related tests for the touched surface
3. broader validation only if the comment fix makes it necessary

If the touched surface includes PR-triggered CI gates, use
`references/local-ci-checks.md` before handoff or push.

Always report:

- exact commands used
- whether the result is CI-matching, repo-native, or only locally approximate
- whether a failing test was reproduced before the fix when applicable

Before resolving any thread after validation:

- reply on-thread with the verdict and exact fix/no-change rationale
- include validation evidence when a code change landed
- only then resolve the thread if the fix or rationale is complete
- after replying or resolving, re-read the live thread state and confirm the
  target thread is resolved or intentionally still open; do not rely on a
  successful mutation response as the final source of truth

### 7. Sync back into a local working branch only when asked

If the user wants the final code in their active dirty checkout:

1. Confirm the destination checkout is the intended local working branch.
2. Use absolute source paths from the worktree and absolute destination paths in
   the root checkout.
3. Copy only the touched files or apply only precise scoped diffs.
4. Preserve unrelated local changes by refusing any broad diff, merge, or reset.
5. Verify the synced destination files now match the worktree versions exactly.
6. Re-run narrow validation in the destination checkout.
7. Stop after the working tree is ready; let the user create the commit and
   cherry-pick it to their main-based branch manually.

### 8. Report the comment outcomes clearly

For each actionable comment, report:

- comment URL or file/line reference
- verdict: valid / invalid / already addressed / outdated / non-actionable
- concise evidence
- file(s) changed, if any
- validation result

When the fix is synced back into a local working branch, also report:

- the exact source worktree paths and destination root-checkout paths
- that unrelated local working-branch changes were intentionally not inspected
- that commit creation and cherry-pick remain user-owned steps

### 9. Push from a worktree only when asked

If the user explicitly asks to push the worktree branch, use
`worktree-readiness` for the push/auth/Husky mechanics. This review skill
only adds reviewer-facing push prerequisites:

1. Re-read the live PR title/body with GitHub tooling before the push.
2. Compare the PR description against the final diff, resolved review comments,
   and validation notes.
3. If the description is stale, update it with the active runtime's GitHub PR
   update tool in the same pass.
4. If dependency or package-API behavior changed, re-check final versions from
   the main-based worktree branch being pushed.
5. Re-read live issue comments, review summaries, inline review threads,
   requested reviewers, active reviewer workflow runs, and current check state
   before the push. If any bot thread is unread,
   unreplied, unresolved, or invalidly resolved, including an outdated bot
   thread that still has `isResolved=false`, or if Copilot is queued or running
   for the current head, stop and batch that fix, reply, or wait before
   triggering remote CI. Leave human threads open unless the human explicitly
   delegated resolution.
6. Use `references/local-ci-checks.md` for PR-triggered gates before the push.
7. After the push, treat the head, PR body, thread state, and CI as new
   evidence. Re-read inline review threads, reply to and resolve eligible bot
   threads, leave human threads open unless delegated, and update the PR body if
   the final diff or validation changed.
8. If the user explicitly requested a final Copilot or AI-review pass and that
   pass produces a code-changing fix, the review evidence is now tied to the
   previous head. After the fix is pushed, wait for current-head CI again and
   request another reviewer pass only when the user's cap or workflow still
   requires current-head reviewer evidence. If the cap is exhausted, say so as
   `Pending Verification` instead of calling the PR review-clean.
9. If the user requested council or another multi-harness review before
   handoff, run it after the PR reaches the requested stable point, fix or
   explicitly reject accepted findings, and then re-run the necessary
   validation and thread checks. Do not treat the earlier council or reviewer
   output as current if the fix changed the head.
10. Do not hand off a pushed review-fix PR as ready until current-head required
   checks are green, the live PR head SHA still matches the pushed branch, and
   the live thread scan has zero unresolved bot threads, including outdated
   bot threads. These checks must be re-read after the last push, force-push,
   PR-body edit, thread reply, thread resolution, or reviewer request. If a
   human thread remains open, say so explicitly instead of calling the PR
   comment-clean.
11. For stacked PRs, a lower-branch fix makes child evidence stale. After
    amending, rebasing, or force-pushing a parent branch, rebase each affected
    child on its immediate refreshed parent, push with lease, and re-run the
    child closeout gates from its new head. Do not use the child's older green
    CI, older thread scan, or older merge-clean state as proof after the parent
    changed.

## Do and do not

### Do

- use authenticated GitHub tools first for PR metadata
- treat GitHub URLs as authenticated surfaces and never pass them to webpage
  fetch tools
- start from the PR URL itself; do not ask the user to restate the PR number
- read inline review threads before claiming there are no actionable comments
- use GraphQL review-thread queries only when thread ids or other exact fields
  are missing from the current authenticated tool surface
- add a concise author reply before resolving any addressed review thread
- re-read thread state after reply or resolution before reporting it clean
- do review-thread mutations in order: reply on the exact inline thread,
  re-read that thread, resolve only eligible bot threads, then re-read thread
  state again
- correlate live scanner failures with security review threads before splitting
  the work into separate fixes
- assess comment validity before editing code
- isolate comment fixes in a disposable worktree when the root checkout has unrelated local work
- transplant only touched files back into the root checkout
- tell the user which comments were valid and which were not
- treat empty issue-style PR comments as incomplete until review threads are checked

### Do not

- assume every PR comment deserves a code change
- inspect unrelated local working-branch drift without permission
- use GitHub webpage fetches for PR comment state
- create a worktree before you know which comments are actually actionable
- infer "no review comments" from empty issue-style PR comments
- resolve a review thread without a substantive thread-specific reply first
- parallelize review-thread reply and resolution mutations; a resolved thread
  without the author reply attached is not a complete comment fix
- report review-comment work complete from stale issue comments, review
  summaries, or pre-push thread state
- use a broad repo diff when the user explicitly scoped it out
- push or commit unless asked

## Example prompts

- Pull the comments from `https://github.com/example-org/example-app/pull/<number>`, check if they are valid, fix them in a worktree, and sync the touched files back into the requested local working branch.
- Address unresolved Copilot review comments from this PR URL without touching unrelated local working-branch work.
- Use the PR link, fetch inline review threads, validate each comment, and only then apply the real fixes locally.

## References

- `github-workflow` `references/pr-operations.md` skill — PR metadata and status-check primitives
- `references/ci-worktree.md` skill — clean worktree reproduction and sync-back discipline
- `AGENTS.md` — dirty-worktree and repo `tmp/` discipline
- `GEMINI.md` — mirrored-skill maintenance and local workflow rules
- `.github/copilot-instructions.md` — repo workflow and validation expectations
