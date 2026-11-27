<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-11 -->

# Quality Scout

Use this lane for identifying at most three actionable repository-quality or
code-health tasks that feed the current implementation workflow.

This lane is adapted from repository-quality and skeptical code-audit workflow
patterns. Keep the focused analysis, actionability, and pressure to prevent
future defects. Do not copy recurring bot cadence, cache memory, persona/tone,
issue templates, AI disclosure text, or safe-output mechanics into
example-app code authoring.

## Mission

Find the smallest useful quality improvement surface and turn it into
actionable code-authoring work. The lane should reduce future maintenance,
validation, handoff, or production risk without becoming a generic audit
ritual.

Follow this mission sequence:

1. Pick one focus area from current repo evidence, not from a generic quality
   checklist.
2. Prefer project-specific pain over standard categories when the repo suggests
   a sharper focus.
3. Gather lightweight metrics or examples with file paths and line evidence.
4. Produce at most three actionable tasks, each with owner, scope, validation,
   and risk.
5. Route any task that should be implemented now back through the specific
   code-authoring lane that owns it.

## Ownership

This lane owns quality scouting and task shaping. It does not own final review
verdicts, broad refactors, issue creation, or implementation without a routed
code lane.

If the requested product is a durable ranked backlog, roadmap option set, or
self-contained plan for later execution, stop and route to `improve`. Do not
bounce between both owners: `quality-scout` ends by selecting current
implementation work; `improve` ends with an advisory artifact.

Use standard focus areas only when repo evidence supports them:

- code quality: complexity, code smells, maintainability, naming, dead paths
- documentation: stale README, inline comments, examples, operator docs
- testing: high-value gaps, brittle tests, missing integration seams
- security: secrets, dependency risk, access control, trust boundaries
- performance: hot paths, query shape, payload size, caching, rendering cost
- CI/CD: workflow health, feedback speed, permissions, flaky checks
- dependencies: outdated or risky packages, unpinned privileged actions
- code organization: file size, ownership boundaries, locality, navigation

## Probes

- What repeated handoff issue, slow validation loop, or confusing code shape
  would this improvement prevent?
- Which files or modules demonstrate the quality issue?
- Is the issue newly introduced, newly exposed, or longstanding background
  debt?
- Can a small implementation task improve the situation without a broad
  rewrite?
- Which validation command or authoring lane would prove the improvement
  worked?

## Triage

Keep a task only when it is:

- grounded in current repo evidence;
- specific enough for an agent or human to implement;
- scoped to one coherent change;
- likely to reduce future maintenance, handoff, test, or operator cost; and
- not better handled as an ADR, owner decision, or final read-only verdict.

Skip:

- generic quality advice without file evidence;
- broad "clean up the codebase" tasks;
- tasks that require product, security, architecture, or rollout authority
  without naming that owner; and
- repeat analysis of a focus area that was just checked unless new evidence
  makes it relevant.

## Output

```text
Quality scout:
- focus area: <repo-specific area>
- evidence: <paths, symbols, or metrics>
- tasks:
  - <task>: scope <files>; validation <command>; risk <risk>
- skipped: <adjacent focus areas and why>
```

If no task survives triage, say so plainly. A clean quality scout is useful
only when it names what was checked and why no action is worth taking now.
