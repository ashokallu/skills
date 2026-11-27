---
name: peer-result-propagation
description: Use only when the current Codex Desktop orchestrator has accepted a completed result that materially changes an exact existing peer task and must deliver and join it. Do not use in Codex CLI, other harnesses, non-orchestrator tasks, or for routine progress.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-07 (Codex Desktop-only peer-result propagation contract) -->

# Codex Desktop Peer Result Propagation

```text
Type: owning lane
Use when: you are the orchestrator for the current Codex Desktop task and an accepted
          completed result changes a verified existing peer task's objective, constraints,
          acceptance criteria, admissible evidence, blocker, or next action
Skip when: the runtime is not Codex Desktop, the current task is not the orchestrator,
           the result is not accepted, progress is routine, evidence is unchanged,
           relevance is speculative, or the recipient or remit is unknown
Owns: one bounded post-result delivery, its parent-owned join, acknowledgement
      reconciliation, and return to the interrupted owner
Does not own: result production, delegation, ownership transfer, recipient decisions,
              runtime transport implementation, task creation, or task lifecycle
Allowed side effects: Codex Desktop task reads plus exact authorized sends and bounded joins
Inputs: source result ID/version, material claim and evidence, exact recipient/remit,
        affected decision, messaging authority, transport capability, and prior delivery state
Exit states: delivered | duplicate | undelivered | no relevant peer | blocked
Outputs: delivery identity, delivery packet, join record, acknowledgement disposition,
         reconciliation action, and remaining Pending Verification
Re-enter when: a material correction, recipient response, authority/transport recovery,
               or changed recipient remit affects a prior delivery decision
```

This lane is intentionally Codex Desktop-only. Do not mirror it into
`.agents`, `.claude`, the shared root instructions, or cross-harness evals.
Do not apply it in Codex CLI or another harness merely because that runtime can
read `.codex` files.

This is a narrow post-result event route for the current Codex Desktop
orchestrator. It prevents an investigation,
implementation, review, or decision result from remaining trapped in one task
when an exact existing peer will make a different decision because of it. It
does not create a general synchronization protocol.

## Runtime And Orchestrator Gate

Enter this lane only when all of these are true and the materiality trigger
below passes:

1. The current runtime is Codex Desktop.
2. The current task owns orchestration of the result and its dependent
   decision. A worker, reviewer, or recipient does not self-appoint as the
   orchestrator.
3. The completed result has been accepted by its current owner.

If any entry condition is false or unverified, keep the lane inactive and
return to the current owning route without a lane packet.

After entry, classify whether native task inventory, exact-task read,
message-send, and bounded join primitives are available for the intended
recipient. Do not attempt equivalent shell, tmux, MCP, other-harness,
task-creation, or lifecycle workarounds. Missing native primitives or
action-specific send authority selects the bounded undelivered record below
and marks the missing boundary `Pending Verification`.

## Activation

Apply this deterministic positive trigger only after a result exists:

> The result changes a verified existing recipient task's objective,
> constraints, acceptance criteria, admissible evidence, blocker, or next
> action.

Verify the recipient's current remit from exact task identity and current
task evidence. A title, guessed relationship, stale roster, topical overlap,
or possible future usefulness is insufficient.

Do not activate delivery for:

- routine progress or social status;
- evidence the recipient already has with no changed consequence;
- speculative relevance or an unknown recipient/remit;
- a broad team, roster, or full-mesh audience;
- a task that would need to be created or revived solely for the update; or
- an unavailable action-specific messaging authority for the send itself; in
  that case use the bounded undelivered fallback after material lane activation.

When no exact relevant peer exists, exit `no relevant peer` without emitting a
packet or adding ceremony. When material relevance is established but the
send path is unavailable, use the bounded undelivered fallback below; do not
infer authority from the importance of the result.

## Precedence And Ownership Boundaries

Run this event route after the source result is accepted by its current owner
and before any dependent decision, handoff, integration, or completion claim.
Block only work that consumes the delivery or acknowledgement. Unrelated work
continues.

- `delegation` owns assigning child work and consuming the child's final. This
  lane may begin only after that result exists and only for a separate existing
  peer whose decision changes.
- `handoffs` owns transferring work to one next owner. This lane keeps current
  ownership unchanged and must not duplicate a payload already carried by an
  accepted handoff to the same task.
- `status-and-continuity` owns user-facing routine status. This lane is not a
  progress-reporting channel.
- Codex Desktop owns task discovery, exact send/read/wait primitives, task and
  host identifiers, cursors, and transport-specific recovery. This lane does
  not define a portable adapter contract for other runtimes.

After every required delivery is joined or explicitly recorded as
undelivered, return to the interrupted owner. This lane never becomes the
owner of the recipient's objective or the parent decision it informs.

## Material Claim And Delivery Identity

Represent each material claim as the affected field, the concise changed
claim, and the evidence identity that supports it. Order multiple claims by
affected field and evidence identity; formatting, greetings, and explanatory
prose do not participate in identity.

The delivery identity is the semantic tuple:

```text
<exact recipient task identity>
<source result ID>
<source result version>
<ordered material-claim set>
```

The exact recipient identity includes the host when the runtime requires it.
A digest may accompany the tuple, but it never replaces the human-readable
fields.

- If the same delivery identity was already accepted by transport, do not
  resend it. Resume its existing join when dependent work needs the result.
