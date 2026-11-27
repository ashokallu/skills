<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-18 (decision-status and artifact fidelity) -->

# Docs And Operator Truth

Use this lane when changed behavior affects comments, docstrings, README files,
runbooks, PR text, CLI help, config flags, logs, dashboards, release notes,
operator workflows, skills, prompts, agent role files, or durable instruction
docs that future agents/humans will treat as policy.

This lane protects readers as much as reviewers and operators. Documentation
should make the codebase easy to navigate at the local, file, module, package,
and project level, but it should be authored from understanding, not eagerness.
Read nearby docs early only to inventory affected surfaces. Make documentation
changes in the final consistency pass after the implementation logic,
callers/callees, config or runtime wiring, tests, and operator path are
understood.

## Probes

- Does documentation name a migration, command, flag, default, schema, source
  of truth, or validation step that no longer exists?
- Do flag descriptions, CLI help text, allowed values, persisted enum/string
  values, log labels, operator docs, and examples use the same terms for the
  same behavior?
- Does each flag help string name the real mode and prerequisite gate where it
  is accepted, rather than a broader mode that will later reject it?
- Does a PR body or review guide omit meaningful behavior changed in the diff?
- Does a requested plan, policy, or reference preserve the exact behavior it
  was asked to record, with proposal, approved decision, phase choice, and
  execution status kept distinct?
- Do logs and run summaries make dangerous under-coverage obvious?
- Do comments or TODOs describe an old invariant, fallback, generated-owner,
  rollout sequence, auth/data boundary, cache behavior, or operator evidence
  path?
- Did the code change create or alter a local, file-level, module/package, or
  project-level contract that readers need in order to navigate the code safely?
- Would an operator know what was checked, what was skipped, and what remains
  unsafe after a capped, dry-run, sampled, or staging-only run?
- Do apply, import, audit, migration, mirror, or reconciliation errors point to
  the specific missing evidence, unsafe blocker, flag, run ID, or recovery
  action instead of collapsing into a generic count?
- Are warnings and success logs gated on the condition that actually happened,
  so logs do not claim blockers were resolved, mirror failures were surfaced,
  or safety checks ran when that path was skipped?

## Rules

- Treat misleading docs, logs, comments, and PR text as implementation defects
  when they can cause wrong review, validation, rollout, or operator action.
- Treat documentation edits as final-pass work. Do not update durable docs from
  a first-pass guess; first inspect the source behavior and the concrete reader,
  reviewer, or operator confusion the doc should prevent.
- Treat a semantically substituted requested artifact as a documentation
  defect even when its facts, citations, and formatting are correct. Before
  handoff, identify any reversed, removed, deferred, or phase-shifted behavior
  and cite the owner authority for that delta; otherwise restore the requested
  content and label its actual decision status.
- Treat flag descriptions and generated help as behavioral docs. When changing
  flags, modes, drift categories, enum values, or operator-facing labels, read
  the descriptions thoroughly and align them with persisted names, logs,
  examples, and operator prose.
  If a flag is accepted only for a sub-mode or paired flag, say that in the
  help text and examples so operators do not infer it applies to the parent
  mode.
- Treat operator README sections and runbooks as launch contracts, not
  reference prose. When code, config, or policy work will lead to a shared
  environment job, read the exact mode section before recommending the run.
  Compare each documented gate against current source and data, and stop when
  a documented gate is unproven or stale.
- Keep examples secret-safe and use placeholders for credentials.
- Do not update `Last verified` unless the behavior or command was verified.
- Mark unverified doc claims `Pending Verification` instead of presenting them
  as current.
- Keep documentation type pure when adding larger docs: tutorial, how-to,
  explanation, or reference. Split mixed content instead of creating a doc that
  is hard to maintain.
- Prefer links to source files, commands, and symbols over copied code blocks
  that will drift.
- Verify documented commands and paths with the repo before handoff. If they
  cannot be checked, name the exact command or path as `Pending Verification`.
- Update operator-visible logs and run summaries when a code path is capped,
  sampled, dry-run-only, staging-only, best-effort, fallback-driven, or
  flag-gated, so future operators do not mistake partial proof for full
  coverage.
- For best-effort mirrors and apply gates, treat log and error wording as part
  of the safety contract. A misleading warning, missing warning, or generic
  error can cause the next operator to run the wrong command or miss a real
  unresolved production-data risk.
