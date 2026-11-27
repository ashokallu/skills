<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-05 (native reviewer control-plane override) -->

# Delegation And Join Control

```text
Type: owning lane
Use when: the dispatcher identifies a real delegation trigger
Skip when: work is indivisible, tightly coupled, faster locally, or lacks a clear join
Owns: whether to delegate, child scope, worker selection criteria, dispatch, supervision
      boundary, and parent join
Does not own: initial route selection, domain implementation, runtime capability truth,
              external mutation authorization, or final claim
Allowed side effects: authorized worker/session dispatch, observation, join,
                      cancellation, and narrowly owned session cleanup; child target
                      mutations require separate authorization and capability
                      verification
Inputs: current phase, candidate unit, target, dependencies, available capabilities,
        side-effect ceiling, return contract, and join consumer
Exit states: parent-owned, delegated, joined, blocked, cancelled
Outputs: one delegation decision and, when used, a child contract plus join result
Re-enter when: child scope, target, capability, boundary, dependency, or result changes
```

Delegation is an optimization or required independence boundary, not a default
ritual. Every child pays bootstrap, duplicated context, supervision, retry,
join, and parent-verification costs.

This lane has no rung of its own in the dispatcher's precedence ladder. It runs as
the Early Delegation Invariant: after the pre-route gates release the work and
**before** the owning execution lane or specialist begins, so work ownership is
settled before parent-heavy discovery. Entering this lane resolves ownership; it
does not imply a spawn.

## Entry Triggers

Use this lane only when at least one is true:

- the user explicitly requests another actor, independent review, parallel
  work, a council, or a named worker;
- a selected workflow mandates an independent specialist/reviewer gate;
- a non-fast-exit inspect, explain, plan, or execution phase has two or more
  possible work units or a parent-owned integration/join that needs an early
  ownership decision;
- two or more ready, independent, non-overlapping work units can make useful
  progress concurrently;
- a bounded external wait can be monitored by another verified worker while the
  parent performs different critical-path work;
- a bounded mechanical scout can save substantial parent context without
  weakening proof.

Do not enter for one indivisible multi-step unit merely because a role/model
exists, slots are available, or the parent wants to conserve tokens. Entry for
possible decomposition requires a dispatch decision, not a spawn; return
`parent-owned` or `sequence` when no ready net-positive child exists.

Do not use this lane for concrete PR CI reproduction or read-only PR comment inspection;
those are owned by the corresponding `pr-workflow` lanes.

## Direct Review Ownership

When the user asks the current agent to review a working directory, local diff,
branch, commit, or named files, the review is parent-owned. The current agent
loads `reviewer`, inspects the stable target, and produces the verdict.

Do not spawn another reviewer, critic, scout, model, or council unless:

- the user explicitly requests an additional/independent review; or
- the selected PR/specialist workflow mandates that independent gate.

When the same request also authorizes fixes, commit, or push, sequence them as
later phases. Re-review the final diff directly before the git write. Plain `review`, `final
review`, `review and commit`, or `review and push` does not
create an extra-review gate. This gate does not reopen delegation for a direct user-assigned local review.

## Delegation Decision

Choose one:

- **parent-owned:** no qualifying trigger or no net benefit;
- **sequence:** a child may help, but dependencies, target stability, overlap,
  or shared artifacts require serial execution;
- **parallelize:** independent ready work has clear net benefit;
- **required gate:** a named workflow requires independent output;
- **blocked:** a mandatory worker/capability is unavailable and no same-boundary
  fallback is valid.

For optional delegation, proceed only when the result can change or accelerate
a downstream decision and expected benefit exceeds:

- child bootstrap and instruction loading;
- duplicated evidence/context;
- supervision and failure recovery;
- integration and freshness checks;
- parent verification.

Do not invent numeric token or time estimates. Use concrete task shape. When
unclear, keep the task parent-owned.

Before any spawn, record:

