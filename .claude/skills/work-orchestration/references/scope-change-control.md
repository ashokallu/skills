<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (plan-changing delta route) -->

# Scope Change Control

```text
Type: decision gate
Use when: after a phase starts, a new request or finding materially changes files,
          consumers, acceptance, side effects, risk, effort, or owner
Skip when: execution has not started or the fact is an ordinary detail already covered
           by the current objective and boundary
Owns: disposition of a material scope delta after work has started
Does not own: initial intake, objective authorization, implementation, or review
Allowed side effects: read-only classification
Inputs: current phase contract, new fact/request, current authority, and proof
Exit states: proceed, split, defer, re-plan, re-lock, ask, stop
Outputs: one scope disposition and next owner
Re-enter when: another material delta appears or the chosen disposition is resolved
```

Use this gate only after a phase has started. It prevents two opposite failures:
silently expanding the task, or restarting the whole orchestration workflow for
an ordinary in-scope detail.

## Trigger

Enter when any of these occurs after a phase has begun and the delta is material:

- the user adds or changes a requirement;
- discovery reveals another affected consumer, repository, API, schema,
  generated artifact, migration, test surface, or operator step;
- a proposed fix needs broader permissions or side effects than declared;
- validation or review exposes a correctness requirement outside the current
  file list;
- execution shape, dependency load, or ownership changes materially;
- an optional improvement appears while solving the required problem.

Do not enter for a minor implementation detail already implied by the accepted
objective and proof. A derived-count or summary correction is also not a scope
delta when the exact authoritative resource/action enumeration remains
unchanged and unambiguous.

Do not enter for initial ambiguity; use `request-intake`. Do not use this gate
to slice an already-known broad initiative; use `work-slicing`. When the new
request is a tangent that pauses the active objective, use
`task-suspension-checkpoint`. This gate may hand an objective-changing delta to
`objective-lock`; objective lock owns the new version and must not return the
same unchanged delta here.

## Classify The Delta

Choose exactly one class:

1. **In-scope detail** — a necessary implementation detail that does not change
   the outcome, consumers, side-effect boundary, or acceptance criteria.
2. **Correctness expansion** — additional work is necessary for the accepted
   outcome to be correct, compatible, safe, or testable.
3. **Optional follow-up** — useful improvement that is not required for the
   accepted outcome.
4. **Plan-changing** — preserves the locked objective but materially changes an
   accepted step, target, mechanism, owner, proof, risk, side effect,
   preservation/deletion obligation, or ordering.
5. **Objective-changing** — changes product behavior, authority, ownership,
   production defaults, fallback semantics, or the primary deliverable.
6. **Conflicting** — contradicts a locked objective, explicit non-goal,
   authorization boundary, or another governing instruction.

## Disposition Rules

- **In-scope detail → absorb.** Update the active work item and proof surface.
  Do not reopen intake or idea challenge.
- **Correctness expansion → absorb or split.** Absorb when bounded, same-owner,
  and within the approved side-effect/risk ceiling. Split when it adds a new
  owner, repository, publication unit, migration, production action, or
  independently reviewable outcome.
- **Optional follow-up → defer by default.** Record a concise follow-up with its
  value and evidence. Do not implement it unless the user or owning plan adds it
  to scope.
- **Plan-changing → re-plan.** Route to `plan-acceptance` for a new exact
  user-approved version, then return to critic only when independently required.
- **Objective-changing → re-lock.** Route to `objective-lock`; run
  `idea-challenge` again only for the changed direction.
- **Conflicting → stop the affected work.** Route to `conflict-resolution` or
  ask the exact owner question when evidence cannot decide.

A correctness expansion may proceed without a user question when it is the
smallest reversible action needed to satisfy the already-approved outcome and
stays within permission. State the expansion before acting when it materially
changes time, files, risk, or review surface.

When a task autonomy envelope is active for qualifying critical actions, apply
its fieldwise comparator before the normal disposition. Any higher environment,
read sensitivity, write/execute, cost/resource, destructiveness, rollback
burden, or monitoring dependency, or any new principal or critical resource,
stops before that action and returns to the parent dispatcher for version
`vN+1` in `PRELIMINARY`. Scope control cannot absorb an upward delta merely
because it is a correctness expansion. A narrowing may remain in the current
version when the objective, phase authority, and remaining gates still hold.
New non-qualifying collaboration in the same task remains outside the packet
and uses its owning route; do not expand the envelope merely because the task
also contains a critical action.

Predeclared bounded recovery is an in-scope detail, not an envelope delta, only
when it uses an already-authorized critical action class and exact resource
set, stays inside every approved ceiling, follows critical-state readback,
preserves action semantics, and satisfies the recovery contract in
[autonomy-envelope](autonomy-envelope.md). The first failed attempt plus one changed-variable retry
is the limit. A new target/resource/principal/environment, changed action
semantic or credential, new network/tool/cost effect, second failure, or
unknown partial external state returns to the dispatcher for `vN+1` or
`BLOCKED`. Ordinary Git recovery remains outside the autonomy envelope and
uses `worktree-readiness`.

## Scope Delta Packet

```text
Gate: scope-change-control
Decision: ABSORB | SPLIT | DEFER | RE-PLAN | RE-LOCK | ASK | STOP
Source: user request | discovery | validation | review | external state
Class: in-scope detail | correctness expansion | optional follow-up |
       plan-changing | objective-changing | conflicting
Changes: <objective/target/files/consumers/acceptance/side effects/risk/owner>
Disposition: absorb | split | defer | re-plan | re-lock | ask owner | stop
Reason:
Updated proof:
Allowed boundary:
Next owner:
Re-entry condition:
Pending Verification:
```

## Anti-Loop Rules

- Do not send the same unchanged delta repeatedly through intake, objective
  lock, idea challenge, and scope control.
- Do not call optional cleanup “required for completeness” without tying it to
  an acceptance criterion or concrete risk.
- Do not keep a stale file list after a verified correctness expansion; update
  review and validation scope immediately.
- Do not let a deferred follow-up contaminate completion claims for the accepted
  objective.
- A new user priority can supersede the active objective; use
  `task-suspension-checkpoint`, `abort-and-unwind`, or `request-intake` as
  appropriate rather than hiding the priority change inside scope control.

## Output

Return the `Scope delta` packet above with one disposition, one next owner, and
any updated proof or permission boundary. Re-enter the dispatcher before the
next substantive action when the disposition changes owner, side effects, risk,
or objective.
