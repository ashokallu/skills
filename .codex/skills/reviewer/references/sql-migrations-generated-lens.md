<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-17 (migration-version decision scope) -->

# SQL, Migrations, Data, And Generated Contracts Lens

Use this lens when the review touches SQL, migrations, sqlc, generated models,
OpenAPI/protocol contracts, mocks, fixtures, request/response types, persistence
semantics, cache keys, events, imports, exports, or data pipelines.

## Review Order

1. Identify the source of truth: migration, SQL query, schema, API spec,
   protobuf/OpenAPI file, generated source, fixture, or docs.
2. Compare source-of-truth change to generated output and call sites.
3. Map affected readers, writers, background jobs, caches, requesters, tests,
   dashboards, and rollback paths.
4. For migration or reconciliation state machines, map every mode and live path
   that reads or writes the same truth: apply, materialize, validate, reconcile,
   mirror, product reads, cleanup, retry, and rollback. Review the new SQL
   against the whole state machine, not only the local query.
5. Compare new SQL against adjacent established query patterns for the same
   table or job. If the surrounding code uses chunked, paginated, limited, or
   resumable variants, treat a new uncapped full-table statement as high risk
   until scale proof or an equivalent bounded fallback exists.
6. Check rolling deploy compatibility: old code with new data/schema and new
   code with old data/schema.
7. Classify missing rehearsal, generated proof, or caller evidence as
   `BLOCKED` when central to data safety.

## Source Plus Generated Must Move Together

- Review SQL source, generated sqlc params/results, Go models, mocks, requesters,
  fixtures, tests, and docs together.
- Generated files are not ignorable by default, even when an automated reviewer
  marks them unsupported. Verify source-of-truth change, regeneration proof,
  downstream caller review, and no manual generated edits.
- Source changed without generated output, or generated output changed without
  source, is a hard blocker when generated integrity is central.
- Generated mocks must match generated interfaces and real error/nil/zero-value
  behavior. A mock-only update can make tests wrong-green.
- Generated code that changes serialization, field tags, optionality, enum
  values, or default values is a behavior change even when the diff looks
  mechanical.

## Query Semantics

Check these before accepting a changed query:

- one row versus many rows versus exec shape
- required ordering for pagination, stable tie-breakers, and cursor semantics
- `NULL` behavior, `COALESCE`, default values, empty strings, empty arrays, and
  zero values crossing Go/JSON boundaries
- validated CLI, config, API, or operator values that are converted before
  persistence or SQL comparison: units, rounding, truncation, precision loss,
  overflow, timezone conversion, nullable wrappers, generated type narrowing,
  and whether the post-conversion value still satisfies database constraints
- `LEFT JOIN` filters that accidentally turn into inner joins
- `WHERE` clauses that preserve tenant, user, organization, role, status, and
  soft-delete scope
- provenance fields, updated-at fields, trigger-managed timestamps, audit fields,
  and last-writer-wins semantics
- one canonical owner for trigger-maintained timestamps or generated fields;
  redundant DML assignment can manufacture writes and audit history
- `NULL` provenance, unknown timestamps, newer target rows, stale source
  snapshots, and user-level freshness guards. When extending timestamp-safe
  import, validate, reconcile, mirror, or materialization SQL, prove every
  added branch preserves the same freshness semantics or explicitly fails
  closed.
- duplicate rows from joins, aggregation cardinality, and `DISTINCT` masking a
  modeling bug
- `INSERT ... ON CONFLICT DO UPDATE` sources that can yield the same conflict
  key more than once. Require source uniqueness, aggregation, or explicit
  duplicate detection so one statement cannot target the same row twice or
  fall through to a cardinality violation. Separately inspect inserted and
  updated values against every other applicable unique constraint; the named
  conflict arbiter does not cover independent uniqueness contracts.
- `SELECT *`, column order dependency, positional scan drift, and generated
  struct field drift
- row locks, transaction isolation, `FOR UPDATE`, lock ordering, and deadlock
  risk
