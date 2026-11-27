<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Backend And Go Lens

Use this lens when the review touches Go backend code, controllers, datasources,
services, queues, caches, jobs, config, CLIs, generated mocks, package
boundaries, telemetry, or external integrations.

This lens assumes the Go version declared by `go.mod`, `go.work`, toolchain
pins, CI images, or repo docs. Only apply Go 1.26-specific probes when those
repo files confirm the reviewed target is actually on Go 1.26.

## Review Order

1. Identify changed exported symbols, handlers, methods, interfaces, jobs,
   queues, cache keys, and generated mocks.
2. Map inbound callers, outbound dependencies, data stores, retries, and
   cancellation paths.
3. Check old/new compatibility across rolling deploys, stale clients, duplicate
   delivery, and partially migrated data.
4. Inspect tests for success, error, cancellation, concurrency, auth/tenant, and
   generated-mock coverage.
5. Ask for narrow command output only when read-only safe evidence is missing.

Use `api-contracts-integration-lens` alongside this lens when REST, requester,
webhook, provider, status/error envelope, or old/new client compatibility
changes. Use `auth-permission-tenant-lens` when permission or tenant scope
changes, `concurrency-caching-consistency-lens` when cache/lock/idempotency
changes, and `jobs-queues-schedulers-lens` when async work, schedulers, or
run-state behavior changes.

## Package And Boundary Ownership

- Preserve existing controller, datasource, rest_service, queue, cache, config,
  job, and integration ownership boundaries unless the diff includes a justified
  architectural move.
- Check whether an interface change updates all real implementations, generated
  mocks, tests, call sites, and cross-stack consumers.
- Do not accept a new wrapper/service layer that only forwards calls while
  hiding errors, context, auth scope, observability, or transaction ownership.
- Ensure public handler, queue, event, cache-key, or protocol changes are
  backward and forward compatible when old and new versions can overlap.
- New exported symbols should have a real consumer or documented extension point;
  otherwise they can be dead API surface that future code misuses.

## Errors, Context, And Cleanup

- Check every returned error on I/O, SQL, external calls, JSON decoding,
  response writing, transactions, cache operations, and telemetry exporters.
- Preserve existing error mapping to HTTP status, public message, internal log,
  retry behavior, and caller contract.
- Avoid raw internal errors in user-facing responses or logs that can expose PII,
  tokens, SQL, stack traces, or tenant identifiers.
- Context must propagate from request/job caller into database, HTTP, cache,
  queue, and downstream services unless a bounded background reason is proven.
- Treat `context.Background()` and `context.WithoutCancel()` in cleanup,
  rollback, disconnect, or close paths as reviewable. They need a short timeout,
  caller-owned cancellation rationale, or repo-backed invariant.
- Transactions that mutate durable data need a distinct ambiguous-commit path.
  If `Commit` can return after the database may have committed, review whether
  the code re-reads durable state, records uncertainty, or avoids marking the
  run failed or retryable incorrectly.
- When a best-effort mirror, cleanup, failure recorder, or secondary write runs
  after a primary side effect, verify request cancellation cannot silently skip
  the follow-up and leave unreconciled state. Detached cancellation still needs
  a bounded context, logging, and later reconciliation evidence.
- Rollback, disconnect, cleanup, and close paths need explicit error handling and
  bounded work. Silent cleanup failures are material when they can corrupt data,
  leak resources, or hide partial writes.
  Verify the bounded context reaches the actual I/O call and that a helper does
  not erase an error its caller needs to log, classify, or reconcile.
- New external clients, resolvers, data loaders, or API integrations need an
  explicit lifetime owner. Confirm response bodies, clients, pools, and
  background resources are closed on every service, job, and test path that
  creates them.

## Concurrency And Resource Safety

- Watch for goroutine leaks, unbounded workers, channel sends after early return,
  missing close paths, blocked receives, forgotten `Wait`, and lost cancellation.
- Use `errgroup`, semaphores, bounded channels, contexts, or repo patterns when
  parallelism can grow with request size, tenant size, import size, or queue
  backlog.
