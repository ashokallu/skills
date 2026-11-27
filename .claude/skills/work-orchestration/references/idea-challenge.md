<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-03 (planning-philosophy single-consumption routing) -->

# Idea Challenge

```text
Type: decision gate
Use when: the user proposes a material implementation, architecture, workflow,
          migration, skill, or durable process direction
Skip when: the change is purely mechanical, the current plan/direction is already
           accepted and unchanged, or incident containment must happen first
Owns: whether an unapproved proposed direction should proceed, be revised, be avoided,
      or require an accountable owner decision
Does not own: objective authorization, implementation, or final review
Allowed side effects: bounded read-only evidence gathering and critic dispatch
Inputs: locked objective or clear request, proposed direction, current constraints, and
        relevant system evidence
Exit states: proceed, revise, avoid, needs owner, blocked
Outputs: one disposition, smallest safe version, and next owner
Re-enter when: the objective, proposal, material evidence, or constraints change
```

Use this lane before implementation, workflow, skill, architecture, migration,
or durable process work when the user proposes a direction and the repo has not
yet committed to executing it.

This lane is the default adversary to eager obedience. It asks whether the idea
should be done at all, whether an existing path already solves the need, whether
the current proposal is only a partial slice of the real action item, and
whether a smaller reversible move or a better-scoped single PR preserves most
value with less risk.

## Mission

Challenge the idea while change is still cheap. Be direct, skeptical, and
evidence-backed. Do not be hostile, performative, or contrarian for sport.
Useful sharpness is allowed when it clarifies the consequence, but the value is
the missing dimension and evidence path, not the quip.

Act as the user's thought copilot. The user may be underthinking, overthinking,
or ideating from incomplete information. Do enough thinking to steer the work:
surface the missing dimensions, pick a useful next slice, and prevent avoidable
rework. Do not over-rotate into decision paralysis or endless option analysis.
Use existing repo guidance as the shortcut that keeps judgment sharp without
rethinking every case from scratch.

## Objective-Lock Prerequisite

When `objective-lock` activates, consume its exact lock ID/version before
challenging a solution. Do not infer, replace, or broaden a required objective
from the proposed implementation, critic advice, reviewer findings, or nearby
code. A material `pending owner` or `pending evidence` item blocks this lane
until resolved.

Classify every proposed direction as `direct`, `protective`,
`contract-changing`, or `unrelated` under the lock. A protective direction must
map to a named invariant and proven causal risk. Freeze contract-changing work
and return an owner decision; idea challenge cannot authorize a new contract.
Reject or defer unrelated work.

Use `already locked: <lock-id>@v<version>` for unchanged approved work. This
avoids an objective-lock-generated duplicate challenge but does not suppress an
independently required critic or reviewer gate.

## Forward-Analysis Decision

When the proposed action claims to unblock a larger workflow or could spend
material code, review, CI, release, migration, shared-environment, or operator
budget, consume [forward-analysis.md](forward-analysis.md) here as a companion
lens. This is the earliest owning decision point. Complete its whole-problem, current-evidence,
alternatives, proposed-output, next-consumer, smallest-action, and claim-boundary
decision before recommending execution.

Record that result once using the owner-issued ID and version.
When it controls a substantive plan, show the complete bounded record to the
user before recommending execution. A cross-session critic brief carries the
record ID/version and its decision-changing conclusions without duplicating the
unchanged full record; a same-session reference is valid only while the
consumer can dereference and verify it. Later workflow synthesis, authoring,
review, and specialist lanes consume or challenge the decision without repeating
the analysis. Reopen it only for a material change to the objective, target,
evidence, proposed output, next consumer, or acceptance rules.

When this lane escalates to a fresh critic and forward analysis is active, the
compact semantic brief from `pre-code-critic-assignment` is the consultation
owner. Include the challenge disposition, requested verdict, record ID/version,
and decision-changing conclusions. Do not attach a second full forward-analysis
packet, governing-source inventory, or content hash.

## Planning-Philosophy Consumption

For a substantive proposed direction, consume
[planning-philosophy.md](planning-philosophy.md) once. When forward analysis is
active, it owns that consumption and this lane uses the resulting record; do
not repeat the thought chamber. When forward analysis is inactive, consume the
companion here and place its effects in the existing strongest-objection,
simpler-alternative, evidence, smallest-version, and next-consumer fields.

Do not load or mention the companion for mechanical work or an accepted
unchanged plan with no new planning decision. Do not add a philosophy packet,
lens inventory, or acknowledgement unless a retained mechanism materially
changed a choice, probe, or stop under the companion's output rule. Keep an
applicable acknowledgement inside an existing output field; forward analysis
owns its placement when its record is active.

## Production-Ready Scope Challenge

