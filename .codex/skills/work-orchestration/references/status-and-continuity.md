<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 (preserve suspended objectives across tangential work) -->

# Status And Continuity

```text
Type: owning lane
Use when: the user asks for status, progress, what remains, or a resume summary rather
          than immediate execution
Skip when: the user asks to continue execution rather than receive status
Owns: a read-only account of current state, completed work, remaining work, blockers,
      approvals, active operations, and exact resume point
Does not own: mutation performed merely to improve status
Allowed side effects: read-only refresh needed for an honest update
Inputs: current objective/target, work records, visible state, and requested detail
Exit states: status delivered, resume-ready, blocked, superseded
Outputs: progress packet and next route/re-entry condition
Re-enter when: the user asks to resume or current state changes
```

Use this lane when the user asks for status, progress, what remains, where the
work stands, what was done, what is blocked, or how to continue from partial
work. This lane produces a truthful state update without accidentally mutating
local or remote state.

This lane is especially important for long-running work, interrupted work,
context compaction, user corrections, partially completed plans, and handoff
preparation.

## Use For

- "status", "where are we", "what remains", "what did you change",
  "summarize progress", or "what is blocked"
- an explicit request for a resume summary or continuation packet before work
  restarts; after the packet, re-enter `context-recovery`/
  `state-synchronization` and the owning execution route
- user interrupts, course corrections, changed priority, or a request to pause
  before the next mutation
- partial progress updates during multi-step work
- turning messy notes, tool output, sidecar output, or an active todo list into
  a clean continuation packet
- reporting what was validated versus what is still `Pending Verification`

## Do Not Use For

- final done/ready/fixed claims; use `completion-claim-gate`
- a bare “continue” or “finish” request that asks for execution, not a report;
  route directly through `context-recovery`/`state-synchronization` and the
  owning execution route, emitting only a compact progress update as needed
- stale or questionable branch/PR/CI/release state before mutation; use
  `state-synchronization` or `context-recovery`
- external write, commit, push, PR publication, comment, deploy, rollback, or
  production action
- implementation or validation work after the next owner is clear

## Status-Only Boundary

A status request is read-only by default. Do not edit files, commit, push,
comment, resolve threads, rerun broad validation, or mutate external systems
merely to make the update look fresher.

During active authorized work, a status question is a brief reporting step,
not cancellation or a new permission hold. Answer it, then resume the active
owner under the existing authority. A request to pause, stop, or replace the
work changes that behavior and routes through the corresponding owner. A short
side question does not require a suspension checkpoint unless it actually
suspends the unfinished task.

Allowed actions inside this lane:

- inspect already-available notes, plan state, cited files, and recent tool
  output
- run narrow read-only state checks only when the status would otherwise be
  misleading and the read is inside the user's implied scope
- state "last verified at `<evidence>`" when a live read is unavailable or not
  worth the cost

If a current-state read is required before the next action, route to
`state-synchronization` after the status packet instead of hiding that need.

## Continuity Rules

- Separate **done**, **changed locally**, **validated**, **blocked**, and
  **not checked**. These are different claims.
- Do not promote a sidecar, reviewer, or previous assistant summary to proof
  unless the parent verified the evidence.
- Preserve side-effect history: local writes, generated files, git writes,
  remote reads/writes, services started, data touched, and artifacts created.
- Preserve target identity: repo path, branch, commit/head, PR, issue, service,
  environment, file, dataset, or artifact.
- Preserve the next safe route, not just the next task. Name the lane or
  specialist that owns continuation.
- When user correction changes target, scope, priority, or side-effect
  boundary, stop the old route and re-enter the dispatcher; use
  `request-intake`, `scope-change-control`, or `objective-lock` according to
  whether the change is ambiguous, mid-scope, or objective-changing.
- A bounded side task does not replace the suspended objective. On return,
  re-enter `context-recovery`, reload the approved plan and evidence, and prove
  the next deliverable still matches the primary outcome before editing,
  publishing, or running an operation.
- Do not say "only X remains" unless every other required gate is either
  complete or explicitly out of scope.

## Progress Packet

For non-trivial status, use this compact form:

```text
Status packet:
- objective:
- current route:
- target/state last verified:
- completed with evidence:
- changed locally:
- validation/run evidence:
- side effects already taken:
- blockers:
- Pending Verification:
- next safe route:
- user decision needed:
```

## Handoff Difference

Use `status-and-continuity` when the user needs a readable progress update or
when the same agent can continue. Use `handoffs` when another agent or future
session must take over with an explicit `Next owner`, blockers, target freshness, and exact
continuation instructions.
