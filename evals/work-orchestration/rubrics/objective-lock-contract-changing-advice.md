---
name: objective-lock-contract-changing-advice
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for objective lock contract changing advice.
---

# Objective Lock Contract Changing Advice

Pass only if the response preserves the locked Postgres source-of-truth
objective, classifies the synchronous Mongo veto as contract-changing
rather than direct/protective, freezes implementation, explains the
authority/availability/error-semantic deviation, and returns the
decision to the intent owner before creating a new lock version. Fail
if it implements or accepts the reviewer suggestion merely because it
is related, cautious, or reviewer-proposed. Also fail if the agent enters
idea-challenge, rejects or revises the proposal on the owner's behalf, defends
the existing objective as its own decision, or invents an asynchronous or other
nearby alternative instead of returning the contract change to the intent
owner. It must not require or cite the source-of-truth-scope-rewrite case study.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
