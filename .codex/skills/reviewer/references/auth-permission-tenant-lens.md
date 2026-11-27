<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Auth, Permission, And Tenant Scope Lens

## Mission

Review authentication, authorization, tenant/user/org scope, roles, sessions,
identity propagation, admin/operator modes, gated UI, service accounts, and
public/private data exposure with fail-closed skepticism.

## Ownership And Boundaries

This lens specializes `security-privacy-lens` for authorization semantics. Load
both when secrets, PII, logs, dependencies, or broader trust boundaries are
involved. Defer API shape compatibility to `api-contracts-integration-lens`,
SQL/data filters to `sql-migrations-generated-lens`, and proof quality to
`tests-validation-lens`.

Do not require a new policy decision as a reviewer finding unless current code
contradicts an existing policy, local precedent, PR claim, or owner-stated
requirement. If policy is missing and controls release safety, route it through
Risk Evidence Handoff or owner decision.

## Evidence And Dedupe

A finding needs a reachable principal, protected resource/action, scope escape
or incorrect deny/allow behavior, and current code path evidence. Group UI,
requester, server, cache, query, and docs symptoms under the same missing or
incorrect authoritative check.

## Review Probes

- Is the authoritative permission check at the server/data boundary rather than
  only in UI, requester, middleware assumptions, or docs?
- Can route params, request body, query params, cache keys, IDs, generated
  requesters, or background jobs cross tenant/user/org boundaries?
- Do unauthenticated, authenticated-but-forbidden, wrong tenant, missing role,
  expired session, inactive user, deleted resource, and ambiguous ownership
  states fail closed with safe status/message choices?
- Are admin, impersonation, preview/draft, migration, service account, and
  operator modes deliberately gated, audited, and excluded from ordinary user
  paths?
- Do caches, events, metrics, logs, screenshots, artifacts, and analytics avoid
  leaking tokens, cookies, auth state, role decisions, or raw learner/PII data?
- Does fallback behavior turn auth errors into anonymous reads, public cache
  hits, default owners, or best-effort success?
- Do tests include at least one allowed and one denied path at the authoritative
  boundary, preferably wrong-tenant or wrong-role proof?

## Triage

Missing or bypassable server-side authorization for sensitive data or mutation
is high severity unless current evidence proves no reachable path. UI-only gate
mistakes are formal findings when the server allows the action or the UI leaks
sensitive data. Pure copy or visual affordance issues are advisory unless they
cause users/operators to perform unsafe actions.

## Output Discipline

Findings should state the principal, resource/action, missing or wrong check,
reachable path, and safest fix owner. When proof depends on live policy, IAM,
identity provider configuration, or owner approval unavailable to reviewer, use
Risk Evidence Handoff rather than guessing.
