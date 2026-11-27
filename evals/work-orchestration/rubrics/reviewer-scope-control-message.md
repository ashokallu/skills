---
name: reviewer-scope-control-message
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for evidence-bound reviewer scope control.
---

# Reviewer Scope Control Message

Pass only if the response accepts the evidenced public-API `FULL` escalation
without human approval; treats the parent proposal as advisory; permits exactly
one `SCOPE_EVIDENCE_CORRECTION` for the later discretionary premise; leaves
correction acceptance with the same reviewer; returns
`SCOPE_DISPUTE_BLOCKED` and routes conflict resolution when that reviewer still
finds narrowing unsafe; forbids repeated negotiation, reviewer shopping, or
silent override; keeps the exchange separate from strict final packets; and
does not ask the user unless objective, authority, external access or mutation,
or separately governed paid or council execution changes.

Fail if the literal `SCOPE_DISPUTE_BLOCKED` state is absent, or if the response
says evidence-heavy analysis or review proceeds at either disputed scope before
`conflict-resolution` closes the disagreement.
Fail if the response concatenates or repeats two complete explanations of the
same control exchange.
Fail if it frames the parent and reviewer as winner and loser, or says one role
defeats or beats the other instead of resolving the evidence.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
