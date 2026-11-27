<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-07 (typed decision transport and asymmetric fallback) -->

# Request Intake And Ambiguity Control

```text
Type: decision gate
Use when: a wrong initial interpretation could change target, safety, acceptance, or
          side effects, or deterministic high-impact alignment must run despite clarity
Skip when: a bounded safe read or a reasonable non-material default resolves it
Owns: clarification of objective, target, requested output, and permission for the next
      phase
Does not own: implementation, mid-execution scope disposition, objective authorization,
              or substantive diagnosis
Allowed side effects: bounded read-only discovery
Inputs: current request, visible context, governing instructions, and safe evidence
Exit states: proceed, ask, blocked, reroute, stop, out-of-scope
Outputs: one routeable intake contract and next owner
Re-enter when: the user or evidence materially changes the request
```

## Use For

- unclear references such as “it,” “this PR,” “the branch,” or “the issue”;
- mixed requests containing review, fix, validation, commit, push, publication,
  deploy, or handoff phases;
- unclear write permission or expected artifact;
- broad requests whose target, owner, or acceptance is not yet routeable;
- a new request whose relationship to unfinished work is unclear;
- a user correction that changes the next action before execution resumes.

Also activate as a detector when any of these is true, even if the request
looks clear and the agent is confident:

- an active Work Item Profile is `complex` or `long-horizon`, has
  `cross-system` or `production-wide` impact, or is `coordinated` or `one-way`;
- the ask changes workflow, orchestration, reviewer, agent, skill, publication,
  or other durable defaults;
- broad deletion or consolidation could remove useful colocated content; or
- the work spans multiple owners.

Detection does not make this lane the intent owner. Route an activated case to
`objective-lock`, which alone obtains approval of the intent contract. Consume
an already-active Work Item Profile when useful; do not activate one only to
produce intake ceremony. Ordinary localized reversible work does not activate
this path and emits no skip packet.

Use `scope-change-control` for a material delta discovered **after** a phase is
already active. Use `task-suspension-checkpoint` when a tangent pauses rather
than replaces unfinished work. Use `abort-and-unwind` for stop/cancel/undo
intent.

## Intake Procedure

1. State the next operational outcome in one sentence.
2. Identify the exact target or the smallest read that can identify it.
3. Separate mixed intent into ordered phases; do not authorize later side
   effects early.
4. Classify the ambiguity:
   - target;
   - scope;
   - side-effect permission;
   - acceptance/proof;
   - stale state;
   - conflicting instructions or evidence.
5. Resolve cheap facts from authorized sources before asking the user.
6. Use the safest reasonable default when the ambiguity is low-risk.
7. Ask only for missing information that blocks safe or correct progress.
8. Return one next owner or a precise stop state.

## Question Policy

A blocking question is justified only when the answer is not already supplied
by the complete request, conversation, or current evidence, no reasonable
choice inside the accepted contract resolves it, and its answer can change one of:

- the target;
- the user’s permission boundary;
- a high/critical-risk decision;
- the accepted behavior or deliverable;
- the ability to prove completion.

Batch related blockers into at most three targeted questions. Include the
default you will use when one is safe. Do not ask for facts available in the
conversation, repository, current branch/PR metadata, or a provided artifact.
Do not repeat a question already answered.

First complete independent work already authorized and needed to make the
decision reviewable. Stop only the dependent action. Do not ask the user to
choose routine implementation mechanics, approve an inactive gate, or repeat
permission for an unchanged action. An unresolved product, authority, safety,
or acceptance decision still belongs to its owner.

When a skill requires the hold, identify its exact path and relevant rule,
the missing input, and why existing authority does not satisfy it. Distinguish
an explicit requirement from an interpretation. Use a question tool only for
the purposes that its current runtime contract allows; tool availability alone
does not make it an approval channel.

Use this transport matrix after the owning workflow has determined that a
question is necessary. The matrix selects transport; it never creates the
underlying decision or authority.

| Decision | Required transport |
| --- | --- |
| Optional, non-authority preference whose omission has a safe default | `request_user_input` when available; continue with the disclosed default if unanswered |
| Exact agent authority or permission bound to one displayed artifact/version | Root-only `request_user_decision` with `mode=approval`, an empty caller-options list, and the owning runtime's exact binding contract |
| Durable non-authority blocking choice or non-secret free text bound to one version | Root-only `request_user_decision` with `mode=blocking_input` and zero to three caller choices |
| Required approval when `request_user_decision` is positively absent before presentation | The owning workflow's documented plain-text fallback, displaying the same complete artifact and requiring one unambiguous bound confirmation |
| Structured decision created but declined, cancelled, feedback-only, expired, mismatched, or transport/persistence state becomes uncertain | Remain blocked or continue only independent already-authorized work; never open a second channel |

