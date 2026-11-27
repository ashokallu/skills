<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-19 (initiative-container profile boundary) -->

# Work Slicing

```text
Type: decision gate
Use when: accepted work mixes phases/owners or cannot be reviewed and completed
          coherently as one unit
Skip when: one owner can complete and prove one coherent outcome
Owns: decomposition of an accepted broad initiative into reviewable outcome slices,
      owners, dependencies, proof, and joins
Does not own: code-level implementation planning already owned by `code-authoring`
Allowed side effects: read-only planning
Inputs: accepted objective, scope, constraints, affected systems/repos, and acceptance
Exit states: sliced, keep unified, needs owner, blocked
Outputs: ordered phase/slice ledger and first owner
Re-enter when: objective, dependencies, owners, or publication boundaries change
```

Use this lane when a broad request, initiative, migration, cleanup, multi-owner
issue, or vague "improve/fix everything" prompt needs to become small,
reviewable phases before implementation starts.

This lane creates phase boundaries and owner routing. It does not author code;
code slices route to `code-authoring` after the slice is chosen. The
boundary with that skill's plan-to-slices lane: this lane sequences
mixed-phase, multi-owner work (discovery, code, docs, publication, rollout,
follow-up); `code-authoring` plan-to-slices slices a single code
initiative into implementation slices once a phase is known to be code-only.

## Use For

- broad initiatives that could become multiple PRs or branch stacks
- migrations, cleanups, dependency upgrades, auth/data/infra changes, or UX/API
  changes with compatibility windows
- requests that mix discovery, implementation, docs, validation, publication,
  release, and follow-up work
- deciding whether work should be one PR, stacked PRs, separate docs, a runbook,
  a no-code operational change, or a later roadmap item
- stopping scope creep by naming non-goals and follow-up candidates

## Do Not Use For

- tiny tasks or a single obvious edit
- code implementation details; use `code-authoring`
- generic project management outside example-app repo work
- bypassing `idea-challenge` when the user-proposed direction itself needs
  pressure testing

## Slicing Principles

- A Work Item Profile with `execution shape: initiative container` cannot
  route directly to authoring. This lane must first produce one or more
  independently reviewable `PR-sized item` slices. Each selected slice gets
  its own profile evidence and does not inherit a friendly complexity or review
  forecast from the container.

- Slice by reviewable value, not by agent convenience. Each slice should leave
  the repo safer or more understandable.
- Prefer vertical compatibility slices over broad mechanical churn.
- Keep behavior changes, generated artifacts, migrations, docs, and rollout
  notes together only when reviewers need them together to verify correctness.
- Separate risky one-way changes from safe preparatory work.
- Do not bundle unrelated cleanup with a bug fix, incident fix, auth/data
  change, or dependency upgrade.
- Make each slice independently validatable where practical.
- List follow-ups as follow-ups, not hidden obligations of the current slice.

## Slice Packet

For each candidate slice, define:

```text
Slice:
- outcome:
- owner route:
- in scope:
- out of scope:
- side effects:
- risk:
- critical path: yes/no + owner
- ready when:
- can run with:
- exclusive write owner:
- join artifact and consumer:
- validation:
- reviewer focus:
- depends on:
- can ship alone: yes/no + why
```

## Output

```text
Work slicing decision: SLICED | KEEP UNIFIED | NEEDS OWNER | BLOCKED
- source profile and execution shape:
- initiative completion condition:
- ordered slice ledger: <slice -> owner -> dependency -> join -> ship boundary>
- selected slice profile:
- recommended slice now:
- deferred slices:
- rejected bundling:
- selected next route and owner:
- review/validation proof:
- join/initiative completion rule:
- re-entry condition:
- Pending Verification:
```
