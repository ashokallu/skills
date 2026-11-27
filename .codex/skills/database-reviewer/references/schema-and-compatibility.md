# Schema and compatibility

This lane applies to tables, columns, types, defaults, keys, constraints,
generated types, or overlapping revisions.

- Test whether types, precision, timezone, nullability, defaults, identities, keys, checks, uniqueness, and FK actions encode the real invariant.
- For a new table, verify ownership, tenant boundary, key and lifecycle,
  retention and classification, audit/provenance, access paths, grants/RLS,
  backup/restore expectation, and accountable owner before treating emptiness as
  safety.
- Identify where and when each invariant is enforced: table constraint,
  partial or functional unique index, exclusion or deferred constraint,
  generated column, trigger, policy, or application-only check. Prove the
  predicate covers every applicable row and that statement-time or commit-time
  enforcement matches every writer's transaction behavior; application-only
  enforcement leaves explicit residual risk.
- Choose each foreign-key delete or update action from the referenced row's
  lifecycle. Durable audit or provenance links may need to survive parent
  deletion, while disposable staging children may legitimately cascade; one
  blanket action is not a design rule.
- Inspect duplicate, orphan, malformed, and out-of-range state before tightening
  constraints, narrowing types, or changing precision or state vocabularies.
  Verify tenant
  and ownership boundaries and every reader/writer affected by generated type
  changes, including replication, change-data-capture, cache, search, and
  analytical consumers when present.
- For partitioned or sharded data, verify partition-key coverage, local versus
  global constraint scope, attach/detach validation, pruning predicates, and
  cross-partition access cost.
- Treat collation, character encoding, locale, case folding, and comparison
  rules as persisted semantics. Verify existing data, uniqueness, ordering,
  index operator compatibility, and every reader that assumes the old rules.
- Track horizons for bounded identifiers, sequences, partitions, time buckets,
  and fixed precision. Require current use, growth, rollover or exhaustion
  behavior, and the intended operating horizon when a limit is reachable.
- Build the old-code/new-schema, new-code/old-schema, old-writer/new-schema,
  rollback-code/new-schema, and applicable non-application-consumer matrix.
- Prefer expand, migrate, prove, contract when revisions can overlap.

Do not automatically require an index for every FK or reject every asymmetric down. Return a candidate only when access, referential action, integrity, compatibility, or recovery evidence establishes a consequence.

Useful evidence: full table definitions, writer/reader inventory, generated diffs, representative data-shape queries, deploy coexistence facts, and business invariant source.
