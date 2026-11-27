<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# API Contracts And Integrations Authoring

Use this lane for public or cross-service API behavior: REST handlers,
requesters, Server Actions, webhooks, external providers, generated clients,
protocol payloads, callbacks, pagination, status mapping, or any change where a
producer and consumer must agree across package, service, browser, CMS, or
third-party boundaries.

## Mission

Make the contract explicit before editing. A working local happy path is not
enough when older clients, generated requesters, cache layers, retries, external
providers, or operators can still exercise the old shape.

## Boundaries

This lane owns authoring the code-side contract and its local proof. Also load:

- `security-and-trust-boundary` for auth, tenant scope, secrets, CORS, cookies,
  SSRF-like fetches, user-generated content, or public exposure;
- `typescript-contracts`, `backend-codegen`, or
  `sql-migrations-and-data-contracts` when generated types or persistence
  shapes move;
- `resilience-and-fallbacks` for retries, timeouts, partial success,
  idempotency, fallback values, or best-effort paths;
- `observability-and-operations` when operators need logs, metrics, replayable
  request IDs, or runbook evidence.

Do not invent versioning, SDKs, compatibility layers, or provider abstractions
unless an existing caller, deployment sequence, or external contract requires
that ownership cost.

## Authoring Sequence

1. Name the producer, consumer, route, method, request shape, response shape,
   status mapping, auth requirement, and side effects.
2. Inspect both sides of the contract: handler/controller/requester/client,
   generated types, docs, tests, fixtures, cache keys, retry logic, and callers
   that may still send the old shape.
3. Build a compatibility matrix: old client to new server, new client to old
   server when rolling deploys matter, missing/extra/null fields, empty lists,
   pagination/cursor boundaries, and error responses.
4. Validate inputs at the boundary and normalize outputs at one owner. Do not
   scatter shape repair across unrelated consumers.
5. Keep status codes, content types, error envelopes, localization, and public
   messages consistent with local precedent.
6. Preserve idempotency and replay safety for mutations, callbacks, and webhook
   handlers; use a stable dedupe key when the external system can retry.
7. Update requesters, generated clients, docs, examples, mocks, and fixtures in
   the same slice as the source contract.

## Prevention Probes

- Can an older browser bundle, queued job, webhook retry, mobile-like client,
  stale cache, or generated SDK still call this route with the previous shape?
- Are optional fields truly optional, or did the change make a required
  invariant nullable to avoid understanding callers?
- Do success, validation error, auth error, not-found, conflict, rate-limit,
  timeout, and provider-error paths return the documented envelope and status?
- Are pagination, sorting, filtering, locale, timezone, and enum semantics
  stable across producer and consumer?
- Does the change introduce N+1 calls, larger payloads, cache-key drift, or
  sensitive data in client-visible responses?
- Does an external provider require signature validation, replay windows,
  ordering, retry semantics, or exact acknowledgement behavior?
- Are generated requesters, OpenAPI/protobuf-like specs, TypeScript contracts,
  Go structs, mocks, and fixtures all regenerated from the source of truth?

## Validation

Prefer the narrowest proof that exercises the real seam:

- contract/unit tests at the handler-requester boundary;
- integration tests for auth, error, pagination, and old/new compatibility;
- generated-code validation and compile/type-checks when contracts move;
- provider fixture or webhook replay tests with signature and retry behavior;
- a deterministic curl/browser/API smoke only when automated seam coverage is
  missing.

If a provider sandbox, live webhook replay, or old-client compatibility proof
cannot run, name the exact artifact and environment as `Pending Verification`.

## Output

```text
API contract authoring:
- contract: <producer -> consumer, route/method or provider callback>
- compatibility states checked: <old/new, missing/null/error/pagination/etc.>
- generated/docs/fixtures moved: <paths or not needed>
- proof: <test/command/artifact or Pending Verification>
```
