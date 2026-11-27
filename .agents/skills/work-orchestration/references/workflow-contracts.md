<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (autonomy envelope extracted to its own companion) -->

# Workflow Contracts

```text
Type: companion contract
Use when: an owning gate or lane needs a shared phase, result, join, evidence,
          scope-delta, or handoff schema
Skip when: the selected owner needs no shared boundary or transport contract
Owns: reusable orchestration packet shapes and readiness/completion semantics
Does not own: route selection, substantive work, mutation, or final claim
Allowed side effects: none
Inputs: the active owner's material boundary fields and packet consumer
Exit states: contract selected | blocked on a missing material boundary
Outputs: normalized contracts consumed by the active owner
Re-enter when: a material phase field or packet consumer changes
```

This file is a **companion contract**, not an owning lane. Use it to make phase
boundaries, route outputs, and handoffs unambiguous after the dispatcher has
selected an owner.

## Core Terms

Phase, gate, owning lane, companion, owner, material transition, meaningful
action, bootstrap, `Pending Verification`, critical shared target, and fail
closed are defined once in the dispatcher kernel's Vocabulary section. Do not
restate them here.

One term is local to this companion:

- **Join:** the point where delegated or parallel output becomes a dependency of
  the parent’s next action or claim.

## Universal Reference Interface

Every routable reference must use this exact leading block:

```text
Type: decision gate | owning lane | companion contract
Use when: <observable trigger>
Skip when: <observable non-trigger or narrower owner>
Owns: <one decision or bounded action>
Does not own: <adjacent work that must route elsewhere>
Allowed side effects: <read surfaces plus write/execute ceiling>
Inputs: <minimum state required to act>
Exit states: <source-backed terminal states for this reference>
Outputs: <decision, evidence, artifact, or handoff>
Re-enter when: <material transition that invalidates or reactivates the reference>
```

This file is the sole canonical owner of the interface. Keep `Exit states`
separate from `Outputs`: the former defines how the reference terminates, while
the latter defines what it returns. Runtime-specific behavior may diverge in a
reference body, but the leading interface remains portable and structurally
identical; record intentional body divergence in the preservation ledger. If
two references both appear to own the same decision, the dispatcher’s route
map is authoritative until the conflict is resolved.

## Route Node Interface

Every non-fast-exit boundary exposes enough state for the parent, next owner,
and user to follow the work without reconstructing private reasoning:

- node type and activation trigger;
- consumed target, evidence, and prior decision;
- owned decision or bounded side effect;
- result, proof, and blocked or `Pending Verification` exits;
- next owner plus transition or join trigger; and
- parent-owned visibility while specialist packet ownership remains intact.

The parent is the sole user-visible journey narrator. A child or specialist
returns its existing packet; it does not create a competing journey trace. The
parent translates only route, state, proof, and transition, never scratch
analysis or hidden reasoning.

Before the first target-specific action of a non-fast-exit phase, expose the
classification receipt and compact route selected by the dispatcher.
A route label without the receipt's work type, rationale, ownership, target,
side-effect ceiling, risk, and proof is not enough to start work. At a material
transition, state the prior exit evidence and next-owner rationale before the new phase's first action.
For a delegated branch, name the owner and join boundary before
dispatch, then state the join result before any dependent parent action.

Instruction loading is bootstrap rather than target work. Worktree mutation,
target inspection, implementation, validation, review, git and remote actions,
and production operations are meaningful actions. Fast-exit remains classified:
emit its proportional one-line receipt before the one bounded lookup, or in the
final response when no tool is needed. Conditional Work Item Profile activation
does not waive task classification. After a user correction or a material
objective, target, owner, side-effect, or risk change, expose a classification
delta before the next meaningful action.
Do not add route fields to a stricter parser-facing packet; use commentary or
parent-private state when the transport cannot carry a separate update.

## Lane Journey Contract

The visible journey is a linked sequence of route nodes:

```text
<current node> --[exit evidence]--> <next node>
       \--[conditional branch]--> <specialist/child> --[join evidence]--/
```

At entry, state the current node, why it owns the phase, the target and allowed
side effects, the exit proof, and expected next owner. At transition, state the
prior exit evidence and next-node rationale before the next node acts. At
closeout, state terminal proof and exact `Pending Verification`.

This is an observability contract, not a requirement to recite lane files or
predict every future branch. When evidence changes the route, update the next
link instead of defending the old plan.

## Phase Contract

Before substantive work begins, define:

