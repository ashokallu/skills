<!-- Last verified: 2026-08-11 -->
<!-- MCP opt-in defaults, scripts/dev/open-vscode-with-mcp-env.sh, scripts/dev/check-vscode-mcp-env.sh, and XP import smoke-query review behavior -->

# Staging Mongo MCP

## Core Rules

- Treat staging Mongo credentials as sensitive. Never print `APP_STG_MONGO_URL`, passwords, full auth strings, or `.envrc` contents.
- The repo-local MCP `app-stg-mongo-readonly-local` is disabled by default.
  Enable it only for a task that needs staging Mongo, then restart the session
  before using it.
- Use local port `37017` for staging. Leave `27017` for local dev Mongo.
- Always query a secondary. Never bypass the secondary-only tunnel and never point the MCP directly at a known primary.
- Do not describe `scripts/dev/app_stg_mongo_readonly_mcp.sh` as a fallback for a failed tunnel. The wrapper starts the MCP server process; it still connects through `APP_STG_MONGO_URL`, which should point at the local secondary tunnel.

## Connection Model

Staging Mongo access uses `gcloud compute ssh` to open an authenticated SSH port-forward
from local `127.0.0.1:37017` to MongoDB on the selected staging secondary VM at
`localhost:27017`. Mongo tools talk to localhost, and SSH carries the traffic to the VM.

Component flow:

1. `scripts/dev/app_stg_mongo_tunnel.sh` checks the three staging Mongo VMs in project `example-service-staging`.
2. The script uses `gcloud compute ssh --internal-ip` to run `db.isMaster()` inside each VM's Mongo container and skips the current primary.
3. After it finds a secondary, it starts an SSH tunnel with:
   `-L 127.0.0.1:37017:localhost:27017`
4. `APP_STG_MONGO_URL`, `mongosh`, and the MCP connect to `127.0.0.1:37017`, not directly to `198.51.100.22:27017`.
5. Mongo traffic goes through the SSH tunnel to `localhost:27017` from the VM's perspective, then results return over the same tunnel.

VPN note: the current script does not use `--tunnel-through-iap`; it uses `--internal-ip`.
VPN is not part of the Mongo/MCP connection once the SSH tunnel is already up, but
starting the tunnel still requires this machine to have a private network path to the
VM internal IP. In this dev workspace that path may already exist without a desktop VPN;
on a laptop outside the private network, VPN or another approved private access path
would be needed.

## Required Setup

1. Confirm `.envrc` exports `APP_STG_MONGO_URL` without printing it:
   `awk 'index($0, "APP_STG_MONGO_URL") { print "APP_STG_MONGO_URL present"; found=1 } END { exit found ? 0 : 1 }' .envrc`
2. For Codex CLI sessions, explicitly enable the registered MCP for the task.
   Restart the Codex CLI session so `.codex/config.toml` is reloaded before
   using its tools.
3. For manual stdio checks, use `scripts/dev/app_stg_mongo_readonly_mcp.sh`; it loads `.envrc` itself when `APP_STG_MONGO_URL` is not already inherited.

## VS Code Launcher Checks

Use these only when the agent or MCP server is launched from VS Code. They are not required for a plain Codex CLI session.

- Check VS Code process env:
  `mise run dev:vscode:mcp-env:check`
- If the check reports a restart is required:
  `RESTART=1 mise run dev:vscode:open`

## Tunnel Workflow

Start staging access with:

```bash
scripts/dev/app_stg_mongo_tunnel.sh
```

The default mode starts the tunnel in the background, waits until `127.0.0.1:37017`
is listening, prints a ready/failure message, and exits. Use
`scripts/dev/app_stg_mongo_tunnel.sh --foreground` only when a blocking SSH
tunnel process is explicitly needed.

The tunnel script checks these VMs, discovers zones dynamically, skips the current primary, and binds the first secondary to `127.0.0.1:37017`:

