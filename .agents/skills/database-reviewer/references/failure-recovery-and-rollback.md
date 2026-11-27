# Failure, recovery, and rollback

This lane applies to multi-step work, partial failure, retry/resume, ambiguous
outcomes, down SQL, cleanup, or restoration.

- Distinguish schema rollback, application rollback, data rollback, forward fix, and restore. Inspect failure after every meaningful commit boundary.
- Also distinguish compensation and failover. For each phase identify the last
  reversible point and prove rollback binaries can read data already written by
  forward code.
- Prove run identity can resume or define a safe new-run recovery law. Check partial commit, connection loss, timeout, cancellation, and repeated startup behavior.
- Map database commits against messages, files, remote calls, cache/search
  updates, acknowledgements, and user-visible effects. Ambiguous outcomes need
  correlation identity, idempotent retry or compensation, and reconciliation.
- For reuse of terminal run artifacts, require phase-level completion evidence,
  compatible source lineage, caps and scope, plus retained artifact identity
  and cardinality consistent with recorded zero and non-zero counts. Treat zero
  as a no-artifact sentinel only when that contract is explicit and proved.
  Normalize inherited accounting to the new run's semantic baseline before
  adding new results.
- Treat down SQL that deletes business rows as a retention decision, not a routine inverse. Prove exact ownership and affected count, including rows changed by organic writers after up.
- If down SQL is advertised as repeatable or safe after partial application, prove every referenced object can already be absent. Prefer ownership-aware teardown over separately dropping table-owned objects that disappear with their parent.
- For concurrent pipelines, preserve every independent stage failure while
  distinguishing caller or deadline cancellation from cancellation deliberately
  issued during successful shutdown. Test both paths so cleanup cannot turn
  success into failure or hide the initiating cause.
- Account for invalid or partial indexes, shadow tables, triggers, swapped
  views, coordination rows, and jobs left by failed physical or phased work.
- Inventory every residue and recovery horizon immediately before and after
  each commit, authority-transfer, or irreversible boundary.
- For sharded or partitioned work, define recovery when only a subset advances,
  rolls back, or restores to an earlier point; revalidate cross-target authority
  and invariants afterward.
- Bound the lock, WAL, bloat, disk, lag, and vacuum impact of rollback or
  cleanup. A logically correct rollback can still be the larger outage path.
- Verify the availability, recovery time, and acceptance criteria of backup or
  PITR used by the recovery plan.
- When approval relies on backup, snapshot, PITR, replica promotion, or another
  restore mechanism, configuration presence is not recovery proof. Inspect the
  most relevant successful recovery exercise, artifact and scope, observation
  time, recovery point or loss window, duration, integrity validation, and
  unresolved coverage gaps.

A deliberately irreversible migration may pass only when the recovery policy
and consequences are explicit and accepted.

Useful evidence: up/down/up fixture diff, injected failures, ownership query, dry-run count, restore capability, runbook, and accountable owner acceptance.
