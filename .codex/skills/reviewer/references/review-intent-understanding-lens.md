<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (independent accepted-plan conformance) -->

# Review Intent Understanding Lens

Use this lens before detailed findings when a PR body, draft intent packet, or
parent handoff describes what the change is supposed to do.

## Mission

Avoid diff-reactive review. First understand the author's stated intent and the
review target, then verify that intent against source truth. The intent artifact
aims the review; it does not prove the behavior.

PR body is the source of stated intent, not proof. Code, config, tests, runtime
wiring, generated artifacts, and current GitHub metadata remain the source of
truth.

## Ownership And Boundaries

This lens owns review aiming: it helps the reviewer build and falsify the
change's stated contract before judging findings. It does not own verdict law,
severity, packet format, production blast-radius gates, or Risk Evidence
Handoff. Apply the canonical closeout `documentation_truth` category to stale
PR prose, comments, docs, and operator text; use the AI/large-change lens for broad behavior preservation and
unstated scope growth.

## Objective Conformance

When the target records or changes a behavioral contract, compare the current
implementation with live stated intent across only the applicable fields:
source authority, fallback/error/availability semantics, runtime dependencies
or latency, synchronization, auth or data ownership, flags, phase sequence,
acceptance criteria, protected invariants, and non-goals. Current source and
the pinned diff prove implementation facts; the intent artifact establishes
stated direction but does not prove the code.

Classify each material implementation delta or reviewer recommendation as
`direct`, `protective`, `contract-changing`, or `unrelated`. A silent
contract-changing implementation is a code defect when it violates sufficient
live intent. A reviewer recommendation that would change the contract returns
to the intent owner as a decision; reviewer caution does not authorize the
change. Unrelated advice is excluded from findings.

For parent-authored own work, consume the final target-bound
[orchestration conformance attestation](../../work-orchestration/references/orchestration-conformance.md)
as an intent-provenance input, then independently compare it with the exact
target. Missing, stale, contradictory, or unsupported provenance blocks a
ready/pass verdict only when it can change scope, safety, authority, or
correctness. Do not manufacture the missing parent decision or treat an absent
governing-source inventory, optional heading, or hash as a blocker.

For a teammate's PR, use the live PR body and current artifacts to aim this
comparison. Do not manufacture a retroactive objective lock or require the
author to produce one. When intent is stale, contradictory, or too thin to
decide a material contract field, keep that field `Pending Verification` and
report only what current source and the pinned target prove.

## Accepted-Plan Conformance

For parent-authored own work governed by `plan-acceptance`, consume the exact
accepted plan and the canonical
[plan-conformance contract](../../work-orchestration/references/plan-conformance.md).
Independently rebuild both mappings from the stable target:

- every approved stable step ID to implementation and proof;
- every changed file, meaningful hunk, and mechanism to an approved step or
  explicit deviation; and
- every preservation and deletion obligation to semantic evidence inside the
  touched content.

Do not accept the parent or authoring ledger as proof. File presence, phrase
presence, and changed-file inventories do not prove that generally useful
content or behavior survived. Sample grouped mechanical hunks and inspect every
semantic preservation/deletion row.

Record the companion plan-conformance result as `MATERIAL_DEVIATION` for
unapproved files, hunks, mechanisms, or semantic loss; `INCOMPLETE` for a
missing unconditional step; and `BLOCKED` for a stale or mismatched plan/target
identity or missing authority. This result does not replace the reviewer's
canonical verdict. A step labeled
deferred, omitted, reordered, or superseded without a new accepted plan version
is incomplete, not a reviewer-approved exception. Keep ordinary work without a
triggered accepted-plan contract free of this packet.

## Review Sequence

1. Read the intent artifact first:
   - live PR body for teammate/open PRs
   - factual pre-open intent packet for own unpublished PRs
   - parent handoff for staged, branch, commit, or follow-up reviews
2. Reconcile freshness before trusting the framing. Treat the intent artifact
   as possibly describing an earlier head than the pinned review target. If its
   stated surfaces, file lists, validation, or risk claims do not match the
   current changed-file inventory or pinned diff, trust the current target and
   treat the intent as stale.
3. Extract the stated contract using the Required Packet fields in
   `../../work-orchestration/references/reviewer-handoff.md` as the
   canonical shape. Pay special attention to acceptance criteria, non-goals,
   changed contracts, flags, data shape, validation, operator impact, and
   `Pending Verification`.
4. Inspect source around those claims before judging hunks:
   - callers and callees
   - runtime wiring, config, feature flags, jobs, or routes
   - tests and fixtures
   - generated files and source-of-truth pairings
   - docs, logs, CLI help, runbooks, and operator truth
5. Before adopting the narrative's framing, form an independent expectation
   from source and the diff of what this change should touch and what could
   break. Actively look for evidence that the stated intent is wrong, stale, or
   incomplete, not only evidence that it is right.
6. Compare the actual diff against stated scope and non-goals. Route unstated
   scope growth, broad behavior preservation, or silent contract movement
   through `ai-large-change-lens.md`; route stale or misleading prose through
   the canonical closeout `documentation_truth` category.
7. Apply the objective-conformance classification when the target records or
   changes a behavioral contract.
8. When plan acceptance activated, independently apply accepted-plan
   conformance against the exact target.
9. Then review the diff against stated intent, accepted plan, and source truth.

## Triage

- If implementation violates a required behavior or makes the stated contract
  unsafe, report a code finding.
- If implementation is correct but the intent artifact overclaims, omits a
  material non-goal, misstates validation, or sends reviewers to the wrong
  surface, report PR-body or documentation drift through the canonical
  closeout `documentation_truth` category.
- If the intent artifact is internally confident but points reviewers at the
  wrong surface or asserts a false invariant, treat it as misleading, not merely
  thin. Re-derive the contract from source and surface the false claim through
  the canonical closeout `documentation_truth` category when it can mislead
  reviewers, operators, or future readers.
- If the intent artifact is too thin to determine scope, risk, or validation,
  mark the missing intent `Pending Verification` when it can affect the verdict.
  If the missing scope, risk, or validation controls a production blast-radius
  surface, route the gap through the core Production Blast-Radius Gate and Risk
  Evidence Handoff instead of burying it as generic missing prose.
- If no usable intent artifact exists, build a minimal inspection map from the
  changed-file inventory, mandatory lenses, and source truth. Treat any inferred
  goal as `Pending Verification`; do not use inferred intent to justify `PASS`.
- Do not file findings merely because the intent artifact could be more polished
  when the code and review target are clear enough.

## Output Discipline

In the `review-intent-understanding` row of `Selected reviewer lenses:`, name
the intent artifact inspected, the target head or equivalent pin when available,
and whether it was sufficient to aim scope, blast-radius, and validation
inspection. If no usable intent artifact was available, state that under
`Not loaded` or `Pending Verification` according to packet rules.

For own work with an accepted plan, also name its ID/version, independent
conformance result, material exceptions, and any remaining `Pending
Verification`. Give the user the exception-focused result, not a demand to
line-review the raw diff.
