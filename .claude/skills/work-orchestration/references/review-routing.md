<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (single review-owner decision tree) -->

# Review Routing

```text
Type: decision gate
Use when: a review/verdict/readiness/comment-cleanup request exists or an
          authoring/publication workflow reaches a review gate
Skip when: a selected specialist workflow already owns review end to end
Owns: selection of the review workflow and immediate review owner
Does not own: the verdict, code fixes, GitHub mutation, or publication content
Allowed side effects: read-only target classification
Inputs: request, target kind, base/head or file scope, current workflow, and review
        policy
Exit states: local-review, PR-workflow, helper-review, specialist-review, critic,
             blocked
Outputs: one review owner, stable-target requirements, and deferred gates
Re-enter when: target, review purpose, independence requirement, or workflow changes
```

## Decision Tree

1. **PR URL/number, existing PR, PR CI/comments/threads, or “review this PR”**
   → `pr-workflow` first. It establishes live metadata, current head,
   worktree, changed files, checks, and thread state. Only then does its review
   lane dispatch the required reviewer(s).
2. **Working directory, local diff, branch, commit, or named files; no PR owner
   requested** → the current agent loads `reviewer` and produces the
   verdict.
3. **Explicit extra/independent/second-model/Codex review, or a loaded workflow
   mandates one** → `delegation` + `reviewer-handoff`; use `closeout-review` for
   the Codex helper when selected.
4. **Direct SQL/schema/migration/data-safety review** → database reviewer or
   `reviewer` database path as the owning specialist requires.
5. **Proposal/plan before implementation** → `idea-challenge` or the
   `code-authoring` pre-code critic, not final code review.
6. **Reviewer finding requires a change** → `code-authoring`, focused
   validation, then refresh only the review gates invalidated by the change.
7. **PR title/body or publication readiness** → publication lane inside
   `pr-workflow`, then `github-workflow` for mutation.

Do not choose several review owners “for coverage.” Additional reviewers need a
user request, a mandatory specialist rule, or material risk that the owning
workflow explicitly maps to them.

## Direct Local Review Law

A direct local/branch/commit/named-file review belongs to the current agent.
Target size, file type, instruction/mirror files, an available reviewer role, or
later commit/push intent does not create an implicit second review.

For “review and fix/commit/push”:

1. perform the requested review;
2. apply only accepted fixes in a later authorized phase;
3. rerun affected validation;
4. directly re-review the final target;
5. enter the relevant git/remote phase.

Do not send this path through `reviewer-handoff`, `closeout-review`, a critic,
scout, or council unless extra review is explicitly requested or mandatory.

## PR Review Entry Law

PR-shaped work always starts with `pr-workflow`, even when a local branch
already exists. Review-only PR prompts allow reads and metadata refresh. A disposable isolated
review worktree is allowed only when `pr-workflow` and current repo policy
explicitly define it as review setup, it preserves existing work, and it has a
bounded cleanup path. Review-only prompts do not authorize product validation,
edits, commit/push, PR mutation, or thread mutation.

The PR workflow decides whether its ordinary native reviewer is mandatory and
how database/security/infra siblings are dispatched. Do not duplicate those
rules here or author the first PR verdict in the parent before the workflow’s
required reviewer returns.

If a mandatory reviewer cannot run, use `runtime-capability-check` and the
fallback rules of the owning workflow. A failed spawn is not a passed review.

## Stable Target Requirements

Before any verdict-producing reviewer starts, establish:

- target type and exact identity;
- base/head or commit range where applicable;
- changed-file inventory;
- current intent/non-goals as context, not proof;
- validation already run or `Pending Verification`;
- output contract required by the owning workflow.

For PRs also establish live PR number, base, current head SHA, body,
comments/threads, checks, and review worktree through `pr-workflow`.

A target is unstable when edits continue, the head can move without detection,
or the range is ambiguous. Do not request a final verdict from an unstable
target.

## Specialist Applicability

Use `database-review-applicability` only after the stable target and changed-file
inventory exist. Applicability classification must not bias the ordinary
reviewer’s independent judgment. Required specialist verdicts join before the
parent’s final synthesis.

A target change invalidates target-dependent conclusions, then the parent
classifies the delta through the append-only reviewer ledger. Exact-SHA change alone does not require broad
redispatch: cosmetic or semantically unchanged output needs direct readback,
one changed correctness boundary needs targeted follow-up, and multi-domain
invalidation needs a justified broad pass.

When required reviewers disagree, preserve both verdicts and the stricter
provisional side-effect boundary while `conflict-resolution` verifies the
disputed claim. Do not silently turn the temporary hold into an adopted verdict;
the parent joins the independent decisions under their owning contracts.

A Work Item Profile is an advisory forecast, not a verdict or waiver. The
reviewer independently selects the actual mode from the stable target, current
diff, callers and consumers, impact scope, reversibility, and current evidence.
Production blast radius, database, security, infrastructure, migration, auth,
or public-contract requirements remain mandatory regardless of diff size.

When a separate reviewer is selected, route the advisory forecast and current
mandatory floors through
[`review-control-plane`](review-control-plane.md). Its separate scope-control
message lets the reviewer accept or evidence an escalation without adding
fields to the final verdict packet. The parent may supply one evidence
correction, but unresolved adequacy stays reviewer-owned and fails closed
through `conflict-resolution`.

## Review Cycle Termination

- one initial required review per stable target;
- verify and fix accepted actionable findings;
- rerun affected validation;
- rerun a reviewer only when the fix materially changes a correctness boundary
  that reviewer owns or the owning workflow requires a current-target pass;
- do not rerun for cosmetic docs/comments/formatting or straightforward tests
  that do not change reviewed behavior;
- stop when the current target has no accepted actionable findings and required
  specialist gates are complete or explicitly blocked.

## Output

```text
Gate: review-routing
Decision: LOCAL REVIEW | PR WORKFLOW | HELPER REVIEW | SPECIALIST REVIEW |
          CRITIC | BLOCKED
Requested review shape:
Stable target and evidence:
Next owner / immediate owner:
Mandatory additional gates:
database review applicability: <packet disposition and phase-gate result>
review scope control: <not separate | accepted | escalated | dispute blocked>
Finding-to-fix route:
Target invalidation/review-rerun rule:
Re-entry condition:
Pending Verification:
```
