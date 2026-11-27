<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-27 (single-commit pre-publication boundary) -->

# Publish PR

## Purpose

Use this skill when the user wants a previously completed change moved onto a
clean branch from `main`, validated in an isolated worktree, and published as a
GitHub pull request.

Also use this skill for reviewer-facing PR title/body refreshes on an already
open PR. Even a metadata-only correction must follow the publication template,
diff freshness, and current-head CI closeout rules before a GitHub mutation is
reported as done.

This skill is intentionally self-contained for PR publication. Agents running
from `main` may not have the latest `AGENTS.md`, `CLAUDE.md`, or `repo.md`; do
not rely on those files for the branch split, PR text, or publication rules
below.

This workflow is specifically useful when the current checkout contains
unrelated work and the user wants a clean PR
without dragging that drift along for the ride.

This skill owns PR publication and PR-template behavior. Use
`worktree-readiness` for shared git worktree setup, branch-local
dependencies, Husky repair, and push/auth boundaries. Use
the `pr-workflow` local-ci lane to reproduce PR-triggered gates before opening or
updating the PR.

Opening a PR is not handoff, and small diffs do not bypass authoring
self-audit, required reviewer gates, template truth, review-thread handling,
or current-head readback.

Treat publication as a phase ledger, not a single GitHub mutation. A PR URL is
only proof that GitHub accepted a branch and body. It is not proof that the
authoring lanes were applied, reviewers approved the current diff, review
threads are handled, CI is green for the current head, external provider checks
are satisfied, or the body still matches the diff. Keep each phase separate and
name the evidence that proves it.

Run the owning review gate on the change before the first push, force-push, or
PR creation, not after. Order the work as author, then review, then publish. For
code-bearing PRs the native reviewer subagent is always available in this
runtime, so treat a pre-push review as a required step, not an optional second
pass, and fix or consciously reject its accepted findings before publishing.
This workflow requirement is sufficient authorization to invoke the bounded
native reviewer subagent for the publication gate; do not pause for a separate
subagent permission question.
The reviewer-unavailable allowance applies only to external human or council
reviewers: when just an external pass cannot run, record it as
`Pending Verification` and continue. Do not use it to skip the native gate or to
justify pushing first and reviewing afterward.

If the native reviewer subagent cannot start because stale sidecars or the
runtime agent limit are in the way, repair the sidecar state through the
delegation lane and retry before publication. Do not treat the first spawn
failure as a review result, and do not hand off a PR while the required native
gate is still missing.

After the committed target and changed-file inventory exist, load
[database-review-applicability.md](../../work-orchestration/references/database-review-applicability.md) and carry
its complete packet through publication. When disposition is `required`,
dispatch the independent `database-reviewer` without delaying or shaping the
ordinary reviewer. First push, force-push, PR creation, and PR-ready handoff are
blocked until its verdict returns. `Pending Verification`, reviewer
unavailability, runtime limits, parent confidence, or ordinary-reviewer success
do not waive this gate. `not required` is valid only with the packet's evidenced
negative consequence trace.

Before spending parent context on reviewer-facing inventory, load the
`luna-scouting` lane from the `work-orchestration` skill when a bounded
read-only Luna slice can help: PR body drift, changed-file surface summaries,
validation-command discovery, stale docs, or CI/status inventory from
already-fetched evidence. The parent owns GitHub writes, final CI judgment,
and the actual PR text.

When the user asks to open or create a PR, treat that as a request to complete
the publication loop, not to stop immediately after GitHub returns a PR URL.
After opening the PR, read it back, inspect current-head CI, and keep ownership
until required checks pass, fail and are being fixed, or are blocked by an
explicit external condition. Return early only when the user explicitly asks
for link-only publication, says not to wait for CI, or gives a bounded stop
condition.

When the user asks to create a PR from a worktree or branch and no Jira issue
is already selected, pause before push or PR creation. Ask whether the user has
a Jira issue link/key to use, or whether they want a new Jira issue created for
the PR branch. Do not ask this for ordinary worktree setup, local exploration,
or validation-only branches that are not being published as PRs.

If the user selects or creates a Jira issue for the PR, make the Jira key part
of the PR branch name before publishing whenever that is still practical. Jira
native development panels primarily index branch and commit metadata; PR body
links and remote issue links are useful fallbacks, but they do not reliably
populate the Git integration section. If the branch is already an active open
PR or stacked branch and renaming would create avoidable churn, keep the branch
stable, link the Jira issue visibly, and report native dev-status as
`Pending Verification`.

In this repo, PRs ship from clean `main`-based branches unless the live PR
metadata says otherwise. Keep validation-only branch state separate from the
branch that will actually be reviewed.

## USE FOR

- cherry-picking an existing commit onto a clean `main`-based branch
- transplanting validated local work into a PR publication worktree
- validating, pushing, and opening a PR with `references/pr-template-guide.md`

## DO NOT USE FOR

- commits, cherry-picks, or direct pushes to `local-dev-reference` or any branch
  cut from it; those are non-PR integration/instruction branches and use
  `worktree-readiness` only. Never open a PR, resolve Jira, draft a PR
  template, inspect review threads, or activate PR-CI closeout for those
  branches.
- preparing an existing worktree without PR publication; use
  `worktree-readiness`
- read-only or fix-oriented review-comment work on an existing PR; use the PR
  comments skills
- reproducing PR CI after a worktree already exists; use
  the `pr-workflow` local-ci lane

## Non-negotiable rules

- Treat the root checkout and the worktree as separate surfaces.
- Treat validation-only branch state as separate from the PR base branch.
- Create the worktree from `origin/main` unless the user explicitly asks for a
  different base.
