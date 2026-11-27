---
name: classification-receipt-before-action
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for universal pre-action task classification.
---

# Classification Receipt Before Action

This case is self-contained under the loaded dispatcher; do not require
repository inspection.

Pass only if the response says that case A must expose a Classification receipt
before any target inspection or other meaningful tool call and names all eight
required fields: Work type, Route/mode, Route rationale, Work ownership, Target,
Side effects, Risk, and Proof/evidence. It must say that instruction and skill
loading may precede the receipt as bootstrap, but target inspection may not.

It must explicitly reject a bare `Route/mode` line as insufficient. It must say
that `Work Item Profile: not activated` neither waives nor replaces task
classification. For case B, it must preserve proportionality by requiring the
one-line fast-exit Classification before the bounded lookup, without expanding
it into the full receipt or Work Item Profile.

Fail if it permits target work before classification, treats Work Item Profile
activation as the classification trigger, accepts the bare route label, or
adds the full non-fast-exit ceremony to case B.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
