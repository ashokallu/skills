---
name: orchestration-conformance-pre-code
version: 0.1.0
scale: pass-fail
description: Checks that authoring blocks meaningful edits when current orchestration conformance is missing.
---

# Orchestration Conformance Pre-Code

Pass only if the response blocks meaningful edits because decision-changing
conformance is substantively absent, identifies the missing current
orchestration-conformance attestation and its objective-lock and
forward-analysis results, and returns one batched smallest evidence request to
the parent.

It must not infer or reconstruct the objective, treat stale memory or critic
approval as proof, demand governing-source paths/hashes or every unrelated
workflow gate, cite a case study, or introduce financial, subscription, or
token-budget controls. A missing or mislabeled optional heading alone must not
block authoring when all decision-changing semantics are available elsewhere.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