- Do not publish a new PR from a topic-only branch when the intended Jira issue
  is unknown. First resolve the Jira key or create the issue, then create or
  rename the publication branch so the key is present in the branch name,
  title, and PR body. This gate applies at PR publication time, not when merely
  creating a local worktree.
- For stacked PRs, create each dependent branch from the intended parent branch
  rather than from `main`. Verify the live base chain before push; for the E2E
  stabilization split the expected order is smoke, then regression based on
  smoke, then visual regression based on regression.
- When `main` moves under an existing stack, rebase the root branch onto
  `origin/main`, then rebase each child onto the updated local parent branch in
  dependency order. Do not skip the child rebase just because the root branch
  pushed cleanly; CI dispatched from a child branch uses the child branch SHA,
  so it will not see newly pushed parent commits until the child is rebased and
  pushed too.
- After a stacked rebase, push root to leaf. Child branches usually require
  `git push --force-with-lease` because their commit SHAs changed; fetch first,
  use explicit branch names, and verify `origin/<branch>` equals the local tip
  before telling the user to rerun CI.
- Author replies to PR review threads must not include transient commit SHA
  references. When squashing or rewriting a PR branch, also scan issue comments
  and review comments authored by the current GitHub user for stale commit SHA
  references. Edit only owned comments to remove the transient SHA and keep the
  durable fix explanation.
- Closing a PR is a reviewer-facing timeline action, not a PR-body cleanup.
  For superseded, obsolete, duplicate, abandoned, empty, or no-active-diff PRs,
  add a short PR comment before closing. The comment must explain the closure
  reason, link the successor or owning PR when one exists, state whether any
  runtime behavior is being dropped, and name the condition that would justify
  reopening. After the comment lands, close the PR and read it back.
- Do not use a PR description edit as the closure explanation. Update the body
  only when it would otherwise remain materially misleading, and verify after
  closure that it does not still say the close decision is pending.
- Create worktrees only under the repo `tmp/` directory. Use
  `<repo-root>/tmp/worktrees/<branch-slug>` for PR publication worktrees
  instead of inventing sibling directories outside `<repo-root>`.
- For a new branch that does not have a PR yet, name the worktree folder from
  the branch name with `/` replaced by `-`. Do not wait for a PR number to pick
  the path.
- If the change depends on local environment behavior, validate it on
  a local validation branch first, then transplant it into the `origin/main`-based
  worktree for the branch that will actually be pushed and reviewed.
- Use absolute paths for all worktree operations.
- After creating the worktree, run `worktree-readiness` before
  cherry-picking, reading, or editing code in that worktree.
- Re-read conflicted files before resolving cherry-pick conflicts.
- Never commit local-only env files copied into the worktree for validation.
- Never mention local branch names, local filesystem paths, or disposable
  worktree names in PR titles, PR bodies, or reviewer-facing comments.
- Do not bring instruction or agent workflow changes into PR publication
  worktrees. `AGENTS.md`, `.github/copilot-instructions.md`,
  `.github/instructions/**`, runtime skill directories, and other repo agent guidance changes stay on a dedicated instruction branch only unless the user
  explicitly asks for an instruction-only PR.
- For package-version or package-API changes, re-check the manifests and
  relevant code from the main-based worktree before committing, pushing, or
  drafting the PR body.
- Use `worktree-readiness` for Husky setup, branch-local dependencies,
  and push/auth mechanics.
- Before the first expensive reviewer, council, Codex review helper, push, or
  PR creation, the publication worktree must be committed and all runnable
  CI-equivalent local checks selected for the changed surface must pass. Run
  formatting, generation, lint, build, focused tests, and broad race/coverage
  checks when the corresponding CI workflow will run them. A narrow package
  test is not enough for a non-trivial backend change when broad backend CI is
  runnable. Fix every local failure before spending reviewer tokens or time;
  reviewers are not a substitute for local CI. Record genuinely unavailable
  checks as `Pending Verification` with the exact blocker.
- Before any pre-open reviewer subagent, council, Codex review helper, Copilot
  review, or external reviewer gate, rerun the `code-authoring` handoff
  contract against the actual committed diff. This is a hard authoring gate,
  not status prose: list selected lanes revisited, prove the diff matched those
  lane instructions, record coverage and variance ledgers, name validation or
  `Pending Verification`, and end with `next action allowed: yes`. If that
  contract cannot honestly say yes, fix the branch before asking anyone else to
  review it. Reviewers are not a substitute for applying the selected
  authoring lanes.
- After the committed worktree branch has local CI passing, spin the native
  project `reviewer` subagent for an independent pre-open review. In Codex,
  that means the `multi_agent` reviewer role backed by
  `.codex/agents/reviewer.toml`; do not search for or prefer repo shell
  wrappers when the native subagent tool is available. Keep it unbiased about
  the author's reasoning: do not provide the intended implementation strategy,
  review summary, proposed fix, PR-body draft, or intermediate failed attempts.
  Use `references/reviewer-handoff.md` to prepare the factual target contract:
  publication worktree path, base branch or base/head when known, stated user
  request, acceptance criteria and non-goals when known, changed-file
  inventory, validation, and any prior accepted finding that defines the
  required behavior. Treat this as a blocking first-open gate: fix accepted or
  actionable findings, recommit, and rerun the relevant local CI. Update the
  append-only review-round ledger from `reviewer-handoff` before deciding the
  next review action. Documentation wording, comments, formatting, cosmetic
  edits, semantically unchanged generated output, and straightforward test
  expansion that only locks reviewed behavior need focused validation and
  direct finding readback, not reviewer redispatch. One materially changed
  correctness boundary needs a targeted follow-up on that boundary and fix
  delta. A multi-domain or global invalidation may justify a broad follow-up.
  Before the third broad round overall, run the production-ready scope circuit
  breaker, author self-audit, and validation before deciding whether another
  broad review is necessary. Do not use an exact-SHA change, objective revision,
  or mechanism scope revision as an automatic redispatch trigger. Resolve every
  accepted or actionable finding through the proportionate path above. Do
  not mark the native reviewer subagent unavailable or skip it as `Pending
  Verification`; if the runtime cannot invoke its native reviewer, stop and
  report the workflow/tooling blocker before the first push or PR creation.
