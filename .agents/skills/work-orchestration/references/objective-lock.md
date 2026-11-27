<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (high-impact intent approval and parent question ownership) -->

# Objective Lock

```text
Type: decision gate
Use when: work changes authority, fallback/error/availability semantics, runtime
          dependencies, ownership, production defaults, public contracts,
          migration/cutover states, phased transition behavior, or mandatory
          high-impact intent alignment activates
Skip when: the contract is current and unchanged and no high-impact alignment trigger applies
Owns: owner-authorized objective, acceptance, protected invariants, non-goals,
      authority, and versioned material changes
Does not own: solution selection or implementation
Allowed side effects: bounded read-only evidence gathering and owner questions
Inputs: current request, governing artifacts, accountable owner evidence, and known gaps
Exit states: locked, unchanged, pending evidence, pending owner, superseded
Outputs: objective lock ID/version and downstream contract
Re-enter when: an owner-controlled field or its source of authority changes
```

Use this lane when planned work materially selects or changes a product,
runtime, data, API, rollout, or workflow contract and the parent needs one
owner-authorized objective before challenging solutions or starting edits.

The governing questions are:

- **What problem are we trying to solve now?**
- **Does this action directly complete the objective, protect a locked
  invariant, change the contract, or remain unrelated?**

This lane produces one compact, versioned objective contract reused by idea
challenge, critic, authoring, validation, and own-work reviewer handoff. It is
not a repeated questionnaire, a new subagent gate, or permission to ask the user
for facts the repo or environment can prove.

## Ownership Boundary

This lane owns:

- the problem and observable outcome;
- intent owner and authoritative intent source;
- verified facts versus owner decisions;
- acceptance criteria, protected invariants, and non-goals;
- conditional transition and retirement semantics;
- lock status and version;
- relevance classification for proposed actions and findings;
- reopen and non-reopen decisions.

It does not own:

- target, permission, or mixed-phase ambiguity; use `request-intake`;
- whether a proposed solution is worthwhile; use `idea-challenge` after lock;
- implementation-plan readiness; use the pre-code critic when selected;
- code design or edits; use `code-authoring`;
- teammate PR intent reconstruction; use the live PR body and PR workflow;
- reviewer verdicts or review-tool selection.

## Activation

Require an objective lock when work materially selects or changes any of these:

- source authority or data ownership;
- fallback, error, or availability semantics;
- runtime dependencies or synchronization model;
- auth, permission, privacy, or trust ownership;
- migration or cutover states;
- public or cross-service contracts;
- production defaults or rollout behavior;
- durable workflow, reviewer, authoring, or publication defaults;
- durable persistence, retained observability with ongoing operator ownership,
  or lifecycle machinery that activates Production-Ready Scope;
- multi-phase transition behavior whose current action constrains later phases.

Also require one explicit intent-contract approval when `request-intake`
detects a mandatory high-impact alignment trigger: active `complex` or
`long-horizon` complexity, `cross-system` or `production-wide` impact,
`coordinated` or `one-way` reversibility, durable workflow/orchestration/
reviewer/agent/skill/publication default changes, broad deletion or
consolidation with useful colocated content at risk, or multi-owner work.
Apparent clarity and agent confidence do not waive this approval.

Do not activate merely because work is non-trivial or touches one of those
domains without changing its verified contract; sequencing language alone does not activate
objective-lock when the material contract is verified and
unchanged. The explicit high-impact triggers above are the bounded exception;
ordinary localized reversible work remains outside this gate and emits no skip
packet.

Use one of these compact outcomes when a full lock is unnecessary:

- `not required`: tiny mechanical work or a localized fix that preserves a
  verified existing contract;
- `already locked: <lock-id>@v<version>`: execution continues under an unchanged
  approved objective;
- `urgent containment`: record only the immediate objective, stop condition,
  protected invariant, and owner before safe containment; complete a full lock
  before a durable fix.