```text
Mode:
Objective:
Target:
Owner:
Side effects: <Reads: ...; Writes/executes: ...>
Risk:
Constraints/budget:
Required inputs:
Success evidence:
Assumptions / Pending Verification:
Stop or re-entry trigger:
Next consumer:
```

### Phase Readiness

A phase is ready when:

- the objective and target are specific enough to act on;
- authorization covers the highest planned side effect;
- state is fresh enough for the action;
- prerequisite gate results are present;
- material deadlines, paid calls, CI runs, polling, and resource ceilings are
  known or have an explicit stop condition;
- the owner has the required capability;
- delegated scope is exclusive and non-overlapping;
- success evidence and stop conditions are testable;
- the next consumer is known when the result feeds another phase.

Do not block on information that cannot change safety, target selection,
acceptance, or proof. Carry it as an assumption or `Pending Verification`.

Check applicability before filling a field. Absent paid calls, deadlines,
external waits, and shared resources require no invented budgets. Known request
constraints remain binding; an actual material activity still needs its ceiling
or stop condition. Reuse established values and gate results while current.
A missing material input blocks its dependent action, not independent work
already authorized within the same task.

## Task Autonomy Envelope

The task autonomy envelope is owned by
[autonomy-envelope](autonomy-envelope.md). It activates only when at least one
planned action targets a critical shared target **and** that action's critical
mutation effect is `direct` or `predictable`.

Most work never activates it. Ordinary commits, pushes and branch updates, PR
creation or metadata, review comments and thread replies, Jira or Confluence
collaboration, reads, waits, polling, and test-only CI actions remain under
their owning phase when their critical mutation effect is `none`. They still
require action-specific authority, an exact target, proportional risk handling,
specialist mechanics, and post-write readback.

Load that companion only when the predicate is satisfied. Its canonical packet,
acceptance card, readiness states, approval latch, axis comparison, and
bounded-recovery rules are not duplicated here.

## Route Ledger

Maintain a route ledger only for multi-phase, delegated, high-risk, interrupted,
or externally mutating work. It is a compact continuity index, not a transcript
or another approval gate.

```text
Route ledger row:
Phase ID:
Objective and target:
Owner:
Allowed boundary / risk:
Status: active | complete | partial | blocked | cancelled | superseded
Evidence or artifact pointer:
Side effects performed:
Next owner / transition trigger:
Reopen condition:
```

Append or update a row only at material transitions. Use the ledger to recover
state, inventory mutations, settle stale/conflicting claims, and prevent an old
approval or proof from leaking into a new target. Do not record secrets, private
payloads, scratch reasoning, or every command.

## Work Item Profile

Use a Work Item Profile only when non-fast-exit work has a real downstream
implementation, validation, review, publication, or initiative-slicing
decision. It is an evidence snapshot, not a second task definition, calendar
estimate, risk authorization, or publication permission.

```text
Work item profile <stable-id>@v<positive-integer>:
Kind: defect | feature | maintenance | investigation | operation
Execution shape: atomic | PR-sized item | initiative container
Complexity: trivial | standard | complex | long-horizon + evidence
Impact scope: contained | component | service | cross-system | production-wide + evidence
Reversibility: easy | coordinated | one-way + evidence
Confidence: HIGH | MEDIUM | LOW + material unknowns
Read surfaces: none | local | remote | production/data-sensitive
Write/execute class: none | workspace | validation | local-git | remote-write |
                     production-write | destructive/history-rewrite
Behavioral surface:
Data/auth/config/API/runtime impact:
PR path: no PR | one PR | stacked PRs | initiative slices | Pending Verification
Review forecast: LITE | STANDARD | FULL | COUNCIL + rationale
Specialist applicability: required | not required with negative trace | Pending Verification
Proof surface:
```

This profile is inferred routing context, not an owner-authorized objective
lock. When `objective-lock` activates, carry its stable ID/version, status,
intent source, acceptance criteria, protected invariants, and non-goals.

```text
Objective-lock status:
- state: not required | already locked | locked | pending owner | pending evidence
- lock: <lock-id>@v<version> | none
- material pending item: <none or exact owner/evidence gap>
```

An `initiative container` cannot route directly to code authoring; send it to
`work-slicing` first. Forecasts are advisory: actual changed surface, risk,
repository policy, and mandatory database/security/infra/release gates override
a friendly profile.

Create the profile once after bounded evidence. Derive `<stable-id>` as a short,
kebab-case slug of the accepted objective, for example `fix-import-dedup`. Once
assigned, it remains constant across versions of that work item and must not be
reused for another objective. If the slug already identifies a different work
item, add one short deterministic target/issue suffix and keep the resolved ID
stable. A materially different objective gets a new ID; do not hide it behind a
version increment.

