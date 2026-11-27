<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Performance And Scale Lens

Use this lens when the review touches benchmarks, profiling, load tests,
Lighthouse/Web Vitals, bundle analysis, caching, hot-path code, query fanout,
queue throughput, CPU or memory behavior, or claims about latency, throughput,
cost, or scale.

Reviewer checks whether performance-sensitive changes preserve correctness and
are supported by comparable evidence. Performance ownership, infrastructure
sizing, and product tradeoffs remain with the parent or specialist.

## Review Order

1. Identify the user or system metric the change claims or can materially affect.
2. Map the hot path: route, handler, query, cache, queue, render, bundle,
   external call, or instrumentation path.
3. Check baseline, profiler, benchmark, production artifact, or current
   operational evidence before accepting optimization claims.
4. Compare before/after evidence only when environment, input size, sample size,
   command, commit, and workload are comparable.
5. Verify the optimization did not weaken correctness, security, privacy,
   readability, rollback, or test coverage.

## Evidence Quality

- Do not accept "faster" claims without a baseline and a comparable after
  measurement, unless the change removes an obviously unreachable or redundant
  operation and the output contract is still proved.
- Latency evidence should include tail behavior, usually P95/P99, not only
  averages. Go benchmarks should include allocations when allocation behavior is
  relevant.
- Frontend performance evidence should prefer production-build artifacts:
  bundle analysis, Lighthouse JSON, Web Vitals, route timing, or profiler data.
  Development server scores are not production proof.
- SQL, cache, and queue performance claims need data volume, cardinality, query
  plan, index shape, queue depth, retry behavior, or operational artifact
  proportional to risk.
- "Chunked" is not a performance proof by itself. For jobs that run multiple
  SQL statements per chunk, verify each expensive substatement is bounded by
  the same keyset or has separate plan evidence. Restore, insert, delete,
  validation, evidence persistence, cleanup, and progress writes can each be
  the real bottleneck.
- Timeout increases are weak evidence. Treat them as a diagnostic or owner
  tradeoff unless the review target proves query shape, row counts, locks,
  storage, and in-flight observability are within the operational envelope.
- A benchmark from a tiny fixture, local laptop, stale CI cache, or different
  environment is useful evidence but not proof of production-scale safety unless
  the workload is representative.

## Cross-Stack Performance Footguns

- Watch N+1 queries, unbounded loops, broad GROQ or SQL scans, repeated backend
  calls from render paths, missing pagination, high-cardinality joins,
  expensive sorts, and payloads that grow with tenants, learners, courses,
  content, events, or imports.
- Large audit, classification, import, export, reconciliation, or reporting
  writes should use the repo's bulk or batched persistence pattern when one
  exists. Per-row database writes are reviewable when the input can grow with
  users, content, tenants, or historical evidence.
- Hot read paths should return before allocations, map construction, expensive
  normalization, or external lookups when a feature flag, run ID, or empty input
  proves the no-op path.
- Caching changes must preserve auth, tenant, user, locale, feature-flag,
  preview/draft, and permission dimensions. Faster wrong data is a correctness
  and privacy defect.
- Backend optimizations that move work to queues, goroutines, caches, or
  background jobs need retry, backpressure, cancellation, idempotency, and
  observability review.
- For ordered production scans, require proof that an O(1) monotonicity guard
  observes decoded logical-key order before accepting it as a replacement for
  per-record state.
- For chunk-, page-, or batch-enforced caps, inspect the enforcement point,
  maximum overshoot, and transient memory, WAL, lock, and transaction cost.
  Even confirmed rollback proves only final state; it does not make the nominal
  cap a resource bound, and uncertain rollback needs recovery evidence.
- Frontend optimizations must not remove loading/error states, accessibility,
  duplicate-submit protection, route freshness, or read-your-writes semantics.
- Instrumentation added to hot paths must be bounded and safe. Logging, tracing,
  profiling, and metrics can add latency, allocation pressure, sensitive data
  exposure, or cardinality explosions.

## Dependency And Default Changes

- Dependency upgrades can silently change timeouts, retry defaults, error
  handling, bundle output, telemetry, cache semantics, or algorithmic behavior.
  Changelog review and critical-path spot checks matter even when tests pass.
- Performance regressions can hide behind passing unit tests. Look for warnings,
  generated output changes, lockfile churn, transitive dependency changes, and
  runtime defaults in release notes.
- Do not accept a slower or more complex implementation because it is more
  generic unless the reviewed target proves the generic path is needed now.

## Validation And Regression Proof

- Performance tests should fail for the real regression: route latency,
  allocations, query count, bundle size, cache hit/miss behavior, queue
  throughput, or user-visible Web Vitals.
- Optimizations need functional regression proof too. If they touch data
  semantics, auth, caching, retries, or UI state, load the matching domain and
  tests lenses.
- Rollback or revert guidance is material when the change affects production
  latency, cost, resource limits, or operator runbooks.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- optimization lacks comparable baseline/after evidence while performance proof
  controls merge, rollout, or operator confidence
- change optimizes a non-hot path while leaving the measured bottleneck intact
- cache, batching, concurrency, or query change can serve wrong data, duplicate
  work, leak data, or amplify failures
- new path adds N+1 calls, unbounded scans, large client bundles, excessive
  allocations, high-cardinality metrics, or hot-path logging without proof
- dependency or default change can silently regress latency, memory, bundle
  size, retry behavior, or telemetry without targeted review
- benchmark, profile, Lighthouse, or CI artifact is stale, wrong target, wrong
  environment, or too narrow for the claimed production effect
- a long job can run an expensive first statement with no in-flight progress
  signal, leaving operators unable to distinguish healthy work from a stall
