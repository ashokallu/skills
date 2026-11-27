# Backup, restore, and disaster recovery

This lane applies when approval depends on backup, snapshot, PITR, restore,
failover/failback, disaster recovery, or recovery across shards or stores.

- Inventory every required data, schema, log, key, role, extension, object,
  configuration, control-plane, and external-system dependency. A backup job's
  green status is not recovery proof.
- Define target scope, consistency boundary, RPO, RTO, loss window, retention,
  encryption/key access, and who can restore when the primary control plane or
  credentials are unavailable.
- When PITR, a snapshot, or full-store restore is proposed as rollback, state
  the recovery unit and the fate of unrelated valid writes committed after the
  recovery point. Require explicit accepted loss or a proved capture, replay,
  or merge path; backup availability alone is not safe reversal.
- Inspect the most relevant successful exercise. Record artifact and target,
  engine/schema and application compatibility, observation time, restore and
  replay duration, post-restore integrity checks, traffic-restoration time, and
  limitations.
- Prove convergence around nontransactional DDL, dirty or partial migrations,
  shards, replicas, CDC, derived stores, and other cross-system state. A
  transactionally consistent database restore may still leave authority split.
- For failover and failback, verify fencing, sequence/key state, write loss or
  replay, routing, split-brain prevention, and recovery of the failed side.
- Test deletion, retention, legal-hold, and tombstone behavior after restore so
  recovered backups do not silently resurrect data that must remain deleted.
- Include validation and safe traffic restoration in measured RTO; a database
  process starting is not service recovery.

When phase-specific rollback or forward-fix, topology or durability, or
derived-consumer replay emerges, return to the central router and add the
matching lane.

Block candidates include restore-dependent approval without a relevant
successful exercise, missing key/control-plane recovery, unproved integrity or
compatibility, RPO/RTO unsupported by measured scope, unsafe failback fencing,
unresolved cross-target authority after recovery, or a recovery-unit rewind
that can discard unrelated valid writes without an accepted or proved recovery
path.

Useful evidence: backup inventory and checksums, restore drill, recovery logs,
integrity and parity results, RPO/RTO measurement, key-access rehearsal,
failover/failback evidence, deletion tests, and operator runbook.
