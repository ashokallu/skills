<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-16 (proportional database follow-up) -->

# PR Re-review Worktree

Use this lane for a bounded follow-up review by the exact reviewer session that
produced findings against an earlier immutable target. Its purpose is to verify
a finding-directed fix batch without repeating unrelated discovery, while
preserving independent full review before terminal whole-PR signoff.

This is a middle-phase lane under `pr-workflow`. It does not replace the
initial full review, the neutral stabilization review, the canonical review
packet, or the independent database-reviewer gate.

Every target change still follows `reviewer`: re-enter its middle phase,
recompute the selected lens set against the exact new target, complete the
target-relevant analysis and residual pass, and record the standard middle-phase
completion before running the end phase. The impact cone bounds that work; it
does not waive or replace a mandatory reviewer phase.

Use the shared `readback`, `targeted`, `broad`, and `blocked` vocabulary from
`work-orchestration/references/review-control-plane.md`. This lane keeps
ownership of the ordinary re-review lifecycle, provenance, impact-cone closure,
and whole-PR-signoff limits. If the reused reviewer disputes the proposed
follow-up depth, finish the companion's separate scope-control exchange before
this lane's evidence-heavy procedure; never put that exchange in the compact
re-review result.

## Admission Gate

The parent must choose and preserve review-fix topology before requesting this
lane. Create one new ancestral, finding-directed commit or exact range after
the reviewer accepts findings. Do not amend, squash, rebase, or otherwise
rewrite `H0` while this scoped review is planned, queued, running, or
unresolved. Provider-specific convenience rules do not override this
provenance requirement.

Enter this lane only when the parent can prove all of the following:

- the exact same reviewer thread or tool session is continuing; a nickname,
  role, model, session alias, or similarly named process is not provenance;
- the prior target `H0` and new target `H1` are full immutable SHAs;
- `git merge-base --is-ancestor H0 H1` succeeds and the artifact is included;
- the prior canonical result is included by immutable artifact ID or content
  plus SHA-256 digest;
- the reviewer's own findings have stable IDs such as `F1` and `F2`;
- the parent supplies one finding-directed fix commit or exact range, a
  resolution explanation per finding ID, and current validation artifacts.

If any identity, target, ancestry, artifact, or finding binding is absent or
ambiguous, use a fresh full review. Non-ancestral and tree-equivalent rewritten
targets also use a fresh full review; equivalence does not restore reviewer or
SHA-bound evidence provenance.

Reject a purported finding-directed range when unrelated or interleaved edits
appear unless every changed path and dependency edge is mapped to an accepted
finding and remains inside the bounded impact cone.

The parent owns this record and all git writes. The reviewer remains read-only,
retains only its own prior finding context, and resets its conclusion for every
new target.

## Lifecycle

Use this state machine. Do not turn a compact re-review result into a terminal
review artifact.

1. `INITIAL_FULL_A(H0)`: fresh reviewer A performs the ordinary complete review
   and emits the canonical packet bound to `H0`.
2. `FIX_BATCH_A(H0,H1)`: the parent implements accepted findings in an explicit
   ancestral commit or range and prepares the admission record.
3. `SCOPED_A(H0,H1)`: exact reviewer A re-enters the reviewer middle phase,
   recomputes the selected lens set for `H1`, and verifies its fixes, the fix
   delta, and the bounded impact cone. It emits only the non-signoff result
   defined below.
4. `SCOPED_A_LOOP`: related regressions or new defects inside the proved cone
   may receive another ancestral finding-directed fix batch. An unrelated
   finding, unbounded dependency edge, redesign, history rewrite, or incomplete
   safety model exits to `RESET_FULL`.
5. `STABILIZE(HS)`: after A returns `RESOLVED`, retire A. The parent may
   conditionally squash only under existing commit policy. A rewrite requires
   tree-equivalence proof and invalidates SHA-bound CI, review-thread, and
   reviewer evidence even when the trees match.
6. `NEUTRAL_FULL_B(HS)`: fresh reviewer B receives the ordinary factual target
   packet with no historical findings, focus hints, completion labels, or
   expected verdict. B performs independent whole-PR discovery and emits the
   canonical packet bound to `HS`.
7. If B is clean, that current-target canonical packet is the terminal review
   evidence. If B finds issues, the parent may give exact B an ancestral,
   exclusively finding-directed fix batch and enter `SCOPED_B(HS,HN)`.
8. When B resolves its own bounded findings, B records the required
   current-target middle-phase completion, including the recomputed lens set
   and residual pass for `HN`, then runs the existing reviewer end phase once
   and emits a new canonical packet bound to `HN`. This cumulative current-target
   packet is allowed only when every intervening change is ancestral and
   finding-directed and the impact cone is closed.
9. Enter `RESET_FULL` and dispatch a fresh neutral reviewer C when scoped work
   finds an unrelated issue, the dependency or safety model proves incomplete,
   unrelated edits appear, reachability cannot be bounded, a required full gate
   is invalidated, or history is rewritten after B's full review. Do not chain
   reviewers indefinitely around an invalid model.

Every `SCOPED_A_LOOP` or `SCOPED_B` transition is subject to the Targeted
follow-up circuit breaker in
`work-orchestration/references/reviewer-handoff.md`.
`AUTHORING_RESET_REQUIRED` blocks the next reviewer request until its recovery
artifact selects validation/readback, targeted, broad, or blocked/owner
escalation without resetting the boundary lineage.

