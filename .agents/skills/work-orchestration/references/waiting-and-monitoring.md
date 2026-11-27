<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-22 (autonomy monitoring and terminal-observation proof) -->

# Waiting And Monitoring

```text
Type: owning lane
Use when: the next phase depends on a state transition the agent does not directly
          control
Skip when: the state can be checked once now, or the operation itself still needs to be
           started
Owns: bounded observation of external progress and the transition when it ends
Does not own: starting/mutating the operation, retrying failures, publication policy, or
              final readiness judgment
Allowed side effects: read-only observation; local process control only for a process
                      the current workflow owns
Inputs: exact watched target, current state, observer capability, terminal states,
        cadence/budget, and continuation owner
Exit states: terminal-success, terminal-failure, changed-target, timed-out, parked,
             handed-off, blocked
Outputs: observed state, evidence, and next owner
Re-enter when: terminal state, target, budget, or continuation capability changes
```

Use for CI, reviewer/Copilot state, council output, long local commands, deploy
propagation, queue drains, external ticket state, or another worker’s in-flight
result. Owning specialist rules override this general contract; PR publication
waits belong to the publication lane inside `pr-workflow`.

An active ordinary or database review uses `reviewer-handoff` with the
`review-control-plane` companion before this generic lane. Its pull-based
`REVIEW_PROGRESS:` response, semantic-ownership boundary, and closure proof
override the generic progress packet below. Do not substitute polling, a
generic progress summary, or parallel parent semantic review.

## Capability Gate

Before promising continued monitoring, verify whether the runtime can:

- remain active for the required interval;
- perform the next observation at the declared time;
- receive a delegated watcher result;
- resume/wake without a new user turn;
- safely keep or background a local process.

Use `runtime-capability-check` when uncertain. A sleeping shell, detached
process, scheduled timer, or background worker does not automatically wake the
parent. Never tell the user monitoring will continue unless a verified owner
will consume and report the next result.

For an active task autonomy envelope, the selected observation mode must remain
inside its monitoring ceiling. `READY FOR AUTOPILOT` is unavailable when a
required terminal observation depends on wake/resume capability that is
unknown or unsupported. A bounded foreground wait may continue only within its
declared budget; otherwise stop at a named checkpoint, park, hand off to an
accepted owner, or block. Starting a background process is not terminal
observation proof.

## Wait Contract

Before the first poll or blocking wait, define:

```text
Gate: <operation and state required>
Target and operation ID:
Expected states:
Terminal success/failure/judgment states:
Evidence source and check method:
Observation cadence/backoff:
Budget and stop condition:
Watcher: parent | verified child | external owner | parked
Independent parent work: <bounded and non-overlapping, or none with reason>
On terminal state: <next owner and required state refresh>
```

The budget may be a timeout, poll count, workflow deadline, or current-turn
foreground boundary. It is a stop condition, not an estimate promised to the
user.

## Choose An Observation Mode

- **Bounded foreground:** use when the current call can block or poll and return
  within the declared budget.
- **Delegated watcher:** use only after `delegation` and runtime capability
  checks prove a net-positive, read-only watcher with a join path.
- **Parked:** return current state, exact re-entry condition, and check method
  when autonomous resume is unavailable or the observation budget is exhausted.
- **Handoff:** transfer only when a named recipient accepts target, latest
  state, next check, and terminal reporting responsibility.

Do not duplicate a delegated watch with parent polling. Do not create a tangent
merely to stay busy.

Before selecting independent parent work, scan only the already identified routing
ledger for ready, non-overlapping work whose result does not assume the wait
outcome. Do not start fresh discovery or manufacture a tangent merely to stay
busy.

## Observation Rules

- Every observation reads the actual gate-owning surface. Adjacent logs,
  metrics, another branch, or another environment are supporting evidence, not
  substitutes.
- Never busy-poll. Use a cadence appropriate to the system and back off when no
  useful state can change quickly.
- Waiting is not proof. Read terminal state before any dependent claim.
- If the target/head/run changes, stop and route through
  `state-synchronization`; do not keep watching the obsolete operation.
- If the operation fails, route to the owning recovery/diagnosis workflow. Do
  not turn a wait into an unbounded retry loop.
- When the budget expires, make one final observation, then either report a
  terminal state or explicitly park/transfer the non-terminal obligation. Return
  the exact current state and `Pending Verification`. Do not ask “how long should
  I keep watching?” unless the user must choose between materially different
  operational costs; otherwise provide the re-entry condition.
- A continuation packet is parking evidence, not active monitoring. Do not
  promise a future check or say monitoring continues unless the runtime has a
  proven wake or recurring-monitoring mechanism that this session will consume,
  or an accepted external owner will perform and report it.
- Long local commands should have a timeout, output location, completion check,
  and abort cleanup. Background only when the current workflow can later consume
  the result.
- A new user message is a route boundary. Preserve or transfer the active wait
  obligation before spending substantial effort on an unrelated task.
- Terminal notification outranks optional side work. Consume and report the
  terminal result at the next safe boundary.

## Progress Packets

For operations with meaningful progress, each reported sample should contain
only what changed:

```text
Phase/state:
Completed/total or latest checkpoint:
Change since prior observation:
Anomaly or timeout risk:
Next observation/re-entry condition:
```

Do not infer workflow phases from telemetry labels without verifying the
producer contract.

## Active Obligation Ledger

Record non-terminal operations with:

- operation and target ID;
- start/as-of time;
- latest observed state;
- next check condition;
- terminal method;
- current owner;
- timeout/park condition.

Remove an obligation only after terminal evidence is consumed, the operation is
cancelled, or an accepted handoff transfers ownership. Before final closeout,
the ledger must be empty or every remaining item must be explicitly parked or
transferred.

## After The Wait

A terminal observation is a phase boundary. Refresh drift-prone state before a
mutation or claim; CI, comments, commits, deployment state, or review threads
may have changed while waiting.

## Output

```text
Wait outcome: TERMINAL SUCCESS | TERMINAL FAILURE | TARGET CHANGED | TIMED OUT |
              PARKED | HANDED OFF | BLOCKED
Target and observed state:
Evidence:
Observation mode and budget used:
Continuation owner: <none unless verified runtime watcher or accepted handoff>
Active obligations remaining:
State refresh required:
Next owner / re-entry condition:
Pending Verification:
```
