<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (same-response review comments and canonical conventions) -->

# PR, Stack, Follow-Up, And Thread Lens

Use this lens for example-app GitHub PR reviews, stacked PRs, follow-up
patches, PR body/title checks, unresolved review comments, prior review
artifacts, CI/check freshness, closeout, and variance-ledger work.

For PR reviews routed through `pr-workflow`, this lens is mandatory
even when the changed files are single-domain.

## Review Order

1. Verify or receive the stable PR head SHA and base used for code evidence.
2. Establish whether the review is cumulative, stack delta, single commit,
   follow-up patch, or replacement candidate.
3. Read changed files from the local worktree at the same head SHA used for code
   evidence.
4. Refresh or verify PR body/title, checks, and review threads when tooling is
   available.
5. Map prior comments and supplied outputs to current code before trusting them.
6. Emit a verdict tied to one consistent target.

## Freshness And Target Facts

For live PRs, refresh or verify when tooling is available:

- head SHA
- base branch and merge base
- changed-file inventory
- PR title/body/reviewer guide
- current check runs/statuses for the current head
- unresolved review threads and inline comments
- whether the diff is cumulative or stack delta
- whether another agent is still editing the target

State unavailable non-central freshness facts as `Pending Verification`. Use
`BLOCKED` when missing head, base, stack, or freshness evidence controls verdict
safety.

All code inspection, thread mapping, status evidence, and current-code artifacts
presented in the packet must come from one consistent live head SHA. If the head
changes, refetch, recompute lens selection, and restart the central review before
claiming `PASS` or `PASS_WITH_FINDINGS`.

## Target Matching

Dirty local work, staged diffs, branch diffs, PR diffs, stack deltas, and single
commits answer different questions.

- If the parent asked for staged, review staged evidence.
- If the parent asked for a PR, review the PR worktree at pinned head.
- If the parent asked for stack delta, do not silently review the whole branch.
- If the parent names a branch, local worktree, ref, or comparison range, verify
  the checkout and diff base match that target before review. A branch-name
  mismatch is a target mismatch, not a harmless label typo, when it can change
  the reviewed files or verdict.
- If the target is a follow-up patch, classify prior accepted findings before
  looking for unrelated new issues.
- Flag target mismatch when it can hide the shipped change or make the verdict
  misleading.

## Linked Change And Active-Flow Reachability

Before assigning severity to a finding whose impact depends on a flow being
active, prove both the code path and the route that reaches it. A handler,
callback, branch, or input shape still existing in source proves capability;
it does not prove that the ordinary product flow, production default, or named
consumer still uses it.

When the PR body, user, review thread, or source names a predecessor,
replacement, superseding change, migration, or dependent PR that affects the
flow:

1. Read the linked change as stated intent, then verify its relationship with
   current ancestry, containment, base/head, or equivalent repository evidence.
2. Trace current callers, routes, flags, config, and environment selection from
   the reviewed target to the behavior. Do not infer reachability from the
   linked description or an obsolete caller alone.
3. Separate affected consumers. A reachable compatibility path for one caller
   does not prove that another migrated caller is still exposed.
4. Calibrate severity from the narrowest currently reachable impact. Reserve
   blocking or production-regression language for a default or deployed path
   proven by current evidence; otherwise downgrade, reject, or mark the exact
   reachability fact `Pending Verification`.

A user correction that names new dependency or migration context is evidence to
verify, not an instruction to defend or retract a finding automatically. If the
verified correction changes the reachability map, invalidate the dependent
candidate, recompute its impact and severity, and repeat any affected packet or
GitHub-comment preparation before emitting or posting it.

## PR Body, Title, And Reviewer Guide Drift

Compare PR prose to the actual diff. Flag drift that could mislead:

- review scope or changed files
- scope claims that describe one component, route, infra object, or behavior
  while the diff also changes shared components, global defaults, unrelated UI
  copy, runtime config, provider constraints, or environment defaults
- user-visible behavior and acceptance criteria
- validation already run or intentionally omitted
- rollout, migration, operator, or rollback steps
- release notes, QA handoff, or stakeholder expectations
- generated files and source-of-truth locations
- dependency, infra, or permission changes
- exact config values, timeout values, feature-flag states, run IDs, and pending
  verification items after each push or force-push

