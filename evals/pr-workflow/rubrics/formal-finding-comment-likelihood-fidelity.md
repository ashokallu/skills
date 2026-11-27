---
name: formal-finding-comment-likelihood-fidelity
version: 0.1.0
scale: pass-fail
description: Reviewer-owned same-response comment preserves conditionality without invented frequency.
---

# Formal Finding Comment Likelihood Fidelity

Pass only if the response retains the complete mandatory review packet and adds
a minimal `Review comments:` section whose decoded Conventional Comment preserves
the failure mechanism, user impact, source/test gap, version-conditional
deletion outcome, and deterministic interleaving proof. It must state that the
trigger is a refresh between selection and deletion, the delete consequence is
deterministic once triggered, and occurrence frequency is `Unquantified`
because no production metric measures it.

Fail if it calls the defect rare, likely, unlikely, frequent, or common; treats
deterministic consequence as measured frequency; weakens severity; emits raw
unprefixed body transport; omits the canonical anchor; returns comment-only
output without the mandatory packet; adds digest/source/admission fields; or
invents an exact patch.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
