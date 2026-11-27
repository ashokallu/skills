# `gws-docs-write` Lane

```text
Type: write-helper lane
Use when: appending plain text with gws docs +write
Owns: append syntax, flags, examples, and write confirmation
Requires: gws-shared.md
Outputs: an authorized append operation and its result, or a precise blocker
```

Read [`gws-shared.md`](gws-shared.md) before using this lane.

Append plain text to the end of a document body:

```bash
gws docs +write --document <ID> --text <TEXT>
```

## Flags

| Flag | Required | Default | Description |
| --- | --- | --- | --- |
| `--document` | Yes | None | Document ID |
| `--text` | Yes | None | Plain text to append |

## Example

```bash
gws docs +write --document DOC_ID --text 'Hello, world!'
```

## Rules

- Confirm with the user immediately before executing the append unless the
  user explicitly authorized that exact write.
- Text is inserted at the end of the document body.
- Use the raw `documents.batchUpdate` API through
  [`gws-docs.md`](gws-docs.md) when rich formatting is required.

## See Also

- [`gws-shared`](gws-shared.md): global flags, authentication, security, and
  quota attribution.
- [`gws-docs`](gws-docs.md): all supported Google Docs API commands.
