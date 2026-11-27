---
name: readonly-data-access
description: Use for read-only example-app data access including Cloud SQL metadata or replica reads, Staging or Production Mongo secondary reads, database MCP probes, SSH tunnel triage, query-safety planning, and secret-safe data inspection.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-26 -->

# Readonly Data Access

Use this skill when the task needs secret-safe, read-only inspection of
example-app data stores. This is the umbrella for bounded database metadata,
Cloud SQL read-replica probes, Staging and Production Mongo secondary reads,
MCP connection triage, and query-safety planning.

## Picker Contract

Pick this skill when the user asks to inspect database state, count rows,
check table sizes, list collections, run a small read-only query, triage a
database MCP/tunnel connection, resolve read-only MCP `Auth required` or stale
token failures, or plan safe read-only evidence gathering.

Do not pick this skill for writes, migrations, data repair, restore/import
execution, application code changes, schema changes, or production decisions
that require more than read-only evidence. Route those to the domain workflow
or mark the needed read-only evidence as a lane under that workflow.

## First Reads

`AGENTS.md` is loaded by default in this runtime, so do not re-read it. Before
using a lane, make sure you have read `repo.md` and this `SKILL.md`, and read
either one you have not already read.

## Route The Ask

Load only the lane that matches the current data source:

| Ask shape | Lane |
| --- | --- |
| Cloud SQL metadata, Staging or Production Postgres read-only query, Cloud SQL executeSql, Cloud SQL Auth Proxy, SQL_REPLICA_URI, table-size/count probes, production read-replica safety | [references/cloudsql-readonly.md](references/cloudsql-readonly.md) |
| Staging MongoDB MCP, SSH tunnel on `127.0.0.1:37017`, secondary-only reads, MongoDB 3.2 compatibility, legacy Mongo collection/index/schema probes | [references/staging-mongo-readonly.md](references/staging-mongo-readonly.md) |
| Production MongoDB secondary reads, VPN-gated direct Mongo checks, `MIGRATION_JOB_MONGO_URI`, legacy `mp.app_experience` comparison, Mongo/PG XP evidence | [references/production-mongo-readonly.md](references/production-mongo-readonly.md) |

Do not load multiple lanes unless the task explicitly compares data sources or
an XP migration workflow needs read-only evidence from more than one system.

## Safety Rules

- Never print full secrets, DSNs, passwords, bearer tokens, auth strings,
  `.envrc` contents, or raw credential-bearing command output.
- Prefer metadata, stats, explain plans, small samples, and bounded counts
  before broad scans or expensive aggregates.
- Use read replicas or secondaries when the lane requires them.
- Use timeouts or query limits for anything that may scan, group, sort, join,
  or aggregate a large collection/table.
- For temporary migration or report tables where the Production replica reader
  lacks SELECT, use the Cloud SQL lane's primary read-only workaround only
  under its stated conditions. Do not grant permissions or switch to
  write-capable access by convenience.
- Treat MCP wrapper failures, tunnel failures, stale tokens, and unavailable
  tooling as `Pending Verification`; do not replace missing access with
  guessed data.
- Stop local proxy/tunnel processes you started when the lane says to do so.

## Do Not Use For

Use another skill instead when the request is already in one of these shapes:

- Backend code, SQLC, migrations, mocks, generated Go code, or app behavior:
  use `work-orchestration`.
- PR review or reviewer verdicts that merely need possible data-evidence
  follow-up: use `pr-workflow` or `reviewer`, and list this skill
  as a read-only evidence lane only when needed.
- GitHub, browser, E2E, Sentry, Jira, or Confluence work: use the specialist
  workflow.

## Closeout

When this skill shaped the work, close with:

- lane loaded
- data source and environment inspected
- exact read-only commands or MCP tools used, without secrets
- bounds applied, such as timeout, limit, secondary/replica, or metadata-only
- any proxy/tunnel started and stopped
- unresolved `Pending Verification`
