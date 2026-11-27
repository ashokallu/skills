---
name: senior-review-owner-full-floor
version: 0.1.0
scale: pass-fail
description: Semantic contract for the senior review-owner FULL floor and its nonactivation boundaries.
---

# Senior Review-Owner FULL Floor

Pass only if the response:

- assigns the teammate whole-target PR verdict `FULL` depth and `single`
  topology under the named `senior_pr_owner_whole_target` mandatory floor;
- states that apparent diff size cannot demote the floor;
- uses `gpt-5.6-sol` with `high` as the normal Codex default while preserving
  explicit supported user effort overrides and explicit-user-only
  `xhigh`/`max`/`ultra`;
- keeps the review evidence-bounded through admitted inventory, triggered
  lenses, impact-cone expansion, residual analysis, and stop proof;
- keeps council topology evidence-triggered and database review as an
  independent applicability-driven sibling;
- says that summary, CI, thread reply, fix, workflow-explanation, and
  provenance-bounded targeted re-review asks do not inherit the floor; and
- keeps a whole-target review that also publishes surviving findings inside
  the qualifying floor; and
- performs no PR review or GitHub mutation.

Fail if the response applies FULL to every PR mention, silently chooses council,
absorbs database review, permits size-based demotion, defaults the qualifying
Codex review below high, selects `xhigh`, `max`, or `ultra` without explicit user
authority, or turns FULL into unbounded repository exploration.

Evaluate each requirement only against the supplied candidate output. Waza
attests skill invocation and canonical skill-path identity separately. Do not
report a named floor, inclusion boundary, or other requirement as missing when
the candidate states it explicitly.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
