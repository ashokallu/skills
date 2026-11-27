<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Test Quality

Use this lane when adding or changing tests, fixtures, mocks, snapshots,
integration coverage, CI checks, or validation scripts.

This lane is adapted from the Agentics `test-improver` workflow. Keep the
focus on valuable, maintainable tests, but do not copy bot cadence, monthly
activity issues, AI disclosure text, or generic branch/PR mechanics into
example-app code authoring.

## Mission

Improve confidence in behavior that matters. One good test for complex,
reachable behavior is better than many tests that only increase coverage.

Follow this mission sequence:

1. Understand the implementation and public behavior before writing tests.
2. Identify the bug-prone, critical, edge, or integration behavior worth
   proving.
3. Prefer existing repo test patterns and validated commands.
4. Add the smallest test that would fail for the real regression.
5. Treat failing tests as possible product evidence, not as text to rewrite
   until green.

## Authoring Posture

- Be thoughtful: focus on tests that catch real bugs in reachable behavior.
- Be concise: keep test names, fixtures, and handoff notes focused on the
  behavior and evidence that matter.
- Be mindful of maintenance: avoid brittle tests, fixture walls, and coverage
  padding that create more future work than confidence.
- Be transparent: state what the test proves, what command verified it, and
  what remains `Pending Verification`.
- Be restrained: when no high-value test opportunity exists, do not add a test
  just to prove the lane ran.

## What To Test

- Critical or bug-prone business logic
- Edge cases around errors, boundaries, null or empty states, cancellation,
  retries, partial failure, and race-sensitive behavior
- Aggregate and full-outer reconciliation fixtures with multiple physical rows
  per logical key and every equal, left-only, right-only, and differing class;
  assert cardinality, payload nullability, signed delta, and full identity
- Integration points: database, generated contracts, APIs, external services,
  queues, caches, auth, feature flags, observability/run-state, accessibility,
  i18n, and browser-visible flows
- Recently fixed bugs and review findings that should not regress
- Flaky tests when the task is to stabilize a real unreliable signal
- Shared test helpers or fixtures only when they reduce repeated complexity
  and make future tests easier to understand
- User-facing acceptance criteria expressed as Given/When/Then scenarios
- Auth boundaries: unauthenticated, unauthorized, expired-token, and malformed
  input behavior when the changed surface touches protected paths
- Tests that read repository files must discover the checkout or worktree root
  from a stable marker or git metadata, not assume the process working
  directory, module root, or a fixed number of parent directories

## What Not To Test

- Trivial getters, constants, or framework wiring with no meaningful logic
- Private implementation details when a stable public seam exists
- Duplicated production logic in assertions
- Brittle snapshots or fixture walls that hide the behavior being proved
- Tests that only increase coverage while missing the real failure mode
- Code you cannot explain. Misunderstood tests are worse than no tests.
- Constants or static values that only assert they equal themselves.

## Quality Checks

- Would this test fail for the regression we care about?
- Does it prove the integration point where the flag, API, job, cache, route,
  permission check, fallback, run-state, or UI actually does something?
- Does it cover high-value data shapes, not only one-row happy paths?
- Does it test behavior through a stable public seam instead of mocking the
  unit under test?
- Are mocks limited to real boundaries such as network, database, filesystem,
  clock, or external service?
- Are cleanup, test handles, and failure scopes correct for subtests and
  integration databases?
- Is the command narrow enough to run during development?
- Did you check whether the repo already has coverage, test, lint, format, and
  CI-equivalent commands for this surface before inventing one?
- Are generated reports, coverage files, benchmark outputs, and transient test
  artifacts kept out of commits?
- When validated input is persisted after unit conversion, rounding,
  truncation, serialization, or generated-type narrowing, does the test cover
  boundary values after conversion? Include positive sub-unit values,
  fractional values, exact whole-unit values, zero, overflow or max-bound
  behavior, and the database constraint that will receive the stored value.
- For database integration tests, are shared pools, singleton suites, global
  migrations, DDL, triggers, advisory state, and package-level locks routed
  through the repo's isolation helper instead of bypassed in `t.Parallel()`?
- For tests that exercise session-level database behavior, especially advisory
  locks, does the test use the same pinned connection or transaction ownership
  as production? Passing a pool where production uses one session can make the
  test wrong-green or leak locks.
- For transaction-local database settings, does the test exit through the same
  path as production and recheck the same pinned connection afterward? A
  rollback-only test can hide a setting that leaks after commit.
- Does the fixture represent the real producer's stored shape, including
  nullable fields, omitted fields, raw evidence payloads, and classification or
  overlay rows that differ by category?
- For set-based data mutations, does at least one test fail when only a subset
  of selected rows is actually applied? Assert expected rows versus touched rows
  and final target state, not just non-zero progress.
- When classifications, buckets, or repair classes differ, does test coverage
  exercise each lifecycle separately instead of relying on one accepted class as
  a proxy for all accepted classes?
- If a helper supplies default fixture values, can it silently overwrite an
  explicit caller value or hide a missing required field?
- Would the test still pass if the production gate matched `NULL` as zero,
  required an overlay for a no-overlay classification, emitted the wrong
  operator error, logged a resolution that did not happen, served a stale cache
  entry, retried a duplicate side effect, or skipped the disabled flag branch?

## Test Failure Discipline

For database-changing work, construct the applicable evidence matrix rather
than one universal suite. Cover the claims that matter across:

- clean install, supported production/fleet upgrade states, old/new schema and
  code coexistence, rollback code on forward schema, and delayed consumers;
- partial or ambiguous commit, dirty migration state, cancellation, connection
  loss, process death, pause/resume, retry, and recovery;
- organic writers, multiple migration workers, deadlock/serialization, lease
  expiry, failover, and other adverse interleavings;
- malformed, duplicate, orphan, null, skewed, hot-key, and largest-tenant or
  shard data;
- live-DDL lock queues, long blockers, timeout scope, invalid residue, runner
  transaction parity, plans/statistics, resource peaks, and rollback cost;
- independent reconciliation, partial-target convergence, restore/failover
  RPO/RTO and integrity, tenant/RLS/role denial, redaction, retention, and
  deletion propagation.

Record every material difference between the harness and production engine,
version, runner, transaction mode, topology, privileges, collation, statistics,
scale, and concurrency. Preserve failed rehearsal evidence and state untested
populations. The author constructs this evidence; the selected reviewer lanes
judge the claims it supports.

- Never modify tests just to force them to pass.
- If the test expectation is correct and production code fails it, treat that
  as a potential bug and fix the code or report the finding.
- Only change expectations when current docs, code contracts, or owner
  guidance prove the old expectation was wrong.
- Document the reasoning when a test expectation changes.
- Do not add runner-specific flags unless the repo script or runner help proves
  the flag is supported. If a command fails because of an unknown flag, rerun
  the baseline repo command before changing code.

## Clean Result

If no high-value test opportunity exists, say so. Do not add low-value tests to
prove the lane ran.
