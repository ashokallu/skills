<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-19 (work-item profile reconciliation) -->

# Impact And Source Map

Use this lane just before editing unfamiliar, shared, cross-stack,
issue-derived, or external-fact-dependent code. Its job is to prevent the agent
from changing a plausible-looking local file while missing the real contract,
caller, deployed evidence, or versioned source of truth.

## Mission

Build the smallest useful map that makes the next code edit honest.

Follow this mission sequence:

1. Identify the changed symbol, route, query, workflow, config, data shape,
   generated contract, or external fact that the edit depends on.
2. Confirm the current repo source of truth before using memory, issue text,
   logs, comments, copied prompts, or old artifacts as implementation facts.
3. Map definitions, 3-10 representative usages, upstream inputs, downstream
   consumers, and nearby tests or generated outputs for changed shared code.
4. For current external, framework, SDK, platform, or dependency behavior,
   check repo-pinned versions first, then prefer official docs, release notes,
   or primary sources over search-result summaries.
5. Stop once the map is actionable for the next edit. Do not turn impact
   mapping into an unbounded repository audit.
6. Mark unsearched areas, version gaps, deployed-code drift, or unavailable
   operational evidence as `Pending Verification`.

After orchestration has established the route, target, read-only boundary,
disjoint scopes, and join point, independent definition, caller, test, config,
docs, and validation-source searches may run concurrently. The parent joins
their evidence, selects and reads the active domain lanes, and only then edits.
Do not parallelize dependent discovery, verdicts, or writes.

## Code Impact Search

Start narrow and widen only when risk requires it.

- Use `rg -l` or equivalent search to shortlist files before opening them.
- Prefer exact symbol, route, table, event, feature flag, translation key, env
  var, workflow id, API path, and generated-type searches before broad terms.
- When structural search is available and useful, use it to confirm syntax
  shape after text search finds candidate files. If structural search is not
  available, say so only when it affects confidence.
- Inspect the definition and a representative caller set, not every match in a
  large repo, unless the change is a migration, public contract, generated
  surface, or security/data boundary.
- Check tests, fixtures, mocks, generated outputs, docs, logs, and runbooks
  that already encode expected behavior.
- For bug fixes from Sentry, logs, GCloud, or GitHub context, match the
  reported file, function, route, release, environment, and stack frame against
  the current checkout before assuming local code equals deployed code.
- Do not claim "no impact", "safe to change", or "unused" unless the scoped
  search actually proves that claim. Otherwise name the exact scope searched
  and what remains `Pending Verification`.

## Source Truth For External Facts

When code depends on facts outside the current file, make the source explicit.

- Check lockfiles, package manifests, `go.mod`, generated headers, and local
  config before applying framework or library advice.
- Prefer official docs, release notes, API references, RFCs, source
  repositories, or vendor migration guides for current behavior.
- Capture the version, product area, date or retrieval context, and source used
  when it materially affects the implementation.
- Treat issue descriptions, PR comments, dashboards, stack traces, agent
  summaries, and copied prompts as evidence to verify, not as final truth.
- If an official source conflicts with local code, prioritize the current repo
  contract for this implementation and mark the external mismatch for follow-up.
- If a tool returns empty, partial, stale, or environment-limited data, say what
  it proves and what it does not prove.

## Capability, Configuration, And Observation Gate

Use this gate only when a runtime symptom or missing-behavior claim may lead to
new code. Bound it to affected surfaces; do not turn it into a repository-wide
audit.

Reconcile four layers before declaring behavior absent:

1. **Intended contract:** the owner-approved value or behavior the user,
   operator, or downstream system should observe.
2. **Implemented capability:** the complete caller-to-consumer path for every
   affected surface, including in-place mutations, adapters, transforms,
   fallbacks, and branch order.
3. **Effective configuration:** the environment flags, parameters, lineage,
   deployment state, and prerequisites that activate the capability.
4. **Observed behavior:** bounded current logs, rows, output, and transformation
   lineage, with the claim kept inside that evidence.

Disabled or incompletely configured capability is not missing code. When an
observed difference matches a known transform, overlay, floor, fallback, or
migration artifact, reconcile its activation and lineage before proposing a
comparator, duplicate transform, or repair direction. If a material layer
cannot be established, stop the missing-code diagnosis at `Pending
Verification` and name the smallest evidence that would settle it.

## Task Shape Before Editing

If the requested change is vague, shape it before writing code:

- name the objective in one sentence;
- define in-scope and out-of-scope surfaces;
- identify the measurable success criteria and validation proof;
- classify risk signals: app plus backend, auth, data, generated code, SQL,
  Sanity, workflow, dependency, public API, external integration, feature flag,
  cache/concurrency, job/queue, fallback, accessibility/i18n, observability,
  production scale, instruction-policy drift, or external side effect;
- choose a conservative complexity level when scope is uncertain; and
- escalate to planning or architecture instead of coding through unclear
  boundaries.

## Work Item Profile Reconciliation

When orchestration supplied an active Work Item Profile, compare its current
version with the definition, representative callers and consumers, runtime and
environment reach, source-of-truth boundary, tests, and proof map found here.
Do not reclassify from file count or diff size. A one-line Production default
can remain trivial complexity while becoming production-wide and FULL review;
a broad internal refactor can remain complex while its impact stays contained.

Emit a versioned delta only when evidence changes execution shape, complexity,
impact scope, reversibility, confidence because of a named unknown, PR path,
review forecast, specialist applicability, or the validation/review route. If
the change becomes an initiative container, stop direct authoring and return to
`work-slicing`. If no material field changes, reuse the current version without
reciting it.

## Output

Keep the map short and attach it to the code-change todo:

```text
Impact/source map:
- source truth: <repo file, official source, operational evidence, or Pending Verification>
- impact checked: <definition, representative usages, callers/consumers/tests>
- behavior reconciliation: <not triggered | intended contract, capability, configuration, observation>
- edit boundary: <in scope / out of scope>
- gaps: <none or exact Pending Verification>
- work item profile: <not activated | unchanged stable-id@version | versioned material delta and routing consequence>
```

The map is not a final research packet. It is a just-in-time authoring guard
that keeps the next edit grounded in the real code and current evidence.
