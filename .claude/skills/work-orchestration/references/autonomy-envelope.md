<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-27 (visible critical-mutation readiness evidence) -->

# Task Autonomy Envelope

```text
Type: companion contract
Use when: at least one planned action targets a critical shared target with a direct or
          predictable mutation effect, or is high/critical-risk, irreversible-destructive,
          and lacks verified bounded restoration
Skip when: no planned action satisfies either activation branch; ordinary commits,
           pushes, PR/issue/document collaboration, reads, waits, and test-only CI remain
           outside when critical effect is `none` and the irreversible branch is false
Owns: the qualifying-mutation ceiling, its packet fields, version lifecycle,
      readiness states, approval latch, and bounded-recovery rules
Does not own: route selection, action-specific authorization, mutation mechanics,
              monitoring execution, or the final claim
Allowed side effects: none by itself; the owning phase supplies every authorized action
Inputs: planned action set, target/effect/risk/destructiveness classification, authority
        evidence, capability rows, rollback/restoration and monitoring facts
Exit states: PRELIMINARY | APPROVAL REQUIRED | READY FOR AUTOPILOT |
             READY WITH CHECKPOINTS | BLOCKED
Outputs: one versioned envelope, its acceptance card, and the permitted action ceiling
Re-enter when: any authority-bearing field, ceiling, named set, or readiness input changes
```

This companion is the sole canonical owner of the task autonomy envelope. The
dispatcher kernel retains a minimal fail-closed fallback for when this file
cannot load; that fallback never replaces the contract below.

The envelope answers one question: **what is the maximum qualifying mutation
this task may perform, and has that ceiling been approved?** It never answers
whether the current action is authorized. That remains with the owning phase and
`risk-and-side-effects`.

## Activation Predicate

The parent dispatcher owns one task-level autonomy envelope only when at least
one planned action satisfies this action-local predicate:

```text
acceptance packet required =
  (critical shared target
   AND critical mutation effect in {direct, predictable})
  OR
  (risk class in {high, critical}
   AND destructiveness = irreversible-destructive
   AND bounded restoration state != verified)
```

`Activation` has deterministic precedence. Use `critical-shared-mutation`
whenever the first branch is true, including when both branches are true. Use
`irreversible-nonrestorable` only when the second branch is true and the first
branch is false.

A **critical shared target** is shared managed infrastructure, Staging or
Production runtime or persisted data, shared database state, deployed
artifacts or traffic, shared config or flags, secrets or IAM, queues, jobs, or
an equivalent service/data/security control plane. An isolated local
development process, local or emulated service, local database, repository,
Git remote, code-review/issue/document system, and ordinary test-only CI
surface are not critical shared targets by themselves.

A **direct** effect means the action itself creates, updates, deletes, executes,
or controls critical shared state. A **predictable** effect means the action's
normal successful workflow causes that mutation even when the immediate
surface is Git, CI, or another control plane. `none` means neither occurs.
Critical effect wins over a routine-looking label: a push or workflow dispatch
whose normal success deploys, migrates, changes traffic, or runs a shared-state
job satisfies the predicate.

Derive **bounded restoration state** from the existing destructiveness,
rollback, readiness, and no-rollback evidence; it is not a new packet field or
competing recovery class:

- `verified` means a current, target-specific restore is executable within the
  already-authorized principal, tools, time, and scope bounds;
- `unknown` activates the envelope but remains `PRELIMINARY` while an authorized
  read-only preflight can resolve it, otherwise `BLOCKED`; confirmation cannot
  approve unknown restoration away; and
- `verified absent` may reach `APPROVAL REQUIRED` only with
  `approved-no-rollback` plus explicit irretrievable-state and compensation
  limits in `No-rollback terms`.

Irreversible destruction of unique user-owned state is at least high risk.
Disposable agent-created artifacts remain outside the irreversible branch only
when their complete reconstruction is deterministic and currently verified;
mere regeneration hope, a generic backup claim, or an untested command is not
verified bounded restoration.

## Packet Scope Within A Mixed Task

