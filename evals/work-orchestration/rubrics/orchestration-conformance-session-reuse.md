---
name: orchestration-conformance-session-reuse
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for current-instruction and attestation reuse.
---

# Orchestration Conformance Session Reuse

Pass only if the response allows reuse of the same-session attestation for the
completely unchanged first resubmission without a second recital. After the
decision-bearing instruction change it must reject `HEAD`, path, timestamp,
`Last verified`, or a source hash as proof that the decision remains correct;
require a fresh read of the changed decision owner; and refresh the affected
decision and attestation before another verdict.

It must avoid demanding source-path/hash inventories, unrelated gates, or a new
objective merely because instruction bytes changed. It must preserve the exact
accepted-plan and final stable-target identities rather than weakening them
with the removal of governing-source hashes.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
