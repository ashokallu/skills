---
name: reviewer-scope-parallel-join
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for parallel sibling review and lossless join.
---

# Reviewer Scope Parallel Join

Pass only if the response dispatches both reviewers immediately from static
evidence and explicit gaps; states that ordinary PR review performs no
environment preflight or live read; preserves missing current proof as
claim-specific `Pending Verification`; gives each sibling its own separate
scope-control exchange; does not let negotiation for one serialize the other;
waits for both required accepted packets before final handoff; maps the
ordinary result to `ACTION` and the database result to `EVIDENCE`; emits
`JOIN_BLOCKED_EVIDENCE` by precedence; preserves the original P2, database
verdict, central gap, targets, confidence, and owners; and states that the join
authorizes no publication, approval, deployment, or mutation.

Evaluate only the supplied candidate output against those semantic
requirements. Waza attests skill invocation and canonical skill-path identity
separately; do not infer or independently grade whether the skill was available
or invoked.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