Classify each action independently. Explicit unattended/autopilot wording,
external or data-sensitive reads, polling, waiting, supervision needs,
ordinary reversible local work, and unrelated collaboration in the same task do not
activate an envelope. Ordinary commits, pushes and branch updates, PR creation
or metadata, review comments and thread replies, Jira or Confluence
collaboration, and test-only CI actions remain under their owning phase when
their critical mutation effect is `none`. They still require action-specific
authority, an exact target, proportional risk handling, specialist mechanics,
and post-write readback.

When a task contains qualifying and non-qualifying actions, the envelope
contains only the complete qualifying action set and its load-bearing
preflights, rollback/abort, readback, monitoring, and terminal-delivery
actions. Co-occurrence never packet-gates unrelated actions. A later new
qualifying action creates a new version before that action; it does not
retroactively change completed non-qualifying work.

## Ceiling Versus Authority

The envelope is a ceiling, never action authority. Every action must be inside
both the action-specific authority of its owning phase and the active envelope:

```text
permitted action = phase authorization intersect active autonomy envelope
```

Generic assignment, `autonomous`, or `go full autopilot` language does not
authorize Production or destructive work. Exact current wording that names a
qualifying mutation establishes the requested objective, but
authorizes only the enumerated read-only readiness preflights. Execution
authority begins only after the complete unchanged envelope version is
represented by a lossless acceptance card and confirmed, or verified standing
authority applies. Neither path bypasses the risk, external-boundary,
specialist/runbook, capability, prerequisite, abort, rollback, monitoring, or
proof gates.

## Approval Budget

The interactive approval budget is one hold for each stable qualifying
mutation-envelope version. Another hold is justified only by a new
version after a material authority delta, denial followed by reconsideration,
or ambiguity in an authoritative binding field. Routine remote collaboration
must never create an envelope merely to consume this approval budget.

## Work Item Profile Interaction

When a Work Item Profile is active, show its complexity, impact scope,
reversibility, confidence, and review forecast beside the first envelope
version. Those fields are the task estimate and blast-radius label; do not
invent a second estimation scale inside the envelope. Refresh the profile and
envelope together when a material discovery changes that estimate.

## Canonical Packet

Use this canonical packet:

```text
Autonomy envelope <stable-id>@v<positive-integer>:
Activation: critical-shared-mutation | irreversible-nonrestorable
State: PRELIMINARY | READY FOR AUTOPILOT | READY WITH CHECKPOINTS |
       APPROVAL REQUIRED | BLOCKED
Risk: <low | medium | high | critical>
Blast radius: <descriptive affected users/data/services/stakeholders and hard scope ceilings>
Work item profile: <stable ID/version, or not activated>
Environment ceiling: <local | remote-non-production | staging | production>
Principal/identity set: <none or exact allowed principals>
Resource set: <exact repositories, services, branches, databases, tables, or IDs>
Read-sensitivity ceiling: <public | internal | sensitive | secret-auth>
Write/execute ceiling: <none | workspace | validation | local-git |
                       remote-write | production-write |
                       destructive-history-rewrite>
Cost/resource ceiling: <none | bounded | unbounded>
Cost/resource limits: <comma-separated name=non-negative-integer limits, or none>
Destructiveness ceiling: <reversible | coordinated | irreversible-destructive>
Rollback boundary: <local-revert | external-coordinated | approved-no-rollback>
Monitoring dependency: <synchronous | bounded-polling | autonomous-wake-resume>
Monitoring capability: <supported | unsupported | unknown>
Phase-authorized actions: <exact action classes already authorized>
Predeclared bounded recovery: <none or exact authorized recovery action classes>
Preliminary preflights: <exact already-authorized read-only checks, or none>
Planned action graph: <stable action-id:preflight|mutation|rollback-abort|
                      readback|monitoring|terminal-delivery rows>
Capability/action evidence map: <one current evidence row per planned action ID>
Shared-environment effect: <none | direct | predictable>
Shared-mutation latch: <readiness-building | awaiting-confirmation | confirmed |
                       standing-authority>
Confirmation binding: <none | envelope ID/version + environment + principal set
                      + resource set + action classes + ceilings + recovery
                      permission + evidence source/time>
Standing-authority proof: <none | current authority artifact + owner + scope +
                          applicability window/condition>
Prerequisites and gates: <met items and unresolved items>
Unresolved readiness: <none or exact blocker IDs>
Checkpoints: <named stop-before-action boundaries, or none>
Abort/stop conditions:
Success proof and terminal observation:
Expansion handling: <stopped-and-regated, only for an upward delta>
No-rollback terms: <none | owner-approved; irretrievable=<exact state>;
                   compensation=<exact limits>>
```

