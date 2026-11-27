<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-18 (objective-conformance intake consumption) -->

# Authoring Core

Use this lane at the beginning of non-trivial code authoring, after
`change-intake` has classified the work and before the first meaningful edit.
It turns final-gate failure patterns into construction-time discipline.

## Mission

Write code like the maintainer who will own the runtime behavior after merge.
Author against shipped behavior, evidence, and ownership boundaries, not against
intent wording, plausible-looking diffs, or green checks that do not prove the
risky path.

Follow this mission sequence:

1. Define the code target: changed surface, intended behavior, non-goals,
   side effects, and proof required for handoff.
2. Inspect context before editing shared behavior: callers, consumers,
   generated surfaces, configs, feature flags, mode semantics, cache/lock
   ownership, nearby tests, docs, and operator entrypoints.
3. Define the next consumer before editing: the command, workflow, runtime,
   reviewer, operator, downstream system, or human decision that will consume
   this change's output. Prove that consumer will accept the produced artifact
   or state under current rules and current data, or mark the acceptance proof
   `Pending Verification`.
4. Load `impact-and-source-map` just before editing when the target is
   unfamiliar, shared, cross-stack, issue-derived, or depends on current
   external/library facts.
5. Identify the central failure that would make the change unsafe even if the
   obvious happy path works. For conditional behavior, build a compact behavior
   matrix before editing: states, prerequisites, branch precedence, side
   effects, errors/fallbacks, observability, docs, and proof for each branch.
6. Pick the smallest implementation that closes that failure without adding
   speculative flexibility.
7. Keep every claim either proved by current evidence or marked
   `Pending Verification` before handoff.

## Objective Conformance Consumption

When `change-intake` recorded an active objective-conformance result, consume
that result before choosing code shape. Implement only mechanisms classified
there as direct or protective, and keep the named locked field and evidence
visible while editing. Do not reinterpret critic or reviewer advice, a prior
incident response, or a familiar safety mechanism as a new requirement.

If source inspection or implementation discovery would change source
authority, fallback/error/availability semantics, runtime dependencies or
latency, synchronization, auth or data ownership, flags, phase sequence,
acceptance criteria, protected invariants, or non-goals, stop the edit and
return to `change-intake` and `objective-lock`. Do not make the implementation
internally coherent around a contract the intent owner has not accepted.

## Authoring Boundaries

This lane owns implementation discipline. It does not own final verdicts,
severity mapping, parser-facing packet shape, GitHub thread handling, or owner
approval decisions.

During authoring:

- design and edit only the current code target;
- preserve unrelated worktree changes;
- verify cheap facts from current repo files instead of relying on memory;
- treat generated output, logs, old comments, bot suggestions, and prior
  summaries as leads until current source confirms them;
- route product, legal, security approval, data-governance, infrastructure, or
  architecture authority to the owner instead of hiding it inside code; and
- avoid broad cleanup, dependency churn, config knobs, or helper extraction
  that is not needed for the requested behavior.

## Production-Ready Scope Lock

When the change adds durable persistence, retained observability with ongoing
operator ownership, or lifecycle machinery, consume the active objective key
and its subordinate `<objective_key>/mechanisms@v<version>` ledger before
editing. The objective lock owns the outcome, acceptance criteria, protected
invariants, semantics, transitions, and non-goals. The mechanism ledger records
only mandatory current contracts, persisted states, retained signals,
thresholds, operator obligations, lifecycle mechanisms, and `keep`, `defer`, or
`remove` dispositions. This pair is the gate; do not require a narrative read
or acknowledgement.

Keep each new persisted state, retained operational signal, threshold,
operator obligation, repair path, retention rule, cleanup path, rollback
coordination, or decommission workflow only when it directly satisfies an
existing acceptance criterion, is required by a mandatory current contract, or
is `protective`: it maps to a named protected invariant and current evidence
proves the change makes the prevented failure reachable. Otherwise defer or
remove it. The ledger cannot create an acceptance criterion or amend an
objective-owned field. Keep one stable action-item identity while the requested
outcome lineage remains the same; neither objective nor mechanism revision
erases earlier review or validation history. Expose the scope decision and
evidence, not background narrative or acknowledgement text.

## Context Discipline

Before editing a shared or risky path, inspect enough current context to avoid
breaking the real contract:

- caller and consumer paths for changed exported symbols, routes, handlers,
  requesters, jobs, CLI commands, workflows, and generated contracts;
- old/new compatibility for persisted data, cache keys, queue/event payloads,
  DTOs, enums, nullable fields, and public API shapes;
