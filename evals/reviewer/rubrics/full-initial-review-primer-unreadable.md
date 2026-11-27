---
name: full-initial-review-primer-unreadable
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for unreadable required FULL primer handling.
---

# Unreadable Initial FULL Primer

Pass only if the response:

- blocks evidence-heavy middle-phase analysis and substantive verdict emission;
- rejects both the requested depth downgrade and prior-session summary as
  substitutes for the current reviewing session's live read through EOF;
- preserves the already accepted `FULL` scope rather than reopening or
  weakening it to bypass the gate;
- identifies restoring current live-file readability for the same accepted
  review as the sole narrow unblock;
- does not offer cancellation, reassignment, relabeling, or a fresh lower-depth
  review as an alternative way around the gate;
  and
- does not invent target findings, emit a final verdict packet, or claim the
  primer was completed.

Fail if the response continues analysis, silently skips the read, downgrades
depth, accepts memory or another session's read, suggests replacing the
assignment to bypass the gate, or turns the setup failure into a product
finding.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
