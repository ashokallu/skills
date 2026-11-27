# Environment and data-shape context

This lane governs how environment-specific topology, effective configuration,
capacity, relation scale, statistics freshness, workload heat, and headroom
evidence may affect a database verdict. It is additive to the domain lanes that
own configuration, physical design, replication, recovery, or live DDL.

## Evidence law

Bundled snapshot and operation records are illustrative fixtures. Use them to
learn the evidence format and collect current evidence for the target.

- Keep Terraform-declared state, live-observed state, and generated snapshot
  metadata separate. Terraform proves configured intent at its named commit,
  not effective runtime state. A live read proves only its target and
  observation window.
- Treat catalog relation bytes as exact only at observation time. Treat
  `reltuples` and `pg_stat_user_tables` cardinalities as estimates and record
  their statistics timestamp or that it is unavailable. Never silently convert
  an estimate into an exact row count.
- A snapshot's `valid_until` is a maximum currentness window, not proof that no
  change occurred. Within that window, bounded coverage of relevant
  invalidators may support a current-state claim. A proven deployment,
  migration, resize, failover, engine or configuration change, statistics
  reset, or material workload/data-shape change invalidates only dependent
  fields.
- Loading precedes freshness judgment. After loading, classify each relevant
  claim as current, historical, event-invalidated, or `Pending Verification`
  for currentness. When no bounded invalidation check accompanies the artifact,
  compare it with current target, deploy, migration, instance, and workload
  evidence before treating dependent fields as current. Time validity alone is
  insufficient, but the observation remains historical evidence.
- Use environment context to select probes and bound consequences. Never infer
  that a change is safe because a relation is small, auto-resize is enabled, a
  replica exists, Terraform declares a value, or estimated rows look bounded.
- If currentness of an expired, event-invalidated, unavailable, or omitted
  field could reverse a named decision, return `Pending Verification` for that
  current fact and block only the exact merge, deployment, or Production
  operation it controls. Do not discard the field's historical observation or
  turn its currentness gap into a finding. The parent may prepare a targeted
  bounded refresh before a new reviewer spawn; this static reviewer never
  requests or executes it. Top-N omission never proves that an affected
  relation is small.
- A source-only migration does not invalidate observed environment state. A
  migration or deployment invalidates a field only when current evidence shows
  it reached the environment and could change that field.
- Keep results secret-safe. Do not persist DSNs, users, role memberships, IP
  addresses, tenant identifiers, row samples, payloads, activity query text, or
  secret-backed settings in the snapshot.

## Parent-owned Staging preflight and refresh contract

These are parent instructions, not reviewer actions. The parent owns
authentication, environment selection, and the Cloud SQL lane in
`readonly-data-access`. It validates the checked-in snapshot first and
refreshes only after maximum validity expires, after a listed invalidator, or
when a material affected relation or field is omitted. A read-only PR review
never rewrites its target worktree.

1. Record the active source commit and inspect Terraform declarations at that
   commit. Label them `configured`.
2. Timestamp and run bounded `gcloud sql instances describe` reads for both
   Staging instances using the tracked non-SQL collector definition. Project
   only the fields represented in the snapshot; do not persist addresses,
   certificates, service accounts, or users.
3. Run each query in
   `evidence/staging-cloudsql-collector.sql` separately through the sanctioned
   Staging read-only wrapper. Its content hash must equal the snapshot's
   `collector_sha256`. The wrapper's execution bound is the query timeout; do
   not replace estimates with `COUNT(*)`, `EXPLAIN ANALYZE`, sampling, or
   payload reads.
4. Query the Cloud Monitoring `database/disk/bytes_used` metric for each named
   instance with the tracked resource-filter template over a declared window
   and retain only the latest timestamp/value plus the window.
5. Validate schema, semantics, and collector hashes. For review-time refresh,
   write a secret-safe immutable artifact outside the PR target, record its
   content digest, make it readable to the reviewer sandbox, and retain it until
   every consumer finishes. If a probe fails, retain the field as `unavailable`
   with its reason; do not carry the old value forward as current.

Expired snapshots and snapshots with unknown invalidation coverage remain
historical evidence. If the parent has no safe refresh path, it spawns the
reviewer with the exact currentness gap. The reviewer blocks only the named
decision that depends on current state. Neither owner widens access, switches
to writes, or runs an unbounded query.

## Parent-owned Production refresh differences

Production uses the read replica and `SQL_REPLICA_URI` through the sanctioned
direct private-IP workflow. Before collection, prove the intended identity and
VPN path, then require `pg_is_in_recovery() = true`. Wrap every query in
`BEGIN READ ONLY`, set a local statement timeout, and stop if recovery state is
false or unavailable. Do not switch to the primary merely to complete the
snapshot.

Execute `evidence/production-cloudsql-collector.sql` against the replica.
Replica-local `pg_stat_user_tables` counters and analyze timestamps are not
source-primary statistics, so the Production collector uses replicated
`pg_class.reltuples` estimates and labels statistics timestamps unavailable.
Keep the same metadata projection, Monitoring bound, event invalidation, top-N
omission, secret-safety, and refresh-failure rules as Staging.

The reviewer consumes only the validated immutable result and readiness packet.
It never executes these steps, falls back to the primary, or asks another agent
to refresh evidence during its verdict.

When another material database consequence emerges, return to the central
router and add its matching lane.
