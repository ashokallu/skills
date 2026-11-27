<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Jobs, Queues, And Schedulers Authoring

Use this lane for Cloud Run jobs, workers, cron/scheduled tasks, queue
consumers, Pub/Sub-like handlers, async processors, import/export jobs,
reconciliation, backfills, repair scripts, batch commands, retries, leases,
ack/nack behavior, and job run-state contracts.

## Mission

Author async work so it is bounded, resumable, idempotent, observable, and safe
to retry. A job is not safe because it succeeds on a small local fixture; it is
safe when timeout, shutdown, retry, partial progress, and operator evidence are
first-class.

## Boundaries

Also load `production-data-safety` for mutation-capable or production-scale
jobs, `sql-migrations-and-data-contracts` for persistence/query changes,
`resilience-and-fallbacks` for failure paths, `concurrency-caching-consistency`
for locks/idempotency, `observability-and-operations` for run state, and
`ci-workflow-authoring` for scheduler/deploy/runtime config.

Do not add a background job to hide user-visible latency unless the product,
consistency, retry, and operator implications are explicitly accepted.

## Authoring Sequence

1. Define the job contract: trigger, inputs, scope, dry-run/apply mode, cap,
   chunking strategy, idempotency key, lock/lease, timeout, retry policy,
   terminal statuses, and operator entrypoint.
2. Inspect existing job patterns, scheduler/workflow config, service account,
   permissions, env vars, secrets, resource limits, runbooks, and tests before
   editing.
3. Make empty input, no-op, partial success, retryable failure, permanent
   failure, timeout, cancellation, and unknown commit outcome explicit.
4. Process in bounded chunks or keyset pages when data can grow. Persist enough
   progress to resume safely after timeout or crash.
   Progress and terminal rows must separate started, completed, committed, and
   failed-after-commit work so retries and operators do not mistake an
   attempted chunk for a durable mutation.
5. Acknowledge queue messages only after durable success or durable failure
   recording. Dead-letter or retry poison messages deliberately.
6. Keep dry-run and apply semantics equivalent where dry-run authorizes apply;
   loudly document anything sampled, capped, skipped, or environment-specific.
7. Emit durable run summaries and safe structured logs/metrics that let
   operators decide next action.

## Prevention Probes

- Can the job exceed Cloud Run, queue visibility, database transaction, provider
  rate limit, CI, or scheduler timeout under production cardinality?
- Does retry duplicate writes, send duplicate notifications, re-export data, or
  lose progress after a crash?
- If cancellation or timeout arrives during terminal progress/failure/success
  recording, does that bookkeeping use an intentional detached narrow context
  when the write is needed to preserve durable operator truth?
- Are locks or leases released on partial acquisition failure, timeout,
  cancellation, panic, and normal completion?
- Does a capped or sampled run claim complete coverage or update evidence that
  later paths treat as authoritative?
- Are service account permissions, env vars, secrets, scheduler names, regions,
  and runtime limits aligned across code, workflow config, and runbook?
- Do per-chunk and uncertain-commit logs include the stable run/job identifier
  needed to correlate them with durable run-state and progress rows?
- Do tests cover empty input, first chunk, last chunk, duplicate/retry, failure,
  and resume states?

## Validation

Prefer a focused dry-run/apply fixture, job unit tests over chunking and resume,
queue retry/ack tests, and config readback for scheduler/runtime limits. For
production jobs, require bounded rehearsal, cardinality/timeout model, or exact
`Pending Verification` before claiming readiness.

## Output

```text
Jobs/queues authoring:
- job contract: <trigger, scope, mode, cap/chunk/retry/idempotency>
- operator state: <run-state/logs/metrics/runbook>
- proof: <tests/dry-run/config readback or Pending Verification>
```
