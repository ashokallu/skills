<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Feature Flag And Rollout Lens

## Mission

Review feature flags, modes, environment toggles, staged rollout, experiments,
kill switches, datasource switches, deploy gates, and conditional runtime
behavior for safe defaults, branch coverage, rollback, observability, docs, and
cleanup ownership.

## Ownership And Boundaries

This lens owns the conditional-behavior matrix. Defer auth/data/security to the
matching domain lenses, workflow/deploy wiring to `ci-workflow-infra-lens`,
failure semantics to `silent-failure-fallback-lens`, and validation quality to
`tests-validation-lens`.

Do not object to a flag merely because flags add complexity; surface it when
that complexity creates a reachable bug, unproved rollout claim, unsafe default,
or durable maintenance burden.

## Evidence And Dedupe

A finding needs current code/config/docs evidence for a flag/mode branch that
can ship with wrong behavior. Group missing tests, stale docs, and logs under
the same unsafe flag contract when they share one root cause.

## Review Probes

- Is the flag/mode owner, source of truth, default, allowed values, environment
  behavior, rollout plan, rollback/kill switch, and removal trigger clear?
- Are off, on, unset, invalid, local, CI, staging, production, old/new deploy,
  cached config, and stale browser bundle states handled deliberately?
- Are flag checks centralized and typed, or duplicated as ad hoc strings across
  frontend, backend, jobs, workflows, and docs?
- Does either branch change auth, data shape, cache keys, generated contracts,
  event schemas, provider behavior, migrations, or operator commands?
- Are invalid values rejected loudly rather than falling through to the risky
  branch?
- Do tests cover both branches and at least one failure/deny state at the seam
  that owns the behavior?
- Do logs, metrics, dashboards, PR text, and runbooks expose the active mode
  when operators need rollout evidence?
- Is the flag temporary with cleanup criteria, or intentionally a permanent
  product mode with maintained tests/docs?

## Triage

Unsafe production defaults, untested behavior branches, stale operator rollout
instructions, or missing rollback evidence can be formal findings when they
control merge or release safety. Pure cleanup reminders for temporary flags are
advisory unless the dead branch is already misleading tests or runtime behavior.

## Output Discipline

For findings, state the flag, affected branch/state, reachable runtime path,
current evidence, and proof or fix needed. For unresolved live rollout evidence,
use Risk Evidence Handoff when release safety depends on config readback,
owner-approved rollout, or post-deploy telemetry.