Do not create a retroactive objective lock for review of a teammate's existing
PR. That review uses the live PR body as stated intent and marks missing intent
`Pending Verification`. Do not ask the user to reconfirm intent already explicit
in a current approved artifact.

## First Response When This Lane Is The First Eligible Gate

When the dispatcher selects this lane as the first eligible gate, the first
response is **lock-only**. Its job is to make the owner's decision boundary
concrete, not to advance a solution.

Emit the schema below. Prose before or after it may only name the
`objective-lock` route, restate which rows are pending, name the blocked later
gates, restate the stop condition, or neutrally enumerate unresolved options
solely to make the owner decision boundary concrete.

That prose must not rank, recommend, pressure-test, or characterize those
options, and must not add implementation implications, evidence claims, or policy
rationale. Do not label an unresolved option safe, safer, safest, fail-safe,
fail-open, or fail-closed, and do not characterize the route itself that way.
Neutral enumeration may expose the decision boundary; it may not select within
it.

Name every unresolved authority participant, disagreement policy, failure
semantic, and availability tradeoff as `pending owner` or `pending evidence`. A
vague role label such as `safety net` is not a resolved participant role.
Serialize it as
`<participant>=<prompt label>; exact role unresolved; <pending owner | pending evidence>`
with no parentheses, examples, alternatives, or inferred roles added.

```text
Objective-lock first response:
- route/mode: objective-lock; <mode>
- source authority: <locked | pending owner | pending evidence>
- retained participant roles: <each participant and status; vague role = exact
  role unresolved; no examples, alternatives, parentheses, or inferred roles>
- disagreement policy: <locked | pending owner | pending evidence>
- failure semantics: <locked | pending owner | pending evidence>
- availability tradeoff: <locked | pending owner | pending evidence>
- blocked until resolved: idea-challenge, critic, authoring
- stop condition: every material pending row resolved by its owner or evidence
```

Do not omit a material row merely because the prompt used vague safety language.
The response ends after the schema or one bounded restatement of its stop
condition. Do not append or prepend a challenge, recommendation, conditional
acceptance, concrete safety characterization, option list, or implementation
guidance anywhere in that response while a material row remains unresolved.

Every material row must be resolved before `idea-challenge` may begin.

## Preservation Authoring While Policy Is Pending

Pending behavioral policy blocks selecting or implementing that policy. A
material `pending owner` or `pending evidence` row blocks idea challenge, critic approval, and authoring until objective-lock resolves it.
It does
not block an owner-requested artifact whose only job is to preserve competing
observations, proposals, assessments, or plans.

Use one compact decision and serialize every row; do not replace the schema with
summary prose:

```text
Preservation authoring decision:
- artifact 1: <content and proposal/observation/assessment status>
- artifact 2: <content and proposal/observation/assessment status>
- exact policy conflict: <behavior one would select versus the other>
- discoverable facts: <verified evidence | Pending Verification + bounded check>
- authority states: artifact fidelity=<status>; packaging=<status>;
  execution authorization=<status>; owner-approved behavioral policy=<status>
- residual owner decision: <only behavioral policy evidence cannot select>
- implementation boundary: preservation allowed; selection and execution blocked
```

Name artifact fidelity, packaging, execution authorization, and owner-approved
behavioral policy separately even when several share the same status. When the
current side-effect boundary forbids fact inspection, record discoverable facts
as `Pending Verification` with the bounded check that later authoring requires.

Do not blend the artifacts or present either as approved. Resolve discoverable
facts through evidence work; ask the owner only for behavioral policy that
evidence cannot select.

## Evidence Before Questions

Before asking the user, inspect facts that are safely discoverable from current
source, config, tests, runtime metadata, logs, database metadata, approved plans,
or existing public artifacts. Use the user for product intent, sequencing,
priorities, tradeoffs, owner decisions, and facts that cannot be independently
verified.

Ask enough material questions to remove ambiguity. Do not ration questions when
an unanswered product decision would change the contract, and do not burden the
user with facts the agent can verify itself.

