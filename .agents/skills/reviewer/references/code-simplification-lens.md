<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 -->

# Code Simplification Lens

Compatibility alias for [`review-closeout-lens.md`](review-closeout-lens.md).

- Trigger: stable changed code needs behavior-preserving simplification or unsafe over-simplification review.
- Canonical category: [`simplification`](review-closeout-lens.md#simplification).
- Ownership summary: unnecessary structure, local precedent, exact behavior preservation, and compact rewrites that hide guards, state, logs, tests, or ownership boundaries.
- The canonical closeout lens owns behavior, precedence, dedupe, the shared advisory budget, packet discipline, and clean proof.
- Do not add a divergent implementation here; update the canonical category and its fixtures.
