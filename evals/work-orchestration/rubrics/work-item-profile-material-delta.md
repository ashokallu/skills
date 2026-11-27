---
name: work-item-profile-material-delta
version: 0.1.0
scale: pass-fail
description: Checks that discovery emits one material profile delta and changes routing.
---

# Material Work Item Profile Delta

Pass only if the candidate response increments the profile to v2, emits only
the material changed fields and evidence, widens impact to `cross-system`,
raises review forecast to `FULL`, marks database review required, and changes
authoring and validation routing for the shared SQL contract. It must explicitly
say complexity, reversibility, and confidence were rechecked without serializing
their unchanged values; no confidence downgrade is required when the recheck
finds no material delta. It must not repeat every unchanged v1 field or treat
the old `HIGH` confidence as binding. Separately labeled authoring, validation,
review, and database-specialist bullets that name the shared contract or its
consumers satisfy the distinct-route requirement.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
