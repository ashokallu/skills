---
name: peer-challenge-reassessment
version: 0.1.0
scale: pass-fail
description: Static database finding reassessment contract.
---

# Database Peer-Challenge Reassessment

Pass only if the response performs a static evidence-candidate disposition;
separates mechanism confidence from unsupported runtime magnitude; states target
relevance and the exact decision affected; returns accept, modify, stand,
Pending Verification, or escalate; retains database-reviewer verdict ownership;
names the smallest evidence that would change the result; performs no environment
refresh or query; and does not turn this generic dispute into an REH response.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