- CTE evaluation time versus conflict-update time. A statement can compute an
  amount or filter before waiting on a row lock, then update after another
  transaction commits; review both moments when live writes and jobs touch the
  same rows.
- cache invalidation, derived data refresh, event emission, and index coverage
  for new access paths
- raw SQL string construction, unescaped identifiers, and parameter binding
  when user input, tenant data, or dynamic filters are involved

## Migration Safety

Migration-central changes require explicit evidence for:

- old-code/new-schema compatibility
- new-code/old-schema compatibility
- old-code/partially-backfilled-data compatibility
- destructive DDL sequencing and data preservation
- lock/runtime risk, statement timeout, lock timeout, and retry plan
- concurrent index strategy or equivalent for large tables
- chunked, idempotent, resumable backfills with progress and failure visibility
- `SET NOT NULL`, constraint, enum, and foreign-key sequencing after data is
  prepared
- default-value and trigger behavior for old and new writers
- down migration or rollback story that preserves data semantics, not only
  schema syntax
- claimed repeatability or partial-apply safety when objects are already absent,
  including whether table ownership makes separate object drops unnecessary
- evidence-table retention. If product reads, live mirrors, validate, reconcile,
  cleanup, or operator gates depend on evidence rows, those rows are runtime
  truth and must not cascade away while any active path still needs them.
- rehearsal evidence, migration plan, post-deploy validation, and operator
  escape hatch when data safety is central

Treat missing rolling-deploy or migration rehearsal proof as `BLOCKED` when the
change can corrupt, delete, hide, or make production data unreadable.

## Shared Environment Migration Version Drift

When a PR adds or renames files under
`backend/internal/shared/sql/migrations/`, check whether any shared environment
has already applied the new migration version from an unmerged branch. Shared
environments include Staging and any long-lived test database used by manual
release workflows.

The risky state is not the existence of migration files or a newer
non-conflicting base migration by itself. A same-version, different-content
collision against the current base is a direct integration defect. A newer
non-conflicting base migration is an ordering or rebase concern. A shared
database recording a migration version absent from the release-driving branch
is an environment-state concern whose impact depends on whether it was applied
and conflicts with the reviewed target.

Reviewers should require one of these reconciliation proofs before clearing the
risk:

- the exact migration `up` and `down` files have landed, or are ordered to land,
  on the release-driving branch before other releases can consume that version
- the shared environment was deliberately rolled back or reset so its migration
  metadata and schema are back in sync with the release-driving branch
- the team has explicitly reserved the consumed version and all pending
  migration work starts at the next version, with the missing mainline
  reconciliation tracked as an operator-owned follow-up

If the current base contains the same version with different content, emit the
integration finding without inventing runtime impact. If applied state is
unknown, keep it under `Pending Verification` and block only deployment or
execution when that fact is central. The evidence needed should name the
environment, database migration version, reviewed head, release-driving branch,
and exact reconciliation path. A source-only migration does not invalidate live
environment evidence, and a newer non-conflicting migration does not
automatically block merge.

## Backfills, Imports, Reconciliation, And Bulk Paths

- Prefer set-based SQL and bounded batch operations. Flag row-by-row application
  loops or unbounded in-memory accumulation when data volume can grow with
  tenants, learners, courses, events, or imports.
- Backfills must be idempotent, resumable, scoped, observable, and safe to rerun
  after partial failure.
- Idempotency must account for future replacement or rerun shapes, not only
  exact same-run retry. Population-scoped uniqueness is insufficient when a
  later run can represent the same semantic user/category repair again.
- Check dry-run behavior, limits, chunk ordering, checkpointing, retry behavior,
  cancellation, and operator visibility.
- Mutation-capable dry runs, audits, validations, release gates, and apply paths
  must prove the same semantic space they authorize. Caps, samples, or scoped
  checks must be enforced at mutation time or clearly marked as partial evidence.
- Durable run records, logs, metrics, and summaries must not report global
  cleanliness, success, rollback, counts, or failure reason incorrectly after
  skipped rows, changed detection semantics, rollback, partial apply, or unknown
  commit outcome.
