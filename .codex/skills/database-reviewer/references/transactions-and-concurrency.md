# Transactions and concurrency

This lane applies to multi-statement writes, read-modify-write paths, isolation
settings, row or advisory locks, write retries, claim/queue patterns, or
concurrent-writer safety claims.

- Identify the transaction boundary, effective isolation, snapshot scope,
  autocommit, savepoints, and connection/pool mode. Do not assume values read
  earlier remain current when the engine or level permits a newer snapshot.
- Map what commits together, what can commit separately, and which readers can
  observe intermediate state. Partial multi-table, multi-shard,
  database/message, or database/cache commits need an explicit recovery and
  visibility contract.
- For read-then-write paths, prove the write is atomic through a conditional
  statement, row lock, version predicate, or equivalent conflict detector.
  An application decision followed by an unconditional write is a lost-update
  candidate.
- For invariants spanning rows, predicates, or time windows, test write skew and
  phantoms. Require a
  database-enforced invariant, sufficient predicate locking, serializable
  execution, or another mechanism whose coverage is proven.
- Check one consistent acquisition order for paths holding multiple locks and
  bounded lock waits for latency-sensitive callers. Define `NOWAIT`, skipped
  locks, timeout, deadlock, and partial-acquisition behavior.
- Where deadlocks, serialization failures, connection loss, or ambiguous commit
  outcomes can abort work, require bounded retry semantics and prove every
  repeated database and external side effect is idempotent. A retry loop is not
  safe merely because the transaction may have rolled back.
- Keep lock-holding transactions bounded. External I/O, user interaction,
  unbounded scans, or missing statement and idle-in-transaction timeouts are
  block candidates when they can extend contention or strand resources.
- Match session-scoped state, advisory locks, temporary tables, prepared
  statements, roles, search path, and transaction settings to the
  connection-pooling mode. Transaction pooling must not be assumed to preserve
  session state.
- For transactional outbox, inbox, trigger-based change capture, or equivalent
  delivery, prove atomicity with the originating write, stable event identity,
  ordering scope, duplicate delivery and replay behavior, publish-marker
  recovery, and consumer idempotency.
- For claim/queue patterns, prove exclusivity, lease expiry or crash recovery,
  starvation behavior, and whether skipped locked work is eventually visible.
- Include lease clock assumptions and stuck-claim detection or repair. For
  online migrations, test adverse interleavings between migration work and
  organic writers rather than only the single-threaded job path.
- When prepared transactions, XA, or an external transaction coordinator
  exists, prove coordinator recovery, inventory and ownership of in-doubt work,
  timeout and lock retention, duplicate resolution, replay, failover, heuristic
  outcomes, and the operator law for commit versus rollback.

Block candidates include partial-commit exposure without recovery, a lost-update
or write-skew path, inconsistent lock order with material deadlock consequence,
unsafe transaction retry, external I/O that extends material lock contention,
a session-scoped correctness mechanism invalidated by pooling, or prepared
transactions with no bounded in-doubt resolution law.

Useful evidence: transaction and isolation configuration, commit-boundary and
side-effect inventory, exact statements, constraints, lock order, pooling mode,
timeout and retry policy, and a concurrent-writer or fault-injection test.
