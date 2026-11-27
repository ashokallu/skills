<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Data Migration And Cutover Authoring

Use this lane when work moves a data domain between stores or owners:
Mongo-to-Postgres migrations, source-of-truth changes, dual-read or dual-write
phases, backfill jobs with parity checks, datasource switches behind flags,
read-path cutover, write-path cutover, decommission of a legacy store, or
reconciliation between two live copies of the same domain.

This lane owns the multi-phase migration shape. It does not replace
`sql-migrations-and-data-contracts` (schema/DDL/contract movement),
`production-data-safety` (operator gates for bulk writes), or
`jobs-queues-and-schedulers` (the backfill job mechanics); load those for the
concrete artifacts.

## Mission

A cross-store migration is safe only when, at every phase, exactly one store
is authoritative per operation, divergence between stores is measured rather
than assumed, and every phase has a rehearsed reverse path. The failure mode
is not a bad query; it is weeks of silent divergence discovered after the
legacy store is gone.

## Boundaries

Also load:

- `feature-flags-rollout` for the datasource switch, phase gating, and
  old/new deploy behavior;
- `concurrency-caching-consistency` for dual-write races, read-after-write
  across stores, and cache keys that must encode the active source;
- `production-data-safety` before any backfill, repair, or bulk write runs
  against production-sized data;
- `observability-and-operations` for parity dashboards, divergence alerts,
  and operator runbooks per phase;
- `value-and-release-readiness` before recommending a phase transition.

Do not begin write-path changes until the read-parity evidence for the
already-migrated data exists or the missing evidence is explicitly
`Pending Verification`.

## Authoring Sequence

1. Name the phase this change belongs to and the invariant it must preserve:
   (a) new store shadow/backfill, (b) dual-write with legacy authoritative,
   (c) read cutover, (d) new store authoritative with legacy fallback,
   (e) legacy decommission. Code that mixes phases needs an explicit reason.
2. Build the applicable phase matrix before implementation. For every phase
   name exact artifacts and schema versions, targets, active readers/writers,
   authority, entry evidence, durable state, checkpoint, rate/concurrency
   bound, progress, stop threshold, owner, failure residue, retry/resume,
   rollback/forward-fix/restore options, last reversible point, exit evidence,
   and the enforced next gate.
3. Define per-field mapping as a contract: source field, target field, type
   conversion, null/absent semantics, ID mapping strategy, timezone/precision
   handling, and which side wins on conflict. Ambiguous fields are findings,
   not TODOs.
4. Make the backfill resumable and idempotent: chunked by a stable key,
   checkpointed run state, safe to re-run over already-copied rows, bounded by
   caps and dry-run mode, and rate-limited against the source store.
5. Handle writes-during-backfill deliberately: change capture, re-copy window,
   dual-write start ordering, or a stated freeze — pick one and document why
   rows written mid-backfill cannot be lost or duplicated.
6. Build parity verification as its own artifact, not a side effect: count
   parity, checksum or field-level sample comparison, divergence report with
   concrete row IDs, and a threshold that gates the next phase.
   Define validation predicates independently from mutation eligibility.
   Freshness, ownership, conflict, or overwrite rules that protect writes must
   not suppress a real parity difference unless validation records that state
   explicitly. Cover source-newer, target-newer, equal, and null-version cases.
7. Keep the switch reversible at every phase: a single datasource flag or
   config with known propagation time, no schema or code change required to
   flip back, and a stated data-loss window (writes to the new store after
   cutover) for reverse cutover.
8. In dual-write, decide failure semantics explicitly: if the secondary write
   fails, does the operation fail, retry async, or record divergence? Never
   let secondary failure silently succeed without a divergence record.
9. Decommission last and slowest: legacy reads removed only after sustained
   parity, an owner decision, and a retention window; keep an export or
   snapshot before destructive cleanup.
10. Canonicalize identifiers before grouping, deduplication, ordering,
   pagination, or checkpointing when multiple source encodings map to one
   logical key. Source-native sort adjacency is not proof of canonical
   adjacency.
11. Treat preflight counts as advisory when concurrent writes can change the
    selected set. Bound and stabilize authoritative selection through
    transaction isolation, locking where supported, or an equivalent immutable
    snapshot, watermark, version, or claim/checkpoint contract. Preflight and
    mutation must share candidate semantics, though counts may differ under
    concurrency. Treat affected-row rollback as a secondary correctness
    assertion, not an operational bound: scan, lock, WAL, replication, and
    rollback cost still need a proven envelope.
12. When a later run reuses a prior run's staged or diagnostic artifacts, do
    not trust terminal status alone. Prove the reusable phase completed under
    compatible source, lineage, caps, and scope, and that retained artifact
    identity and cardinality match recorded accounting for zero and non-zero
    counts. Treat zero as a no-artifact sentinel only when that contract is
    explicit and proved. Normalize inherited metrics to the new run's semantic
    baseline before adding newly produced results.

## Prevention Probes

- Which store is authoritative for each read and write path in this diff, and
  can any caller disagree during a rolling deploy?
- Can a row written during backfill, retry, or reverse cutover be lost,
  duplicated, or resurrect deleted data?
- Do ID mappings survive re-runs, and can two source rows map to one target
  row (or one to two) without detection?
- Does the parity check compare semantics (normalized values) rather than raw
  bytes, and does it cover recently-written rows, not only the backfilled
  snapshot?
- Can a mutation-protection predicate make validation falsely clean? Require
  shared normalization and null interpretation, but mode-specific eligibility:
  preflight count must match its mutation, while validation must match
  reconciliation and keep intentionally skipped writes visible as explained
  differences.
- Are nulls, missing fields, empty strings, zero values, and legacy sentinel
  values converted with the same meaning on both sides?
- Does read-after-write hold for a user whose write went to one store and
  next read may hit the other (cache, replica, or flag propagation)?
- Is there a divergence record and alert when dual-write partially fails, or
  does the happy path stay green?
- Can the operator tell, from run state and dashboards alone, which phase is
  active and whether it is safe to advance?
- Does contract cleanup wait until stale binaries, jobs, retries, replicas,
  consumers, and the declared rollback window are drained or unable to use the
  old shape or authority?

## Validation

Prefer: dry-run backfill output over a bounded production-representative
sample; parity report artifact with counts, checksums, and named divergent
IDs; a rehearsed flag flip in staging including reverse; failure-injection
tests for secondary-write failure and mid-backfill writes; and idempotency
proof by re-running the backfill over a completed chunk. Live production
evidence the author cannot collect stays `Pending Verification` with the exact
command or artifact the operator must produce.

## Output

```text
Data migration/cutover authoring:
- phase and invariant: <a–e phase, authoritative store per path>
- mapping contract: <fields/IDs/conflict rule location>
- backfill safety: <chunking, resume, idempotency, caps, dry-run>
- parity evidence: <report artifact or Pending Verification>
- reversibility: <flip mechanism and data-loss window>
- divergence handling: <dual-write failure semantics and alerting>
- proof: <rehearsal/tests or Pending Verification>
```
