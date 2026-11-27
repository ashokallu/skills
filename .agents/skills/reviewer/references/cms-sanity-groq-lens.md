<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-17 -->

# CMS, Sanity, And GROQ Lens

Use this lens when the review touches Sanity CMS schemas, GROQ queries, generated
Sanity types, content datasource/cache/webhook behavior, draft or preview mode,
CMS mutations, dataset/project config, or docs that future reviewers will use for
CMS data work.

Reviewer checks query safety, result-shape correctness, public-content
boundaries, and mutation guardrails. Schema design, content ownership, and
production CMS operations still require the appropriate owner or specialist.

## Review Order

1. Identify the source of truth: checked-in schema, generated types, GROQ string,
   backend datasource, frontend requester, cache/webhook path, or runbook.
2. Verify every queried field, reference target, and projected result shape
   against the schema or generated type that the reviewed code actually uses.
3. Map consumers: frontend components, backend content services, caches, search
   indexes, preview/draft flows, tests, and documentation.
4. Check public versus draft visibility, dataset/project targeting, query
   bounds, reference expansion, cache invalidation, and mutation safety.
5. Classify missing schema, dataset, dry-run, rollback, or consumer proof as
   `BLOCKED` when it controls data safety, public content correctness, or
   operator handoff safety.

## Schema And Result Shape

- Field names, document types, array shapes, reference targets, slug paths, and
  optional fields must match the checked-in schema or generated type.
- Generated Sanity types are source-derived artifacts. Do not accept manual edits
  unless the generator source and regeneration proof move with them.
- Result-shape changes need consumer review. A query that returns `null`, an
  array instead of a singleton, missing references, draft fields, or renamed
  projections can strand UI or backend code even when GROQ syntax is valid.
- Public docs or tests that show a query should include the expected result
  shape when consumers depend on it.

## GROQ Query Safety

- Prefer explicit projections. `{...}` or broad projections need a current,
  local justification because they can over-fetch private fields and create
  brittle result shapes.
- List queries need bounded slices, stable ordering, pagination, or proof that
  the result set is intentionally tiny. A bounded response payload is not proof
  that filters, joins, dereferences, or aggregates are bounded.
- Check draft filtering for public paths: public queries must exclude
  `drafts.**` unless preview mode or an authenticated editor flow proves it is
  intentional and contained.
- Validate user-provided GROQ parameters before interpolation or query assembly.
  Manual string concatenation, raw slug insertion, locale filters, or dynamic
  field names are reviewable injection and correctness risks.
- Reference expansion should be intentional and minimal. Deep `->` chains,
  nested arrays, reverse references, and count/aggregate queries need scale and
  null-shape review.

## Cache, Webhook, And Consumer Semantics

- Content cache keys and invalidation must include dataset, locale, preview or
  draft mode, tenant/user/permission dimension when relevant, and every query
  input that can change visible content.
- Sanity webhooks or re-indexing paths need signature/secret handling,
  idempotency, retry behavior, stale content visibility, and safe logging.
- Preview and draft flows must not leak draft content into public caches, static
  props, browser logs, serialized state, or unauthenticated responses.
- Backend content datasource changes need old/new result compatibility across
  rolling deploys and stale cache entries.
- Frontend consumers need loading, empty, missing-reference, and stale-content
  behavior when CMS content is optional or remotely mutable.

## Mutation And Dataset Safety

- CMS mutations, schema migrations, or bulk patches require dataset/project
  identity, dry-run or preview evidence, backup/export or rollback story,
  explicit scope, and owner confirmation before apply.
- Production dataset writes are production blast-radius triggers. Reviewer
  should not pass them without bounded evidence for affected document count,
  idempotency, rollback, and post-apply verification.
- Logs and reports should identify documents by `_id`, `_type`, counts, and
  safe summaries. Do not quote full production document content, tokens, or
  private fields into durable artifacts.
- If the reviewed repo only consumes schemas maintained elsewhere, flag stale or
  unverified schema assumptions as `Pending Verification` or `BLOCKED`
  according to impact.

## Tests And Validation

- Query tests should assert result shape, draft exclusion, reference resolution,
  ordering, bounds, null/empty behavior, and user-parameter validation.
- Cache/webhook tests should prove invalidation hits the same tags, keys,
  dataset, locale, and preview/public mode that the runtime reads.
- Mutation tests or dry-runs should include no-op, partial failure, rerun,
  skipped document, rollback, and operator-summary behavior when central.
- Browser or snapshot evidence over CMS content proves only the observed dataset,
  document state, flags, viewport, account, and commit.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- query references fields, types, or result shapes that do not match the schema
  or generated type used by current code
- public query can include drafts, private fields, unvalidated parameters, or
  over-broad projections
- list, reference, or aggregate query can grow unbounded without pagination,
  stable ordering, or scale proof
- cache or webhook behavior can serve stale, cross-dataset, cross-locale,
  preview/draft, tenant, or permission-wrong content
- generated Sanity types drift from schema source or were edited manually
- CMS mutation or migration lacks dataset identity, dry-run, backup/rollback,
  idempotency, or post-apply verification when data safety is central