Both `irretrievable` and `compensation` values must be explicit and non-empty.

## Lossless Acceptance Card

For a qualifying mutation, present this lossless projection at the
approval hold:

```text
Autonomy acceptance card <stable-id>@v<positive-integer>:
Justification and safer alternative: <accepted-plan/forward-analysis projection>
Risk and blast radius: <exact Risk and Blast radius projection>
Credible failures and harm signals: <risk-gate projection>
Target/environment:
Principal set:
Exact resource set:
Exact action classes:
Ceilings: <sensitivity; write/execute; cost; destructiveness; monitoring>
Readiness/access evidence: <exact preflights, action-evidence rows, monitoring, and prerequisites projection>
Unresolved readiness: <exact Unresolved readiness projection>
Rollback, abort, and readback:
Irretrievable state and compensation limits: <none or exact no-rollback projection>
Predeclared bounded recovery: <none or exact authorized recovery action classes>
Reapproval triggers:
Terminal proof:
```

The card is a projection of existing owners, not a second contract.
Justification and safer alternatives come from the accepted plan or forward
analysis; risk, blast radius, credible failures, and harm signals come from
`risk-and-side-effects`; readiness comes from capability, prerequisite,
monitoring, and unresolved-readiness fields; recovery comes from
destructiveness, rollback, bounded recovery, compensation/no-rollback, abort,
and readback; approval binds the exact envelope version and authority-bearing
fields. The card must include every risk and blast-radius fact, principal,
target/resource, action class, ceiling, readiness/access row, unresolved
readiness item, rollback/readback obligation, and recovery permission that
execution may use. Any omission invalidates confirmation. If exact enumeration
cannot fit or cannot remain readable without summarizing or hiding an
authority- or readiness-bearing value, display the complete canonical envelope
instead.

Use a native structured question or approval surface only when its current
runtime contract explicitly permits permission binding and preserves the exact
envelope ID/version and immutable fields. Tool availability alone is not that
capability.

When the current root task's live tool inventory exposes the first-party
`request_user_decision` capability, its `approval` mode is the recognized
structured route:

1. Materialize the complete canonical envelope as the artifact, compute its
   full lowercase SHA-256, keep its bytes unchanged through the hold, and
   render the complete lossless card or envelope and its machine metadata inline
   with Markdown before the tool call.
2. Set `decision_id` to the stable envelope ID, `version` to its exact `vN`,
   `artifact_digest` to that SHA-256, `prompt` to a short, friendly question
   about the exact immediately preceding inline artifact, and `options` to an
   empty list. Keep the decision ID, version, digest, and other binding metadata
   out of the question. Never copy the full unformatted artifact into the
   structured component.
3. Require one returned binding that matches the mode, decision ID, version,
   artifact digest and request. Treat only `status=approved` with the exact
   bound answer as confirmation. `declined` moves the version to `BLOCKED`.
   `status=feedback` is non-authorizing steering from a separate free-text
   dialog: continue within current authority, revise the artifact as needed,
   and create a fresh version before requesting any later approval.
4. Preserve the returned profile/install, host, thread, turn and call binding
   as approval evidence. Never accept model-supplied identity or reuse another
   transport's resolution.

If this exact capability is positively absent before request creation, display
the same card and stop for one unambiguous plain-text confirmation of the exact
version. Once a structured request exists, cancellation, ambiguity, identity
drift, persistence/transport failure, or missing/mismatched output remains
blocked or uncertain. Never open a fallback channel after presentation and
never infer approval from silence, timeout, window close, MCP elicitation,
ordinary `request_user_input`, or dynamic-tool output.

The fixed `Give feedback` choice never grants authority, even when its second
dialog contains the literal text `Approve`, an offered option, or other
approval-like wording. Feedback is excluded from trusted Guardian approval
evidence and must replay with its typed feedback disposition.

## Authoritative Enumeration And Presentation Errata

The exact enumerated resource and action sets are authoritative. Derived counts,
labels, and prose summaries are presentation only. Correcting a derived value
is a same-version erratum only when the authoritative enumeration remains
unchanged and unambiguous. If the enumeration changes or the prior display
could reasonably bind a different set, clear confirmation and create a new
version.

