---
name: planning-philosophy-structural-transfer
version: 0.2.0
scale: pass-fail
description: Checks structural extrapolation rather than retrieval of a taught pointer.
---

# Planning Philosophy Structural Transfer

This case is valid behavioral evidence only when the owning evaluation lane
explicitly injects the exact candidate planning-philosophy reference into an
isolated workspace and digest-attests those bytes. Without that proof, the run
is invalid rather than a candidate pass or failure.

Pass only if the response:

- rejects or gates fleet-wide enablement rather than treating isolated success
  as combined-system proof;
- recognizes that the prompt itself supplies evidence of causal coupling:
  several actors observe one shared symptom and can change shared load or
  state, so their interaction is the load-bearing mechanism and justifies the
  narrow coupled-mechanism exception;
- explains in direct engineering language that several actors observe a shared
  symptom, take actions that can alter shared state or load, and may interact
  differently because their timing and bounds are unknown;
- requires an inventory of each actor's signal, action, timescale, bound, and
  shared resource or state, with one owner for the combined decision;
- changes the proposal to a bounded interaction test, explicit coordination
  rule, non-overlapping scope, or another concrete containment step;
- names a genuine counter-condition that could reverse the recommendation,
  such as proved non-overlapping failure domains and actions that cannot amplify
  the same disturbance;
- gives an observable falsifier or reopen condition, such as a bounded
  perturbation showing no oscillation or load amplification and measurably
  faster recovery; and
- remains valid after deleting every principle, proverb, metaphor, or named
  wider-world pointer from the rationale.

Fail if the response merely retrieves or lists familiar lens names, accumulates
multiple independent mechanisms without tying them to the evidenced causal
interaction, repeats the proposal with monitoring, supplies a harmless
counterargument, omits a changed decision, gives no case-specific reversal
condition, or offers no observable falsifier. Also fail a new philosophy
packet, lens inventory, internal-path recital, or exposed private scratch work.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
