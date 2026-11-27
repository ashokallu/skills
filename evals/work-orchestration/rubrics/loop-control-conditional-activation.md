---
name: loop-control-conditional-activation
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for loop control conditional activation.
---

# Loop Control Conditional Activation

Pass only if the response keeps case A out of loop control and routes
the first ordinary failure through execution recovery, environment
tooling, or the owning auth/setup workflow. It must activate
loop-control-and-escalation for case B, reject the identical retry and
unnecessary reviewer, name the exact claim or blocker, state that the
prior attempts added no evidence, choose exactly one changed tactic,
reroute, targeted question, handoff, or genuinely blocked state, and
give a material changed variable plus a terminal stop condition. It
must not report BLOCKED solely because two attempts failed when a safe
changed tactic or owning route remains.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