When a proposal adds durable persistence, retained observability with ongoing
operator ownership, or lifecycle machinery, require an active objective key and
create `<objective_key>/mechanisms@v1` before recommending a slice. Record only
mandatory current contracts, proposed mechanisms, obligations, deferred
lifecycle ideas, and `keep`, `defer`, or `remove` dispositions. Keep a
mechanism only when it directly satisfies an existing acceptance criterion, is
required by a mandatory current contract, or is `protective`: it maps to a
named protected invariant and current evidence proves the change makes the
prevented failure reachable. The mechanism ledger cannot create or change the
outcome, acceptance criteria, invariants, semantics, transitions, or non-goals.

Freeze any proposed change to an objective-owned field and return to
`objective-lock`. An otherwise unmapped mechanism requires an objective-contract
amendment before it can be kept. Pass both the objective key and mechanism
scope key to authoring without requiring a narrative read or acknowledgement.

Ordinary rollback notes, short runbook updates about existing controls, typo or
formatting changes, semantically unchanged generated refreshes, and routine CI
repairs do not trigger this challenge unless they change a correctness
boundary. Expose the task-time scope decision and its evidence, not background
narrative or acknowledgement text.

Exploit the agent advantage before asking the user to decide. The user has
limited attention and cannot simultaneously read code, query databases, inspect
logs, check metrics, compare docs, and reason about PR scope. When safe,
available, and relevant, gather those evidence streams in parallel or in the
smallest useful sequence, then return a supported proceed, revise, block, or
owner-decision recommendation. Do not make the user discover evidence that the
agent can collect read-only or through already-authorized workflows.

Think at two levels before recommending execution:

1. Holistic action item: the end state, decision gate, dependency chain, owner
   decision, evidence source, operational risk, and likely follow-up work.
2. Current slice: the smallest coherent unit that advances the end state without
   creating avoidable PR, review, CI, council, or operator churn.

Default pressure: write less code and open fewer PRs. A new PR is expensive:
authoring, self-audit, local validation, review loops, bot review, CI, possible
council review, thread resolution, release validation, and handoff. Before
recommending another PR, ask whether live data reads, logs, UI/E2E checks,
existing flags, operator decisions, docs, or a broader but still coherent PR can
solve the problem without another slice. If a PR is still needed, explain why it
should be one PR or why the work must be split.

Follow this sequence:

1. Restate the idea as the decision it would commit the repo, product, users,
   operators, data, or future agents to.
2. Name the real end state the user is trying to reach, not only the literal
   next step they suggested.
3. Name the strongest objection, not the easiest nit.
4. Ask whether doing nothing, using an existing lane, gathering live evidence,
   narrowing the scope, broadening the current PR to cover the coherent action
   item, or choosing a fallback would satisfy the real need.
5. Identify the smallest reversible experiment or slice that would test the
   idea without creating unnecessary process, code, PR, review, or routing debt.
6. Decide whether to proceed, revise, avoid, or escalate before deeper work
   starts.

## Critic Escalation

Most idea challenges are handled inline by the parent agent. Escalate to the
`critic` subagent or critic role when the proposed idea needs careful
independent thought because the blast radius is high, the decision is hard to
reverse, or the change touches application foundations.

This escalation is different from the pre-code critic assignment in
`code-authoring`. This lane asks whether the idea should happen at all.
The pre-code critic assignment happens later, after the repo has a candidate
implementation direction, and asks whether that plan is coherent enough to
start editing.

One bounded critic consultation may satisfy both gates only when the brief contains distinct
`should we do this?` and `is this implementation plan ready?` sections, names
the selected implementation lanes, and the critic explicitly approves both.
The plan must remain materially unchanged. A verdict that answers only one
question satisfies only that gate, and a material revision reopens
implementation readiness.

Escalate before implementation when the idea proposes:

- adding, deleting, replacing, or splitting a service;
- rewriting a module, subsystem, workflow engine, migration path, auth model,
  data model, persistence boundary, public API, or generated contract family;
- lift-and-shift work across frameworks, stores, queues, services, or runtime
  ownership boundaries;
- changing bedrock architecture, deployment topology, IAM/security posture,
  tenant boundaries, production data semantics, or rollback strategy;
- making a default gate mandatory across many branches, PRs, agents, or
  workflows; or
- any one-way-door decision where failure would affect production, many users,
  operator recovery, team trust, or future architectural option value.

For workflow-policy decisions that significantly affect whole workflows,
escalation is mandatory, not optional. This includes adding, removing, or
changing default gates, lane behavior, skill routing, reviewer or authoring
behavior, publication workflow, or process expectations across many agents,
lanes, PRs, branches, or future reviews. The parent must run this lane, send
the idea to critic, and receive critic approval before editing instructions or
skills. Do not treat apparent usefulness, user urgency, or agent confidence as
a substitute for the gate.

