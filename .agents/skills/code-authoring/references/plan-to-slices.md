<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-31 (independently green wide-refactor slicing) -->

# Code Plan To Slices

Use this lane when a broad code request, initiative, epic, or multi-domain
change needs small reviewable increments before implementation.

## Mission

Turn a broad ask into an ordered set of independently shippable,
independently reviewable slices, each with one owner and one demonstrable
result, so review cost stays low and rollback stays cheap.

## Boundaries

This lane owns slicing and sequencing. Also load `architecture` when slice
boundaries depend on seam design, `impact-and-source-map` when the changed
surface is not yet known, `value-and-release-readiness` when slice order must
follow user value, and `feature-flags-rollout` when incomplete slices must
ship dark behind a flag.

Do not slice by technical layer ("backend slice, frontend slice, test slice")
when a vertical behavior slice is feasible; layer slices defer integration
risk to the last, largest step.

## Slice Rules

- Slice by user-visible or operator-visible behavior, not technical layer.
- A vertical product slice contains the backend, API, UI, and tests needed for
  one independently valuable behavior. Do not call backend plumbing, later UI
  wiring, and a final test batch separate vertical slices merely because each
  commit can merge or preserve the old default.
- Prefer one receiving owner and one demonstrable result per slice.
- Include outcome, scope, acceptance criteria, validation, dependencies, risk,
  and owner.
- Keep each slice reviewable in one sitting; if a slice's diff cannot be
  reviewed carefully in roughly 30 minutes, split it again.
- Sequence the riskiest or least-reversible learning first when possible, so
  the plan can change before sunk cost accumulates.
- Put schema, generated-contract, and public API movement in early slices
  with compatibility for the old behavior, so later slices stay small and
  independently green.
- Mark slices `AFK` only when an agent can implement them from repo evidence
  without human product, security, rollout, access, or architecture judgment.
- Keep dependencies acyclic and model only true blockers. A blocker edge means
  the dependent slice cannot begin or ship until the blocker's acceptance is
  proved. Name the current frontier: every unfinished slice whose blockers are
  complete, and therefore can start now.
- Use vertical slices by default. A mechanically wide shared-contract change
  that cannot land atomically without breaking callers may instead use
  expand–migrate–contract: add a compatible new form, migrate callers in
  bounded batches, then remove the old form only after every batch completes.
  Every step and migration batch must remain independently green, shippable,
  and reviewable. If that cannot be achieved, redesign the compatibility seam
  instead of hiding the failure in a final integration slice or a branch that
  is green only after shared integration.
- For expand–migrate–contract, state the frontier explicitly. The initial
  frontier contains the compatible expand step. Once it is accepted, every
  caller batch without another proved blocker enters the frontier together;
  do not serialize independent batches by default. The contract step stays
  blocked by every caller batch and enters the frontier only when all are done.
- Give every slice a rollback story: revert commit, flag off, or explicit
  irreversibility with owner sign-off.

## Prevention Probes

- Which slice would a reviewer reject as "too big to review safely"?
- Does any slice ship a broken intermediate state to users or operators
  without a flag or gating?
- Is there a hidden integration slice at the end where all layer slices meet?
- Which acceptance criterion could pass while the real outcome still fails?
- Does the first slice prove the central premise, or only scaffold?

## Output Discipline

Present the plan as an ordered table or list: slice name, outcome, scope,
acceptance criteria, validation, dependencies, risk, owner, `AFK` eligibility.
Stop at a draft plan when the user asked for planning. Continue only when the
first slice is clear and no HITL decision blocks it. Record deferred slices
and open decisions explicitly rather than absorbing them into slice one.
