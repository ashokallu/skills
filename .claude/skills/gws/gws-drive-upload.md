# `gws-drive-upload` Lane

```text
Type: write-helper lane
Use when: uploading a local file with gws drive +upload
Owns: upload syntax, flags, examples, MIME/name behavior, and write confirmation
Requires: gws-shared.md
Outputs: an authorized upload operation and its result, or a precise blocker
```

Read [`gws-shared.md`](gws-shared.md) before using this lane.

Upload a file with automatic metadata:

```bash
gws drive +upload <file>
```

## Flags

| Flag | Required | Default | Description |
| --- | --- | --- | --- |
| `<file>` | Yes | None | Path to the local file |
| `--parent` | No | None | Parent folder ID |
| `--name` | No | Source filename | Target filename |

## Examples

```bash
gws drive +upload ./report.pdf
gws drive +upload ./report.pdf --parent FOLDER_ID
gws drive +upload ./data.csv --name 'Sales Data.csv'
```

## Rules

- Confirm with the user immediately before executing the upload unless the
  user explicitly authorized that exact write.
- MIME type is detected automatically.
- The filename is inferred from the local path unless `--name` is supplied.

## See Also

- [`gws-shared`](gws-shared.md): global flags, authentication, security, and
  quota attribution.
- [`gws-drive`](gws-drive.md): all supported Google Drive API commands.
