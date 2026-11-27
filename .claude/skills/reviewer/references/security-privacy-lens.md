<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Security And Privacy Lens

Use this lens when the review touches secrets, tokens, cookies, auth state,
authentication, authorization, permission checks, tenant/user scope, PII or
learner data, input validation, output encoding, SSRF-like network fetches,
security headers, crypto, dependency security, public error/log content,
privacy-sensitive analytics, or security/audit documentation.

Reviewer checks code-side security evidence and obvious local exploit paths.
Deep threat modeling, penetration testing, compliance approval, cryptographic
design approval, and business-risk acceptance remain with the owning humans or
specialists.

## Review Order

Use `auth-permission-tenant-lens` for detailed authorization, tenant/user/org
scope, identity propagation, and gated-resource semantics. Keep this lens active
for broader trust-boundary, secret, privacy, input/output, dependency, and
sensitive-evidence risk.

1. Identify trust boundaries: browser, server, queue, cache, database, external
   service, webhook, workflow, operator, and generated artifact.
2. Map sensitive assets: tokens, cookies, private env vars, PII, learner
   progress, tenant data, admin-only operations, internal URLs, and credentials.
3. Trace authn/authz, input validation, output encoding, logging, caching,
   dependency, and config behavior for changed paths.
4. Prove exploitability or realistic misuse before severity escalation; keep
   speculative gaps as `Pending Verification` unless central proof is missing.
5. Route owner decisions separately when product, legal, data-governance,
   security, or infra approval controls safety.

## Secrets And Sensitive Evidence

- Do not inspect or quote actual `.env`, auth-state, private key, cookie, or
  token values unless the user explicitly requested defensive investigation of
  that exact file. Report exposure by path, key shape, and risk without values.
- Logs, screenshots, CI artifacts, Sentry payloads, browser console output,
  telemetry, fixtures, docs, and examples can leak secrets or PII. Redact or
  summarize sensitive values.
- Public errors and user-facing messages must be generic and localized where
  surrounding UI expects it. Internal detail belongs in safe logs or metrics.
- Dependency, registry, package-manager, Docker, and workflow config can expose
  credentials or redirect trusted resolution to untrusted sources.

## Auth, Permission, And Tenant Scope

- Protected routes, handlers, jobs, caches, events, and query paths must enforce
  user, tenant, organization, role, and permission scope at the data or action
  boundary, not only in UI, comments, route names, or tests.
- Background jobs, repair scripts, webhooks, and workflow dispatches often bypass
  request auth. Verify owner, input scope, dry-run or safety controls, audit
  trail, idempotency, and environment restrictions.
- Cache keys, CDN entries, generated artifacts, analytics, metrics, and logs
  must not mix private data across users, tenants, permissions, locales,
  preview/draft state, or environments.
- Missing auth, stale feature flags, malformed tokens, expired sessions, and
  partial permission data must fail closed for protected data or irreversible
  actions.

## Input, Output, And External Calls

- SQL, Mongo, GROQ, search, shell, template, URL, header, path, and redirect
  inputs need structured APIs or explicit validation. Parameterized APIs are
  still reviewable when dynamic identifiers, raw fragments, or driver misuse are
  present.
- Frontend rendering of user-generated content needs safe escaping or explicit
  sanitization. `dangerouslySetInnerHTML`, Markdown/HTML renderers, rich text,
  CMS content, and embedded URLs need caller and content-source review.
- External fetches, image optimization, webhooks, callbacks, and proxy routes
  need host allowlists, redirect behavior, timeout, response-size bounds, and
  credential handling proportional to SSRF or data exfiltration risk.
- CORS, cookies, SameSite, domains, redirect/callback URLs, and auth-refresh
  flows need old/new compatibility and safe failure behavior.

## Severity Calibration

- Critical or P1 security findings need a reachable exploit path and impact
  statement. Do not inflate severity for theoretical patterns without a path.
- Internal-only or admin-only access can reduce likelihood, but does not clear
  catastrophic impact such as cross-tenant data exposure, credential leakage,
  data loss, or privilege escalation.
- If exploitability depends on facts reviewer cannot gather read-only, use Risk
  Evidence Handoff for the exact owner, artifact, environment, or specialist
  proof needed.

## Tests And Verification

- Security-sensitive tests should cover denial paths, missing/stale auth,
  wrong tenant, insufficient role, malformed input, encoded output, retry,
  cache separation, and webhook signature failures.
- A scanner, audit, or dependency report proves only the artifact, lockfile,
  command, database version, and commit it scanned.
- For security-motivated fixes, verify the old vulnerable path would fail and
  the new guard blocks the exploit or misuse path rather than only satisfying a
  test assertion.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- missing or wrong auth, permission, tenant, role, or environment enforcement
  can expose or mutate protected data
- secret, cookie, token, private env, auth state, PII, or learner data can leak
  through source, logs, artifacts, telemetry, browser bundles, docs, or errors
- unvalidated input reaches SQL, Mongo, GROQ, shell, template, redirect, URL, or
  external fetch behavior
- cache, CDN, generated artifact, analytics, or metric key omits a sensitive
  dimension and can mix private data
- security fix lacks proof for the vulnerable path or weakens another guardrail
- dependency, workflow, Docker, or registry change introduces privileged
  execution or credential exposure without provenance and containment