Increment the version and emit a compact delta only when execution shape,
complexity, impact, reversibility, confidence, PR path, review forecast,
specialist applicability, or proof route materially changes. Cosmetic file-count
movement does not reclassify the work. Keep the profile out of strict
reviewer/database-reviewer parser packets unless the owning workflow explicitly
includes it.

Serialize every field with its label and use the exact canonical enum token;
never compress the axes into an unlabeled positional string. `production-wide`
impact requires at least a `FULL` review forecast. An `initiative container`
routes to `work-slicing`, and each resulting `PR-sized item` receives its own
profile and specialist-applicability decision. Forecasts do not authorize
publication, apply, release, or a mandatory-gate waiver.

When a material axis changes, reevaluate every dependent route and emit only
this version delta. The unchanged-axis row lists names only; it must not repeat
tokens, values, `=`, or old-to-new pairs:

```text
Work item profile <stable-id>@vN+1 delta:
- <changed field>: <old> -> <new>
- evidence: <fact proving the change>
- unchanged axes rechecked, names only and values omitted: <axis name, axis name>
- authoring route change: <scope and consumers>
- validation route change: <proof widened to affected consumers>
- review route change: <forecast and focus>
- database-specialist route change: <required owner or evidenced negative trace>
```

A file or call-site count never raises complexity by itself. `complex` requires
non-local reasoning, concurrency or state-transition hazards, multiple
contracts or owners, or material coordination beyond repetitive edits. A
private test-only refactor with one owner and unchanged runtime behavior remains
`standard` regardless of file count. A substantive `PR-sized item` uses at
least `STANDARD` review. Direct or indirect consequences to a shared database
contract require `cross-system` impact, `FULL` review, database review, and
authoring/validation coverage for every affected consumer.

`Review forecast` is a proposal to the shared
[review control plane](review-control-plane.md), not a reviewer command. The
reviewer accepts it or returns an evidence-backed escalation under that
companion. `COUNCIL` remains the compatible profile token for council topology;
the companion preserves the underlying `LITE`, `STANDARD`, or `FULL` depth and
all mandatory floors without changing strict final packet schemas.

## Gate Result Contract

A decision gate emits exactly one of:

- `PROCEED`: one named next owner and the boundary it may use;
- `ASK`: one batched blocking question, with safe default when available;
- `BLOCKED`: exact missing authority, capability, evidence, or target;
- `STOP`: cancellation, containment, or terminal no-action result;
- `REROUTE`: one named next gate or owner and why the current gate exposed it.

Use this shape:

```text
Gate:
Decision: PROCEED | ASK | BLOCKED | STOP | REROUTE
Governing fact:
Allowed boundary:
Next owner:
Reopen condition:
Pending Verification:
```

A gate must not return several competing next owners. Conditional branches are
allowed only when the condition and eventual join consumer are explicit.

## Result Contract

An owning phase returns:

```text
Status: COMPLETE | PARTIAL | BLOCKED | CANCELLED | SUPERSEDED
Outcome:
Target and final state:
Side effects performed:
Evidence / validation:
Files or resources changed:
Risks and rollback state:
Pending Verification:
Next owner or terminal condition:
```

Use claim-specific language. `changed locally`, `validated`, `committed`,
`pushed`, `published`, `deployed`, and `verified live` are separate outcomes.

### Phase Completion

A phase is complete only when:

- its acceptance condition is met;
- required proof is current for the exact target;
- side effects stayed within the authorized boundary;
- delegated outputs were joined and verified;
- unresolved gaps are named;
- no known mandatory next action remains inside the same phase.

A phase may be `PARTIAL` without being a failure. State what is complete and the
smallest remaining blocker.

## Blocked-State Contract

Use `BLOCKED` only when the current owner cannot safely make progress. Include:

```text
Blocked on:
Why it matters:
Evidence already gathered:
Safe work still possible:
Smallest unblock action:
Unblock owner:
Re-entry condition:
```

Do not use `BLOCKED` for ordinary uncertainty that a bounded read can resolve,
or as a replacement for a targeted question.

## Transition Contract

Re-enter the dispatcher only when a material field changes. At transition:

1. record the prior phase result;
2. refresh changed Classification receipt fields;
3. name the new owner and why the prior evidence activates it;
4. carry forward only relevant assumptions, evidence, and approvals;
5. invalidate stale proof tied to an old target, head SHA, environment, or
   scope.

Do not reload an unchanged gate merely to appear thorough. A gate reopens only
when its stated reopen condition occurs.