- If the same delivery identity was already acknowledged, reuse that
  acknowledgement and exit `duplicate`.
- A material correction increments the source result version, marks the old
  identity superseded, and creates a new delivery identity.

## Delivery Protocol

For each exact recipient:

1. Verify the task identity, current remit, material changed field, affected
   decision, and action-specific authority.
2. Check prior delivery state using the delivery identity.
3. Send one concise evidence-bearing delivery packet through Codex Desktop's
   exact-task messaging primitive. Do not add social introduction, reciprocal
   acknowledgement, or unrelated context.
4. Record accepted-send evidence. Dispatch is not acknowledgement.
5. Open exactly one parent-owned join record for the accepted send.
6. Before dependent use, consume a non-empty recipient final that explicitly
   correlates to the delivery identity and classify its disposition.

Serialize dependent sends to the same recipient. A destination turn may
contain multiple injected messages, so a shared turn or cursor is never
per-message acknowledgement. If the runtime allowed independently authorized
concurrent sends, keep each accepted send separate and leave per-message
acknowledgement `Pending Verification` until an exact correlated final exists.

## Unavailable Transport Or Authority

When an exact previously identified recipient cannot be revalidated, the task
plane is unavailable, or send authority is absent:

- do not send, create a task, revive a task, change lifecycle state, or choose
  a replacement recipient;
- preserve one `Undelivered peer result:` packet in the current task's
  already-authorized durable checkpoint, handoff, or result state;
- mark delivery and acknowledgement `Pending Verification`;
- name the exact reopen condition, such as restored task readback, verified
  recipient identity/remit, or new explicit messaging authority; and
- block only the decision that depends on delivery while unrelated work
  continues.

This fallback creates no filesystem-write permission. If no durable state
transport is authorized, include the packet in the current owner's existing
user-visible or handoff output and report that persistence itself is
`Pending Verification`.

## Required Records

```text
Peer-result delivery packet:
- source result: <stable ID>@v<positive integer>
- recipient: <exact task and host identity>
- verified remit: <current evidence>
- material field changed: <objective | constraints | acceptance criteria |
  admissible evidence | blocker | next action>
- claim and evidence: <concise claim plus exact evidence identity>
- affected decision or next action:
- requested incorporation:
- authority boundary:
- delivery identity: <semantic tuple or lossless reference>
```

```text
Peer-result join record:
- delivery identity:
- accepted-send evidence: <exact runtime receipt or Pending Verification>
- destination turn and cursor: <when exposed>
- join owner:
- join checkpoint:
- acknowledgement state: pending | acknowledged | Pending Verification
```

```text
Peer-result acknowledgement packet:
- delivery identity:
- non-empty final evidence:
- recipient disposition: accepted | corrected | rejected | unrelated | needs input
- corrections or new constraints:
- affected parent decision:
- reconcile or reopen action:
- remaining Pending Verification:
```

```text
Undelivered peer result:
- delivery identity or candidate source result:
- intended exact recipient and last verified remit:
- material claim and evidence:
- unavailable boundary: transport | recipient verification | authority
- blocked dependent decision:
- unrelated work allowed:
- reopen condition:
- persistence: <durable checkpoint, handoff, or result state | user-visible
  output only and Pending Verification>
- delivery: Pending Verification
- acknowledgement: Pending Verification
```

## Acknowledgement And Corrections

Accepted-send evidence proves only that transport accepted a write. Treat the
delivery as acknowledged only when a non-empty recipient final explicitly
correlates to the delivery identity. If correlation is missing, classify the
final for its own task but keep this delivery's acknowledgement `Pending
Verification`.

For `corrected`, `rejected`, or constraint-changing acknowledgements:

1. mark the prior claim and every dependent decision that consumed it;
2. supersede the old source result version;
3. reopen the parent decision before any dependent action;
4. reconcile the decision with the recipient evidence; and
5. send and join any required corrected delivery under its new identity.

An `unrelated` disposition closes the delivery for that recipient and is
evidence to revisit the recipient-selection rule. A `needs input` disposition
returns to the owner of the missing decision; it does not grant the recipient
new authority.

## Focused Routing Cases

| Situation | Expected route |
| --- | --- |
| The Codex Desktop orchestrator accepts a completed result that changes an exact existing peer's next decision, and the native task primitives plus send authority are present | Activate this lane, send once, and join the exact delivery before dependent use |
| A worker or reviewer produces the result but does not own orchestration | Return the result to its parent through the existing delegation or review join; do not contact peers directly |
| Codex CLI or another harness reads this file | Keep this lane inactive; do not emulate Desktop task primitives |
| The Desktop task plane or exact recipient readback is unavailable | Preserve one undelivered record and block only the dependent decision |
| The same delivery identity was already accepted | Do not resend; resume or reuse its exact join evidence |
| A later accepted result materially corrects an acknowledged claim | Increment the source-result version, create a new delivery identity, and reopen every dependent decision that consumed the old claim |

## Anti-Patterns

- broadcast every result to every task
- create a task so a result has somewhere to go
- use titles or topical similarity as recipient proof
- send routine progress to demonstrate collaboration
- resend an accepted identity instead of joining it
- call dispatch, a busy destination turn, or an empty final acknowledgement
- make both tasks synchronously wait on each other
- block unrelated work while one dependent delivery is pending
- let this lane transfer ownership or decide the recipient's response
- silently absorb a correction after dependent work consumed the old claim
