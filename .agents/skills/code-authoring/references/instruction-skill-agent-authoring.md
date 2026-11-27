<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-18 (requested-artifact semantic fidelity) -->

# Instruction, Skill, And Agent Authoring

Use this lane when changing skills, agent role files, prompts, durable reviewer
or authoring instructions, packet docs, runbooks that agents treat as policy,
TOML role definitions, mirror files across runtimes, or examples that future
agents will follow.

## Mission

Author instructions as executable policy: scoped, non-contradictory, testable by
future agents, and easy to route. Good instruction docs change behavior without
creating bloated checklists, hidden priority conflicts, or impossible promises.

## Boundaries

This lane owns durable instruction content. It does not own final reviewer
verdict law, PR posting mechanics, runtime tool availability, or hidden chain of
thought policy unless the instruction file itself is the correct home. Load
`docs-and-operator-truth` for doc/readme/runbook truth, `existing-conventions`
for local skill shape, and `quality-scout` when auditing broad instruction
coverage before edits.

Do not add runtime-specific claims, model-version assumptions, tool paths, or
workflow mechanics unless they are verified in the target repository and belong
in that layer.

## Authoring Sequence

1. Identify the instruction artifact, runtime(s), caller, trigger, owner,
   priority, and behavior gap it must close.
2. Identify the exact content the owner asked the artifact to preserve and its
   authority state: artifact fidelity, phase or packaging, execution,
   owner-approved behavior, verified fact, advisory proposal, or `Pending
   Verification`.
3. Read adjacent role/skill/reference docs and mirrors before editing. Avoid
   duplicating core law into optional lanes.
4. Classify each addition as routing, evidence requirement, domain footgun,
   validation gate, output discipline, maintenance hygiene, or example.
5. Put rules at the narrowest durable home: core role for verdict/output law,
   skill `SKILL.md` for routing and lane selection, reference lane for domain
   probes, PR workflow for GitHub mechanics, runbook for operator commands.
6. Use active, testable language. Prefer "When X changes, inspect Y and prove
   Z" over vague reminders such as "be careful" or "ensure quality".
7. Include do-not-use and boundary clauses so agents know when not to apply the
   lane.
8. Keep examples short and behavior-changing. Remove or consolidate equivalent
   wording nearby instead of stacking synonyms.
9. Update mirrors, lane maps, summary docs, and links together when routing or
   filenames change.

## Requested Artifact Fidelity

Preserve these authority boundaries when authoring durable skills, agent roles,
prompts, plans, or policy docs:

- a request to preserve a proposal requires accurate recording and decision
  status, not implementation approval;
- naming the current or next phase constrains packaging, but does not select a
  new runtime policy;
- execution authorization applies only to the identified plan under its
  accepted objective and constraints; and
- facts, agent proposals, critic advice, and reviewer advice remain evidence or
  recommendations until the proper owner accepts a behavioral change.

Before handoff, answer in one sentence whether the resulting artifact preserves
the exact requested deliverable. If any accepted behavior was reversed,
removed, deferred, or moved to another phase, cite the owner statement that
authorized that delta. Without that authority, restore the requested artifact
or stop at the unresolved decision; do not make a polished substitute durable.

## Prevention Probes

- Does the instruction conflict with higher-priority system/developer policy,
  local runtime role files, parser packet contracts, or existing lane ownership?
- Could an agent follow the text and know exactly what evidence to collect,
  what action is forbidden, and what to report as `Pending Verification`?
- Does the lane include mission, boundaries, probes, triage/validation, output,
  and edge cases without becoming a standalone agent workflow?
- Does it accidentally require every lane for every task, encourage checklist
  dumping, or make small tasks too expensive?
- Are safety-sensitive instructions explicit about secrets, production writes,
  irreversible operations, and owner/specialist approval boundaries?
- Are examples current, source-backed, and not overfitted to one incident when a
  generalizable rule would be clearer?
- Do cross-runtime mirrors and references still agree after the edit?

## Validation

At minimum, run a Markdown/readability pass and a link/filename sanity check.
For larger changes, test routing with representative scenarios: tiny no-op,
normal implementation, PR-bound handoff, high-risk production data, docs-only,
agent-role edit, and reviewer packet. If mirror updates cannot be made in the
same change, mark mirror parity `Pending Verification` with exact paths.

## Output

```text
Instruction authoring:
- artifact/routing gap: <file/lane and behavior gap>
- requested-artifact proof: <requested content, decision status, preserved location, authority for any delta>
- ownership placement: <core skill/reference/runtime/PR workflow/runbook>
- conflicts/mirrors checked: <paths or Pending Verification>
- validation: <markdown/link/routing checks or Pending Verification>
```
