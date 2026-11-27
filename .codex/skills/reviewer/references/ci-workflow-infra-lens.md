<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-02 -->

# CI, Workflow, Infrastructure, And Local-Dev Lens

Use this lens when the review touches GitHub Actions, reusable workflows,
package scripts, Docker, Compose, devcontainers, Terraform, Helm/Kubernetes,
release automation, hooks, local-dev tooling, CI validation, environment config,
monitoring, or agent workflow files that can execute commands or affect merge,
deploy, or developer behavior.

Reviewer checks code-side and workflow-side safety. Product, security,
infrastructure, data, and release owners still own approvals that reviewer cannot
make.

## Review Order

1. Identify what can execute, where it runs, and which actor/event triggers it.
2. Map secrets, tokens, OIDC/IAM, write permissions, deploy authority, artifacts,
   caches, and external services reachable from the change.
3. Check fork, PR, branch, tag, schedule, and manual-dispatch behavior.
4. Check validation fidelity: does the workflow prove the changed behavior or
   only report a green status?
5. Check rollback, environment targeting, branch governance, and local-dev-only
   constraints.

## GitHub Actions And CI Security

Scrutinize these as high-risk surfaces:

- `pull_request_target`, `workflow_run`, `repository_dispatch`, `workflow_call`,
  `schedule`, and manual `workflow_dispatch` with privileged inputs
- `permissions: write-all`, broad write scopes, package publishing, deployment,
  issue/PR mutation, or protected-branch effects
- fork PRs receiving secrets, tokens, cloud credentials, or privileged artifacts
- checking out attacker-controlled refs before running privileged steps
- artifact download/use from untrusted workflows or previous jobs
- cache restore keys that let untrusted branches poison privileged builds
- shell interpolation of PR titles, branch names, commit messages, issue bodies,
  file paths, matrix values, or user-controlled inputs
- unpinned privileged actions, containers, scripts, or installers
- OIDC subject/audience conditions that are broader than intended
- environment protection, concurrency, and deployment approval bypasses

A workflow path that can run untrusted code with secrets, write tokens,
deployment credentials, or protected-branch effects triggers the reviewer
core's "privileged workflow or supply-chain path" hard blocker unless the
current diff proves containment; this lens does not add a new blocker beyond
that core rule.

## Validation Fidelity

- A green check proves only the command, target, environment, commit, and inputs
  it actually ran. Inspect workflow filters, paths, matrix, test filters, caches,
  skipped steps, `continue-on-error`, and conditional gates.
- Do not accept a status summary when the changed package, route, migration,
  generated source, or workflow branch was not exercised.
- Required checks must run on the right event and head/base. PR status from a
  stale head or different merge base is stale-prone evidence.
- Terraform Cloud and SAST/security provider checks can be base-gated. In
  example-app, some provider checks run only when the PR base is `main`, not
  while the same branch is a stacked child PR targeting a parent branch. If a
  stacked PR is retargeted to `main`, re-read the provider checks on the new
  base before issuing a final merge-readiness or review-clean claim.
- `continue-on-error`, `|| true`, broad `if: always()`, suppressed exit codes,
  no-op jobs, and artifact-only success can make wrong-green CI.
- If a useful check cannot run in read-only review, request exact current logs,
  check name, job URL/artifact, head SHA, and expected proof.

## Build, Package Scripts, And Next.js 16 Tooling

- Package scripts can be privileged execution paths. Inspect install, prepare,
  postinstall, build, codegen, lint, test, preview, deploy, and release scripts
  together with dependency and lockfile changes.
- Next.js 16 uses Turbopack by default for many builds. Check custom webpack,
  loaders, aliases, PostCSS, dynamic imports, native modules, and build flags for
  parity or explicit opt-out.
- `next lint` is removed in Next.js 16; lint validation must call the configured
  tool directly rather than assuming `next build` ran lint.
