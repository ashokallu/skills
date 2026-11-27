<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Code Simplification

Use this lane for behavior-preserving simplification, unnecessary abstraction,
large-file pressure, and clarity or maintainability cleanup.

This lane is adapted from the Agentics `code-simplifier` and
`large-file-simplifier` workflows. Keep the durable authoring behavior, but do
not copy scheduled scan windows, PR creation mechanics, safe-output footers,
cache paths, or issue templates into example-app code authoring.

## Mission

Improve clarity, consistency, and maintainability while preserving exact
functionality. Prefer readable explicit code over overly compact code.

Follow this mission sequence:

1. Read the changed code and nearby local conventions before suggesting a
   simplification.
2. Identify exactly which complexity the simplification removes.
3. Check whether the simpler shape preserves public interfaces, behavior,
   generated ownership, logs, tests, and debugging affordances.
4. Apply only targeted changes that improve readability or maintainability.
5. Validate with the smallest command that proves behavior is unchanged, or
   mark the proof `Pending Verification`.

## Ownership

This lane owns behavior-preserving simplification and navigability. It does
not own behavior changes, broad architecture redesigns, performance rewrites,
or review verdicts.

Defer to stronger lanes when:

- repeated logic may encode a shared invariant:
  `duplication-and-abstraction.md`;
- the simplification changes SQL, imports, backfills, jobs, or operator gates:
  `production-data-safety.md`;
- the change claims speed, memory, network, or cost improvement:
  `efficiency-and-scale.md`;
- tests are missing or brittle: `test-quality.md`; and
- comments, docs, logs, or PR text become stale:
  `docs-and-operator-truth.md`.

## Probes

- Can nesting, branching, or state be reduced without hiding behavior?
- Is a helper, wrapper, struct, interface, config knob, or file split carrying
  real complexity, or only looking reusable?
- Are names specific enough to reveal domain intent without comments?
- Does a large file have natural domain, ownership, or testability boundaries?
  Treat 500 lines as a scout signal, not an automatic split mandate.
- Are comments explaining non-obvious invariants, or narrating obvious code?
- Does a compact rewrite remove useful guardrails, logs, tests, or state
  boundaries?
- Does the split plan keep each new file focused, keep public symbols stable,
  update imports, and let tests run after each incremental move?

## Guardrails

- Never change behavior as part of simplification unless the user asked for
  that behavior change.
- Do not optimize for fewer lines over readability.
- Do not collapse separate concerns into one function.
- Preserve helpful abstractions that encode ownership boundaries, invariants,
  generated-contract seams, or test seams.
- Do not split a file mechanically to satisfy a line-count target.
- Do not create a new dependency, config knob, or helper just to make a
  simplification look tidy.
- Validate with the narrowest relevant check after simplification.

## Clean Result

If no simplification is beneficial, say so plainly in closeout. A clean pass is
useful evidence that the code was checked for obvious clarity and maintenance
pressure; it is not proof that the change is safe.