- Check for loop-variable capture, shared mutable state, races, unsynchronized
  maps/slices, test-only race hiding, and data structures reused across requests.
- Advisory locks, leases, and other partial acquisitions need error-path
  cleanup for the subset already acquired. Review failure on the Nth acquisition
  separately from full success and ordinary release.
- Lock scope should match the conflict key. A lock that blocks all live writes
  while only one user/category/tenant overlaps is a correctness and availability
  risk when the live path has a short timeout or fail-open mirror budget.
- Channel and goroutine patterns need proof for early error, timeout,
  cancellation, panic, partial result, and producer/consumer shutdown.
- Do not rely on a goroutine leak profile or race detector claim unless the
  command actually ran on the changed path. When unavailable, name the focused
  leak/race evidence the parent should provide.
- Resource ownership must be explicit for response bodies, files, iterators,
  rows, transactions, timers, tickers, subscriptions, pub/sub consumers, and
  stream readers.
- Session-level database state such as advisory locks must have explicit
  connection ownership. If production uses a pinned connection, helper calls and
  tests that pass a pool are not equivalent unless the code proves acquisition,
  mutation, and release stay on the same session.

## HTTP, External Integrations, And Queues

- External calls need timeouts, retry budget, backoff, idempotency, rate-limit
  handling, status/body handling, response body close, and safe observability.
- Retries must not duplicate writes, re-enqueue irreversible work, or amplify
  partial outages without idempotency keys or dedupe.
- Queue handlers need ack/nack semantics, poison-message behavior, visibility
  timeout fit, tenant/user scope, retry caps, and duplicate delivery handling.
- Cache changes need key versioning, tenant/user/permission inputs, TTL fit,
  stale-read semantics, invalidation, and cold-start behavior.
- Partial failures should be visible to callers or operators; do not accept
  silent best-effort behavior when users rely on all-or-nothing results.

## Data, Auth, Tenant, And Privacy

- Protected handlers, datasources, and jobs must prove user, tenant,
  organization, role, and permission scope at the correct boundary.
- Do not rely on frontend gating, caller comments, test fixture names, or route
  naming as authorization evidence.
- Check that tenant/user constraints are carried through SQL, Mongo, caches,
  events, jobs, logs, metrics, and external requests.
- PII and learner data in logs, traces, metrics, events, errors, fixtures, or
  queue payloads must be redacted, minimized, or explicitly allowed by policy.
- Background jobs and repair scripts often bypass request auth; verify their
  owner, input scope, dry-run/safety controls, and audit trail.

## Mutation-Capable Jobs And Apply Paths

- Treat dry-run, audit, validate, apply, reconcile, finalize, and repair paths as
  production blast-radius surfaces, even when the diff looks like ordinary Go.
- Dry-run or capped evidence must match the semantic scope of the write it
  authorizes. A clean capped run cannot authorize a broader apply unless code
  enforces the same cap, chunk, or fail-closed boundary at mutation time.
- Freshness checks must happen at the point that controls mutation, not only
  before setup, flag parsing, or long-running reads.
- Invariants checked before a later `FOR UPDATE`, conflict update, or final
  mutation must be rechecked after the protecting lock is held, or in the same
  statement that writes. Live writes can change target state between setup and
  mutation.
- Apply paths need bounded transaction finalization, explicit rollback/commit
  error handling, idempotency, resumability, durable run-state truth, and clear
  behavior for unknown commit outcome.
- Chunked jobs must persist chunk output and checkpoint/progress atomically, or
  prove retry idempotency. A retry after a checkpoint failure must not duplicate
  durable evidence, double-count summaries, or skip already committed rows.
- Custom failure paths must preserve the same terminal-state invariants as the
  shared reporter path: status, finished timestamp, error message, durable
  counters, and retry/resume visibility should agree.
- Shutdown, cancellation, and timeout handling must not strand partial writes or
  report success after rollback, skipped rows, stale proof, or unknown outcome.
- Operator-visible logs, metrics, run records, and summaries must distinguish
  sampled/capped/partial work from global success.