- Apply the author self-review's database applicability packet before the first
  push or PR creation. When it is `required`, complete any material parent-owned
  environment preflight and dispatch `database-reviewer`; when environment
  context is `neither`, record why and dispatch immediately. The parent blocks
  publication until the database verdict returns. Do not replace this sibling
  with the ordinary reviewer, Codex review helper, CI, a user opt-out, or an
  unavailable-runtime note.
- The independent reviewer subagent and the Codex review helper are two
  different pre-open gates. Do not substitute one for the other. The reviewer
  subagent gives an ordinary reviewer perspective over the branch and changed
  files; the Codex helper gives a separate high static review. A first-time PR
  may be opened only after both gates have passed with no accepted or
  actionable findings. Only an external human or council reviewer can be marked
  unavailable as `Pending Verification`; do not apply that allowance to the
  native reviewer subagent or Codex review helper.
- Do not confuse these review surfaces:
  - Native reviewer subagent: invoke the runtime's `reviewer` agent directly
    when the native multi-agent tool exists. This is the required independent
    reviewer gate.
  - Codex review helper: resolve `references/scripts/codex-review` from the
    active runtime's loaded `work-orchestration` skill directory, verify
    that exact executable with `--help`, then invoke it with the publication
    worktree as the current directory and pass
    `--mode branch --base origin/main`. This is a separate high static review
    gate.
  - Repo wrappers such as `scripts/dev/agent-call-codex.sh` or cross-harness
    scripts: use them for external harness collaboration, scripted Codex
    review requests, or explicit fallback only. They are not the native
    reviewer subagent when a native subagent tool is available.
- The Codex review helper is owned by `work-orchestration`, not by
  `reviewer` or `pr-workflow`. Never derive its location from the
  current reference file and never search for a guessed copy under either
  non-owner skill. If the loaded orchestration skill's exact helper path is
  missing or its `--help` check fails, stop and report the helper-availability
  blocker instead of trying nearby skill directories or ad hoc wrappers.
- Before opening any PR from a publication worktree, require the worktree branch
  to be up to date with `origin/main`, then run the verified orchestration-owned
  helper with `--mode branch --base origin/main` while the publication worktree
  is the current directory. The helper runs Codex review with high reasoning.
  Intentional runtime divergence: Codex owns this helper and the Luna-specific
  scout lane; other mirrors may reference the repo's Codex helper without
  carrying the Luna lane themselves.
  Treat accepted or actionable Codex review comments as a blocking pre-open
  gate: fix them and rerun focused validation. Rerun Codex review only when the
  fix changes the reviewed behavior or reasoning contract; do not rerun it for
  bounded documentation, cosmetic, or review-requested regression-test-only
  changes that preserve the reviewed implementation. Open the PR only after
  the branch still targets current `origin/main` and every finding is fixed or
  consciously rejected with evidence.
- Before choosing amend, squash, rebase, or a new commit for review fixes,
  inspect the active review provenance. If a human reviewer or an internal
  reviewer must inspect a finding-directed fix, preserve `H0` and publish one
  new ancestral fix commit or exact range. Do not rewrite that boundary while
  scoped re-review is planned, queued, running, or unresolved. The narrow
  Copilot-only amend exception applies only when no human baseline changed, no
  scoped internal review is required, and no immutable reviewed target must be
  preserved. Uncertainty selects a new commit.
- Finding-directed commits created during pre-open review are temporary review
  provenance, not the public PR topology. After every required pre-open
  reviewer is terminal and every accepted finding is resolved, squash the
  complete branch range over its intended base to exactly one commit before the
  first push and before PR creation. For a stacked PR, count relative to its
  intended parent branch, not `main`.
- Record the reviewed pre-squash head, perform the history-only squash, and
  prove `git diff --quiet <reviewed-head>..HEAD` plus
  `git rev-list --count <base>..HEAD = 1`. A tree-equivalent squash does not
  require reviewer redispatch solely because the commit SHA changed. Rerun
  commit-message or history-sensitive checks, then proceed to push and PR
  creation. If tree equivalence fails or the count is not exactly one, stop:
  the publication branch is not ready.
- Never open a new PR with multiple commits because review fixes were recorded
  separately. The temporary commit ledger may remain in local notes or review
  artifacts; GitHub must receive one cohesive commit for the PR.
- Build the PR body from `references/pr-template-guide.md` instead of
  freehanding it. Do not use the root `pull_request_template.md` as a template
  source for example-app PRs; it is obsolete and lower quality than this
  repo-owned guide. If GitHub pre-populates that template, replace it with the
  structure from `references/pr-template-guide.md`.
- Treat GitHub tools as mutation mechanisms, not PR-body authors. Before any
  `gh pr create`, `gh pr edit`, PR title/body MCP mutation, or equivalent
  operation, prepare the title/body through this lane and
  `references/pr-template-guide.md`.
- Before the first PR create/edit mutation, run a local PR-body contract check
  against the exact draft that will be written. Do not open or update the PR
  until the draft has the exact template headings: `## Description`,
  `### What?`, `### Why?`, `## Reviewer guide`,
  `### Understanding guide`, `## Dependencies`,
  `## Risks and impact (What is the risk level of the changes and why?)`,
  `Rollback:`, `## Verification`, and `**Link to Jira issue:**`. Include
  `## Operator notes` when the guide requires it. If the draft uses freeform
  alternatives such as `## What changed`, `## Why`, or `## Risk and impact`,
  stop and rewrite it before calling GitHub.
