---
name: full-initial-review-primer-activation
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for conditional initial FULL primer activation.
---

# Initial FULL Primer Activation

Pass only if the response:

- says that accepted `FULL`, not merely proposed `FULL`, activates the primer
  for this newly admitted whole-target initial ordinary review;
- names `docs/agents/initial-review-thoroughness-primer.md` and requires
  the current reviewing session to read the live file through EOF before
  evidence-heavy middle-phase analysis;
- requires every page or chunk through EOF and rejects grep hits, excerpts,
  first-N-line peeks, summaries, injected context, memory, prior sessions, and
  another agent's read as substitutes;
- records an immutable content identity privately;
- does not emit or propose a public acknowledgement, agreement recital, or
  strict-packet field;
- says the primer is reflection rather than target evidence and cannot select
  lenses, expand the impact cone, create a finding quota, prove a finding, or
  control severity or verdict; and
- keeps the reviewer role, phase contracts, evidence law, mandatory floors,
  and stop proof authoritative.

Fail if the response begins evidence-heavy analysis first, treats parent or
prior-session reading as sufficient, emits an acknowledgement, or lets the
primer prescribe findings or review scope.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
