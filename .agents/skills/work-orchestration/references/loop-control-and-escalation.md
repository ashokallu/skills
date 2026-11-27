<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (initial loop control and escalation lane) -->

# Loop Control And Escalation

```text
Type: decision gate
Use when: repeated attempts, route oscillation, waits, or delegation add no narrowing
          evidence
Skip when: new evidence materially narrows the problem and the next attempt is distinct
Owns: stopping non-progress loops and selecting one materially different tactic,
      reroute, question, handoff, or blocked state
Does not own: another identical retry or reviewer/agent shopping
Allowed side effects: read-only comparison of attempt history and state
Inputs: attempt history, evidence gained, budget, current owner, and unresolved blocker
Exit states: changed tactic, rerouted, ask, handoff, blocked
Outputs: progress test, forbidden repeat, next attempt, and stop condition
Re-enter when: genuinely new evidence or authority arrives
```

Use this lane when work is no longer narrowing toward evidence, a fix, a route,
or a safe decision. An initial failure followed by one changed-variable retry
with a materially identical outcome is sufficient activation; a third variant
is not required. It prevents agents from burning time by retrying the same
command, rereading the same area, reloading adjacent lanes, polling without a
stop condition, asking broad questions, or spawning more agents to hide an
unclear plan.

This lane does not diagnose the product by itself. It decides whether the next
move is a different tactic, a narrower route, a targeted user question, a
handoff, or a blocked report.

## Use For

- two materially identical command, test, lookup, search, tool, or subagent
  attempts fail or return no new narrowing evidence
- one complete execution-recovery retry changes a named variable and falsifier
  but reproduces the same failure class and locus, leaving retry budget `0`
- route oscillation: the agent keeps bouncing among intake, conflict, risk,
  source, validation, diagnosis, review, or specialist lanes without a new fact
- a plan expands into unrelated cleanup, extra review cycles, repeated council
  asks, broad scanning, or speculative implementation without moving acceptance
  evidence forward
- repeated flaky validation, CI reruns, or local environment repair attempts
  cannot distinguish product failure from setup/tooling failure
- external waiting or monitoring lacks a terminal stop condition, owner, or
  maximum poll scope
- delegated output is repeatedly stale, malformed, uncited, or outside scope
- the current owner cannot perform the needed action but has not yet produced a
  compact handoff or blocked state

## Do Not Use For

- the first ordinary failure of a command, wrapper, credential, or tool; classify
  that through `execution-recovery-and-tool-failures` first
- known product diagnosis that is still producing new evidence; use `diagnose`
- a properly bounded wait with a terminal stop condition; use
  `waiting-and-monitoring`
- a user stop/cancel/undo request; use `abort-and-unwind`
- broad initiative planning before a direction exists; use `request-intake`,
  `objective-lock`, `idea-challenge`, or `work-slicing` first as applicable

## Progress Test

Before another retry, ask all five questions:

1. What exact acceptance or safety claim is the current step trying to prove?
2. What new fact did the last attempt add?
3. What variable will change on the next attempt: target, command, environment,
   evidence source, owner, input data, reproduction path, or hypothesis?
4. What stop condition will end the next attempt even if it fails?
5. Who consumes the next result, and what decision does it unblock?

If any answer is missing, do not retry yet. Re-scope, re-route, ask one targeted
question, or report `BLOCKED`.

When execution recovery already spent its one changed-variable retry and the
failure class and locus are materially identical, this lane must choose
`REROUTE`, `ASK`, `HANDOFF`, or `BLOCKED`. `CONTINUE_DIFFERENT_TACTIC` becomes
available again only after new diagnosis or implementation evidence changes the
hypothesis, not merely because another variable can be named.

## Anti-Loop Rules

- Never run the same command or search again with the same target and inputs just
  because the previous result was inconvenient or empty.
- Do not broaden from a narrow failure to "check everything". Broaden only to
  the smallest adjacent surface that can falsify the current hypothesis.
- Do not add another reviewer, critic, scout, or council when the missing item is
  a target, permission, environment, exact command, or owner decision.
- Do not keep editing after validation shows a different class of failure; route
  the failure class first.
- Do not hide a stuck state behind optimistic language such as "almost done",
  "should be fine", "likely fixed", or "just needs CI".
- Do not keep polling external systems after the wait contract's terminal state,
  max attempts, or ownership transfer condition has been reached.

## Decision Options

Choose exactly one next move:

- `CONTINUE_DIFFERENT_TACTIC`: one bounded attempt with a changed variable and a
  named stop condition
- `REROUTE`: the failure belongs to another lane or specialist
- `ASK`: one targeted question blocks safety or correctness and cannot be
  discovered cheaply
- `HANDOFF`: another owner has the capability, authority, or context; produce a
  compact handoff
- `BLOCKED`: no safe next action remains under the current permission, tools, or
  evidence

## Output

```markdown
## Loop Control Decision
- Current claim or objective:
- Attempts already made:
  - <attempt>: target/input/result/new evidence
- Loop signal: <retry | route oscillation | stale delegation | wait without stop | scope creep | no narrowing>
- Missing blocker: <target | permission | current state | environment | owner | evidence | command | other>
- Retry budget on entry: 0 | not applicable
- Decision: CONTINUE_DIFFERENT_TACTIC | REROUTE | ASK | HANDOFF | BLOCKED
- Next move: <one concrete action, owner, changed variable, and stop condition>
- What not to repeat:
- Pending Verification:
```

After this lane emits a decision, re-enter the dispatcher for the next owner.
Do not reload this lane again unless a new loop signal appears after the changed
tactic has been attempted.