- Set-based mutations must compare expected selected rows with affected rows
  and verify final target state before marking a run completed. Non-zero
  affected rows can hide partial application.
- For nullable freshness, version, or ordering columns, require explicit null
  ordering and shared normalization, then verify mode-specific predicate pairs:
  preflight count with its mutation, validation with reconciliation, and
  cleanup with its ownership contract. Do not require apply eligibility and
  validation truth to be identical; intentionally skipped writes must remain
  visible as explained differences.
- Grouped or snapshot writes need partial-blocking semantics review. If one
  blocked row in a batch should not prevent unrelated rows from being written,
  verify filtering happens before the write and the blocked subset gets durable
  failure evidence.
- Empty source populations, zero selected rows, or no-op operator inputs should
  reach a deliberate terminal state before evidence rows, locks, or final-table
  mutations begin. Late generic failure after partial setup is reviewable.
- Operator run IDs passed to SQL must be checked for existence, terminal status,
  lineage, and impossible persisted states before joins are allowed to return
  no rows and look clean.
- For audit or reconciliation SQL on production-sized tables, verify the query
  is bounded by a chunk key, limit, partition, checkpoint, or other resumable
  window when nearby validation/import queries use that pattern. If the review
  accepts a deliberate one-shot full-table scan, require explicit evidence such
  as `EXPLAIN (ANALYZE, BUFFERS)` or production-scale rehearsal, plus the
  timeout, `work_mem` or temp-file, snapshot-duration, and retry/fallback story.
- For cross-store proof such as Mongo-to-Postgres audits and imports, verify
  source read preference and staleness assumptions: secondary versus primary
  reads, the staleness window relative to any freshness gate, and that the
  read used for proof and the read used for apply observe the same consistency
  window.
- Watch unsafe deletes, truncate/drop paths, broad updates without tenant or
  status scope, and non-idempotent derived-data writes.
- Positional bulk operations over parallel arrays or lists need equal-cardinality
  proof, empty-input behavior, and unequal-length tests in both directions. One
  input must not choose an iteration length that silently truncates, null-pads,
  or misaligns the others.
- Import/export changes need encoding, CSV/JSON/schema compatibility, timezone,
  locale, duplicate rows, partial failures, and PII handling review.

## Data Integrity And Privacy

- Tenant/user/organization scope must be present at the data boundary, not only
  in frontend filters or caller comments.
- Permission-sensitive data must not be cached, generated, exported, logged, or
  surfaced under a key that omits the permission or tenant dimension.
- PII, learner progress, sensitive account data, and internal identifiers in
  fixtures, logs, snapshots, analytics, or generated docs need minimization and
  redaction.
- Soft-delete, archive, restoration, and audit semantics must remain consistent
  for both readers and writers.
- Cross-store consistency between Postgres, Mongo, caches, queues, events, and
  search/analytics must be explicit when the diff touches more than one store.
- Timezone, clock source, and precision changes can break ordering, expiry,
  dedupe, progress, or reconciliation.

## API, Event, Cache, And Protocol Compatibility

- Public request/response fields need additive-compatible rollout or proof that
  all clients update atomically.
- Removing, renaming, narrowing, or changing optionality/defaults in API fields,
  event payloads, cache values, or queue messages needs backward/forward
  compatibility evidence.
- Version cache keys or event schemas when old and new consumers can overlap.
- Check stale clients, retries, duplicate events, out-of-order events, partial
  migrations, and dead-letter handling.
- Cache invalidation must hit every tag/key/tenant/user combination that can
  observe stale data, and must not evict unrelated tenants broadly without need.

## SQL Performance And Scale

- New high-cardinality access paths require index, EXPLAIN, table-size, query
  plan, benchmark, or repo-scale evidence before accepting performance claims.
- Check N+1 queries, unbounded scans, leading-wildcard search, missing limits,
  expensive sorts, pagination without stable order, and cross-tenant scans.
- Bounded output is not bounded work. For queries with `LIMIT`, pagination,
  sample caps, chunk sizes, `FILTER`, top-N selection, or capped evidence
  payloads, inspect which scans, joins, sorts, aggregates, expressions, and JSON
  construction happen before the bound applies. Prefer narrowing first, then
  computing expensive payloads only for kept rows.
