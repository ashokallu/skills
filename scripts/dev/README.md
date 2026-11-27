# Shared skill scripts

These helpers live at the checkout-relative `scripts/dev/` paths used by the
skills. Tools that operate on a checkout should be launched from the intended
Git worktree. Check `--help` for the wrapper's supported options before use.

## Setup by workflow

| Workflow | Configuration |
| --- | --- |
| Cross-harness collaboration | Install the CLI for the chosen harness. Provide `AGENT_COLLAB_VPN_URL` or the wrapper's `--vpn-url` when a VPN probe is needed. |
| Muse MSP | Install the pinned Node dependency with `npm ci --ignore-scripts --prefix scripts/dev/muse-msp`. |
| Browser authentication | Supply the app URL, API URL, and cookie domain with the flags in `agent-browser-auth.sh --help`. The documented example URLs use reserved domains. |
| Local TLS | Set `LOCAL_DEV_CA_CERT` to the certificate path, or use the checkout's `infrastructure/caddy/local-dev.crt`. |
| Cloud SQL | Set `GOOGLE_CLOUD_PROJECT`, `CLOUD_SQL_INSTANCE`, `CLOUD_SQL_DATABASE`, and `GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT`. |
| Staging MongoDB | Set `APP_STG_MONGO_PROJECT`, `APP_STG_MONGO_INSTANCES`, and the connection variable `APP_STG_MONGO_URL` for the read-only MCP helper. |
| Jira | Set `JIRA_URL` and `JIRA_PROJECT_KEY`. The helper resolves the GitHub repository from the target worktree. |

Backend CI checks, browser test-suite scripts, and repository contract checks
depend on the adopting project's application layout, CI definitions, or eval
fixtures. Names such as `cleanup-runs.ts` and `bootstrap-local-auth.ts` refer
to helpers in that project's test suite. Operating-system paths and paths
inside isolated runtime namespaces are part of their respective tool contracts.
