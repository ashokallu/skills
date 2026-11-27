<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-24 (critical shared mutation autonomy boundary) -->

# Completion Claim Gate

```text
Type: companion contract
Use when: any owner about to say done, fixed, ready, green, pushed, updated,
          review-clean, deployed, verified, or all set
Skip when: the response makes no material completion/readiness claim
Owns: claim-to-current-evidence check and precise final wording
Does not own: missing implementation, validation, review, publication, or operational
              work
Allowed side effects: none; it may request a separately routed read-only refresh
Inputs: candidate claims, exact target, current evidence, side effects, and gaps
Exit states: claim allowed, narrow claim, Pending Verification, blocked
Outputs: atomic claims with evidence and unresolved gaps
Re-enter when: target, evidence, side effects, or claim wording changes
```

Do not weaken a broad claim to hide missing proof. Split it into smaller true
claims and name the remainder `Pending Verification`.

## Claim Taxonomy

Treat each state independently:

1. **Located/understood** — relevant target/evidence identified.
2. **Changed locally** — intended files modified; no claim about validation.
3. **Validated locally** — named checks passed on the exact checkout/target.
4. **Reviewed** — required reviewer(s) produced current-target verdicts.
5. **Committed** — local git object exists and status/head readback supports it.
6. **Pushed** — remote ref contains the intended commit.
7. **Published/metadata updated** — live PR/resource metadata reflects the
   intended content.
8. **Current-head CI green** — required checks passed for the live head.
9. **Review/thread clean** — required current-target comments/threads are
   inspected and actionable items handled under policy.
10. **Deployed** — live environment runs the intended revision/config.
11. **Verified live** — selected runtime/regression evidence proves behavior.

Never use one state as shorthand for another. A merge is not a deploy; a tag is
not live behavior; a push is not green CI; local tests are not review-clean.

## Universal Gate

Before any completion wording:

- compare the active phase’s success evidence with evidence actually collected;
- verify target identity and freshness (path/branch/head SHA/PR/run/environment/
  resource/version);
- confirm side effects stayed within authorization;
- when a task autonomy envelope was active, compare performed actions against
  both their phase-specific authority and the final envelope version, and
  reconcile every `PRELIMINARY`, `APPROVAL REQUIRED`, confirmation or standing
  authority binding, capability/action row, checkpoint, version change, and
  stop condition; first confirm the envelope was activated only for actions
  satisfying the critical-target plus direct/predictable-mutation predicate;
  when recovery occurred, prove it was predeclared, stayed inside the exact
  approved resource/action sets and ceilings, followed state readback and the
  one-retry limit, and reran every invalidated gate;
- check material assumptions and invalidate dependent proof when false/stale;
- confirm every triggered mandatory gate either completed or is named
  `Pending Verification`/blocked;
- confirm scope and changed-file/resource inventory match the accepted outcome;
- join and verify required delegated work;
- state unresolved risks, skipped checks, blockers, and rollback state plainly.

Use `evidence-and-verification-ledger` for high-risk, disputed, external,
release, PR, or broad readiness claims.

For code-authoring, reviewer, PR publication, or substantial repo-work handoff,
scan the index in `docs/agents/agent-violation-examples.md` and read every complete example that matches the task,
artifacts, gates, or response shape. Read the whole document through EOF for violation correction,
instruction audits, or when matching scope cannot be narrowed. If the required
examples cannot be read, keep closeout `Pending Verification`.

Completion closeout should verify prior instruction/case-study gates; it should
not introduce a new broad document-reading ceremony. Read violation examples or
instruction audits here only when the selected workflow explicitly required
that artifact and it was not yet satisfied, or when correcting a known process
violation.

## Claim-Specific Proof

### Local Change

- current relevant diff and file inventory;
- intended generated artifacts included;
- unrelated dirty work preserved and not claimed;
- structured/format-sensitive files reopened and visually checked;
- parser/formatter/linter run when available, or exact gap named.

### Local Validation

Record command, working directory, exact checkout/head, environment/prereqs,
exit/result, and material output. A result from another worktree/commit is stale.

Use the specialist’s canonical local CI parity gate when one exists. For
backend changes in this repository, ordinary `go test`, `go build`, generation,
lint, or diff checks alone do not replace the documented backend local-CI helper
when that helper is required by `pr-workflow`/`code-authoring`.

### Commit / Branch State

Immediately before the response, inspect current status, head, and relevant
history. For remote sync compare local and remote refs. When history rewrite was
possible, inspect reflog/history evidence and state it; never deny an amend,
reset, rebase, or force-push without proof.

