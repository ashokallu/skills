<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-31 (deletion and current-variation seam rules) -->

# Code Architecture Deepening

Use this lane for read-only architecture assessment before broad refactors, or
after a bug exposes poor locality, missing seams, or testability friction.

## Mission

Find the one reversible structural move that most improves locality,
ownership, or testability, grounded in the repo's current shape — not an
idealized redesign.

## Boundaries

This lane owns assessment and seam design. Load `plan-to-slices` to sequence
an approved refactor, `simplification` for behavior-preserving cleanup inside
an existing boundary, `duplication-and-abstraction` when the pressure is
repeated logic rather than misplaced ownership, and `adr-research` when the
move is strategic enough to need a documented decision.

Do not edit code during this pass unless the user asked for implementation.

## Process

1. Map current modules, callers, data ownership, and validation surfaces.
2. Look for friction: scattered concept ownership, duplicated guards, shallow
   pass-through modules, private-helper-only testability, and leaked trust or
   migration assumptions.
3. Run the deletion test. Imagine removing the module: if its complexity
   disappears, it is likely pass-through; if the responsibility reappears
   across callers, the module is earning locality and leverage.
4. Rank candidates by user impact, regression risk, locality gain, and
   testability gain.
5. Prefer one reversible deepening move over a program of moves.
6. Before adding a production seam, identify the current behavior, consumer,
   environment, or implementation variation that it must support. A test fake
   alone may justify an internal test seam, but it does not prove that callers
   need a public production seam. Do not use a fixed adapter count as proof.
7. For tactical designs, specify the interface before implementation: API
   shape, event payload, data contract, error format, versioning,
   compatibility plan, and owner of each boundary.
8. For strategic decisions, check existing ADRs and document reversibility,
   capacity, rollout, rollback, and security/privacy impact before coding.

Each candidate should include files/modules, problem, deepening move, tests,
ADR impact, value, security/cost, rollback, and risk.

## Design Pressure Checks

- Does this option deliver the user, API, data, or operator value better than a
  smaller local change?
- What existing repo pattern already solves this problem?
- If the module disappeared, would responsibility vanish or spread back across
  current callers?
- What current variation makes a new production seam real, rather than useful
  only to a test fake or hypothetical future implementation?
- What are the upstream and downstream consumers, and how do they migrate?
- Can the decision be reversed in one sprint? If not, who owns the decision?
- Does the team have the skills, time, dependencies, and operational access to
  maintain the result?
- Does the design create new trust boundaries, PII flows, external calls,
  queues, storage, costs, or deploy topology?
- Will the seam be exercised by tests through its public interface, or does
  testability still require private access after the move?
- Does the move reduce the number of files a future single-concept change
  must touch, measured against two or three recent real changes?

## Output Discipline

Present ranked candidates with the evidence behind each ranking factor.
Recommend at most one move to start, name the trigger that would justify the
next move, and record rejected candidates with reasons so the assessment is
not silently redone later. Unverified claims about consumer impact or
migration cost stay `Pending Verification`.
