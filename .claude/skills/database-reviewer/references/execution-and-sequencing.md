# Execution and sequencing

This lane applies to every migration target.

- Identify the exact migration pair, stable head, runner, transaction behavior,
  artifact identity or checksum, startup/deploy coupling, and all services that
  may race to migrate.
- Trace how the runner discovers migration sources. Require one canonical path
  or namespace invariant and tests that select the intended source while
  rejecting aliases, nested or generated lookalikes, generated drift, and
  unrelated migration directories.
- For high-blast-radius jobs, verify effective runtime task count, parallelism, and retry shape at process startup when deployment configuration is intended state rather than a runtime guarantee.
- Check numbering/pairing, whether an applied migration was edited, dirty-version recovery, stacked dependencies, and schema/code/job deployment order.
- Review stacked revisions cumulatively when their assembled schema states or
  order control safety; an isolated safe diff is not release-sequence proof.
- For conditional DDL such as `IF NOT EXISTS` or `OR REPLACE`, prove success
  cannot preserve a pre-existing object with a divergent definition. A
  successful no-op is not schema convergence evidence.
- Build the required sequence from old schema/code through new schema/code. Do not infer transaction behavior from the SQL shape.
- Split or gate statements incompatible with the runner's actual transaction or
  retry mode. For live DDL, prove lock and statement timeouts apply in the
  executing session, remain correctly scoped, and have bounded retry or
  operator recovery semantics.
- When background database work coordinates with latency-sensitive or fail-open
  writers, make the durable running state visible before acquiring contended
  locks. Prefer try-locks or an explicit wait bound so the pre-visibility race
  cannot turn intended fail-open behavior into foreground latency.
- If lock acquisition or setup fails after publishing `running`, release any
  partial locks and transition the durable state out of `running` using
  cancellation-independent, explicitly bounded cleanup. A stale coordination
  row must not block foreground work indefinitely.
- Treat repository migration checks as continuity evidence only; they do not
  by themselves prove runtime, lock, data, or rollback safety.
- For shard, tenant, or partition fleets, require an execution manifest with
  target set, per-target version, skipped targets, retries, and partial
  completion. One successful target is not convergence proof.
- For a concrete rollout plan, require each applicable canary, dry-run,
  rehearsal, pause/resume, validation, decommission, rollback/forward-fix, and
  abort gate to name its evidence, threshold, decision owner, and failure
  consequence.
- Before authorizing a costly full run, require a query-readiness gate for every
  scale-sensitive statement on its critical path. The gate names the canonical
  statement, representative environment evidence, winning plan, runtime and
  resource budget, timeout margin, progress visibility, and safe abort/retry
  consequence. If that proof is missing, block the run rather than learning
  query performance through repeated full executions.

For phased, live, distributed, or authority-moving work, inspect the author's
phase matrix. Each applicable phase names schema/artifact versions, targets,
active readers and writers, authority, entry evidence, durable state,
checkpoint, rate/concurrency bound, progress, stop threshold, owner, failure
residue, retry/resume, recovery options, last reversible point, exit evidence,
and the enforced next gate. A single down file is not that matrix.

Return central missing proof when current environment version, runner semantics,
or prerequisite ordering could change approval. Block candidates include
code-before-schema exposure, incompatible transaction requirements, unsafe
replay after failed startup, or an applied migration rewritten without a
repair plan.

Useful evidence: migration history, merge-base ancestry, runner source, deploy entrypoints, current environment version, and failure-state rehearsal.