### Push / Remote Mutation

Read back the actual remote branch/resource after mutation. The local command’s
success message alone is insufficient. For Jira/Confluence/GitHub/cloud/other
systems, verify the exact resource ID/version/content/state the mutation was
meant to change.

### PR Publication / Metadata

After any push, rebase, amend, squash, or PR-body update, refresh:

- live PR number/base/head SHA;
- title/body and changed files;
- current-head required checks;
- relevant review objects and threads.

Ensure reviewer-facing text contains no stale SHAs, outdated validation, old
file lists, local paths/tool leakage, obsolete pending-CI wording, or stale
thread status.

### CI

A pushed PR is not green when required checks are pending, queued, missing,
stale-head, skipped without accepted explanation, failing, or uninspected.
Report exact current-head state. If the session cannot autonomously continue
monitoring, use a parked wait outcome rather than implying future completion.

### Reviewer / Copilot / Threads

- use the owning PR/review workflow’s required gates for the current target;
- inspect live inline thread state after the last push and after any reply or
  resolution mutation;
- do not infer thread-clean state from issue comments or review summaries;
- never auto-resolve human reviewer threads;
- bot/Copilot threads may be resolved only under the owning workflow after a
  verified fix or supported non-actionable classification and required reply;
- a code-changing review fix invalidates stale CI/review evidence for the old
  head and may require targeted/current-target review refresh.

A request to “request Copilot review” is complete only at the request boundary
unless the owning workflow/user explicitly requires the full terminal review,
thread handling, and current-head CI cycle. State which boundary was requested
and proved; do not silently expand or truncate it.

### Release / Deployment / Live Verification

Keep these claims separate:

- commit included in release;
- release/manual deploy present in environment;
- live service/job uses intended image/config/traffic;
- selected behavior verified with bounded runtime evidence.

Use `release-regression-validation` for live product proof and
`release-terraform-plan-analysis` for pre-apply release/plan advice. Terraform
plan output is not post-apply live proof.

### Review Result

A review request closes with a verdict-shaped response: findings with evidence,
or an explicit no-findings statement plus `Pending Verification`. Worktree setup,
file inventory, lens selection, or CI snapshot alone is not a review result
unless the user requested only setup/status.

### Handoff / Continuity

Verify the packet’s target IDs, next action, side-effect boundary, blockers,
active operations, and `Pending Verification` against current state. A handoff
is not complete when it points at stale branches, PR heads, or already-resolved
blockers.

## Ordered Workflows

When the user gave an ordered workflow or “you know the drill,” compare the
result against every explicitly requested gate. Do not substitute one success
surface for another. If a known required next step remains inside the active
scope, continue it or state the exact blocker; do not ask “what next?”

## Claim Wording

Prefer:

```text
Changed locally: <files/outcome>
Validated: <commands/results>
Committed: <sha>
Pushed: <remote ref/readback>
PR/current-head state: <metadata/checks/reviews>
Deployment/live proof: <revision/evidence>
Pending Verification: <exact gaps>
```

Avoid umbrella phrases such as “all good,” “fully done,” or “ready” unless all
implied states are proven.

Never claim `READY FOR AUTOPILOT` from confidence or a completed preflight.
Name the envelope version and prove its action authorities, prerequisites,
owning gates, rollback terms, stop conditions, and terminal-observation
capability. For a qualifying critical mutation, also prove every planned action
has a complete current capability row and the unchanged envelope is
`confirmed` or has verified `standing-authority`. Do not require or reconstruct
an autonomy packet for routine Git, GitHub, issue/document, test-only CI, read,
wait, or polling actions whose critical mutation effect was `none`.
`APPROVAL REQUIRED` is not autopilot readiness. If an upward delta was
discovered but not versioned and re-gated, or required monitoring cannot be
consumed by the current runtime, narrow the claim and mark the missing proof
`Pending Verification`.

For a stable confirmed version, repeated approval holds are a workflow defect.
A corrected derived count with unchanged authoritative enumerations and a
predeclared bounded recovery do not justify another hold. A later approval is
valid only for a new envelope version caused by material expansion,
denial/reconsideration, or ambiguous prior authority.

## Output

```text
Completion decision: ALLOW | NARROW | PENDING VERIFICATION | BLOCKED
Atomic claims allowed:
Current target identity:
Evidence for each claim:
Claims not allowed and why:
Remaining risks/rollback:
Pending Verification:
```
