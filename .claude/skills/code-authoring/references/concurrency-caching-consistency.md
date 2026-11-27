<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Concurrency, Caching, And Consistency Authoring

Use this lane for caches, invalidation, locks, leases, transactions, optimistic
updates, race windows, idempotency keys, deduplication, distributed work,
read-after-write behavior, stale data, fanout, queue/event consistency, and
concurrent mutation paths.

## Mission

Author a clear source-of-truth and consistency model. A fix that works in a
single local request can still fail under concurrent writes, stale caches,
worker retries, lock contention, or rolling deploys.

## Boundaries

Also load `production-data-safety` for bulk or production data effects,
`jobs-queues-and-schedulers` for async processing, `resilience-and-fallbacks`
for retries/timeouts, `efficiency-and-scale` for hot caches or high-cardinality
keys, and `auth-permissions-identity` when cache keys or locks include tenant or
user scope.

Do not add distributed locks, global caches, or eventual-consistency machinery
unless the current failure mode needs them and local precedent supports them.

## Authoring Sequence

1. Name the source of truth, derived copies, cache keys, invalidation points,
   transaction boundaries, lock/lease scope, retry/idempotency key, and stale
   read tolerance.
2. Trace write then read behavior across handlers, jobs, caches, requesters,
   database transactions, events, and frontend state.
3. Pick the smallest consistency model: strong transaction, read-after-write,
   cache invalidation, stale-while-revalidate, eventual consistency with
   operator visibility, or explicit unsupported race.
4. Scope locks and cache keys to the real conflict domain: tenant/user/resource,
   not global unless the resource is actually global.
   When latency-sensitive or fail-open work coordinates with background work,
   publish the coordination state before acquiring contended locks and prefer
   try-lock or explicitly bounded waiting. Otherwise foreground traffic can
   block in the visibility window before it knows to skip or defer safely.
   If lock or setup fails after publishing `running`, release partial locks and
   transition that durable state out of `running` with cancellation-independent,
   explicitly bounded cleanup so foreground work cannot remain wedged.
5. Make idempotency durable before side effects when retries, callbacks, queue
   redelivery, or unknown commit outcomes can repeat work.
6. Ensure invalidation happens after successful writes and cannot claim success
   when the write failed, committed ambiguously, or only partially applied.
7. Add tests or focused harnesses for duplicate, concurrent, stale, retry, and
   rollback states where they matter.

## Prevention Probes

- Can two requests/jobs choose the same rows, reuse the same key, or overwrite
  each other's state because selection happens before locking or commit?
- Does a cache key omit tenant, locale, role, feature flag, draft/published
  state, permissions, or version fields that affect the response?
- Does invalidation run on the wrong branch, before commit, after rollback, or
  only in one of several write paths?
- Are optimistic UI updates, local state, or derived stores rolled back or
  reconciled after server rejection?
- Does retrying after timeout, unknown commit, queue redelivery, or webhook
  replay duplicate external side effects?
- Are stale reads acceptable and documented, or did they become hidden data
  loss, authorization bypass, or operator confusion?

## Validation

Useful proof includes transaction/query tests, duplicate replay tests,
concurrent goroutine/request tests, cache-key unit tests, integration tests for
write plus invalidation plus readback, and failure-injection for unknown commit
or retry. If only production topology can prove a race or cache behavior, name
that environment evidence as `Pending Verification`.

## Output

```text
Concurrency/cache authoring:
- consistency model: <source, cache/lock/transaction/idempotency>
- race/stale states checked: <states>
- proof: <test/harness/artifact or Pending Verification>
```
