<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (accepted-plan conformance intake) -->

# Code Change Intake

Use this lane at the start of every non-fast-exit code authoring task. Its job
is to make the code-lane choice visible before edits start.

## Process

1. Restate the requested outcome in repo terms.
2. Consume the current
   [orchestration conformance attestation](../../work-orchestration/references/orchestration-conformance.md).
   Missing, stale, contradictory, or unsupported conformance blocks critic
   dispatch and meaningful edits. Do not reconstruct the attestation inside code
   authoring. Ask only for the current attestation and its missing objective-lock
   and forward-analysis dispositions; do not replace that evidence request
   with a new gate checklist.
   When forward analysis is complete, require its ID/version and the
   decision-changing conclusions needed for the candidate. Do not require an
   unchanged full record, source inventory, or digest as transport ceremony.
3. Record the objective-lock status from orchestration: `not required`,
   `already locked: <lock-id>@v<version>`, active locked contract, `pending
   owner`, or `pending evidence`. When the lock is activated, material pending
   intent or evidence blocks meaningful edits. Do not reconstruct or silently
   broaden the objective inside code authoring.
   A `not required` result must name the verified unchanged contract, applicable
   objective-owned fields checked, and current evidence; a bare label is
   invalid.
   After the critic reaches a terminal disposition, when `plan-acceptance`
   activated, also consume the exact accepted-plan ID,
   version, content identity, approval evidence, ordered stable step IDs,
   preservation/deletion obligations, side-effect ceiling, and required critic
   disposition. Missing or mismatched evidence blocks edits. Initialize the
   canonical `plan-conformance` ledgers; do not invent another schema.
4. Classify side effects: local read, local write, validation command, git
   write, remote read, remote write, or production-affecting action.
5. Name the behavior surface: UI route, API endpoint, external integration,
   backend package, SQL query, migration, job, queue, scheduler, cache,
   feature flag, workflow, config, script, generated artifact, skill/agent
   instruction, or docs contract.
6. Identify risk triggers: data, auth, public API, external integration,
   generated contract, migration, bulk write, production scale, cache,
   concurrency, job/queue, fallback, feature flag, observability, external side
   effect, accessibility/i18n, performance, security, instruction-policy drift,
   docs/operator truth, or broad refactor.
7. Select the narrowest first lane and any mandatory adjacent lanes.
8. Prepare a code-change todo for non-trivial work. Each item must name the
   code lane or lanes to load, the just-in-time read point, and the rationale
   for what the agent should look for before editing that item.
9. For non-trivial code work, include `authoring-core`, `implementation`,
   `existing-conventions`, and `engineering-judgment` before the first
   meaningful edit so target, context, central failure, surgical implementation
   discipline, local precedent, overengineering pressure, proof, and runtime
   truth are visible before implementation begins.
10. Include `impact-and-source-map` when the change touches unfamiliar code,
   exported symbols, cross-stack contracts, issue-derived fixes, ops evidence,
   current external/library behavior, or any claim that needs source truth
   before edits.
11. Emit the visible audit:

```text
Entry Contract TODO:
- orchestration conformance: pending | complete <attestation-id>, next action=<critic evaluation | plan acceptance | meaningful edits | no>
- objective lock: not required with evidence | already locked <lock-id>@v<version> | locked <lock-id>@v<version> | pending owner/evidence
- plan acceptance: not triggered | accepted <plan-id>@v<version> content=<identity>, approval=<evidence>, critic=<disposition> | blocked
- plan conformance: not triggered | initialized, steps=<stable IDs>, preservation/deletion=<obligations>
- objective conformance: not activated | complete, fields=<applicable authority fields>, mechanisms=<direct/protective/contract-changing/unrelated dispositions>, blocked=<none or item>
- pr-4685 lane discipline: pending | complete, agreement=<required agreement stated>
- pr-4706 publication gate: not triggered | pending | complete, agreement=<required agreement stated>
- case-study transfer preflight: not triggered | pending | complete, commitments=<C1-C3 or reason not triggered>
- forward analysis: not triggered | pending | complete, record=<ID/version>, transport=<exact record | verified same-session reference>
- violation examples: pending | complete, audit=<negative-pattern result>
Selected code lanes:
- <lane>: <surface and rationale>
Code-change todo:
- <item>: lanes=<lane[, lane]>; load timing=just before edit; rationale=<what to look for>
Skipped adjacent lanes:
- <lane>: <skip reason>
Pre-code critic:
- required | optional | skipped, because <risk overlay and confidence rationale>
Final-shape preflight:
- needed: yes/no, because <risk surface>
```

## Objective Conformance Intake

When `objective-lock` activated, this lane is the sole pre-edit owner of the
task-applicable conformance record. Before selecting an implementation
mechanism, copy only the locked fields the task can affect: source authority,
fallback/error/availability semantics, runtime dependencies or latency,
synchronization, auth or data ownership, flags, phase sequence, acceptance
criteria, protected invariants, and non-goals. Do not build a universal
transition matrix when those fields are irrelevant.

