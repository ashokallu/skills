<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-21 (grounded-explanation ownership) -->

# Zoom Out

```text
Type: owning lane
Use when: entry point, ownership, implementation location, or adjacent contracts are
          unfamiliar; or a read-only repo explanation needs several lookups
Skip when: one bounded lookup or a domain specialist already answers the question
Owns: the smallest useful system/ownership/dependency map needed to choose the next
      route, or a grounded multi-file repo explanation with no specialist owner
Does not own: broad architecture redesign, implementation, or risk authorization
Allowed side effects: bounded read-only repository/system discovery
Inputs: question/objective, candidate target, and desired decision/explanation
Exit states: mapped, explained, narrowed, blocked
Outputs: system map or grounded explanation, confidence/gaps, and next owner/terminal
         answer
Re-enter when: discovery exposes a materially different target, owner, or boundary
```

Use this as a short read-only mapping pass to decide where the requested work
lives before routing. This lane also owns read-only "explain how X works in
this repo" requests that need more than one bounded lookup and have no
specialist owner; for those, the deliverable is the grounded explanation
itself, with the System Map kept internal unless the user asked for the map.
Once the route is `code-authoring`, pre-edit
impact and source-truth mapping belongs to that skill's impact-and-source-map
lane; do not duplicate the deeper pass here.

## Process

1. Identify the entry point from the user's request: route, command, package,
   component, migration, workflow, or error text.
2. Classify the mapping shape before searching:
   - definition lookup: find the definition, owner, and key callers
   - flow tracing: follow the entry point one layer down and one layer up
   - impact assessment: find callers, importers, generated or config
     dependencies, and affected tests
   - grounded explanation: answer a read-only "how does X work" question from
     cited current files; the explanation is the deliverable and the System
     Map stays internal unless requested
3. Read the nearest relevant skill, ADR, docs, and local `AGENTS.md` if the
   subtree has one.
4. Start with focused, path-only searches for the likely symbol, route,
   command, or file. Prefer scoped searches such as `rg -l` to build a
   shortlist, then read only confirmed candidates. Use semantic, structural, or
   language-server tools when available to confirm text matches before relying
   on them. Broaden scope only when the shortlist is empty or ambiguous.
5. When the approach is unclear or precedent-sensitive, inspect a bounded slice
   of recent history for the touched path or symbol. Treat old commits as
   leads, then re-check current code before copying a past pattern.
6. Trace one layer up and one layer down:
   - callers and owners
   - data and control flow
   - auth, feature flag, environment, or rollout assumptions
   - generated code, config, SQL, mocks, feature flags, tests, and validation
     commands when they could be affected
   - API, webhook, cache, queue, scheduler, external-system, and sibling-service
     contracts when the target crosses a runtime boundary
7. Stop when you can explain where the requested change fits without expanding
   into unrelated modules. Before leaving map mode for edits, name the files or
   symbols to change, the callers or contracts relied on, and the validation
   surface. If repeated searches stop narrowing the target, change strategy or
   ask for the smallest missing input.
8. If no result is found, report the exact searches tried and one next-best
   query or alternate entry point before concluding the target is absent.

## Evidence Discipline

- State the search scope: directories, globs, symbols, and whether coverage is
  full or sampled.
- List up to about 10 highest-signal locations. If more exist, summarize the
  repeated pattern and name what was not expanded.
- Do not claim "no impact", "safe to change", or "only affects X" without
  naming the searched scope. Mark unsearched areas `Pending Verification`.
- When mapping discovers a higher side-effect, multi-repo, or external-system
  boundary, stop broadening code search and re-route through [risk-and-side-effects.md](risk-and-side-effects.md),
  [multi-repo-boundaries.md](multi-repo-boundaries.md), or [external-system-boundaries.md](external-system-boundaries.md)
  before editing.
- Prefer `path:line` plus symbol names over large code excerpts or raw command
  output.

## Output

For routing/mapping work, use:

```markdown
## System Map
- Entry point:
- Search scope:
- Key locations:
- Upstream callers:
- Downstream dependencies:
- Generated/config/test touchpoints:
- Domain terms:
- Validation surface:
- Change risk:
- Next owner:
- Pending Verification:
```

For a grounded explanation, answer the user's question directly and cite the
current paths/symbols that support each material claim. Include search scope and
`Pending Verification` only where they affect confidence; keep the internal
System Map out of the response unless the user asked for it or it materially
improves comprehension.

Use repo language. Mark uncertain claims `Pending Verification`.
