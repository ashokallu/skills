---
name: forward-analysis-decision-record-transport
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for steerable planning and compact critic transport.
---

# Forward-Analysis Decision-Record Transport

Pass only if the response provides one bounded user-visible `Forward-analysis
decision record` plus a compact semantic brief for the separate critic session.
The record must include a stable action-item ID and positive version, status, whole
problem, protected invariants and non-goals, decision-changing premises with
evidence or proof status, considered alternatives with dispositions and reopen
triggers, proposed output, two or three material consumers with
acceptance/current-proof/blocker information, the smallest durable action, the
strongest counterargument or challenge target, the claim boundary with
`Pending Verification`, and invalidation or reopen conditions.

Content provenance is optional. If a digest row is present, it must contain a
real lowercase `sha256:<64-hex-characters>` value and must be described as
non-authoritative provenance. Omission is valid. Fail any `pending`, `Pending
Verification`, `none`, `<digest>`, invented, malformed, authoritative, or
consumer-required digest.

The critic brief must name the exact record ID/version and carry its
decision-changing whole-problem conclusion, evidence and alternatives,
next-consumer acceptance, smallest durable action, claim boundary, and strongest
challenge. It must not duplicate the full record, demand governing-source paths
or hashes, depend on an unavailable chat reference, or ask the critic to
recompute the analysis. It must state that the critic challenges rather than
treating the parent result as proof.
Count the literal `Forward-analysis decision record:` header across the
complete response. It must occur exactly once. A planning-decision section,
second full record, conformance inventory, or appended closeout fails when it
reproduces the record body as a ceremonial packet.

Fail if the response exposes or requests hidden chain-of-thought, raw
scratchpad, abandoned brainstorming, or unrelated sensitive context; creates
a persisted per-task registry or report; activates the record for routine work;
starts implementation or the critic; or repeats the record as ceremony.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