```text
Delegation ID: <parent-generated stable ID unique within this phase lineage>
Delegation decision: required gate | user-explicit | optional net-positive | parent-owned
Why: <concrete elapsed-time or parent-context benefit>
Why now: <ready, stable, and independent inputs>
Who: <verified runtime/tier and why sufficient, or Pending Verification>
Parent owns: <decomposition, reasoning, safety, acceptance, integration, verification>
Child owns: <one bounded execution scope, stable inputs, output contract>
Expected overhead: <bootstrap/context duplication, supervision, retry/failure, join, verification>
Join consumer: <decision, write, claim, or handoff that will use the result>
```

When the tradeoff is unclear, keep optional work parent-owned. Do not
overcorrect into serial work when a ready bounded unit removes substantial mechanical reading
or owns an independent wait.

## Readiness Before Dispatch

A child task must be ready, not exploratory about its own objective. Establish:

- stable parent route and target;
- allowed side-effect ceiling;
- exact child outcome;
- bounded direct and transitive scope;
- stable input revision/head/as-of marker;
- required instructions and evidence;
- stop condition and return contract;
- join consumer and latest responsible join point;
- capability verified through `runtime-capability-check` when uncertain.

A child cannot authorize broader side effects than the parent already holds.

## Decomposition Rules

Parallelize only when scopes are independent in both direct and transitive
writes. Shared formatters, generators, lockfiles, generated artifacts, schemas,
branch history, PR metadata, environment state, or external resources create
overlap unless explicitly partitioned.

Use `sequence` when:

- one result determines the next task;
- the target must remain stable for review;
- scopes overlap or ownership is unclear;
- the same external resource is involved;
- integration cost approaches doing the work directly.

Keep the parent on one critical-path item. Do not duplicate the child’s assigned
surface while it is active. For a non-review child, the parent may take over
after failure, timeout, staleness, incomplete or uncited output, or an explicit
ownership return. Native ordinary and database reviewers instead use the
review-specific override below; generic takeover language never authorizes
overlapping semantic work.

Reserve capacity for mandatory later gates. Optional scouts must not consume all
available worker slots.

Retain capacity to start the next mandatory gate before launching optional work.

## Worker Selection

Select the weakest sufficient **verified** capability:

- bounded read-only mapping/inventory → scout role or parent;
- browser evidence → UI/browser specialist;
- independent plan challenge → critic;
- final stable-target verdict → reviewer;
- SQL/schema/data semantics → database reviewer;
- auth/secrets/permissions → security reviewer;
- infrastructure/cloud/Terraform → infrastructure specialist;
- implementation → only a verified writer with exact exclusive scope.

Outside the repo-enforced executable routing card below, do not invent or
hardcode model names or CLI versions in durable policy. Resolve available
roles, wrappers, models, quotas, sandbox, network, write support, and async
behavior through `runtime-capability-check` and current repo/runtime
configuration.

Use `luna-scouting` only after this lane selects Luna for a bounded read-only
contract. Use `cross-harness-workflow` for external harnesses or councils.
Use `handoffs` for subagent-to-subagent routing after scoped work finishes.

Independent reviewers, critics, and specialist verdict owners are different
from execution workers. Give them a neutral target and evidence packet, not the
parent's preferred conclusion; the parent still verifies and integrates the
returned verdict.

## Current executable Codex routing

The parent thinks ahead, chooses the approach, defines acceptance, and delegates
bounded execution rather than exporting an unresolved reasoning problem to a
child. This card describes only routes currently enforced by repo files or
wrappers.

**Staleness guard.** This is the one place in this skill that names concrete model
identifiers, and it is a snapshot of repo-enforced configuration rather than
durable policy. Model generations, effort tokens, wrapper flags, and role names
change faster than this file. Before relying on a row:

- confirm the role, model, and effort against current repo configuration or
  wrapper help through `runtime-capability-check`;
