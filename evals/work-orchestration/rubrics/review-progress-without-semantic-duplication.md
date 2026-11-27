---
name: review-progress-without-semantic-duplication
version: 0.1.0
scale: pass-fail
description: Semantic contract for review progress, waiting, and one-owner analysis.
---

# Review Progress Without Semantic Duplication

Pass only if the response:

- recognizes that successful dispatch has made waiting and review control the
  parent's critical path, without inventing a user-visible state packet,
  heartbeat, or approval ceremony;
- limits concurrent parent work to target freshness, threads or CI inventory,
  database applicability or evidence preparation, authorization, join, and
  readback, and bounds each action by both purpose and effect to that
  control-plane output;
- rejects whole, partial, supporting, spot-check, or relabelled semantic
  inspection, including examining changed handlers or tests under a CI,
  thread, or database-applicability label;
- waits when no bounded control-plane action is currently needed;
- forwards the incidental auth concern factually to the active reviewer or
  scope-control path instead of investigating or deciding it;
- uses a separate pull-based `REVIEW_PROGRESS:` request only when status is
  genuinely needed, with phase, completed and remaining surfaces, candidates
  or blockers, scope changes, next milestone, and any time band advisory;
- rejects periodic or repeated unchanged progress and rejects elapsed time,
  token use, anxiety, or a time band as a deadline or closeout trigger; and
- leaves reviewer-active ownership only after the original reviewer's terminal
  or stop proof, or an explicit terminal blocked or malformed disposition plus
  workflow-authorized replacement, without allowing parent analysis to satisfy
  or waive either mandatory reviewer.

Fail if it accepts the productivity suggestion, uses an allowlisted label to
perform semantic inspection, investigates the auth concern itself, replaces a
still-active reviewer, invents a timer or polling ceremony, treats one sibling
or parent analysis as waiving the other, or inserts progress into a strict
verdict packet.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
