<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Production Data Safety

Use this lane for SQL, migrations, imports, backfills, dry-run/apply jobs,
bulk writes, generated queries, reconciliation, audits, Cloud SQL, Mongo to
Postgres consistency, production-scale data, or operator safety gates.

When the work is a multi-phase cross-store migration (source-of-truth move,
dual-read/dual-write, datasource cutover, legacy decommission), also load
`data-migration-and-cutover`; this lane keeps the operator/bulk-write safety
gates while that lane owns the phase and parity contract.

## Non-Negotiable Questions

- What is the worst-case production data shape, table size, cardinality, and
  index coverage?
- If this adds a migration, import, apply, materialization, reconcile, validate,
  mirror, cleanup, retry, or read-cutover mode, what is the full cross-mode
  state machine? Name the modes and live paths that must keep agreeing before
  coding.
- Is every query or mutation bounded by chunk, keyset, limit, timeout, or
  operator-controlled scope?
- Does the claimed chunk or cap cover every expensive statement in the phase,
  or only the first/main statement? List restore, insert, delete, validation,
  evidence, cleanup, and progress statements separately.
- For large jobs, how much SQL storage can the run write, how much disk is
  free now, is auto-resize enabled, and what cleanup or approval is required
  before launch?
- If a cap is checked only after a chunk, page, or batch, what is the maximum
  overshoot and transient memory, WAL, lock, and transaction cost? Document the
  enforcement point; even confirmed rollback does not make the nominal cap a
  resource bound, and uncertain rollback needs separate recovery evidence.
- Does dry-run exercise the same semantic path as apply, or can it hide apply
  failures?
- What operator README, runbook, or CLI help defines this mode's preconditions,
  and has each precondition been proven in execution order before authoring or
  recommending a run?
- Is the operation idempotent, resumable, cancellable, and rollback-aware?
- Can a production-scale ordered stream replace per-record state with an O(1)
  monotonicity or contiguity check? Prove ordering after identity decoding and
  canonicalization before removing the growing set.
- What happens on timeout, context cancellation, partial failure, retry, and
  unknown commit outcome?
- For best-effort mirrors, audits, reconciliation writes, failure rows, or
  apply gates, does each effect have its own intentional context and timeout
  budget instead of accidentally inheriting a canceled request or exhausted
  deadline?
- Are generated SQL, mocks, interfaces, fixtures, and consumers updated from
  the owning source?
- Is operator-visible run state durable, structured, and truthful?
- If a failure happens after any durable chunk, merge, delete, restore,
  evidence insert, or secondary effect has committed, does the terminal run
  state record the committed counts and affected scope instead of falling back
  to zero or pre-run defaults?
- Are evidence tables audit-only, or runtime truth used by product code, live
  mirrors, validation, reconcile, or cleanup? Runtime-truth evidence must not
  be deleted by convenience cascades while any path still depends on it.
- Do docs, flags, logs, and PR text say exactly what is and is not covered?

## Authoring Rules

- Do not ship one-shot production-scale scans when a bounded pattern is needed
  unless live evidence proves the one-shot path is safe under production shape.
- Treat staging evidence as non-representative when staging cardinality differs
  materially from production.
- If capped or sampled runs change detection semantics, emit loud operator
  warnings and document the uncovered space.
- For fail-open primary writes with secondary persistence, make the primary
  success path bounded, make secondary failure visibility durable, and avoid
  adding unbounded or surprising latency to the user-facing request.
- For live-write interactions, model races between CTE evaluation, row locking,
  conflict updates, transaction visibility, and stale snapshots. A query that
  computes before waiting on a row lock may update after another transaction
  commits.
- For set-based mutations, compare expected rows with touched rows and verify
  final target state before marking a run complete. Non-zero affected rows is
  not proof that every selected row was applied.
- For chunked mutations, distinguish attempted chunks from committed chunks.
  When a later cap, timeout, validation, or finalization check fails after
  earlier chunks committed, build the failed terminal outcome from the durable
  committed summary, not from an empty local accumulator.
- For grouped or snapshot writes that contain multiple logical rows, decide
  whether one blocked row should fail the whole batch or only that row. If
  unrelated rows should continue, split/filter before the write and record
  durable failure evidence for only the blocked subset.
