<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# API Contracts And Integration Lens

## Mission

Review cross-boundary contracts where a producer and consumer must agree:
REST/API handlers, requesters, Server Actions, generated clients, webhooks,
third-party providers, callbacks, protocol payloads, pagination, status/error
envelopes, and public/private API behavior.

## Ownership And Boundaries

This lens owns contract reachability and compatibility. It defers auth and data
exposure to `security-privacy-lens`, persistence shape to
`sql-migrations-generated-lens`, generated/source movement to the appropriate
file lens, failure handling to `silent-failure-fallback-lens`, and proof quality
to `tests-validation-lens`.

Do not emit taste findings about API style unless the current target creates a
material, reachable compatibility, correctness, security, or operator problem.

## Evidence And Dedupe

A finding needs current-target evidence for the producer, at least one reachable
consumer or external caller, and the incompatible state. Group duplicate
findings by contract root cause, not by each affected requester or fixture.

Useful evidence includes handler/requester code, generated types, route docs,
fixtures, old/new deploy path, provider docs already in repo, webhook samples,
cache keys, tests, and PR body claims.

## Review Probes

- Did the request/response shape, status code, error envelope, content type,
  pagination, sorting, filtering, locale, or enum semantics change for existing
  callers?
- Can old clients, stale browser bundles, queued jobs, webhook retries, cached
  generated clients, or rolling deploys still send the previous shape?
- Are nullable, missing, empty, duplicate, and unknown-field states handled
  deliberately by both producer and consumer?
- Do auth, not-found, conflict, validation, rate-limit, timeout, and provider
  failure paths preserve the documented status/error behavior?
- Are generated clients, TypeScript contracts, Go structs, mocks, fixtures,
  snapshots, and docs moved from the source of truth rather than hand-edited?
- For external callbacks/webhooks, are signature, replay window, idempotency,
  ordering, acknowledgement, retry, and provider timeout semantics respected?
- Does the API change expose larger payloads, N+1 fanout, cache-key drift,
  private fields, or user/tenant data beyond the intended contract?

## Triage

Promote to a formal finding when an existing or plausible caller can break,
receive misleading data, mutate the wrong resource, leak data, retry unsafely,
or be unable to diagnose a failure. Keep advisory notes for small docs/examples
or low-risk naming mismatches that do not change behavior.

## Output Discipline

When clean, the selected-lens audit should name the contract seam reviewed. When
blocked by unavailable provider, old-client, or rolling-deploy evidence, use
`Pending Verification` or Risk Evidence Handoff according to core reviewer law.
Do not paste raw provider secrets, tokens, webhook payload secrets, or PII.
