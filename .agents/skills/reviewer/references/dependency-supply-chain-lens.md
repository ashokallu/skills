<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-17 -->

# Dependency And Supply-Chain Lens

Use this lens when the review touches manifests, lockfiles, package-manager
config, Go modules, Docker images, GitHub Actions, Terraform providers, codegen
tools, vendored code, binary artifacts, registry config, SBOM/scanner output, or
any new third-party runtime/build/deploy dependency.

## Review Order

1. Identify every dependency or toolchain surface that changed, including
   transitive lockfile churn and scripts.
2. Classify each change as runtime, dev/test, build, codegen, deploy, workflow,
   infra, or documentation-only.
3. Check provenance, pinning, integrity, registry/source, license/security policy
   when applicable, and rollback/removal path.
4. Map execution authority: install scripts, build scripts, CI secrets, deploy
   credentials, generated code, and cloud permissions.
5. Ask for scanner/SBOM/provenance evidence only when it materially affects the
   verdict.

## Manifests And Lockfiles

- Review manifest and lockfile together. A manifest-only or lockfile-only change
  needs a reason unless the package manager's behavior explains it.
- Flag unexplained broad churn, cross-ecosystem churn, wrong package manager,
  removed integrity pins, registry changes, package source changes, lifecycle
  script enabling, peer-dependency overrides, or dependency downgrades.
- New runtime dependencies need a reachable need, local owner, exit/removal path,
  bundle/runtime impact review, security/license acceptability when required by
  policy, and validation of the changed behavior.
- Dev/test dependencies still matter when they run in CI with secrets, generate
  code, publish artifacts, run browser automation, or affect deploy output.
- Do not accept a dependency because it is popular. Review the reachable use and
  authority it receives in this repo.
- Passing tests do not prove a dependency is behavior-compatible. Review release
  notes, upgrade guides, and current usage for silent default changes such as
  timeouts, retry policy, error handling, telemetry, logging, parser behavior,
  cache semantics, algorithm choice, or deprecation warnings.

## JavaScript / React / Next.js Dependencies

- Verify React, React DOM, Next.js, TypeScript, ESLint/Biome, testing libraries,
  Playwright, bundlers, and framework plugins are version-compatible with repo
  package files and CI Node version.
- Next.js 16 requires updated assumptions around Turbopack, removed `next lint`,
  async APIs, image config defaults, proxy/middleware, and cache APIs. Dependency
  bumps that cross those boundaries need migration evidence.
- Check package scripts for lifecycle hooks: `preinstall`, `install`,
  `postinstall`, `prepare`, `prepack`, `build`, `generate`, `test`, `deploy`,
  and release commands.
- Registry and auth config (`.npmrc`, pnpm/yarn/npm settings) must not expose
  tokens or redirect package resolution to untrusted sources.
- Bundle-size and client-runtime impact matters when a new dependency reaches
  browser code, Server Components serialization, middleware/proxy, or edge-like
  paths.
- Framework and library upgrades that change defaults need critical-path spot
  checks for auth, data handling, routing, caching, serialization, and error
  behavior, not only "breaking changes" sections.

## Go Modules And Toolchains

- Review `go.mod`, `go.sum`, `go.work`, `toolchain`, replace directives,
  vendored code, private module config, and CI Go images together.
- `replace` directives, local paths, forks, pseudo-versions, and private modules
  need owner rationale and removal path.
- `go` and `toolchain` lines control which language/tool behavior is available;
  do not assume Go 1.26 behavior when CI or module files pin older versions.
- `go.sum` churn should correspond to module graph changes. Broad unexplained
  checksum churn or missing sums can signal wrong tool/version or tampering.
- Generated code tools and `go generate` dependencies are supply-chain surfaces
  when they run in CI or produce committed code.
- Native/cgo dependencies require platform, linker, image, security, and runtime
  compatibility review.

## GitHub Actions, Docker, Terraform Providers

- Actions and reusable workflows should be pinned appropriately for their
  authority. Privileged actions with write/deploy/cloud secrets need stronger
  pinning and provenance than low-risk read-only actions.
- Docker images should use trusted sources and pins/digests where policy or risk
  requires. Mutable `latest`-style tags are high risk for builds or deploys.
- Terraform providers and modules need version pinning, source trust, state
  compatibility, plan evidence, and rollback path for risky infra changes.
- Downloaded binaries, curl-pipe-shell installers, checksums, and signature
  verification are material when tools run with repo secrets or deployment
  authority.

## SBOM, Scanners, And Vulnerability Evidence

- Scanner output is evidence for the artifact, commit, lockfile, and database
  version it actually scanned. Do not generalize stale or unrelated scans.
- Missing scanner/SBOM output is `Pending Verification` unless the changed
  dependency or privileged execution path makes proof central; then use
  `BLOCKED`.
- Vulnerability exceptions need owner, affected package, reachability, mitigation,
  expiry/revisit date, and removal/upgrade path when required by policy.
- Low severity transitive issues should not drown out reachable high-authority
  execution paths.

## Provenance, Secrets, And Integrity

- No dependency, lockfile, package-manager config, Dockerfile, action, or doc
  should expose tokens, saved auth state, cookies, private registry secrets, SSH
  keys, or internal URLs that policy treats as sensitive.
- Check for typosquatting, maintainer/source changes, package rename/split,
  abandoned packages, prebuilt native binaries, optional dependencies, and
  platform-specific install behavior when the change is material.
- Generated artifacts from dependency upgrades need source-of-truth proof and
  downstream review.
- A dependency that materially expands execution surface without provenance,
  pinning, owner rationale, validation, and rollback/removal path triggers the
  reviewer core's "dependency/toolchain/container/action/provider/lockfile"
  hard blocker when it can affect production or privileged workflows; this
  lens does not add a new blocker beyond that core rule.
- Sparse or unclear release notes on a major upgrade are risk evidence, not a
  reason to assume compatibility. Mark behavior changes `Pending Verification`
  or request source/changelog/runtime proof when they affect hot paths, auth,
  data, build output, or deploy tooling.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- dependency or tool can run with secrets/write/deploy authority without safe
  pinning/provenance
- lockfile churn is unexplained, from the wrong tool, or removes integrity
  protection
- new runtime dependency lacks reachable need, owner, validation, or exit path
- upgrade can silently change runtime defaults, telemetry, errors, performance,
  or data handling without changelog/runtime proof
- package registry/source config can leak credentials or resolve from untrusted
  sources
- Go module replacement, pseudo-version, toolchain, or generated-code tool makes
  builds non-reproducible or unsafe
- scanner/provenance evidence is missing where dependency risk is central
