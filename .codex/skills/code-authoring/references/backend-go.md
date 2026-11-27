<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Backend Go Authoring

Use this lane for focused example-app Go backend changes: services,
controllers, datasources, REST handlers, SQL-backed behavior, backend tests,
interfaces, generated mocks, and generated-code-aware edits.

## Mission

Own backend behavior end to end. Map the execution boundary, identify the root
cause or design gap, implement the smallest durable fix, and verify it with
task-local evidence.

Follow this sequence:

1. Read the relevant path in execution order before editing:
   `datasource.go` -> `controller.go` -> `rest_service.go`, plus
   `backend/services/api/main.go` when dependency wiring matters.
2. Identify the domain owner, caller, auth/permission boundary, data source,
   API contract, generated source of truth, cache/queue/job boundary, and tests
   that prove the behavior.
3. Add or adjust focused regression coverage first when feasible. If RED cannot
   be demonstrated, mark the exact gap `Pending Verification`.
4. Implement the smallest production change that corrects behavior without
   broad package restructuring, compatibility shims, speculative abstraction,
   or new config knobs.
5. Validate the changed success path, one relevant failure path, and one
   integration boundary.

## Backend Contracts

- The domain triad is the default shape: datasource owns raw SQL, Mongo, cache,
  or external I/O; controller owns business orchestration; REST service owns
  Gin routes, binding, auth middleware, response encoding, and HTTP status
  mapping.
- Keep Gin out of controllers and datasources. Controllers consume request
  contexts, not `*gin.Context`.
- Route auth and permissions must be explicit:
  `auth.MustBeAuthenticated`, `auth.OptionallyAuthenticated`, and
  `PermissionVerifier.MustHavePermission` where the route family requires them.
  Load `auth-permissions-identity` when protected resources, tenant scope,
  service accounts, admin/operator modes, or gated API behavior changes.
- Map REST handler errors through `shared.ErrorToHTTPStatusCode(err)`. Do not
  hardcode domain error status codes in new handlers.
- Use shared sentinel errors and `types.ConstError` patterns. Wrap errors with
  context using `%w` and check them with `errors.Is`.
- Use structured logging and existing log key constants. Never log secrets,
  cookies, tokens, saved auth state, raw sensitive payloads, or PII.
- Propagate context through SQL, Mongo, cache, Pub/Sub, RPC, and goroutine
  boundaries. New goroutines must have a clear lifecycle, cancellation path,
  shutdown or ack behavior, and explicit handoff to `jobs-queues-and-schedulers`
  or `concurrency-caching-consistency` when async or shared-state behavior
  changes.
- For best-effort work after a successful primary effect, choose context
  behavior deliberately. A canceled request context may be correct for request
  work, but mirror writes, cleanup, failure recording, and resolution steps may
  need `context.WithoutCancel` plus a fresh narrow timeout so durable visibility
  survives client disconnects and expired sub-deadlines.
- Do not use `ctx.Err() == nil` as proof that a context still has enough budget
  for required durable bookkeeping after partial or expensive work. When a
  skipped subset, committed partial result, or convergence path depends on a
  failure record, allocate its detached narrow timeout at the point of
  recording and test both still-active and already-expired source contexts.
- For transactions that mutate durable data, handle ambiguous commit outcomes
  separately from ordinary rollback. Do not mark a run failed, retryable, or
  clean after `Commit` returns an uncertain error unless durable state is
  re-read or the outcome is explicitly marked for operator verification.
- Keep the total latency budget for optional secondary work explicit. Do not
  stack independent timeouts on the request critical path when the feature is
  intended to be fail-open.
- Nil-check optional collaborators before effectful calls when construction
  paths can omit them. A feature flag, missing SQL querier, publisher, cache,
  or notifier should fail safely instead of panicking the live path.
- Session-level database state such as advisory locks must have explicit
  connection ownership. If production pins a connection, helpers and tests must
  use the same pinned-connection shape; pooled calls that may acquire, mutate,
  and release on different sessions are not equivalent.
- Partial acquisition paths need cleanup before returning. When a loop acquires
  locks, leases, resources, or external reservations and later acquisition can
  fail, release the already-acquired subset on the error path, not only after
  full success.
- Lock scope should match the actual conflict key. Avoid global or broad locks
  that serialize unrelated live writes when per-user, per-category, per-tenant,
  or transaction-scoped locking can preserve correctness without degrading the
  hot path.
- Prefer repo abstractions for time and IDs when surrounding code already uses
  them.
- Keep interfaces small and consumer-owned. Preserve existing exported
  exceptions instead of broadening interfaces for convenience.
- Prefer direct readable code, early returns, and narrow state. Do not add
  optional params for required values or wrappers that only move complexity.

## Data, SQL, And Generated Code

- Never hand-edit generated files such as `backend/internal/shared/sql/*.go`,
  `backend/internal/**/mock/mock_*.go`, or files marked `DO NOT EDIT`.
- For SQL queries, domain interfaces with mocks, or Postgres migrations, also
  load `backend-codegen` and `production-data-safety`.
- SQL queries live in `backend/internal/shared/sql/queries/*.sql` and must keep
  sqlc annotations: `-- name: QueryName :one|:many|:exec`.
- Use generated sqlc methods and parameterized queries. Do not hand-write
  equivalent ad hoc SQL in Go.
- New migrations must be linearly numbered, reversible, rolling-deploy aware,
  and checked with the repo migration validation path.
- Use read-only SQL pools for SELECT paths when the existing domain separates
  read and write pools.
- Cache errors should follow local conventions. Optional cache failures are
  usually logged and swallowed; do not make cache failure break primary
  behavior unless the surrounding contract requires it.

## Validation

- Run Go commands from `backend/` unless a repo task explicitly wraps them.
- Targeted lane first: changed package test or focused `-run` test.
- Standard lane before done when feasible: `go build ./...` and
  `go test ./...`.
- Deep lane when risk justifies it: race tests, configured lint, codegen, or
  migration checks.
- For endpoint changes, add or update table-driven tests using existing test
  helpers, especially `testutil.GinEndpointTester` where that pattern already
  exists.

## Output

```text
Backend Go authoring:
- boundary: <service/controller/datasource/route/query>
- source of truth: <files and generated owner>
- validation: <commands or Pending Verification>
- residual risk: <none or exact gap>
```
