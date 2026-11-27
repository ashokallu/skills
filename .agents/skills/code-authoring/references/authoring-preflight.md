<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (accepted-plan conformance proof) -->

# Authoring Preflight

Use this lane before handoff or PR publication for a code change. It gives the
author one final construction-focused pass over the changed surface before the
implementation leaves the code-writing phase.

This lane borrows useful pressure from skeptical code-audit workflow patterns:
inspect changed lines with skepticism, prioritize important issues, stay
actionable, and explain why a fix matters. Do not copy persona, sarcasm,
duplicate-run caches, GitHub posting mechanics, verdict formats, severity law,
or gate submission steps into code authoring.

## Process

1. Build the changed-file inventory from current local evidence.
2. Map changed surfaces to the preventive probes below.
3. Run authoring closeout lanes that correspond to those probes.
4. Complete the coding task handoff checklist below with current repo evidence.
5. Run a skeptical self-check over changed lines and nearby context.
6. Record covered probes, fixed issues, and remaining proof gaps in the code
   closeout.

## Preventive Probe Matrix

- PR-ready branch: simplification, documentation truth, naming, conventions,
  focused changed-line cleanup, and broad-diff skepticism
- Backend Go: package ownership, context cancellation, error translation,
  cleanup, concurrency/resource safety, API/external-call boundaries, jobs or
  queues, and validation value
- SQL, migrations, generated contracts, imports, backfills, audits, bulk jobs:
  SQL/data-contract lane, source plus generated output movement, migration
  safety when DDL changes, bounded execution, production data safety,
  performance scale, and validation
- Frontend UI or browser behavior: frontend-ui, accessibility-and-i18n,
  test-quality, responsive correctness, data-shape truth, performance, and
  privacy when auth or sensitive browser state changes
- Bug fix or runtime symptom: debugging-and-repro, root-cause proof,
  before/after evidence, regression test, and debug artifact cleanup
- Dependency, tool, or CI workflow change: dependency upgrade safety,
  changelog and behavior-change assessment, security scan, rollback files, DX
  command verification, CI workflow authoring, and CI alignment
- Auth, permission, tenant, identity, secret, PII, workflow permission,
  dependency: auth-permissions-identity plus trust-boundary proof, least
  privilege, secret-safe logs, supply-chain provenance, and explicit owner or
  validation evidence
- Logs, metrics, Sentry, GCloud, dashboards, runbooks, release proof:
  observability-and-operations, operator-visible truth, alert/log usefulness,
  stale docs, and rollback or recovery clarity
- User-facing or production-facing behavior: value-delivery proof path,
  drift check, release risk, rollback conditions, and explicit remaining
  `Pending Verification`
- Types, DTOs, enums, state machines, public API contracts, integrations,
  webhooks, or requesters: API contract lane, old/new compatibility, illegal
  states, nullable fields, enum growth, provider retry semantics, and persisted
  or wire-format invariants
- Conditional behavior, gates, modes, branches, flags, caps, fallbacks, or
  state-dependent side effects: feature-flags-rollout plus private
  behavior-contract map covering states, prerequisites, branch precedence,
  outputs, side effects, errors, observability, docs/help/comments, and tests
  before handoff
- Fallbacks, retries, catch blocks, best-effort behavior, optional effectful
  calls: resilience-and-fallbacks, explicit failure visibility, bounded retry
  semantics, no false success, and proof that fallback behavior is intentional
- Cache, lock, transaction, optimistic update, idempotency, dedupe, or stale
  read behavior: concurrency-caching-consistency, source-of-truth map,
  invalidation branch coverage, duplicate/retry proof, and stale-state handling.
- Jobs, queues, production mirrors, reconciliation, dry-run/apply gates, and
  classifier or overlay matching: jobs-queues-and-schedulers, request
  cancellation behavior, total timeout budget, optional dependency guards,
  durable failure visibility, fail-closed malformed payload handling, realistic
  producer fixtures, and operator-actionable errors
- Comments, docstrings, examples, TODOs, skills, prompts, or agent role docs
  describing behavior: instruction-skill-agent-authoring when policy changes,
  runtime truth, stale invariant removal, examples that match current behavior,
  and requested-artifact semantic fidelity

## High-Signal Prevention Checks

