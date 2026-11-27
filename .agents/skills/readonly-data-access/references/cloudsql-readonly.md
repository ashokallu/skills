<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-23 (self-contained Google Cloud MCP token recovery) -->

# Cloud SQL Readonly

Use this skill for read-only Cloud SQL checks in `example-app`, especially
when answering migration, capacity, table-size, or production-read-replica
questions. Treat all DB credentials, tokens, and `.envrc` contents as sensitive:
never print secret values, full DSNs, bearer tokens, or passwords.

## Core Rules

- Prefer read-only metadata first: instance state, disk size, DB user list, and
  table stats before exact counts or aggregates.
- Prefer replicas for Production SQL reads. Confirm `pg_is_in_recovery() = true`
  before running non-trivial SQL.
- Do not run mutation SQL. Avoid `EXPLAIN ANALYZE` on Production unless the
  user explicitly asks for execution and the query is bounded.
- Use `statement_timeout` for any query that may scan, group, sort, or join a
  large table.
- Before sampling temporary migration, report, or operator tables, inspect the
  current table columns from `information_schema.columns` or a bounded
  metadata query. Do not assume column names from memory, old PRs, or previous
  runs.
- For row samples, project only concise evidence fields such as run IDs, user
  IDs, category IDs, statuses, counts, and numeric totals. Avoid selecting `*`
  from tables that may contain large arrays, JSON payloads, document lists, or
  sensitive fields unless the user explicitly needs that payload and it is safe
  to summarize rather than paste.
- Stop local `cloud-sql-proxy`, tunnel, and keepalive processes you started
  before ending the activity. Treat this as a security cleanup, not a cosmetic
  cleanup: stale local listeners can expose privileged database paths beyond
  the intended task window.
- Track proxy/tunnel PIDs when starting them and stop those exact PIDs. Do not
  rely on terminal tabs, memory, or broad process-name cleanup.
- Do not delete repo-root `tmp/`; use it only for local scratch files when
  needed.

## DB Operation Fumble Prevention

Use this section before any Cloud SQL operation that moves from read-only
evidence into a write-capable path, including truncation, cleanup, manual
repair, migration recovery, or operator-owned SQL.

- Derive the DB table scope from live schema first. For cleanup or truncation,
  inventory current matching tables such as `xp_import_%`, `xp_live_%`, and
  explicitly named target tables before trusting a static runbook list. Then
  compare the live inventory against the runbook. A stale list is a blocker
  until the extra tables are classified and included or deliberately excluded.
- Run the FK graph against the final live scope, not the remembered scope. If
  an out-of-scope referencing table appears, stop before mutation. Do not use
  `CASCADE` to make the error disappear.
- Inspect secret key names before adapting a connection string. Repo secrets
  may use keyword strings such as `database=...`, while `psql` expects
  `dbname=...`. Convert only inside the process and never print the DSN.
- Check whether a secret is Cloud Run socket-shaped. A value like
  `host=/cloudsql/<connection-name>` works inside Cloud Run but local `psql`
  will look for a missing Unix socket. For local direct access, use the
  documented private-IP path or a correctly authenticated Cloud SQL Auth Proxy.
- Separate read-only API paths from write paths. The Staging executeSql wrapper
  is intentionally SELECT-only and the IAM DB user may have only `SELECT`
  privileges. Do not try to force truncation, cleanup, or repair through the
  read-only wrapper.
- Treat Cloud SQL Data API as a bounded admin surface, not a drop-in
  replacement for normal DB connections. It has request and execution limits,
  and repo wrappers may enforce read-only SQL. Use it only when its auth model,
  privilege model, and timeout fit the operation.
- Do not assume Cloud SQL Auth Proxy uses the same identity as `gcloud auth
  list`. The proxy can use Application Default Credentials, a quota project,
  gcloud user credentials, an OAuth token, or impersonation, and each path can
  fail differently. Pick the documented path first.
- If a proxy attempt fails, stop that exact proxy process before trying another
  auth mode or port. A stale proxy listener can cause misleading port-in-use
  errors and can keep privileged DB access open longer than intended.
- Prefer the known-good auth path for the environment. If default ADC points at
  an unrelated project, use the documented `--gcloud-auth` or token-based path
  instead of experimenting with service-account impersonation. Do not assume
  impersonation works until the current principal has
  `iam.serviceAccounts.getAccessToken` for that service account.