- Operator evidence must mean exactly what it says. Counters, logs, summaries,
  and metrics should distinguish attempts, chunks, upserts, touched groups,
  inserted rows, durable rows, final table state, partial samples, retries, and
  skipped work so operators cannot sum or compare them incorrectly.
- Starting, resuming, or resetting a sub-phase must not hide existing blockers or
  evidence from earlier phases. Summary counters should match the durable rows
  and the operator filters that humans will use to decide the next gate.
- Fail-closed gates should reject missing or malformed evidence with actionable
  context. Do not coerce absent payload fields, missing IDs, or unresolved
  categories into zero or empty values that can accidentally match a valid case.
- Verify which database connection each read and write path uses: primary
  versus read replica. Long replica reads need a recovery-conflict and
  cancellation story; moving them to primary needs a load and locking
  rationale.

## Version-Specific Go Probes

- The `go` line, `toolchain` line, and CI image control language semantics and
  available APIs. Do not assume Go 1.26 features are allowed when module files
  or CI images target an older version.
- When the reviewed target is confirmed to use Go 1.26, inspect the
  version-matched release notes or repo-owned migration guidance before
  accepting syntax, runtime, crypto, profiling, or standard-library behavior
  changes as safe.
- `go fix` modernizers should be treated as code changes, not magic. Review the
  resulting diff for behavior preservation, generated-file drift, and tests.
- Performance, GC, profiling, or cryptography claims require benchmarks,
  reproducible runtime evidence, or version-matched documentation on the changed
  workload; do not accept generic speed or safety claims.

## SQL, Generated Mocks, And Cross-Stack Contracts

- When SQL, sqlc, migrations, generated mocks, or request/response types change,
  load the SQL/generated lens and review source plus generated output together.
- Removed or replaced SQL queries, generated methods, mocks, and helpers should
  leave no dead generated surface or stale callers. Search both source SQL and
  generated output before accepting "unused" or "replaced" claims.
- Generated names are still public contracts inside the repo. Check acronym,
  initialism, nullability, slice, and timestamp naming against local generated
  conventions before accepting broad generated churn.
- Generated mocks must encode the real interface contract, including errors,
  nils, context cancellation, and multiple calls where relevant.
- Test-only mock changes can weaken production coverage. Check whether a mock now
  accepts impossible inputs, ignores context, returns happy-path defaults, or
  bypasses auth/data checks.
- Backend response-shape changes need frontend requester and UI consumer review.

## Tests And Validation For Go Changes

- Targeted tests should cover success, relevant errors, nil/empty inputs,
  permission/tenant denial, cancellation, timeout, duplicate delivery, and
  partial failure proportional to risk.
- For transactional or dual-write changes, include the uncomfortable path where
  one item succeeds, a later item fails, and downstream mirrors or side effects
  must not run. Happy-path and all-fail tests are not enough for atomicity
  claims.
- Table-driven tests are only useful if cases exercise distinct behavior and
  assert concrete outputs, side effects, logs, metrics, or storage changes.
- Race, leak, integration, sqlc, migration, or external-service tests are
  central only when the changed risk depends on them. If central and unavailable,
  use `BLOCKED`; otherwise request them as residual proof.
- A test that only asserts no error from a mocked dependency is usually weak.
  Require public behavior, persisted state, emitted event, or error mapping.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- missing or wrong auth, tenant, organization, role, or permission enforcement
- ignored error, context loss, cleanup failure, or transaction mistake that can
  corrupt data, leak resources, or mislead callers
- goroutine/channel/retry pattern can leak, deadlock, duplicate writes, or create
  retry storms
- exported interface or generated mock change leaves callers stale or tests
  wrong-green
- public handler, queue, event, cache, or protocol change is not rolling-deploy
  compatible
- logs, errors, metrics, or payloads expose secrets, tokens, or PII
- validation cannot exercise the changed backend behavior and no alternative
  central proof exists
- mutation-capable job can authorize or perform broader writes than the dry-run,
  capped, or validation proof actually covered
- apply/finalize path can report success, clean coverage, rollback, or durable
  counts incorrectly after skipped rows, partial commit, rollback failure, or
  unknown commit outcome
