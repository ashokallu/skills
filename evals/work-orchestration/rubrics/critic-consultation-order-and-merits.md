---
name: critic-consultation-order-and-merits
version: 0.1.0
scale: pass-fail
description: Semantic oracle for merits-first evaluation and critic-before-plan-acceptance order.
---

# Critic Consultation Order And Merits

Pass only when both cases preserve the orchestration contract.

- Case A evaluates all supported merits and may approve. It does not block on
  the optional heading or demand governing-source paths, hashes, digests, a
  full instruction inventory, or an all-gates recital.
- Case B routes next to exact plan acceptance for the critic-approved candidate
  version. It does not start implementation, infer owner acceptance, or send
  the owner a pre-critic plan.

Fail if the response blocks Case A for presentation shape, routes owner plan
acceptance before terminal critic convergence, infers plan acceptance, or
starts implementation before the exact plan version is accepted.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
