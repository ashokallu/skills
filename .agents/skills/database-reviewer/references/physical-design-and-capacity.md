# Physical design and capacity

This lane applies to DDL, indexes, access paths, rewrites, large or hot
relations, or performance/resource claims.

Start by applying the core performance decision scope. In advisory
`performance-assessment`, missing comparable runtime evidence makes the claim
`unproven`; it is not itself a defect or a merge/Production blocker. Merge and
deployment readiness block only when performance is acceptance-critical or a
material reachable risk. Production execution remains fail-closed for every
scale-sensitive critical-path statement.

- Determine lock mode/acquisition, queue amplification, rewrite/scan behavior for the deployed PostgreSQL version, timeouts, and recovery from timeout or invalid objects.
- For live-table DDL, prove lock wait, statement time, transaction duration,
  retry, and abort policy from the executing session. A metadata-fast statement
  can still queue behind old transactions and block later traffic.
- Verify the actual engine/version algorithm and any dangerous fallback from an
  online, concurrent, instant, or in-place request. Include metadata locks,
  blocker transactions, implicit commits, shadow/change-capture tooling,
  cutover locks, and invalid or partial residue.
- For online index work, account for phase scans, waits, uniqueness failure,
  transaction restrictions, invalid or half-built residue, cleanup, write
  amplification, and extra CPU/I/O.
- Inspect parameter skew, generic versus custom prepared plans,
  partition-leaf convergence, intended and unintended post-deploy plan adoption,
  write regression, and every dependency before index replacement or removal.
- Reproduce the executing session's prepared-statement and plan-cache behavior.
  Compare generic and custom plans when parameters or relation sizes can change
  the access path, and verify any `plan_cache_mode` override is transaction- or
  statement-scoped as intended. A fast literalized probe does not prove the
  parameterized job statement will choose the same plan.
- Match indexes to actual predicates, joins, ordering, selectivity, FK actions, and latency needs; reject duplicate or unused structures and account for write/bloat/storage cost.
- Inspect the executed or winning plan, not rejected alternatives or an
  arbitrary explain subtree. A plan probe must derive from the canonical
  runtime query shape or carry an explicit drift test; a duplicated
  approximation can remain green after production work changes.
- Separate estimated plan shape from representative runtime. Measure rows/bytes, skew, WAL, disk, lag, autovacuum, I/O, memory, connection and maintenance-window headroom when judgment depends on them.
- Load relevant optional historical operation candidates and classify each as
  direct, comparable, contextual, or not applicable to the claim. A contrary
  runtime or capacity assertion must identify a proved material difference.
  Without that difference, keep the assertion `Pending Verification` rather
  than presenting a generic worst case as a finding.
- Build a phase cost model for every scale-sensitive statement, including work
  before the first progress checkpoint and finalization after the last chunk.
  Record expected invocations, rows per logical key, fanout, scans, temp I/O,
  per-call latency, total runtime, timeout margin, and retry cost. A chunk-size
  bound does not bound an unchunked preflight or finalization statement.
- Include temp space, bloat/dead tuples, vacuum impact, and conservative margins
  in planned capacity budgets. Small fixtures prove only their own scale and
  distribution.
- Model forward, abort, cleanup, rollback, replay, and restore high-water marks
  separately. Include WAL/redo/binlog retention, auto-resize ceilings, quotas,
  and the worst tenant, shard, or partition rather than fleet averages.
- Check identity and sequence headroom on growing write paths. Require the
  current maximum, type or sequence ceiling, growth rate, and projected
  exhaustion horizon; the declared type alone is not capacity proof.
- Plain `CREATE INDEX`, validated `CHECK` or foreign-key addition, `SET NOT
  NULL`, type conversion, or unbounded active-table mutation requires
  runner-compatible and scale-specific lock and scan analysis. When staged
  validation is available, prove the add and validate phases independently.
- Treat temporary disabling of constraints, triggers, RLS, replication, or CDC
  as a separate integrity and recovery boundary with enforced restoration and
  current readback.
- After bulk mutation, prove statistics are current before treating dependent
  plan or selectivity evidence as representative.
- Do not materialize an unbounded validation/reconciliation diff in application
  memory or persist it row by row. Require set-based, streaming, or bounded-key
  chunks and separately bound memory, transaction duration, exception volume,
  and retry cost.
- When a full scan is ordered by a stable logical key, prefer an O(1) monotonicity or contiguity guard over a set that grows per record. Prove the order after decoding and canonicalization, not merely in the source storage representation.
- For caps enforced after a chunk, page, or batch, identify the enforcement
  point, maximum overshoot, and transient memory, WAL, lock, and transaction
  cost. Even a confirmed rollback proves only final-state integrity; it does
  not prove the configured cap bounded resource consumption. An uncertain or
  failed rollback requires separate recovery evidence.
- Treat a statement timeout as an abort bound, not a performance design or
  capacity proof. Repeatedly raising the timeout or rerunning the same
  production-shaped query without new plan, statistics, or contention evidence
  is not an acceptable experiment when the statement can consume material CPU,
  I/O, temp space, locks, or operator time.

Conditions that may block the applicable decision include
indefinite active-table waits, unbounded startup work,
transaction-incompatible concurrent DDL, a scale-sensitive pre-mutation gate
whose largest-environment winning plan and runtime budget are unproved, timeout
growth offered as the only performance mitigation, or material capacity claims
contradicted by representative proof. A confirmed condition may become a
finding; missing representative proof remains a
decision-scoped evidence gap, not a finding. Do not use this list to claim an
operation will saturate resources, time out, exhaust connections, or cause an
outage without evidence for that concrete impact.

Useful evidence: PostgreSQL version, `EXPLAIN`, representative `EXPLAIN (ANALYZE, BUFFERS)`, relation/index statistics, write rate, lock rehearsal, timeout policy, and abort thresholds.
