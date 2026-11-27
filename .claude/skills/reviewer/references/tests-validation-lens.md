<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-12 -->

# Tests And Validation Lens

Use this lens when the review touches tests, fixtures, mocks, snapshots, golden
files, browser/E2E helpers, CI validation claims, follow-up patches, bug fixes,
or any implementation where missing proof can change the verdict.

Reviewer owns assertion quality, wrong-green risk, behavior-contract coverage,
and relevance of provided validation. QA owns broader verification strategy,
lane ordering, flake policy, CI matrix design, and exploratory coverage.

## Review Order

1. Identify the changed behavior contract and public entry point.
2. Map which test or validation artifact is claimed to prove it.
3. Check whether that proof would fail if the production behavior regressed.
4. Check negative, edge, and failure paths proportional to risk.
5. Classify missing central proof as `BLOCKED`; classify non-central proof gaps
   as `Pending Verification` or residual risk.

## Proof Quality Standard

A useful test proves behavior through a public or stable contract. Prefer:

- user-visible route, handler, requester, API, queue, job, SQL query, generated
  contract, cache invalidation, feature flag branch, permission boundary,
  accessibility/locale path, or workflow behavior
- concrete assertions over no-error or existence-only checks
- real serialization, real routing, real permission/tenant scope, and real
  generated types when those are the behavior under review
- focused deterministic commands whose output names the changed package, test,
  route, or workflow
- failing-before/passing-after evidence for bug fixes when practical

Existence-only assertions are valid only when existence is the behavior.

For user-facing or operator-facing changes, passing tests is not the same as
value delivery. Check whether the proof maps to the stated value, acceptance
criteria, or workflow outcome. Runtime evidence can be manual verification, an
E2E flow, integration proof, staging or preview verification, or another
artifact that exercises the real path. If only code review or unit tests exist,
label the runtime gap instead of saying the feature was verified.

## Wrong-Green Patterns

Flag tests or validation that can pass while production fails:

- repository-file tests assume the process working directory, module root, or
  a fixed parent depth instead of discovering the checkout/worktree root from a
  stable marker or git metadata
- mocks bypass the real contract, schema, requester, auth, cache, or generated
  type
- mocks sit inside the system under test rather than at a real boundary, or so
  many mocks are required that the test mostly proves wiring instead of behavior
- assertions duplicate production logic instead of checking observable output
- fixtures cannot reach the regression, edge case, permission state, or old data
  shape
- aggregate or full-outer reconciliation fixtures omit multiple physical rows
  per logical key, one-sided classes, exact output cardinality, null payload
  semantics, signed delta direction, or the full lookup identity
- the changed branch is never exercised, the disabled/unset/invalid flag state
  is skipped, or coverage only touches setup code
- implicit `any`, broad casts, or generated mocks hide type drift
- private implementation details are over-coupled while public behavior is
  unasserted
- snapshot updates include broad unrelated churn without semantic isolation
- happy-path-only tests for auth, tenant, API compatibility, migration, cache
  invalidation, job retry/resume, accessibility focus, locale formatting,
  retry, cleanup, or rollback
- validation command succeeds without running the changed tests due to filters,
  skipped suites, missing package selection, or stale cache
- browser helpers swallow click, navigation, console, route, or assertion errors
- a changed expectation was edited to match current output without proving the
  old expectation was wrong from a requirement, bug report, spec, or current
  contract
- negative assertions against removed classes, fields, or strings that are no
  longer present in either good or bad output. Prefer positive assertions for
  the expected state so the test fails when the behavior is absent.
- fixture helpers that branch on human-readable test names, overwrite explicit
  caller inputs with defaults, or cast away valid union/interface cases. Those
  helpers can make future cases pass for the wrong reason.
- tests for gates, classifiers, validators, or reconcilers that exercise only
  the main allowed path while leaving alternate allowed branches, rejected
  evidence branches, mode-gating errors, or malformed-payload paths untested
