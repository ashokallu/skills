# Data transition and accounting

This lane applies to backfills, imports, repairs, provenance, timestamps,
dry-run/apply, conflict handling, or reconciliation.

- Prove stable source-to-destination identity, conflict key, tenant or shard
  scope, concurrency behavior, deterministic batching, cancellation,
  checkpoints, resume, and rerun after partial failure.
- Inventory every SQL phase from source selection through policy/accounting
  gates, mutation, cleanup, and finalization. Classify each statement as
  chunked or unchunked and read-only or mutating, then prove the largest
  unchunked statement fits the environment runtime and resource budget. Do not
  infer that a job is scalable because its final merge is chunked.
- For a moving source, prove a gap-free snapshot/change-tail handshake with
  durable watermarks and idempotent overlap. Use stable keyset or range progress
  and define how writes during copy are captured, ordered, and reconciled.
- Track provenance creation, clearing, mutation, and trust. Organic writes must not leave legitimate rows vulnerable to later cleanup.
- Make exception rows evidence-complete for the decision they support: retain the relevant source and target identities, versions or timestamps, values, and signed difference without persisting unrelated sensitive payloads.
- Account for per-row triggers, foreign-key checks or cascades, and generated
  columns during backfill or bulk DML. Prove their aggregate lock, WAL, audit,
  and side-effect cost is intended and bounded at representative scale.
- Suppress semantically identical retry writes, including equal-version upserts whose compared content is unchanged, so retries do not rewrite audit timestamps or manufacture change history.
- Reconcile durable committed effects, not attempted statements. Define separate
  attempted, selected, inserted, updated, unchanged, skipped, conflicted,
  failed, unknown, and compensated outcomes; one field must not silently mean
  different things in dry-run and apply.
- Verify timestamp semantics and immutable source snapshot/version. Require per-bucket equations and an exception inventory.

`ON CONFLICT DO NOTHING` is not observability or reconciliation. A transactional batch followed by failed accounting may still have an ambiguous committed outcome.

Treat preflight counts as advisory when concurrent writes can change the
candidate set. Require authoritative selection to be bounded and stabilized
through transaction isolation, locking where supported, or an equivalent
immutable snapshot, watermark, version, or claim/checkpoint contract. Preflight
and mutation must share candidate semantics, though counts may differ under
concurrency. An affected-row rollback guard is secondary correctness proof,
not an operational bound on scan, lock, WAL, replication, or rollback cost.

Validation must be independent of the job's success exit or self-reported
processed count. State checksum or sampling limits, clock/timezone semantics,
and equal, source-newer, target-newer, and missing-side classes. Preserve
per-tenant or per-shard status so fleet totals cannot hide failed or stale work.
Bound downstream trigger, audit, cache/search/CDC, event, retry, memory, temp,
WAL, lag, lock, and transaction amplification at the planned rate.
Adaptive throttling must use current signals, enforced bounds, and an explicit
stop path; independently bound the reconciliation work needed to prove success.

Useful evidence: key map, concurrency and fault-injection tests, run ledger, source/target counts, failure-resume rehearsal, organic-write tests, and exact timestamp assertions.
