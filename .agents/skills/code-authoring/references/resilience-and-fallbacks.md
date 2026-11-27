<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Resilience And Fallbacks Authoring

Use this lane for retries, timeouts, cancellation, partial failure, fallback
values, best-effort paths, fail-open/fail-closed choices, circuit breakers,
cache fallbacks, `catch` blocks, optional chaining on effectful paths, default
returns, cleanup, and user/operator-visible failure semantics.

## Mission

Make failure behavior deliberate and observable. A fallback is a product and
operational decision, not a way to hide an exception so the happy path keeps
looking green.

## Boundaries

Also load `api-contracts-and-integrations` for public error/status behavior,
`auth-permissions-identity` when denial can be mistaken for recoverable failure,
`concurrency-caching-consistency` for stale cache or race windows,
`observability-and-operations` for failure evidence, and `test-quality` for
failure-injection proof.

Do not introduce new retry frameworks, queues, caches, or circuit breakers for a
narrow bug unless local precedent and the failure mode justify the ownership.

## Authoring Sequence

1. Classify each failure: caller error, auth/permission denial, missing data,
   dependency outage, timeout, cancellation, conflict, duplicate, retryable,
   permanent, partial success, or unknown outcome.
2. Decide the safe behavior before editing: fail closed, fail open, no-op,
   retry, compensate, surface error, persist failure evidence, or ask operator.
   For secondary effects such as telemetry, progress markers, mirrors, cleanup,
   or failure recording, explicitly decide whether the secondary effect is
   required correctness or best-effort diagnostic support. A best-effort
   secondary effect must not be wired so its own transient failure turns the
   primary operation into failure.
3. Put recovery at the boundary that can act. Lower layers should return typed
   errors/context; boundary layers translate to user messages, status codes,
   logs, metrics, or run state.
4. Bound retries with timeouts, jitter/backoff, idempotency, dedupe keys, and a
   terminal state. Do not retry non-idempotent mutations blindly.
5. Preserve cancellation and cleanup. If work must outlive a request, use an
   explicit detached context with a narrow timeout and durable visibility.
   Verify that bounded context reaches the actual close, disconnect, rollback,
   or terminal-state call. Return or boundedly log cleanup errors needed for
   recovery and operator diagnosis; helpers must not erase them merely because
   cleanup is best effort.
6. When concurrent pipeline stages stop together, drain and join independent
   failures. Preserve preexisting caller or deadline cancellation, but do not
   report cancellation deliberately issued after successful completion as a
   new failure; test both origins.
7. Avoid silent defaults. Empty arrays, `null`, zero values, stale cache, and
   optional results must mean the same thing to producers and consumers.
8. Add tests or harnesses that force the failure path. A test that only proves
   the fallback value exists is not enough when the original error disappears.

## Prevention Probes

- Does a catch block, `Promise.allSettled`, `recover`, optional chaining,
  `errors.Is`, broad `default`, or empty return swallow a material failure?
- Can a fallback serve stale, public, cross-tenant, wrong-locale, or wrong-mode
  data after auth, cache, provider, or request failure?
- Do retry and timeout budgets compose, or can nested timeouts exceed the user,
  job, CI, provider, or Cloud Run limit?
- Are unknown commit outcomes, partial batch writes, ack/nack ambiguity, and
  cleanup failures represented durably before retry or success?
- Can a best-effort telemetry, progress, log, metric, mirror, cleanup, or
  failure-recording write fail independently of the primary work? If yes, does
  that failure have bounded logging or durable visibility without rolling back
  or aborting the primary work unless fail-closed coupling is the explicit
  product decision?
- Does the user see an actionable safe message while operators get enough
  detail to diagnose without leaking sensitive payloads?
- Are success logs, run summaries, UI toasts, or API statuses truthful when
  secondary best-effort work failed?

## Validation

Prefer failure-injection tests that make the dependency fail at the real seam:
mocked provider errors, context cancellation, timeout, duplicate callback,
partial batch failure, cache miss/stale hit, auth denial, or commit ambiguity.
For UI paths, cover loading/error/retry states with deterministic waits. For
jobs, cover retry, resume, terminal state, and idempotent re-run.

## Output

```text
Resilience/fallback authoring:
- failure classes: <states considered>
- chosen behavior: <fail-open/fail-closed/retry/no-op/etc.>
- observability: <user/operator signal>
- proof: <failure-injection test or Pending Verification>
```
