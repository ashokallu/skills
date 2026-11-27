# Sharding, partitioning, and distribution

This lane applies to distribution keys, shard or partition routing, fanout,
resharding, rebalancing, and partial-fleet database work.

- Identify routing authority, placement metadata, cache invalidation, ownership,
  and every caller that selects a target. Prove the key preserves tenant
  isolation, dominant access paths, retention, pruning, and expected growth.
- Version and fence routing maps so stale routers cannot write to an old owner.
  Name donor and recipient authority during movement and prove shard-key changes
  cannot strand or duplicate lookup state.
- Verify uniqueness, referential rules, and idempotency at their real scope:
  local, tenant, partition, shard, or global. A local constraint is not global
  proof unless the key makes cross-target collision impossible.
- Bound scatter/gather, cross-target joins, aggregation, ordering, pagination,
  timeouts, retries, and partial-result behavior. Surface hot keys, skew,
  default partitions, and oversized tenants.
- For resharding, prove write-during-move behavior, stable identity, snapshot or
  watermark, checkpoints, reconciliation, authority transfer, and cleanup.
- For partial-fleet migrations, require a target manifest, per-target version,
  canary order, retry/resume law, skipped-target policy, and old/new reader and
  writer compatibility.
- For attach, detach, split, or merge, inspect bounds, validation scans,
  inherited constraints and indexes, pruning predicates, default-partition
  interaction, and parent/child locks.
- For distributed identifiers, prove collision, clock, failover, cache-loss,
  monotonicity, and exhaustion assumptions. Recovery of one target must not
  create cross-target authority or referential drift.
- Include global secondary lookup convergence, residency constraints, and
  collision risk when a restored target rejoins the fleet.
- Observe progress, lag, counts, skew, queue depth, errors, retries, and status
  age per target; fleet averages can hide a failed or hot target.

Block candidates include missing routing authority, local invariants presented
as global, unbounded fanout, no partial-fleet law, unsafe writes during movement,
or recovery that leaves cross-target authority unresolved.

Useful evidence: shard map, router source, partition definitions, distribution
histogram, per-target plans and versions, rollout manifest, reconciliation,
recovery rehearsal, and per-target dashboards.