- PR titles must describe the current implementation stage, not the final
  program goal unless this PR actually completes that goal. For phased,
  gated, preparatory, stacked, or bridge changes, use verbs such as `prepare`,
  `add`, `validate`, or `gate` instead of implying a full ownership or rollout
  cutover.
- When opening or updating a PR body, include the guide's `Reviewer guide`
  section for every non-trivial PR.
- Keep the PR body in sync with the actual diff. Whenever the commit range
  changes through a new commit, amend, rebase, or squash, re-derive the
  changed-surface list and verification scope from
  `git diff --name-only <base>...HEAD`. The `What?`, `Reviewer guide`, and
  `Verification` sections must match the current changed-file set; never leave a
  stale file list or stale validation wording after pushing more changes.
- Treat the live diff and live evidence as the only source for reviewer-facing
  PR body updates. Do not inherit old head SHAs, stale green runs, transient
  failure investigations, local branch details, or intermediate discarded fixes
  from the previous body. Preserve only proof that is still true for the
  current head, or label older proof as historical and clearly separate it from
  current-head verification.
- When a PR adds or edits ADRs, run a branch-local publication check before
  pushing: ADR numbering must match the target branch sequence, not a
  local-dev-only sequence; publishable ADRs must not say they are local-only;
  references to ADRs or docs absent from the target branch must be removed,
  linked to an external source, or marked as a separate pending decision; and
  the ADR status/checklist must match the PR's current rollout stage.
- After a current-head CI or workflow rerun, replace stale pending, failed, or
  historical verification blocks that describe the same gate. Do not append new
  green evidence while leaving older text that still says the gate is pending
  or only verified on an older head.
- After any squash, amend, rebase, or force-push, treat previous workflow runs,
  review-thread references, and PR-body SHA/status fields as stale leads until
  they are verified against the live head SHA or an explicitly proven
  tree-equivalent rewrite. Re-read the live PR metadata before closeout.
- Treat PR publication as incomplete until reviewer-facing metadata and
  current-head CI state are both handled. Do not come back immediately after
  creating the PR just because the URL exists. Inspect current-head CI and keep
  ownership until required checks pass, fail and are being fixed, or are
  blocked by an explicit external condition, unless the user explicitly asked
  for link-only publication or said not to wait for CI.
- Treat external-provider, environment, database, runtime, staging, production,
  and Terraform evidence as separate from local validation and GitHub check
  state. A local command or green GitHub check can support the PR, but it does
  not prove a provider plan, remote state, database metadata, deployed revision,
  or runtime behavior unless that exact artifact was inspected. Put missing
  external proof under `Pending Verification` with the artifact needed to clear
  it.
- For stacked infrastructure PRs, remember that Terraform Cloud and
  SAST/security provider checks can be base-gated and may run only after the PR
  targets `main`. When a parent merges and GitHub retargets the child to
  `main`, re-read the new current-head provider checks before saying the child
  PR is green or ready. If provider details require Okta and are inaccessible
  through GitHub auth, report that as `Pending Verification` and ask the user
  for provider logs, screenshots, exported artifacts, or, for Terraform state
  evidence, stop the state-dependent work until the user supplies a manually
  downloaded local state file path.
- If the user gave a larger publication or review-closeout workflow, the PR URL,
  PR-body update, branch push, or green CI is only one phase. Keep a visible
  phase ledger and finish every named gate before handoff: local validation,
  metadata refresh, council or sidecar review, requested Copilot or reviewer
  pass, thread reply/resolution, current-head CI, and final live-state readback.
  Do not replace a requested reviewer gate with a CI status statement, and do
  not call the PR ready while any requested phase remains pending.
- Treat "request Copilot review" and "request one more Copilot review" as a
  full review-gate request, not a request-only mutation, unless the user
  explicitly says to only send the request. The publication lane remains open
  until Copilot finishes for the current head, review objects and GraphQL
  threads are fetched, actionable comments are fixed, eligible bot threads are
  replied to and resolved, any required push is followed by green current-head
  CI, and the final live PR/thread/check readback is complete.
- Copilot and GitHub CI may run in parallel only after the exact PR head has
  passed every applicable deterministic local PR-triggered gate selected by
  this lane or the PR local-CI lane. Strong local confidence means evidence
  from the exact worktree, branch, and commit being pushed, not an older head,
  partial lint, or a likely-green assumption. When overlap is allowed, keep two
  independent ledger gates open: `current-head GitHub CI` and `current-head
  Copilot review/thread state`. Handoff is blocked until both are terminal and
  clean for the same head: required GitHub CI is green, Copilot workflow or
  review state is terminal, review objects and GraphQL threads were inspected,
  no actionable current-head Copilot comments remain unresolved, and the live
  PR/thread/check state was reread after the last mutation.
- Rebuild the phase ledger when the user corrects the workflow, the PR base
  changes, a parent PR merges, a reviewer leaves new comments, or a push
  rewrites the head. The new ledger must preserve unfinished gates from the
  user's latest instructions unless the user explicitly cancels them.
- When the user asks to open a PR and explicitly says work will resume after
  the PR exists, do not wait indefinitely on CI. Create the PR, read back the
  live title/body/base/head/head SHA, do one current-head CI inventory pass, and
  report the exact pending/running checks without calling the PR ready or green.