- tests that use string literals for domain constants when production code has
  canonical constants or generated enum values, inviting typo drift between the
  fixture and real contract

## Unstable-Green And Flake Patterns

Flag validation that can pass or fail by luck:

- uncontrolled time, timers, timezone, locale, randomness, network, or external
  services
- shared mutable state, global mocks, test order dependency, cache reuse, or
  shared database rows
- direct use of singleton integration pools or shared database schemas from
  `t.Parallel` tests without the repo's isolation wrapper, semaphore, or mutex.
  DDL, triggers, global functions, and shared table mutations are especially
  suspect.
- package-local mutexes around shared integration pools must cover every test
  that installs DDL, triggers, functions, or table-wide state changes, not only
  the tests added in the latest patch.
- async polling without deterministic wait conditions
- arbitrary sleeps instead of event or state synchronization
- brittle CMS/user-visible copy selectors when stable structure exists
- snapshots tied to generated IDs, time, random order, or locale-specific output
- tests that rely on current date, user's machine, local browser profile,
  gitignored files, or remote mutable data
- package manager, build, or CI cache behavior treated as proof without cache
  invalidation awareness

## React, Next.js, And UI Tests

- React 19 Actions, form Actions, `useActionState`, `useFormStatus`, and
  `useOptimistic` need assertions for pending, success, error, duplicate submit,
  rollback, and authoritative server reconciliation.
- Next.js Server Components, Server Actions, cache tags, `updateTag`,
  `revalidateTag`, `refresh`, proxy/auth redirects, and async request APIs need
  tests or artifacts that exercise the relevant server/client boundary.
- UI tests should prove route, state setup, viewport where relevant, auth/tenant,
  feature flags, and expected user-observable result.
- Feature-flag, mode, datasource-option, or runtime-config tests should cover
  enabled, disabled, configured, unconfigured, invalid, old/new deploy, and
  failure combinations when those states change behavior or support an
  inert-rollout claim.
- Accessibility-sensitive UI changes should include keyboard, focus, role/name,
  form error, long-copy, locale, or RTL proof proportional to the changed UI, or
  a clear parent-requested browser artifact.
- Screenshots prove only the observed route, account, viewport, flags, browser,
  data, and commit. Do not generalize them.

## Go, Backend, SQL, And Migration Tests

- Backend tests should include success, relevant error, nil/empty input,
  permission/tenant denial, context cancellation, timeout, duplicate delivery,
  and partial failure proportional to risk.
- Transactional and mirror tests should include partial-success-then-failure
  paths, not only happy path and all-fail path. Assert rollback state and that
  downstream mirrors, logs, or summaries were not emitted from uncommitted work.
- SQL tests should assert query shape, ordering, tenant/user scope, null/empty
  behavior, write side effects, and generated scan shape.
- Tests for persisted CLI, config, API, or operator values should cover the
  value after unit conversion, rounding, truncation, serialization, nullable
  wrapping, or generated-type narrowing. Boundary cases include positive
  sub-unit values, fractional values, whole-unit values, zero, overflow or
  max-bound values, and the receiving database constraint.
- Tests for derived evidence should assert semantics, not just existence or
  counts. Summaries, samples, aggregates, deltas, null/non-null totals, status
  buckets, and operator-visible fields need fixtures that fail if the value is
  computed from the wrong source rows, state, tenant, user, or time range.
- Tests for session-level database behavior, especially advisory locks, must
  mirror production connection ownership. If production pins a connection,
  tests that pass a pool are wrong-green unless they prove acquire, mutation,
  and release stay on the same session.
- Tests for set-based mutations should fail when only a subset of selected rows
  is applied. Assert expected row count, affected row count, and final target
  state rather than only non-zero progress or no error.
- Classification, bucket, or repair fixtures should exercise each lifecycle
  that behaves differently. One accepted class is not proof for another accepted
  class when delete, restore, validate, reconcile, read, or cleanup semantics
  differ.