Ordinary `request_user_input`, MCP elicitation, a dynamic tool, chat, silence,
or a default is never an approval channel. `Give feedback` is steering, not
authority, even when its free text says to approve. A child returns its
question to the parent and never receives or proxies the root-only decision
capability.

Only the parent asks the user. A child returns the questions and defaults to
the parent. The transport matrix above is authoritative: the parent uses the
verified native capability required by the applicable row, and a plain-text
approval fallback is allowed only when the owning workflow documents it and
capability absence was positively established before presentation. Failure or
uncertainty after structured presentation never opens another channel. Tool
absence never implies approval. For mandatory high-impact alignment, this
lane routes the evidence and open decisions to `objective-lock`; it does not
ask a second set of intent questions or approve the contract itself.

When no safe default exists, use:

```text
Blocking input: <exact fact or approval>
Why it matters: <target/safety/acceptance consequence>
Safe work possible meanwhile: <none or bounded read-only work>
```

## Default Interpretations

These are defaults for an otherwise unqualified request, not keyword rules.
Read the whole sentence and prior authority first. For example, "how would you
do this, then make the changes" requests execution, while "how would you do
this, do not edit" requests a plan. "Can you fix this?" is an action request.

- “check,” “look at,” “review,” “explain,” “plan,” and “how would you” are
  read-only; an explicitly repo-authorized disposable PR-review checkout is a
  narrow setup exception, not permission for validation, edits, git history, or
  remote mutation;
- Unless the request narrows or forbids the work, “fix,” “implement,” “update,”
  “add,” and “remove” authorize scoped workspace-local edits plus the focused
  local checks required by the owning workflow. Those checks must not add a
  paid call, external or shared-environment operation, publication, or
  destructive cleanup. These action words do not authorize commit, push, PR
  mutation, deploy, or production/data mutation;
- “validate,” “verify,” “try it,” “smoke test,” “build,” and “compile” request
  an actual check when the environment supports it;
- “push,” “open/update PR,” “comment,” “merge,” “release,” “deploy,” and
  “apply” require the matching remote or production phase;
- “use your judgment” allows the simplest reversible choice inside the current
  permission boundary, not broader architecture or risky writes.

A direct request for a later action preserves its authority while the earlier
phases run; it does not let that action run before its prerequisites.

## Out-Of-Scope Requests

This dispatcher governs example-app repository work. Intake is where a request
outside that context is recognized, before any lane is selected.

Return `out-of-scope` when the request has no example-app repository target
and no repository side effect would advance it. Name the closest owner when one
exists, then stop. Do not force the request onto a lane, invent a generic
project-management workflow, or perform a repository side effect to make an
out-of-scope request tractable.

A request that mixes in-scope and out-of-scope work is not out of scope. Order
the in-scope phases normally and report the out-of-scope remainder as an explicit
exclusion:

```text
Scope split:
- in scope: <ordered phases with owners>
- out of scope: <exact excluded portion and closest owner, or none available>
- exclusion is explicit: yes
```

Do not silently omit the remainder. An unreported exclusion later reads as a
completion claim for work that was never attempted.

## Mixed Requests

Represent each phase independently:

```text
1. review — read-only — verdict proof
2. fix accepted findings — local write — focused validation
3. commit — local git write — HEAD/status readback
4. push/update PR — remote write — remote metadata and current-head readback
```

A later phase may depend on the prior result and may never become active.
Execute an explicitly requested phase when its conditions and required gates
pass. Preserve conditional wording: "review, then fix and push" supplies later
action authority; "review, then we may fix it" does not. Do not ask again for
unchanged authority or treat mentioning a possible phase as an instruction.

## Objective And Work Item Escalation

The objective produced here is provisional. Route to `objective-lock` when the request
materially selects or changes authority, fallback/error/availability semantics,
runtime dependencies, data/auth ownership, production defaults, public
contracts, migration/cutover states, or durable workflow policy.

Create a Work Item Profile from `workflow-contracts` only when a real downstream
implementation, validation, review, publication, or initiative-slicing decision
will consume its estimate. Task length alone does not activate it.

When the dispatcher has activated a task autonomy envelope, intake may supply
verified target, phase, and authority facts to that envelope. Intake never owns
envelope activation, readiness, versioning, or reconciliation, and a clear
request must not be routed through intake merely to populate the packet.

## Output

```text
Gate: request-intake
Decision: PROCEED | ASK | BLOCKED | REROUTE | STOP | OUT-OF-SCOPE
Objective:
Target:
Ordered phases:
Allowed boundary for next phase:
Ambiguities resolved:
Assumptions / Pending Verification:
Blocking question: <none or one batched question>
Next owner:
Reopen condition:
```
