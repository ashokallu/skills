# `gws-docs` Lane

```text
Type: service lane
Use when: reading, creating, retrieving, or batch-updating Google Docs, or
          discovering Docs API commands
Owns: Docs resources, methods, schema discovery, and raw API command shape
Requires: gws-shared.md
Outputs: a validated Docs command or a precise schema/setup blocker
```

Read [`gws-shared.md`](gws-shared.md) before using this lane.

```bash
gws docs <resource> <method> [flags]
```

## Helper Command

| Command | Description |
| --- | --- |
| [`+write`](gws-docs-write.md) | Append plain text to a document |

## API Resources

### `documents`

- `batchUpdate`: Apply one or more updates atomically after all requests are
  validated. Reply order matches request order.
- `create`: Create a blank document using the supplied title. Other supplied
  content fields are ignored.
- `get`: Get the latest version of a document.

## Discover Commands

Inspect the service and exact method before calling it:

```bash
gws docs --help
gws schema docs.<resource>.<method>
```

Use the schema output to construct `--params` and `--json`. Confirm with the
user before executing `create`, `batchUpdate`, or another write unless the user
already authorized that exact operation.
