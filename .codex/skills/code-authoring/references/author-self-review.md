<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-17 (database applicability prevention gate) -->

# Author Self-Review Delta

## Mission

Catch reviewer-visible defects while the author still has direct knowledge of
the change, before spending an independent reviewer call. This is a final
authoring prevention gate, not a reviewer role, verdict, or replacement for an
independent review.

The completed code-authoring handoff and `authoring-preflight` remain
authoritative for the exact stable target, selected authoring lanes, coverage
and variance ledgers, validation, documentation truth, `Pending Verification`,
and next-action state. This reference records only what changed when the author
applied reviewer lenses to that target.

## Admission And Exclusions

Run this gate once after mandatory authoring closeout and before the first
independently dispatched reviewer when all are true:

- the current agent authored the change;
- the exact target is stable and substantive; and
- an owning workflow requires or the user explicitly requested an independent
  reviewer.

Do not run it for:

- review of a teammate's PR;
- a user-assigned direct review of a local diff, branch, commit, working tree,
  or named files, which the current agent owns through `reviewer`;
- a local-only micro-edit that is eligible to skip authoring closeout and has no
  independent review gate; or
- finding-directed post-review re-review, which uses `authoring-preflight`'s
  strengthened Review-fix proof before the scoped re-review lane and the
  original reviewer's own context.

When excluded, record only `Author self-review: excluded, because <evidence>`
and stop; do not emit the full delta contract below. Do not create this gate
merely to justify optional delegation.

## Reviewer-Lens Delta

Use the current runtime's `reviewer/SKILL.md` only as an eager catalog of
reviewer lenses. Select the lenses triggered by the actual changed surfaces and
read only their preventive references. Turn each selected lens into a concrete
probe that is not already dispositioned by the authoring handoff.

Inspect the exact diff plus the minimum caller, consumer, configuration, test,
generated, documentation, and operator context needed to answer those probes.
Fix actionable issues before dispatch. Do not enter reviewer bootstrap,
analysis, closeout, severity, confidence, deduplication, packet, or verdict
procedures. In particular, do not emit `PASS`, `BLOCKED`, `NEEDS_INPUT`, a
`Verdict:` line, or a canonical or compact review packet.

If every reviewer probe was already dispositioned by the authoring contract,
record `undispositioned reviewer probes: none`; do not restate the proof.

## Conditional Database Delta

Load the parent-owned
`work-orchestration/references/database-review-applicability.md` contract
against the exact target. Carry its complete tri-state packet into this delta;
do not reconstruct a shorter file-type trigger list.

When applicability is `required`, consult `database-reviewer/SKILL.md` and only its
consequence-relevant lanes as prevention and evidence-readiness prompts. Check
whether the authoring artifacts expose the invariants, scale assumptions,
failure behavior, recovery path, and evidence an independent database reviewer
will need. Environment reads remain parent-owned through
`readonly-data-access`; this gate must not autonomously query a database
or environment, issue a database verdict, waive the evidence preflight, or
replace the independent database-reviewer sibling.

When applicability is `not required`, retain the packet's evidenced negative
trace and do not load database-reviewer. `Pending Verification` blocks
database-reviewer dispatch and every later first-push or PR-creation gate until
the parent proves a disposition; it never delays the ordinary reviewer.

## Fix And Recompute Rule

A material self-review fix changes the stable proof contract. Identify the
affected authoring handoff or preflight rows, rerun those rows and any validation
made stale by the fix, and only then recompute this delta against the new exact
target. Do not append a self-review claim to stale authoring evidence.

Mechanical wording or formatting corrections may use focused proof when they
do not change behavior, contracts, validation strategy, or risk. Record why no
authoring row was invalidated.

## Independent Reviewer Isolation

The author self-review delta is author context and must not shape a fresh
independent reviewer. Use a verified fresh-session mechanism that passes zero
inherited author turns and expose only the factual Required Packet from
`work-orchestration/references/reviewer-handoff.md`.

For a Codex native subagent, set `fork_turns="none"` or use a currently
verified zero-history successor. Other runtimes must use their verified
equivalent; a default spawn whose inheritance behavior was not checked is not
proof of isolation.

Isolation covers every reviewer-visible input, not only prompt wording:

- inherited parent conversation or turns;
- attached or generated context files and handoff artifacts;
- tool, browser, terminal, or model session state; and
- any other reviewer-visible input channel.

The factual packet may include the exact target and intent, changed-file
inventory, current validation, required reviewer instructions, and factual
environment evidence. It must not include this delta, selected reviewer lenses,
issue or fix history, preferred files, expected verdict, confidence,
completion labels, or author conclusions.

A new process or agent identity is insufficient when author context is still
inherited. Record the verified isolation mechanism. If zero-history isolation
cannot be proved, mark the invocation `context-contaminated`; its result is
advisory only and cannot satisfy the independent gate. Obtain an isolated
review or keep independent dispatch blocked with `Pending Verification`.

## Delta Output Contract

For an admitted target, record only this compact delta:

```text
Author self-review delta:
- authoring contract: <exact target identity plus completed handoff/preflight artifact>
- admission: <required | excluded, because evidence>
- reviewer lenses selected: <lens plus concrete surface, or none>
- undispositioned reviewer probes: <probe plus evidence/disposition, or none>
- changed dispositions: <none or issue/fix references>
- affected authoring proof rerun: <not needed with reason, or exact rows/artifacts>
- material validation rerun: <not needed with reason, or exact command/artifact>
- database reviewer: <complete applicability packet reference, disposition, evidence-readiness, and phase-gate state>
- reviewer context isolation: <verified mechanism | context-contaminated and Pending Verification>
- independent dispatch allowed: <yes/no, because evidence>
```

Do not copy unchanged coverage, variance, validation, documentation, or
`Pending Verification` ledgers into this delta. Reference the authoritative
authoring artifact and record only new or changed dispositions.
