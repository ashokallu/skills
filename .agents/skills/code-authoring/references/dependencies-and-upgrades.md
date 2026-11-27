<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Dependencies And Upgrades

Use this lane when code authoring changes package versions, lockfiles,
generated dependency metadata, package managers, build tools, GitHub Actions,
container images, or runtime libraries.

This lane preserves the useful dependency-management workflow from the Copilot
dependency agent. It does not preserve Copilot report templates, handoff
tables, or fixed artifact locations.

## Mission

Upgrade dependencies safely with minimal diffs, documented behavior risk,
security evidence, and a rollback path.

Follow this sequence:

1. Identify the owning scope and package manager:
   `app/` uses Yarn v1, `backend/` uses Go modules, and `e2e/pd/` uses npm.
2. Read the current manifest, lockfile, and nearby CI/install commands.
3. Review official release notes or changelogs before upgrading minor or major
   versions. Mark unavailable release evidence `Pending Verification`.
4. Apply the smallest viable upgrade. Do not batch unrelated major upgrades.
5. Let the package manager update lockfiles. Never hand-edit `yarn.lock`,
   `go.sum`, or `package-lock.json`.
6. Run security and behavior checks appropriate to the changed scope.
7. Record rollback files and verification commands before handoff.

## Behavior-Change Detection

Passing tests do not prove a dependency is behavior-compatible. Check for:

- changed defaults such as timeouts, retries, serialization, auth handling, or
  environment variables;
- thrown-vs-returned errors, nullability changes, warnings, or deprecations;
- transitive dependency additions, lifecycle scripts, telemetry, or native
  binaries;
- performance-sensitive behavior such as cache policy, bundle size, query
  execution, or network fanout; and
- security changes, advisories, or newly introduced high/critical
  vulnerabilities.

Treat auth, data handling, persistence, generated contracts, and major version
bumps as high risk until proven otherwise.

## Required Checks

Choose the narrowest commands that prove the changed scope, then broaden when
the package affects shared runtime behavior.

- Frontend: inspect `app/package.json`; use Yarn commands from `app/`; include
  lint, type-check, test, build, or browser smoke based on risk.
- Backend: inspect `backend/go.mod`; use Go module commands from `backend/`;
  include targeted tests, `go test`, generated output checks, or vulnerability
  scanning based on risk.
- E2E: inspect `e2e/pd/package.json`; use `npm ci` and the relevant Playwright
  script when test runner dependencies change.
- Security scans: run available repo audit/vulnerability commands, or record
  the unavailable scanner and exact follow-up.

## Boundaries

- Do not introduce a new package manager into a scope that already has one.
- Do not add dependencies to avoid writing small local code unless the new
  dependency has clear durable value and security posture.
- Do not downgrade to avoid a security fix without explicit owner approval.
- Do not suppress warnings, failing tests, or type errors caused by an upgrade
  without proving the suppression is safe.

## Output

```text
Dependency authoring:
- scope: <app | backend | e2e | workflow | image>
- change: <package old -> new or tool change>
- behavior risk: <low | medium | high, with reason>
- security scan: <command/result or Pending Verification>
- rollback: <files/commands>
```