## Preliminary State

`PRELIMINARY` is a lifecycle state, not a readiness result. It permits only the
enumerated, already-authorized preflights. Those preflights may resolve
prerequisite, capability-map, monitoring-capability, and checkpoint evidence
inside the same unchanged ceiling version.

## Planned Action Graph And Capability Map

Build the planned action graph before readiness. Give every load-bearing
preflight, mutation, rollback/abort, readback, monitoring, and terminal-delivery
action a stable ID. Map every ID to one evidence row that names the owning gate,
why the action is load-bearing, its capability or integration, current
principal and target, auth and runtime/network states, evidence source and
freshness, allowed and prohibited boundaries, availability, fallback or
blocker, and action role.

Use this exact delimiter-safe row grammar:

```text
action-id=<owning-gate>|<purpose-rationale>|<capability-integration>|<principal>|
  <target>|<auth-state>|<runtime-network-state>|<evidence-source>|<freshness>|
  <allowed-boundary>|<prohibited-boundary>|<availability>|<fallback-blocker>|
  <action-role>
```

The delimiters `,`, `|`, and `=` are reserved and cannot appear inside a field.
Every planned action ID has exactly one row, no unrelated row is allowed, and
the final `action-role` must equal that action's planned role. At the approval
hold:

- `principal` and `target` are exact stable values or `not-required`;
- `auth-state` is `authorized` or `not-required`;
- `runtime-network-state` is `ready` or `not-required`;
- `freshness` is `current@<timestamp-or-immutable-identity>`;
- allowed and prohibited boundaries are both explicit;
- `availability` is `verified`;
- `fallback-blocker` is `none`; and
- a mutation row's allowed boundary includes the exact
  `<environment>/<write-or-execute-ceiling>` it proves.

Do not list unrelated installed tools. Do not place tokens, passwords, bearer
credentials, private keys, cookies, secret values, or credential-bearing URLs
in any row. Runtime capability, external identity/auth, privacy, and monitoring
execution retain their own gate ownership. A credentialed smoke or metadata
check is never implied by this packet. A local-only capability cannot satisfy a
remote mutation row.

The envelope transports existing owner results rather than deciding them:

- `Risk` and descriptive `Blast radius` come from `risk-and-side-effects`;
  blast radius describes affected scope and hard quantity ceilings, not a
  second Work Item Profile estimate scale.
- Principal, target, auth/permission state, and external allowed/prohibited
  operations come from `external-system-boundaries`.
- Capability/integration, runtime/network/sandbox state, availability, and
  fallback or blocker come from `runtime-capability-check` when triggered, or
  from the current inventory/config evidence that proved the gate unnecessary.
- Purpose/rationale states why the already-planned action role is load-bearing
  for the accepted objective or terminal proof; it cannot add another action.
- Evidence source/freshness comes from the gate that produced the evidence.
- Monitoring capability and prerequisites remain owned by their existing
  runtime, waiting, phase-readiness, and specialist gates.

## Predeclared Bounded Recovery

When bounded recovery may be needed, include its exact recovery action classes
as phase-authorized actions and give each a planned mutation row plus current
capability evidence before the approval hold. Do not add a generic recovery
wildcard after confirmation.

## Effect Classification

Classify critical mutation effect from the action's normal outcome, not from
the API or tool name. `direct` means the action itself changes a critical
shared target; `predictable` means its normal successful workflow triggers
that change; `none` means neither occurs. `direct` or `predictable` plus a
critical shared target requires the shared-mutation latch. `none` remains
outside the envelope only when the irreversible branch is also false; otherwise
the same existing latch gates the qualifying action. A qualifying action must carry the same effect
classification into execution evidence so a missing latch cannot be hidden by
its surface label.

## Lifecycle And Approval Latch

Every qualifying version starts in `PRELIMINARY`. A qualifying mutation without
verified standing authority uses this same-version progression:

```text
PRELIMINARY -> APPROVAL REQUIRED -> READY FOR AUTOPILOT |
                                      READY WITH CHECKPOINTS
```