- Next.js 16.2 dev-server lock files and browser-log forwarding are dev aids, not
  proof of a passing browser flow. Logs can contain sensitive data; do not quote
  secrets or full auth state.
- Native TypeScript config, generated route types, or build adapter changes need
  evidence that local and CI commands use the same config path.

## Docker, Compose, And Devcontainers

- Check base image provenance and pinning, digest versus mutable tag, OS package
  install scripts, curl-pipe-shell, user/root, exposed ports, copied secrets,
  build args, and layer caching of sensitive files.
- Ensure `.dockerignore`/context changes do not include env files, credentials,
  auth-state files, local backups, gitignored scratch outputs, or large artifacts.
- Runtime containers need health checks, non-root where expected, resource limits,
  signal handling, graceful shutdown, and clear environment requirements.
- Compose/devcontainer changes should not silently point developers at production,
  shared cloud resources, or privileged credentials.
- Local-only conveniences must be labeled and scoped so they cannot be reused in
  CI/prod by accident.

## Terraform, Cloud, And Infrastructure

- Require project/environment clarity, state workspace, provider version, IAM
  blast radius, resource naming, secrets handling, cost/quota impact, and apply
  ordering.
- When a PR removes or stops passing module inputs, compare the module defaults
  and peer environment overrides before treating the change as narrow. A scoped
  infra PR must not silently re-enable jobs, storage, exports, services, cache,
  tiers, or cost-bearing resources through default fallback.
- Provider constraints, backend settings, and root-module pins are part of the
  deploy contract. Do not let an unrelated infra change drop explicit provider
  version bounds or environment-specific pins without a migration rationale.
- README, module examples, variable descriptions, and PR body claims must match
  actual Terraform defaults and environment overrides. Documentation that says a
  resource is excluded while defaults create it is a material review signal.
- Check destroy/recreate behavior, force replacement, public exposure, ingress,
  egress, storage retention, backups, encryption, logging, and monitoring.
- Validate-only requests stay read-only: inspect config and plan evidence, then
  return a verdict and required deltas. Never make file edits from this lens or
  the reviewer role; route any needed infra change to `code-authoring`
  instead.
- New infrastructure, larger tiers, per-request billing, data egress, idle
  capacity, or nonlinear scaling need cost evidence proportional to risk.
  Missing cost or quota proof is central when it can control rollout, approval,
  or rollback.
- OIDC, service accounts, roles, buckets, queues, DNS, certificates, and deploy
  credentials need least-privilege reasoning and owner approval when merge safety
  depends on authority reviewer does not own.
- Terraform plan/apply evidence is central for risky infra. If unavailable and
  the change can affect production, use `BLOCKED` or route to infra specialist.
- For any request to analyze, validate, summarize, approve, or risk-assess a
  Terraform plan log for Test/Integration, Staging, or Production, run the same
  deep-pass workflow for all environments before giving an apply recommendation.
  Environment changes affect shared infrastructure and can later be promoted, so
  do not treat non-Production plan logs as safe shortcuts.
- A Terraform plan summary is not an apply-safety verdict. `0 to destroy`,
  small resource counts, or apparently routine Cloud Run updates do not prove
  feature flags, runtime env vars, image ownership, secret versions, or
  replacement edges are safe. If the supplied log omits attribute-level diffs,
  classify the missing attributes as `Pending Verification` and ask for the
  JSON/full plan artifact or the environment Terraform state before concluding.
- For each changed Terraform resource, build a resource/attribute risk ledger:
  planned action, desired value from current source, Terraform state value or
  `Pending Verification`, live provider value when safe to inspect, planned
  value, and apply impact. Use `origin/main` for source comparison when the
  plan is for the latest merged environment configuration; do not rely on a
  stale local branch, a PR branch, or a remembered config value.