Harmless wording drift is secondary. Stale guidance that can steer review,
merge, QA, rollout, or future maintenance is a formal finding or `Pending
Verification` item when evidence is incomplete.

## Review Threads And Prior Comments

Treat prior comments, review summaries, unresolved threads, issue comments,
Copilot, Claude, Clawpatch, council output, and tool summaries as leads until
verified against current code, callers, tests, config, CI, or requirements.

Open and closed threads both count. Multi-reviewer activity (humans, bots, or
both) is a dig-deeper signal, not proof that coverage is already complete.
Act as the last reviewer available: no better reviewer is assumed to follow.

### Prior-Comment Adversarial Pass

When any review threads, review summaries, or material issue comments exist for
the target, run this pass before Independent Residual Pass.

**Material** (same law as `reviewer`): could affect correctness, data,
security, deployability, operator truth, public API/UX contract, test validity,
or the reviewer verdict. Otherwise ledger-only, advisory, or nit. Soft labels
like "nit" do not demote a material concern without current impact evidence.

For each material prior comment or thread root:

1. Map to current head, path, symbol, and still-reachable behavior.
2. Challenge the comment itself, not only whether the author replied:
   - still valid and reachable at current head?
   - invalid, wrong, or based on a misread of the contract?
   - indirect (symptom only) while a deeper root cause remains?
   - incomplete fix (author claimed fixed, but root path still fails)?
   - out of scope, nit, or duplicate of another root cause?
3. Challenge author "fixed" / "addressed" replies with current-code artifacts.
   Thread resolution UI, emoji, age, hunk movement, and collapsed state are not
   proof of fix.
4. Record disposition in the variance ledger with a current-code artifact:
   `concern_remains_open`, `fixed_with_artifact`, `invalid_or_wrong`,
   `indirect_incomplete`, `out_of_scope`, `stale`, `duplicated`, or
   `pending_verification`.
5. Promote still-valid concerns that survive this challenge into formal findings
   when they meet the reviewer core standard. Reject or ledger-only invalid
   comments; do not restate them as if they were confirmed.

Do not stop at open threads. Closed or outdated threads can hide incomplete
fixes or wrong resolutions. Do not auto-resolve human threads; humans own
their threads, but the reviewer still judges code truth for the verdict.

When fetched review objects or inline comments are used in COUNCIL or contested
contexts, summarize disposition in the variance ledger. Do not write `Variance
ledger: N/A` after relying on those artifacts.

## Variance Ledger Discipline

Use a variance ledger when aggregating supplied critic/reviewer/Clawpatch/Copilot
/council output or contested prior findings.

For each material external claim, record:

- source label
- claim summary
- current-code artifact checked
- disposition: verified, rejected, stale, duplicated, unresolved, out of scope,
  or `Pending Verification`
- whether it affects the verdict

Highest-risk disagreement gets checked first. Do not group unrelated material
claims under "same as above" language when the parent needs traceability.

## Follow-Up Patch Rules

For follow-up patches:

- First classify each prior accepted finding as resolved, unresolved, out of
  scope with evidence, or superseded.
- When the parent asks to fix a finding from the current review, reread the
  exact finding after editing and run a focused self-review against the changed
  target before handoff. A formatter pass or lint-clean result does not prove
  the finding's root cause is fixed.
- Verify the root cause, not only the visible symptom, lint error, failing test,
  or review wording.
- If the fix changes code, generated files, migration, workflow, or tests,
  require focused validation of the changed surface.
- Add new findings only when the follow-up creates new material risk or reveals
  a previously hidden central issue.
- If a patch only silences a test or comment while leaving the root failure path
  intact, that is a high-value finding.

## Stack And Multi-PR Work

- State stack parent/base and whether the review includes upstream stack changes.
- Verify that unchanged upstream stack code is not blamed for a delta-only PR
  unless it makes the delta unsafe.
- For dependent PRs, old/new compatibility across stack landing order matters.
- For stacked production-risk PRs, separate cumulative risk, stack-delta risk,
  inherited unresolved gates, and whether the child depends on parent safety
  proof. A child PR must not receive PASS or PASS_WITH_FINDINGS when it relies
  on an unresolved parent P0/P1 or central Risk Evidence Handoff.