- Use audit dimensions as a coverage sweep, not as a new mandatory full audit.
  After the selected lanes have been applied, ask whether the diff still hides
  an unhandled risk in correctness, security/privacy, performance/scale,
  tests/verification, architecture or existing conventions, dependencies or
  migrations, DX/tooling, docs/operator truth, or value/direction. If a
  dimension is relevant and not covered by the selected lanes, load the
  narrowest owning lane or mark the exact gap `Pending Verification`. Skip
  irrelevant dimensions with a short rationale for tiny or mechanical work; do
  not emit a nine-section checklist by default.
- Source and generated artifacts must move together. If a query, schema,
  interface, mock, OpenAPI file, Sanity type, or migration source changed, run
  the owning generator or document the exact `Pending Verification`.
- Validation must prove the risky path, not just exercise nearby code. Avoid
  tests that stay green when the real user, operator, data, permission, or
  production-scale outcome fails.
- Error handling must not turn failed effects into apparent success. Catch only
  where the code can recover, translate, add useful context, or protect a
  boundary.
- Data and production paths need boundedness proof: caps, chunks, idempotency,
  resume behavior, timeouts, query shape, transaction finalization, and
  operator-visible state.
- For long-running SQL jobs, "chunked" is not sufficient proof. Confirm every
  expensive statement in the chunk, including secondary restores, inserts,
  deletes, validations, evidence writes, cleanup, and progress updates, is
  bounded by the intended keyset or has separate query-plan proof.
- Long jobs need a first-progress signal before the first expensive statement
  starts, not only after the first chunk commits. If operators cannot
  distinguish "stuck before first chunk" from "working normally", fix
  telemetry before handoff or mark the path `Pending Verification`.
- Progress and telemetry must have an explicit failure contract. Before
  handoff, classify each marker, duration, progress row, log, metric, and
  terminal update as strict operator truth or best-effort diagnostic signal.
  Strict writes need transactional/durable proof. Best-effort writes need
  bounded context, warning visibility, and proof that their own failure cannot
  abort or roll back primary work.
- Timeout increases are not proof. Treat them as diagnostics unless query
  shape, row counts, locks, storage, and progress telemetry prove the work can
  finish within the operational envelope.
- Best-effort secondary effects need explicit budgets and visibility. Check
  that success does not hide failed mirror/audit work, that failure recording
  does not reuse an already-canceled context, and that optional collaborators
  cannot panic the primary path.
- Mutation-capable state machines need a cross-mode pass before handoff. For
  migration jobs, repair flows, mirrors, validators, reconciles, cleanup, and
  read cutovers, name the runtime truth each mode writes and reads, then prove
  the changed mode does not make another mode's truth stale or misleading.
- Set-based writes need final-state proof. Check expected row counts against
  affected row counts and verify target state before a run can be marked
  completed, especially when live writes can race inserts or updates.
- SQL freshness and provenance need explicit probes for `NULL` timestamps,
  newer target rows, stale source snapshots, conflict updates, and row-lock wait
  ordering. Do not accept a copied timestamp guard until the new query's truth
  function is re-proved.
- Persisted boundary values need post-conversion proof. When validated CLI,
  config, API, or operator input is rounded, truncated, serialized, narrowed,
  or wrapped before storage, compare the stored value to database constraints
  and generated types. Cover positive sub-unit values, fractional values,
  boundary counts, overflow edges, and zero/`NULL` behavior before handoff.
- Test fixtures must be production-shaped. For DB-backed gates, inspect the
  real producer and ensure tests cover `NULL`, missing, malformed, zero,
  no-overlay, and overlay-required cases without leaking shared database state.
- Conditional behavior needs branch-by-branch proof. Before handoff, enumerate
  meaningful states or inputs, prerequisites or gates, branch precedence,
  output or side effect per branch, error or fallback behavior, observability,
  affected docs/comments/help text, and test coverage. Fix missing states,
  wrong precedence, misleading names/docs/errors/logs, and untested guard paths
  before asking reviewer or Copilot to find them.
- Auth, tenant, privacy, and secret paths need reachable-path proof. Do not
  rely on UI hiding, local callers, or trusted defaults as security boundaries.
- Broad or AI-assisted diffs need behavior-preservation proof. Check callers,
  consumers, generated outputs, configs, tests, and docs instead of trusting a
  plausible diff shape.
- Dependencies and CI workflows need privilege and provenance checks. Prefer
  pinned, minimal, existing tooling over new privileged scripts, actions,
  images, or transitive runtime dependencies, and preserve required failure
  signals when changing workflow YAML.
- Naming, comments, runbooks, logs, and PR-facing explanation must match actual
  runtime behavior. Delete stale prose instead of preserving misleading detail.
