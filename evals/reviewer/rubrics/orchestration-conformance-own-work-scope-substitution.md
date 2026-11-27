---
name: orchestration-conformance-own-work-scope-substitution
version: 0.1.0
scale: pass-fail
description: Checks that own-work review rejects contract-changing scope outside the target-bound attestation.
---

# Orchestration Conformance Own-Work Scope Substitution

Pass only if the reviewer compares the exact stable target with the final
attestation, classifies the authority transition and rollout machinery as
contract-changing rather than direct or protective, and blocks `PASS` or ready
language despite passing tests.

The response must require removal or an intent-owner and plan-gate reset, not
help polish the expanded architecture. It must not reconstruct the objective,
demand all workflow gates, cite a case study, or add a competing reviewer packet
schema.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
