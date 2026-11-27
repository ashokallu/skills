---
name: objective-lock-verified-contract-skip
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for objective lock verified contract skip.
---

# Objective Lock Verified Contract Skip

Pass only if the response records or reuses the existing lock and moves
to the owning implementation workflow without asking the user to repeat
objective discovery or triggering an objective-lock-generated duplicate
critic/review. It must also state or preserve that independently
required existing critic, reviewer, validation, and publication gates
still apply. Fail if it suppresses those gates or restarts broad scope
discovery despite the explicitly unchanged verified contract.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
