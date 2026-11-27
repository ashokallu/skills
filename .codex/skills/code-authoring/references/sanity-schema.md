<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Sanity Schema Lane

## Scope

example-app is a consumer of Sanity CMS. The schema definitions and Sanity Studio live elsewhere. This skill covers the patterns this repo uses to query, cache, and react to Sanity content. It does not cover authoring Sanity schemas.

Three surfaces touch Sanity:

1. Go backend - `backend/internal/shared/sanity/` and `backend/internal/content/cms_sanity*.go`
2. Next.js frontend - `app/data/sanity/`, `app/api/cmsRequester.ts`, and `app/utils/sanity/`
3. Webhook flow - Sanity notifies backend on content change and the backend flushes CMS plus ETag caches

## The client

`backend/internal/shared/sanity/sanity.go` exposes `Query`, `Create`, `CreateOrReplace`, `Update`, `Unset`, `DeleteByID`, `DeleteByQuery`, `RestoreToDate`, `UseCDN(ctx)`, `FlushCache(ctx)`, and `Close(ctx)`.

Gotchas:

- `Query` returns `types.ErrNotFound` when Sanity returns `""` or `"null"`
- There are dedicated rate-limited HTTP clients for mutations, queries, and CDN reads
- A GROQ query over 1 second logs at warn level

## Cache-through behavior

Wire order in `backend/services/api/main.go` is:

```text
L1 in-memory (otter)
  -> L2 Redis + HTTP
```

Rules that matter:

- Cache keys hash `query + sorted param keys + param values`
- CDN use is blocked for 5 minutes after a cache flush, so `UseCDN(ctx)` silently falls back to the non-CDN client during that window
- Cache errors are logged and swallowed

## Sanity <-> Mongo ID translation

Some content was migrated from the legacy Mongo store to Sanity. Requests still arrive with Mongo IDs in URLs, but Sanity needs Sanity IDs.

- Translator: `backend/internal/content/datasource.go :: (DataSource).SanityIDByMongoID`
- Consumer: `backend/internal/content/controller.go :: (Controller).ContentQuery`

When adding a new CMS-backed endpoint that identifies content by Mongo ID, route through `SanityIDByMongoID`. Do not rebuild the translation inline.

## GROQ query conventions

Before adding or changing a GROQ query, verify the fields, types, reference
targets, and expected result shape from repo-owned consumers, generated types,
checked-in query fragments, or a live read-only dataset query. If the deployed
schema or dataset cannot be verified, say `Pending Verification` and base the
change only on inspected repo evidence.

Query shape rules:

- Use explicit projections. Do not use `{...}` in production-facing queries
  without a specific justification.
- Bound list queries with slice operators or pagination. Do not add unbounded
  high-cardinality result sets.
- Filter drafts out of public-facing reads unless the caller is explicitly a
  preview/editor workflow.
- Resolve references intentionally with `->` only for fields the consumer
  needs; avoid pulling full referenced documents by default.
- Return and type the smallest shape that satisfies the consumer. Include
  `_id` and `_type` when they are needed for evidence, cache keys, or result
  discrimination.
- For every changed query, write or record the expected result shape. Keep the
  TypeScript, Zod, Go DTO, or consumer contract aligned with the projection.
- If user input influences a GROQ query, validate the parameter before it
  reaches the query and pass it as a parameter, never through string
  interpolation.

### Backend

GROQ query strings live in `backend/internal/content/cms_sanity_queries.go`.

- Project only the fields you need
- Use Sanity parameters like `$paramName`
- Do not string-interpolate user input into the query
- Validate or normalize user-controlled parameters before they reach GROQ

### Frontend

Frontend GROQ helpers live in `app/data/sanity/`.

- Put new fragments in the right `data/sanity/*.ts` file
- Type response shapes with Zod where the data flows into rendering
- Use `app/utils/sanity/image-builder.ts` for image URLs

## Live Dataset Queries

Use live GROQ queries when a review or migration decision depends on whether a
document exists in a specific Sanity dataset. Do not infer target document IDs
from Mongo alone.

Find the project and dataset from Terraform before querying:

- staging: `infrastructure/stg/main.tf` currently uses project `fuvbjjlp` and
  dataset `app-staging`
- production: `infrastructure/prd/main.tf` currently uses project `fuvbjjlp`
  and dataset `app-production`

Prefer the repository's configured Sanity client when writing application code.
For one-off read-only verification from an agent shell, call the Sanity query
API with a bearer token from the environment or Secret Manager without printing
the token. Keep tokens out of command arguments, logs, PR comments, and docs;
use stdin, environment variables scoped to the process, or a short script that
sets the Authorization header internally.

When checking Mongo-to-Sanity mappings, query the target document type by
`mongoID` and project only the fields needed for evidence:

```groq
*[_type == "xp-category" && mongoID in $mongoIDs]{
  _id,
  _type,
  title,
  mongoID
}
```

Treat unmatched source Mongo IDs as data findings, not automatic schema or
mapping bugs. They need a real target document in the queried dataset before
code should map them to a Sanity ID.

## Mutations and Dataset Safety

Repo work should prefer read-only Sanity checks. Any mutation, bulk patch,
delete, restore, or schema/data migration needs explicit scope, environment,
and rollback evidence before apply:

1. Confirm project and dataset from configuration or the client before the
   mutation. Production datasets require explicit user confirmation.
2. Run a dry-run or equivalent preview first when the API supports it, then
   compare the affected document count and sample IDs against the request.
3. Confirm backup/export or rollback steps before applying changes.
4. Apply only after explicit user approval of the dry-run scope.
5. Verify results with a read-only query and keep tokens, full document
   payloads, and PII out of logs, command arguments, PR comments, and docs.
6. For production datasets, require the dataset name to be explicitly confirmed
   after the dry-run scope is reviewed.

## Webhook flow

Source of truth: `backend/internal/content/controller.go :: (Controller).SanityCMSWebhook`.

1. Sanity signs the webhook payload with HMAC-SHA256
2. The handler calls `c.cms.FlushCache(...)`
3. The handler calls `c.cache.DeleteMatching(..., "etag.*")`
4. Both must succeed or the cache goes stale

Do not add a new CMS-cached endpoint whose ETag key prefix is outside `etag.*`.

## Adding a CMS-backed endpoint

1. Add the GROQ fragment to `backend/internal/content/cms_sanity_queries.go`
2. Add orchestration in the controller and translate Mongo IDs if needed
3. Register the route in `(*RESTService).RegisterRoutes`
4. Add an endpoint test
5. Confirm webhook invalidation still covers the ETag key

## Anti-patterns

- Calling the Sanity HTTP API directly from a controller or handler
- Interpolating user input into a GROQ string
- Using `{...}` or unbounded list queries in production-facing GROQ
- Exposing drafts through public-facing queries
- Adding a cache key prefix that `SanityCMSWebhook` does not invalidate
- Fetching CMS content inside a DB transaction
- Using the CDN client immediately after a mutation or flush
- Running Sanity mutations without dataset confirmation, dry-run or preview,
  rollback evidence, and explicit approval

## References

- `backend/internal/shared/sanity/sanity.go`
- `backend/internal/shared/sanity/sanity_cache.go`
- `backend/internal/shared/sanity/validator.go`
- `backend/internal/content/cms_sanity.go`
- `backend/internal/content/cms_sanity_queries.go`
- `backend/internal/content/controller.go`
- `backend/internal/content/rest_service.go`
- `app/api/cmsRequester.ts`
- `app/data/sanity/*.ts`
- `app/utils/sanity/image-builder.ts`
