# Operations, security, and evidence

This lane applies to rollout gates, operator intervention, sensitive data or
errors, monitoring, and all material production-readiness claims.

- Require observable dry-run, apply, validate, reconcile, pause, abort, resume,
  rollback or forward-fix, and terminal states with run identity, progress,
  rate, age, errors, stop thresholds, and decision owner.
- Inspect locks, latency, errors, WAL, disk, lag, and rollout health evidence. Small fixtures prove only their own environment and scale.
- For a concrete plan, inventory blast radius by object, tenant or shard,
  rows/bytes, traffic rate, critical path, data classification, retention duty,
  SLO, and downtime constraint. Small-fixture estimates remain assumptions
  unless scale, distribution, and concurrency are representative or
  conservatively bounded.
- Minimize persisted identifiers/payloads, verify tenant predicates and least privilege, and test retention/deletion duties.
- Shadow tables, exception ledgers, exports, logs, and dry-run artifacts inherit
  the source data's classification and retention or deletion duties.
- Review migration, application, backup, and replication roles; encryption-key
  transitions; masking; residency and legal hold; and whether object swaps or
  restores lose grants, RLS, classification, tombstones, or required deletion.
- Trace database ownership, grants and default privileges, invoker or definer
  execution, object resolution, row-security policy applicability and bypass
  roles, and every tenant-bearing read and write path. Do not treat an
  application predicate as database-enforced authorization.
- Treat external error strings as hostile. URI-only regex redaction is insufficient proof for keyword DSNs or arbitrary payloads; prefer structured allowlisting, truncation, and adversarial tests.
- Parse structured DSN, URI, and query options at their grammar boundaries before decoding component values. Test duplicate keys, case variants, encoded delimiters, and malformed encodings rather than scanning the decoded string.
- For connection URIs, distinguish the selected application database from the
  authentication database and driver defaults. Keep URI paths, explicit
  database selection, and authentication-source options explicit and
  semantically consistent across templates, secrets, code, and operator
  examples; the two databases may intentionally differ.
- Persist and log the identity of the artifact actually executed, such as an
  image digest, build provenance, release artifact, or checked-out commit,
  rather than an ambiguous event or merge SHA. Give each log event a distinct
  operator decision purpose and attach structured run and scope identity to
  actionable warnings.
- Require applicable operator controls to name evidence, threshold, decision
  owner, and failure consequence. A canary, flag, runbook hold, rate limit,
  maintenance window, or kill switch is not a gate until its enforcement and
  readback are proved.
- Before crediting a canary, prove whether the hazardous database effect is
  contained to that target. Catalog changes, lock queues, constraints, shared
  indexes, replication, or resource saturation may expose the wider workload
  on first application. If isolation is absent, treat the canary as
  representative exposure rather than bounded blast radius.
- A stop threshold states absolute value, rate of change, sustained window,
  alert owner, false-positive behavior, and maximum harm through detection and
  completed stopping.
- Inspect runbook target selectors, executing principal, units, defaults,
  confirmation behavior, copy/paste safety, non-production defaults,
  interruption/re-entry, and postconditions.
- Kill-path evidence proves no new work starts, in-flight work reaches a safe
  boundary, durable state leaves `running`, locks and resources release, cleanup
  is bounded, and restart does not silently resume.
- Detect conflicting automation and manual authority. Require current target
  readback, representative canary selection, damage-before-stop bounds, and a
  post-run watch and cleanup owner.
- Capped, sampled, or scoped audits must loudly disclose changed detection semantics and every uncovered population in operator-visible output. Zero findings must not be presented as full coverage when the query could not detect out-of-scope drift.
- Every connection, cursor, transaction, and terminal-state cleanup path must
  remain usable after parent cancellation when required, carry a hard deadline
  to the actual I/O call, and surface failures needed for recovery or operator
  diagnosis. Preserve the primary error while returning or boundedly logging
  cleanup errors with safe run identity.
- Production evidence names its observation window, release artifact,
  configured rate, dataset and tenant/shard coverage, and material limitations;
  one healthy interval is not general production proof.
Block candidates include no observable terminal state, missing abort authority
for high-risk work, cross-tenant possibility, secret leakage, or absent central
production proof that could reverse the verdict.

Useful evidence: runbook, metrics/log schema, sample run, alerts/thresholds, role grants, data classification, redaction tests, dataset provenance, head SHA, and limitations.