No compact result grants whole-PR signoff. Only the canonical packet produced
by a full reviewer end phase against the exact current stable target can serve
as whole-PR review evidence. Do not squash or rewrite after B when B is expected
to produce cumulative terminal evidence; a post-B rewrite enters `RESET_FULL`.

## Scoped Review Procedure

Retain context, reset the conclusion, and review only what current evidence can
bound safely.

### Seeds

Seed the impact cone with:

- every file and symbol changed in `H0..H1`;
- each prior finding's location, mechanism, required outcome, and proof surface;
- every test and observable contract claimed as validation.

### Expansion And Closure

Expand through target-relevant definitions and interfaces, callers and
callees, imports, consumers, persistence and query boundaries, tests and
fixtures, generated sources and outputs, config and flags, docs and runbooks,
auth and permissions, public APIs and schemas, analytics and observability,
CI/workflow behavior, and runtime ownership.

Continue until the latest dependency frontier adds no target-relevant edge.
Record included edges and explicit probes that found no expansion. Prior clean
evidence may be reused only while every target-relevant input it depended on is
unchanged. It is evidence, not a prohibition on inspection. Reviewer autonomy
to expand is unconditional.

Closure requires concrete search or dependency artifacts and an explicit list
of unchanged prior-evidence inputs. File count, elapsed time, token pressure,
or parent confidence cannot close the cone.

### Mandatory Escape

Return `ESCALATE_FULL_REVIEW` when any of these is true:

- unrelated files, requirements, or behavior changed;
- the fix is a redesign, ownership move, or cross-layer change rather than the
  agreed correction direction;
- target history is non-ancestral or rewritten;
- dynamic, reflection, plugin, or generated reachability cannot be enumerated;
- public API or schema, generated-source contract, auth or tenant boundary,
  data semantics or migration, workflow, infrastructure, release semantics, or
  environment-dependent evidence exceeds the bounded finding fix;
- a new finding is outside the recorded cone; or
- evidence shows the prior safety model, case-study inputs, or selected lenses
  were incomplete.

## Re-review Result Contract

This is intentionally not the canonical review packet. Begin exactly with one
of:

```text
Re-review result: RESOLVED
Re-review result: NEEDS_CHANGES
Re-review result: ESCALATE_FULL_REVIEW
```

Then emit these fields in order:

```text
Reviewer provenance: <exact session/thread ID and prior-result digest or artifact ID>
Prior target: <H0>
Review target: <H1>
Fix range: <exact commit/range and ancestry artifact>
Scope basis: <stable finding IDs and fix intent>
Impact cone: <included files, symbols, consumers, and contracts>
Selected lenses: <recomputed current-target lens set and concrete surfaces>
Closure proof: <dependency/search artifacts and unchanged prior-evidence inputs>
Expansion probes: <potential edges inspected and outcomes>
Prior finding dispositions:
- <finding ID>: RESOLVED | REMAINS | REGRESSED | SUPERSEDED; <evidence>
New findings: <None or complete causal finding detail>
Validation evidence: <executed or inspected artifacts and Pending Verification>
Escalation: <None or exact escape reason and next full-review target>
Whole-PR signoff: not granted
```

Do not emit a line beginning `Verdict:`, `Packet ends.`, or a `PASS`, `ready`,
or `approved` whole-PR conclusion. Never omit provenance, `H0`, `H1`, or the
ancestry artifact.

Compactness must not erase finding quality. Every `REMAINS`, `REGRESSED`, or
new finding includes severity and confidence, location, mechanism, concrete
impact, evidence, correction direction, and focused verification. That detail
may be inline or an immutable finding artifact included in the result. A
`RESOLVED` disposition names the required outcome and proof; status alone is
not evidence.

## Database Reviewer Matrix

Preserve the independent database gate while leaving target-delta
classification with `database-reviewer`:

- no database-related surface or database-consequence change: use the ordinary
  lifecycle above and record why database follow-up is not required;
- any target delta that can affect a database conclusion: provide the exact
  delta to `database-reviewer`, which classifies it as validation/readback,
  one-boundary targeted follow-up, or justified broad follow-up;
- an exact-SHA change or unchanged environment does not by itself preserve a
  target-dependent conclusion, and it does not by itself require broad review;
- re-preflight environment evidence only when a dependent fact changed,
  expired, was invalidated by the target delta, or a relevant event occurred;
  and
- when database follow-up is required, the ordinary scoped reviewer never
  waives or substitutes for `database-reviewer`. If that reviewer is
  unavailable, keep the gate blocked.

The database reviewer decides which conclusions and evidence dependencies the
new target invalidated. The parent records that classification and required
preflight in the append-only review-round ledger before dispatch.

Map its result to the shared vocabulary without taking over the database
reviewer's classification: validation/readback is `readback`, a one-boundary
follow-up is `targeted`, a justified residual sweep is `broad`, and missing
provenance or an unresolved scope dispute is `blocked`.

## Efficiency Evidence And Rollback

Efficiency comes from bounded scope, not from a hard token, time, or file-count
cap. Record elapsed and token evidence when the runtime exposes it, but do not
claim measured savings without a representative pilot.

Reject or roll back this lane if a representative run repeats unrelated full
discovery, misses a seeded outside-cone defect, permits compact signoff, or
bypasses a required database or fresh-full reset. Provider authentication gaps
leave the real-model pilot `Pending Verification`; they do not waive
deterministic contracts.
