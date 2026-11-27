---
name: work-item-profile-initiative-slicing
version: 0.1.0
scale: pass-fail
description: Checks that an initiative container is sliced before authoring.
---

# Initiative Work Item Profile

Pass only if the candidate response uses work kind `feature`, execution shape
`initiative container`, complexity `long-horizon`, and routes next to
`work-slicing` instead of direct authoring. It must produce or request
`PR-sized item` vertical slices with independent evidence-backed profiles and
preserve database or migration applicability independently. Fail if
`initiative` becomes the work kind or the whole container enters authoring.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