- Migration tests or rehearsal evidence should cover old/new compatibility,
  idempotency, chunking, rollback/down where meaningful, and post-deploy checks.
- Mutation-capable job tests should cover dry-run versus apply scope, empty
  input, no-op, first/last chunk, duplicate delivery, retry/resume, timeout,
  partial failure, cap and
  chunk enforcement at mutation time, stale proof rejection, skipped rows,
  partial failure, rollback failure, unknown commit outcome, rerun behavior, and
  operator-visible run-state truth.
- Operator-mode tests should cover both specific actionable failure messages and
  generic failure fallbacks. A branch that is supposed to explain the next safe
  action should be asserted directly, not only through exit status.
- Race, leak, integration, and load evidence are central only when the changed
  behavior depends on concurrency, resource lifetime, or scale.
- Version-sensitive static-analysis findings need repo-version proof before they
  become actionable. For example, loop-variable capture advice differs by Go
  version, so verify `go.mod`, `go.work`, toolchain, or CI image first.

## Follow-Up Patch Proof

For follow-up patches that claim to resolve prior findings:

- Map each prior accepted finding to current code and classify it as resolved,
  unresolved, out of scope with evidence, or superseded.
- Check that the patch fixes the root cause, not merely the visible assertion,
  lint error, comment wording, or failing branch.
- Require focused validation on the changed surface when the follow-up changes
  code, generated output, migration, workflow, or tests.
- Do not introduce unrelated new findings unless the follow-up creates material
  risk or reveals a previously hidden central issue.

## Validation Claims And Commands

- Never claim a command ran unless output exists for the current target.
- Verify command working directory, target package/path, filter, commit/head,
  environment, and whether the command can mutate files or external state.
- Tool permission failures are workflow evidence. They are code findings only if
  they prove repo misconfiguration central to the change.
- If a useful check cannot be run read-only, name the exact command/artifact,
  working directory, expected proof, and why it would flip the verdict.
- Broad slow/flake/paid/network/ML-only checks should not block when focused
  deterministic evidence already proves the behavior.

## Lint, Formatter, And Static-Analysis Changes

- Lint-only or formatter-only diffs should preserve runtime behavior. Flag
  control-flow, data-shape, error-handling, query, concurrency, or accessibility
  changes hidden inside a style cleanup.
- Formatter churn should be scoped to the configured tool and target files. Broad
  rewrites need evidence that the formatter, config, and file set are intended.
- Rule suppressions need the rule name, local reason, and smallest scope. A
  suppression that hides auth, data, query, error, concurrency, or test
  correctness should route to the owning implementation or security lens.
- Config changes that relax lint, typecheck, markdownlint, test, or static
  analysis behavior need the same review as any validation gate change: what
  signal is lost, what replaces it, and why CI remains trustworthy.

## Coverage Movement And Refactors

- Test refactors must preserve or strengthen behavior coverage. Check what moved,
  weakened, duplicated, skipped, or became implementation-specific.
- Snapshot/golden rewrites need semantic isolation and source-of-truth review.
- Removing a test is a behavior change unless the obsolete path is proven dead or
  replaced by stronger coverage.
- Generated coverage reports are leads; inspect the actual tests and changed
  behavior before accepting them.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- central behavior has no meaningful test or alternative proof
- supplied tests cannot fail for the claimed regression
- validation output is stale, wrong target, filtered away, or invented
- lint/formatter/static-analysis change weakens validation, hides behavior
  changes, or suppresses a material warning without local justification
- follow-up patch silences the symptom while root cause remains reachable
- flaky or wrong-green helper can make PRs pass despite broken login, route,
  auth, data, or workflow behavior
- broad snapshot/golden update hides unreviewed behavior change
- mutation-capable job tests prove only the happy path while stale proof,
  skipped rows, cap bypass, rollback/commit ambiguity, or operator-truth failure
  remains reachable
