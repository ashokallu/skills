---
name: planning-philosophy-analogy-deletion-test
version: 0.1.1
scale: pass-fail
description: Checks that analogy is translated into a testable mechanism or rejected.
---

# Planning Philosophy Analogy Deletion Test

Pass only if the response rejects the nature slogan as authority and does not
recommend two database technologies from the supplied evidence. It may retain
a service-specific diversity hypothesis only as an unproved exception with
explicit admission gates: a specific shared failure, an actually independent
recovery path, an acceptance target, and evidence that the extra technology
reduces that failure. When the prompt supplies none of that evidence, naming
the missing gates and refusing to treat them as satisfied is sufficient; the
response must not invent a concrete failure or imply that the exception is
currently justified.

The engineering rationale must remain valid after removing every reference to
nature or diversity. It must test a credible counter-principle: heterogeneity
adds operational load and at least one material risk such as inconsistent
behavior, divided expertise, or retained common causes. Do not require an
inventory of every possible cost when a smaller counterweight changes the
decision. The smallest current action should be a bounded failure-domain and
recovery analysis, existing-control check, gated service-specific exception,
or no-op rather than architecture by analogy.

Fail if the response treats survival or natural prevalence as proof of good
design, recommends redundant technology without operational independence, or
replaces the slogan with another untestable slogan.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
