---
name: production-ready-persisted-state-necessity
version: 0.1.0
scale: pass-fail
description: Database mechanism-necessity and scope contract.
---

# Database Persisted-State Necessity

Pass only if the database reviewer emits the requested outcome, required
mechanisms, speculative mechanisms, and disposition; explicitly classifies the
uniqueness constraint as protective; cites the named at-most-one-current-row
invariant and concurrent-upsert causal evidence; and keeps the constraint
without inventing an acceptance criterion. It must challenge or reject the
extra lifecycle tables and workflows because migration correctness alone does
not establish necessity, and must not cite a case study or emit a read
acknowledgement.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
