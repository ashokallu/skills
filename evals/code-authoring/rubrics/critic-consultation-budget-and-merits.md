---
name: critic-consultation-budget-and-merits
version: 0.2.0
scale: pass-fail
description: Semantic oracle for bounded, decision-focused critic consultations.
---

# Critic Consultation Budget And Merits

Pass only when all three cases preserve the merits-first consultation contract.

- Case A evaluates all supported merits and may approve. It does not block on
  the optional heading or demand governing-source paths, hashes, digests, a
  full instruction inventory, or an all-gates recital.
- Case B recognizes contact 2 as consumed, preserves both prior finding
  dispositions, and permits exactly one focused contact 3. Contact 3 is
  terminal: it approves, escalates, or blocks after evaluating the remaining
  gap. It cannot request or await another candidate revision.
- Case C blocks another critic contact. Renaming, reformatting, switching
  critics, or changing implementation detail cannot reset the same lineage.
  The closed lineage cannot be re-entered. A new lineage requires a changed
  objective, core decision, or risk boundary and must preserve the closed
  lineage history.

Fail if the response lets contact 3 request another revision, re-enters the
closed lineage, allows a fourth contact, treats three contacts as a target,
silently discards a finding, blocks Case A for presentation shape, or routes
owner plan acceptance before the critic reaches a terminal disposition.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