- mode, flag, environment, locale, tenant, auth, permission, cache, stale-data,
  concurrency, retry, and old/new deploy combinations that can make one code
  path illegal in another context;
- the next consumer's acceptance gates: exact command, API, job mode, reviewer
  expectation, operator runbook, downstream schema, persisted state, or release
  workflow that must accept the artifact or state produced by this change;
- surrounding tests, fixtures, mocks, generated outputs, docs, logs, and
  runbooks that already define the expected contract; and
- failure, retry, cancellation, timeout, cleanup, rollback, idempotency,
  cache-invalidation, lock/lease, queue ack/nack, and operator-visible state
  for effectful paths.

Do not make required values optional to avoid understanding the invariant.
After a required invariant is proved or narrowed, write code that preserves it.

## Production And Data Posture

Treat production-affecting work as unsafe until bounded by design and proof.
This applies to SQL, migrations, imports, exports, audits, reconciliation,
backfills, bulk writes, caches, schedulers, Cloud Run services or jobs, deploy
workflows, CMS mutations, auth, permissions, learner data, and public APIs.

Before writing or accepting such a path, make these properties explicit:

- worst-case data shape, table size, cardinality, query plan, or bounded
  rehearsal needed to prove scale;
- caps, chunks, timeouts, retries, idempotency, resume behavior, and shutdown
  behavior;
- transaction finalization, rollback, unknown commit outcome, and durable
  operator-visible run state;
- environment parity across local, CI, staging, production, primary, replica,
  service, and job execution;
- dry-run or sampled path equivalence to the apply/write path it authorizes;
  and
- rollback, recovery, or fail-closed behavior when central proof is missing.

If central safety proof is unavailable, revise the implementation plan before
coding further or mark the exact missing artifact `Pending Verification`.

## Next Consumer Proof

A change is not ready merely because it compiles, tests pass, or the local
implementation matches intent. It is ready only when the next consumer can use
the produced output.

Before implementing or handing off non-trivial work, answer these questions
with current evidence:

- What artifact, state, flag, schema, command behavior, document, or public
  claim does this work produce?
- Who or what consumes that output next?
- What exact acceptance rules does that consumer enforce?
- Does current repo, runtime, data, PR, CI, release, or operator state satisfy
  those rules?
- What is the next likely blocker after that consumer runs?
- Can that blocker be checked cheaply now, and would failing to check it cause
  another PR, release, full run, review cycle, or user escalation?

If the next consumer would reject the output, fix the plan before coding. If
the consumer acceptance cannot be checked, keep the claim narrow and mark the
missing proof `Pending Verification`.

## Validation Truth

Validation must be able to fail for the real defect or unsafe behavior.

- Add or run focused checks at the seam that owns the changed behavior: API
  contract, permission boundary, data query, flag branch, cache invalidation,
  job retry/resume, UI state, or operator run state.
- Cover rejection paths for illegal flag, mode, environment, permission, input,
  or state combinations.
- Prefer characterization coverage before risky behavior-preserving refactors.
- Treat tests that only exercise nearby code, mocks that hide the real
  boundary, or snapshots that do not assert behavior as weak proof.
- Do not claim codegen, migrations, browser flows, builds, or CI passed unless
  the command or artifact was actually checked at the current target.
- When a useful proof cannot be run, name the exact command, working directory,
  artifact, expected evidence, and safety boundary under `Pending Verification`.

## Runtime Truth

Names, comments, docs, examples, logs, CLI help, PR text, and runbooks are part
of the implementation contract when they steer future coding, validation,
rollout, operations, or incident response.

While editing:

- update or delete stale prose that no longer matches runtime behavior;
- check documented commands and flags against the code that enforces them;
- keep user-facing errors generic and localized;
- put technical failure detail in logs, metrics, tests, and operator evidence;
- avoid comments that restate obvious code; and
- preserve comments only when they explain non-obvious invariants,
  constraints, generated ownership, rollout gates, or workarounds.

## Output

For non-trivial work, keep this discipline visible in the code-change todo:

```text
Authoring core:
- target: <changed surface and runtime contract>
- objective key: <lock-id>@v<objective-version>
- objective conformance intake: <applicable fields and retained direct/protective mechanisms>
- mechanism scope: <objective-key>/mechanisms@v<mechanism-version>
- mandatory current contracts: <contracts>
- deferred lifecycle mechanisms: <mechanisms>
- next consumer: <who/what consumes the output and acceptance proof>
- central failure to prevent: <failure mode>
- context checked before edit: <callers, consumers, generated/docs/tests>
- proof needed: <validation or Pending Verification>
```

Keep it short. The purpose is to keep the implementation honest while the agent
is still close to the code, not to create a second plan document.