## Branch And Join Contract

Before parallel or delegated work starts, define:

```text
Delegation/branch ID:
Branch owner:
Exclusive scope:
Allowed side effects:
Input evidence:
Return contract:
Join consumer:
Join deadline or stop condition:
Parent work while branch runs:
```

Assign the branch ID once at branch creation and reuse it through every update
and the join. A delegated branch uses the exact Delegation ID from its child
contract; do not create a parallel identifier for the same work.

At join, the parent verifies cited evidence, checks target freshness, resolves
conflicts, and records what was accepted or rejected. Child output is evidence,
not automatic truth or authorization.

## Scope Delta Contract

When new information changes the active phase, capture:

```text
New fact or request:
Delta to objective/target/files/consumers/acceptance/side effects:
Classification: in-scope detail | correctness expansion | optional follow-up |
                objective-changing | conflicting
Disposition: absorb | split | defer | re-lock | ask owner | stop
Proof or approval needed:
```

`scope-change-control` owns the disposition. Do not silently absorb optional
work or restart the full workflow for an ordinary corrective detail.

## Assumption Contract

Record an assumption only when it influences target, safety, implementation,
validation, or claim wording:

```text
Assumption:
Basis:
Impact if false:
Verification owner and point:
State: active | verified | invalidated | superseded
```

Invalidate dependent proof when an assumption is disproved.

## Evidence Transport Contract

For evidence crossing owners or phases, preserve:

- source and target identity;
- timestamp or freshness;
- command/query/tool used;
- bounded excerpt, count, hash, URL, or artifact pointer;
- sensitivity and redaction boundary;
- what the evidence proves and does not prove;
- any sampling or access limitation.

Do not paste large logs, full payloads, secrets, private data, or whole files
when a compact summary plus stable artifact pointer is sufficient.

## Handoff Contract

Use this packet when another owner must continue:

```markdown
Status: ACTIONABLE | BLOCKED | COMPLETE
Next owner: <parent | named agent | named specialist>

## Objective
<one observable outcome>

## Scope
- In scope:
- Out of scope:
- Exact target:

## Route And Boundary
- Owning lane/specialist:
- Allowed side effects:
- Risk:
- Required approvals:

## Current State
- Work completed:
- Branch/PR/resource identifiers:
- Files/resources changed:
- Running or external operations:

## Evidence
- Verified facts and artifact pointers:
- Validation and results:
- Assumptions:
- Pending Verification:

## Acceptance And Next Action
- Acceptance criteria:
- Exact next action:
- Stop/re-entry condition:
```

Keep the packet small enough to act on without replaying the whole history.
Strict specialist packet formats override this generic shape.

## Checklist Library

Use these as additions to an owning phase, never as independent routes.

### External Mutation

- Target system, identity, and resource ID verified by read.
- Mutation content prepared by the owning specialist.
- Permission and side-effect class explicit.
- Sensitive evidence redacted.
- Post-write readback defined.
- Rollback/correction path known or `Pending Verification`.

### Review Readiness

- Stable target and changed-file inventory exist.
- Review owner selected by `review-routing`.
- Validation status is factual, not implied.
- Author context is separated from reviewer judgment.
- Database/security/specialist applicability is decided when triggered.
- Material fixes invalidate stale review evidence.

### Publication Readiness

Publication is owned by the publication lane inside `pr-workflow`.
Before reviewer-facing mutation:

- final diff and base/head are current;
- title/body describe intent, contracts, tests, risk, rollout, and rollback;
- file lists and commands match the current target;
- local paths, secrets, stale SHAs, and obsolete CI wording are removed;
- post-write metadata and current-head CI readback are planned.

### Incident Or Production Change

- Environment, service, release, cohort, and timeline are explicit.
- Impact and confidence are separated.
- Containment/rollback precedes speculative mutation when safer.
- Read/write authorization is explicit.
- Evidence is timestamped and secret-safe.
- Monitoring owner and terminal condition are named.

### Migration Or Data Change

- Current/target state, volume, and ownership are mapped.
- Rolling compatibility and lock/load risk are assessed.
- Dry-run, boundedness, backup, reconciliation, and rollback proof are defined.
- Generated artifacts and consumers are included.
- Production-scale gaps remain `Pending Verification`.

### Documentation Or Instruction Change

- Audience and source of truth are named.
- Durable policy is separated from volatile runtime detail.
- Links and referenced paths are verified.
- Examples are conditional, secret-safe, and non-authoritative.
- Mirrored/derived instruction surfaces and evals are updated when required.