`APPROVAL REQUIRED` is the single interactive hold budgeted for that stable
version. The parent must display the lossless acceptance card, or the complete
envelope when lossless projection is not possible, and stop before mutation.
Confirmation is valid only when the user names the envelope ID/version or gives
an immediate unambiguous approval to the displayed unchanged packet with no
intervening material delta. Before action, record the binding to that exact
version, environment, principal set, resource set, action classes, ceilings,
and predeclared recovery permission. A denial or cancel moves the version to
`BLOCKED`; later reconsideration starts `vN+1`.

## Immutable Fields After The Hold

After `APPROVAL REQUIRED`, only confirmation or verified-standing-authority
evidence, latch status, and the resulting `State` may change on the same
version. Environment, principals, resources, sensitivity, action classes,
action graph and capability map, shared-environment effect, ceilings, rollback,
monitoring, checkpoints, abort conditions, and proof are immutable. Any change
clears confirmation, creates `vN+1` in `PRELIMINARY`, and rebuilds readiness.

A presentation erratum does not mutate those fields. Execution may also append
recovery and refreshed-proof evidence without changing the envelope when the
recovery action class and capability row were present before the hold and all
of these conditions hold:

- current critical target state and the first attempt's effect are read back;
- partial state is known and safely reconcilable;
- the recovery keeps the exact environment, principal, resources, action
  semantics, credentials, tooling, network/cost effects, ceilings, and
  rollback boundary already confirmed;
- the action is idempotent under the observed state or the predeclared recovery
  explicitly reconciles that state;
- only one changed-variable retry is attempted; and
- every readiness, specialist, validation, monitoring, or proof gate
  invalidated by the recovery is rerun before the completion claim.

A new critical target, principal, action semantic, environment, credential,
tool, network/cost effect, ceiling, rollback burden, a second failure, or
unknown partial external state is not bounded recovery. Stop and create
`vN+1`, or use `BLOCKED` when the partial state cannot be safely reconciled.
Ordinary Git hook, restaging, invocation, or content-fix recovery is owned by
`worktree-readiness`; it does not create or version an autonomy packet
unless its predictable normal effect independently satisfies the critical
mutation predicate.

## Verified Standing Authority

Verified standing authority may move a qualifying version directly from
`PRELIMINARY` to a terminal execution disposition only when the current
incident/release authority artifact explicitly covers the same environment,
principal, resources, actions, applicability window or condition, rollback or
abort, proof, and operator role. A runbook that describes mechanics does not
create authority.

## Readiness States

The readiness states mean:

- `READY FOR AUTOPILOT`: every planned action has action-specific authority,
  a complete current capability row, prerequisites, owning gates, proof, and
  required terminal-observation capability; for a qualifying
  mutation, the latch is `confirmed` or `standing-authority`;
- `READY WITH CHECKPOINTS`: execution may continue only until the named
  checkpoints, each of which stops before the specified action for new evidence
  or authority; it never permits crossing a qualifying-mutation checkpoint;
- `APPROVAL REQUIRED`: only the enumerated preliminary preflights may continue;
- `BLOCKED`: no safe progress remains.

`PRELIMINARY` remains the state while an authorized read-only preflight can
populate or refresh a row, a row is partial/unknown/unavailable, prerequisites
are unresolved, monitoring is unknown, or `Unresolved readiness` is not
`none`. Use `BLOCKED` when no safe authorized preflight can resolve a
load-bearing blocker, required authority/capability/terminal observation is
unavailable, or rollback remains unknown for high/critical work.

Enter `APPROVAL REQUIRED` only when the activation predicate is satisfied;
every planned action has exactly one complete, current,
role-matched, authorized or not-required, network-ready or not-required,
verified, boundary-complete, blocker-free evidence row; prerequisites and gates
are exactly `met`; monitoring capability is `supported`; `Unresolved readiness`
is exactly `none`; rollback, abort, readback, and bounded cost are valid; and
the latch is `awaiting-confirmation`. Otherwise remain `PRELIMINARY` or return
`BLOCKED`; never ask the user to approve an incomplete readiness claim. In
particular, bounded restoration `unknown` cannot enter `APPROVAL REQUIRED`.

## Axis Comparison

