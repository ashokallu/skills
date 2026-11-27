<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-17 (bounded authoring pilot) -->

# Case-Study Transfer Preflight

Use this pilot after every triggered mandatory code-authoring case-study
agreement is complete. Its purpose is to convert the agreement into a small,
prospective behavior contract before target evidence can pull the author back
into hurried patch production.

## Pilot Boundary

This reference owns active recall for the `code-authoring` entry
contract. It does not add a timed delay, expose hidden chain of thought, repeat
agreement prose, alter reviewer packet serialization, or activate from an
optional narrative read. Do not copy this pilot into reviewer, database,
wrapper, publication, or root instruction surfaces until focused evaluation
shows better decisions or probes with acceptable visible-message, token, and
latency overhead.

Optional narrative case studies may inform task-time behavior through their
own owning lanes. They do not trigger this preflight, create a commitment row,
or require read provenance, acknowledgement, citation, or closeout narration.

## Evidence Boundary

After all triggered mandatory agreement responses are complete, and before
this authoring session performs its first target-specific evidence action,
complete the Case-study Transfer Preflight.

Allowed before this gate:

- repo boot, skill, lane-routing, and mandatory case-study instruction reads;
- exact mandatory agreement responses;
- worktree creation, readiness preparation, and target identity setup; and
- parent-supplied target, changed-file inventory, or routing inputs.

Parent-supplied target and inventory data remain routing inputs, not evidence,
until the gate completes. Target-specific evidence actions include PR metadata,
diff or code inspection, caller or test inspection, CI or log reads,
validation, browser or data access, edits, and mutations.

If target-specific evidence was inspected prematurely, stop before further
target work, record the ordering violation, complete the preflight without
rewriting it around the evidence already seen, and rerun any downstream audit
whose independence the premature read compromised.

## Beginning: Active Recall

Maximum three commitments total, not three per case study. Use immutable IDs
`C1` through `C3`. Each row must reconstruct the operational lesson in the
agent's own words and make its effect on this task falsifiable:

```text
C1 | operational lesson=<own words> | task risk=<specific failure> | changed decision/probe/stop=<observable action> | self-violation signature=<how this agent could still miss it>
```

Freeze each initial row before target evidence. Execution may attach evidence
or status, but it may not rewrite the lesson, task risk, promised action, or
self-violation signature. A row fails the gate when it is generic advice,
merely paraphrases the agreement, lacks a task-specific risk, lacks an
observable action, or cannot say how this agent could still violate it.

New risks discovered later follow the normal lane, variance, and authoring
handoff contracts. They do not become retroactive case-study commitments.

For an interactive session, emit the beginning rows to the user before target
evidence. For a headless, one-response, or child runtime whose transport cannot
show a pre-evidence update, keep the rows private or parent-facing and enforce
the same ordering internally.

## Middle: Material Rehearsal

Do not repeat the rows after ordinary commands or narrate private reasoning.
Emit one compact update only at a natural phase transition or when the
commitment materially changes a decision, probe, stop condition, or plan:

```text
C1 applied | decision/probe=<changed action> | evidence=<artifact or Pending Verification>
```

If no commitment changes the action, emit no middle update. New evidence that
changes the task's risk or lane map still follows the normal authoring delta
and variance rules even when it is unrelated to `C1`-`C3`.

## Ending: Prospective Reconciliation

Before authoring handoff, reconcile only the IDs frozen at the beginning:

```text
C1 | status=<embodied|deviated-and-corrected|not-reached|Pending Verification> | obstacle/evidence=<artifact> | changed choice or deviation=<observable delta> | correction/outcome=<result>
```

No new commitment IDs are allowed, and the beginning fields remain immutable.
Use `embodied` only when evidence shows the commitment observably changed an
action. Use `deviated-and-corrected` when the agent drifted, identified the
drift, and repaired the affected work and proof. Use `not-reached` when the
anticipated condition or promised probe was legitimately outside the reached
path. Use `Pending Verification` when the evidence needed to disposition the
commitment is missing.

General implementation success is not evidence that a commitment was
embodied. When no observable influence exists, report `not-reached` or
`Pending Verification` rather than manufacturing a successful story. A
material uncorrected deviation blocks the owning authoring phase under the
existing lane and handoff rules.

## Transport Compatibility

Interactive authoring may show the beginning rows, material middle updates,
and ending reconciliation as normal progress or closeout messages. Keep each
surface bounded by the formats above.

For headless or one-response execution, keep the transfer trace private or
parent-facing. Surface only task consequences that the existing consumer
contract already permits. Do not prepend or append the transfer trace to a
strict packet, add packet fields, or weaken a parser-facing first/last-line
contract. The final strict packet remains solely the owning workflow's
canonical payload.

## Pilot Acceptance

Treat this as a behavioral experiment, not proof that active recall already
works. The pilot fails closed when an author:

- inspects target evidence before the beginning rows are frozen;
- supplies generic commitments without task-specific observable actions;
- forgets a commitment at a material phase transition or closeout;
- adds or rewrites a commitment after evidence;
- claims influence without evidence;
- leaks optional narrative provenance or acknowledgement;
- writes transfer text into a strict packet; or
- expands visible narration beyond three beginning rows, material updates, and
  one reconciliation per frozen row.

Expand this contract only after same-model baseline and candidate evidence
shows improved probe or decision quality, zero packet and optional-provenance
failures, and acceptable measured overhead. If baseline behavior is already
equivalent or the rows produce no observable decision changes, do not expand
the policy.