- For every DB write, record the access path in the handoff: direct private IP,
  Cloud SQL Auth Proxy, Data API, or another approved path; the SQL identity;
  the bounds used; and proof that any proxy or tunnel started for the task was
  stopped.

## Environment Facts

Staging:

- project: `example-app-staging`
- instances: `app-api`, `app-api-replica`
- validated SQL API path: repo-local wrapper
  `scripts/dev/google_cloud_sql_stg_readonly_mcp.py`
- IAM DB user seen through executeSql:
  `agents-stg@example-app-staging.iam`

Production:

- project: `example-app-prod`
- instances: `app-api`, `app-api-replica`
- `executeSql` is not enabled on the Production replica unless live state
  changes; expect the error:
  `The instance doesn't allow using ExecuteSql to access this instance`
- Production currently uses built-in DB users for direct SQL; the safe
  read-replica credential is in Secret Manager as `SQL_REPLICA_URI`.
  Read it into process memory only and do not print it.

## First Checks

List instances:

```bash
gcloud sql instances list \
  --project example-app-prod \
  --filter='name:app-api' \
  --format='table(name,state,databaseVersion,settings.tier,settings.dataDiskSizeGb,region)'
```

List DB users without secrets:

```bash
gcloud sql users list \
  --project example-app-prod \
  --instance app-api-replica \
  --format='table(name,type)'
```

For Staging metadata, explicitly opt into `google-cloud-sql-stg` when the
active client supports it; otherwise use the bounded `gcloud` inventory below.

## Registered Google Cloud MCP Token Recovery

Google Cloud resource MCPs use `GOOGLE_MCP_ACCESS_TOKEN`, a short-lived bearer
token captured when the agent harness starts. If a registered Google Cloud MCP
returns `Auth required`, do not immediately classify the failure as broken IAM,
MCP setup, or cloud availability.

From the repository root, run this bounded Staging smoke. Unsetting the stale
environment value forces the wrapper to mint a fresh token through
`scripts/dev/google-mcp-access-token.sh`; the token remains in process memory
and the command prints only the read result:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"execute_sql_readonly","arguments":{"sqlStatement":"SELECT 1","rowLimit":1}}}' \
  | env -u GOOGLE_MCP_ACCESS_TOKEN \
      python3 scripts/dev/google_cloud_sql_stg_readonly_mcp.py
```

If this fresh-token smoke succeeds while the registered MCP still returns
`Auth required`, the current harness has stale in-process auth. Stop retrying
that registered tool. Ask the user to open a new OS terminal that loads
`.envrc`, mints a fresh `GOOGLE_MCP_ACCESS_TOKEN`, and launches the harness from
that environment. The new process boundary is required because updating a
parent shell does not replace the token already captured by the running
harness.

If the fresh-token smoke also fails, keep the failure in read-only diagnosis
and inspect the returned auth/IAM/API evidence. Do not use the stale-token
explanation as proof, and do not widen to primary or write-capable database
access as a fallback.

## Long-Running GCP Operator Reads

For multi-hour XP import operator windows, do not depend on a single
`GOOGLE_MCP_ACCESS_TOKEN`; it can expire inside the run. Prefer `gcloud`
inventory, Cloud Logging reads, and Cloud Monitoring REST calls that mint a
fresh token per read. Keep any `gcloud auth print-access-token` value inside
the shell or process and never print it.

Use this operator access pattern:

1. Use registered Google Cloud MCP tools only for short smoke checks when their
   token is known fresh. If a run may last longer than the token TTL, use
   `gcloud` and direct Google APIs instead.
2. Use `gcloud run jobs describe`, `gcloud run jobs executions describe`, and
   `gcloud logging read` for Cloud Run job state, execution state, and logs.
3. Use Cloud Monitoring REST with a fresh `gcloud auth print-access-token`
   inside each one-shot process for Cloud SQL and VM vitals.
4. Use the repo-local Staging SQL wrapper with
   `env -u GOOGLE_MCP_ACCESS_TOKEN` so a stale harness MCP token cannot leak
   into the process. The command text mentions `GOOGLE_MCP_ACCESS_TOKEN` only
   to remove it; it is not a dependency for the read.
5. For Production SQL reads, use the direct private-IP workflow below first
   when VPN is connected. Keep the Auth Proxy workflow as a fallback and as
   useful auth-surface diagnostics, but the current worker has seen the proxy
   listen locally while backend connection attempts time out. Do not switch to
   primary or write-capable access for convenience.
6. Summarize metrics, row counts, and log state. Do not paste bearer tokens,
   DSNs, full secrets, or raw credential-bearing output into chat or files.

Use `gcloud` directly for Cloud Run job and Cloud SQL instance inventory:

```bash
gcloud run jobs describe xp-mongo-to-postgres-import \
  --project <project-id> \
  --region us-central1 \
  --format=json

