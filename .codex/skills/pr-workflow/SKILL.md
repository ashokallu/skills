---
name: pr-workflow
description: Use when example-app work starts from a GitHub PR URL/number, "this PR", PR publication, PR title/body authoring or refresh, PR worktree, PR review, PR inline review comments including non-blocking advisory comments, PR CI/checks/status, named check-run conclusions/details URLs, PR comments, bug-fix PR root-cause or stale-or-real proof, local dev repro, headless codex review with explicit reasoning effort, or "if I share a PR link" step-by-step PR review workflow explanation with rationale and instruction sources.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (minimal same-response review comments) -->

# PR Workflow

Use this skill as the entry point for example-app pull-request work.
It keeps PR routing visible while lazy-loading the heavier lane references only
after the task shape is known.

## Route Boundary Contract

This specialist consumes the shared
[Route Node Interface and Lane Journey Contract](../work-orchestration/references/workflow-contracts.md#lane-journey-contract).
Before PR work starts, the parent names the PR target or authorized publication
request, the active side-effect boundary, the evidence that ends the current PR
phase, and the next reviewer, validation, GitHub mutation, or handoff owner.
After that proof is observed, narrate the transition before the next owner
acts. Internal PR lanes remain private workflow machinery rather than separate
user-visible route nodes.

## First Reads

`AGENTS.md` is loaded by default in this runtime, so do not re-read it unless
`references/review-worktree.md` bootstrap, routing law, or the verdict depends
on a fresh read. Before repo-facing PR work, read `repo.md`, then
`work-orchestration`, then this skill, if you have not already. Those are
live file reads; pasted context, memory, or previous
sessions do not replace them.

`work-orchestration` is the universal workflow dispatcher. You must
classify the request with its work schema (mode, side effects, success evidence,
route) before acting on this specialist workflow. If you reached this skill
without first classifying through the orchestrator, stop before any PR metadata,
GitHub, git, worktree, code, or CI tool call; load the orchestrator, classify
the request, then resume this skill only if the route confirms PR-shaped work.
If the classification does not produce PR-shaped work, follow the orchestrator's
specialist routing table instead.

Then choose the smallest lane that matches the user's ask. Do not load every
reference file by default.

Stay in the current runtime's local skill tree for PR lanes. Do not inspect
other runtime mirrors just to answer or execute a PR workflow unless another
loaded instruction or the user explicitly asks for cross-runtime comparison.
When searching for PR lane rules, constrain searches to the current runtime's
`pr-workflow` skill directory and named companion skills. Do not search
other runtime skill trees or home-directory mirrors for example-app PR
workflow rules.

## Route The Ask

| User ask                                                                                                                                                    | Lane to load                                                                                       | Operational boundary                                                                                                                            |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| "review this PR" with a URL or PR number, including headless PR review, inline review comments, or non-blocking advisory comments                           | `references/review-worktree.md`                                                                    | Senior review-owner signoff: substantive teammate whole-target verdicts use the named `FULL` floor; narrower PR intents stay proportional.      |
| Reviewer assignment, final output contract, review-comments handoff, scope-control, sibling scheduling, or parent join explanation or execution             | `references/review-worktree.md` plus the `review-control-plane` companion                          | Load both owners; for review comments also load the packet-format and GitHub-operation owners before answering or dispatching.                  |
| Exact reviewer session must verify its own findings against an ancestral finding-directed fix batch                                                         | `references/re-review-worktree.md`                                                                 | Bounded middle-phase re-review with immutable provenance and impact-cone escape rules; never grants whole-PR signoff.                           |
| PR metadata, changed files, comments, reviews, or CI summary only, especially "no checkout"                                                                 | `references/comments-read.md` and/or `references/ci-read.md` as needed                             | Read-only GitHub state only. Do not create a local checkout unless the user changes the ask.                                                    |
| Multiple PRs, PR queue, risk-sort, first pass, triage, prioritization, or "what should I review first"                                                      | `references/batch-pr-triage.md`                                                                    | Read-only queue triage. Do not call a PR review-complete or safe-to-merge unless the full review lane later proves it.                          |
| PR URL plus Copilot comments, review comments, unresolved threads, `discussion_r*`, or `pullrequestreview-*` links, even when paired with a design question | `references/comments-read.md`                                                                      | Complete comment-surface discovery first, including GraphQL review threads when needed; then answer or route.                                   |
| Failing or allegedly failing GitHub Actions on a PR, with fix or reproduction requested                                                                     | `references/ci-worktree.md`                                                                        | Inspect live CI first, prepare an isolated PR worktree, reproduce the concrete failing lane, then fix only the proven issue.                    |
| Existing branch, cherry-pick, or PR worktree needs local `pull_request` gate selection before push, review, or PR publication                               | `references/local-ci-checks.md`                                                                    | Select and run repo-proven local equivalents of PR-triggered CI gates from an already-prepared worktree.                                        |
| Validated work must be transplanted, pushed, and opened as a PR, or an existing PR title/body needs reviewer-facing refresh                                 | `references/publish-pr.md`, then `references/pr-template-guide.md` for title/body content          | Own publication preparation and closeout; use `worktree-readiness` for git mechanics and `github-workflow` only for mutations.      |
| Address, fix, reply to, classify, or resolve PR review comments or unresolved threads                                                                       | `references/comments-worktree.md`; use `references/comments-read.md` first for read-only discovery | Work through review feedback in a clean worktree, validate accepted fixes, and mutate GitHub only when explicitly requested.                    |
| Bug-fix PR where correctness depends on root cause, stale-or-real behavior, repro, or proof of the fix shape                                                | `references/bugfix-review-repro.md`, plus the review or CI lane it selects                         | Decide whether diff review is enough, whether proof is required, and how to report stale or unproven bug-fix claims.                            |

If the prompt is just "review this PR", do not route to the CI-fix,
comment-fix, or bug-repro lanes first. Start with
`references/review-worktree.md`.

For a whole-target review, or an explanation of its depth, topology, or
reasoning-effort rules, reading `review-worktree.md` is incomplete until the
`## Senior Review-Owner Scope Floor` and
`## Headless Codex Aside Reviews` sections have both been read. Do not answer
from an earlier partial view. Full review execution continues through EOF.

When the scope-control or join row activates, load
`references/review-worktree.md` and
`../work-orchestration/references/review-control-plane.md` before
answering or dispatching. Read both files through EOF. For a parent join, do not
stop after the scope-control or target-change sections: continue through
`## Lossless Parent Join`, then apply its exact candidate mapping and
precedence-selected `JOIN_*` category.
Keep the originating reviewer verdict separate from the control-plane
candidate classification and final `JOIN_*` category. Do not substitute
`PASS_WITH_FINDINGS`, `BLOCKED`, or nearby prose for the canonical candidate
and join vocabulary, and do not summarize away the retained sibling state or
the join's authority boundary.

When the final-output-contract or review-comments part of that row
activates, continue through `## Finding-To-Comment Fidelity Gate` in
`references/review-worktree.md`, the `Review comments:` subsection in
`docs/agents/pr-review-packet-format.md`, and `## New Reviewer Feedback
Submission` in
`../github-workflow/references/pr-operations.md` before answering,
dispatching, accepting, or publishing. A high-level statement that the
reviewer owns wording is incomplete. The answer or handoff must preserve the
full ordinary and database packets, exact Summary and Body UTF-8 identities,
pipe-prefixed UTF-8 literal lines, finding-ordinal coverage, complete canonical
anchors, severity-derived event and decorations, parent-only mechanical checks, unchanged-byte
publication, authenticated readback, and lossless sibling retention.

For a contract explanation or reviewer assignment, the following eight rows
are a strict lossless output contract. Reproduce every row without
paraphrasing, merging, shortening, or omitting any field. Additional
explanation may follow the complete block; it never substitutes for a row.

```text
Reviewer comments handoff:
- reviewer outputs: complete ordinary packet plus conditional review comments; complete database packet plus conditional review comments; comment-only closeout forbidden
- reviewer semantic ownership: diagnosis; exact Conventional Comment wording; exact Summary and Body UTF-8 bytes
- comment identity and transport: finding ordinal; pipe-prefixed UTF-8 Summary and Body; valid UTF-8; no model-emitted base64, digest, or byte count
- comment binding: reviewed target from the packet header; complete canonical anchor or unanchored ordinal; severity-derived event and decoration
- parent mechanical ceiling: ordinal partition; literal-block parse; UTF-8; anchor; duplicate/thread; event; authorization; unchanged-byte publication; authenticated readback
- semantic repair: return incomplete or ambiguous wording to the same reviewer; no parent redraft
- mutable-state failure: stale head or anchor fails closed for refresh
- sibling join: retain each ordinary and database verdict, finding, comment, confidence, target, and evidence gap losslessly; publish one event
```

In this repository, a request for a substantive whole-target verdict on a
teammate or otherwise non-owned PR by URL or number is a senior review-owner
signoff request. Its review-scope proposal must carry the named
`senior_pr_owner_whole_target` mandatory floor at `FULL` depth and `single`
topology. Apparent diff size cannot demote that floor.

This floor is intent-specific, not a reaction to any PR mention or generic
words such as "deep" or "thorough." It does not activate for a PR summary,
metadata or CI read, existing-comment or thread handling without a new
whole-target verdict, triage, a fix request, workflow explanation, or a
provenance-bounded targeted re-review. A whole-target review that also asks to
publish surviving findings still qualifies. Those narrower asks continue
through their existing proportional lanes. `FULL` also does not imply
`council`, replace database-review applicability, or authorize mutation.

In the initial route audit for ordinary PR review, do not say
`reviewer` is skipped. It is deferred until the PR workflow has live PR
metadata, a stable base/head target, a verified worktree when needed, and a
changed-file inventory. Use wording like
`reviewer: deferred until stable target and changed-file inventory exist;
required before final verdict`.

If the prompt says Copilot or another reviewer left comments, or includes a
review-summary URL such as `pullrequestreview-<id>`, do not answer from review
summaries alone. Load `references/comments-read.md` and discover inline thread
state before giving a recommendation, even if the user also asks a design or
workflow question.

## Review Dispatch Economy

Reviewer subagent spend is a budget, not a free resource. Resuming a reviewer
replays its accumulated context, so the first dispatch must request every
semantic artifact the known consumers require for the **active phase only**.

Default whole-target PR review, including a required database sibling, uses the
complete canonical verdict packet with conditional same-response review
comments. When formal findings exist, the reviewer adds the minimal `Review
comments:` section from `docs/agents/pr-review-packet-format.md`; a clean review
omits it. An explicitly verdict-only or triage assignment forbids the section.

This default avoids a second reviewer turn without burdening clean reviews or
repeating finding metadata. The reviewer owns exact wording from
`docs/agents/pr-comment-conventions.md`; the parent never supplies those
conventions and never drafts or rewrites comment bodies. Preparing review
comments does not authorize GitHub mutation. Narrow metadata, thread, or CI
reads do not dispatch a reviewer.

The reviewer emits the packet once to the parent. The parent accepts it once,
does not paste it into commentary or repeat it in later turns, and reports a
bounded verdict, findings, current state, and `Pending Verification` by default.
Forward the exact packet to the user only when the user explicitly asks for the
packet itself. The parent never writes or rewrites reviewer comment prose.

`references/review-worktree.md` `## Review Dispatch Economy (law)` owns the
complete producer/consumer, evidence-snapshot, publication-capability, and
one-time transport rules.

## Shared PR Rules

- Parse owner, repo, and PR number before GitHub calls. Default to
  `example-org/example-app` only when the prompt omits owner/repo.
- Prefer authenticated GitHub read surfaces for metadata, comments, reviews,
  statuses, and checks. Use `github-workflow` for authenticated GitHub
  reads, operations, and `gh` fallback.
- Plan the remote PR read pass before calling GitHub. Fetch reviews, threads,
  changed files, and branch metadata in one consolidated pass where practical
  instead of interleaving many slow network calls through the analysis. Fetch
  CI/check state as its own separate workflow-run call per
  `references/ci-read.md` instead of folding it into that consolidated call.
  Do not use `github-workflow` `references/pr-operations.md` for CI
  reads; that lane owns authenticated GitHub writes. Do not request
  `statusCheckRollup` in a `gh pr view --json` field list or call REST
  check-runs as a first attempt; both commonly return `403`/`Resource not
  accessible by personal access token` for this repo's token.
- When the user gives a PR URL or number and describes a problem, bug,
  migration concern, CI failure, review finding, or "this PR" behavior, treat
  the live PR head as the source of truth before searching code. Read PR
  metadata, fetch the head branch or PR head ref, check whether that exact head
  is already contained in `origin/local-dev-reference`, then create or reuse the
  matching PR-head worktree when it is not contained. Search and inspect code
  in that worktree first. Use the root checkout only for orchestration,
  fetching, containment checks, and explicit base/diff comparison until it is
  proven to be the same PR head.
- When the user gives an ordered PR workflow, asks to repeat a previous
  workflow, or says "you know the drill", turn every named gate into a visible
  phase ledger before mutating anything. Include target/base changes,
  reviewer-comment fixes, local validation, PR metadata refresh, council or
  sidecar review, Copilot or other reviewer requests, thread replies and
  resolution, current-head CI, and final handoff. Do not collapse the workflow
  to only the next obvious step, and do not hand off until every requested gate
  is completed, explicitly blocked, or explicitly cancelled by the user.
- When the user corrects the workflow after work has started, rebuild the phase
  ledger from the latest instruction before mutating again. Keep already-proven
  evidence only when it is still tied to the live head and current target; mark
  older or target-mismatched evidence as historical or `Pending Verification`.
- If a GitHub MCP/tool call is blocked by permissions, missing fields, or
  harness configuration, fall back to the repo-authenticated `gh` lane or local
  git/file reads rather than retrying the same blocked surface.
- Keep GitHub-facing review comments, replies, and PR descriptions focused on
  code correctness, design feedback, and verified operator state. Do not post
  internal harness, worktree, rebase, checkout, or CI execution-log metadata as
  reviewer-facing text.
- Preserve the GitHub conversation shape when replying. If the actionable
  concern is an inline review thread, reply on that thread. If the concern is a
  review-summary comment with no inline thread surface, use a PR comment that
  quotes the reviewer text at the top before responding. Do not post a
  detached standalone comment when a thread reply or quote reply can anchor the
  response to the reviewer concern.
- Do not include raw commit IDs in GitHub review replies, Copilot replies, or
  PR comments unless the user explicitly asks for them or the reviewer asked
  about a specific commit. Prefer the file, behavior, validation result,
  reviewer concern, or live PR state. Commit IDs belong in local notes, review
  packets, or CI evidence, not in human-facing thread replies by default.
- When a PR review verdict has findings, include the detailed findings in the
  same response or packet as the verdict. Do not return a findings-bearing
  verdict and defer the finding details to a later message.
- Treat a review packet as an evidence artifact, not an instruction to mutate
  the PR. If the user asks to address a finding from a review packet, first
  classify each finding as accepted, rejected, already addressed, or
  `Pending Verification`; then route accepted fixes through the comment-fix,
  implementation, validation, and publication phases as separate work. Do not
  keep operating in the read-only review lane after the task becomes a fix.
- Treat reviewer suggestions that change rollout strategy, feature gating,
  risk posture, title/body wording, ADR publication, or operator instructions
  as proposal work until accepted. First answer with the blast radius, possible
  failure modes, viable approaches, proposed path, risks, and cleanup story.
  Do not change code, title, body, ADRs, or docs to match the proposal until
  the user or reviewer accepts that direction or explicitly asks for the edit.
- `pr-workflow` owns PR discovery, thread state, worktree mechanics,
  GitHub replies, CI selection, and publication flow. It does not replace
  `code-authoring` for code or test edits. When accepted PR feedback
  requires backend, frontend, test, config, generated, migration, script, or
  workflow code changes, stop before editing and route each code-change todo to
  the relevant `code-authoring` lane with rationale. Read the selected
  code-authoring lane just in time before touching the files, then return here
  for validation, replies, thread resolution, PR body refresh, and push.
- For ordinary "review this PR" requests, do not stop after setup, checkout,
  changed-file inventory, CI collection, reviewer-lens selection, or sidecar
  launch. Those are inputs. The expected output is the review verdict with
  findings or an explicit no-findings statement. If the review cannot proceed,
  emit the review-shaped blocker with `Pending Verification` instead of
  reporting only readiness to review.
- Native Reviewer Dispatch Gate for ordinary PR review: after the stable
  worktree and dispatch inventory exist, spawn the native reviewer immediately.
  Classify the exact target through the parent-owned
  `database-review-applicability` contract. When it is `required`, prepare
  a static evidence-and-gap packet, then spawn the static `database-reviewer`
  as an independent sibling without environment preflight. Ordinary PR review
  may inspect local Git and files, checked-in artifacts according to their
  provenance, GitHub PR metadata, reviews, threads, and head-pinned CI metadata.
  It must not access live runtimes, Staging, Production, databases, logs,
  monitoring, Sentry, browsers, or other environment state, even read-only, and
  must not execute tests, builds, migrations, smoke checks, collectors, or
  other validation. Missing current proof is claim-specific `Pending
  Verification`; it does not delay either reviewer or authorize evidence
  collection. Live reads require a separately user-requested validation or
  production-readiness phase and fresh classification. Do not prescribe either
  reviewer's autonomous static inspection scope. Review handoff is blocked
  until every required reviewer returns. A required database reviewer has no
  user-opt-out or unavailable-runtime waiver. A target or relevant static
  evidence change invalidates its dependent disposition and verdict.
- Static review still includes its required Git preparation: fetch the explicit
  PR and base refs, create or reuse the canonical review worktree, reset it to
  the exact fetched head, and perform the workflow-required local refresh or
  rebase. Those actions are authorized review setup, not validation or runtime
  access; do not report them as instruction violations merely because the
  review is static. That authority does not permit helper-output or evidence
  files beyond the canonical worktree and required workflow metadata. Do not
  persist fetched runtime, database, log, or monitoring output in repository
  temporary storage, a system temporary directory, or another local artifact.
- For non-owned PR review requests where the user says to rebase with
  `origin/main`, interpret that as "locally update the review worktree with
  current `origin/main` before full review." Use
  `scripts/dev/update-pr-review-worktree-with-main.sh <worktree>` after the
  canonical PR worktree is created. The helper tries rebase first; if rebase
  conflicts, it aborts the rebase, switches the worktree to a synthetic local
  review branch based on `origin/main`, and applies the PR's aggregate diff as
  one commit. If the aggregate-diff fallback also conflicts, report the
  helper's conflicted paths as a blocker instead of hand-resolving conflicts
  during review setup. Do not push this local update for a non-owned PR unless
  the user explicitly asks for a push.
- When the user owns the PR and asks the current agent to review it, address reviewer
  comments, or handle Copilot/reviewer feedback, start by updating the PR
  worktree branch with `git fetch origin main` and rebase it onto
  `origin/main` before assessing or fixing comments.
- Before any git write or GitHub mutation on an owner PR, freeze the live
  target in local notes: PR number, head branch, base branch, live head SHA,
  current commit list, intended commit topology, allowed mutation type, and the
  exact PR or thread being changed. If any field is unknown, stale, or corrected
  by the user, stop and re-read the live target before amending, squashing,
  rebasing, pushing, force-pushing, replying, resolving, or editing PR metadata.
- Before any push or force-push to an open owner PR, re-read live review
  threads, review summaries, issue comments, current check state, requested
  reviewers, and active reviewer workflow runs first.
  Treat this as a batching gate: if any bot thread is unread, unreplied,
  unresolved, or invalidly resolved, including outdated bot threads with
  `isResolved=false`, if Copilot or another requested reviewer is queued or
  running for the current head, or if stale PR-body validation or a known local
  validation gap exists, wait or fetch that evidence, then fix and validate all
  of it before triggering another remote CI cycle. Do not push a partial CI fix
  while known review comments remain unread, unresolved, or still running.
- Treat a completed automated-review workflow run as a signal to fetch the
  resulting review objects and GraphQL threads, not as proof that there were no
  comments. Do not push, hand off, or say comments are clean until the live
  review-thread surface for the current head has been reread and every
  actionable bot thread is replied to and resolved or explicitly named as
  `Pending Verification`.
- Keep new-PR publication topology separate from already-open owner-PR
  maintenance. Before a new PR exists, finding-directed commits may remain
  separate only while required pre-open review is active; after every required
  pre-open review is terminal, `publish-pr` requires one tree-equivalent
  squashed commit over the intended base before first push and PR creation.
  The owner-PR provenance rules below apply after a PR exists and must not be
  used to publish a new multi-commit PR.
- For owner-PR comment fixes, choose commit topology only after classifying the
  required review provenance. Human feedback and findings from an internal
  reviewer that must verify its own fix use a new ancestral,
  finding-directed commit or exact range. Do not amend, squash, or otherwise
  rewrite that boundary while scoped re-review is planned or active. A simple
  Copilot-only fix may amend only when the human-review baseline is unchanged,
  no scoped internal re-review is required, and no immutable reviewed target
  must be preserved. Uncertainty fails closed to a new commit.
- Comment-thread ownership is separate from code ownership. For
  Copilot-generated threads, post a concise reply with the verified fix,
  rationale, or non-actionable classification before resolving the thread.
  Never auto-resolve human reviewer threads; leave those open for the reviewer
  unless the human explicitly delegates resolution.
- Before any squash, amend, rebase, or force-push on an owner PR, write down
  the intended commit topology from the live PR commits and user request:
  which commits must remain separate, which commits may be combined, and which
  base branch the resulting diff is measured against. Do not collapse an
  original feature commit together with later review-fix commits unless the
  user explicitly asks to squash the entire PR. Phrases like "top two commits"
  mean only those commits, not all commits in the PR.
- If the user corrects the PR number, branch, commit range, or required commit
  count after work has started, stop the current git-write path. Re-read the
  live corrected target, inspect local branch/reflog state, and move only the
  intended changes to that target before any amend, squash, rebase, push, or
  force-push.
- For Copilot-only follow-up churn, preserve the reviewer's useful history
  boundary: combine adjacent bot-review fix commits with each other when
  requested or when they are clearly the same follow-up batch, but keep the
  underlying feature or intentionally separate implementation commits intact.
  After rewriting, verify the live PR commit list matches the intended shape
  before reporting completion.
- After pushing owner-PR comment fixes, always re-read the live PR body and
  update it when it no longer matches the diff, validation, or review state.
  This is part of the documentation-staleness sweep: the PR body is a live
  reviewer-facing document, not a secondary status note.
- After any push or force-push that addresses review feedback, immediately
  re-read the live inline review-thread surface, not only issue comments or
  review summaries. Do not report the PR as comment-clean until every bot
  thread, including `isOutdated=true` threads, has either a thread-specific
  reply and is resolved or is explicitly named as `Pending Verification`;
  every human thread must be
  left for the human reviewer or explicitly delegated. `isOutdated=true` is not
  a substitute for `isResolved=true`.
- Treat the PR body as reviewer evidence, not a formality. Before handoff,
  check that it includes the current rationale, failure or incident evidence
  that motivated the change, live config values that reviewers will compare,
  stack or dependency links, validation actually run for the current head, and
  explicit `Pending Verification` for unrun operator checks. Remove stale
  timeout values, old head claims, obsolete dependency notes, and copied
  placeholders before asking a human to review. Also remove stale pending-CI
  notes after current-head CI turns green, stale validation commands after a
  review-fix push, stale reviewer-guide file lists after the diff changes, and
  stale Copilot/reviewer status after threads are replied to or resolved.
- PR descriptions must be portable reviewer documents. Before any handoff or
  metadata-only correction, scan the live body for local paths, absolute
  binary paths, local tool-install paths, disposable worktree names, copied
  check-run inventories, routine `GitHub CI` sections, raw commit IDs,
  Copilot/council/Luna process labels, reviewer-verdict labels, and transient
  headings such as "focused validation after ...". Rewrite those as
  repo-relative commands, behavior-focused validation notes, or remove them.
- After a PR body edit, re-read the live body and scan again for those same
  forbidden terms. If a process label remains or a removed bullet left a glued
  sentence on the previous line, fix the body before reporting completion.
- Treat paid or slow AI reviewer requests, including Copilot review reruns, as
  final-gate actions, not routine confirmation after every small fix. Request
  such a review only when the user explicitly asks, when the PR is ready for
  the final review gate after current-head validation, or when a loaded workflow
  says that reviewer is required for this head. For normal follow-up fixes,
  inspect existing threads, reply with verified evidence, resolve eligible bot
  threads, and rely on focused validation plus current-head CI instead of
  repeatedly requesting a new review.
- Do not request Copilot by guessing reviewer-assignment semantics. In
  particular, do not use `gh pr edit --add-reviewer
  copilot-pull-request-reviewer` as the Copilot review trigger unless the
  repo's current GitHub workflow explicitly documents that path. Use the
  documented Copilot/GitHub workflow trigger and then verify the Actions run,
  review object, requested-reviewer state, and inline threads together.
- If the user explicitly requires a council, Copilot pass, Codex review, Luna
  sidecar, or any other reviewer gate, CI green is not a substitute for that
  gate. Run the named gate at the point the workflow specifies, fix accepted
  findings, then re-enter validation and closeout for the new head. A final
  answer that says only "CI is green" is incomplete while any requested
  reviewer gate, thread scan, metadata refresh, or sidecar evidence remains
  outstanding.
- If the user says "request Copilot review" or "request one more Copilot
  review", do not stop after sending the request unless the user explicitly
  says to only send it. Treat the phrase as the full PR workflow gate:
  request, wait for current-head Copilot completion, fetch review objects and
  GraphQL threads, classify and fix actionable comments, reply on and resolve
  eligible bot threads, push any required fixes, wait for current-head CI, then
  reread live PR/thread/check state before handoff.
- When Copilot review is explicitly requested or required, it becomes a
  current-head closeout gate. It may overlap with GitHub CI only when the exact
  PR head already passed the applicable deterministic local PR-triggered gates.
  Request or monitor it before GitHub CI is green only when the user explicitly
  asked for Copilot or the loaded workflow requires Copilot for this head.
  Manual requests must not replace the expected automatic first Copilot pass on
  `main`-based PRs. Once Copilot is requested or required, the phase ledger must
  carry two independent gates: `current-head GitHub CI` and `current-head
  Copilot review/thread state`. Do not call the PR ready, green, done, fixed,
  or review-clean until both gates are terminal and clean for the same head:
  required CI is green, Copilot is terminal, review objects and GraphQL threads
  were inspected, and no actionable current-head Copilot comment remains
  unresolved.
- Treat Copilot execution and Copilot PR review state as two separate evidence
  surfaces. A successful Copilot Actions run only proves the daemon executed;
  it does not prove a review object, inline thread, or cleared requested-reviewer
  state was attached to the PR. After every requested Copilot pass, inspect the
  current-head workflow run, live reviews, requested reviewers, and GraphQL
  `reviewThreads` together. If the run log claims a comment was stored but no
  current-head PR review or thread appears, mark the pass `Pending Verification`
  and recover the concern from logs where possible. If Copilot remains stale as
  a requested reviewer with no current-head review/thread surface after a
  successful run, clear the stale Copilot request and re-request once through
  the documented GitHub workflow, then wait for the fresh current-head pass and
  inspect threads again.
- If Copilot leaves comments, classify them as bot review threads: fix or
  explain with current-code evidence, post a concise thread-specific reply,
  resolve only eligible bot threads, push or amend according to the active
  commit policy, refresh PR metadata if it drifted, and wait for current-head
  CI to go green again after any code or metadata-changing push.
- For simple Copilot-only fixes on an owner PR, amend is permitted only after
  the active workflow proves that no human-review baseline changed, no scoped
  internal re-review is required, and no immutable reviewed target must remain
  addressable. Otherwise use a new commit. Verify the live commit list after
  the push.
- If the user requested a final Copilot review, council review, Codex review,
  Luna inventory, or other named gate, record it in the phase ledger and keep
  working until that gate is terminal for the current head. Do not hand off
  from green CI while a required reviewer gate is queued, running, absent, or
  not inspected.
- Before handoff on any PR task, audit the phase ledger against the latest user
  request. The final response must name the actual terminal state: comments
  fixed or unresolved, bot threads replied/resolved or still open, human
  threads left for reviewer, PR body/title fresh or still stale, current-head
  CI green/failed/pending/inaccessible, and requested reviewer gates
  complete/blocked.
- When the user says to repeat the same workflow, follow the same drill, sync
  dependent PRs the same way, or otherwise references a previous ordered PR
  process, reconstruct the full gate list from the user's latest instruction
  before starting. The phase ledger must include every named gate from that
  workflow, such as base change or rebase, PR body refresh, Copilot comment
  fixes, first current-head CI green, council or Codex review, post-review
  changes, final Copilot request, thread resolution, final current-head CI, and
  handoff. Before final response, audit the ledger item by item; a successful
  push, one green CI pass, or one reviewer pass does not complete the workflow
  while any named gate remains unrun, running, unresolved, or stale.
- PR body freshness is part of the same gate as code freshness. After every
  review-fix push, amend, force-push, base change, or dependency update, re-read
  the live body and remove stale validation sections, obsolete pending-CI
  wording, local machine paths, reviewer-process labels, old dependency notes,
  or validation commands that no longer match the current diff.
- PR title, ADRs, and durable docs are part of the same freshness sweep when
  they exist or are changed by the PR. After a reviewer-driven scope change,
  ensure the title does not overclaim, ADR numbering matches the branch it will
  land on, local-only references are removed from publishable docs, and rollout
  or cleanup language matches the current implementation.
- When the user caps reviewer requests, record the cap and count requests
  against the live PR. After the cap is exhausted, do not ask for another
  reviewer pass just because code changed again; use local validation,
  current-head CI, and existing thread state unless the user explicitly resets
  the cap.
- If the only stale surface is PR metadata, such as an inaccurate validation
  command, stale dependency note, or reviewer guide wording, fix the PR body or
  title directly through the GitHub lane. Do not create a code commit for a
  metadata-only correction. Re-read the live body afterward and scan for local
  path leakage, non-portable commands, routine CI noise, and internal process
  labels before reporting it fixed.
- Closing a PR is not a metadata-only PR-body correction. When closing a PR as
  superseded, obsolete, duplicate, abandoned, empty, or no-active-diff, first
  add a PR timeline comment that explains the durable closure reason, the
  successor or owning PR when one exists, whether any runtime behavior is being
  dropped, and what would have to change before reopening. Then close the PR.
  A PR body edit may remove stale or misleading text before closure, but it is
  never a substitute for the closure comment.
- If a PR was closed after an incorrect or misleading PR description rewrite,
  do not guess the previous body. Use the GitHub operations lane to inspect PR
  body history through GraphQL `userContentEdits`, restore only a verified
  historical body or explicitly leave the body unchanged as `Pending
  Verification`, then add the closure comment that should have been present.
- After closing a PR, re-read the live PR state and timeline. Verify the
  closure comment is present, the state is closed, and the PR body does not
  still say closure is undecided, pending, or future work when the decision has
  already been made.
- Keep PR metadata-only work isolated from local repo edits. Use a scratch file
  outside the checkout or a clearly ignored temporary path for body drafts, and
  run `git status --short --branch` before and after the GitHub mutation. If
  local files become dirty during metadata-only work, inspect them immediately;
  do not stage, commit, or push them unless they are an explicitly requested
  instruction/code change.
- Any PR body write, including a small refresh after review comments, must
  first route through this skill's `references/publish-pr.md` lane and
  `references/pr-template-guide.md`. Use the GitHub lane only after that
  content is prepared, as the authenticated mutation mechanism. Do not
  freehand PR descriptions from chat context, local notes, or memory.
- If you push, force-push, update a PR title/body, request or rerun PR CI, or
  resolve/reply to review threads, do not close from the GitHub mutation alone.
  Immediately re-enter this skill's owning PR publication lane, re-read live PR state,
  and complete the lane's closeout checks. A successful `gh` command proves only
  that the mutation was accepted; it does not prove reviewer-facing metadata,
  current-head CI, or review-thread state is complete.
- Treat every push, amend, force-push, PR body edit, title edit, or thread
  mutation as a phase boundary. Re-run the route classification before the next
  action: local validation belongs to the local-ci lane, reviewer-facing text
  belongs to the publish lane, thread replies belong to the comments lane, and
  final readiness belongs to the post-publication closeout. Do not carry a
  decision made in one phase into the next phase without live evidence.
- When a PR branch is rewritten after review feedback, all earlier PR-body CI
  claims, Copilot summaries, sidecar inventories, and thread scans are stale
  unless tied to the new live head or proven tree-equivalent. Refresh them in
  this order before handoff: live head and changed files, local validation that
  matches the changed surface, PR body, review threads, sidecar CI inventory
  when required, then parent-owned current-head CI.
- If a PR title/body update is needed after an amend, squash, rebase, or
  force-push, re-read the live PR head SHA, changed files, and current-head CI
  before drafting the replacement text. Old PR-body validation claims and old
  workflow runs are historical unless they are tied to the live head SHA or an
  explicitly proven tree-equivalent rewrite.
- For follow-up, repair, or stacked PRs, the PR body must link the parent,
  prerequisite, or source PR that explains the relationship, or explicitly say
  there is no dependency. Do not rely on the base branch alone to explain why
  the PR exists.
- After any push, PR creation, PR-body update, amend, squash, rebase, or
  force-push on a PR, complete the post-publication sequence before closeout:
  re-read the live PR title, body, base, head SHA, changed files, and
  current-head CI; run the configured bounded sidecar for CI status inventory
  when the runtime provides one; then make the parent-owned final CI judgment
  from live GitHub evidence. The sidecar reports the check/run inventory back
  to the parent, but the parent owns log interpretation, fixes, reruns, final
  readiness, and every user-facing claim.
- When the runtime has a configured lightweight CI inventory sidecar, that
  sidecar is a required closeout input for PR create/update/push work. It is not
  a substitute for parent judgment and not a best-effort detail to omit
  silently. The parent must explicitly say whether the sidecar completed, what
  current-head CI state was proven, and which checks are still
  `Pending Verification`.
- If the sidecar cannot be launched, cannot access the evidence, times out, or
  returns unsupported/incomplete output, do not silently continue as if the
  sidecar gate passed. Mark the sidecar CI inventory as `Pending Verification`,
  perform the parent-owned live CI read, and say that the PR closeout is missing
  the required sidecar evidence.
- Keep the workflow active until required current-head checks are green, fail
  with an inspected cause, or the user explicitly pauses or asks for status
  only. Do not hand off "pushed", "updated", "fixed", "ready", "done", or
  "green" while the loaded lane still has required CI, PR metadata, or review
  thread work outstanding.
- For review requests, the final response must be the review packet, not a
  progress report that only says checkout, sidecar review, council review,
  comment discovery, or CI inventory finished. A complete review closeout states
  the live target, freshness, current-head CI state, thread state, findings or
  explicit no-findings verdict, residual risk, and any `Pending Verification`.
  Do not hand off that closeout if the Native Reviewer Dispatch Gate failed.
- Do not sign off on a pushed PR while current-head required checks are still
  queued or in progress. Either watch the current head until required checks
  complete, or explicitly report that CI is still pending and keep working when
  the user asked for a fix. If any current-head required check fails, fetch its
  logs, fix the proven cause, validate locally with the matching gate, push,
  update the PR body if needed, and repeat the current-head CI watch.
- Treat "opened", "pushed", "fixed", "ready", and "green" as different claims.
  A branch can be pushed while PR-body metadata is stale, and a PR can be open
  while current-head CI is still unknown. Say exactly which claim is proven and
  which one is pending.
- Treat stale green checks from an older head as historical only. Pin every CI
  statement to the live PR head SHA and ignore older runs when deciding whether
  the PR is fixed.
- When a user asks "what next" after a PR push, CI run, or review-comment
  handling step, answer from live PR evidence and name the next owning lane.
  Do not answer from memory, previous run summaries, or old PR-body status
  blocks.
- For example-app PR CI fixes, do not use the generic `gh-fix-ci` skill.
  Use `references/ci-worktree.md`, with `github-workflow` auth lane only as the
  authenticated CLI fallback.
- Pin one live PR head SHA for review evidence. If the head changes mid-work,
  discard stale artifacts and restart the lane at the new head.
- Once a review or fix worktree is ready, local git and file reads are the
  source of truth for changed files, patches, and code contents. Remote file or
  diff reads are metadata fallbacks only when the lane explicitly allows them.
- Keep ordinary PR review read-only. Do not run validation, edit files, post
  comments, commit, or push unless the user's ask or selected lane explicitly
  requires it.
- Triage-only queue work is not review approval. Use "low queue risk" rather
  than "safe to merge" unless a full PR review and required merge gates have
  actually completed at the current head.
- Before final signoff, consider `cross-harness-workflow` or reviewer
  `COUNCIL` mode for broad, high-blast-radius, contested, or AI-heavy PRs when
  heterogeneous review would materially improve confidence. Escalation is
  mandatory only when signoff is requested, a central risk touches auth,
  permissions, tenant/user data, production mutation, migrations, infra/deploy,
  generated contracts, public APIs, or broad AI refactors, and at least one
  escalation signal is present: the diff spans multiple domains,
  single-reviewer evidence cannot bound the blast radius, or reviewer findings
  conflict. Narrow, well-bounded PRs on those surfaces can stay in FULL review
  when current local evidence is sufficient. Do not apply this to read-only
  triage or metadata-only asks unless the user requests signoff.
- For worktrees, load `worktree-readiness` and follow its reuse, dirty
  tree, branch ownership, and push rules.
- For reviewer verdicts, load the current runtime's reviewer role, then
  `reviewer` after the stable review target and changed-file inventory are
  known.
- For parser-facing PR review output, use the packet format reference at
  `docs/agents/pr-review-packet-format.md`.

## Closeout

Name the lane used, the evidence collected, commands run, and any `Pending
Verification` surfaces. For read-only lanes, say explicitly when no checkout or
mutation happened. For mutation lanes, report the worktree, files touched,
validation, commit, push, GitHub write state, and final current-head
required-check conclusions as applicable. If any required check is still
pending, the closeout must say that plainly and must not describe the PR as
fixed or green.
