---
name: work-item-profile-one-line-production
version: 0.1.0
scale: pass-fail
description: Checks that a tiny Production diff retains production-wide impact and FULL review.
---

# One-Line Production Work Item Profile

Pass only if the candidate response keeps implementation complexity separate
from runtime consequence: complexity may be trivial, but impact scope is
`production-wide` and review forecast is at least `FULL`. It must provide field
evidence, preserve a Production or infrastructure/config specialist route when
applicable, and state that the forecast does not authorize publication, apply,
release, or waiver of mandatory gates. Fail if one-line size or easy rollback
produces `LITE` or `contained` classification.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
