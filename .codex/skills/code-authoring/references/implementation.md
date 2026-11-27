<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Code Implementation

Use this lane before code edits, refactors, scripts, tests, workflows, config
changes, dependency changes, generated outputs, or implementation pattern
choices.

## Authoring Standards

- Tie behavior changes to the request, verified defect, acceptance criterion,
  or observable outcome. Mark inferred or unproved value as
  `Pending Verification`.
- Make surgical changes. Every changed line should trace to the request,
  verified defect, or required validation.
- Inspect nearby examples before creating a component, handler, test,
  migration, script, workflow, or helper. Match local layout, naming, typing,
  fixture style, and validation pattern.
- Prefer direct readable code over cleverness, speculative flexibility, or
  reusable-looking wrappers that add cognitive load.
- Reuse existing constants, helpers, types, schemas, and shared utilities when
  they define the required behavior.
- When two packages must coordinate on the same lock namespace, mode string,
  status, feature flag, query key, or sentinel value, define one shared
  constant or helper instead of duplicating literals. Drift between duplicated
  coordination values is a correctness bug, not just cleanup.
- Use structured APIs, parsers, typed contracts, or schema-aware helpers for
  JSON, YAML, SQL, URLs, dates, paths, and protocol payloads.
- Before changing a shared, exported, public, or widely referenced symbol,
  inspect definitions, callers, references, and expected types.
- When similar identifiers travel together, make names encode their role and
  destination. For example, distinguish source-stage run IDs from target
  migration run IDs, explicit input counts from selected row counts, and
  attempted counts from committed counts. If swapping two arguments would
  corrupt durable data or operator truth, the names are not clear enough.
- Treat names as part of the contract when they encode a value's role, units,
  source, destination, lifecycle, or domain/storage boundary. When that
  contract changes, rename the semantic carriers in the changed ownership
  slice together: variables, parameters, helpers, SQL CTEs and aliases, source
  definitions that own generated output, fixtures, and docs. Do not leave an
  old-role name such as `target` on a delta merely to minimize the diff. Keep
  intentionally stable public, compatibility, historical, and generated names
  unchanged unless their owning contract also changes.
- In tests, replace an opaque boundary or sentinel literal with an
  intent-bearing local constant when the raw value hides the contract being
  proved. Share the constant only when multiple consumers must coordinate on
  the same value. Do not create constants for ordinary, self-evident fixture
  values.
- Keep state, branching, argument counts, and optionality low. Prefer early
  returns and single-assignment flow when they clarify behavior.
- Prefer one real code path. Add flags, config, caches, fallbacks, or
  compatibility layers only for an existing caller, deployment environment,
  migration path, or documented external API behavior.
- When adding conditional behavior, write the branch matrix before editing and
  cover invalid, disabled, old/new deploy, and failure states. A flag that lacks
  tests, logs, docs, and removal/rollback criteria is unfinished behavior.
- For API, integration, and generated-contract work, update producers,
  consumers, mocks, fixtures, docs, and generated artifacts together. Do not
  repair shape drift in one consumer while leaving the source contract unclear.
- For cache, lock, queue, retry, or idempotency changes, name the source of
  truth and the consistency model before editing. Include stale, duplicate,
  concurrent, timeout, and unknown-outcome states where they are reachable.
- Do not make required values optional. After asserting or narrowing required
  data, trust the invariant.
- Catch errors at boundaries where the code can recover, translate, protect a
  user-facing path, or add useful context. Do not use broad catch blocks as
  ordinary control flow.
- Return explicit values at transaction or callback boundaries. Do not return
  a broad local error variable after every non-nil branch has already returned;
  use the exact terminal value so reviewers can reason about rollback and stale
  error leakage.
- Add comments only for non-obvious constraints, invariants, or workarounds.
- For refactors, preserve external behavior. Add characterization coverage
  first when existing tests are weak and the path is risky.
- Do not add dependencies, generated clients, build steps, env vars, config
  knobs, or abstractions as side effects of a narrow change.
- Do not suppress linters, warnings, type errors, or failing tests with blanket
  disables, broad casts, ignored errors, or downgraded rules.
- If a change begins as bug fixing, reproduce the issue or use the static-defect
  exception from `debugging-and-repro` before editing.
- If a change begins as lint/format cleanup, keep it behavior-preserving. When
  a lint finding requires logic changes, reclassify it as implementation work
  and load the relevant risk lane before editing.

## Generated And Structured Artifacts

- Treat generated files as outputs. Edit the owning source interface, query,
  schema, or config first; run the repo generator; inspect generated diffs.
- For structured data, preserve indentation, ordering, quoting, and minimal
  diff shape. After editing, run a cheap diff check such as `git diff --check`
  and `git diff --numstat -- <files>`.
- If a formatter causes unrelated churn, treat that as an edit bug unless the
  task explicitly required reformatting.

## Architecture Judgment During Code

- Be strict about auth, routing, URL handling, redirects, locale/state
  fallbacks, response-shape assumptions, retry behavior, cache invalidation,
  idempotency, feature flags, and illegal config combinations.
- Validate illegal option combinations in code and cover the rejection path.
- Decide empty-input behavior before side effects. A zero-row import,
  materialization, mirror, or repair mode should either be an explicit no-op
  success or fail fast with an actionable error before creating durable
  evidence, acquiring locks, or mutating state.
- Prefer set-based SQL and bulk operations for imports, migrations,
  validation, and bulk-update paths when they avoid row-by-row work, then prove
  they are bounded at production shape.
- Keep user-facing errors generic and localized. Put technical detail in logs,
  metrics, and tests.
- Verify names, comments, docs, walkthroughs, logs, and CLI/help text describe
  actual runtime behavior.
- For user-facing, API, data, or operator behavior, keep acceptance criteria
  tied to observable value. A green unit test is weak proof if it does not
  exercise the real user, API, data, or operator path.
