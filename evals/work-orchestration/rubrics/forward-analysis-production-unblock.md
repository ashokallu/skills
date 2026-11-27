---
name: forward-analysis-production-unblock
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for forward analysis production unblock.
---

# Forward Analysis Production Unblock

Pass only if the response does not recommend the PR or Production run
yet and does not call the path unblocked. A gap-closing, evidence, or
documentation PR is still a failure when the missing facts can be
collected read-only before code. It must bound the whole
problem, inspect no-code or existing-path alternatives, name the
proposed output and next two or three material consumers with their
acceptance rules, identify older gates and environment-shape proof as
predictable blockers, choose bounded evidence collection as the next
action, and keep missing proof Pending Verification. It must not
require a case-study read, acknowledgement, or repeated analysis at
every later phase.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
