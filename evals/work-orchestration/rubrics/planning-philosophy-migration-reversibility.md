---
name: planning-philosophy-migration-reversibility
version: 0.1.0
scale: pass-fail
description: Checks a reversible migration decision with an honest counterweight.
---

# Planning Philosophy Migration Reversibility

Pass only if the response does not recommend the immediate full switch and
deletion. It must translate the one-way-door, sample-selection, and
next-consumer problems into concrete proof or sequencing requirements, such as
population coverage, parity or shadow evidence, reconstructability, a bounded
rollback target, or explicit cutover and deletion gates. It must name what
cannot be recovered after deletion and what evidence would permit that step.

It must also treat prolonged dual operation as a real counter-principle with
carrying cost and divergence risk. The response should choose the shortest
bounded overlap that preserves the required evidence and recovery option, not
keep both systems indefinitely. The rationale must stand without relying on a
proverb or metaphor name and must remain inside existing planning output rather
than creating a philosophy packet.

Fail if a small Staging sample is treated as population proof, deletion is
recommended before reconstructability and consumer acceptance are known, dual
operation is dismissed without tradeoff, or the response lists lenses without
changing the plan.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