Only the parent asks the user. A child returns at most three decision-changing
questions with safe defaults. The parent uses a verified native structured-
question capability when available; otherwise it asks one blocking plain-text
question and stops. Missing tool capability never implies approval. Reuse facts
and questions already resolved by intake; do not make mandatory alignment a
duplicate questionnaire.

Useful questions include:

- What problem should this phase solve, and why now?
- What observable behavior proves completion?
- What must change and what must remain unchanged?
- What already-defined phase follows this one?
- Which current behavior does that later phase still consume?
- How long must a transitional mechanism remain?
- What explicit decision or evidence retires it?
- Which failure, fallback, and availability semantics are intended?
- What is outside the current task?

## Decision Provenance And Scope Delta

`scope-change-control` may hand this lane an `objective-changing` delta after a
phase has started. Consume that classification as the reason to create or
reopen the objective version. Do not return the same unchanged delta to
`scope-change-control`; this handoff is one-way unless new evidence creates a
different material delta.

When the task records, packages, approves, or implements behavioral policy,
keep these authority states separate. Include only states that materially apply
to the current task; this is not a mandatory recital:

- **Artifact-fidelity obligation:** the owner asked an artifact to preserve a
  proposal, observation, alternative, or plan accurately. This requires exact
  behavior and decision-status labeling. It does not approve that behavior,
  select its phase, or authorize implementation.
- **Phase and packaging authority:** the owner named the current slice, next
  pull request, or sequencing boundary. It constrains what belongs now. It does
  not approve a new behavioral policy or authorize implementation by itself.
- **Execution authorization:** the owner directed implementation of an
  identified plan under its accepted objective and constraints. It does not
  authorize policy substitution, phase absorption, or changes to accepted
  behavior.
- **Owner-approved behavioral policy or objective:** the owner selected product,
  runtime, data, or operator behavior. It does not grant a separately gated
  publication, remote-write, Production, or destructive side effect.
- **Verified fact:** current source, configuration, runtime, data, or other
  direct evidence. Facts constrain decisions; they do not select policy.
- **Inference, proposal, critic advice, or reviewer advice:** advisory input
  until the proper owner accepts it.
- **Pending Verification:** an unproven material premise. It is never authority.

Do not promote one state into another implicitly. In particular, preserving a
proposal does not approve it for execution, naming the next phase does not
authorize implementation, and finding a dependency does not authorize a new
objective.

When new evidence, a missing dependency, critic advice, reviewer feedback, or
implementation discovery pressures the plan, compare it with the current lock:

- adapt implementation mechanics that preserve the outcome and phase boundary;
- report missing prerequisite plumbing and offer bounded packaging options;
- freeze additions or removals of runtime behavior, accepted requirements, or
  protected invariants for an owner decision;
- do not pull a known next consumer into the current phase without explicit
  phase and packaging authority; and
- do not describe a reduced or reversed plan as equivalent to the current one.

Reopen and version the lock only for a material contract delta under the rules
below. Reuse the unchanged lock for implementation details so provenance does
not become another per-phase ceremony.

## Objective Contract

Use this compact shape. Omit conditional fields that do not apply.

```text
Objective lock:
- lock: <stable-id>@v<positive-integer>
- status: locked | pending owner | pending evidence
- intent owner/source: <user, approved artifact, product contract, or owner>
- approval evidence: <explicit owner acceptance when high-impact alignment activated>
- problem: <one sentence>
- observable outcome: <behavior or operational state>
- verified facts: <current evidence>
- owner decisions: <intent not discoverable from evidence>
- authority ledger: <only applicable artifact, phase, execution, policy, fact, advice, and Pending Verification states>
- acceptance criteria: <observable pass/fail checks>
- protected invariants: <behavior that must survive>
- non-goals: <explicit exclusions>
- transition phases: <current -> transition -> target, only when phased>
- known next consumers: <next two or three phases, only when known/material>
- retirement condition: <only for temporary behavior>
- Pending Verification: <material and non-material unknowns>
- relevance ledger: <item -> direct | protective | contract-changing | unrelated>
- next owner: <idea-challenge | plan-acceptance | owning execution route | request-intake | blocked>
- reopen condition: <material field or evidence change>
```

