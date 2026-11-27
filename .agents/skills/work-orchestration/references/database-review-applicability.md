<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (mandatory PR decision-point disposition) -->

# Database Review Applicability

```text
Type: decision gate
Use when: authored PR-bound work or ordinary PR review has a stable target, base,
          and changed-file inventory and needs a database applicability disposition
Skip when: no authored PR-bound or ordinary PR-review decision point exists
Owns: whether a stable review target requires an independent database reviewer and
      whether current environment proof is material to a claim
Does not own: the ordinary review verdict or database verdict
Allowed side effects: classification only; the owning phase sets any evidence-read authority
Inputs: stable target, changed-file/contract inventory, data flow, and environment gaps
Exit states: required, not required, pending evidence, blocked
Outputs: immutable applicability packet for reviewer routing
Re-enter when: target or database/data-access surface changes
```

Use this parent-owned support lane after the exact target, base, and changed-file
inventory exist and before a workflow may dispatch `database-reviewer`, push an
authored branch for the first time, create a PR, or emit a PR review handoff.
The owning review workflow may start the ordinary reviewer as soon as its
independent dispatch inventory is ready; this classification must not delay or shape that verdict.
This lane decides whether the independent `database-reviewer` sibling is
required. It does not perform the database review, collect live environment
evidence, or make either reviewer depend on the other.

## Applicability State

Bind one disposition to the immutable target and decision point:

- `required`: current evidence proves a direct database surface or an indirect
  database consequence.
- `not required`: current evidence proves the target leaves database semantics,
  execution, load, recovery, configuration, and concrete operator decisions
  unchanged.
- `Pending Verification`: the parent cannot yet prove either state. This fails
  closed for first push, PR creation, approval or merge-ready language, and
  overall PR review handoff.

A branch name, backend path, file extension, or absence of a migration is not a
disposition. Recompute the packet when the target, base, inventory, review
decision, or a material environment dependency changes.

## Consequence Classifier

Classify `required` when the target changes any of these surfaces:

- migrations, schema, SQL or generated queries, indexes, constraints,
  backfills, imports, cutovers, reconciliation, database configuration, or
  database operations;
- data-access behavior that changes predicates, joins, cardinality, ordering,
  pagination, query count or frequency, batching, write volume, access paths,
  transaction boundaries, isolation, locking, retries, idempotency, consistency,
  replicas, connection pools, timeouts, or failure recovery;
- runtime, job, cache, API, or feature behavior that can materially change
  database load, capacity, correctness, availability, or retained data; or
- a stable plan, runbook, readiness artifact, or operator decision that directs,
  approves, sequences, or claims readiness for concrete database work.

Do not require the sibling merely because a backend file calls an unchanged
data-access path. `not required` needs an evidenced negative trace: name the
changed surfaces, inspect the nearest persistence callers or consumers when a
database consequence is plausible, and state why query execution, transaction
behavior, load, recovery, configuration, and operator decisions remain
unchanged. UI-only, wording-only, test-only, or semantically unchanged generated
edits may qualify only when that trace proves no database consequence.

## Environment Context Is A Separate Decision

Reviewer applicability and environment-evidence applicability are independent.
A source-only SQL or transaction change still requires `database-reviewer` when
environment scope is `neither`.

After applicability becomes `required`, classify environment scope as Staging,
Production, both, or neither. Context is material for live or nonempty-relation
DDL and claims about scale, latency, locks, rewrites, selectivity, capacity,
topology, effective configuration, replicas, recovery, or Production readiness.
This classification identifies proof needs; it does not authorize live access.

For ordinary PR review, the owning phase is static. Do not collect or refresh
environment evidence. Use checked-in artifacts only within their declared
provenance and observation boundary, record stale or missing current proof as
claim-specific `Pending Verification`, and dispatch `database-reviewer` without
waiting for a live preflight. The gap may block an exact production-readiness
claim, but it does not become a defect and does not waive or delay either
reviewer.

Live collection through `readonly-data-access` is available only after a
separately user-requested validation or production-readiness phase performs a
fresh classification. Authority from ordinary review never carries into that
phase.

## Non-Waivable Parent Gate

When applicability is `required`, reviewer unavailability, runtime limits,
parent confidence, token savings, ordinary-reviewer completion, or an ad-hoc
request to skip the gate do not waive repository policy. Only an authorized
change to the governing workflow/policy can remove the requirement. Classify a
failed dispatch through `execution-recovery-and-tool-failures`; retry once only
when capability, input, target, or another material variable has changed. If
the independent database verdict still cannot return, record the exact
blocker as `Pending Verification` and keep these parent-owned outcomes blocked:

- first push or force-push of an authored PR-bound branch;
- PR creation;
- approval, merge-ready, review-complete, or safe-to-merge language; and
- overall PR review synthesis or handoff.

The ordinary reviewer remains autonomous and may finish its own verdict without
waiting for or consuming the database verdict. Only the parent combines the
independent results, preserves disagreements, and applies the stricter outcome.

## Required Packet

```text
Database review applicability:
- exact target and base: <immutable revisions or Pending Verification>
- decision point: <first push | PR creation | PR review handoff | approval/merge readiness | targeted re-review>
- disposition: <required | not required | Pending Verification>
- direct triggers: <changed surfaces and evidence, or none>
- indirect consequence trace: <caller/consumer path and changed database effect, or evidenced unchanged path>
- evidenced exclusions: <why plausible triggers do not change database consequences>
- environment scope: <Staging | Production | both | neither> + rationale
- environment materiality: <material | not material | Pending Verification>
- evidence state: <checked-in artifact | exact central evidence gap | not material | Pending Verification>
- reviewer state: <not required | pending dispatch | running | returned verdict | blocked>
- phase gate: <allowed | blocked> + exact reason
- next owner: <ordinary review join | database reviewer | separately authorized evidence phase | blocked handoff>
- reopen condition: <target/evidence/capability change that can alter disposition>
```

Every consumer carries this packet instead of reconstructing a shorter trigger
list. `not required` is valid only with the negative trace. `Pending
Verification` and `required` without a returned verdict keep the named phase
blocked.

For target changes after an initial database verdict, retain the existing
proportional re-review contract: `database-reviewer` owns classification as
validation/readback, one-boundary targeted follow-up, or justified broad
follow-up, and environment preflight repeats only when dependent evidence is
expired or invalidated in a separately authorized phase. Ordinary PR review
preserves the resulting evidence gap without a live refresh.