- For long-running current-head CI or other read-only wait loops, use Luna
  when available as a bounded monitor. Give Luna the PR number, live head SHA,
  expected checks or states, unexpected states to report, allowed read-only
  evidence sources, and stop conditions. Luna reports observations only; the
  parent owns GitHub reads that require credentials, log interpretation, fixes,
  PR-body updates, reruns, and final status wording.
- Internal review confidence comes from the authoring preflight, exact-head
  deterministic local checks, native reviewer, and Codex review helper.
  Copilot and other paid or slow AI reviewers are optional external escape
  audits, not substitutes for those gates and not missing proof when they were
  neither requested nor started. Do not request Copilot for reassurance or to
  make an internally incomplete review look complete.
  For PRs whose base is `main`, repo settings may request the first Copilot
  review automatically, so do not manually duplicate that pass. When an
  automatic, user-requested, or workflow-required pass starts, keep its
  review/thread state open through final handoff, monitor it alongside GitHub
  CI after exact-head local gates pass, and handle every actionable comment.
  Do not request or rerun Copilot merely because a small fix, PR-body refresh,
  thread reply, or intermediate POC change landed. Request it manually only
  when the user explicitly asks or a loaded workflow makes it required for the
  current head. An absent optional pass is neither a blocker nor `Pending
  Verification`.
  When a manual Copilot request is allowed, route the GitHub mutation through
  `github-workflow` and its Request Copilot Review section. Do not use
  `gh pr review` for this purpose; it posts a submitted author review comment
  and creates public PR noise that cannot be deleted like a pending review.
  Luna may monitor and report review/action state, but the parent must fetch
  review comments, decide whether they are real, make fixes, and re-enter CI
  monitoring for the new head.
- When a final Copilot or reviewer pass leaves inline comments, the closeout is
  not satisfied by a PR-level review comment or issue comment with the same
  text. Reply on the exact inline thread, resolve only eligible bot threads,
  then re-read the review-thread surface and confirm the reply is attached to
  that thread before waiting on current-head CI.
- Do not parallelize inline-thread reply and resolution mutations. The required
  order is: post the thread-specific author reply, re-read that exact thread
  to confirm the reply landed, resolve the eligible bot thread, then re-read
  the thread state. If the reply mutation fails after a resolve mutation,
  repair the thread state before closeout instead of treating the resolve as
  sufficient.
- If a final Copilot or reviewer pass leaves a valid comment that causes a code
  change, the pass is no longer evidence for the new pushed head. After the fix
  is pushed, wait for current-head CI and decide whether the explicit user
  request or reviewer-request cap requires another current-head pass. If another
  pass is required but cannot be run, report that as `Pending Verification`;
  do not call the PR final-review-clean.
- Do not automatically rerun expensive AI reviewers after every post-open
  review-comment fix. First classify the fix. If it is simple, local, and
  mechanically bounded, such as documentation text, typos, local comments or
  help text, a trivial guard reorder, or an obvious early return, reply to the
  thread, resolve eligible bot comments, run focused validation, and wait for
  current-head CI without calling the native reviewer subagent or Codex review
  helper again. Rerun the appropriate reviewer gate when the fix changes
  behavior, SQL, auth, data, infra, concurrency, error handling, public
  contracts, tests, operator workflow, or when the reviewer comment requires a
  design judgment. First-open reviewer and Codex gates remain non-negotiable.
- For PR publication closeout, current-head CI evidence and parent-owned live
  judgment remain mandatory; Luna does not. Use `delegation` before assigning
  CI inventory or monitoring to Luna. If the approved packet selects Luna,
  record its scope, live head SHA, timeout or stop condition, and result. If
  optional Luna fails and retry overhead erases the benefit, take over the
  evidence read in the parent rather than blocking closeout on worker choice.
- Ask for an additional AI review only when the change is complex enough that
  the extra paid or slow pass is likely to catch material risk, when the PR has
  reached the final review gate, or when the user explicitly asks for one.
- The closeout must say one of: current-head required checks passed,
  current-head checks failed and the fix/blocker was handled, or current-head
  checks are still pending because the user explicitly asked not to wait or an
  external blocker prevents completion. Do not use completion, ready, green, or
  fixed language while current-head checks are queued or running.
- Treat PR closeout as a three-surface proof, not a single green signal. After
  the final push, force-push, PR-body edit, thread reply or resolution,
  reviewer request, or base change, re-read all three surfaces from GitHub:
  the live PR head SHA and base, live review-thread state with zero unresolved
  bot threads regardless of outdated state, and required current-head
  checks/status contexts. If the PR is stacked and a
  lower branch changed, repeat this closeout for every rebased child PR after
  that child is pushed. Do not finish from a parent PR's green checks, a
  pre-push thread scan, or local validation from before the last mutation.
- Inspect status-context and check-run detail text, not only the top-level
  pass/fail state. If a context is marked successful but its detail text says
  a policy, advisory, security, Terraform, or external-provider subcheck failed
  non-blockingly, report it as `passed with advisory` or equivalent. Do not
  describe the PR as cleanly green while an advisory detail still needs human
  or operator acknowledgement.
- When an advisory-detail context is intentionally non-blocking, keep the
  distinction clear: current-head required checks may be passing, but the
  advisory itself remains reviewer/operator evidence. Include the context name,
  provider details URL when available, and the exact follow-up owner. Do not
  hide the advisory under a generic "all checks passed" summary.
- Before drafting a follow-up or stacked PR body, inspect the source, parent, or
  prerequisite PR that introduced the behavior or dependency and link it in
  `Why?` or `Dependencies`. If there is no such PR, write `None` instead of
  leaving the relationship implicit.
- For behavior, severity, status, exception, or config-shape changes, explain
  each changed state in reviewer-facing terms: what it means, whether it
  blocks, why it belongs in that category, and what evidence supports the
  choice. Do not rely on a before/after value list as the only explanation.
