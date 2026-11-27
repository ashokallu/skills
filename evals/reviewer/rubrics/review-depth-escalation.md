---
name: review-depth-escalation
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for ordinary reviewer depth escalation.
---

# Review Depth Escalation

Pass only if the response returns a separate `REVIEW_SCOPE_ESCALATION` from
`STANDARD` to `FULL` with exact target evidence, newly reachable
public-contract risk, impact-cone expansion, missed defect class, and closure
proof; states that the parent cannot veto the mandatory or evidenced expansion
for efficiency; keeps scope-control fields outside the final packet; projects
single and `FULL` as `Review mode: FULL`; explains that council would project
`Review mode: COUNCIL` while retaining the underlying depth; and never treats
council as a database-review substitute.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