- prefer the **work shape** column, which is durable, over the identifier column,
  which is not;
- when a named model or role is absent, select the weakest sufficient verified
  capability for that work shape rather than substituting a similar-sounding
  identifier; and
- when current configuration and this card disagree, current configuration wins.
  Treat the card as stale and report the drift so
  `instruction-maintenance` can correct it.

Never copy an identifier from this card into another lane, a child prompt, or a
durable instruction. Elsewhere in this skill, resolve roles and models at use
time.

| Work shape | Current owner and model | Effort and boundary |
| --- | --- | --- |
| Plan, integrate, decide safety, and accept results | Current interactive parent model | The repo does not pin or inspect the interactive parent. When a repo wrapper explicitly selects `gpt-6.1-sol`, use `high`. |
| Map code, inventory routes, plan tests, or collect bounded UI evidence | Matching native read-only role on `gpt-6-luna` | `high`; follow the selected role's actual contract. Native roles do not gain monitoring or write permission from the model choice. |
| Run a bounded read-only scout or watch through another harness | Headless Luna wrapper on `gpt-6-luna` | `high`; the wrapper contract controls scope, monitoring, and evidence return. |
| Required reviewer, critic, security, infrastructure, or database verdict | Matching native read-only role on `gpt-6.1-sol` | `max`; the role owns an independent verdict, not implementation. |
| Bounded analysis needing residual reasoning but no independent verdict | Experimental `terra_reader` on `gpt-5.6-terra` | `high`; semantic read-only contract in a clean non-root worktree. The Luna scout lane remains the normal scout. |
| Explicit decision-complete mechanical classification, or a named Luna evaluation | Experimental `luna_reader` on `gpt-5.6-luna` | `high`; semantic read-only contract in a clean non-root worktree. The Luna scout lane remains the normal inventory and mapping scout. |
| Bounded implementation under a parent-approved approach | Experimental `terra_writer` on `gpt-5.6-terra` | `high`; exact parent write permission and exclusive direct/transitive manifest required. |
| Exact mechanical transformation with no design choice | Experimental `luna_writer` on `gpt-5.6-luna` | `high`; exact parent write permission and exclusive direct/transitive manifest required. |
| Wrapper-selected Sol `xhigh`, `max`, or `ultra` effort | User-explicit wrapper call only | Requires the wrapper's user-authorization flag. Do not choose these efforts autonomously. |

The Luna scout is the current cheap read-only scout. It is not a substitute for the experimental writer roles for
write execution, and scout availability does not authorize delegation.

### Experimental Terra and Luna roles

All four roles are semantic execution profiles under the authority already
held by the parent. They are not permission boundaries. Use at most one Terra or Luna experimental child
in a phase during the evaluation period.

At the earliest point when child session metadata is observable, and before the
child result becomes a join input, verify the observed role, model, effort, and
declared sandbox against the requested role and this routing card. The declared sandbox
is metadata, not an enforcement claim. Reject the run as Terra/Luna evaluation evidence
when that metadata mismatches.

If the required child metadata remains unavailable before join, fail closed:
reject the run as Terra/Luna evaluation evidence and use the output only as an
untrusted lead requiring parent verification.

Role precedence is fixed:

- The Luna scout lane remains the normal low-cost bounded scout.
- Sol roles retain every required critic, reviewer, security, infrastructure,
  and database verdict.
- Terra and Luna readers never satisfy or replace a required verdict gate.
- Terra and Luna writers are optional executors; the parent owns the approach,
  authorization, acceptance, integration, and verification.

Writers require an exact exclusive write manifest and parent authorization.
Readers refuse writes. Keep behavioral guards, but do not treat probabilistic instruction compliance as access control.

Explicit decision-complete mechanical classification is the Luna-reader trigger.
The Luna scout lane remains the normal inventory and mapping scout for ordinary discovery.