gcloud sql instances list \
  --project <project-id> \
  --filter='name:app-api' \
  --format='table(name,state,databaseVersion,settings.tier,settings.dataDiskSizeGb,region)'
```

Use Cloud Logging for job progress and failure evidence:

```bash
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="xp-mongo-to-postgres-import"' \
  --project <project-id> \
  --freshness=7d \
  --limit=20 \
  --format='table(timestamp,severity,resource.labels.job_name,resource.labels.location,textPayload)'
```

The installed `gcloud` may not expose `gcloud monitoring time-series`. Use the
Cloud Monitoring REST API with a fresh token per call for vitals. Keep the
token in process memory and print only summarized metric values:

```python
import datetime, json, subprocess, urllib.parse, urllib.request

project = "example-app-prod"
end = datetime.datetime.now(datetime.timezone.utc)
start = end - datetime.timedelta(minutes=30)
flt = (
    'metric.type="cloudsql.googleapis.com/database/cpu/utilization" '
    'AND resource.labels.database_id="example-app-prod:app-api"'
)
params = urllib.parse.urlencode({
    "filter": flt,
    "interval.startTime": start.isoformat().replace("+00:00", "Z"),
    "interval.endTime": end.isoformat().replace("+00:00", "Z"),
    "pageSize": "5",
})
token = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
req = urllib.request.Request(
    f"https://monitoring.googleapis.com/v3/projects/{project}/timeSeries?{params}",
    headers={"Authorization": f"Bearer {token}"},
)
with urllib.request.urlopen(req, timeout=20) as r:
    data = json.load(r)
print({"seriesCount": len(data.get("timeSeries", []))})
```

For Cloud SQL Monitoring filters, `resource.labels.database_id` must be the
full `<project-id>:<instance-name>` value, for example
`example-app-staging:app-api`. If you include the Monitoring resource
`region` label, use `us-central`, not the Cloud Run or Cloud SQL region string
`us-central1`. A zero-series response after using only `app-api` or
`us-central1` is a query-shape issue until checked with the full label form.

For common operator vitals, query these Cloud SQL metrics through the same REST
shape and summarize min, average, p95, and max for the run window:

- `cloudsql.googleapis.com/database/cpu/utilization`
- `cloudsql.googleapis.com/database/disk/write_bytes_count`
- `cloudsql.googleapis.com/database/disk/bytes_used`
- `cloudsql.googleapis.com/database/network/connections`, when series are
  available

Not every useful-looking descriptor has data for every instance or database
engine. If a metric returns zero series, verify the exact descriptor and
resource labels before treating it as service evidence.

Production Mongo VM metrics live outside the Learn project. Use
`example-service-prod` for the known Mongo VM inventory:

```bash
gcloud compute instances list \
  --project example-service-prod \
  --filter='name~example-mongodb' \
  --format='table(name,zone,status,networkInterfaces[0].networkIP)'
