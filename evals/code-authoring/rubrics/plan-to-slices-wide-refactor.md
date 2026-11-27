---
name: plan-to-slices-wide-refactor
version: 0.2.0
scale: pass-fail
description: Checks vertical defaults, dependency frontiers, and independently green expand-migrate-contract plans.
---

# Plan To Slices For Wide Refactors

Pass only if the response keeps A as vertical user-visible slices and treats B
as the narrow mechanical exception:

- Every proposed A slice names a coherent learner-visible outcome and includes
  all backend, API, UI, and test work needed to deliver that outcome. Calling
  the plan vertical is not sufficient.
- B starts with a compatible expansion that keeps the old form working.
- B migrates callers in bounded batches, each independently green, shippable,
  reviewable, and blocked only by the expansion.
- B contracts the old form only after every migration batch completes, so the
  contract slice is blocked by every batch.
- The initial frontier contains the expansion; after it completes, all
  otherwise independent migration batches enter the frontier; contraction
  enters only after all batches finish.
- The response rejects a hidden final integration slice or shared-only-green
  branch and revises the compatibility seam if batches cannot stay green.

Fail if the response labels A vertical but concretely orders backend or API
work as one slice, UI wiring as a later slice, or tests as a final slice. Also
fail if layer slicing becomes the default, blocker edges include preferences
rather than true prerequisites, the frontier is omitted, or any migration
batch needs a later integration step before it is valid.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
