---
name: gws
description: Use for gws CLI commands and troubleshooting, including gws drive files list, gws drive +upload, Drive file, folder, and shared-drive operations, gws docs +write, Google Docs API operations, gws auth and schema discovery, and serviceusage.services.use 403 quota-project errors.
---

# Google Workspace CLI

Use one umbrella workflow for Google Workspace CLI tasks. Load only the lanes
needed for the current request.

## Lane Map

| Lane | Load when | Owns |
| --- | --- | --- |
| [`gws-shared`](gws-shared.md) | Every `gws` task | Installation, authentication, quota project, global flags, security, shell behavior, and feedback etiquette |
| [`gws-drive`](gws-drive.md) | Managing Google Drive files, folders, comments, permissions, revisions, changes, or shared drives | Drive v3 resources, methods, schema discovery, and raw Drive API command construction |
| [`gws-drive-upload`](gws-drive-upload.md) | Uploading a local file with `gws drive +upload` | Upload helper syntax, flags, examples, and write confirmation |
| [`gws-docs`](gws-docs.md) | Reading, creating, retrieving, or batch-updating Google Docs; discovering Docs API commands | Docs resources, methods, schema discovery, and raw Docs API command construction |
| [`gws-docs-write`](gws-docs-write.md) | Appending plain text with `gws docs +write` | Append helper syntax, flags, examples, and write confirmation |

## Routing

1. Read [`gws-shared.md`](gws-shared.md) before running any `gws` command.
2. For `gws docs +write`, read
   [`gws-docs-write.md`](gws-docs-write.md). The general Docs lane is not
   required unless the task also needs another Docs method.
3. For `gws drive +upload`, read
   [`gws-drive-upload.md`](gws-drive-upload.md). The general Drive lane is not
   required unless the task also needs another Drive method.
4. For other Google Drive operations, read [`gws-drive.md`](gws-drive.md).
5. For other Google Docs operations, read [`gws-docs.md`](gws-docs.md).
6. For a service without a dedicated lane, use the discovery and safety
   patterns in `gws-shared`; inspect the service help and exact method schema
   before constructing the command.

## Safety Boundary

- Read-only discovery and API calls may proceed when they fit the user's
  request.
- Confirm with the user immediately before a write or delete unless the user
  explicitly authorized that exact operation.
- Never print access tokens, refresh tokens, client secrets, API keys, or
  credential-file contents.
- Treat credential selection and quota-project attribution as separate
  mechanisms. Changing the credential source does not disable the quota
  project selected by `gws`.
