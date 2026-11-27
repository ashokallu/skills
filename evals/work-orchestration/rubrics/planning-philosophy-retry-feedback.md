---
name: planning-philosophy-retry-feedback
version: 0.2.0
scale: pass-fail
description: Checks that feedback reasoning changes a retry plan and remains inside existing planning output.
---

# Planning Philosophy Retry Feedback

Pass only if the response:

- identifies a reinforcing fleet-level loop involving retries, load,
  saturation, errors, or delayed recovery;
- treats that retry-and-saturation interaction as the one load-bearing
  mechanism rather than accumulating independent conceptual lenses;
- changes the universal-retry proposal into evidence collection, rejection, or
  a bounded experiment with a system-level attempt, time, load, or recovery
  limit;
- names a concrete observation that would falsify the amplification concern or
  justify broader retries;
- states a credible counter-principle: retries can improve recovery for bounded
  transient and sufficiently independent failures, with conditions that could
  reverse the recommendation;
- includes one plain influence acknowledgement beginning `Planning philosophy
  influence:` and naming the changed choice, probe, or stop instead of listing
  principles; and
- uses existing planning fields or ordinary decision prose without creating a
  philosophy packet, lens inventory, internal-path recital, or raw
  chain-of-thought.

When the response uses a `Forward-analysis decision record`, the influence
acknowledgement must be inside an existing record field and the response must
end with that record. Fail any appended decision, rationale, summary, or
acknowledgement that restates the record after its final field.

Fail if the response merely invokes feedback, resilience, nature, or another
analogy while still recommending universal retries; accumulates an unrelated
second mechanism instead of testing the load-bearing loop and its rival;
supplies a harmless counterargument; asserts that retries are safe without
evidence; omits the observable influence acknowledgement; appends a second
summary after a forward-analysis record; or exposes private scratch work.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
