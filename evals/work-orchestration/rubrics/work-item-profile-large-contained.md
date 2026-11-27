---
name: work-item-profile-large-contained
version: 0.1.0
scale: pass-fail
description: Checks that file count alone raises neither complexity nor runtime impact.
---

# Large Contained Work Item Profile

Pass only if the candidate response keeps complexity independent from impact
and uses `standard` for this fixture. The supplied evidence proves repetitive
private test-only edits, one owner, unchanged behavior, and no runtime or
cross-package consumers; file/test count supplies no non-local reasoning,
concurrency, state-transition, multi-contract, multi-owner, or coordination
evidence for `complex`. Impact scope must stay `contained` or `component` and
reversibility must stay `easy`. Review forecast should be `STANDARD`, not
`LITE` and not unsupported `FULL` solely because of file count, with focused or
standard package validation. It must cite the proved private test-only boundary
and preserve the reviewer's right to widen mode if the actual diff reveals
runtime consumers. Fail if file count inflates complexity or size and impact
collapse into one label.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
