<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-14 (bounded same-class authoring) -->

# Existing Conventions

Use this lane before authoring a change where the repo may already have a
pattern for the same kind of problem. Its job is to stop agents from inventing
a new local dance when the codebase already defines architecture, naming,
ownership, tests, validation, and operational shape.

## Mission

Find how example-app already solves this class of problem, then align the
implementation with that precedent unless current evidence proves a narrower or
safer divergence is needed.

## Boundaries

This lane owns convention discovery and fit. It does not overrule correctness,
security, production safety, or explicit product requirements. If the existing
pattern is unsafe, stale, or a bad fit for the current requirement, do not copy
it blindly. State the divergence, why the old pattern is insufficient, and what
evidence supports the new shape.

Do not turn this lane into broad architecture archaeology. Search only enough
to identify the relevant local convention and make the next edit honest.

When no clear standard exists, do not invent one and present it as repo
convention. Choose the smallest requirement-backed local shape, or defer the
ownership decision when it materially affects future implementations.

## Bounded Standard Selection

1. Name the problem class and owning surface narrowly, such as controller
   error reporting, package-level integration fixtures, or workflow
   environment selection. Do not search under labels such as "backend code."
2. Search the closest owning package, module, test family, shared helper, or
   operator surface first. Include the proposed change and enough current
   siblings to detect a competing owner or pattern.
3. One authoritative owner is sufficient after a bounded search finds no
   current competing owner pattern in that surface.
4. Require multiple precedents only when the first is not authoritative, the
   change challenges an established pattern, or current precedents conflict.
5. When evidence conflicts, broaden only to the nearest shared owner needed to
   resolve it. Stop at an authoritative standard, a justified divergence, or
   no clear standard; do not perform repository-wide archaeology.
6. Prefer the strongest current owner over a weak nearby copy. New lines in the
   same change and isolated stale examples do not establish convention.
7. A replacement for an unsafe or obsolete pattern must prove the need, make
   the new owner discoverable, and migrate or retire the old path so the change
   does not leave accidental concurrent ways to perform the same job.

## Authoring Sequence

1. Apply the bounded standard selection above before editing.
2. Extract only the convention dimensions relevant to the planned change:
   - file/module placement and ownership boundary;
   - naming, terminology, prefixes, suffixes, units, and domain words;
   - caller/callee shape, dependency direction, and public contract;
   - error, logging, metrics, fallback, retry, and context propagation pattern;
   - test fixture, mock, assertion, generated-code, and validation pattern;
   - config, feature flag, environment, workflow, or operator-documentation
     pattern.
3. Ask the core question: would this change create or extend a materially
   different path where a current owner already provides a standard?
4. Select the implementation action: conform, narrow, replace, intentionally
   diverge, or defer because no material standard is established.
5. Edit with the smallest shape that fits the current requirement and does not
   leave an accidental second path.

## Prevention Probes

Ask these before editing:

- Which existing file or sibling feature would a maintainer expect this change
  to resemble?
- Does the new name use the same domain term, unit, state word, and ownership
  boundary as nearby code?
- Is the new helper, abstraction, flag, config, fixture, or workflow already
  represented by an existing helper or pattern?
- Did the search establish an authoritative owner, or only collect nearby
  copies that happen to look similar?
- Does the change live at the same layer as similar behavior, or did it move
  policy into a caller, UI, test, script, or doc that does not own it?
- Are tests using the same fixture and assertion style as the surrounding
  package, or did they create a one-off proof shape?
- Does the implementation introduce a new branch, wrapper, dependency, or
  fallback where existing code uses a direct path?
- If this replaces an old pattern, will the old and new paths remain reachable
  at the same time, and is that overlap intentional and bounded?

## Divergence

Divergence from local convention is allowed only when at least one is true:

- the existing pattern is unsafe, deprecated, or contradicted by current source;
- the requirement changes the contract in a way sibling examples do not cover;
- the smaller conforming change would preserve a known bug;
- security, production-data safety, generated contracts, or public API
  compatibility require a different shape.

When diverging, record the old convention, the new shape, and the evidence that
the divergence is intentional. Add documentation only when future readers would
otherwise copy the old pattern into the new case.

A deliberate replacement is not convention drift when the stronger new owner
is discoverable and callers are migrated without leaving an accidental old/new
split. If temporary coexistence is required, name its owner, exit condition,
and proof instead of treating both paths as equally valid convention.

## Output

Keep the convention check short in the code-change todo or handoff:

```text
Existing conventions:
- problem class and owning surface: <narrow job and current owner>
- bounded evidence/search scope: <files, symbols, siblings, or shared owner>
- standard state: <authoritative | conflicting | no clear standard | justified divergence>
- selected implementation action: <conform | narrow | replace | diverge | defer>
- concurrent-path disposition: <none | intentionally migrated | explicitly unresolved with reason>
```