```

For the current production migration target, `example-mongodb-002-us-central1`
has IP `192.0.2.10`. Resolve its instance ID before querying
`compute.googleapis.com/instance/*` metrics because Monitoring filters use
`resource.labels.instance_id`, not the VM name.

## Staging Readonly SQL

Use the repo-local executeSql wrapper for Staging SQL because it sets
`autoIamAuthn=true` and rejects non-read-only SQL. Prefix the command with
`env -u GOOGLE_MCP_ACCESS_TOKEN`; this deliberately unsets the stale
short-lived MCP token captured by the harness and forces the helper down its
gcloud-backed auth path:

```bash
env -u GOOGLE_MCP_ACCESS_TOKEN python3 - <<'PY'
from scripts.dev import google_cloud_sql_stg_readonly_mcp as m
print(m.execute_readonly_sql(
    "SELECT current_user, current_database(), pg_is_in_recovery()",
    10,
))
PY
```

Notes:

- The second `execute_readonly_sql` argument is a result-row limit, not a
  timeout. For one-to-many queries, calculate the maximum possible result rows
  before choosing it, or batch parent keys so each result fits below the cap.
  If the returned row count equals the cap, treat the result as possibly
  truncated. Never infer that a parent or child row is missing from a capped
  result; rerun with a proven-sufficient bound or per-key batches before
  classification, mutation, or operator reporting.
- The Cloud SQL Data API has a hard execution timeout around 30 seconds.
- A query timing out there is useful evidence, but it is not proof that the
  same SQL cannot finish through a normal DB connection.
- For XP migration, the Staging full dry-run ID
  `xp-dry-run-stg-full-20260529155001` is useful for read-only audit probes,
  but verify current docs/state before relying on it.

## Production Readonly SQL Through Replica

This is the fallback path. Prefer "Production Direct Private-IP SQL Workflow"
below first when the current shell is on VPN.

Use Cloud SQL Auth Proxy to the Production replica, then connect with the
`reader` credential from `SQL_REPLICA_URI`.

## Production Direct Private-IP SQL Workflow

Use this workflow first for Production SQL reads when the current shell is on
VPN. It avoids the Cloud SQL Auth Proxy auth/quota-project dance and uses the
same built-in DB credentials as the proxy workflow. Keep secrets in process
memory only.

Current private IPs:

- Production replica `app-api-replica`: `192.0.2.21`
- Production primary `app-api`: `192.0.2.22`

First confirm the intended Google identity and network path:

```bash
gcloud auth list --filter=status:ACTIVE --format='value(account)'
scripts/dev/agent-collab-vpn-smoke.sh --timeout-sec 12
```

The expected account for Learn Production access is the the organization account, not a
personal Google account. The VPN smoke should print:

```text
vpn-smoke-ok https://app.staging.example.com/
```

Then smoke the replica with `SQL_REPLICA_URI`. This must print only the SQL
identity and recovery state, never the DSN or password:

```bash
python3 - <<'PY'
import os, shlex, subprocess

secret = subprocess.check_output([
    "gcloud", "secrets", "versions", "access", "latest",
    "--project", "example-app-prod",
    "--secret", "SQL_REPLICA_URI",
], text=True).strip()
parts = dict(token.split("=", 1) for token in shlex.split(secret) if "=" in token)

env = os.environ.copy()
env["PGPASSWORD"] = parts["password"]
conn = (
    "host=192.0.2.21 port=5432 "
    f"dbname={parts.get('database', 'learn')} "
    f"user={parts.get('user', 'reader')} "
    "sslmode=disable connect_timeout=10"
)
sql = """
SET statement_timeout = '10s';
SELECT current_user, current_database(), pg_is_in_recovery();
"""
subprocess.run([
    "psql", conn, "-v", "ON_ERROR_STOP=1", "-P", "pager=off",
    "-c", sql,
], check=True, env=env)
PY
```

Expected safe smoke result:

- `current_user = reader`
- `current_database = learn`
- `pg_is_in_recovery = t`

If the replica reader cannot see temporary XP migration, report, or operator
tables, do not call Production SQL access blocked. First prove the permission
gap with `information_schema.columns`, then use the gated
"Temporary Migration-Table Permission Workaround" section below (not the
general primary-IP workflow) — it names the exact conditions that must all be
true before switching from the replica to the primary for this case.

Known Production limitation: this is usually a DB-grant gap, not a replication
or auth failure. The Production replica and primary have the same replicated
table schema and data, but the standard read path uses the `reader` DB user from
`SQL_REPLICA_URI`, while the primary workaround uses the broader app DB user
from `SQL_URI`. The `reader` user may lack privileges on temporary XP
migration, report, or operator tables even though those tables exist and are
visible to the app user. Do not infer that the table is missing, that
replication is broken, or that gcloud auth failed until the DB user and
`information_schema.columns` visibility have been checked.

For the primary read-only workaround, connect directly to the primary private
IP with `SQL_URI`, force the session read-only, and keep the query bounded:

```bash
python3 - <<'PY'
import os, shlex, subprocess

secret = subprocess.check_output([
    "gcloud", "secrets", "versions", "access", "latest",
    "--project", "example-app-prod",
    "--secret", "SQL_URI",
], text=True).strip()
parts = dict(token.split("=", 1) for token in shlex.split(secret) if "=" in token)

env = os.environ.copy()
env["PGPASSWORD"] = parts["password"]
conn = (
    "host=192.0.2.22 port=5432 "
    f"dbname={parts.get('database', 'learn')} "
    f"user={parts.get('user', 'api')} "
    "sslmode=require connect_timeout=10"
)
sql = """
BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';
SELECT current_user, current_database(), pg_is_in_recovery();
SELECT count(*) AS rows
FROM public.<temporary_migration_report_table>
WHERE <bounded_predicate>;
COMMIT;
"""
subprocess.run([
    "psql", conn, "-v", "ON_ERROR_STOP=1", "-P", "pager=off",
], input=sql, text=True, check=True, env=env)
PY
```

Closeout for this direct workflow must say:

- active gcloud account checked
- VPN smoke result
- replica direct private-IP smoke result
- whether the replica reader could see the needed table
- whether the primary read-only workaround was used
- bounds applied, such as `BEGIN READ ONLY`, `statement_timeout`, filters, and
  projected columns
- any local proxy, tunnel, or keepalive process started for the activity was
  stopped by exact PID, or no such process was started

The existing Auth Proxy workflow below is still valid as a fallback and for
auth diagnostics. In the current worker, it appears actively unreliable for
this access path because the proxy can listen locally while Cloud SQL backend
connection attempts time out. Prefer the direct private-IP workflow above
unless a future environment proves the proxy path healthy again.

## Production Cloud SQL Auth Preflight

Do not treat `gcloud auth list` as proof that Cloud SQL Auth Proxy will use the
same identity or quota project. The proxy can use Application Default
Credentials while `gcloud` CLI commands use the active CLI account. Before
declaring Production SQL access blocked, explicitly distinguish these surfaces:

- CLI account: `gcloud auth list --filter=status:ACTIVE`
- fresh CLI token path: `gcloud auth print-access-token --project example-app-prod`
- ADC path: only relevant when intentionally using ADC; ADC quota-project
  errors do not prove the the organization CLI account lacks access

For this repo's Production read-only SQL checks, prefer the fresh CLI token
path below. If a plain proxy or `--quota-project` proxy fails with
`test-cloud-run-go`, `SERVICE_DISABLED`, `USER_PROJECT_DENIED`, or
`serviceusage.services.use`, that is an ADC/quota-project problem. Retry with
the explicit `--token` / `--login-token` mode before reporting a blocker.

When reporting an access blocker, name which auth surface failed:

- `ADC quota project failed`
- `fresh CLI token proxy failed`
- `replica reader lacks SELECT on <table>`
- `primary read-only workaround unavailable`

Do not collapse those into "cannot access Production SQL"; they require
different fixes and have different operational meaning.

Start the proxy using a fresh gcloud OAuth token when ADC points at the wrong
quota project. From the current worker environment, the Production replica
smoke requires `--private-ip`; without it, the proxy can listen locally but
psql may time out before the Cloud SQL backend connection completes:

```bash
TOKEN=$(gcloud auth print-access-token --project example-app-prod)
cloud-sql-proxy \
  --private-ip \
  --auto-iam-authn \
  --token "$TOKEN" \
  --login-token "$TOKEN" \
  --port 55434 \
  example-app-prod:us-central1:app-api-replica
```

This command must not print the token. If you start the proxy this way, save
the PID when launching it and stop that exact PID before handoff. Do not use
`pkill -f` or `pgrep -af` for tokenized proxy commands because process-list
output can expose credential-bearing arguments.

```bash
PROXY_PID=$!
# After the read-only check:
kill "$PROXY_PID" 2>/dev/null || true
wait "$PROXY_PID" 2>/dev/null || true
```

Use Python to read `SQL_REPLICA_URI` without printing the secret and pass only
the password through `PGPASSWORD`:

```bash
python3 - <<'PY'
import os, shlex, subprocess

secret = subprocess.check_output([
    "gcloud", "secrets", "versions", "access", "latest",
    "--project", "example-app-prod",
    "--secret", "SQL_REPLICA_URI",
], text=True).strip()
parts = dict(token.split("=", 1) for token in shlex.split(secret) if "=" in token)

env = os.environ.copy()
env["PGPASSWORD"] = parts["password"]
conn = (
    "host=127.0.0.1 port=55434 "
    f"dbname={parts.get('database', 'learn')} "
    f"user={parts.get('user', 'reader')} "
    "sslmode=disable connect_timeout=60"
)

subprocess.run([
    "psql", conn, "-v", "ON_ERROR_STOP=1", "-P", "pager=off",
    "-c", "SELECT current_user, current_database(), pg_is_in_recovery();",
], check=True, env=env)
PY
```

Expected safe smoke result for Production replica:

- `current_user = reader`
- `current_database = learn`
- `pg_is_in_recovery = t`

## Temporary Migration-Table Permission Workaround

The default Production path is still the replica plus `SQL_REPLICA_URI`. If the
replica reader returns `permission denied` for a new temporary migration,
operator, or report table, do not assume that Production reads should switch to
the primary. Use this workaround only when all of these are true:

- The table is migration-only, report-only, or expected to be removed after the
  migration window.
- The user or workflow explicitly needs read-only evidence from that table.
- The replica reader permission gap is confirmed on the current table.
- The query is a bounded `SELECT`, metadata lookup, count, or report read.
- No schema change, grant, data change, lock-heavy command, or cleanup action is
  needed.

For that narrow case, connect through Cloud SQL Auth Proxy to the Production
primary with the app SQL credential, but force the SQL session to be read-only.
Treat this as an operator workaround, not a durable permission model. If the
table becomes long-lived or the read path is needed repeatedly, prefer adding
the replica-reader grant through the migration or DBA-owned permission flow.

Secret and process hygiene for this workaround:

- Read `SQL_URI` and OAuth tokens into process memory only. Never print the DSN,
  password, token, or proxy command output that contains credentials.
- Do not run `ps`, `pgrep -af`, or `pkill -f` patterns that can echo a proxy
  command line containing `--token` or `--login-token`. Save the proxy PID from
  `$!` and stop exactly that PID.
- Use a non-default local port and wait for the port without process-list
  commands.
- Wrap evidence SQL in `BEGIN READ ONLY`, use `SET LOCAL statement_timeout`,
  and keep result sets bounded.

Generic shape:

```bash
TOKEN=$(gcloud auth print-access-token --project example-app-prod)
cloud-sql-proxy \
  --private-ip \
  --auto-iam-authn \
  --token "$TOKEN" \
  --login-token "$TOKEN" \
  --port 55435 \
  example-app-prod:us-central1:app-api \
  >/tmp/cloudsql-prd-primary-readonly.log 2>&1 &
PROXY_PID=$!
cleanup() {
  kill "$PROXY_PID" 2>/dev/null || true
  wait "$PROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT
```

Use the saved PID for cleanup and run the SQL from a process that does not print
the secret:

```bash
python3 - <<'PY'
import os, shlex, subprocess, time

for _ in range(60):
    result = subprocess.run(
        ["bash", "-lc", "</dev/tcp/127.0.0.1/55435"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode == 0:
        break
    time.sleep(1)
else:
    raise SystemExit("proxy did not become ready")

secret = subprocess.check_output([
    "gcloud", "secrets", "versions", "access", "latest",
    "--project", "example-app-prod",
    "--secret", "SQL_URI",
], text=True).strip()
parts = dict(token.split("=", 1) for token in shlex.split(secret) if "=" in token)

env = os.environ.copy()
env["PGPASSWORD"] = parts["password"]
conn = (
    "host=127.0.0.1 port=55435 "
    f"dbname={parts.get('database', 'learn')} "
    f"user={parts.get('user', 'api')} "
    "sslmode=disable connect_timeout=60"
)
sql = """
BEGIN READ ONLY;
SET LOCAL statement_timeout = '30s';
SELECT count(*) AS rows
FROM public.<temporary_migration_report_table>
WHERE <bounded_predicate>;
COMMIT;
"""
subprocess.run([
    "psql", conn, "-v", "ON_ERROR_STOP=1", "-P", "pager=off",
], input=sql, text=True, check=True, env=env)
PY
```

Closeout must say this workaround was used, why the replica path was blocked,
which bounds were applied, and that the proxy PID was stopped. Do not describe
the result as ordinary Production replica verification.

## Mandatory Proxy And Tunnel Cleanup

Before ending any activity that started a local proxy, SSH tunnel, database
tunnel, or keepalive process, perform a cleanup pass:

1. Stop every process that this activity started, using exact saved PIDs.
2. Confirm the expected listener is gone with a port-level check such as
   `ss -ltnp` filtered to the local port, without printing tokenized command
   lines.
3. Report the cleanup in closeout. If cleanup cannot be confirmed, mark it
   `Pending Verification` and name the remaining local port or process class.

Never leave Cloud SQL Auth Proxy, SSH tunnels, database tunnels, or paired
`sleep` keepalives running after a task unless the user explicitly asks to keep
them alive for a follow-up command. Even then, state the local port, expected
lifetime, and cleanup owner.

## Table Size And Count Probes

Start with stats that do not scan the whole table:

```sql
SELECT relname,
       n_live_tup,
       n_dead_tup,
       pg_size_pretty(pg_total_relation_size(format('%I.%I', schemaname, relname))) AS total_size,
       pg_total_relation_size(format('%I.%I', schemaname, relname)) AS total_bytes,
       pg_size_pretty(pg_relation_size(format('%I.%I', schemaname, relname))) AS table_size,
       pg_relation_size(format('%I.%I', schemaname, relname)) AS table_bytes,
       pg_size_pretty(pg_indexes_size(format('%I.%I', schemaname, relname))) AS index_size,
       pg_indexes_size(format('%I.%I', schemaname, relname)) AS index_bytes,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
  AND relname = 'content_user_experience';
```

Then exact counts only when needed and on a replica:

```sql
SET statement_timeout = '5min';
SELECT count(*) AS exact_rows
FROM public.content_user_experience;
```

For grouped audit cardinality, treat this as potentially expensive:

```sql
SET statement_timeout = '5min';
SELECT count(*) AS user_category_groups
FROM (
    SELECT user_id, category_id
    FROM public.content_user_experience
    GROUP BY user_id, category_id
) AS groups;
```

If the replica cancels with `canceling statement due to conflict with recovery`,
that is real evidence that the query is too intrusive for casual production
probing on the read replica. Prefer chunking or a more bounded query shape.

## Known Failure Modes

- `Auth required` from Google Cloud MCP tools:
  stale harness `GOOGLE_MCP_ACCESS_TOKEN`; ask the user to launch from a new OS
  terminal that loads `.envrc`.
- Proxy says Cloud SQL Admin API is disabled in `test-cloud-run-go`:
  ADC quota project is wrong. Use fresh token mode or fix ADC quota project.
- Proxy with `--quota-project example-app-prod` says
  `USER_PROJECT_DENIED` / missing `serviceusage.services.use`:
  the current ADC caller cannot use that quota project. Use token mode.
- Proxy with service account impersonation says
  `iam.serviceAccounts.getAccessToken` denied:
  the current principal cannot impersonate that service account. Do not keep
  retrying.
- Production `executeSql` returns `dataApiAccess` / `ALLOW_DATA_API` error:
  use Cloud SQL Auth Proxy and `SQL_REPLICA_URI` instead.
- Production Auth Proxy listens locally but psql times out:
  retry with `--private-ip` before treating it as a credential failure.
- IAM DB user login fails in Production:
  Production may not have agent IAM DB users. Check
  `gcloud sql users list`; use the built-in `reader` credential from
  `SQL_REPLICA_URI` when authorized.
- Long aggregate on replica is cancelled due to recovery conflict:
  do not rerun blindly. Use this as pressure evidence and switch to bounded
  query design.

## XP Migration Notes

Production `content_user_experience` live check on 2026-06-10 found:

- exact rows: `5,486,304`
- total size: about `1,940 MB`
- heap size: about `884 MB`
- index size: about `1,056 MB`
- only index: `experience_pk (user_id, document_id, category_id)`

The grouped `(user_id, category_id)` aggregate on the Production replica was
cancelled due to recovery conflict. For XP ledger audit PRs, treat one-shot
full aggregation over `content_user_experience` plus millions of staged rows as
risky. Prefer chunked/bounded audit design or clearly documented operator
execution with live vitals.
