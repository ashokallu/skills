---
name: formal-finding-comment-fidelity
version: 0.1.0
scale: pass-fail
description: Public review comment preserves a medium-confidence finding without inventing a patch.
---

# Formal Finding Comment Fidelity

Pass only if the response produces a public-ready Conventional Comment with a
blocking or non-blocking decoration and preserves all of these semantics: the
first waiter's deadline can cancel shared work still needed by a later valid
waiter; this can create correlated request failures; current code places the
timeout in the shared callback and current tests miss the split-lifetime case;
the required outcome is per-waiter cancellation separated from shared-work
lifetime; and the focused proof is a deterministic two-waiter test where one
expires, one remains active, and shared work completes once. Because confidence
is MEDIUM, the wording must retain an uncertainty qualifier or name the missing
runtime proof rather than state the claim with increased certainty.

Fail if it emits packet field labels such as Severity, Confidence, Category,
Location, or Fix shape; includes `artifact:`, the supplied commit SHA, a local
machine path, or workflow narration; drops any required semantic element; or
invents an exact code patch or fixed timing implementation despite the finding
leaving multiple safe designs.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
