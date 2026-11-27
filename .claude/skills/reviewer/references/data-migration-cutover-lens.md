<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Data Migration And Cutover Lens

## Mission

Review multi-phase cross-store data movement: Mongo-to-Postgres domains,
source-of-truth changes, dual-read/dual-write phases, backfill jobs and their
parity checks, datasource switches, read-path and write-path cutover, reverse
cutover, and legacy store decommission.

## Ownership And Boundaries

This lens owns the migration phase model: which store is authoritative per
operation, how divergence is measured, and how every phase reverses. Defer
Postgres DDL/lock/index safety to `migration-safety-lens` and
`sql-migrations-generated-lens`, backfill job mechanics (retry, ack, resume)
to `jobs-queues-schedulers-lens`, the datasource flag contract to
`feature-flag-rollout-lens`, dual-write races and cache correctness to
`concurrency-caching-consistency-lens`, and operator run-state evidence to
`observability-ops-lens`. This lens almost always co-triggers the Production
Blast-Radius Gate; when central parity or reversibility proof is missing,
escalate through reviewer core and Risk Evidence Handoff instead of treating
it as ordinary residual risk.

Do not demand a full five-phase program for a bounded one-off copy with owner
sign-off; scale the contract to the domain's blast radius.

## Evidence And Dedupe

A finding needs the migration phase, the operation whose authoritative store
is wrong or ambiguous, and the reachable loss/duplication/divergence
sequence. Group per-field mapping defects sharing one conversion root cause.
Evidence includes the mapping code, backfill job and its run-state contract,
parity-check artifacts, the datasource flag and its readers, dual-write error
handling, runbooks, and dry-run or staging reports at the reviewed head.

## Review Probes

- For each read and write path in the diff, which store is authoritative in
  the current phase — and can any caller, cached bundle, or mid-rolling-deploy
  instance disagree?
- Can a row written during backfill, retry, or reverse cutover be lost,
  duplicated, or resurrect deleted data? Is the writes-during-backfill
  strategy (change capture, re-copy window, dual-write ordering, freeze)
  stated and implemented, not assumed?
- If a chunked apply, backfill, repair, or reconcile phase fails after some
  durable chunks commit, does the terminal run state preserve committed counts,
  affected scope, and retry interpretation instead of reporting zero or only
  the failed final check?
- When a run reuses a terminal run's staged or diagnostic artifacts, does it
  prove phase-level completion, compatible source/lineage/caps/scope, and
  retained artifact identity and cardinality consistent with recorded zero and
  non-zero counts rather than trusting status alone? If zero is treated as a
  no-artifact sentinel, is that contract explicit and proved? Are inherited
  counters normalized before new results are added so prior exceptions are not
  counted twice?
- Is the backfill chunked by a stable key, checkpointed, idempotent over
  already-copied rows, capped, and dry-runnable — or a single unbounded pass?
- Does parity verification exist as an artifact (counts, checksums or
  field-level samples, named divergent IDs) with a threshold gating the next
  phase, or is parity asserted from the backfill's own success exit code?
- Are validation predicates independent from apply eligibility, freshness,
  conflict-resolution, and last-writer-wins rules? A write may correctly skip
  an older source while parity review must still surface the difference or
  classify it as an explicit explained state.
- Is a preflight count treated as advisory under concurrent writes, with the
  authoritative candidate set bounded and stabilized through transaction
  isolation, locking where supported, or an equivalent immutable snapshot,
  watermark, version, or claim/checkpoint contract? Preflight and mutation must
  share candidate semantics, though counts may differ under concurrency. An
  affected-row rollback guard is secondary proof, not an operational bound.
- Are nulls, missing fields, empty strings, zeros, sentinel values, IDs,
  timezones, and precision converted with the same meaning on both sides?
- If a dual write partially fails, does the operation fail, retry, or record
  divergence — or does the happy path stay green with silent drift?
- Does read-after-write hold for a user whose write hit one store while the
  next read may hit the other (flag propagation, cache, replica lag)?
- Is every phase reversible by a single flag/config flip with a stated
  data-loss window, and has the reverse been rehearsed anywhere?
- Is decommission gated on sustained parity, an owner decision, and a
  retention snapshot — or does this diff delete the legacy path early?
- Can the operator tell from run state and dashboards which phase is active
  and whether advancing is safe?

## Triage

Promote: ambiguous authority for any write path, lossy or duplicating
backfill windows, parity claimed without a comparison artifact, silent
dual-write divergence, irreversible cutover steps, and premature legacy
deletion. Keep phase-plan style preferences and hypothetical divergence with
no reachable write path as advisory.

## Output Discipline

Findings state the phase, the operation, the interleaving or conversion
sequence, and the smallest contract fix or missing artifact. Central parity,
staging rehearsal, or production readback evidence the reviewer cannot
collect read-only goes to Risk Evidence Handoff; a BLOCKED verdict must state
whether staging-only execution can unblock merge or production evidence is
also required. If clean, the selected-lens audit names the phase reviewed,
the authoritative-store map checked, and the parity/reversibility artifacts
inspected.
