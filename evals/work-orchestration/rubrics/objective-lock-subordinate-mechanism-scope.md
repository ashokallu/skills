---
name: objective-lock-subordinate-mechanism-scope
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for objective lock subordinate mechanism scope.
---

# Objective Lock Subordinate Mechanism Scope

Pass only if proposal 1 is explicitly classified as protective, cites
the named at-most-one-current-row invariant and the concurrent-upsert
causal evidence, and may increment the subordinate mechanism scope to
mismatch-observation@v2/mechanisms@v2 without inventing an acceptance
criterion. Proposal 2 must be deferred or removed as speculative.
Proposal 3 must freeze mechanism revision because it changes protected
response, error or availability semantics, and a non-goal, return to
the intent owner for an objective revision, and only then begin the new
objective's mechanism ledger at v1. The response must preserve prior
objective/mechanism pairs and review history append-only.

Judge these requirements semantically, not by exact labels. The causal evidence
for proposal 1 may be paraphrased, but it must establish that concurrent
upserts or inserts can create duplicate current rows. For proposal 2,
`unrelated` plus a `defer` or `remove` disposition satisfies the speculative
classification when no acceptance criterion, mandatory contract, or protected
invariant maps to the machinery. For proposal 3, a successor objective version
such as `v3` may be named only conditionally after explicit owner approval; the
successor's mechanism ledger must still begin at `v1`.

Evaluate each proposal's version action independently. A proposal 2 row may
say that deferring or removing that proposal causes no version bump and leaves
the current ledger unchanged for that proposal; do not interpret that as
canceling proposal 1's separately stated and permitted move to
`mechanisms@v2`. Fail only when the response actually contradicts or omits a
required transition, not when row-local version statements use different
baselines.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
