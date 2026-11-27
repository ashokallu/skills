<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-13 (worker-independent recovery gates) -->

# Context Recovery

```text
Type: decision gate
Use when: continuation depends on prior state that may be incomplete or stale
Skip when: the current conversation/state already supplies a trustworthy resume contract
Owns: reconstruction of the current objective, target, approvals, evidence, and safe
      resume point from stale/compacted/handed-off context
Does not own: executing the resumed task or treating prior artifacts as current proof
Allowed side effects: bounded read-only recovery; continuity artifact writes only when
                      already authorized by the active workflow
Inputs: available handoff/checkpoint/history, current target, and requested continuation
Exit states: recovered, blocked, superseded, cancelled
Outputs: current resume contract and stale assumptions retired
Re-enter when: new current evidence or owner intent changes the resume state
```

Use this lane when the agent resumes work from a previous thread, compaction,
handoff, long pause, partial notes, failed tool run, or questionable prior
completion claim.

A recovered context is a starting point, not proof. The next action must be
routed from current state.

## Use For

- "continue", "pick up where we left off", "finish this", "same as before",
  or "you know the drill"
- previous agent handoff, transcript summary, `tmp/` brief, local notes, or
  generated artifacts are the main context
- a prior completion claim is suspected to be wrong, incomplete, or stale
- a tool crash, timeout, compaction, or session end interrupted a workflow
- another agent changed the branch, PR, CI, issue, docs, or instructions since
  the plan was written

## Do Not Use For

- fresh tasks with all target details in the current user message
- active phase state where only a normal live refresh is needed; use
  `state-synchronization`
- subagent-to-subagent handoff payload shape; use `handoffs`

## Recovery Steps

1. Normalize the latest user request into one next outcome.
2. Inventory carried-forward artifacts: handoff, plan, notes, branch, PR,
   command logs, changed files, review output, external IDs, and blockers.
3. Mark each artifact as current proof, useful lead, stale, conflicting, or
   unsafe to use.
4. Synchronize live state for any artifact that gates the next action.
5. Re-emit the Classification receipt for the next phase only.
6. Preserve protected state: user changes, unrelated dirty files, secret-bearing
   logs, local-only notes, and external resources that should not be mutated.
7. Continue only if the next owner, side effects, and proof target are clear.

When resuming after a temporary side task, load the checkpoint created through
`task-suspension-checkpoint` before deciding what to implement, run, or
publish. The latest conversational blocker must not replace the primary
deliverable recorded before suspension. If recovered artifacts materially
conflict, route through `conflict-resolution` before mutation.

## Prior Completion Audit

When recovering from a questionable "done" state, check:

- Was the requested deliverable actually produced, not merely setup or planning?
- Did validation run on the current checkout/head/environment?
- Were required reviewer, CI, publication, thread, or specialist gates
  completed for the current target?
- Were remote mutations read back after write?
- Are unresolved blockers or skipped checks named as `Pending Verification`?
- Did the previous response overstate inspected coverage or current state?

If any answer is no, do not repeat completion language. Route the missing gate
or report a status update.

## Output

```text
Gate: context-recovery
Decision: RESUME | REROUTE | ASK | BLOCKED
- recovered artifacts:
- current proof:
- stale/conflicting leads:
- protected state:
- next route:
- side effects allowed:
- re-entry condition:
- Pending Verification:
```