- Keep `Why?` focused on durable motivation for the final diff: the defect,
  rollout need, operational gap, or reviewer decision being addressed. Do not
  include local debugging chronology, previous wrong classifications, branch
  management details, failed attempts, or transient CI investigations unless
  that history is the product behavior under review. Put measured proof in
  `Verification` or the `Understanding guide`.
- If touched files trigger PR CI, run the matching `pr-workflow`
  local-ci lane before push or mark the exact gate `Pending Verification`. Use
  workflow-pinned tool versions when the workflow pins them; a convenient local
  binary is not proof of CI parity when versions differ.
- Treat backend, generated-code, migration, workflow, and other CI-triggering
  changes as pre-publication validation work, not post-publication cleanup.
  If a CI-equivalent local command is known and can run, run it before opening
  or updating the PR. Opening the PR first and using GitHub runner minutes to
  discover deterministic lint, formatting, generated-code, or type errors is a
  workflow failure unless the exact local gate is blocked and named as
  `Pending Verification`.
- For any PR create, PR body update, branch push, amend, squash, rebase, or
  reviewer-comment fix where the current diff includes `backend/**`, the
  backend local-ci gate is non-negotiable before the GitHub write: run the
  backend CI parity helper from the exact clean worktree and commit that will
  be pushed:

  ```bash
  scripts/dev/run-backend-ci-checks.sh <repo-root>/tmp/worktrees/<slug> --all
  ```

  Do not substitute targeted package tests, one linter command, a local build,
  or generated-source checks for this helper. If a check cannot run locally,
  stop and report the exact blocker as `Pending Verification` instead of
  opening, updating, pushing, or describing the PR as ready.

## Recommended workflow

### 1. Gather context first

1. If the user supplied a GitHub issue URL, fetch it for compliance.
2. Use GitHub issue/PR tools as the source of truth for issue metadata.
3. Confirm the source commit exists locally.
4. Fetch `origin/main` before creating the worktree.
5. If the source change was validated through the local dev environment,
   confirm that validation happened on the local validation branch, then treat the
   worktree as the publication surface for the PR.

Typical checks:

- issue title/body
- source commit SHA
- current root-checkout branch

### 2. Create the isolated worktree

Create a dedicated branch under repo `tmp/`:

```bash
git -C /path/to/repo fetch origin main --prune
git -C /path/to/repo worktree add -B <branch-name> /path/to/repo/tmp/worktrees/<branch-slug> origin/main
```

Guidance:

- Prefer descriptive branch names like `<issue-or-topic-slug>`.
- Keep the worktree disposable and self-contained.
- The standard path is `<repo-root>/tmp/worktrees/<branch-slug>`, where
  `<branch-slug>` is the branch name with `/` replaced by `-`.
- Do not create ad hoc sibling checkouts outside `<repo-root>` or hidden temp
  paths.

### 3. Run worktree readiness

After `git worktree add`, stop and run `worktree-readiness` before
cherry-picking, reading, editing, validating, committing, pushing, or opening a
PR from the new worktree. This PR-publication skill owns cherry-pick,
PR-template, and reviewer-facing behavior; the shared readiness skill owns path
policy, branch-local dependencies, Husky repair, GitHub auth fallback, and push
boundaries.

### 4. Cherry-pick the source commit

Apply the existing commit into the worktree branch:

```bash
git -C /path/to/worktree cherry-pick <sha>
```

If conflicts occur:

1. read each conflicted file in full
2. resolve in favor of the intended behavior while preserving newer `main`
   structure where possible
3. run a syntax/error pass on the edited files
4. continue the cherry-pick

If Husky blocks continuation in a fresh worktree, return to
`worktree-readiness`, repair the worktree, then rerun the real
`git cherry-pick --continue` command.

### 5. Validate from the worktree

Run focused validation for the surfaces touched by the transplanted change.

For `e2e/pd` work:

1. ensure the worktree has its own `node_modules`
2. if local env files are required for validation, copy them into the worktree
   only for the test run and do not commit them
3. when switching between staging and production validation, clean or isolate
   `.auth/`, `test-results/`, and run metadata before rerunning
4. run the narrowest meaningful Playwright coverage first

If the worktree includes `app/` code, `worktree-readiness` must already
have installed branch-local `app/node_modules`. Use the `pr-workflow` local-ci lane
for PR-triggered frontend validation before opening the PR.

Example validation pattern for an E2E/auth transplant:

- `npm run tests:auth-bootstrap`
- `npx playwright test tests/example-app/auth-session-check.spec.ts --config=e2e.config.ts --project=chromium-auth`
- targeted `smoke.spec.ts` public login-view check
- targeted `smoke-auth.spec.ts` authenticated navigation checks

### 6. Keep instruction changes out of the PR worktree

If the user asks for skills, `AGENTS.md`, `.github/copilot-instructions.md`,
`.github/instructions/**`, or other repo agent guidance updates after success,
make those edits on a dedicated instruction branch only. Do not add, cherry-pick, commit,
or push them from this PR publication worktree unless the user explicitly asks
for an instruction-only PR.

### 7. Commit the final branch state

Before committing:

- check `git status --short --branch`
- confirm only intended tracked files are staged
- exclude copied `.env` files and other local-only artifacts
- exclude `AGENTS.md`, `.github/copilot-instructions.md`,
  `.github/instructions/**`, runtime skill directories, and other agent workflow files unless this is an instruction-only PR explicitly
  requested by the user

Use conventional commit messages because this repo enforces them.

If Husky or auth blocks commit/push in a fresh worktree, return to
`worktree-readiness` and rerun the real git command after the worktree is
ready. If the branch touches PR-triggered surfaces, run the `pr-workflow` local-ci lane
before handoff or push.

