<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-11 against MCP opt-in defaults -->

# Staging Mongo MCP

Use this skill for read-only staging MongoDB work. Treat staging credentials as
sensitive and keep all access secondary-only.

## Core Rules

- Never print `APP_STG_MONGO_URL`, passwords, full auth strings, or `.envrc`
  contents.
- Use local port `37017` for staging. Leave `27017` for local dev Mongo.
- Always query a secondary. Never bypass the secondary-only tunnel and never
  point tools directly at a known primary.
- Do not describe `scripts/dev/app_stg_mongo_readonly_mcp.sh` as a fallback
  for a failed tunnel. The wrapper starts the MCP server process; it still
  connects through `APP_STG_MONGO_URL`, which should point at the local
  secondary tunnel.
- Claude does not register the staging Mongo MCP by default. Add a client-local
  registration only for a task that needs staging Mongo, then restart the
  session. Use manual stdio checks only when the user permits that local
  command path.

## Connection Model

Staging Mongo access uses `gcloud compute ssh` to open an authenticated SSH
port-forward from local `127.0.0.1:37017` to MongoDB on a selected staging
secondary VM at `localhost:27017`. Mongo tools talk to localhost, and SSH
carries traffic to the VM.

Component flow:

1. `scripts/dev/app_stg_mongo_tunnel.sh` checks the three staging Mongo VMs
   in project `example-service-staging`.
2. The script uses `gcloud compute ssh --internal-ip` to run `db.isMaster()`
   inside each VM's Mongo container and skips the current primary.
3. After it finds a secondary, it starts an SSH tunnel with
   `-L 127.0.0.1:37017:localhost:27017`.
4. `APP_STG_MONGO_URL`, `mongosh`, and the MCP connect to
   `127.0.0.1:37017`.
5. The MCP runs `isMaster` before tool calls and refuses a member that reports
   primary.

## Required Setup

1. Confirm `.envrc` exports `APP_STG_MONGO_URL` without printing it:

   ```bash
   awk 'index($0, "APP_STG_MONGO_URL") { print "APP_STG_MONGO_URL present"; found=1 } END { exit found ? 0 : 1 }' .envrc
   ```

2. For an explicit staging Mongo task, add a client-local registration for the
   repo wrapper and enable it locally. If it is still missing at runtime,
   restart Claude Code.
3. For manual stdio checks, use
   `scripts/dev/app_stg_mongo_readonly_mcp.sh`; it loads `.envrc` itself
   when `APP_STG_MONGO_URL` is not already inherited.

## Tunnel Workflow

Start staging access with:

```bash
scripts/dev/app_stg_mongo_tunnel.sh
```

The default mode starts the tunnel in the background, waits until
`127.0.0.1:37017` is listening, prints a ready/failure message, and exits. Use
`--foreground` only when a blocking SSH tunnel process is explicitly needed.

If failover happens while the tunnel is open, restart the tunnel.

## Connection Failure Triage

Use this sequence when MCP or stdio checks report
`ECONNREFUSED 127.0.0.1:37017` or `Address already in use`:

1. Confirm `.envrc` still exports `APP_STG_MONGO_URL` without printing it.
2. Check whether anything is listening on `37017`:
   `scripts/dev/app_stg_mongo_tunnel.sh --status`
3. If nothing is listening, start the tunnel and verify again:
   `scripts/dev/app_stg_mongo_tunnel.sh`
4. If the MCP still returns `ECONNREFUSED`, inspect the tunnel log:
   `tail -n 40 tmp/app-stg-mongo-tunnel-37017.log`
5. If tunnel startup says `Address already in use`, inspect the owner before
   killing anything:
   `lsof -nP -iTCP:37017 -sTCP:LISTEN || true`
6. If the listener is an existing `ssh` / `gcloud compute ssh` port-forward,
   retry the MCP `connect` tool before restarting it.
7. Restart the tunnel only when no listener exists, the listener is not the
   expected SSH port-forward, or the MCP still cannot connect after a valid
   listener is confirmed.

Do not keep running read tools after connection refusal until the tunnel is
verified listening. Do not report success from shell command completion alone;
report the MCP JSON result.

## MCP Behavior

The MCP server is intentionally absent from `.mcp.json` by default. For an
explicit staging Mongo task, register `app-stg-mongo-readonly-local` in
client-local configuration with
`scripts/dev/app_stg_mongo_readonly_mcp.sh`; do not commit the personal
opt-in.

The wrapper uses MongoDB Node driver `3.7.4` because staging runs MongoDB
`3.2.20` and modern `mongosh` / official MongoDB MCP clients cannot connect.

Read-only constraints:

- `find` limits results to at most 100 documents.
- `aggregate` blocks write/admin stages including `$out`, `$merge`,
  `$currentOp`, `$listSessions`, and `$planCacheStats`.
- `collection-schema` infers field paths and types from a small sample without
  returning document values.
- `list-databases` may return only the configured database with
  `complete: false`.
- The MCP defaults to `secondaryPreferred` and refuses primary connections.

## Query Plan Verification

The registered MCP `explain` tool is suitable for simple find or aggregation
plans, but it may not expose every query option needed to reproduce application
queries exactly. For example, the XP import smoke preflight uses projection,
`sort({userId: 1})`, and `hint({userId: 1})` together. Do not conclude that
the real smoke query will `COLLSCAN` from an MCP explain call that omitted the
sort or hint.

When exact plan shape matters, verify the actual application query path, add
tooling support for the missing options, or use a legacy-compatible MongoDB
driver path that can send the same query shape. Modern `mongosh` is not a good
fallback for staging MongoDB 3.2; if it reports a maximum wire version error,
switch to the repo MCP/wrapper or compatible driver instead of retrying it.

## Large Query Safety

For staging audits against dense collections such as `app_experience`, keep
queries bounded and index-aware:

- Add a small `limit` or `batchSize` for exploratory reads before widening.
- Use indexed filters or `_id` ranges for broad scans; do not run unbounded
  projections when a count, sample, or explain result would answer the question.
- Query ObjectId fields such as `_id` and `userId` with Extended JSON
  `{"$oid": "..."}` values. The MCP serializes returned ObjectIds as strings,
  but filtering with plain strings returns false negatives for ObjectId fields.
- Use `collection-indexes` and `explain` before expensive aggregations. If the
  plan shows `COLLSCAN`, narrow the filter before running the query.
- Because the MCP reads from a secondary, recently mutated data may lag. For
  write-verification tasks, either wait and re-read with that caveat or verify
  through the backend/write path instead of treating the secondary read as
  immediate truth.

## Manual Stdio Check

Use a small count or collection listing when a registered MCP tool is
unavailable or you need to verify the stdio server directly. Do not dump large
documents.

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"count","arguments":{"database":"mp","collection":"app_experience","filter":{}}}}' |
  timeout 25s zsh -lc 'set -a; source .envrc >/dev/null 2>&1; set +a; bash ./scripts/dev/app_stg_mongo_readonly_mcp.sh'
```

The command may exit with timeout because MCP servers stay open; the JSON
response before timeout is the result.
