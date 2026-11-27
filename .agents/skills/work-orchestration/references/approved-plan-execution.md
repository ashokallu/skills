<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (content-bound admission and plan-conformance execution) -->

# Approved Plan Execution

```text
Type: owning lane
Use when: a current accepted plan exists and the user asks to execute, continue, or
          finish it
Skip when: the direction is still proposed, the plan is stale/incomplete, or a
           specialist already owns the complete execution workflow
Owns: plan admission, step-to-phase sequencing, progress tracking, delta detection,
      and evidence-backed completion of the accepted plan
Does not own: re-approving the direction, domain mechanics, hidden scope expansion,
              publication authority, or critical-mutation approval
Allowed side effects: only those authorized for each admitted plan step
Inputs: current content-bound accepted-plan record, critic disposition when required,
        exact target, current state, and acceptance evidence
Exit states: COMPLETE | PARTIAL | BLOCKED | SUPERSEDED | CANCELLED
Outputs: executed steps with evidence, next ready phase, or a precise delta/blocker
Re-enter when: plan, objective, target, authority, risk, dependencies, or acceptance
               changes
```

This lane prevents two common failures: re-running idea challenge for an
unchanged approved direction, and treating plan approval as blanket permission
for every execution side effect.

## Admission

Before executing, consume [plan-acceptance](plan-acceptance.md) when it was
required and verify only what can materially change the route:

- the exact plan body and content identity match the current accepted version;
- explicit approval and any required critic admission bind that same version;
- its objective and target still match the user's request;
- prerequisites and dependency order remain plausible;
- the next step has action-specific authority;
- acceptance evidence is observable;
- no newer state has superseded the plan.

Use bounded reads to resolve these facts. Route to:

- [objective-lock](objective-lock.md) when an owner-controlled contract field is
  missing or changed;
- [idea-challenge](idea-challenge.md) when the direction is merely proposed;
- [state-synchronization](state-synchronization.md) when the target may have
  moved;
- [scope-change-control](scope-change-control.md) when execution reveals a
  material delta.

Use [plan-conformance](plan-conformance.md) as the one evidence schema during
execution. Missing identity, an in-place body change, a critic revision absorbed
without a new accepted version, or a stale plan blocks admission.

Do not ask the user to re-approve an unchanged plan merely because execution is
starting.

## Execute By Phases

Translate the plan into the smallest current phase that has one owner, one
boundary, and one proof. For each step:

1. retain its stable step ID and identify the exact target and next side effect;
2. apply only triggered boundary/specialist gates;
3. delegate only a ready independent unit or required independent judgment;
4. execute through the owning specialist/lane;
5. map implementation evidence and every changed file, meaningful hunk, and
   mechanism to the step or an explicit deviation;
6. check semantic preservation and deletion obligations inside touched files;
7. collect the step's acceptance evidence;
8. mark dependent steps ready only after their prerequisites are proved.

Plan acceptance by itself is not execution authority. A current request to
execute the plan may authorize an action only when the accepted plan
unambiguously binds that action class and target and governing policy permits
it. Newly derived or broadened side effects require their own boundary. In
particular, edit, commit, push, publish, deploy, data mutation, and destructive
cleanup remain separate action classes.

## Delta Handling

Classify new facts once:

- **in-scope detail:** absorb inside the current boundary;
- **correctness expansion:** absorb only if objective, authority, risk, owner,
  and proof remain valid; otherwise split;
- **optional improvement:** defer by default;
- **objective-changing:** freeze affected work and re-lock;
- **conflict/stale plan:** synchronize or resolve conflict before continuing.

Do not silently polish beyond acceptance, and do not restart the entire plan for
an ordinary corrective detail.

A material unapproved file, hunk, mechanism, or semantic deletion freezes the
affected work and routes through `scope-change-control`. An unconditional step
that will be omitted, deferred, reordered, or superseded returns to
`plan-acceptance` for a new user-approved version. Do not mark either case
complete in the progress ledger.

## Progress Record

For a short plan, an ordinary progress update is enough. For long, delegated,
or high-risk execution, keep a compact ledger:

```text
Plan/version and step ID:
Owner / target / boundary:
State: ready | active | complete | partial | blocked | deferred | superseded
Evidence:
Changed surfaces and semantic obligations:
Dependencies / next step:
```

## Exit

Return one of:

- `COMPLETE`: all accepted plan outcomes are proved;
- `PARTIAL`: a useful subset is complete and the smallest remainder is named;
- `BLOCKED`: the next step lacks target, authority, capability, or prerequisite;
- `SUPERSEDED`: a newer objective/plan/target replaced this plan;
- `CANCELLED`: execution was stopped.

The final result distinguishes local changes, validation, git state,
publication, deployment, and live verification.
