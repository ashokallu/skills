# Live DDL and online schema change

This lane applies to DDL against a nonempty or possibly live relation,
metadata/catalog locks, validation scans, rewrites or copies, online or
concurrent schema-change tooling, cutover, and invalid partial residue.

- Identify the deployed engine/version, storage or table type, extensions,
  replication mode, and migration runner. Classify actual statement behavior:
  metadata-only, instant, in-place, scan, rebuild, copy/rewrite,
  online/concurrent, or blocking. Labels are not proof; classify and gate any
  unsupported or omitted algorithm/lock fallback.
- Determine locks acquired during preparation, execution, validation, commit,
  and cleanup; conflicts, blocker transactions, queue amplification, and
  effects on referenced tables, partitions, indexes, catalogs, or sequences.
- Prove executing-session lock-wait, statement, transaction, idle, retry, and
  cancellation bounds and their precedence. Automatic retry must not turn a
  short timeout into an indefinite lock queue.
- Inspect long-running and prepared transactions, replication apply,
  vacuum/compaction, backup, and maintenance that can delay or be delayed by
  DDL. Define blocker preflight, progress visibility, pause, and abort law.
- Determine DDL transactionality and implicit commits. Online or concurrent
  forms must match the runner transaction mode; partial success must be
  detectable, cleanable, resumable, or safely retryable.
- For online indexes, staged constraints, not-null validation, and foreign
  keys, prove phase scans, both referencing and referenced lock effects,
  concurrent-writer coverage, failure residue, transaction restrictions, and
  final validated/catalog state.
- Inspect shadow-table or change-capture tooling, copy checkpoints, DML
  catch-up, existing triggers, cutover lock, replica/log impact, disk
  multiplier, cleanup ownership, and recovery when copy or swap fails.
- Preserve old/new schema coexistence throughout the operation, including old
  binaries, rollback code, prepared statements, cached plans, replicas, CDC,
  and delayed consumers.
- If constraints, triggers, RLS, replication, or CDC are disabled, treat that
  as a separate integrity boundary. Prove concurrent-writer handling,
  pool/session containment, restoration after every failure, current readback,
  and independent validation of skipped invariants.
- Define entry, cutover, completion, retry/resume, abort, cleanup, and final
  convergence. Inventory invalid indexes, shadow objects, helper columns,
  triggers, not-valid constraints, detached partitions, coordination rows, and
  orphaned jobs after failure or cancellation.

Block candidates include guessed lock/rewrite/transaction behavior, indefinite
wait or retry, critical lock-queue amplification, runner-incompatible DDL,
undetectable partial residue, missing cleanup/completion law, or incompatible
mixed-schema and rollback states.

Useful evidence: exact DDL and runner source, official engine/version behavior,
lock/blocker queries, relation size and write rate, progress and catalog
readback, session timeout/retry settings, representative lock rehearsal,
abort/cancellation evidence, and failed-operation cleanup tests.

When another material database consequence emerges, return to the central
router and add its matching lane. Physical design continues to own query-plan
selection, index-to-predicate design, complete capacity/high-water budgets,
identity/sequence exhaustion, and bounded reconciliation memory or overshoot.
