<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Duplication And Abstraction

Use this lane when changed code repeats logic, introduces abstraction pressure,
or may create drift-prone copy-paste.

This lane is adapted from the Agentics `duplicate-code-detector` workflow.
Keep semantic duplicate detection and actionable refactoring discipline, but do
not copy issue-creation mechanics, fixed recent-commit windows, cache paths, or
blanket test/workflow exclusions into code authoring.

## Judgment

Three similar call sites are not automatically a defect. Prefer inline clarity
until a shared helper removes real complexity or prevents likely drift.

## Ownership

This lane owns semantic duplication and abstraction pressure. It does not own
large-file splitting, performance optimization, or wording cleanup unless the
duplication itself creates maintainability risk.

Flag duplication when it:

- repeats a domain invariant, auth check, data-shape rule, SQL filter, feature
  flag rule, or error contract that can diverge
- forces future changes across multiple files for one concept
- hides inconsistent behavior behind similar-looking code
- copies test setup so heavily that assertions no longer reveal intent
- repeats 10 or more meaningful lines, or appears in three or more similar
  patterns, and the repetition can realistically drift
- creates different implementations of the same business behavior

Skip duplication comments when:

- local repetition is clearer than an abstraction
- the duplicated code is generated or fixture data
- the abstraction would need vague names, broad parameters, or optional
  behavior to serve all callers
- the repetition is standard language boilerplate, imports, exports,
  constructors, getters, or small idiomatic setup
- the finding is only textual similarity with no shared semantic behavior

When extracting, name the invariant, keep the interface small, and update tests
so the shared behavior is covered through a stable seam.

## Output Discipline

For broad duplication scans, keep only the top distinct patterns. Do not bundle
unrelated duplication into one refactor. Each proposed extraction should name
the current locations, the shared invariant, the suggested destination, and the
test seam that proves behavior stayed intact.

If no meaningful duplication survives triage, record a clean result instead of
inventing an abstraction.