`pending owner` or `pending evidence` blocks idea challenge, critic approval,
and authoring only when the unresolved item is material to the activated lock.
Record non-material unknowns without turning them into a planning blockade.

For phased work, the transition section must identify current state,
transitional state, target state, protected behavior, next consumer, and exit
condition. Do not require a transition matrix for work without phased behavior,
or a retirement condition when no temporary mechanism exists.

## Production-Ready Mechanism Scope

When Production-Ready Scope activates in an owned planning or authoring flow,
create its subordinate mechanism ledger only after an objective lock exists.
Identify the pair as:

```text
objective_key=<lock-id>@v<objective_version>
mechanism_scope_key=<objective_key>/mechanisms@v<positive-integer>
```

The objective lock remains the sole owner of the problem, observable outcome,
acceptance criteria, protected invariants, authority and failure semantics,
transitions, and non-goals. The mechanism ledger owns only persisted states,
retained signals, thresholds, operator obligations, repair, retention, cleanup,
rollback, and decommission mechanisms plus their `keep`, `defer`, or `remove`
dispositions.

Keep a mechanism only when it directly satisfies an existing acceptance
criterion, is required by a mandatory current contract, or is `protective`:
it maps to a named protected invariant and current evidence proves the change
makes the prevented failure reachable. The ledger cannot create or amend an
objective-owned field. An otherwise unmapped mechanism requires the intent
owner to amend the objective contract before it can be kept.

Idea challenge creates `<objective_key>/mechanisms@v1`, authoring consumes that
pair, and authoring preflight revises the mechanism ledger from the actual diff.
A mechanism-only revision increments the mechanism version under the unchanged
objective. A change to an objective-owned field freezes the mechanism revision
and returns to this lane. After the owner approves a new objective version,
start its mechanism ledger at `v1` and preserve every prior objective/mechanism
pair and its review history append-only.

Do not manufacture an objective or mechanism key for review of a teammate's PR.
That review continues from current live PR intent and task-time necessity
analysis under the existing exemption.

### Mechanism-Scope Decision Record

Mechanism scope uses a two-step fail-closed kernel. First classify relevance as `direct`, `protective`, `contract-changing`, or `unrelated`.
Second, freeze
mechanism revision when a proposal changes an objective-owned field.

For every mechanism-scope decision, state these five fields explicitly:

```text
Mechanism scope decision:
- relevance class: <direct | protective | contract-changing | unrelated>
- disposition: <keep | defer | remove | freeze>
- causal evidence: <for protective, how current evidence makes the named
  protected failure reachable; for direct, the acceptance criterion it satisfies>
- version action: <mechanisms@vN -> vN+1 | no bump | frozen pending owner>
- append-only history: <prior objective/mechanism pairs preserved>
```

For a `protective` mechanism, the causal-evidence field must restate how current
evidence makes the named protected failure reachable. Stating only that the failure is reachable is insufficient.

A `contract-changing` item has disposition `freeze`: do not revise the mechanism
ledger until the intent owner approves a new objective.

Do not promote optional machinery into an objective change merely because it
would add lifecycle, persistence, repair, retention, or cleanup behavior. When no
acceptance criterion, mandatory current contract, or evidence-backed protected
invariant requires it, classify it as speculative or `unrelated` and `defer` or `remove` it with no version bump.

A kept `direct` or `protective` mechanism never edits the current ledger version
in place. Increment the mechanism version under the same unchanged objective, for example `mechanisms@v1` to `mechanisms@v2`, and preserve the earlier version
append-only.

## Relevance Disposition

The parent classifies each plan item, critic recommendation, reviewer finding,
and discovered opportunity:

