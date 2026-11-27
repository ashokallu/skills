<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Code ADR Research

Use this lane for evidence gathering before writing an ADR. A good packet lets
the ADR author decide; it does not silently make the decision.

## Mission

Produce a decision-ready evidence packet: the real problem, the honest option
set, and the verified facts each option depends on, with unverified claims
clearly marked so the decision is never built on assumed evidence.

## Boundaries

This lane owns evidence gathering and option framing. For final ADR
authoring, route through the owning ADR workflow instead of keeping the
decision inside this code skill. Load `architecture` for seam and boundary
analysis, `impact-and-source-map` for repo-truth collection, and
`efficiency-and-scale` or `security-and-trust-boundary` when the decision
hinges on those claims.

## Protocol

1. Restate the decision topic in one sentence, including what triggers the
   decision now and what happens if no decision is made.
2. Audit current repo state, including relevant ADRs, docs, existing partial
   implementations, and prior attempts; a superseded ADR or abandoned branch
   is evidence, not trivia.
3. Identify options, including status quo and at least two alternatives. For
   each option name what it optimizes for, what it gives up, and which
   existing repo pattern it extends or contradicts.
4. Gather authoritative external evidence only when it is needed, prefer
   primary sources (official docs at the repo's pinned versions, benchmarks
   with stated conditions), and record where each fact came from.
5. Map per-option: migration path, rollback difficulty, security surface,
   operational ownership, cost order of magnitude, and team capability fit.
6. Separate verified facts from assumptions. Every load-bearing claim is
   either evidenced (with source) or `Pending Verification` (with the exact
   check that would verify it).
7. Produce or update a packet under `docs/agents/<decision-slug>-research.md`
   only when the user asked for a saved artifact.

## Prevention Probes

- Is the status quo represented fairly, or strawmanned to justify change?
- Does any option depend on a version, feature, quota, or API behavior that
  was assumed rather than checked against the repo's actual versions?
- Which claim, if wrong, flips the recommended direction? Is it verified?
- Are rollback difficulty and decommission cost stated for the favored
  option, not only the migration path in?

## Output Discipline

The packet ends with the option comparison and open questions, not a verdict.
If the evidence strongly favors one option, say so and why, but label it as
research-lane assessment and leave the decision to the ADR author. List every
`Pending Verification` with the concrete verification step.