- `example-mongodb-001-us-central1`
- `example-mongodb-002-us-central1`
- `example-mongodb-003-us-central1`

If failover happens while the tunnel is open, restart the tunnel. The MCP also runs `isMaster` before every tool call and refuses to query a member that reports primary.

## Connection Failure Triage

Use this sequence when the MCP reports `ECONNREFUSED 127.0.0.1:37017` or `Address already in use`.

1. Confirm `.envrc` still exports `APP_STG_MONGO_URL` without printing it.
2. Check whether anything is actually listening on `37017`:
   `scripts/dev/app_stg_mongo_tunnel.sh --status`
3. If nothing is listening, start the tunnel and verify again:
   `scripts/dev/app_stg_mongo_tunnel.sh`
4. If the MCP still returns `ECONNREFUSED`, inspect the tunnel log:
   `tail -n 40 tmp/app-stg-mongo-tunnel-37017.log`
5. If tunnel startup says `Address already in use`, inspect the owner before killing anything:
   `lsof -nP -iTCP:37017 -sTCP:LISTEN || true`
   `ps -ef | grep '[g]cloud compute ssh .*127.0.0.1:37017\|[s]sh .*127.0.0.1:37017' || true`
6. If the listener is an existing `ssh` / `gcloud compute ssh` port-forward, retry the MCP `connect` tool before restarting it. A previous tunnel may have bound successfully just after your first readiness check.
7. Only restart the tunnel when one of these is true:
   - no listener exists on `37017`
   - the listener is not the expected SSH port-forward
   - the MCP still cannot connect after a valid listener is confirmed

Do not keep running read tools after `ECONNREFUSED 127.0.0.1:37017` until the tunnel is verified listening.
Do not report success from shell command completion alone; report the JSON result from the MCP response.

## MCP Behavior

The MCP server is configured in `.codex/config.toml` as
`app-stg-mongo-readonly-local` with `enabled = false`. Enable it only for an
explicit staging Mongo task.

It uses `scripts/dev/app_stg_mongo_readonly_mcp.sh`, which installs MongoDB Node driver `3.7.4` under `/tmp/app-stg-mongo-readonly-mcp` because staging runs MongoDB `3.2.20` and modern `mongosh` / official MongoDB MCP clients cannot connect.

The wrapper loads `.envrc` itself if `APP_STG_MONGO_URL` is missing from the inherited environment.
This supports Codex CLI and other MCP launchers that do not inherit the expected shell or IDE environment.
Agents still must not print `.envrc` or the URL.
The wrapper is not an alternative network path. If it returns `ECONNREFUSED 127.0.0.1:37017`, fix the tunnel before retrying.

Available tools:

- `connect`
- `list-databases`
- `list-collections`
- `find`
- `count`
- `aggregate`
- `explain`
- `collection-indexes`
- `collection-schema`
- `collection-storage-size`
- `db-stats`

Read-only constraints:

- `find` limits results to at most 100 documents.
- `aggregate` blocks write/admin stages including `$out`, `$merge`, `$currentOp`, `$listSessions`, and `$planCacheStats`.
- `collection-schema` infers field paths and types from a small sample without returning document values.
- `list-databases` may return only the configured database with `complete: false` because the staging identity cannot enumerate admin database metadata.
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

Use a small count or collection listing when a registered MCP tool is unavailable or you need to verify the stdio server directly. Do not dump large documents.

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"count","arguments":{"database":"mp","collection":"app_experience","filter":{}}}}' |
  timeout 25s zsh -lc 'set -a; source .envrc >/dev/null 2>&1; set +a; bash ./scripts/dev/app_stg_mongo_readonly_mcp.sh'
```

The command may exit with timeout because MCP servers stay open; the JSON response before timeout is the result.
If the terminal integration only shows `Completed with input` and not the MCP JSON output, the check is not evidence. Re-run the command in a way that captures stdout, or use the registered MCP tools.
