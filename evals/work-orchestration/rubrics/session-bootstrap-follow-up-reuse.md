---
name: session-bootstrap-follow-up-reuse
version: 0.1.0
scale: pass-fail
description: Semantic contract for follow-up instruction-read reuse.
---

# Session Bootstrap Follow-Up Reuse

Pass only if the response handles every case without turning reuse into a
blanket skip:

- A performs the full applicable initial bootstrap because no reusable ledger
  exists.
- B and C reuse matching instruction reads without reopening unchanged
  contents only after continuity, ledger, scope, and current immutable
  identities are proved. Across B through D, the response must make clear that
  a new user turn or compaction alone supplies neither continuity proof nor a
  forced new-session result; this may be expressed through the cases rather
  than repeated as an exact sentence.
- D fails closed to the applicable new-session reads because continuity or the
  ledger is unproved. Conversation history, summaries, paths, timestamps,
  `HEAD`, and prior attestations are examples of insufficient substitutes; do
  not require the response to enumerate every example when it relies on none.
- E rereads the changed governing source at a new immutable identity, discovers
  and reads the newly applicable subtree instruction, and does not require
  unrelated unchanged sources to be reopened.
- F obeys the higher-priority per-turn selected-`SKILL.md` read and requires the
  fresh critic session to spot-check only current decision owners that can
  change its verdict, without transporting or reproducing the parent's complete
  path-and-identity ledger. The unchanged parent session may reuse other
  matching reads.
- The optional Bootstrap packet remains conditional: no global reuse narration
  is added for ordinary B or C. When a gap, conflict, blocked state, or exact
  source-set consumer requires the packet, it uses one `Instruction reuse` row
  that names both reused and refreshed paths.

Fail if the response uses a new turn or compaction as automatic proof either of
continuity or of a new session, trusts non-content freshness evidence, bypasses
a mandatory selected-skill or verdict-bearing spot-check, makes a critic reread
every unchanged source, or emits the reuse packet globally.

Grade the decisions across the cases semantically. Do not require a checklist,
verbatim restatement, or exact placement when the conditional behavior is
unambiguous.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
