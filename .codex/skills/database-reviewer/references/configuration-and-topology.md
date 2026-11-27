# Configuration and topology

This lane applies to database parameters, extensions, connection pools,
routing, replicas, failover, durability, backup, retention, or topology changes.

- Distinguish declared configuration from its effective value and scope. Check
  precedence, per-session overrides, rollout or restart requirements, rollback,
  and mixed-version coexistence.
- Verify engine/version and extension compatibility at every node that can
  execute or serve the affected work.
- Map writer and reader routing, replication or propagation delay,
  read-after-write expectations, failover behavior, and recovery from partially
  applied configuration.
- Compare aggregate pool maximums across instances and workers with database
  limits and reserved headroom. Inspect acquisition timeout, idle and maximum
  lifetime, scale/retry amplification, and leak or borrow-wait metrics; one
  process's pool bound is not fleet capacity proof.
- Include autoscaling services, jobs, migration workers, and retry amplification
  in pool demand. Separate their priority or resource budget from foreground
  traffic when contention would violate an application SLO.
- Align client, proxy, acquisition, statement, lock, idle-in-transaction, and
  cancellation timeouts so a failed caller cannot strand work or locks.
- For connection settings, distinguish writer and reader endpoints, selected
  database, authentication source, role, TLS mode, search path, and driver
  defaults across configuration, secrets, code, and operator examples.
- For durability, backup, retention, or recovery-setting changes, state the
  altered failure consequence and verify the effective topology after rollout.
- Require observable effective state rather than treating configuration source
  as runtime proof.

Block candidates include an ineffective or partially applied safety setting,
unbounded aggregate connection demand, reader routing that violates required
freshness, unsupported mixed versions, or failover/durability behavior without
recovery evidence.

Useful evidence: effective-value inventory, configuration precedence,
engine/version support, topology and routing map, restart behavior, aggregate
connection limits, replication lag, failover rehearsal, restore evidence, and
rollback results.
