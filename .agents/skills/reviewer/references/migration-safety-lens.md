<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Migration Safety Lens

Use this lens when a review target includes pending or recent Postgres
migrations under `backend/internal/shared/sql/migrations/`, or when SQL/query
changes depend on concurrent index safety, rolling-deploy schema safety,
deploy-time locks, or down-migration reversibility.

## Default posture

Read-only. Inspect SQL, run lightweight checks such as
`backend/migrations-check.sh`, and compare schema changes against queries. Do
not apply migrations, drop tables, or edit migration files while using this
lens.

## When to use

- A change adds or modifies files under `backend/internal/shared/sql/migrations/`
- A query change may depend on unsafe rolling-deploy schema assumptions
- You want a migration safety pass before merge or release

## When not to use

- Writing or fixing a migration; use the backend-codegen lane in `code-authoring`
- Fixing sqlc compile errors; use normal backend implementation flow
- Debugging application behavior that only happens to involve the database
- Cross-store movement, dual-write phases, backfill parity, or datasource
  cutover as the central risk; use `data-migration-cutover-lens` and keep this
  lens for the DDL/lock/rolling-deploy side

## Review sequence

1. Check linearity and pairing:

    ```bash
    cd <repo-root>/backend
    ./migrations-check.sh internal/shared/sql/migrations
    ls internal/shared/sql/migrations | sort | tail -20
    ```

2. Scan for concurrency-unsafe DDL:

    ```bash
    cd <repo-root>/backend/internal/shared/sql/migrations
    rg -n "CREATE INDEX|ALTER TABLE|DROP INDEX|REINDEX" *.up.sql
    ```

3. Check rolling-deploy compatibility against live queries under
   `backend/internal/shared/sql/queries/`
4. Check backfill correctness before any `SET NOT NULL`
5. Check `down.sql` reversibility
6. Check query compatibility and whether sqlc-generated nullable types will
   change call sites
7. Compare new mutable-table conventions against sibling migrations: timestamp
   maintenance, triggers, primary keys, secondary indexes, uniqueness, and
   rollback behavior. Require a reason when the migration diverges from an
   established convention or adds a structure already covered by another one.
8. Decide whether new evidence or audit tables are runtime truth. If active
   code, validation, reconcile, live mirrors, cleanup, read paths, or operator
   gates depend on those rows, review foreign-key actions, retention, and
   cleanup as data-safety behavior, not only schema hygiene.
9. Check every explicit index against primary keys, unique constraints, and
   sibling indexes. A strict duplicate of a constraint-created btree index adds
   write and storage cost without improving the access path.
10. Flag traced SQL query name changes as low-risk observability churn
11. For migration jobs, imports, applies, materialization, validation, or
    reconcile modes, read the operator README/runbook section for the exact
    mode when the review claim includes run readiness. Verify that every
    documented precondition is proven in execution order, including older
    gates that the current diff did not touch. If a run would predictably fail
    at a documented freshness or exact-match gate, do not let a newer policy
    or cap change be described as unblocking the workflow.

## High-risk patterns

- `DROP COLUMN`, `DROP TABLE`, `RENAME COLUMN`, or `RENAME TABLE` without a
  multi-release plan
- `CREATE INDEX` or `DROP INDEX` on hot tables without `CONCURRENTLY`
- concurrent index operations mixed with other DDL in one transaction or
  migration step that cannot run outside a transaction
- active-table DDL without a short `lock_timeout` or an explicit reason it is
  safe to wait for locks
- `SET NOT NULL` on a populated table without a prior backfill
- Type changes or volatile defaults that rewrite large tables during rolling
  deploys
- Broken or asymmetric down-migrations

## Findings format

Report findings through the reviewer core packet, P0-P3 severity, and
confidence model owned by this runtime's reviewer core role file (Claude:
`.claude/agents/reviewer.md`; Codex: `.codex/agents/reviewer.toml`; Agents:
`.agents/plugins/example-app/agents/reviewer.md`; Copilot:
`.github/agents/reviewer.agent.md`). This lens contributes
probes, review sequence, and evidence expectations only; it does not define its
own report template, numeric score, or reporting threshold. Anchor each finding
to `path/to/file.sql:line` with the SQL snippet, grep output, or affected query
reference as evidence, and state the remediation shape, often a split across
multiple releases.

## References

- `backend/internal/shared/sql/migrate.go`
- `backend/internal/shared/sql/sqlc.yaml`
- `backend/migrations-check.sh`
- `code-authoring` backend-codegen lane
- current runtime backend architecture guidance when available