Compare these axes independently. Environment order is `local <
remote-non-production < staging < production`. Read sensitivity order is
`public < internal < sensitive < secret-auth`; never infer sensitivity from
environment. Write/execute order is `none < workspace < validation < local-git
< remote-write < production-write < destructive-history-rewrite`.
Destructiveness order is `reversible < coordinated <
irreversible-destructive`, and monitoring order is `synchronous <
bounded-polling < autonomous-wake-resume`. Principal/identity and resource
fields are exact sets. Cost/resource limits name comparable units such as
`paid-calls=2, minutes=30`; a new unit, a higher limit, or an unbounded cost
expands them, and an unbounded ceiling cannot be `READY FOR AUTOPILOT`. Any new
category is an expansion rather than an inferred order.

## Rollback Boundary

Rollback is fail-closed rather than an unbounded permissive scale. Moving from a
local revert to coordinated external rollback is an expansion. Moving to
`approved-no-rollback` is an exceptional upward transition allowed only for an
explicitly destructive action with current owner-approved terms that name the
state that will be irretrievable and the exact compensation limits. Unknown or
unavailable rollback blocks high/critical readiness and cannot be converted to
`approved-no-rollback` by confirmation alone.

## Expansion And Narrowing

Any increase in an axis or addition to a named set stops before the expanded
action. The parent creates version `vN+1` in `PRELIMINARY`, re-enters the
dispatcher and every owning risk, external, capability, or specialist gate,
then follows the applicable ordinary, confirmation-latched, or
standing-authority lifecycle. A narrowing may continue without a user ceremony
while action-specific authority and all remaining gates still hold.

## Readiness Versus Authority

Keep readiness distinct from authority. For work outside the approval latch, an
exact current request may preserve action-specific authority while missing
preflight or rollback evidence blocks readiness. For a qualifying
mutation, the initial request preserves the objective and planned action class
but not execution authority; the post-readiness confirmation or verified
standing authority supplies that missing action boundary. A high-risk action
with unknown rollback is `BLOCKED`. Explicit owner-approved compensating or
no-rollback terms may satisfy the rollback row for intentionally irreversible
work, but do not by themselves justify `READY FOR AUTOPILOT`; every other
authority, capability row, prerequisite, gate, proof, and terminal-observation
requirement must still pass.

## Upward-Delta Reconciliation

For an upward delta, serialize this compact reconciliation after the canonical
envelope packet:

```text
Readiness states: PRELIMINARY | APPROVAL REQUIRED | READY FOR AUTOPILOT |
  READY WITH CHECKPOINTS | BLOCKED
Critical-mutation lifecycle: PRELIMINARY -> APPROVAL REQUIRED -> terminal execution state
Standing-authority lifecycle: PRELIMINARY -> terminal execution state
Independent axis comparison: environment; principal/resource sets; sensitivity;
  write class; cost; destructiveness; rollback; monitoring
Preserved gates: risk; external boundary; specialist/runbook; prerequisites;
  rollback; abort; monitoring; proof
Version transition: immutable-field delta or denial/reconsideration -> vN+1
  PRELIMINARY -> owning gates -> latch progression
Approval budget: one hold per stable version; presentation errata and
  predeclared bounded recovery do not consume another hold
Narrowing rule: continue only while remaining authority and gates hold
Irreversible readiness: explicit classification + current owner terms + all
  planned action authorities, prerequisites, gates, proof, and terminal observation
```

## Boundary With Adjacent Owners

| Question | Owner |
| --- | --- |
| Is this action authorized at all? | the owning phase plus [risk-and-side-effects](risk-and-side-effects.md) |
| What is the exact external target, principal, and readback? | [external-system-boundaries](external-system-boundaries.md) |
| Can the runtime observe the required terminal state? | [runtime-capability-check](runtime-capability-check.md) |
| Who performs and reports the observation? | [waiting-and-monitoring](waiting-and-monitoring.md) |
| Did a failed attempt leave reconcilable partial state? | [execution-recovery-and-tool-failures](execution-recovery-and-tool-failures.md) |
| Does a mid-task delta expand the ceiling? | [scope-change-control](scope-change-control.md), which cannot absorb an upward delta |
| Is the final claim supported? | [completion-claim-gate](completion-claim-gate.md) |

Ordinary Git hook, restaging, invocation, or content-fix recovery is owned by
`worktree-readiness` and does not create or version an envelope unless its
predictable normal effect independently satisfies the activation predicate.
