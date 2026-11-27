<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Efficiency And Scale

Use this lane when code claims or can materially affect performance, scale,
query cost, memory, CPU, network or I/O fanout, bundle size, cache behavior,
latency, throughput, or cloud cost.

This lane is adapted from the Agentics `efficiency-improver` workflow. Keep
the measurement discipline and focus areas, but do not copy recurring bot
cadence, monthly activity issues, AI disclosure text, or generic
multi-language command snippets into example-app authoring.

## Rules

- No performance claim without a baseline or directly relevant evidence.
- Optimize the hot path only. Do not trade auth checks, validation, cache
  isolation, readability, or operator truth for unmeasured speed.
- Prefer query plans, representative cardinality, benchmarks, profiles, logs,
  metrics, or before/after command output over intuition.
- State proxy limitations when direct measurement is unavailable.
- Use proxy metrics deliberately: wall-clock time, CPU work, allocations,
  network bytes, payload size, query rows scanned, and cache hit/miss behavior.
- If an optimization makes code harder to read, explicitly justify why the
  measured gain is worth the maintenance cost.
- Do not add dependencies, benchmark infrastructure, deployment config, or
  broad caching layers without a tracked owner decision.

## Probes

- Does the change add N+1 calls, broader scans, larger payloads, extra
  serialization, repeated parsing, or cache misses?
- Does a query still use intended indexes after added filters, joins, or
  ordering?
- For migration, audit, validate, reconcile, cleanup, or bulk jobs, does the
  chunk/keyset boundary apply to every expensive statement in the phase, not
  just the obvious main statement?
- Could the first chunk or first statement run long enough that operators see
  no progress? If yes, require first-statement telemetry or a smaller bounded
  probe before claiming readiness.
- Does a loop or goroutine fanout have backpressure, cancellation, and limits?
- Does frontend code increase render churn, bundle size, waterfalls, or
  blocking work?
- Does UI performance evidence come from a production build when Lighthouse,
  Core Web Vitals, bundle size, or render cost is being used as proof?
- Does an optimization make failure modes, permissions, tenant boundaries, or
  state transitions harder to reason about?
- Is data over-fetched through `SELECT *`, unused fields, unbounded queries,
  missing pagination, redundant API calls, or database calls inside loops?
- Are static assets, images, long lists, polling loops, or repeated
  serialization doing avoidable work?

## Output Discipline

Report the measured proxy, the before/after evidence, and the limitation of
that proxy. If measurement is not available, treat the claim as
`Pending Verification` and prefer a smaller reversible change.

Do not present a timeout increase as an optimization or scale fix. It is only
acceptable as a diagnostic or owner-approved operational tradeoff when the
remaining query cost and liveness signals are explicitly documented.

For infrastructure, external API, or cloud-resource changes, include a rough
cost order of magnitude and the primary cost driver. Escalate or mark
`Pending Verification` when cost could scale faster than usage or when the
monthly impact is material.
