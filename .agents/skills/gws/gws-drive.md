# `gws-drive` Lane

```text
Type: service lane
Use when: managing Google Drive files, folders, comments, permissions,
          revisions, changes, access proposals, or shared drives
Owns: Drive v3 resources, methods, schema discovery, and raw API command shape
Requires: gws-shared.md
Outputs: a validated Drive command or a precise schema/setup blocker
```

Read [`gws-shared.md`](gws-shared.md) before using this lane.

```bash
gws drive <resource> <method> [flags]
```

## Helper Command

| Command | Description |
| --- | --- |
| [`+upload`](gws-drive-upload.md) | Upload a file with automatic metadata |

## API Resources

### `about`

- `get`: Get user, Drive, and system capabilities. The `fields` parameter is
  required. See [Return user info][user-info] and
  [Return specific fields][fields].

### `accessproposals`

- `get`: Retrieve an access proposal by ID.
- `list`: List access proposals on a file. Only approvers can list them; other
  users receive a 403.
- `resolve`: Approve or deny an access proposal.

See [Manage pending access proposals][pending-access].

### `approvals`

- `get`: Get an approval by ID.
- `list`: List approvals on a file.

### `apps`

- `get`: Get a specific installed app.
- `list`: List a user's installed apps.

### `changes`

- `getStartPageToken`: Get the starting page token for future changes.
- `list`: List changes for a user or shared drive.
- `watch`: Subscribe to changes for a user.

See [Retrieve changes][changes] and [resource-change notifications][push].

### `channels`

- `stop`: Stop watching resources through a notification channel.

### `comments`

- `create`: Create a comment. The `fields` parameter is required.
- `delete`: Delete a comment.
- `get`: Get a comment by ID. The `fields` parameter is required.
- `list`: List a file's comments. The `fields` parameter is required.
- `update`: Update a comment with patch semantics. The `fields` parameter is
  required.

See [Manage comments and replies][comments] and
[Return specific fields][fields].

### `drives`

- `create`: Create a shared drive.
- `get`: Get shared-drive metadata by ID.
- `hide`: Hide a shared drive from the default view.
- `list`: List the user's shared drives. Supports the `q` search parameter.
- `unhide`: Restore a shared drive to the default view.
- `update`: Update shared-drive metadata.

See [Manage shared drives][shared-drives] and
[Search for shared drives][search-shared-drives].

### `files`

- `copy`: Copy a file and apply requested patch-semantic updates.
- `create`: Create a file. The upload endpoint supports files up to 5,120 GB
  and requires a valid MIME type rather than the literal `*/*`.
- `download`: Download file content. Download operations remain valid for 24
  hours after creation.
- `export`: Export a Google Workspace document to a requested MIME type.
  Exported content is limited to 10 MB.
- `generateIds`: Generate file IDs for later create or copy requests.
- `get`: Get file metadata or content by ID. Use `alt=media` to download
  content stored in Drive.
- `list`: List files. Supports the `q` search parameter and includes trashed
  files by default; include `trashed=false` to exclude them.
- `listLabels`: List labels on a file.
- `modifyLabels`: Add or modify labels on a file.
- `update`: Update file metadata, content, or both with patch semantics. The
  upload endpoint has the same size and MIME constraints as `create`.
- `watch`: Subscribe to changes to a file.

See [Create and manage files][create-file],
[Download and export files][downloads], [Search for files][search-files],
[List labels][list-labels], and [Set a label field][set-label].

### `operations`

- `get`: Get the latest state of a long-running operation. Poll at intervals
  recommended by the API service.

### `permissions`

- `create`: Create a permission for a file or shared drive.
- `delete`: Delete a permission.
- `get`: Get a permission by ID.
- `list`: List permissions for a file or shared drive.
- `update`: Update a permission with patch semantics.

Concurrent permission operations on the same file are unsupported; only the
last update is applied. See [Share files, folders, and drives][sharing].

### `replies`

- `create`: Create a reply to a comment.
- `delete`: Delete a reply.
- `get`: Get a reply by ID.
- `list`: List replies to a comment.
- `update`: Update a reply with patch semantics.

See [Manage comments and replies][comments].

### `revisions`

- `delete`: Permanently delete a binary-file revision. Revisions of Google
  Docs, Sheets, and Slides, and the last remaining revision, cannot be deleted.
- `get`: Get revision metadata or content by ID.
- `list`: List revisions. Large or frequently edited files can return an
  incomplete history, so the first returned revision might not be the oldest.
- `update`: Update a revision with patch semantics.

See [Manage revisions][revisions].

### `teamdrives`

These methods are deprecated:

- `create`: Use `drives.create`.
- `get`: Use `drives.get`.
- `list`: Use `drives.list`.
- `update`: Use `drives.update`.

## Discover Commands

Inspect the service and exact method before calling it:

```bash
gws drive --help
gws schema drive.<resource>.<method>
```

Use the schema output to construct `--params` and `--json`. Confirm with the
user before executing any create, update, delete, copy, upload, permission,
comment, reply, label, access-proposal resolution, watch, channel-stop, or
shared-drive visibility change unless the user already authorized that exact
operation.

[changes]: https://developers.google.com/workspace/drive/api/guides/manage-changes
[comments]: https://developers.google.com/workspace/drive/api/guides/manage-comments
[create-file]: https://developers.google.com/workspace/drive/api/guides/create-file
[downloads]: https://developers.google.com/workspace/drive/api/guides/manage-downloads
[fields]: https://developers.google.com/workspace/drive/api/guides/fields-parameter
[list-labels]: https://developers.google.com/workspace/drive/api/guides/list-labels
[pending-access]: https://developers.google.com/workspace/drive/api/guides/pending-access
[push]: https://developers.google.com/workspace/drive/api/guides/push
[revisions]: https://developers.google.com/workspace/drive/api/guides/manage-revisions
[search-files]: https://developers.google.com/workspace/drive/api/guides/search-files
[search-shared-drives]: https://developers.google.com/workspace/drive/api/guides/search-shareddrives
[set-label]: https://developers.google.com/workspace/drive/api/guides/set-label
[shared-drives]: https://developers.google.com/workspace/drive/api/guides/manage-shareddrives
[sharing]: https://developers.google.com/workspace/drive/api/guides/manage-sharing
[user-info]: https://developers.google.com/workspace/drive/api/guides/user-info
