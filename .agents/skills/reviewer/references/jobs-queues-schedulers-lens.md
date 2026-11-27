<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Jobs, Queues, And Schedulers Lens

## Mission

Review Cloud Run jobs, workers, cron/scheduled tasks, queue consumers,
Pub/Sub-like handlers, async processors, import/export jobs, reconciliation,
backfills, repair scripts, batch commands, retries, leases, ack/nack behavior,
and job run-state contracts for bounded, resumable, idempotent operation.

## Ownership And Boundaries

This lens owns async execution shape. Defer production data blast radius to
`sql-migrations-generated-lens`, `migration-safety-lens`, and the core
Production Blast-Radius Gate; defer failure semantics to
`silent-failure-fallback-lens`, concurrency/idempotency to
`concurrency-caching-consistency-lens`, operational evidence to
`observability-ops-lens`, and workflow/runtime config to
`ci-workflow-infra-lens`.

Do not ask reviewer to run live jobs, broad production scans, migrations, or
mutations as proof. Request bounded artifacts through Risk Evidence Handoff.

## Evidence And Dedupe

A finding needs current target evidence for a job/queue/scheduler path and a
reachable failure, scale, retry, timeout, permission, or operator-state gap.
Group docs, tests, config, and code symptoms under the same unsafe job contract.

## Review Probes

- Is the trigger, scope, input, dry-run/apply mode, cap, chunking, timeout,
  retry policy, idempotency key, lock/lease, terminal state, and operator
  entrypoint explicit?
- Can the job exceed Cloud Run, scheduler, queue visibility, DB transaction,
  provider rate limit, CI, or process timeout under production cardinality?
- Does retry/redelivery duplicate writes, notifications, exports, provider
  calls, cache invalidations, or run-state rows?
- Are empty input, no-op, partial success, retryable failure, permanent failure,
  timeout, cancellation, crash, and unknown commit outcome represented
  durably?
- For progress, success, and failure rows, is each write made with the context
  semantics its role requires? Terminal operator-truth writes after expensive
  work should not be canceled accidentally by the caller context when the
  primary work has already reached the point being reported.
- If a post-chunk cap, validation, finalization, or timeout check fails, does
  the failed outcome use durable committed chunk counts rather than a fresh or
  empty local result?
- Are queue messages acknowledged only after durable success or durable failure
  evidence, with poison messages handled deliberately?
- Are locks, leases, temp files, external reservations, and partial acquisition
  paths cleaned up on every error and shutdown path?
- Do service account permissions, env vars, secrets, scheduler names, regions,
  runtime limits, and runbooks match the code path being reviewed?
- Do chunk, retry, progress, and uncertain-commit logs include the stable run or
  job ID needed to join logs back to durable run-state rows?
- Do tests cover chunking, first/last page, duplicate/retry, failure, resume,
  and operator-visible run state?

## Triage

Missing idempotency, unbounded production-scale execution, misleading dry-run
coverage, unsafe ack/retry behavior, or absent terminal run state is material
when the job can mutate, export, notify, or authorize operator action. Pure
code-style concerns are not findings unless they affect those properties.

## Output Discipline

Findings should name the job contract field that is unsafe, the reachable state,
and the smallest proof/fix. Use Risk Evidence Handoff for production
cardinality, runtime config, IAM, timeout, scheduler, or bounded rehearsal
evidence unavailable to reviewer.
