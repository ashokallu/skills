<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-26 -->

# Production Mongo Readonly

Use this lane for bounded, read-only Production Mongo checks in
`example-app`, especially XP migration comparisons against
`mp.app_experience`. Treat this as a Production data-access lane: prove VPN
reachability first, use only configured secrets, verify the target is a
secondary, keep reads bounded, and never print credentials.

## Core Rules

- Do not attempt Production Mongo reads until the current shell proves VPN
  reachability. If the VPN gate fails, stop and report `Pending Verification`.
- Use Production Mongo only for read-only evidence. Do not run writes, admin
  operations, collection scans, repair commands, or schema changes.
- Never print `MIGRATION_JOB_MONGO_URI`, `MONGO_URI`, passwords, auth strings,
  access tokens, raw secret values, or command output that contains them.
- Prefer the migration job Mongo URI for XP migration checks because it is
  already configured for the direct secondary target used by the import job.
- Confirm the connected node reports secondary before reading data. A remembered
  VM name or IP is only a lead until the live connection reports its role.
- Use the legacy-compatible MongoDB Node driver path. Modern `mongosh` may be
  installed, but it is not reliable proof for the legacy MongoDB server version.
- Keep reads indexed and bounded: use explicit `userId` or `_id` filters,
  small batches, projections, and socket/connect timeouts.
- If the direct Mongo connection times out while the VPN gate passes, record the
  exact network blocker and stop. Do not silently switch to a primary or broad
  SSH path.

## VPN Gate

Run the repo VPN smoke before touching Production Mongo:

```bash
scripts/dev/agent-collab-vpn-smoke.sh --timeout-sec 12
```

Expected success:

```text
vpn-smoke-ok https://app.staging.example.com/
```

If this fails, do not keep trying database commands. Report that the execution
surface is not on VPN.

For the current Production migration target, a direct TCP probe to the known
secondary IP can distinguish VPN/network reachability from credential or driver
problems:

```bash
timeout 20s bash -lc '</dev/tcp/192.0.2.10/27017' &&
  echo prod-mongo-tcp-ok ||
  echo prod-mongo-tcp-failed
```

Do not treat this TCP probe as database evidence. It only proves that the
network path to the Mongo port is open.

## Target And Secrets

Known Production migration target:

- project for VM inventory: `example-service-prod`
- target VM: `example-mongodb-002-us-central1`
- internal IP: `192.0.2.10`
- expected role for migration reads: secondary
- Mongo database: `mp`
- XP collection: `app_experience`

Verify the VM inventory when role or IP matters:

```bash
gcloud compute instances list \
  --project example-service-prod \
  --filter='name=example-mongodb-002-us-central1' \
  --format='value(name,zone,status,networkInterfaces[0].networkIP)'
```

For XP migration read checks, read `MIGRATION_JOB_MONGO_URI` into process memory
only:

```bash
gcloud secrets versions access latest \
  --project example-app-prod \
  --secret MIGRATION_JOB_MONGO_URI
```

Never print that command output in chat, files, logs, PR comments, or artifacts.
Use command substitution inside the process that needs the URI.

## Driver Setup

Use the same legacy-compatible driver family as the Staging Mongo read-only MCP:

```bash
dependency_dir=/tmp/app-stg-mongo-readonly-mcp
if [ ! -d "${dependency_dir}/node_modules/mongodb" ]; then
  npm install --prefix "${dependency_dir}" mongodb@3.7.4 >/dev/null
fi
```

Then run Node with:

```bash
NODE_PATH=/tmp/app-stg-mongo-readonly-mcp/node_modules node <script>
```

This dependency path is local scratch state. Do not commit it.

## Secondary Smoke

Use a small script that connects with `secondaryPreferred`, runs `isMaster`,
and exits before any data query if the node does not report secondary:

```bash
NODE_PATH=/tmp/app-stg-mongo-readonly-mcp/node_modules node - <<'NODE'
const {execFileSync} = require('child_process');
const mongodb = require('mongodb');
const MongoClient = mongodb.MongoClient;

const uri = execFileSync('gcloud', [
  'secrets', 'versions', 'access', 'latest',
  '--project', 'example-app-prod',
  '--secret', 'MIGRATION_JOB_MONGO_URI',
], {encoding: 'utf8'}).trim();

MongoClient.connect(uri, {
  useNewUrlParser: true,
  readPreference: 'secondaryPreferred',
  connectTimeoutMS: 20000,
  socketTimeoutMS: 30000,
}, async (err, client) => {
  if (err) {
    console.error(JSON.stringify({mongo_connect_error: err.message}));
    process.exit(2);
  }

  try {
    const role = await client.db('admin').command({isMaster: 1});
    console.log(JSON.stringify({
      secondary: !!role.secondary,
      ismaster: !!role.ismaster,
      setName: role.setName || null,
    }));
    if (!role.secondary) process.exit(3);
  } finally {
    client.close();
  }
});
NODE
```

The expected safe role shape is:

```json
{"secondary":true,"ismaster":false,"setName":"rs0"}
```

## Bounded XP Read Shape

For `mp.app_experience`, query by explicit user ObjectIds and project only
the fields needed for the comparison:

```javascript
const docs = await client.db('mp').collection('app_experience').find(
  {userId: {$in: users.map((userID) => new ObjectID(userID))}},
  {
    projection: {
      userId: 1,
      migratePoints: 1,
      deletedTime: 1,
    },
    limit: users.length,
  },
).toArray();
```

For XP migration comparisons:

- Join Postgres rows to Mongo category IDs using the approved mapping in
  `backend/internal/xpimport/categorymap.go`.
- Compare current PG ledger totals, current Mongo `migratePoints[].point`, and
  any existing overlay delta separately. Do not conclude that a gap row is
  missing from Mongo unless Mongo was actually read.
- Use the residual formula for overlay-read decisions:
  `current_pg_ledger_amount - current_mongo_amount - existing_overlay_delta`.
- Positive residual means the current overlay would still undercount after the
  read flag is enabled. Zero or negative residual means the current Mongo plus
  existing overlay already covers that user/category pair.

## Failure Handling

- VPN smoke fails: stop and report that the execution surface is not connected
  to VPN.
- TCP probe fails: stop and report the Production Mongo network path is blocked.
- Mongo connection fails after VPN and TCP pass: report the driver or credential
  error without printing secrets.
- `isMaster` reports primary: stop. Do not query a primary.
- Query needs more than explicit bounded users or small batches: switch to an
  operator plan or purpose-built report job instead of widening an ad hoc shell
  query.

## Closeout

When this lane shaped the work, report:

- VPN smoke result
- Mongo target and whether direct TCP was reachable
- secret name used, not the secret value
- driver path used
- live Mongo role result
- database, collection, projection, filter shape, batch size, and limits
- rows/users/categories compared, summarized without raw credentials
- any `Pending Verification`, especially if Mongo could not be reached or role
  could not be proven secondary