### 8. Push and open the PR

Use `worktree-readiness` for the push/auth/Husky mechanics. This skill
adds PR-publication requirements: push the branch explicitly from the worktree,
then create the PR with:

- title based on the shipped change
- base branch `main`
- body follows `references/pr-template-guide.md`
- issue link in the final field
- no mention of local branch names, local filesystem paths, or worktree names

For stacked PRs, replace `main` with the immediate parent branch and list the
dependency chain plus merge order in the PR body. Keep the diff and validation
described relative to that immediate base, not the default branch.

If the stack is already open and you add a fix to a lower branch, update every
dependent PR branch before expecting its `workflow_dispatch` runs to include
the fix. For example, after changing smoke in a smoke -> regression -> visual
stack, rebase and push regression, then rebase and push visual. A green smoke
run does not prove that visual's remote branch contains the smoke fix.

### 9. Fill the PR template for reviewers

The PR body is part of the review surface. Follow
`references/pr-template-guide.md` explicitly instead of replacing it with a
freeform summary. Never substitute the root `pull_request_template.md`; it is
obsolete for our PRs, and this guide is the durable reviewer-facing contract.

Before publishing:

- Read this full skill, not only the quick command snippets.
- Read `references/pr-template-guide.md` from this skill.
- Inspect the parent PR for stacked work and 1-2 recent similar PRs to match
  actual repo title style and tone.

Title rules:

- Keep titles short and conventional, such as `fix(workflows): ...` or
  `feat(docker): ...`.
- Do not include dependency noise in the title, such as `(depends on #4518)`;
  put stacking and dependency details in `## Dependencies`.
- Do not use em dashes in PR titles, PR bodies, issue comments, or review
  replies. Use regular hyphens or rephrase.
- Follow the exact structure in `references/pr-template-guide.md`.
- Include `## Reviewer guide` for every non-trivial PR.
- Decide whether `## Operator notes` is required. Add it when the PR changes
  infra, CI/release behavior, migrations, jobs, rollout gates, Terraform,
  apply/destroy behavior, data backfills, auth/permissions, or another
  workflow where a human operator needs post-merge, pre-apply, retry, fallback,
  or "do not run this yet" guidance. Omit it for ordinary changes where Risks,
  Rollback, and Verification already cover the operator question.
- Never mention local branch names, worktree paths, `tmp/`, or internal agent
  details in reviewer-facing GitHub text.
- Never add routine green-check inventories or a `GitHub CI` status section to
  the PR body. The GitHub UI owns standard CI status. Only mention CI in the
  body when a non-visible or external gate materially changes reviewer action,
  and remove that wording as soon as it becomes stale.

Required pre-mutation check:

- The exact draft to be written contains the template headings from
  `references/pr-template-guide.md`, not remembered or freeform substitutes.
- The draft has no internal review process history, such as "pre-push review
  gate", "reviewer pass", "reviewer fix", sidecar names, or routine tool
  verdicts.
- The draft has no routine GitHub current-head check inventory. Put normal CI
  status in chat closeout evidence or leave it to the GitHub UI, not the PR
  body.
- External-provider, Terraform, runtime, staging, production, database, or
  operator proof is listed as `Pending Verification` unless that exact artifact
  was inspected.
- If any bullet fails, the next action is to repair the draft locally, not to
  create the PR and fix metadata afterward.

Use the canonical reviewer-facing shape in
`references/pr-template-guide.md`; do not copy, remember, or maintain a second
inline template here. That guide is the source of truth for required headings,
including `Out of scope:`, `### Understanding guide`, `Rollback:`,
conditional `## Operator notes`, `Pending Verification:`, and the final
`**Link to Jira issue:**` field. If this lane and the guide ever appear to
disagree, stop and update this lane to point back to the guide instead of
improvising a hybrid PR body.

Guidance:

- Keep `What?` descriptive, but put the motivation in `Why?`; reviewers should
  not need to infer the reason from changed files.
- Keep `Why?` current-state and reviewer-facing. It is not a diary of how the
  patch was developed, how CI was debugged, or which local process mistakes
  happened before the final diff.
- Add a `Reviewer guide` immediately after `Why?` for non-trivial PRs. Group
  files by review concern rather than dumping the full changed-file list.
- Call out intentional exclusions so reviewers know which follow-up PR owns
  omitted behavior.
- Keep dependencies concrete: name stacked PRs, schema prerequisites, rollout
  order, and whether the PR can land independently.
- Verification should distinguish commands actually run from expected CI or
  unrun checks. Use `Pending Verification` for important unrun checks.
- PR-body validation commands must be portable for reviewers. Use repo-relative
  paths and standard project commands only; keep absolute machine paths, local
  tool install paths, shim bypasses, shell-specific setup, and one-agent
  environment workarounds out of reviewer-facing text.
- Validation text must describe the final behavior, surface, or command that
  was checked. Do not label sections by internal process history such as a
  reviewer fix, Copilot fix, council pass, sidecar result, timeout workaround,
  or other transient event.
- Never mention a local working branch, local filesystem paths, disposable
  worktree names, gitignored files, or `tmp/` artifacts in PR bodies.
- Never mention internal agent review tools, subagent names, local review
  passes, Copilot/council/Luna process labels, or their verdicts in PR
  bodies. Convert useful evidence into reviewer-facing behavior, risk, or
  validation language.

Before any PR body write or refresh, run a hygiene scan on the draft text and
rewrite every match unless it is a deliberate product or source term:

- local paths: `/home/`, `/Users/`, `.local/share`, `mise/installs`,
  `tmp/worktrees`, local branch names, gitignored env/auth/state files
