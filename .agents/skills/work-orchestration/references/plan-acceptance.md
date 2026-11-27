<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-12 (critic convergence before exact plan acceptance) -->

# Plan Acceptance

```text
Type: decision gate
Use when: high-impact or otherwise critic-bound work has an exact implementation plan
          whose semantics must remain stable through authoring and review
Skip when: work is localized and reversible, no accepted multi-step plan is needed, or
           one specialist owns the complete workflow under an unchanged contract
Owns: exact plan identity, user acceptance, version lifecycle, and implementation admission
Does not own: intent, rationale, critic merits, execution, deviation disposition, or review
Allowed side effects: parent-owned user questions and bounded read-only plan assembly
Inputs: locked objective, accepted direction, forward-analysis result when triggered,
        exact plan body, target, authority, risk, and proof obligations
Exit states: ACCEPTED | PENDING OWNER | INVALIDATED | SUPERSEDED
Outputs: one content-bound accepted-plan record and next owner
Re-enter when: any decision-bearing plan field or critic-required revision changes
```

This gate turns an implementation plan into an exact owner-accepted contract.
It is not a rationale lane, planning style, execution owner, or permission to
perform later side effects.

## Activation

Activate after required critic convergence and before implementation when any
of these is true:

- an active Work Item Profile is `complex` or `long-horizon`, has
  `cross-system` or `production-wide` impact, or is `coordinated` or `one-way`;
- the plan changes workflow, orchestration, reviewer, agent, skill, publication,
  or other durable defaults;
- broad deletion or consolidation could remove useful colocated content; or
- multiple owners must implement or accept the result.

Apparent clarity and agent confidence do not waive activation. Consume an
already-active Work Item Profile when its axes provide the evidence; do not
create an otherwise-unused profile merely to emit this gate.

Do not activate for ordinary localized reversible work. An inactive gate emits
no skip packet and requires no file load.

## Route And Ownership

Use this order:

1. `request-intake` detects ambiguity or mandatory alignment and routes.
2. `objective-lock` alone obtains approval of the intent contract.
3. `idea-challenge` and `forward-analysis` settle direction and rationale when
   triggered.
4. A required critic evaluates the decision-ready candidate under the bounded
   consultation contract. The candidate is not yet an accepted plan.
5. The parent disposes every material critic finding and reaches a terminal
   critic verdict for the exact candidate revision.
6. This gate presents that critic-informed implementation plan and obtains any
   independently required owner approval.
7. `approved-plan-execution` admits the critic-approved, owner-accepted version.

A critic-required material revision updates the candidate revision before plan
acceptance. Do not ask the owner to approve a design the critic is expected to
change. A material change after plan acceptance creates a new plan version; it
reopens critic only when it changes the objective, core decision, or risk
boundary. Do not repeat intake or objective lock unless an objective-owned
field changed.

Only the parent interacts with the user. A child returns at most three
decision-changing questions and safe defaults. The parent uses a verified
native structured-question capability when available; otherwise it asks one
blocking plain-text question and stops. Missing tool capability never implies
approval.

## Accepted-Plan Record

Use one stable plan ID and positive version. The identity covers the exact body
from `Plan` through `Invalidation conditions`; changing that body without a
version increment is an identity mismatch.

```text
Accepted plan:
- Plan: <stable-id>@v<positive-integer>
- Status: ACCEPTED | PENDING OWNER | INVALIDATED | SUPERSEDED
- Content identity: <exact body transported inline | real immutable digest>
- Objective lock: <lock-id>@v<version>
- Approval evidence: <explicit user decision bound to this version>
- Ordered steps: <stable step ID -> outcome, owner, target, mechanism, boundary>
- Discovery boundary: <allowed reads and target expansion rules>
- Acceptance and proof: <step ID -> observable evidence>
- Preservation obligations: <semantic content or behavior that must remain>
- Deletion obligations: <content, behavior, files, or mechanisms that must disappear>
- Non-goals and forbidden changes: <explicit exclusions>
- Side-effect ceiling: <allowed action classes; later authority still required>
- Risk and review obligations: <critic/specialist/reviewer requirements>
- Critic disposition: <pending | approved exact version | revision required>
- Invalidation conditions: <decision-bearing changes requiring a new version>
```

Plan approval never grants commit, push, publication, deployment, destructive,
Production, database, or other shared-state authority. Those remain separate
action classes under their owning workflows. This restriction concerns
authority derived solely from approving a plan. Preserve any explicit
action-specific authorization already supplied in the same request or current
conversation; do not ask for it again merely because the phase changed.
Critical mutations still require their exact confirmed envelope or verified
standing authority. Approval of an objective is not approval of an unseen plan
version, and implementation discretion is not evidence of version acceptance.

## Version Lifecycle

Create a new version for any addition, removal, or reordering of a step, or any
material change to:

- target or discovery boundary;
- implementation mechanism or owner;
- acceptance or proof obligation;
- risk, side-effect ceiling, or review requirement;
- preservation or deletion obligation; or
- non-goal or forbidden change.

Preserve prior versions and their approval or critic history append-only. A
wording-only correction may retain the version only when the exact meaning,
target, mechanism, authority, proof, and ordering remain unchanged.

## Admission And Failure

`ACCEPTED` requires an exact body, a terminal critic disposition when critic was
required, explicit approval of that version, no material pending field, and the
next owner named. `PENDING OWNER` blocks implementation. `INVALIDATED` blocks
execution until a new accepted version exists. `SUPERSEDED` ends the old plan
without rewriting its history.

The next owner is the narrow execution owner. Neither a critic nor an
implementer may repair a missing acceptance record, infer approval from
silence, or absorb a post-acceptance revision into the old version.
