# MCP configuration examples

These files are opt-in. Copy only the server entries you intend to use into
your client's configuration. The examples use a public service endpoint and
reference `CONTEXT7_API_KEY` through the environment.

| Example | Destination |
| --- | --- |
| [Claude Code JSON](claude.mcp.json) | Project `.mcp.json` |
| [VS Code JSON](vscode.mcp.json) | Project `.vscode/mcp.json` |
| [Codex TOML](codex.config.toml) | Codex `config.toml` |

The VS Code example also includes browser tooling. Review the package setup
and use a suitable version before enabling those entries.
