<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# SQL, Migrations, And Data Contracts Authoring

Use this lane for SQL queries, schema migrations, sqlc inputs/outputs, seed or
fixture data, generated models, data contracts, cache/event schemas, imports,
exports, analytics/data-pipeline surfaces, and persistence changes that must
stay compatible across old and new code.

## Mission

Move source schema, generated code, callers, tests, and operator truth together.
A migration or query is not ready because it compiles locally; it is ready when
old/new runtime compatibility, data shape, lock behavior, generated artifacts,
and rollback/recovery expectations are explicit.

## Boundaries

Also load `production-data-safety` for production-scale tables, bulk writes,
backfills, imports, dry-run/apply paths, reconciliation, or operator gates. Load
`backend-codegen` for sqlc/mockery mechanics, `backend-go` for Go call paths,
`api-contracts-and-integrations` when persistence shapes cross an API boundary,
and `efficiency-and-scale` when query cost or index choice matters.

Do not perform production mutations or broad live scans as part of authoring
proof. Request bounded artifacts or mark them `Pending Verification`.

## Authoring Sequence

1. Name the data contract: table/query/schema/source-of-truth, generated output,
   producer, consumer, runtime compatibility window, and rollback expectation.
2. Inspect current schema, existing migrations, sqlc queries, generated Go,
   fixtures, consumers, indexes, constraints, docs, and tests before editing.
3. Choose an expand/contract or backward-compatible sequence when rolling
   deploys can run old and new code against the same database.
4. For new columns, constraints, indexes, enum-like values, or foreign keys,
   decide nullability/default/backfill/order before writing DDL.
   Choose referential actions from each row lifecycle, and keep one owner for
   trigger-maintained timestamps or generated fields rather than assigning the
   same value independently in DDL and DML.
5. For query changes, check cardinality, join semantics, duplicates, ordering,
   pagination, `NULL` behavior, isolation/locking, and partial-result states.
6. Edit the source query/schema/migration first; regenerate derived artifacts;
   inspect generated diffs instead of hand-editing outputs.
7. Update fixtures, mocks, repository tests, API/requester contracts, and docs
   in the same slice as the persistence contract.
8. For rollback/down migrations, state whether the path is reversible,
   destructive, data-preserving, or intentionally no-op with operator warning.
   If it claims repeatability or partial-apply safety, make already-absent
   objects harmless and use ownership-aware teardown where appropriate.
9. Give migrations and generated artifacts immutable identity or checksums that
   reviewers, release tooling, and operators can match to the executed target.
10. Design application rollback, schema rollback, data reversal, compensation,
    forward fix, and restore as distinct paths when applicable. Prefer
    application rollback against an additive forward schema when that avoids a
    more dangerous live down migration, and name the last reversible point.
11. For phased live single-store DDL or schema work, build the applicable
    expand/backfill/validate/contract matrix before implementation. Name active
    versions and readers/writers, entry and exit evidence, bounds, stop owner,
    failure residue, recovery options, and the enforced next gate for each
    phase.

## Prevention Probes

- Can old code run after the migration and can new code run before/after it
  during deploy, rollback, worker lag, or queue replay?
- Will a `NOT NULL`, unique, FK, enum, check constraint, or default fail on
  existing rows or writes from older code?
- Does any validated CLI, config, API, or operator value get converted before
  persistence or SQL comparison? Check units, rounding, truncation, overflow,
  precision loss, timezone conversion, nullable wrappers, and generated type
  narrowing against the final database constraint, not only the pre-conversion
  validation. A positive duration, count, or amount can become invalid after
  conversion.
- Does an index need concurrent creation, partial predicate, covering columns,
  or a separate validation step to avoid locks or table scans?
- Do joins multiply rows, drop rows, or turn absent/`NULL` data into false
  success?
- Can one `INSERT ... ON CONFLICT DO UPDATE` statement produce multiple source
  rows for the same conflict key? Prove source uniqueness by construction,
  pre-aggregate it, or detect duplicates and fail with a domain error before
  PostgreSQL rejects a second update to the same target row.
- Separately verify that inserted and updated values satisfy every other
  applicable unique constraint; uniqueness for the named conflict arbiter does
  not prove compatibility with independent uniqueness contracts.
- Do queries rely on nondeterministic order, offset pagination on changing
  data, timezone-sensitive comparisons, or local-only row counts?
- Do positional bulk operations over parallel arrays or lists prove equal
  cardinality before binding? Test longer and shorter companion inputs so one
  array cannot silently truncate, null-pad, or misalign the others.
- Are generated types, mocks, fixtures, snapshots, docs, and cache/event schema
  consumers updated from the owning source?
- Do tests prove semantics rather than just accepting changed generated output?

## Validation

Use the narrowest deterministic proof available:

- migration up/down on a local test database or migration harness;
- sqlc/generator command plus compile/tests for generated call sites;
- query tests covering `NULL`, empty, duplicate, stale, and permission-scoped
  rows;
- `EXPLAIN`, estimated cardinality, or bounded rehearsal when production scale
  can change query plan or lock behavior;
- focused regression tests for old/new compatibility when deploy order matters.

When production shape proof is unavailable, record the missing query plan,
cardinality, table size, lock rehearsal, or migration command as
`Pending Verification` and do not claim production readiness.

## Output

```text
SQL/data authoring:
- contract: <table/query/migration/generated source>
- compatibility: <old/new, up/down, nullable/default/backfill decision>
- generated artifacts: <regenerated paths or not needed>
- proof: <migration/query/generator/test command or Pending Verification>
```
