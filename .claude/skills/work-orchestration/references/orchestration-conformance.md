<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-12 (decision-focused attestation without source inventories) -->

# Orchestration Conformance

```text
Type: companion contract
Use when: parent-authored substantive work is about to enter a pre-code critic,
          meaningful authoring, or an independently dispatched own-work reviewer
Skip when: reviewing a teammate or external open PR from current public artifacts
Owns: one current-session attestation that parent orchestration completed every
      decision-bearing safety gate triggered before critic, authoring, or own-work review
Does not own: gate activation decisions, objectives, implementation, verdicts,
              accepted-plan identity, stable-target identity, or teammate PR history
Allowed side effects: bounded read-only checks of governing and current artifacts
Inputs: target, current intent/acceptance, material gate outcomes, scope decisions,
        authority, consultation state, and instruction freshness
Exit states: ready | pending | invalidated
Outputs: one decision-focused, target-bound orchestration conformance attestation
Re-enter when: a decision-bearing instruction, objective, target, gate result,
               consultation state, or scope changes
```

Use this contract when parent-authored substantive work will enter a pre-code
critic, meaningful authoring, or an independently dispatched own-work reviewer.
It prevents a parent from skipping `objective-lock`, `forward-analysis`,
`scope-change-control`, or another triggered safety gate and asking a later
role to reconstruct the missing decision.

This is admission control, not a new gate or a source-provenance ceremony. The
parent attests the current decision state. Critics, authors, and reviewers check
the decision-bearing evidence they need; they do not demand an exhaustive
instruction recital.

Do not require this attestation for review of a teammate or existing open PR.
Use the live PR body and current artifacts as stated intent, keep material gaps
`Pending Verification`, and never demand the author's private planning history.

## Current-Instruction Attestation

Before the first attestation in a parent session, read the current root
instructions, repository guide, dispatcher, this companion, and each triggered
decision owner. Record the owners consulted by stable role or lane name. Do not
serialize governing-source paths, file digests, source hashes, timestamps, or a
full instruction inventory in the attestation or a critic/reviewer handoff.

The parent refreshes the attestation after a known decision-bearing instruction
change. A new critic or reviewer reads or spot-checks only the current owners
whose rules can change its verdict. It does not reproduce the parent's complete
read set.

Source freshness and attestation reuse are separate:

- unchanged same-session reads may be reused;
- a known decision-bearing instruction change requires rereading that owner and
  refreshing affected decisions before the next transition;
- an unchanged instruction set does not preserve an attestation after a material
  objective, target, classification, gate result, consultation, or scope change;
- a new critic or reviewer session performs its own verdict-bearing spot checks;
  and
- `HEAD`, a timestamp, a prior attestation, or a content hash alone never proves
  that the current decision is correct.

## Attestation Contract

The parent owns attestation creation and versioning. Use one stable action-item
ID and a positive version:

```text
Orchestration conformance attestation:
- attestation: <stable-action-item-id>@v<positive-integer>
- status: ready | pending | invalidated
- current-instruction check: <current session; refreshed owners when changed>
- governing decision owners consulted: <role/lane names only>
- classification: <current complete classification receipt or stable reference>
- objective and intent: <not required with evidence | lock ID/version | pending>
- forward analysis: <not triggered with evidence | record ID/version | blocked>
- critic consultation: <not required | lineage, candidate revision, contact ordinal,
  prior material dispositions, terminal disposition>
- plan acceptance: <not triggered | accepted plan ID/version and approval evidence | blocked>
- scope changes: <none | material deltas and dispositions | blocked>
- target binding: <candidate revision | final exact target and changed-file inventory>
- unresolved decision-changing gaps / Pending Verification: <items and effect>
- next action allowed: <critic evaluation | plan acceptance | meaningful edits |
  reviewer dispatch | no>
```

Each triggered decision names one useful evidence pointer. Do not expand the
attestation into an all-gates checklist, exhaustive file list, governing-source
identity inventory, case-study recital, or narrative workflow history.

The critic consultation state is intentionally small: lineage ID, candidate
revision, contact ordinal, and the disposition of each prior material finding.
A finding disposition is `resolved`, `rejected with current evidence`,
`routed to accountable owner`, or `still blocking`. Accepted-plan content
identity and final stable-target identity remain owned by their canonical
contracts and must not be weakened merely because governing-source hashes are
forbidden.

## Versioning And Invalidation

Increment the attestation version when a decision-bearing field changes:

- objective, acceptance criteria, protected invariant, or non-goal;
- candidate revision, critic contact ordinal, finding disposition, or terminal
  critic verdict;
- target or ordered changed-file inventory;
- classification, side-effect boundary, risk, or owner;
- triggered-gate set or result;
- accepted-plan body/version/approval;
- material scope delta; or
- final stable-target identity.

A representation-only correction may preserve the version when no authority,
target, result, or decision changes. Preserve prior accepted-plan and final
target identities under their existing contracts.

## Consumer Enforcement

### Pre-Code Critic

The critic checks the objective, authority, scope, current evidence, candidate
revision, risks, rollback/detection, verification proof, and unresolved
decision-changing gaps. It evaluates every merit that the available semantics
support even when a heading is missing or mislabeled.

A presentation or transport defect is non-blocking when the needed semantics
are available elsewhere in the brief. A substantive contradiction or missing
objective, authority, safety, ownership, rollback, or verification input may
require revision or blocking. Batch the smallest decision-changing evidence
requests into the current response; do not reject the whole consultation before
merits or request governing-source paths and hashes.

### Authoring

`change-intake` consumes the terminal critic state and any independently
triggered accepted plan before meaningful edits. `authoring-preflight` later
reconciles the attestation against the exact stable diff, accepted finding
dispositions, and material scope changes. Material drift increments the version
or invalidates the attestation before reviewer dispatch.

When plan acceptance activated, authoring continues to use
[plan-conformance](plan-conformance.md) for bidirectional step/surface and
semantic preservation/deletion evidence. The attestation references that
result; it does not duplicate its schema.

### Own-Work Reviewer

The reviewer independently compares the exact pinned target with the final
target-bound attestation. Missing or contradictory decision provenance blocks a
ready/pass verdict only when it can change scope, safety, authority, or
correctness. A missing governing-source inventory, optional heading, or hash is
not a blocker.

Classify added mechanisms as `direct`, `protective`, `contract-changing`,
or `unrelated`. Contract-changing scope returns to the intent owner;
unsupported scope is removed, deferred, or causes a plan reset. Reviewer advice
must not help perfect speculative architecture merely because it exists.

## Acceptance

The attestation is ready only when:

- current decision-bearing instruction owners were consulted;
- every triggered gate has a current result and one useful evidence pointer;
- `not required` decisions include evidence;
- critic consultation has a terminal disposition when required;
- no material scope delta is unclassified;
- accepted-plan and final-target identities are present when their owners
  require them;
- blockers and `Pending Verification` have honest impact; and
- `next action allowed` names exactly one transition or `no`.

Missing decision-bearing conformance cannot be laundered through critic
approval, reviewer thoroughness, passing tests, or an internally coherent diff.
Conversely, cosmetic packet shape and governing-source inventory ceremony cannot
block substantive evaluation.
