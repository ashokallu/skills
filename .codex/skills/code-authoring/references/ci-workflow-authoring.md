<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# CI Workflow Authoring

Use this lane when code authoring changes GitHub Actions workflow YAML, CI
path filters, job dependencies, matrices, caches, artifacts, permissions,
runner settings, workflow scripts, or CI cost/runtime behavior.

This lane is adapted from the Agentics `ci-coach` workflow. Keep the durable
optimization and safety behavior, but do not copy scheduled automation, PR
creation mechanics, safe-output configuration, or daily scan windows into
example-app code authoring.

## Mission

Improve CI reliability, clarity, and runtime efficiency without hiding failures
or weakening the proof a PR gives reviewers.

Follow this sequence:

1. Read the affected workflow files and the package/module manifests they run.
2. Identify the concrete CI problem or optimization: slow critical path, cache
   miss, unbalanced matrix, unnecessary job, stale path filter, oversized
   artifact, timeout, permission scope, or missing local parity.
3. Estimate impact, risk, and effort before editing. Prefer high-impact,
   low-risk, small-scope changes.
4. Make the smallest workflow change that preserves failure signal and branch
   protection semantics.
5. Validate workflow syntax and the narrowest affected local command, or mark
   the exact GitHub-only proof `Pending Verification`.
6. Update operator or PR-facing docs only when workflow behavior, required
   evidence, or local reproduction commands changed.

## Ownership

This lane owns authoring changes to CI workflow files and CI-adjacent helper
scripts. It does not own live PR CI triage, Actions log collection, check-run
watching, or PR thread workflow. Use `pr-workflow` for those phases.

Defer to adjacent lanes when:

- the workflow failure root cause is unknown: use the PR CI lanes first;
- the edit changes repo scripts, local task runners, Docker compose, or dev
  setup outside CI YAML: `dx-tooling.md`;
- dependency or lockfile changes are part of the fix:
  `dependencies-and-upgrades.md`;
- permissions, tokens, secrets, OIDC, deployment environments, or third-party
  integrations change: `security-and-trust-boundary.md`; and
- test behavior, fixtures, flake policy, or assertions change:
  `test-quality.md` or `tdd-regression.md`.

## Optimization Probes

- Can independent jobs run in parallel without changing required-check meaning?
- Is a matrix balanced, or is one shard consistently the critical path?
- Are cache keys specific enough to be safe but stable enough to hit?
- Do path filters skip work only when the skipped workflow is truly irrelevant?
- Are artifacts necessary, scoped, and retained for the shortest useful time?
- Are timeouts intentional and matched to normal runtime plus failure diagnosis?
- Are permissions least-privilege for the jobs that need them?
- Does a local command still reproduce the same class of failure as CI?
- Does a workflow-dispatch or workflow-run path belong to browser/E2E or release
  validation instead of the PR-gate path?

## Anti-Patterns

- Do not add `|| true`, blanket `continue-on-error`, broad retries, or skipped
  tests to make CI green.
- Do not suppress logs or annotations that reviewers need to understand a
  failure.
- Do not optimize for a tiny runtime gain by adding opaque workflow complexity.
- Do not remove a job, path, artifact, or required proof without naming the
  replacement evidence.
- Do not loosen permissions, secrets access, branch filters, or deployment
  gates as part of an efficiency cleanup.
- Do not change source or test behavior in this lane unless that code edit is
  separately routed through the relevant code-authoring lane.

## Validation

For workflow authoring, validate the narrowest useful surface:

- syntax/static check for edited workflow YAML when available;
- local command parity for jobs that run app, backend, catalog, or E2E commands;
- path-filter reasoning from the changed-file set when filters changed;
- cache/artifact/permission reasoning from the workflow diff when live GitHub
  proof is unavailable; and
- current-head GitHub Actions proof only when the workflow must run remotely to
  prove the change.

If the workflow cannot run locally or current-head CI is not available yet, say
`Pending Verification` with the exact check name or GitHub run needed.

## Output

```text
CI workflow authoring:
- workflow changed: <path/job>
- intent: <reliability | runtime | cost | clarity | permission | parity>
- risk: <failure signal preserved? required checks preserved?>
- validation: <command/result or Pending Verification>
- reviewer evidence: <what a reviewer should trust>
```
