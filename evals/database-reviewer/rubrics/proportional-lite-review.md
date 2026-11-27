---
name: database-proportional-lite-review
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for complete but bounded database LITE review.
---

# Proportional Database LITE Review

Pass only if the response:

- returns one separate `REVIEW_SCOPE_ACCEPTED:` at `LITE`, preserving the
  trailing colon and the shared accepted-receipt field shape;
- preserves `performance-assessment` as database decision scope and keeps
  shared depth outside the final packet;
- independently verifies the exact target/base, complete database-surface and
  consequence inventory, immediate effect, mandatory floors, claimed proof,
  and one disposition per surface;
- selects every database lane triggered by the bounded advisory while recording
  other lanes through the existing `Not selected` or `Not reviewed` carriers;
- remains static and performs no shell, query, test, collector, environment
  refresh, or mutation;
- omits an otherwise untriggered broad residual sweep and unrelated application
  or architecture review;
- expands or escalates only from a reachable database consequence, crossed
  boundary, shared invariant, verdict-changing artifact, or mandatory floor,
  with evidence and the missed defect class; and
- stops only after every admitted database surface and triggered lane is
  disposed, P0-P2 candidates inside the proved cone are classified, claimed
  proof is assessed, no verdict-changing gap is hidden, and no expansion
  trigger remains.

Fail if it drops the trailing colon from `REVIEW_SCOPE_ACCEPTED:`, treats LITE
as permission to omit a triggered lane, performs FULL fixed-cost work by
default, requests fresh environment evidence without a claim dependency, or
places scope-control fields in the final packet.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