- `direct`: required by a locked acceptance criterion;
- `protective`: prevents a proven regression or safety violation caused or made
  reachable by this change and maps to a named protected invariant;
- `contract-changing`: related to the objective but changes authority,
  fallback, errors, availability, dependencies, synchronization, auth/data
  ownership, phase sequence, acceptance criteria, invariants, or non-goals;
- `unrelated`: does not complete the objective or protect a locked invariant.

Critics and reviewers provide evidence. They do not authorize a disposition or
contract change. The parent verifies the premise and causal link before acting.

Freeze a `contract-changing` item. Present the original contract, proposed
change, evidence, consequences, and smaller alternatives to the intent owner.
Owner approval must explicitly amend the objective contract and create a new
version before adoption.

An `unrelated` item is deferred or rejected. General owner enthusiasm does not
make it current scope; the owner must explicitly amend the objective contract
if the item should become part of the action.

## Lock Sequence

1. Consume the provisional objective and target from `request-intake` when that
   lane ran.
2. Gather current evidence before asking owner questions.
3. Agree on the problem, outcome, invariants, acceptance criteria, and non-goals.
4. Add transition, future-phase, and retirement fields only when applicable.
5. Classify candidate actions with the four-way disposition.
6. Mark the contract `locked`, `pending owner`, or `pending evidence`.
7. Continue to `idea-challenge` only when no material pending item remains.

Idea challenge tests candidate directions against this contract. It must not
infer, replace, or silently broaden a required lock. A critic tests an approved
direction or implementation plan; it does not become the intent owner.

## Reopen Rules

Reopen and increment the lock version when evidence, implementation discovery,
critic advice, reviewer feedback, or an owner request would change:

- source authority;
- fallback, error, or availability semantics;
- runtime dependencies or synchronization model;
- auth or data ownership;
- phase sequence;
- acceptance criteria;
- protected invariants;
- non-goals.

Preserve the prior version and record why the contract changed. Re-run idea
challenge or critic only when the changed fields materially alter the input to
that gate. Never request another review automatically because the lock version
changed.

Do not reopen for:

- wording or formatting;
- semantically unchanged generated output;
- validation or readback of the existing contract;
- implementation details wholly inside the lock;
- an already-dispositioned unrelated observation;
- execution of an unchanged approved plan;
- a localized fix that restores the verified locked behavior.

## Reusing An Unchanged Lock

Reusing a verified unchanged objective lock suppresses only duplicate
objective-lock discovery and objective-lock-generated ceremony. It never waives an independently triggered critic, reviewer or database-reviewer, validation, or publication gate.

When reporting the next route, name those gate classes explicitly and state that
each still applies when independently triggered. Do not silently preserve only
the nearest validation step:

```text
Reused objective lock transition:
- objective: <stable id verified unchanged>
- suppressed only: duplicate objective-lock discovery and generated ceremony
- next owner: <owning implementation workflow>
- independently triggered gates preserved: critic; reviewer; database reviewer;
  validation; publication
- reopen condition: material authority, fallback, dependency, sequence,
  acceptance, invariant, or non-goal change
```

## Downstream Contract

- `idea-challenge` receives the lock ID/version and challenges only directions
  that preserve it, unless it returns an explicit owner decision.
- code-change intake records `not required`, `already locked`, or the active
  lock and blocks edits on material pending fields.
- pre-code critic receives the exact lock and identifies contract-changing
  advice instead of silently redefining the plan.
- authoring preflight compares the final diff and accepted findings with the
  active lock before reviewer dispatch.
- own-work reviewer handoff includes the lock ID/version, acceptance criteria,
  invariants, and non-goals. Teammate PR review remains exempt.

Existing critic and reviewer selection rules remain authoritative. An unchanged
objective lock prevents objective-lock-generated duplicate ceremony; it does
not suppress an independently required critic, database reviewer, ordinary PR
reviewer, or user-requested review.
