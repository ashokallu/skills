<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-28 -->

# Silent Failure And Fallback Lens

Use this lens when the diff changes error handling, catch blocks, fallback
chains, retries, timeouts, optional chaining on effectful paths, best-effort
behavior, mocks or stubs, empty/default returns, partial-success handling, or
operator-visible failure evidence.

The goal is to distinguish intentional degradation from hidden failure. A
fallback is safe only when the relevant caller, user, operator, test, or retry
path can still tell what happened and what state is durable.

## Review Order

1. Identify the operation that can fail and the caller or user that depends on
   the result.
2. Check whether the changed code catches only expected errors, or can suppress
   unrelated bugs, auth failures, data loss, deploy issues, or contract drift.
3. Trace the fallback output to callers, UI, jobs, logs, metrics, retries, and
   tests.
4. Decide whether the fallback is explicitly required by product/runtime
   behavior, or whether it masks a defect that should fail closed.
5. Verify that exhausted retries, partial work, skipped work, and unknown
   outcomes are visible to the owner who can act on them.

## High-Risk Patterns

Flag material issues when reachable:

- empty catch blocks, broad catch-all handlers, or `log and continue` paths that
  hide a failed required operation
- returning `null`, empty arrays, zero counts, default objects, or success-like
  responses on error without caller-visible failure semantics
- treating zero affected rows, skipped inputs, filtered rows, or partial
  set-based progress as success when the caller expects every selected row,
  mirror write, evidence row, or repair candidate to be processed
- optional chaining or `||`/`??` defaults that silently skip writes, permission
  checks, event emission, cleanup, metrics, or generated-contract validation
- defaulting missing evidence fields, unresolved IDs, absent categories, or
  malformed payload values into zero/empty values that can pass a comparison or
  gate as if the evidence were valid
- fallback chains that use stale cache, sample data, test doubles, mocks, stubs,
  or placeholder data outside an explicitly bounded test/demo path
- retries that exhaust without surfacing final failure, idempotency status,
  partial side effects, or next operator action
- error handling that treats permission denial, missing config, schema drift,
  timeout, cancellation, and user absence as the same safe default
- UI or API success states that can be shown while the server action, backend
  mutation, queue publish, cache invalidation, or generated request failed
- fallback, empty-state, default-value, or error paths that do not use the same
  feature-flag, mode, datasource-option, or runtime-config activation contract
  as the main path
- early returns in apply, validate, audit, mirror, or reconcile paths that emit a
  generic error while bypassing context-aware gate evidence, operator records, or
  failure details needed for the next safe action
- request-context cancellation after a primary write that prevents a best-effort
  mirror, repair marker, or failure log from running, leaving no observable
  follow-up for reconciliation
- fail-open mirrors or repair markers that share the caller request context
  after a durable primary write, when cancellation can create avoidable drift or
  noisy failure records instead of completing the compensating evidence path
- fail-open mirrors, materializers, validators, or reconcilers whose skipped
  work is not durably recorded with enough scope for retry, repair, or operator
  decision making
- diagnostic telemetry, progress markers, metrics, logs, or best-effort
  secondary writes whose failures are propagated as primary operation failures
  without an explicit fail-closed contract
- commit, cleanup, or finalization paths that intentionally remove caller
  cancellation but also bypass the operator's explicit duration or timeout cap
- custom error types whose `Error()` string is a machine payload instead of a
  concise human summary, causing logs, persisted run errors, and wrapped errors
  to hide the actionable failure reason

## Required Evidence

For passable fallback behavior, reviewer should be able to point to at least one
of these:

- caller-visible error, status, or typed result that distinguishes fallback from
  success
- user-facing recovery path that does not leak sensitive implementation details
- operator-facing log, metric, run-state, alert, or artifact that names the
  failed operation and durable state
- retry, idempotency, cleanup, or rollback behavior that is bounded and tested
- explicit product/runtime requirement that degradation is preferable to
  failing closed, with tests proving the degraded state
- proof that disabled or unconfigured states remain inert through fallback,
  empty-state, default-value, and error paths, not only through the happy path

## Output Discipline

- Do not flag every fallback. Flag fallbacks that can hide correctness,
  security, data integrity, deployability, or operator-truth failures.
- Treat missing evidence as `Pending Verification` when non-central; use
  `BLOCKED` or Risk Evidence Handoff when silent failure would control merge,
  rollout, rollback, data safety, or incident response.
