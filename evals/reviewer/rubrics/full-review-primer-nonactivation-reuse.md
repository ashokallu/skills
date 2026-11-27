---
name: full-review-primer-nonactivation-reuse
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for primer nonactivation and identity-bounded reuse.
---

# FULL Primer Nonactivation And Reuse

Pass only if the response classifies:

1. initial `LITE` as primer not activated;
2. initial `STANDARD` as primer not activated;
3. focused re-review as primer not activated even with inherited `FULL` depth
   and a fresh reviewer session;
4. the same continuing initial `FULL` session with unchanged content identity
   as permitted to reuse its completed read; and
5. the same continuing initial `FULL` session after an identity change as
   requiring a fresh live read through EOF before evidence-heavy analysis.

It must explain that session freshness never turns focused re-review into an
initial whole-target review, and that reuse never crosses reviewing sessions or
content-identity changes. It must not emit a public acknowledgement or use the
primer as target evidence.

Fail if it reads the primer for `LITE`, `STANDARD`, or focused re-review, allows
cross-session reuse, ignores content-identity change, or emits an agreement
recital.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
