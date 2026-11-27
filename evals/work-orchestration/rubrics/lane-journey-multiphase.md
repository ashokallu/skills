---
name: lane-journey-multiphase
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for lane journey multiphase.
---

# Lane Journey Multiphase

Pass only if the response makes the current explanation-only route visible,
identifies why that route owns the current phase, names its target,
allowed side effects, exit proof, and expected next owner, and maps the
later authoring, validation, direct local review, and local commit
transitions without pretending those phases executed. It must keep the
parent as narrator, preserve direct local-review ownership, and avoid
emitting a strict reviewer or database-reviewer packet. This self-contained
task requires no target-specific tool action.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
