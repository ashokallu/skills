---
name: instruction-maintenance-pruning
version: 0.1.0
scale: pass-fail
description: Checks sentence no-ops, trigger branches, compact terms, and completion-first sequencing.
---

# Instruction Maintenance Pruning

Pass only if the response gives all four dispositions:

- A deletes the whole sentence as a behavior no-op instead of rewriting it as
  a stronger slogan.
- B collapses the synonyms to one observable branch trigger because they do
  not represent distinct paths.
- C first replaces the vague inventory completion with a checkable and, where
  needed, exhaustive criterion. It may split the sequence only if later steps
  still cause observed premature completion after the criterion is decisive.
- D rejects the compact term unless it receives an operational definition and
  actually replaces repeated decision-bearing prose.

The response must preserve current owner and route boundaries. Fail if it adds
a new skill or route, imports runtime-only invocation metadata, merely shortens
the text, repeats labels without behavioral effect, or splits before fixing the
completion criterion.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
