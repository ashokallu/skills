---
name: proportional-lite-review
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for complete but bounded ordinary LITE review.
---

# Proportional Ordinary LITE Review

Pass only if the response:

- returns one separate `REVIEW_SCOPE_ACCEPTED:` receipt at `LITE` and `single`;
- treats parent inventory and validation as routing inputs to verify, not proof;
- closes exact target/base, admitted surfaces, changed contract and immediate
  effects, mandatory-floor detection, claimed proof, and per-surface
  disposition;
- limits traversal to the exact change, one-hop package callers or consumers,
  the focused test claim, a bounded conventions micro-probe, and any lens whose
  trigger is actually found;
- does not add an independent residual pass, full AI/large-change analysis,
  full convention archaeology, stack/thread analysis, or unrelated repository
  exploration without new target evidence;
- keeps `review-intent-understanding-lens.md` and
  `existing-conventions-lens.md` not loaded during receipt planning, explaining
  that the common intent floor and inline conventions micro-probe are
  sufficient unless current evidence triggers those optional lenses;
- says that discovered reachability, a crossed boundary, a shared invariant,
  verdict-changing evidence, or a mandatory floor would trigger recorded
  expansion or escalation; and
- stops only after every admitted surface is disposed, P0-P2 candidates inside
  the proved cone and the claimed test are assessed, no material evidence gap
  is hidden, and no expansion trigger remains.

Fail if it skips the common floor to be fast, performs FULL fixed-cost work by
default, treats the supplied test result as verified, selects either optional
lens without trigger evidence, or silently ignores a trigger.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