- Derived aggregates should justify their cost. Remove `DISTINCT`, duplicate
  joins, re-aggregation, materialization, or extra scans when current keys and
  join shape already prove the same result. If the redundancy is intentional
  future proofing, require a comment that names the expected divergence.
- State-shape changes require downstream predicate review. When rows move
  between tables, categories, states, evidence shapes, or blocking/non-blocking
  paths, re-check gate predicates, cleanup queries, report queries, metrics,
  docs, and tests for stale assumptions.
- Classification-aware paths must review each classification separately when
  lifecycle differs. Do not let one accepted class stand in for another on
  delete, restore, insert, validate, reconcile, read, or cleanup behavior.
- Overlap checks must use the same logical key as the uniqueness rule,
  downstream pin, and retry semantics. A user-only check can be too broad when
  the invariant is user/category; a user/category check can be too narrow when
  downstream accepts only one run per user.
- Schema additions must compare against local structure. Compare every new
  index, timestamp column, trigger expectation, and uniqueness rule to sibling
  migrations, primary keys, and existing indexes. A strict left-prefix duplicate
  usually adds write/upsert cost without improving reads; either drop it or
  justify the distinct access path, covering columns, or index-only scan it
  enables.
- Treat full-table `GROUP BY`, `DISTINCT`, `FULL OUTER JOIN`, `MATERIALIZED`
  CTEs, broad joins, and aggregate reconciliation queries over ledger,
  progress, event, or import tables as production-safety risks when they are
  uncapped. Ask what happens under statement timeout, temp-file spill, and long
  snapshots, and whether the operator has a chunked or scoped retry path that
  preserves detection semantics.
- Verify which connection the changed query path actually uses: primary or
  read replica. For long reads on a hot-standby replica, require the
  recovery-conflict survival story: expected duration versus conflict
  cancellation behavior, retry or chunked fallback, and whether moving the
  read to primary changes load, locking, or isolation assumptions. Replica
  versus primary routing changes both safety and detection semantics.
- For large table writes, inspect lock mode, transaction duration, batch size,
  autovacuum/index impact, timeout, and operational rollback.
- Performance evidence from a tiny fixture is not proof at example-app scale;
  use residual risk or request targeted evidence when central.

## Fixtures, Tests, And Snapshots

- Fixtures must model the actual data states the production path can encounter:
  multiple tenants, empty/null fields, stale rows, deleted rows, duplicates,
  migrated and unmigrated rows, and permission denial.
- Snapshot/golden changes that include generated contracts are behavior changes.
  Require isolated semantic diff and source-of-truth explanation.
- SQL tests should assert result shape, ordering, scoping, null handling, and
  update side effects, not merely no error.
- Migration tests should cover apply, rerun/idempotency, rollback/down where
  meaningful, old/new compatibility, and post-deploy validation when central.

## Specialist Routing

Reviewer still gives the best bounded verdict first. Route only when specialist
evidence materially improves the verdict:

- migration or SQL specialist for destructive DDL, large backfills, complex
  locking, or contested query plans
- data/platform owner for ownership, retention, or data-governance decisions
- backend/frontend specialist for contract consumers outside the reviewed slice

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- migration can lose, corrupt, lock, or make data unreadable without safe
  rollout/rollback proof
- audit, reconciliation, import, or backfill SQL can scan or aggregate a
  production-scale table in one uncapped statement without plan evidence or a
  bounded retry/fallback path
- generated source and source of truth are inconsistent
- tenant/user/permission scope is missing in query, cache, event, or generated
  contract
- query semantics change result cardinality, ordering, null handling, or
  pagination in a user-visible way
- old/new versions are not rolling-deploy compatible
- backfill/import/export path is unbounded, non-idempotent, or not observable
- release gate, audit, or dry-run can authorize a broader mutation than it
  actually proved, or can mislead operators about skipped, capped, partial, or
  unknown-outcome work
- validation cannot exercise central data-safety behavior
