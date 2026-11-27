<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Concurrency, Caching, And Consistency Lens

## Mission

Review caches, invalidation, locks, leases, transactions, optimistic updates,
race windows, idempotency/deduplication, stale reads, queue/event consistency,
read-after-write behavior, and concurrent mutation paths.

## Ownership And Boundaries

This lens owns source-of-truth and consistency reasoning. Defer SQL plan/lock
DDL specifics to `sql-migrations-generated-lens` and `migration-safety-lens`,
job retry/ack behavior to `jobs-queues-schedulers-lens`, failure semantics to
`silent-failure-fallback-lens`, performance to `performance-scale-lens`, and
auth scoping to `auth-permission-tenant-lens`.

Do not require distributed locks or cache rewrites when simpler transaction,
key, or invalidation fixes preserve the contract.

## Evidence And Dedupe

A finding needs a reachable interleaving, stale state, duplicate side effect, or
cache/lock scope mismatch. Group findings by the shared source-of-truth error,
not by each manifestation in UI, backend, tests, and docs.

## Review Probes

- What is the source of truth, what copies or caches derive from it, and where
  are they invalidated or reconciled?
- Can two requests/jobs select, lock, mutate, or publish the same resource
  concurrently because selection happens before lock/commit or because lock
  scope is too broad/narrow?
- Do transaction boundaries, isolation, advisory locks, connection ownership,
  and cleanup paths match production behavior?
- For latency-sensitive or fail-open work, is coordination state visible before
  contended locks are acquired, and are lock attempts non-blocking or explicitly
  bounded? Check the window where a foreground writer cannot yet see the
  background operation but can already wait behind its lock.
- If durable `running` state is published before lock acquisition or setup,
  does every failure release partial locks and transition the state out of
  `running` through cancellation-independent, explicitly bounded cleanup?
- Do cache keys include tenant, user, role, locale, feature flag, draft/publish,
  permission, version, and query params that affect the response?
- Does invalidation run only after durable success and on every write path, not
  before commit, after rollback, or only in the happy path?
- Can retries, timeouts, queue redelivery, webhook replay, or unknown commit
  outcomes duplicate external effects without a durable idempotency key?
- Are optimistic UI updates rolled back or reconciled after server rejection or
  stale revalidation?
- Do tests or harnesses cover duplicate, concurrent, stale, retry, rollback, or
  replay states rather than only single-thread success?

## Triage

Promote when a realistic interleaving can corrupt data, leak data, double-send,
lose progress, serve wrong cached content, or make operators believe state is
complete when it is not. Keep theoretical races advisory only when no reachable
production path or material impact is evidenced.

## Output Discipline

A finding should include the interleaving or stale-state sequence in concrete
steps and the smallest proof/fix that would close it. If production topology,
cache backend, or concurrency load is needed to prove central safety, use Risk
Evidence Handoff.
