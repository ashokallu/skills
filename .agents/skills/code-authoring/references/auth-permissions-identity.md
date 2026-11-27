<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Auth, Permissions, And Identity Authoring

Use this lane for authentication, authorization, tenant scope, roles,
permission checks, session/cookie behavior, identity propagation, gated UI,
admin paths, learner/user data access, service accounts, or public/private API
exposure.

## Mission

Author fail-closed access behavior from the resource boundary inward. Do not let
UI hiding, requester assumptions, middleware precedent, or green happy-path
tests substitute for proof that the protected data and side effects are scoped
correctly.

## Boundaries

This lane specializes `security-and-trust-boundary`; load both when the change
can expose sensitive data, secrets, logs, workflows, third-party calls, or
supply-chain risk. Also load `api-contracts-and-integrations` for route/request
shape changes, `sql-migrations-and-data-contracts` for data filters or joins,
and `frontend-ui`/`typescript-contracts` when browser state or typed contracts
move.

Owner, product, legal, or security-policy decisions must be routed explicitly.
Do not encode a guessed policy into code and call it implementation detail.

## Authoring Sequence

1. Identify the principal, credential/session source, resource, action,
   tenant/scope, role/permission, and expected deny behavior.
2. Trace the access decision from entrypoint to data read/write: middleware,
   handler, controller/service, datasource/query, cache key, generated requester,
   UI gate, logs, and docs.
3. Put the authoritative permission check at the server/data boundary. UI gates
   are usability hints, not security controls.
4. Make deny states explicit: unauthenticated, authenticated-but-forbidden,
   wrong tenant, inactive/expired session, missing role, stale token, disabled
   feature, deleted resource, and ambiguous ownership.
5. Keep identifiers scoped. Tenant/user/org IDs used in queries, cache keys,
   jobs, logs, and events must come from trusted context or be validated against
   that context before use.
6. Prefer existing auth helpers and error/status mapping. Avoid custom cookie,
   JWT, role, or redirect logic unless local architecture requires it.
7. Update tests, fixtures, docs, runbooks, and operator notes for the exact
   permission states the code now enforces.

## Prevention Probes

- Can a user infer, fetch, mutate, export, cache, or log another tenant's data
  by changing route params, request body, query params, cache keys, or IDs?
- Does the data query include the same scope that the controller checked, or can
  a later join/load escape the checked resource set?
- Are admin, service account, preview/draft, impersonation, migration, and
  operator modes deliberately gated and auditable?
- Does fallback behavior turn auth errors into anonymous reads, public cache
  hits, default owners, or best-effort success?
- Are redirects, 401/403/404 choices, and user-facing messages consistent with
  avoiding information disclosure?
- Are tokens, cookies, headers, saved auth state, raw PII, or permission
  decisions excluded from logs, screenshots, artifacts, analytics, and PR text?
- Do generated clients, requesters, mocks, and tests preserve the server-side
  permission contract instead of bypassing it?

## Validation

Required proof for auth/permission changes includes at least one positive path
and one negative path at the authoritative boundary. Prefer tests that exercise
wrong tenant or wrong role with real query/request wiring over mocks that simply
return an error.

Useful checks:

- route/controller tests for unauthenticated, forbidden, wrong tenant, and
  allowed states;
- datasource/query tests proving tenant/user/org filters are enforced;
- browser tests for gated UI only after server-side denial is covered;
- secret/log scan or focused grep when sensitive evidence may be emitted.

If specialist security review is required by policy, keep local proof separate
and mark the owner/security sign-off `Pending Verification`.

## Output

```text
Auth/permission authoring:
- protected resource/action: <resource, action, principal, scope>
- authoritative check: <file/symbol/query/cache key>
- deny states covered: <states and tests or Pending Verification>
- sensitive-output check: <logs/errors/artifacts/docs checked>
```