- ADRs and publishable docs must match the branch that will receive them. Check
  numbering, status, proposer/owner fields, related links, local-only notes,
  rollout checklists, and references to other docs before including them in a
  PR. Do not ship an ADR that still describes an earlier local-dev-only state.
- Requested plan and policy artifacts need semantic acceptance proof. Name the
  requested artifact and behavior, show where the final result preserves them,
  distinguish artifact fidelity from phase authority, execution authorization,
  and approved behavioral policy, and cite explicit owner authority for any
  reversal, removal, deferral, or phase change. A lint-clean internally
  coherent substitute does not pass this proof.

## Changed Boundary Proof

Trigger this proof only when the diff changes config or flags, SQL result
shaping, transactions, cleanup, retries, or durable side effects. It is part of
this preflight, not another review pass. Build only the applicable rows and
answer each with a focused test, source-level impossibility proof, or exact
`Pending Verification`:

- Config and flags: distinguish omitted, explicitly zero, negative, positive,
  repeated, and conflicting-mode inputs. Do not infer whether a flag was
  supplied from its parsed value when zero is meaningful or must be rejected.
- SQL result shaping: name the logical output key and test zero, one, and
  multiple physical source rows for that key. Prove joins and aggregates cannot
  multiply, drop, or duplicate output unexpectedly, including stale or
  malformed rows that the query claims to tolerate.
- Transaction lifecycle: inventory every begin, commit, rollback, close, and
  uncertain-commit path touched by the change. Exercise active, canceled, and
  expired parent contexts where cleanup or durable bookkeeping must still run.
- Cleanup and detached work: every detached context must have a fresh narrow
  bound unless a repo-backed invariant proves another lifecycle. Prove cleanup
  failure cannot strand a pooled resource, hide a committed effect, or report a
  false terminal state.
- Conditional or effectful counterexample pass: name one assumption that would
  make the implementation wrong, one valid caller or state missing from the
  happy path, one reachable partial-failure or concurrency ordering, one test
  that would stay green while the defect exists, and the observable acceptance
  proof. Fix or disposition every material counterexample; do not stop after
  finding the first plausible issue.

Do not satisfy this proof with a lane name or generic statement. Record the
changed symbol or query, applicable states, evidence, and disposition. If any
applicable row is unanswered, authoring is not ready for reviewer or Copilot
handoff.

## Production-Ready Scope-Growth Proof

When the production-scope behavior activated during planning or the current diff adds
durable persistence, retained observability, or lifecycle machinery, compare
the actual diff with the active objective key and its subordinate mechanism
scope before reviewer handoff. Build a mechanism ledger with the acceptance
criterion or protected invariant served, mandatory current contract,
obligations created, and `keep`, `defer`, or `remove` disposition.

Keep a mechanism only when it directly satisfies an existing acceptance
criterion, is required by a mandatory current contract, or is `protective`:
it maps to a named protected invariant and current evidence proves the change
makes the prevented failure reachable. Otherwise defer or remove it before
reviewer handoff.

Scope grew when the diff adds a mechanism, state, obligation, validation
surface, or materially changed correctness boundary not justified by the
locked acceptance criteria. A correctness boundary includes runtime behavior,
schema or data semantics, auth or privacy, transactions or concurrency, public
contracts, production config or deploy behavior, and operator decisions.

If only mechanism detail changes inside the unchanged objective, increment the
mechanism scope version. If growth changes an objective-owned outcome,
acceptance criterion, invariant, semantic, transition, or non-goal, freeze the
mechanism revision and return to `objective-lock`. After owner approval, start
the new objective version at `mechanisms@v1`. Remove or defer unsupported
mechanisms; keep supported mechanisms only under the three-way rule above.
Scope approval cannot retain an unmapped mechanism or amend the objective.
Preserve every prior objective/mechanism pair, the action-item identity, and
review history append-only. Then rerun the selected authoring lanes and
validation. The mechanism ledger and exact proof, not background narrative or
an acknowledgement, establish readiness.

## Final Orchestration Conformance Reconciliation

Before reviewer dispatch, consume the canonical
[orchestration conformance contract](../../work-orchestration/references/orchestration-conformance.md)
and reconcile its pre-code attestation against the exact stable target. This
lane owns final target binding; it does not create a second attestation schema.

Recheck:

- exact target type and content identity, plus the ordered changed-file
  inventory;
