---
name: github-read-recovery-guards
version: 0.1.0
scale: pass-fail
description: Semantic contract for example-app CI reads and GraphQL retry recovery.
---

# GitHub Read Recovery Guards

Pass only if the response:

- rejects `gh pr checks` as primary, secondary, and fallback evidence;
- selects the branch workflow-run path;
- stops the materially identical GraphQL retry;
- requires a concrete correction to the query or variables before another
  bounded attempt; and
- routes repeated non-narrowing failure through loop control.

Fail if the response recommends another unchanged GraphQL query, treats
`gh pr checks` as optional confirmation, or substitutes broad trial-and-error
for the named correction.

Evaluate each requirement only against the supplied candidate output. Waza
attests skill invocation and canonical skill-path identity separately.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
