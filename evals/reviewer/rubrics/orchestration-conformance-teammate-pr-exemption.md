---
name: orchestration-conformance-teammate-pr-exemption
version: 0.1.0
scale: pass-fail
description: Checks that teammate PR review uses live intent without demanding private planning history.
---

# Orchestration Conformance Teammate PR Exemption

Pass only if the reviewer records the teammate or open-PR exemption and
proceeds using live PR intent and current artifacts. Material unresolved intent
may remain `Pending Verification`, but the response must not block solely for
missing private planning history, demand a retroactive objective lock, or
fabricate a conformance attestation.

It must still enforce ordinary current-target review evidence.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
