<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (new orchestration lane for coordinating concurrent agents and sessions on shared surfaces) -->

# Parallel Work Coordination

```text
Type: decision gate
Use when: multiple actors may touch the same files, branch, PR, environment, or external
          artifact
Skip when: work is read-only or scopes are exclusive with an ordinary parent join
Owns: collision avoidance among concurrent writers/readers on shared mutable surfaces
Does not own: whether delegation is worthwhile or the work itself
Allowed side effects: read-only coordination; mutations remain with named owners
Inputs: actors, mutable surfaces, dependencies, current state, and intended joins
Exit states: partitioned, sequenced, joined, blocked
Outputs: ownership partitions, ordering, synchronization points, and conflict policy
Re-enter when: actor set, ownership, dependency, or shared state changes
```

Use this lane when more than one actor may be changing the same surfaces at
the same time: multiple agent sessions or harnesses (Codex, Claude, Copilot,
council, Luna), a human working alongside the agent, or scheduled automation.
Shared surfaces include a branch, worktree, PR, review threads, instruction
files, generated artifacts, tickets, and pages.

The lane prevents two failure classes: stomping (overwriting or reverting
someone else's live work) and stale-evidence action (mutating a target that
another actor moved after the evidence was gathered).

## Use For

- work on a branch, PR, or file set that another agent or the user may also be
  editing now
- delegating while the parent keeps working: dividing surfaces so parent and
  subagent never write the same files or threads
- pushes, PR edits, thread replies, or instruction-branch commits where a
  remote race is plausible
- deciding whether to proceed, sequence behind the other actor, claim a
  disjoint surface, or coordinate with the user
- interpreting unexpected local or remote changes that suggest a concurrent
  actor rather than a tool failure

## Do Not Use For

- single-actor stale state with no live concurrent writer; use
  `state-synchronization`
- git conflict mechanics (rebase, merge, force-push) as the main task; route
  the chosen resolution to `worktree-readiness`
- multi-repo sequencing of producer/consumer contracts; use
  `multi-repo-boundaries`
- subagent payload shape; use `handoffs`

## Coordination Rules

- Name the writers before writing. For the surfaces this phase mutates, state
  who else can plausibly write them during the phase: user, other sessions,
  Copilot, council reviewers, bots, scheduled jobs. "Nobody" is a claim that
  needs a reason.
- Partition, don't interleave. When parent and delegate (or two sessions)
  work concurrently, give each an exclusive write surface — disjoint files,
  branches, or thread sets. Read overlap is fine; write overlap is not. If
  exclusive partition is impossible, sequence instead of parallelizing.
- One writer per review target. While a reviewer, Codex helper, Copilot, or
  council pass is evaluating a diff, do not keep editing that diff; parallel
  writes make the review target unstable and the verdict stale on arrival.
- Refresh before every remote write when a race is plausible. Before push, PR
  edit, or thread mutation, read the remote head/thread state; use a fetch only
  through `state-synchronization` when that local git write is allowed. If the
  target moved since evidence was gathered, stop and re-route rather than
  forcing the write through.
- Never resolve a race by force. A rejected push or edit conflict means
  another actor moved first. Select a rebase/rebuild/coordination response
  through `worktree-readiness` and the relevant external workflow; do not
  force-push over, revert, or re-resolve another actor's work merely to restore
  the original plan.
- You are not alone in the worktree. Unexpected dirty files, new commits, or
  changed instructions during a task may be another actor's live work.
  Preserve it, classify it (concurrent actor vs earlier own action vs tool
  failure), and route conflicts through `conflict-resolution` rather than
  cleaning it away.
- Instruction and policy files are high-contention surfaces. Batch narrow
  instruction changes and refresh the relevant local/remote state immediately
  before an authorized commit. Use `worktree-readiness` for any pull,
  merge, rebase, or commit; coordination itself does not perform those writes.
- Record ownership in an already-authorized coordination surface when one
  exists: a route ledger or handoff packet by default, or a PR comment/ticket
  assignment only through its owning external workflow and permission gate. Do
  not create a remote write solely because this lane detected concurrency.
- Evidence gathered before a concurrent mutation is stale for that surface.
  When another actor's write is detected mid-phase, treat it as a phase
  boundary: refresh, re-emit the Classification receipt, and decide whether the plan
  still holds.

## Output

```text
Gate: parallel-work-coordination
Decision: PARTITION | SEQUENCE | JOIN | BLOCKED
- shared surfaces and plausible writers:
- partition: <who owns which write surface, or sequenced order>
- races checked: <fetch/readback evidence before remote writes>
- concurrent changes encountered: <none | classified + preserved>
- allowed side-effect boundary per writer:
- next route:
- re-entry condition:
- Pending Verification:
```
