<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (initial bidirectional plan-to-diff contract) -->

# Plan Conformance

```text
Type: companion contract
Use when: an accepted plan from plan-acceptance governs authoring or own-work review
Skip when: no accepted plan contract was required for the work
Owns: one evidence schema for bidirectional plan-to-implementation reconciliation
Does not own: scope, objective, deviation authority, execution, or reviewer verdict law
Allowed side effects: read-only reconciliation against the exact plan and stable target
Inputs: accepted-plan record, current diff/target, authoring evidence, and scope ledger
Exit states: CONFORMANT | MATERIAL_DEVIATION | INCOMPLETE | BLOCKED
Outputs: step coverage, changed-surface mapping, semantic obligations, and exceptions
Re-enter when: accepted plan, target, diff, evidence, or deviation disposition changes
```

Use this schema once during authoring reconciliation and independently during
own-work review. It is not a new lane or audit owner. The parent ledger is an
input to review, never proof that the diff conforms.

## Bidirectional Coverage

Reconcile both directions:

1. Every approved step maps to implementation evidence and one disposition.
2. Every changed file, meaningful hunk, and mechanism maps to an approved step
   or an explicit deviation.
3. Every preservation and deletion obligation is checked semantically inside
   touched files. File presence, changed-file inventory, or phrase presence
   alone is insufficient.
4. Every unconditional omitted, deferred, or superseded step requires a new
   accepted plan version. A label in the implementation ledger cannot waive it.

Use stable step and surface identities. Group mechanical hunks only when they
share one approved mechanism and proof; do not hide an unrelated behavior
change inside a file-level row.

```text
Plan conformance:
- accepted plan: <stable-id>@v<version> and content identity
- stable target: <target type, immutable identity, ordered changed-file inventory>
- step coverage: <step ID -> evidence -> complete | conditional-not-reached |
  incomplete | superseded-by-new-plan>
- changed surfaces: <file/hunk/mechanism -> step ID | deviation ID>
- preservation/deletion ledger: <obligation -> semantic evidence -> satisfied | failed>
- deviations: <ID -> in-scope detail | correctness expansion | optional improvement |
  objective-changing | conflict/stale plan; authority owner; disposition>
- validation evidence: <step/obligation -> exact proof or Pending Verification>
- exceptions for user: <none or material deviations, incomplete items, blockers>
- result: CONFORMANT | MATERIAL_DEVIATION | INCOMPLETE | BLOCKED
- re-entry: <none | scope-change-control | objective-lock | plan-acceptance |
  state-synchronization | authoring>
```

## Result Rules

- `CONFORMANT`: both directions close, every semantic obligation is satisfied,
  and no material deviation or unconditional incomplete step remains.
- `MATERIAL_DEVIATION`: an unapproved file, hunk, mechanism, deletion, or
  semantic change exists. Freeze affected work and route the delta through
  `scope-change-control`; that gate may return an objective-owned change to
  `objective-lock` or an accepted-plan change to `plan-acceptance`.
- `INCOMPLETE`: an unconditional approved step or proof obligation is missing.
  Return to authoring, or to `plan-acceptance` when the step will be deferred,
  omitted, reordered, or superseded.
- `BLOCKED`: plan identity, target identity, required evidence, authority, or
  deviation disposition is absent, stale, contradictory, or unverifiable.

The companion records evidence only. `scope-change-control` and
`objective-lock` retain deviation authority. An implementer, critic, or
reviewer cannot relabel a material deviation as protective or complete merely
to preserve the current version.

## Consumer Requirements

`approved-plan-execution` maintains step state and freezes on material drift.
Code-authoring intake and preflight build the current ledger against the actual
diff before review. The reviewer reconstructs both mappings from the accepted
plan and stable target, samples grouped mechanical hunks, checks every
semantic preservation/deletion obligation, and rejects a parent ledger that is
unsupported by the diff.

User-facing output is exception-focused: plan/version, result, material
deviations, incomplete steps, blockers, and remaining `Pending Verification`.
Do not transfer routine line-by-line audit work to the user or imply that a
clean result guarantees every future agent will comply.
