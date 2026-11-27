# Replication, CDC, and derived consumers

This lane applies to read replicas, logical replication, CDC, outbox/inbox,
search or cache projections, analytics extracts, and other derived stores.

- Inventory every derived consumer and state whether tables, DDL, sequences,
  partitions, policies, grants, functions, and other required objects propagate
  automatically or need ordered application and drift proof.
- Build source/consumer compatibility for additive and contract phases,
  defaults, required state, vocabulary, replica identity, partitions, and
  transformed or versioned payloads.
- Define each read class as read-your-writes, monotonic, bounded-stale,
  eventual, or analytical. Prove routing, lag bounds, fences, watermarks, or
  primary fallback match that contract.
- For replayable delivery, prove stable identity, ordering scope, version
  negotiation, duplicate handling, poison-message policy, backpressure, catchup,
  and idempotent consumer effects.
- Prove projection invalidation or rebuild, missed-event detection, independent
  drift measurement, and deletion or tombstone propagation through retention.
- For failover or promotion, verify sequence/key state, slot or log retention,
  lag catchup, reader routing, split-brain prevention, and which writes may be
  lost or replayed.

When transaction atomicity, pool or topology behavior, schema invariants,
authority transfer, or recovery emerges, return to the central router and add
the matching lane.

Block candidates include unversioned consumer incompatibility, strong freshness
without fences or lag proof, manual propagation without order/drift evidence,
non-idempotent replay, missing deletion propagation, or unsafe promotion state.

Useful evidence: consumer inventory, propagation configuration, replica
identity, compatibility contract, lag and watermark evidence, replay tests,
projection rebuild/drift proof, deletion tests, and failover rehearsal.