- current objective, acceptance criteria, protected invariants, and non-goals;
- every accepted critic or reviewer recommendation;
- every material scope delta and its append-only disposition;
- the triggered-gate set and current results; and
- current decision-bearing instruction owners changed since the last attestation.

Increment the attestation version when the target, objective, classification,
triggered-gate set or result, retained mechanism, or scope-delta ledger changed.
A known decision-bearing instruction change requires the affected owner to be
reread and the resulting decision refreshed. Do not serialize its path or hash
as conformance proof. Missing, stale, contradictory, or unsupported conformance
blocks reviewer dispatch.

Record the final attestation ID and target identity in the assembled Code Authoring
Handoff Contract. `reviewer-handoff` transports that exact target-bound attestation;
it must not accept the pre-code version as final proof.

## Accepted-Plan Conformance Proof

When `plan-acceptance` activated, consume the canonical
[plan-conformance contract](../../work-orchestration/references/plan-conformance.md)
and reconcile the accepted plan against the exact stable diff in both
directions. Every approved step needs implementation evidence and a
disposition. Every changed file, meaningful hunk, and mechanism needs an
approved step or explicit deviation. Check each preservation and deletion
obligation semantically inside touched files; neither file presence nor a
changed-file inventory proves content survived.

An unapproved surface or semantic loss is `MATERIAL_DEVIATION` and freezes
handoff for `scope-change-control`. A missing unconditional step is
`INCOMPLETE`; if it will be omitted, deferred, reordered, or superseded, return
to `plan-acceptance` for a new user-approved version. A plan-body/content-
identity mismatch is `BLOCKED`. Reviewer dispatch requires `CONFORMANT`; the
reviewer will independently rebuild the mapping rather than trust this ledger.

## Objective-Lock Conformance Proof

When `objective-lock` activated, compare the stable diff and every accepted
critic or reviewer finding with the active lock before reviewer dispatch.
Record each material mechanism as:

- `direct`: required by an acceptance criterion;
- `protective`: causally prevents a proven regression or safety violation made
  reachable by the change and maps to a protected invariant;
- `contract-changing`: changes authority, fallback/error/availability
  semantics, runtime dependencies, synchronization, auth/data ownership, phase
  sequence, acceptance criteria, invariants, or non-goals;
- `unrelated`: does not complete the objective or protect an invariant.

Contract-changing or unrelated mechanisms block reviewer dispatch until they
are removed or deferred. Contract-changing work may proceed only after the
intent owner explicitly amends the contract and the parent records a new lock
version. General approval of an unrelated idea is insufficient; the objective
must explicitly change.

Do not rerun objective lock, critic, or review for wording, formatting,
semantically unchanged generated output, validation/readback, or implementation
details wholly inside an unchanged lock. This prevents objective-lock-generated
duplicate ceremony without suppressing independently required critic,
database-reviewer, ordinary PR reviewer, or user-requested gates.

## Coding Task Handoff Checklist

Before saying a coding task is ready for handoff, analyze the changed repo
surface and check that the implementation is working as expected:

- Lane contract proof: every completed code item recorded a delta check after
  its diff existed, and the assembled stable target ran one full selected-lane
  self-audit before leaving authoring. The proof must include stable target,
  selected lanes, coverage ledger, variance ledger, validation or proof
  selection, and an explicit `next action allowed` decision.
- Next-consumer proof: identify the next command, workflow, runtime, reviewer,
  operator, downstream system, or human decision that consumes this change's
  output. Confirm with current evidence that the produced artifact or state is
  accepted by that consumer. If acceptance cannot be proven, do not claim the
  work is unblocked; mark the missing proof `Pending Verification` and name the
  next blocker that may appear.
- Build/run proof: the code builds, starts, or otherwise runs through the
  narrowest repo-owned command that proves the changed surface. If a full run is
  impractical, name the narrower command and the exact remaining `Pending
  Verification`.
- Test proof: focused tests pass for the changed behavior, and broader tests
  run when shared contracts, generated output, migrations, auth, or public
  behavior changed.
- Behavior-contract proof: conditional changes have a private contract map for
  states, gates, branch precedence, outputs, side effects, errors,
  observability, docs/help/comments, and tests; gaps are fixed or marked
  `Pending Verification` before reviewer handoff.
- Changed-boundary proof: applicable config-presence, SQL-cardinality,
  transaction-lifecycle, and cleanup-context rows are answered with tests,
  source proof, or exact `Pending Verification`; unanswered rows block review.
- Instruction clarity: any new command, workflow, config, flag, script, or
  operator path is clear enough for the next engineer to follow without hidden
  local state.