- Cloud Run service and job updates require a runtime-config deep pass. Compare
  desired and live env vars, feature flags, image or digest/tag ownership,
  revision labels, traffic, timeout, retries, CPU/memory, VPC settings, service
  accounts, and secret references before saying apply is safe. A Cloud Run
  template update can create a new revision and can roll back live flags or
  images even when no destroy is planned.
- Known high-risk class: Terraform can roll back live feature flags or runtime
  env vars when source config no longer matches manually deployed or previously
  applied live state. XP migration flags are not special-cased by Terraform;
  they must be reviewed like any other Cloud Run env var by comparing source,
  state, plan, and live GCP state.
- GitHub APIs, GitHub MCP, the GitHub connector, and the user's GitHub token do
  not provide Okta-authenticated access to Terraform Cloud or SAST provider
  details. If provider UI/log access is blocked, mark that evidence `Pending
  Verification` and ask for copied logs, screenshots, exported artifacts, or,
  for Terraform state evidence, stop the state-dependent review until the user
  supplies a manually downloaded local state file path. Test states are
  available to the user at
  `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-test/states`;
  Staging states are available to the
  user at
  `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-stg/states`;
  Production states are available at
  `https://app.terraform.io/app/example-org/workspaces/example-terraform-services-prd/states`.
- Do not run Terraform CLI commands that require Terraform Cloud auth, private
  module registry auth, remote state, plan, or apply without a user-provided
  authenticated path for the current session. Local source inspection and
  `terraform fmt -check` can still be used as partial evidence.
- Do not treat a formatting-only Terraform diff as safe until provider/schema
  behavior and generated plan are clearly irrelevant.
- Feature flags, modes, datasource options, and runtime config need environment
  matrix proof. A claimed inert rollout is not proved by the intended happy path
  alone; compare enabled, disabled, configured, and unconfigured states for each
  environment the PR wires or documents.

## Branch, Release, And Local-Dev Governance

- Keep local-dev-only workflow and agent/instruction changes on the proper
  local-dev branch unless the user explicitly requests otherwise.
- Review branch filters, tag filters, environment names, concurrency groups,
  release notes, version bumps, changelog generation, and rollback jobs.
- A PR body or workflow label that misstates which environment will be deployed
  is material when it can mislead reviewers or operators.
- Do not let gitignored temp files, local backups, worktree-only artifacts,
  captured scratch outputs, or machine-specific paths become durable guidance.
- Hook/pre-commit reviews stay read-only on the provided target. Do not invent
  hook schemas, bypass policies, or background execution behavior.

## Observability, Rollout, And Recovery

- Deployment or workflow changes need safe logs, metrics, alerts, dashboard
  links, rollback steps, and post-deploy validation proportional to risk.
- Cloud Run jobs, schedulers, and release gates need timeout, retry, shutdown,
  idempotency, resource sizing, secret/IAM scope, and operator runbook evidence
  proportional to the production data or service blast radius.
- Logging must not expose secrets, tokens, cookies, saved auth state, full URLs
  with sensitive query params, or learner/user PII.
- Rollout gates should fail closed when artifacts, checks, or environment
  approvals are missing.
- Hidden deploys, silent environment targeting changes, or generated release
  notes that omit material operational risk are reviewable.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- privileged workflow can run untrusted code with secrets or write/deploy tokens
- infra change can create material cost, quota, idle-resource, or nonlinear
  scaling risk without owner-visible estimate or approval path
- CI check can pass without exercising the changed behavior
- branch/environment filter deploys or validates the wrong target
- Docker/build context exposes secrets or changes runtime authority unsafely
- Terraform/cloud change lacks plan, environment clarity, least privilege, or
  rollback proof when production impact is possible
- Cloud Run job, scheduler, release gate, or operator runbook can run with unsafe
  timeout/retry/IAM/resource settings or can authorize production action without
  bounded evidence
- Next.js or package-script validation claims rely on removed or wrong commands
- local-dev instruction changes can leak into durable prod/CI behavior
