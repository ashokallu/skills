<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (shared temporary-resource lifecycle contract) -->

# Resource Lifecycle

```text
Type: companion contract
Use when: an owning lane or specialist will create or adopt a temporary resource
Skip when: the phase creates or adopts no temporary resource
Owns: the shared lifecycle record shape and cross-resource invariants for ownership, retention, cleanup, and residual-state reporting
Does not own: resource-specific creation, retention duration, cleanup method,
              permission, or execution; the owning domain lane or specialist retains
              those decisions
Allowed side effects: none by itself
Inputs: active phase boundary and proposed resource
Exit states: lifecycle recorded | cleanup blocked | residual state reported
Outputs: a lifecycle record consumed and executed by the owning lane or specialist
Re-enter when: resource identity, owner, retention need, cleanup authority, or residual
               state changes
```

Use this companion for temporary files, reports, worktrees, processes, browser
profiles, containers, test data, credentials, locks, or remote fixtures. It
standardizes the record and the invariants around the resource. It does not
replace repository-, tool-, environment-, or domain-specific creation,
retention, cleanup, permission, or verification rules.

## Lifecycle Record

```text
Resource lifecycle:
- resource and purpose:
- exact location or remote target:
- creating or adopting owner:
- ownership proof or marker:
- creation side effects and authority:
- retention need and owning-policy source:
- cleanup trigger, authority, and owning-policy source:
- terminal cleanup or intentional-retention evidence:
- residual state, risk, and next owner:
- Pending Verification:
```

The owning lane or specialist fills the record before creation or adoption,
updates it when lifecycle facts change, and owns the resulting action and
evidence.

## Cross-Resource Invariants

- Create or adopt only the smallest resource permitted by the already
  authorized owning phase.
- Use a unique, task-scoped identity when collisions, cross-run confusion, or
  accidental cleanup are possible.
- Never infer ownership of a pre-existing resource. Treat it as owned only when
  the current run created it or an authorized owner explicitly adopted it with
  evidence.
- Cleanup may target only resources proved to be created or adopted by the
  current run. Ownership uncertainty blocks cleanup and requires a handoff.
- Do not follow symlinks, hardlinks, mounts, archive traversal, redirects, or
  equivalent indirection outside the authorized root or target.
- Keep secrets out of resource names, paths, logs, lifecycle records, and
  retained artifacts. Defer credential handling and disposal details to the
  owning security or domain contract.
- Record any process started by the phase and its continuation owner. Whether
  and how it stops remains an owning-lane decision; do not invent a generic
  stop or retention duration here.
- Classify cleanup as its own action with its own target, side-effect,
  authority, and proof boundary. Creation authority does not imply cleanup
  authority.
- When cleanup is unauthorized, unsafe, incomplete, or impossible, report the
  exact residual resource, last proven owner, current risk, and next retirement
  action. Do not claim a clean terminal state.

## Behavior Contract

| Situation | Required outcome |
| --- | --- |
| Temporary resource created | Record the exact identity, owner, applicable domain policy, cleanup boundary, and terminal proof. |
| No temporary resource created | Do not activate this companion or manufacture a lifecycle record. |
| Cleanup ownership uncertain | Preserve the resource, mark cleanup blocked, and hand off the exact ownership evidence needed. |
| Cleanup remains incomplete | Report residual state, risk, and next owner without claiming completion. |
