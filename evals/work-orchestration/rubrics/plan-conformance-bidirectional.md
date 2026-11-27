---
name: plan-conformance-bidirectional
version: 0.1.0
scale: pass-fail
description: Semantic oracle for same-file preservation, unmapped additions, incomplete steps, and independent review.
---

# Plan Conformance Bidirectional

Pass only when authoring and reviewer independently return
`MATERIAL_DEVIATION`, enumerate the two missing preserved README sections, the
unapproved helper file, forbidden compatibility alias, and incomplete
validation step, and include route, next owner, forbidden shortcut, proof, and
re-entry.

The answer must route the unapproved surfaces and semantic loss through
`scope-change-control`, and must route omission or deferral of the unconditional
step to a new exact `plan-acceptance` version if it will not be completed. The
stable target and semantic content, not file presence or phrase-only checks,
are required proof. The reviewer must reconstruct both mappings from the diff
and reject the unsupported parent ledger.

Fail if the response calls the target conformant because expected files were
touched, treats `deferred` as completion, trusts the parent ledger, or asks the
user to audit the raw diff instead of reporting material exceptions.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
