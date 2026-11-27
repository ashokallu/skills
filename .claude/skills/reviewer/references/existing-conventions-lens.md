<!-- markdownlint-disable MD013 -->
<!--
Last verified: 2026-07-14 (bounded same-class convention review)
-->

# Existing Conventions Lens

Use this lens to decide whether changed implementation fits the best current
example-app standard for the same problem class or creates a material second
way to do the same job.

## Selection Law

Select this full lens for a broad, generated, refactor, mechanical,
multi-domain, placeholder-heavy, or suspiciously fluent target. For a `LITE`
or bounded `STANDARD` implementation target, the middle phase first performs a
bounded owner-first micro-probe. Select this lens when that probe finds
competing patterns, a material convention candidate, unclear ownership, or
evidence that the change creates a second path. Tiny docs-only changes without
behavior, operator, validation, architecture, naming, or ownership claims are
exempt.

Selecting the lens is mandatory when one of those triggers is present; emitting
a finding is not. A convention candidate must still be current, reachable,
material, actionable, and deduplicated under the reviewer core filter. Working
code, green tests, a small diff, or another finding does not waive the
depth-appropriate micro-probe or full lens, but none of those facts makes
convention drift a finding by itself.

## Why It Matters

Concurrent solutions to one problem class make later work slower and less
reliable. Search and ownership become ambiguous, refactors and tests must cover
multiple paths, and error, logging, context, retry, fallback, or operator
behavior can drift without an intentional design decision. The review goal is
one discoverable standard where the codebase has one, not uniformity for its
own sake.

## Ownership And Dedupe

This lens owns same-class standard fit and dual-path detection. It defers to a
stronger selected lens when the same root cause is primarily security,
privacy, production data, generated contract, performance, silent failure, or
documentation truth. In that case, keep convention evidence internal or in the
selected-lens audit and emit exactly one root-cause finding under the stronger
lens.

When the same candidate is retained, record convention detection in the lens
audit but assign the formal finding owner to the stronger lens. Never label a
security, privacy, production-data, generated-contract, performance,
silent-failure, or documentation-truth root cause as conventions-owned merely
because convention evidence also proves it.

Do not emit pure taste. A finding must cite current same-class precedent and
explain the concrete cost of adding or extending another path.

## Bounded Standard Selection

1. Name the problem class narrowly, such as controller error reporting,
   post-response cache work, package-level integration fixtures, or workflow
   environment selection. Do not use broad labels such as "backend code."
2. Search the closest owning package, module, test family, shared helper, or
   operator surface first. Include the changed code and enough current siblings
   to detect a competing pattern.
3. One authoritative owner or unmistakable same-class helper is sufficient
   when a bounded competing-pattern search finds no current alternative in that
   owner surface.
4. Require two or more precedents only when the first is not authoritative,
   the change challenges an established pattern, or current precedents
   conflict. Broaden only to the nearest shared owner needed to resolve the
   conflict; do not perform repository-wide archaeology.
5. Stop when the evidence establishes an authoritative standard, a justified
   divergence, or no clear standard. When no clear standard exists, record the
   search in the selected-lens audit and emit no finding by default. Use
   `Pending Verification` only when the unresolved standard is material to the
   verdict.
6. Prefer the stronger current standard over a weak nearby copy. New lines in
   the same diff and isolated stale examples do not establish a convention.
7. A change may replace an unsafe or obsolete pattern when it proves the need,
   makes the replacement discoverable, and avoids leaving accidental concurrent
   paths. A deliberate, documented divergence that leaves a clear standard for
   the next change is not convention drift.

## Review Probes

For each changed surface that can introduce or extend a convention:

1. Name the problem class and owning surface.
2. Apply the bounded standard selection above.
3. Compare only relevant dimensions from this table.
4. Ask whether the diff creates or extends a second way to perform the same
   job.
5. Test whether the divergence is required by safety, compatibility, or a
   proven weakness in the old pattern, and whether the new owner is
   discoverable.
6. Send any unjustified dual path through the normal candidate filter.

| Dimension | Compare against same-class precedent |
| --- | --- |
| Placement and ownership | Layer, package, module, dependency direction, and shared owner |
| Naming and contracts | Domain terms, units, lifecycle, tenant scope, DTOs, and public API shape |
| Errors and observability | Return/wrap style, structured diagnostics, metrics, and redaction |
| Context and resilience | Cancellation, timeout, detached work, retry, fallback, and failure visibility |
| Cache, flags, and config | Keys, defaults, TTL, invalidation, environment selection, and rollout behavior |
| Tests and generated surfaces | Test family, fixtures, mocks, assertions, source of truth, and regeneration path |
| Workflows and operator docs | Names, steps, runtime linkage, and ownership visible to operators |

The core evidence question is not "does this look different?" It is "does this
change add or extend a materially different path for a job whose current owner
already provides a standard?"

## Finding Law

Keep a candidate only when all of these are true:

- the changed line or contract creates or extends the divergence;
- current same-class evidence establishes the better standard;
- the difference creates concrete correctness, maintenance, search, refactor,
  test, observability, or operator cost;
- a bounded local correction or clearly documented intentional divergence is
  actionable; and
- no stronger lens should own the same root cause.

Typical finding shapes include a duplicate helper with different failure
semantics, a second context or logging path, unexpected ownership placement,
conflicting domain terminology, a one-off test family, or operator naming that
no longer maps cleanly to runtime behavior.

Do not flag:

- a deliberate, documented, discoverable replacement that leaves no accidental
  old/new path;
- a tiny local name improvement with no search, maintenance, or dual-path
  impact;
- a difference with no material or actionable consequence;
- an unchanged inconsistency the target neither touches nor worsens;
- the absence of a clear standard; or
- a broad architectural preference that requires a separate owner decision.

## Output

Do not add a convention-only field to parser-facing packets. Emit a surviving
candidate as a normal finding under the owning lens. In `Selected reviewer
lenses:`, name the problem classes, bounded search surface, standard state, and
disposition. A clean pass requires evidence of the dual-path search, not a bare
"conventions ok."

```text
- existing-conventions: compared controller error reporting within the owning package; one authoritative structured path, no competing sibling, changed line creates a material second path; finding emitted
- existing-conventions: compared integration-fixture ownership within the package and shared test owner; precedents conflict without material effect; no finding
```