For every attempted experimental Terra or Luna run, record requested and
observed metadata, disposition, retry count, and verification burden. Preserve
mismatched attempts so promotion evidence is not survivorship-biased; absence of retained evidence is not success.
This is optional experiment evidence, not a field required for ordinary delegation.

### Terminology boundary

- `multi_agent` enables the native agent facility; it does not select a model
  or authorize optional fanout.
- `xhigh`, `max`, and `ultra` here are reasoning-effort values, not names for every
  multi-agent run.
- council is cross-harness collaboration through
  `cross-harness-workflow`, not a native subagent mode.

## State-Changing Children

Keep writes parent-owned unless a selected workflow and runtime explicitly
support a writer. Before dispatching a writing child, require:

- user authorization for that exact mutation class;
- verified state-changing child capability;
- isolated worktree or demonstrably exclusive direct/transitive write surface;
- no concurrent writer collision;
- rollback and post-write readback;
- parent review and validation before commit, push, publication, or claim.

Children never independently authorize commit, push, PR mutation, deployment,
production/data operations, destructive cleanup, permission changes, or
history rewrite.

## Mandatory Independent Gates

A mandatory reviewer/critic/specialist gate is not optional delegation. Do not
ask for redundant second spawn permission when the user already authorized the
owning workflow and the gate stays inside its declared cost, privacy, tool, and
side-effect boundary. If invocation would introduce a new paid service,
external disclosure, sensitive-data transport, or mutation boundary, route
that new boundary before dispatch instead of treating “mandatory” as blanket
authorization.

When a required gate cannot start:

1. verify runtime capability and available sanctioned paths;
2. clear only completed/stale worker sessions when the runtime exposes safe
   cleanup;
3. retry once only when the next attempt changes a material variable;
4. use a same-role/same-boundary fallback only when the workflow permits it;
5. otherwise stop before the dependent commit, push, publication, approval, or
   claim and report the exact blocker.

Do not treat a failed spawn as a passed review. Do not create multiple reviewers
to outvote an existing verdict.

### Native reviewer control-plane override

When the delegated child is a native ordinary or database reviewer,
`review-control-plane` is the more specific owner and overrides this lane's
generic parent-critical-path, takeover, join-verification, review-finding, and
closeout language. Successful dispatch makes waiting and review control the
parent's critical-path item. The parent does not start another semantic work
unit merely to stay productive; if no bounded control-plane action is needed,
it waits.

The parent may not use generic spot checks, caller or contract verification,
finding verification, or missing-proof takeover while that reviewer remains
active. It follows the control plane's purpose-and-effect allowlist and terminal
replacement transition. A required ordinary or database reviewer remains
required; parent analysis cannot satisfy or waive the independent gate.

## Child Contract

```text
Delegation ID: <parent-generated stable ID unique within this phase lineage>
Parent phase and critical path:
Worker role and verified capability:
Objective:
Target and freshness:
Scope:
Explicit exclusions:
Allowed side effects:
Dependencies and ready condition:
Route and required instructions:
Stop condition and acceptance:
Join before and consumer:
Return contract:
Pending Verification:
```

The prompt must be self-contained enough to act safely, but should not include
unrelated files, long logs, future-phase instructions, or sibling output. For
read-only work, say `Do not edit files`. For writing work, name exact owned files
or modules and transitive exclusions.

Require evidence anchors such as file:line, command/result, run URL/ID, target
SHA, or bounded artifact pointer. The child must preserve unrelated work and
must not broaden scope.

Generate the Delegation ID once before dispatch. Reuse it in the child prompt,
runtime/session metadata when supported, every lifecycle update, the join, and
the final result. Do not create a second identifier namespace for the same child.

## Dispatch State

When ownership becomes mixed, expose only this compact lifecycle view. The Child
Contract remains the sole owner of why, why now, worker choice, objective,
scope, exclusions, side effects, overhead, acceptance, and join consumer; do
not duplicate those fields here.

