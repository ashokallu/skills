<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 -->

# Inline Advisory Review Lens

Compatibility alias for [`review-closeout-lens.md`](review-closeout-lens.md).

- Trigger: stable-target closeout needs passable but consequence-bearing review candidates.
- Canonical category: [`consequence_advisory`](review-closeout-lens.md#consequence_advisory).
- Ownership summary: production cost, operator evidence, wrong-green tests, stale downstream assumptions, and other line-local advisories with proved consequences.
- The canonical closeout lens owns behavior, precedence, dedupe, the shared advisory budget, packet discipline, and clean proof.
- Do not add a divergent implementation here; update the canonical category and its fixtures.
