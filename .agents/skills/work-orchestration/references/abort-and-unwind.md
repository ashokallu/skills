<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-21 (pause-versus-suspension boundary and verified cancellation) -->

# Abort And Unwind

```text
Type: owning lane
Use when: the user or governing workflow expresses stop/cancel/undo/revert intent
Skip when: the user asks for a tangent with later resume; use task suspension
Owns: freezing side effects and carrying out the smallest authorized cancel, revert,
      discard, or containment action
Does not own: speculative cleanup, unrelated rollback, or incident diagnosis
Allowed side effects: only the read/write actions necessary to freeze, reverse, or
                      safely hand off the named work
Inputs: stop intent, active operations/children, mutation inventory, ownership, current
        state, authority, and rollback options
Exit states: stopped, reverted, partially unwound, blocked, transferred
Outputs: mutation inventory, terminal state, and residual risk
Re-enter when: the user changes intent or new mutation evidence appears
```

Use this lane when the user asks to stop, cancel, abort, pause, undo, revert,
roll back, or discard work the agent has done or is doing — in this session or
a prior one. This includes "stop", "hold on", "don't do that", "undo what you
changed", "revert your commits", "close that PR", and "put it back the way it
was". Do not treat "wait for CI", "wait for reviewer", or "wait for command
completion" as aborts; those route to `waiting-and-monitoring`.

This lane is user-initiated unwinding. Failure-initiated recovery (crashed
tools, partial execution) belongs to `execution-recovery-and-tool-failures`;
this lane owns deliberate reversal of work that may have succeeded.

## Use For

- an explicit stop/cancel while a multi-step task is in flight
- a request to undo or revert local edits, commits, pushes, PRs, comments,
  ticket transitions, page edits, or other agent-made mutations
- discarding an approach mid-way and returning to a known-good starting state
- distinguishing "stop doing more" from "reverse what was done" when the user's
  wording covers both
- deciding which parts of completed work can be reversed, which cannot, and
  which need owner confirmation before reversal

## Do Not Use For

- tool or command failures with no user stop request; use
  `execution-recovery-and-tool-failures`
- a scope change or correction that redirects work rather than reversing it;
  use `request-intake` before a phase begins or `scope-change-control` after it
  begins
- a pause that introduces a replacement or side task with intent to resume,
  such as “pause this and do Y first”; route through
  `task-suspension-checkpoint`. A bare “pause,” “stop,” or “hold on” with no
  replacement task remains **halt** intent here
- git mechanics of reset, revert, force-push, or branch surgery as the main
  task; route the chosen reversal to `worktree-readiness`
- production rollback of deployed behavior; use `incident-command` plus
  `risk-and-side-effects` and the owning production workflow

## Immediate Response

On any stop-shaped message:

1. Freeze side effects first. Issue no new local write, git write, remote
   mutation, or delegation, and start no follow-up step. For an operation already
   dispatched, use a verified safe-cancel mechanism when available. When abrupt
   interruption would corrupt state and cancellation is unavailable, allow only
   the current atomic operation to reach a safe boundary, then inventory its
   actual result; do not continue the workflow.
2. Acknowledge the stop before doing anything else. Do not spend the stop
   message finishing "just one more step"; the user's stop outranks the plan.
3. Classify intent: **halt** (stop future work, keep current state),
   **unwind** (reverse some or all mutations), or **halt-then-decide**
   (stop now, present state, let the user choose). When wording is ambiguous
   and any mutation was externally visible, default to halt-then-decide.
4. When the same message names a side or replacement task to do first, freeze
   effects and reroute to `task-suspension-checkpoint` before starting it. Do
   not start the same-session tangent until that lane has written its disclosed
   session-owned checkpoint. An explicit no-local-write boundary or missing
   stable session identity blocks the same-session tangent and requires a
   separate session or explicit permission; a response-only packet is not a
   substitute.
5. For delegated or background work, request cancellation through the verified
   runtime mechanism when one exists and record whether it was accepted. Until
   terminal cancellation is observed, treat the worker/process as still active,
   revoke no permissions by assumption, and preserve/contain any possible
   writes through its owning workflow. Ignore late output unless the user later
   reauthorizes consumption.

## Mutation Inventory

Before proposing or performing reversal, inventory what actually changed,
from the route ledger and live state rather than memory:

```text
Mutation inventory:
- local writes: <files changed/created/deleted, generated outputs>
- git writes: <commits, branches, resets, amends; pushed or local-only>
- remote writes: <PRs, comments, thread resolutions, labels, ticket
  transitions, page versions, uploads>
- delegations in flight: <subagents/Luna/reviewers launched and their write capability>
- irreversible or already-consumed effects: <sent notifications, merged PRs,
  deleted remote data, external side effects>
- protected state: <user edits, unrelated dirty files, others' work that must
  not be touched by the unwind>
```

If the session resumed from compaction or a handoff, load `context-recovery`
first so the inventory reflects prior-session mutations too.

## Reversal Rules

- Reverse in dependency order: remote visibility first when it misleads people
  (close/comment on a wrong PR before deleting its branch), then git state,
  then local files.
- Match the reversal to the mutation class: unpushed commits can be reset;
  pushed commits on shared branches are reverted, not force-pushed, unless the
  user explicitly approves history rewrite and the branch is theirs to rewrite.
- Never widen the blast radius while unwinding. An unwind touches only
  agent-made mutations from the inventory; it must not revert other agents' or
  the user's work, clean unrelated dirty files, or "tidy up" beyond scope.
- Remote reversals are new remote writes. Route them through
  `external-system-boundaries` (target, identity, readback) and
  `risk-and-side-effects` when the reversal itself is externally visible or
  destructive.
- Some things cannot be unwound: sent notifications, seen comments, merged
  PRs, executed jobs, consumed quota. Name these plainly instead of
  pretending the state was restored.
- Confirm before destructive reversal: deleting a remote branch, closing a PR
  with review activity, discarding uncommitted work that took real effort, or
  reverting anything another person has built on.
- After unwinding, read back the end state (git status, PR state, ticket
  state) and report it; do not claim "restored" from the reversal commands
  alone.

## Output

```text
Abort/unwind decision:
- stop intent: halt | unwind | halt-then-decide
- mutation inventory: <summary or reference>
- reversed: <what and how, with readback evidence>
- not reversible: <named residual effects>
- protected state preserved: <evidence>
- next route: <await user | task-suspension-checkpoint | request-intake |
  scope-change-control | none>
- Pending Verification:
```