When escalation is needed, stop the inline lane after preparing the critic
packet. Route dispatch through `delegation`, verifying the current critic
capability when uncertain. The parent continues only after
`APPROVED FOR IMPLEMENTATION`, or after the accountable owner explicitly
accepts a non-safety residual risk that repository policy permits them to
accept. If independent critique is mandatory and no sanctioned critic path is
available, return `BLOCKED`; parent self-review is not an equivalent fallback.

Critic is allowed to ask the parent for live-data, repo, log, metric, runtime,
PR, CI, database, or environment evidence needed to decide. When critic asks
for evidence, the parent collects the smallest safe artifact and returns it to
critic before treating the plan as approved. If critic requires revision, send
one materially revised plan back for re-evaluation. A further unchanged dispute
routes through `conflict-resolution` or `loop-control-and-escalation`; do not
shop for another critic. If critic returns `BLOCKED`, do not implement, publish,
run a mutating job, or seek another approval path around the missing evidence
unless the accountable owner provides a policy-valid non-safety decision.

```text
Critic escalation:
- reason: <foundation-level or high-blast-radius decision>
- idea: <decision being challenged>
- context: <current facts and constraints>
- requested verdict: proceed | revise | do not do | needs owner
```

## Default Trigger

Run this lane by default for user-proposed ideas that could create:

- new implementation work, feature behavior, architecture, or public contract;
- new workflow, skill, agent, lane, durable instruction, template, or process;
- migration, production data, auth, permission, privacy, infra, dependency, or
  generated-contract work;
- broad refactors, cleanup campaigns, or code-quality initiatives;
- multi-agent orchestration or default-gate changes; or
- any action where a simpler workaround, no-op, owner decision, or existing
  repo route may be better than doing the proposed work.

Skip this lane only when the request is a fast-exit answer, a tiny mechanical
edit, execution of an already approved unchanged plan, an explicit command to
commit/push/publish, or a safety-critical fix where delay would be worse than
the challenge. If skipped, name the reason briefly in the route audit.

## Pressure Tests

- What problem are we actually solving, and would the proposed change solve
  that problem or just add ceremony?
- What is the real end state, and is the proposed step only one more narrow
  slice that will force another PR immediately afterward?
- What would make this idea look silly, expensive, or confusing two weeks from
  now?
- What existing skill, lane, command, owner workflow, or repo convention already
  covers this?
- What artifact, state, or capability will this action produce, and who or
  what consumes it next? Prove that the next consumer accepts it under current
  rules and current state before saying the path is unblocked.
- What live evidence can we collect before coding, such as DB reads, logs,
  deployed config, UI/E2E behavior, or current PR/Jira/release state?
- What is the cheapest no-code, docs-only, config-only, or one-off fallback?
- What is the smallest reversible version that preserves most value?
- Can this be one coherent PR instead of several churn-heavy PRs? If not, what
  exact boundary makes the split safer than one PR?
- What new maintenance, token, routing, validation, or reviewer burden does
  this create?
- Which acceptance criterion could pass while the real user, operator, data, or
  agent outcome still fails?
- What central claim is still `Pending Verification`, and would it change the
  decision if false?
- What must be true in the next two or three phases for the user's team-facing
  statement to be honest? Do not allow "unblocked", "last PR", "ready for the
  final run", or equivalent confidence language unless those downstream gates
  are enumerated and either proven with current evidence or explicitly scoped
  out.
- Which next blocker can be predicted cheaply now, and would discovering it
  after this action force another PR, release, full run, review cycle, or user
  escalation?
- Who owns the decision if this crosses product, security, data, infra, legal,
  architecture, or operations boundaries?

## Output

Keep the challenge short enough to unblock the next route:

When a fresh critic handoff owns the current output and forward analysis is
active, use the single handoff assembly from `forward-analysis.md` instead of
the standalone packet below. The assignment itself is the user-visible,
copy-ready artifact; end after it rather than reproducing it in prose or a
second fenced block.

```text
Idea challenge:
- objective lock: not required | <lock-id>@v<version> | pending owner/evidence
- forward analysis: not triggered | complete, record=<ID/version>, transport=<exact inline | verified same-session reference> | blocked
- verdict: proceed | revise | do not do | needs owner
- strongest objection: <one sentence>
- simpler alternative: <existing path, fallback, or no-op>
- holistic action item: <end state and what must be true before it is done>
- smallest safe version: <reversible slice>
- PR/code cost: <no PR | one PR | split PRs, with reason>
- evidence needed: <artifact or Pending Verification>
- next consumer: <who/what consumes the output, acceptance proof, next blocker>
- next route: <lane or specialist>
- critic escalation: <not needed | needed, because ...>
```

If the verdict is `proceed`, continue through the normal route. If the verdict
is `revise`, update the plan before implementation. If the verdict is `do not
do` or `needs owner`, stop unless the user explicitly accepts the consequence
and no safety, privacy, secret, legal, or production-data boundary is violated.
