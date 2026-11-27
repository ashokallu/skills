# `gws-shared` Lane

```text
Type: mandatory prerequisite lane
Use when: any task will inspect, authenticate, or run the gws CLI
Owns: installation, authentication, quota attribution, global flags, command
      syntax, security, shell behavior, and feedback etiquette
Outputs: a secret-safe command plan or an exact setup blocker
Next lane: gws-drive, gws-drive-upload, gws-docs, gws-docs-write, or the
           requested service command
```

## Installation

The `gws` binary must be on `$PATH`. See the
[official project README](https://github.com/googleworkspace/cli#readme) for
installation options.

## Authentication

```bash
# Browser-based OAuth (interactive)
gws auth login

# Service account
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

Credential selection determines which OAuth token or service-account
credential is used. It does not determine or disable quota-project
attribution.

## Quota Project

Use `GOOGLE_WORKSPACE_PROJECT_ID` to select the Google Cloud project that
`gws` attributes quota and billing to:

```bash
export GOOGLE_WORKSPACE_PROJECT_ID=<project-id>
```

The calling principal must have `serviceusage.services.use` on that project.
When a direct Workspace API request succeeds but `gws` returns a 403 naming a
project, inspect quota attribution before replacing credentials. Changing
between keyring, a credentials file, and a raw access token does not by itself
change the quota project.

## Global Flags

| Flag | Description |
| --- | --- |
| `--format <FORMAT>` | Output format: `json` (default), `table`, `yaml`, or `csv` |
| `--dry-run` | Validate locally without calling the API |
| `--sanitize <TEMPLATE>` | Screen responses through Model Armor |

## CLI Syntax

```bash
gws <service> <resource> [sub-resource] <method> [flags]
```

### Method Flags

| Flag | Description |
| --- | --- |
| `--params '{"key": "val"}'` | URL or query parameters |
| `--json '{"key": "val"}'` | Request body |
| `-o, --output <PATH>` | Save binary responses to a file |
| `--upload <PATH>` | Upload file content as multipart data |
| `--page-all` | Auto-paginate with NDJSON output |
| `--page-limit <N>` | Maximum pages with `--page-all`; default is 10 |
| `--page-delay <MS>` | Delay between pages in milliseconds; default is 100 |

Before calling an unfamiliar API method, inspect the service help and exact
schema:

```bash
gws <service> --help
gws schema <service>.<resource>.<method>
```

## Security Rules

- Never output secrets such as API keys, access tokens, refresh tokens, or
  client secrets.
- Confirm with the user before executing write or delete commands unless the
  user explicitly authorized that exact operation.
- Prefer `--dry-run` for destructive operations when the command supports it.
- Use `--sanitize` when the task requires PII or content-safety screening.

## Shell Tips

- In zsh, ranges such as `Sheet1!A1` contain `!`, which can trigger history
  expansion. Use double quotes around the range:

  ```bash
  gws sheets +read --spreadsheet ID --range "Sheet1!A1:D10"
  ```

- Wrap JSON values in single quotes so the shell does not interpret the inner
  double quotes:

  ```bash
  gws drive files list --params '{"pageSize": 5}'
  ```

## Community And Feedback

- When the project is useful, users may star
  <https://github.com/googleworkspace/cli>.
- Direct bugs and feature requests to
  <https://github.com/googleworkspace/cli/issues>.
- Search existing issues before creating a new one. Add context to a matching
  issue instead of filing a duplicate.