- For empty source populations, zero selected rows, or no-op operator inputs,
  choose success or fail-fast before creating evidence, acquiring locks, or
  starting long transactions. The terminal state and error must make the no-op
  decision obvious to operators.
- For cleanup and retention, preserve evidence that runtime paths still need.
  Cascading deletes are only safe when no active code, runbook, validation
  query, mirror, or read path depends on the child rows.
- Guard optional dependencies on effectful paths. A disabled or unwired SQL
  querier, publisher, cache, or notifier should not panic a live write path
  unless the domain contract explicitly requires fail-closed behavior.
- Prefer chunked, resumable, keyset-driven paths for large tables and jobs.
- Design operator progress before the first expensive statement starts. A
  progress row that updates only after a successful chunk commit is useful but
  insufficient when the first chunk can run near timeout.
- Do not use shared-environment full runs as performance discovery when query
  plans, row-count probes, restored/local data, or smaller diagnostic chunks can
  expose the same risk. If a diagnostic run is unavoidable, require terminal
  evidence before turning it into code or rollout claims.
- Treat timeout increases as stopgap diagnostics. A durable fix needs query
  shape, index, lock, storage, and progress proof, or an explicit
  `Pending Verification` owner decision.
- Before authoring or recommending a full-source job or retained temporary
  artifact run, require a storage-footprint model: prior run row counts,
  estimated bytes for heap plus indexes, current allocated disk, current bytes
  used, auto-resize settings, and cleanup/retention impact. Do not let
  "auto-resize is enabled" replace an operator warning and explicit decision.
- Prove central data-safety claims with tests, query plans, bounded rehearsals,
  existing production metadata, or explicit `Pending Verification`.
- Model forward, pause/abort, cleanup, rollback, replay, and restore capacity
  independently. One direction's disk, WAL, log, lag, connection, memory, I/O,
  or maintenance envelope is not proof for the others.
- Treat runbooks and README operator sections as source-level safety gates for
  production-data work. Before claiming a mode, flag, or policy is unblocked,
  extract every documented precondition, freshness rule, exact-match check,
  age limit, cap, rollback boundary, and post-run evidence requirement. A new
  policy or code path does not prove older gates that still execute.

## Apply Gate And Reconciliation Probes

When authoring dry-run, apply, mirror, audit, classifier, reconciliation, or
operator gate code, explicitly test the data shapes that decide whether the
gate fails closed or opens:

- missing, malformed, `NULL`, zero, and absent payload fields must not collapse
  into a successful match unless the production data model proves that shape is
  equivalent;
- `NULL` provenance, unknown timestamps, newer target rows, and user-level
  freshness guards must be reviewed as first-class states whenever import,
  validate, reconcile, mirror, or materialization SQL is copied or extended;
- classification, overlay, and audit fixtures must match the real producer's
  persisted fields, including raw evidence fields used for later matching;
- each classification, blocker, or repair class must be reviewed separately
  when its lifecycle differs. Do not assume two accepted classes can share
  delete, restore, insert, validate, or reconcile semantics;
- no-overlay and overlay-required classifications need separate tests when the
  runtime behavior treats them differently;
- operator run IDs must be loaded and checked for existence, terminal status,
  lineage, and impossible persisted states before SQL joins can silently return
  zero rows;
- operator error messages must name the actionable missing evidence, flags, or
  unsafe blocker class instead of wrapping the error into a generic count; and
- logs that claim blockers were resolved, ignored, skipped, or warned must be
  gated on the condition actually being true in the current run.

## Real-World Failure Pattern To Prevent

Real production incidents and near misses often start with a dry-run, audit,
backfill, or reconciliation path that looks harmless in small data but changes
shape at production scale: an uncapped grouped scan, a missing chunk fallback,
sampled evidence presented as complete coverage, or logs that imply more safety
than the code actually provides.

Use this lane to catch those failures while authoring. Make boundedness,
chunking, operator truth, and production-shape proof explicit before review.
The useful outcome is not a longer checklist; it is code and run text that tell
operators exactly what was checked, what was skipped, how retries behave, and
what evidence proves the path will not surprise production.