- non-portable commands: absolute binary paths, shell aliases, shim bypasses,
  local tool repair commands, machine-specific setup
- process leakage: `Copilot`, `council`, `Luna`, internal agent names,
  reviewer-verdict labels, reviewer tool names, "focused validation after ...",
  "after the reviewer fix", "after the timeout fix"
- stale status noise: routine `GitHub CI` sections, copied green check lists,
  stale pending-CI wording, stale head SHA claims, raw commit IDs not requested
  by the user

After any PR body write, read the live body back and run the same hygiene scan
against the GitHub-rendered source, not the local draft. A mutation is not
complete until the scan returns no process-leakage matches and the edited
section still has valid Markdown shape. Watch for partial-line leftovers caused
by automated replacement, especially when a removed bullet was glued to the
previous bullet.

## Validation checklist

Before opening the PR, confirm:

- [ ] worktree branch is based on `origin/main`
- [ ] source commit was cherry-picked or otherwise transplanted cleanly
- [ ] conflicts were resolved and committed
- [ ] every required pre-open review is terminal; the reviewed pre-squash head
      is recorded; the final squash is tree-equivalent; and
      `git rev-list --count <base>..HEAD` returns exactly `1`
- [ ] focused validation passed in the worktree
- [ ] every deterministic PR-triggered gate that can run locally was run from
      the exact worktree, branch, and commit being pushed, or each skipped gate
      is named as `Pending Verification` with the blocker
- [ ] worktree branch is up to date with `origin/main`, high
      `codex-review --mode branch --base origin/main` ran from the worktree,
      and accepted/actionable findings were fixed before PR creation
- [ ] independent reviewer subagent ran against the committed worktree branch
      with an unbiased prompt, and accepted/actionable findings were fixed
      before PR creation
- [ ] database review applicability is bound to the exact target; `not required`
      has an evidenced negative trace, or the required independent database
      verdict returned before first push and PR creation
- [ ] package-version and package-API claims were re-checked from the
      main-based worktree when relevant
- [ ] only intended files are staged/committed
- [ ] instruction and skill files are absent from the PR branch unless this is
      an explicitly requested instruction-only PR
- [ ] PR body follows `references/pr-template-guide.md`
- [ ] exact PR draft was checked before the GitHub mutation and contains the
      required template headings, not freeform substitutes such as
      `## What changed`, `## Why`, or `## Risk and impact`
- [ ] PR body includes `## Operator notes` when the diff changes infra,
      CI/release, migration, job, rollout, Terraform, apply/destroy, data,
      auth, permission, or other operator-gated behavior
- [ ] PR text does not mention local branch names or local filesystem paths
- [ ] PR validation commands are portable and contain no absolute tool paths,
      shim bypasses, or local environment repair details
- [ ] PR body has no routine `GitHub CI` section, green-check inventory,
      Copilot/council/Luna process labels, transient review-fix headings, or
      raw commit IDs unless explicitly requested
- [ ] live PR body was read back after the write and scanned clean for internal
      review-tool names, reviewer-process labels, and partial-line leftovers
- [ ] accepted or actionable reviewer findings were backpropagated into the
      owning `code-authoring` lane when the lane was missing or weak; if
      the lane already covered them, the authoring discipline failure was
      recorded and the handoff contract was rerun
- [ ] post-open reviewer reruns were classified: simple bounded fixes skipped
      expensive reruns with focused validation, while material/risk-changing
      fixes reran the required reviewer gate
- [ ] phase ledger has no unfinished requested gates before handoff, or each
      unfinished gate is named with its blocker as `Pending Verification`
- [ ] when Copilot and GitHub CI were overlapped, both independent gates were
      closed for the same head before handoff: required current-head CI is
      green, Copilot is terminal, review objects and GraphQL threads were
      inspected, and no actionable current-head Copilot comment remains
      unresolved
- [ ] branch is pushed before PR creation

Immediately after PR creation, read back the live commit list and require
exactly one commit relative to the intended base. If GitHub shows more than
one, publication closeout is blocked; correct the branch topology before
handoff.

## Do and do not

### Do

- preserve unrelated root-checkout work
- validate in the worktree before pushing
- preserve finding-directed commits while pre-open review is active, then
  squash the complete reviewed branch to one tree-equivalent commit before
  first push and PR creation
- run deterministic CI-equivalent gates locally before spending GitHub runner
  minutes
- re-check dependency/package-version claims from the main-based worktree before
  opening the PR
- use GitHub tools for issue/PR metadata
- leave skills, instruction files, and workflow gotcha documentation on
  a local working branch

### Do not

- open the PR from a dirty root checkout when the user asked for isolation
- open a new PR with more than one commit
- commit copied `.env` files
- commit `AGENTS.md`, `.github/copilot-instructions.md`,
  `.github/instructions/**`, runtime skill directories, or other agent workflow files from a feature/PR publication worktree
- ignore Husky/worktree failures and assume the code is broken
- rely on GitHub CI as the first run of a known local linter, formatter,
  generator, typecheck, or test gate
- claim validation succeeded unless the commands actually passed
- base the PR on an unrelated local branch or describe local-only package versions
  as if they were the PR branch truth
- mention local branch names or local filesystem paths in the PR body
- mention local worktree/tooling repair details in the PR body, such as Husky
  bootstrap or repair, nvm/mise prefix workarounds, branch-local dependency
  install issues, fresh-worktree setup failures, or replacing a shimmed command
  with an absolute binary path
- mention Copilot, council sessions, Luna, sidecar scouting, reviewer verdict
  labels, or internal review process history in the PR body
- add a routine GitHub CI section, copied check list, stale pending-CI note, or
  current-head status prose that the GitHub UI already displays
- improvise the PR body when the repo already has a template
