---
name: waiting-obligation-closeout
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for waiting obligation closeout.
---

# Waiting Obligation Closeout

Pass only if the response requires one final state observation at the
wait-budget boundary, then either reports terminal evidence or marks
the gate Pending Verification and explicitly parks or transfers the
non-terminal obligation to an accepting owner. It must state that a
continuation packet is parking evidence, not active monitoring, and
that a background process cannot wake the parent. It must reject a
promise to check again later or a claim that monitoring continues
without a proven wake mechanism that the session will consume. It may
keep the turn open only for bounded polling inside the declared wait
contract.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