- A green check on the whole branch may not prove the stack delta if the changed
  behavior is hidden by upstream modifications.
- If stacked context is unavailable and controls correctness, use `BLOCKED` or
  request the exact base/head evidence.

## Checks, Statuses, And CI Freshness

- Current checks are evidence only for the commit, workflow, event, filters,
  environment, and artifacts they actually ran.
- Prefer authenticated CLI/API or supplied source-of-truth evidence over rendered
  HTML for head/check/thread state.
- Stale checks, skipped jobs, path filters, wrong base, reruns from old commits,
  and `continue-on-error` need explicit treatment when validation is central.
- Do not invent check URLs, names, or results. If a URL or check result affects
  the verdict and cannot be verified, mark it `Pending Verification` or
  `BLOCKED` according to risk.

## GitHub-Facing Comment Hygiene

- Emit GitHub-facing comments only when parent asks for them.
- Before drafting GitHub-facing comments, read `agent-personality` and
  apply only this lens's inline review-comment subset: tact, clarity,
  independent judgment, concise rationale, and constructive fix shape. The
  personality skill supplies the external-reply carve-out; do not use humor,
  persona flourishes, broad teaching, or conversational padding in review
  comments.
- Use concise Conventional Comments anchored to the narrowest file, line, symbol,
  route, workflow, or contract that proves the issue.
- Include severity, why it matters, and fix shape; keep packet, verdict,
  freshness notes, and residual risk in the parent summary.
- Do not post thread resolution instructions, quality scores, fake metrics, broad
  rewrites, or speculative nits.
- Do not duplicate one root cause across many inline comments.
- Format every GitHub-facing comment per `docs/agents/pr-comment-conventions.md`,
  which owns the backticked label, its mandatory blocking decoration, the
  required labeled parts, and the forbidden-content list. That file is mandatory
  whenever the output contract includes conditional review comments, so it applies
  even when this lens is not loaded.
- Wrap file paths, identifiers, config keys, and short snippets in backticks,
  and put multi-line snippets in a fenced code block, so each renders as a
  distinct unit instead of disappearing into prose.
- Hold updates and replies to the same readability bar: prefer several short
  scannable blocks over a single long paragraph, even when the comment is
  intentionally detailed.

## Closeout And Merge Readiness

Before passing a PR review, verify or state residual gaps for:

- stable head/base and lens set
- selected changed files and coverage limits
- current material review threads
- current checks or explicit validation evidence
- generated/source-of-truth integrity
- PR body/title drift
- prior accepted findings for follow-up work
- material `Pending Verification` items and smallest evidence that would flip
  the verdict

Thread inventory is not residual search. Sequence when threads exist:

1. Prior-Comment Adversarial Pass (this lens): challenge open and closed
   comments; verify author fixes; classify dispositions with artifacts.
2. Independent Residual Pass (`reviewer`): assume material still-valid
   prior concerns are fixed, then hunt remaining broken contracts; file new
   findings or empty proof with named probes.

Confirming, restating, or bulk-agreeing with prior comments must not become the
entire verdict. Multi-reviewer comment volume does not reduce the residual bar.

If a required Prior-Comment Adversarial Pass or Independent Residual Pass is
missing (packet only restates open threads, trusts author "fixed" claims
without artifacts, or skips residual empty-proof), treat that as a **reviewer
packet defect**: reject or repair the packet under the `reviewer` Review
Packet Acceptance Gate. Do not emit a formal P0-P3 finding against the PR for
that process gap.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- reviewer inspected the wrong target, stale head, wrong base, or wrong stack
  delta
- PR body/title/reviewer guide materially misleads validation, rollout, or scope
- prior accepted finding remains unresolved despite claimed follow-up
- old review thread is treated as resolved without current-code mapping
- CI/check evidence is stale, wrong target, skipped, or cannot exercise central
  behavior
- supplied external review output is accepted without verifying the highest-risk
  claim
- child PR passes while a parent production-safety gate it depends on remains
  unresolved or unproved
