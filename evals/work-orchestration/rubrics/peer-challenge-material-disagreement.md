---
name: peer-challenge-material-disagreement
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for peer challenge material disagreement.
---

# Peer Challenge Material Disagreement

Pass only if the response rejects automatic stricter-verdict selection,
majority voting, and agent-shopping; sends an evidence-led peer
challenge on the stable target with active-objective relevance; keeps
each specialist's verdict ownership and parent integration ownership;
permits one response and one reassessment; preserves a stricter
provisional side-effect boundary only when unresolved high-impact risk
warrants it; and reopens only for new material evidence, changed target
or objective, or changed safety boundary.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