- Documentation truth: README, runbook, inline help, comments, PR-facing
  explanation, and operator docs are updated when behavior, commands, or risk
  changed.
- Review-response truth: reviewer-facing replies, PR titles, PR bodies, ADRs,
  and operator notes describe the accepted implementation or proposal stage.
  Pending reviewer proposals are not written as completed implementation.
- Performance and observability truth: for any long-running, mutating, or
  shared-environment job, the handoff names the slowest expected statements,
  chunk proof for each expensive statement, first-progress signal, terminal
  progress row, timeout envelope, strict-vs-best-effort telemetry failure
  contract, and any unproven query-plan evidence.
- Review-fix proof: when the current edit claims to resolve review findings,
  record every accepted stable finding ID in one batch; restate each original
  failure mechanism; name the exact changed symbols and files; and close a
  bounded impact cone through sibling code paths that share the mechanism.
  Repository-wide or Git-branch archaeology is not required. For each finding,
  select a regression test that can fail for the original defect when a
  meaningful stable seam exists. Otherwise use focused source-level
  impossibility proof, deterministic contract rejection, or the strongest
  available validation, and record the limitation as `Pending Verification`.
  Detect any newly changed correctness boundary and record the next dispatch
  classification. Reviewer redispatch remains blocked until every accepted
  finding has a disposition and proof record.
- Disputed-finding proof: verify every material critic, reviewer, or database
  reviewer claim against the stable target and active objective before applying
  or discarding it. Apply accepted direct or protective findings; route
  contract-changing findings to the owner for a new lock; defer unrelated
  findings. If premise, target relevance, severity, or consequence remains
  materially disputed, use the bounded peer challenge packets in the
  orchestration conflict-resolution reference. The original specialist owns
  reassessment within its bounded challenge or critic-consultation budget; the
  author must not silently override, relabel, shop for a different verdict, or
  serialize a generic dispute as an `REH-n` response.
- Structure/readability: the code is organized around existing ownership
  boundaries, named clearly, easy to scan, and free of speculative abstraction
  or avoidable duplication.
- Test quality: tests prove the real behavior or failure mode through useful
  public surfaces, not just private helper shape, fixture counts, or mocks that
  cannot fail for the production bug.
- Maintenance posture: generated artifacts, configs, fixtures, docs, and
  source files move together, and stale debug probes or temporary scaffolding
  are removed.

## Review-Fix Topology Proof

Before implementing accepted reviewer findings, record the immutable reviewed
target `H0`, the feedback source, whether the same internal reviewer must
verify its fixes, and the intended next review lane. When provenance-bound
scoped re-review is required, put the complete finding-directed batch in one
new ancestral commit or exact range `H0..H1`; keep unrelated edits out and do
not amend, squash, rebase, or otherwise rewrite that boundary until the scoped
result is terminal. If the boundary was rewritten or contains unmapped work,
do not dispatch scoped re-review; select a fresh full review.

## Skeptical Self-Check

Before handing off:

- focus on changed lines and the nearest context needed to prove risk;
- prioritize security, production data, performance, and correctness before
  style;
- keep a complete disposition ledger for every material self-check candidate;
  a compact top-five summary is allowed only when it states the total and
  overflow count and keeps every overflow item named by stable ID with its
  disposition;
- make every item actionable with a concrete file, line or symbol, and reason;
- prefer recurring patterns on large diffs instead of one-off wording comments;
  and
- do not manufacture comments for small clean changes.

## Output

```text
Authoring preflight:
- covered probes: <probe list with changed surfaces>
- changed-boundary proof: <not triggered or applicable rows with evidence and disposition>
- review-fix proof: <not triggered or H0, feedback source, fix commit/range, ancestry, accepted finding batch, bounded impact cone, proof choices, and next dispatch classification>
- scope-growth proof: <not triggered | objective key + mechanism scope + ledger + disposition>
- plan-conformance proof: <not triggered | plan/version + stable target + step/surface/preservation/deletion reconciliation + result>
- authoring closeout run: <code lanes rerun before handoff>
- handoff checklist: <lane contract proof with stable target, coverage ledger, variance ledger, next-action decision; build/run proof; tests; instructions; docs; structure; test quality; maintenance posture>
- self-check issues: <none or total, top five, overflow IDs, and dispositions>
- Pending Verification: <proof not collected before handoff>
```

This preflight is not a final read-only verdict. It is an implementation-phase
quality gate that should make the final handoff smaller and less surprising.