Classify each proposed mechanism using the active objective lock as `direct`,
`protective`, `contract-changing`, or `unrelated`. Record the evidence and
locked field served by every direct or protective item. A reviewer suggestion,
critic recommendation, prior incident mitigation, or implementation
convenience is evidence, not authority and receives the same classification.

Meaningful edits may begin only when every retained mechanism is direct or
protective. Freeze a contract-changing item and return it to `objective-lock`
for an explicit owner decision and new version. Remove or defer an unrelated
item. `authoring-core` consumes this completed intake; it must not reconstruct
the authority model or create a parallel lock.

## Accepted-Plan Conformance Intake

When `plan-acceptance` activated, map each code item to stable approved step IDs
before editing. Record every candidate file and mechanism under a step or as a
proposed deviation. Preserve same-file semantic obligations explicitly; a file
inventory cannot prove that required content survived. If discovery would add,
remove, reorder, defer, or supersede an unconditional step, or materially
change a target, mechanism, owner, proof, risk, side effect, or preservation/
deletion obligation, stop and route through `scope-change-control`. Do not edit
first and reconcile later.

## Selection Rules

- If `objective-lock` activated and a material item remains `pending owner` or
  `pending evidence`, return to orchestration before editing. A verified
  unchanged lock may be reused without repeating user questions. Existing
  critic and reviewer selection rules still apply independently.

- If the task is only to understand an unfamiliar area, return to
  `work-orchestration` and use the mapping or architecture route before
  code authoring.
- If the root cause is unknown, return to the diagnose route before writing the
  fix.
- If the user asked for a plan only, load `references/plan-to-slices.md` or
  `references/architecture.md` and stop at the plan.
- If a behavior is known and risky enough to regress, include `tdd-regression`
  before implementation.
- If the task is non-trivial, include `authoring-core`, `implementation`,
  `existing-conventions`, and `engineering-judgment` before implementation.
- If the task changes an unfamiliar or shared symbol, route, generated
  contract, workflow, public API, or cross-stack behavior, include
  `impact-and-source-map` before editing that item.
- If the implementation depends on GitHub issue/PR text, Sentry, logs, GCloud,
  docs, release notes, framework behavior, or current library/API facts,
  include `impact-and-source-map` before coding from that evidence.
- If any production data, bulk job, SQL, migration, backfill, import, dry-run,
  apply, or operator gate changes, include `production-data-safety`.
- If SQL queries, migrations, generated data contracts, fixtures, cache/event
  schemas, or old/new database compatibility changes, include
  `sql-migrations-and-data-contracts`.
- If public APIs, internal requesters, webhooks, callbacks, external providers,
  status/error envelopes, pagination, or old/new client compatibility change,
  include `api-contracts-and-integrations`.
- If auth, permissions, tenant scope, identity propagation, gated UI, service
  accounts, or protected resource access changes, include
  `auth-permissions-identity` plus `security-and-trust-boundary` when secrets,
  PII, or broader trust boundaries are involved.
- If retries, timeouts, cancellation, broad catch blocks, fallback values,
  best-effort behavior, or fail-open/fail-closed choices change, include
  `resilience-and-fallbacks`.
- If caches, invalidation, locks, leases, idempotency, optimistic updates,
  stale reads, read-after-write, or concurrency-sensitive writes change,
  include `concurrency-caching-consistency`.
- If jobs, queues, schedulers, async processors, batch commands, or run-state
  behavior changes, include `jobs-queues-and-schedulers`.
- If feature flags, modes, environment toggles, rollout gates, experiments, or
  kill switches change, include `feature-flags-rollout`.
- If logs, metrics, traces, Sentry, alerts, dashboards, runbooks, deploy checks,
  or incident evidence changes, include `observability-and-operations`.
- If user-facing UI copy, forms, keyboard/focus behavior, semantic markup,
  locale formatting, translation keys, RTL, or long-content layout changes,
  include `accessibility-and-i18n`.
- If skills, agent role files, prompts, durable policy docs, packet docs,
  runtime mirrors, or instruction examples change, include
  `instruction-skill-agent-authoring`.
- If any auth, permission, tenant, secret, sensitive log, workflow permission,
  dependency, network, file, or system boundary changes, include
  `security-and-trust-boundary`.
- If a claim mentions faster, cheaper, smaller, scalable, bounded, efficient,
  or production-safe, include the lane that can prove that claim.
- If the user asks for at most three repository-quality, code-health, or
  cleanup tasks feeding the current implementation workflow, include
  `quality-scout` before selecting an implementation lane. Route a durable
  ranked backlog, roadmap, or cold-executor plan for later execution to
  `improve` instead.

## Output Discipline

Keep the audit short. It exists so the user can correct the lane before the
agent writes weak code. Do not turn the audit into a full implementation plan
unless the task genuinely needs a plan.

The rationale is part of the work contract. Select lanes early so the user can
correct routing before code is written. Load lane details just in time so the
agent keeps implementation context hot without spending the whole context
window on lenses that may not apply. If the code-change item changes, update
the lane mapping before editing further.