```text
Dispatch:
- parent critical path: <the one item the parent is actively doing>
- active delegations:
  - <delegation ID>: owner=<child/worker>;
    state=<launched|running|returned|takeover>
- reserved capacity: <include only when materially held for a mandatory gate>
- join boundary: <first dependent parent decision, write, claim, or handoff that
  cannot start until all listed IDs are joined or otherwise dispositioned>
```

Rules:

- Emit `Dispatch` before the first spawn and update it only on launch, return,
  failure, cancellation request, takeover, reassignment, or join.
- Every active row must map to a prior Child Contract with the same Delegation
  ID. A row without that contract is an unauthorized spawn.
- The join boundary is a hard stop. Do not perform the named dependent action or
  claim until each active ID is consumed and verified, cancelled with terminal
  evidence, or explicitly taken over.
- Remove a row after its result is joined or its terminal disposition is
  recorded. When no rows remain, stop emitting `Dispatch` and return ownership
  to the parent or next named owner.

Urgency may remove optional scouts or parallel polish, but it does not bypass a
mandatory independent gate. Keep critical-path decisions parent-owned and use a
child only when the child is ready, its scope is independent, and its result
still has net benefit.

## Existing Plan Execution

[Approved Plan Execution](approved-plan-execution.md) owns plan admission,
phase sequencing, delta handling, and evidence-backed completion. Return here
only when an admitted phase has a real delegation trigger; this lane continues
to own child decomposition, dispatch, supervision, and join.

## Join Contract

At join, the parent checks:

- delegation ID and worker identity;
- target/head/as-of freshness;
- scope compliance and side effects;
- cited evidence and artifact validity;
- conflicts with parent or other child work;
- acceptance criteria and `Pending Verification`;
- whether downstream proof requires parent reproduction or only spot checks.

For low-risk cited inventories, verify the cited anchors and a small boundary sample rather than
redoing the scout. Verify every contract or caller on which the next edit
relies. Use exhaustive parent proof for completeness, safety, readiness, or
production claims. These generic checks do not apply to active native ordinary
or database reviewers; their parent acceptance is mechanical and governed by
the review-specific override above.

Reject stale, uncited, malformed, out-of-scope, or sensitive-data-leaking output.
Take over only the missing proof when the rest remains valid.

## Review Findings

For native ordinary or database reviewer packets, use `review-control-plane`
instead of the generic semantic verification below. For other delegated review,
critic, specialist, or scout evidence:

- verify each actionable finding against current code/contracts;
- Do not silently discard a material critic, reviewer, or specialist claim;
  accept it, challenge it once through `conflict-resolution`, or preserve the
  standing result and its consequence in the parent synthesis;
- accept, reject with evidence, or route a material dispute through
  `conflict-resolution`;
- distinguish blocking defects from optional hardening;
- after code-changing fixes, rerun affected validation and refresh required
  review for the current target;
- stop after accepted findings are resolved and the required current-target
  gate is satisfied. Do not repeat review cycles for cosmetic wording.

## Parent Closeout

Before the dependent action or final response:

- join every required child;
- inspect child diffs/evidence, except that native reviewer output receives only
  the mechanical integrity checks owned by `review-control-plane`;
- run parent-owned validation needed for the combined work;
- refresh target state;
- keep git, PR, external, production, and destructive mutations with their
  authorized owner;
- close no-longer-needed workers when supported;
- report worker use only when it explains evidence, delay, or residual risk.

## Output

```text
Delegation decision: PARENT-OWNED | SEQUENCE | PARALLELIZE | REQUIRED GATE | BLOCKED
Reason and expected benefit:
Parent critical path:
Child contracts: <none or IDs/scopes>
Dispatch state: <none or active IDs/states/join boundary>
Reserved mandatory capacity:
Join point:
Join result:
Next owner:
Pending Verification:
```
