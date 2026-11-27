# SQL query and generated contracts

This lane applies to changed SQL, sqlc queries, generated models, stored JSON,
nullability, joins, aggregations, or database-facing caller contracts.

- Prove row identity, cardinality, null and empty-set semantics, join
  multiplicity, filters, tenant scope, ordering, pagination, and timestamp
  behavior.
- Trace query annotations and generated method/type changes into every caller.
  Generated output is evidence of the contract, not proof that the contract is
  correct.
- Check injection boundaries, parameter typing, transaction context, error
  mapping, row-count expectations, and read/write consistency.
- Exercise `NULL` with `NOT IN`, empty and duplicate inputs, nullable joins,
  omitted tenant predicates, nondeterministic `LIMIT`, and pagination over
  changing data when those shapes are possible.
- Compare predicates, joins, grouping, ordering, collations, and operator
  classes to available keys and indexes. Require representative plans when
  runtime claims matter.
- For a complex precondition, accounting, validation, or reconciliation query
  that gates a large mutation, treat query performance as part of correctness.
  Before approval, require the canonical runtime statement or a mechanically
  derived probe to have a representative winning plan and bounded runtime in
  the largest affected environment. Do not defer the first scale proof to the
  mutating job merely because the query runs before the first target write.
- When the production statement mixes decision logic with `INSERT`, `UPDATE`,
  `DELETE`, or `ON CONFLICT`, require a structurally read-only form for safe
  plan and cardinality probes when feasible. Prove that its shared relational
  expression, parameters, null semantics, classifications, and summary counts
  are equivalent to the authoritative persistence form. Keep persistence
  idempotency, affected-row checks, and recomputation inside the authoritative
  transaction independently tested; a faster read-only probe must not become
  stale approval evidence for different DML semantics.
- Inspect PostgreSQL-version-specific CTE behavior, repeated references, and
  explicit `MATERIALIZED` or `NOT MATERIALIZED` choices. For each forced
  boundary, explain whether it protects reuse or enables predicate pushdown,
  then verify the winning plan does not repeatedly rescan or unnecessarily
  materialize a high-cardinality intermediate result.
- Detect duplicate multiplication, missing rows, silent truncation, N+1
  amplification, unbounded scans, and aggregation spill risk.
- For `INSERT ... ON CONFLICT DO UPDATE`, prove the statement source has at
  most one row per conflict key. Pre-aggregate or reject duplicates with a
  domain-level error before one statement attempts to update the same target
  row twice. Separately validate inserted and updated values against every
  other applicable unique constraint; the named conflict arbiter does not
  prove compatibility with independent uniqueness contracts.
- For aggregate or full-outer reconciliation, test multiple physical rows per
  logical key and every equal, left-only, right-only, and differing class.
  Assert exact cardinality, payload nullability, signed delta direction, and
  helper lookup by the full identity key.
- Use declared uniqueness and constraints to remove redundant grouping or deduplication, and project only columns consumed by joins, aggregates, or output, especially inside lateral probes and materialized CTEs.
- Positional bulk operations over parallel arrays or lists must prove equal
  cardinality before binding. Do not let one input choose the iteration length
  while longer inputs truncate or shorter inputs null-pad or fail; test unequal
  lengths in both directions.
- Keep one owner for trigger-maintained timestamps and other generated fields. DML should not redundantly assign them unless the schema contract deliberately requires an override.
- For triggers, views, procedures/functions, policies, materialized views, or
  change-capture definitions, trace dependencies, cardinality, authorization,
  search-path/object resolution, write effects, deployment ordering, and
  rollback behavior.
- For stored JSON or other schemaless values, prove versioning, required and
  optional fields, defaults, type coercion, indexed paths, and forward/backward
  compatibility for every reader.
- Verify generated artifacts are current and that regeneration did not conceal
  unrelated schema drift.
- Define each query mode's truth contract independently, with shared
  normalization and null interpretation for version, ordering, or timestamp
  columns that drive selection. Inspect mode-specific predicate pairs: count
  with mutation, validation with reconciliation, and cleanup with ownership.
  Apply eligibility and validation truth need not be identical; conflict,
  freshness, ownership, or overwrite predicates must not suppress real parity
  differences, and skipped writes remain visible as explained differences.
  Test null, equal, source-newer, and target-newer states.
- When SQL persists a closed category or state vocabulary, keep application
  constants, generated types, filters, tests, and operator queries complete and
  synchronized; flag magic-string members outside the declared set.

Useful evidence: canonical query text or a mechanical derivation test, schema
and constraints, generated diff, caller inventory, representative fixtures,
winning plans, table statistics, read-only/persistence equivalence tests,
idempotency tests, and observed latency when claimed.
