# Cross-store cutover

This lane applies to Mongo/Postgres or other cross-store movement, dual
reads/writes, backfills, parity, authority transfer, reversal, or decommission.

- Name the source of truth in every phase and define old/new reader and writer
  behavior during overlap. State authority per operation or record class when
  reads and writes move at different times.
- Prove stable identity mapping, write-during-backfill handling, retry,
  checkpoint, reconciliation, and deletion semantics.
- Require parity evidence independent of the migration job's own success exit
  code. Reconcile missing, duplicate, conflicting, and excluded records.
- Check shadow or mirror sampling, fallback behavior, cutover gates, rollback
  limits, stale-source resurrection, and retirement criteria.
- Verify operator observability, abort thresholds, recovery ownership, and the
  evidence required before each authority transition.
- Canonicalize identifiers before grouping, deduplication, comparison,
  pagination, or checkpointing when multiple storage types or encodings map to
  one logical key. Source-native sort adjacency may not survive decoding.
- Treat hard-coded cross-system identity maps as versioned migration contracts.
  Require current evidence for every target environment, validation for
  duplicates and missing members, and an owner or fail-closed refresh path
  when either system can change independently.
- For dual writes, prove atomicity or an observable repair law for partial
  commits, including idempotency, ordering, retry, and divergence ownership.
- Before retiring the source, prove no stale writer, job, export, cache,
  analytics path, backup workflow, or rollback path can restore old authority.
- Reconcile transformed, deleted, excluded, and stale-source records as explicit
  classes; a source freeze or tail watermark must be enforceable and observable.

Useful evidence: phase matrix, mapping code, job state, immutable source
snapshot, per-bucket reconciliation, shadow comparison artifacts, rollout
flags, runbook, and decommission proof.
