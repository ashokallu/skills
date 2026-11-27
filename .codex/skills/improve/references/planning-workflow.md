<!-- markdownlint-disable MD013 MD060 -->

# Improve Planning Workflow

Use for selected audit findings, `plan <description>`, and
`review-plan <file>`.

## Resolve The Plan Root

Default to the canonical durable root `advisor-plans/` and index
`advisor-plans/README.md`. Use `docs/plans/advisor/` only after an explicit
user request for local-only scratch output; label that root
`local-only, non-durable` because the repository ignores it.

Resolve one `plan_root` at entry and carry it through every file, link,
dependency, review, execution handoff, reconciliation, and issue record. Reject
plan files outside that root.

## Plan A Selected Finding

Read [plan-template.md](plan-template.md) immediately before writing the first
plan.

Before writing:

1. Record the current commit SHA.
2. Re-open every cited source and verification-command owner.
3. Inspect the selected root and index. Reconcile existing numbering and avoid
   duplicate or superseded findings.
4. Identify dependencies, product-code scope, explicit non-goals, next
   consumer, and STOP conditions.

Each plan must include current evidence, exact paths and symbols, repository
conventions, ordered steps, per-step verification with expected results, tests,
machine-checkable done criteria, maintenance notes, drift checks, and escape
hatches. Write for an executor that has the repository and plan but none of this
conversation.

The advisor or orchestrating parent owns
`<plan_root>/README.md`. Executors never update the index and never include it
inside product-code scope.

## Plan Variant

For `plan <description>`, skip the broad audit. Perform only enough recon to
write one honest plan. Resolve ambiguities from current source first; ask one
targeted question only when the remaining choice changes scope or safety.

## Review-Plan Variant

For `review-plan <file>`:

1. Confirm the file is inside the resolved `plan_root`.
2. Check it against [plan-template.md](plan-template.md).
3. Re-open its cited sources and verify the planned-at drift boundary.
4. Tighten missing context, ambiguous steps, unowned decisions, unverifiable
   criteria, scope leaks, and generic STOP conditions.
5. If this advisor authored the plan in the same session, use one fresh-context
   read-only agent to identify cold-reader ambiguity, then verify each accepted
   concern directly.

Reviewing a plan does not authorize source edits, execution, commit, push, or
publication.

## Index

Maintain `<plan_root>/README.md` with priority order, dependencies, lifecycle
status, and considered-but-rejected findings. Status values are `TODO`,
`IN PROGRESS`, `DONE`, `BLOCKED`, and `REJECTED`, each backed by current
evidence where applicable.
