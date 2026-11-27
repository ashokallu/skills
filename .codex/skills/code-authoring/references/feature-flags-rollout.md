<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Feature Flags And Rollout Authoring

Use this lane for feature flags, modes, environment toggles, staged rollout,
experiments, kill switches, datasource switches, deployment gates, config
fallbacks, or any conditional behavior that changes runtime behavior by cohort,
environment, tenant, release, or operator command.

## Mission

Author flags as temporary runtime contracts with clear defaults, ownership,
proof for both branches, rollback behavior, and removal criteria. Flags should
reduce rollout risk, not double the number of untested production paths.

## Boundaries

Load `docs-and-operator-truth` for flag descriptions/runbooks, `ci-workflow-authoring`
for deploy or environment wiring, `api-contracts-and-integrations` when flags
change request/response behavior, `auth-permissions-identity` when cohorts or
roles matter, and `test-quality` for branch coverage. When the flag is a datasource
switch inside a cross-store migration, also load `data-migration-and-cutover`
so the phase and parity contract owns the switch semantics.

Do not add a flag to avoid deciding the correct behavior unless there is a real
rollout, compatibility, experiment, migration, or owner-approved operational
reason.

## Authoring Sequence

1. Name the flag/mode, owner, source of truth, default, environments, allowed
   values, intended lifetime, rollback/kill-switch action, and removal trigger.
2. Map the behavior matrix: flag off/on, unset/invalid value, local/CI/staging/
   production, old/new deploy, user/tenant/cohort/role, cache state, and failure
   path.
3. Keep flag evaluation centralized. Avoid ad hoc string checks or duplicated
   environment parsing across frontend, backend, jobs, and workflows.
4. Choose fail-safe defaults. Production defaults, local defaults, and test
   defaults must be explicit; an unset value should not accidentally enable the
   risky branch.
5. Update all affected branches: UI, API, jobs, cache keys, generated types,
   docs/help text, logs, metrics, tests, and rollout instructions.
6. Add cleanup criteria and avoid permanent compatibility layers unless the
   flag represents an ongoing product mode.

## Prevention Probes

- Can old code and new code observe different flag defaults during rolling
  deploy, worker lag, cached config, or browser bundle staleness?
- Does the flag alter auth, data shape, migration order, cache keys, event
  schemas, external provider behavior, or operator commands?
- Are invalid values rejected loudly rather than falling through to a risky
  default?
- Are both branches tested at the seam that owns the behavior, not only by
  snapshotting config parsing?
- Do logs, metrics, dashboards, and run summaries include safe flag/mode labels
  when operators need to diagnose rollout behavior?
- Is there a removal path, or did the change create permanent dead code and
  duplicate business logic?

## Validation

Run tests for flag off, flag on, unset/invalid, and the most important failure
state. Use integration or browser proof when the flag crosses frontend/backend
or cache boundaries. For rollout claims, mark live config readback, deployment
defaults, dashboard evidence, or owner decision `Pending Verification` unless
checked.

## Output

```text
Feature flag/rollout authoring:
- flag/mode: <name, owner, source, default, lifetime>
- behavior matrix covered: <states>
- rollback/removal: <path or Pending Verification>
- proof: <tests/config readback/docs or Pending Verification>
```
