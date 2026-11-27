---
name: oracle
description: Use Oracle browser mode for second-model repo review through a logged-in Chrome CDP session.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-03 -->

# Oracle — browser only in example-app

Oracle bundles your prompt + selected files into one “one-shot” request so
another model can answer with real repo context through browser automation.
Treat outputs as advisory: verify against the codebase + tests.

## Hard rule for this repo

- Do not use Oracle API mode in `example-app`.
- Do not rely on Oracle's engine auto-selection in this repo.
- Always use browser mode backed by a real logged-in Chrome session over CDP.
- Inside Codex, call Oracle through the MCP tool with `engine: "browser"` when
  the MCP server has desktop access; otherwise use the CLI copy-profile path
  below.
- Never pass `browserThinkingTime` to Oracle in this repo. Omit the field
  entirely from MCP calls and CLI invocations.
- Only call the MCP tool after the browser/CDP/config preflight below passes.
- If the preflight fails, fix the browser/CDP/config state first instead of
  falling back to API mode.

## Main use case

Default and required workflow here: browser mode with ChatGPT Pro models
through a logged-in Chrome session.

Recommended defaults:

- engine: browser
- model: current Pro model already selected in ChatGPT
- attachments: a narrow, intentional file set
- sessions: use slugs so you can reattach instead of re-running

## Golden path

1. Pick the smallest file set that still contains the truth.
2. Verify the browser/CDP/config preflight below.
3. Use Oracle MCP in browser mode when the MCP server has a desktop display.
4. If MCP browser launch fails because the MCP process cannot see the desktop,
   use the CLI copy-profile path from a shell that has `DISPLAY` and
   `XAUTHORITY`.
5. If the run detaches or times out, reattach to the stored session instead of
   re-running it.

## Commands

CLI commands below are for local debugging and preflight. In Codex, prefer the
Oracle MCP tool after preflight succeeds unless the MCP server lacks desktop
access.

Show help:

```bash
npx -y @steipete/oracle --help
npx -y @steipete/oracle oracle-mcp --help
```

Preview only:

```bash
npx -y @steipete/oracle --dry-run summary -p "<task>" --file "src/**"
npx -y @steipete/oracle --dry-run full -p "<task>" --file "src/**"
```

Token/cost sanity:

```bash
npx -y @steipete/oracle --dry-run summary --files-report -p "<task>" --file "src/**"
```

Manual paste fallback:

```bash
npx -y @steipete/oracle --render --copy -p "<task>" --file "src/**"
```

## Attaching files

`--file` accepts files, directories, and globs. Use multiple `--file` flags and
`!` exclusions aggressively.

Examples:

```bash
--file "src/**"
--file src/index.ts
--file docs --file README.md
--file "src/**" --file "!src/**/*.test.ts" --file "!**/*.snap"
```

Important behavior from Oracle:

- skips common bulky dirs like `node_modules`, `dist`, `.git`, `.next`, `tmp`
  unless explicitly requested
- honors `.gitignore` when expanding globs
- does not follow symlinks
- rejects files above the default size cap unless configured otherwise

## Browser-only settings

Oracle exposes these browser flags, but `example-app` must omit
`browserThinkingTime` entirely because it is not reliable here.

- `--browser-model-strategy <select|current|ignore>`
- `--browser-manual-login`
- `--browser-port <port>`
- `--browser-thinking-time <light|standard|extended|heavy>`
- `--browser-keep-browser`
- `--browser-attachments auto|never|always`
- `--copy-profile <dir>`
- `--remote-host`, `--remote-token`
- `--remote-chrome <host:port>`

Do not use API-only Oracle options in this repo.

## Sessions

- stored under `~/.oracle/sessions` unless `ORACLE_HOME_DIR` overrides it
- use `--slug "<short-name>"` to keep them easy to reattach
- list recent runs with `oracle status --hours 72`
- reattach with `oracle session <id> --render`

## Prompt pattern

Oracle starts with zero project knowledge. Include:

1. short project briefing
2. exact task/question
3. constraints / non-goals
4. desired output format
5. the file set that contains the truth

Example:

```text
Find the most likely root cause for this flaky login flow.
Return:
1. root cause
2. minimal fix
3. regression risks
Do not suggest broad refactors.
```

## Safety

- Never attach secrets, tokens, cookies, or auth-state files unless absolutely
  required.
- Prefer “just enough context” over repo dumps.
- Verify Oracle output locally before acting on it.

## Browser/CDP preflight for example-app

This repo has a verified Oracle browser setup for ChatGPT Pro:

1. Make sure the desktop session is visible to the process that will launch
   Chrome.

```bash
printf 'DISPLAY=%s\nXAUTHORITY=%s\n' "${DISPLAY-}" "${XAUTHORITY-}"
```

Expected on the current workstation:

```text
DISPLAY=:0
XAUTHORITY=$HOME/.Xauthority
```

If Oracle browser mode fails with `Missing X server or $DISPLAY`, the Oracle
process cannot launch visible Chrome. Restart the MCP server or use the CLI
copy-profile path below from a shell that has `DISPLAY`.

2. Start a CDP-safe cloned Chrome profile instead of trying to add DevTools to
   an already-running default Chrome session. Close the real `Person 2` Chrome
   window first when possible, because copied Chrome lock files can cause the
   clone to exit or hand off to the already-running browser.

```bash
bash scripts/dev/start-chrome-cdp-from-profile.sh \
  --profile-name "Person 2" \
  --url "about:blank" \
  --port 9222
```

3. Verify CDP is alive:

```bash
curl http://127.0.0.1:9222/json/version
```

You should get JSON with a `webSocketDebuggerUrl`. If you do not, Oracle is not
ready.

4. If the cloned browser exits immediately, remove copied lock metadata from
   the cloned profile only, then recreate or relaunch the clone:

```bash
find ~/.cache/agent-browser-cdp/google-chrome-Person_2 -maxdepth 2 \
  \( -name 'Singleton*' -o -name 'LOCK' -o -name 'lockfile' -o -name '.cdp.pid' \) \
  -print -delete
```

Never remove these files from `~/.config/google-chrome`; that is the real user
profile.

5. Make sure that exact cloned CDP browser is visibly logged into ChatGPT, or
   use the CLI copy-profile path below when the MCP launch environment cannot
   use the desktop.

6. Keep Oracle configured via `~/.oracle/config.json` like this for the MCP
   manual-login path:

```json
{
  "browser": {
    "debugPort": 9222,
    "chatgptUrl": "https://chatgpt.com/",
    "manualLogin": true,
    "manualLoginProfileDir": "/path/to/browser-profile",
    "modelStrategy": "ignore"
  }
}
```

7. Verify the config actually matches the running browser:

```bash
cat ~/.oracle/config.json
```

- `debugPort` must match the live CDP port, usually `9222`.
- `manualLogin` must be `true`.
- `manualLoginProfileDir` must match the cloned CDP profile directory you
  launched.
- `modelStrategy` must be `"ignore"` so Oracle does not try to fight the
  ChatGPT UI.

8. Restart Codex after changing `~/.oracle/config.json`, because the Oracle MCP
   server may cache browser config at process start.

9. Run the minimal smoke test only after the relevant preflight passes:

```text
Prompt: Reply with exactly OK.
```

Expected result for normal chat mode: Oracle answers with exactly `OK` through
the browser-backed session. If ChatGPT web search is selected, a transport smoke
may instead return a search-mode response such as asking what to search for; in
that case browser access works, but the ChatGPT UI mode is not clean for the
strict `OK` assertion.

10. When you are done, stop the cloned CDP Chrome session explicitly:

```bash
bash scripts/dev/stop-chrome-cdp.sh \
  --pidfile ~/.cache/agent-browser-cdp/google-chrome-Person_2/.cdp.pid
```

This stops the cloned CDP browser safely without touching your primary Chrome
profile under `~/.config/google-chrome`.

## Working CLI path when MCP lacks the desktop

Use this path when `mcp__oracle__.consult` fails with `Missing X server or
$DISPLAY` in `~/.cache/agent-browser-cdp/google-chrome-Person_2/chrome-err.log`
or then reports `connect ECONNREFUSED 127.0.0.1:9222`. The failure means the
Oracle MCP server was started without the desktop display environment, so its
Chrome exits before CDP is reachable.

Run from a normal shell that has `DISPLAY=:0` and `XAUTHORITY`:

```bash
TMP_ORACLE_HOME="$(mktemp -d /tmp/oracle-home-copy-profile.XXXXXX)"
mkdir -p "${TMP_ORACLE_HOME}"
cat >"${TMP_ORACLE_HOME}/config.json" <<'JSON'
{
  "browser": {
    "debugPort": 9222,
    "chatgptUrl": "https://chatgpt.com/",
    "modelStrategy": "ignore"
  }
}
JSON

ORACLE_HOME_DIR="${TMP_ORACLE_HOME}" npx -y @steipete/oracle \
  --engine browser \
  --model "GPT-5.5 Pro" \
  --prompt "Reply with exactly OK." \
  --slug oracle-smoke-gpt-55-pro \
  --copy-profile "${HOME}/.config/google-chrome" \
  --browser-model-strategy ignore \
  --browser-attachments never \
  --no-notify
```

Why this works:

- `ORACLE_HOME_DIR` keeps the smoke run isolated from the persistent
  `~/.oracle/config.json`.
- The temporary config omits `manualLogin`; Oracle refuses `--copy-profile`
  when the persistent manual-login config is active.
- `--copy-profile ~/.config/google-chrome` lets Oracle own the throwaway
  browser profile and avoids the attach-metadata mismatch from
  `--browser-attach-running`.
- The command still uses browser mode and the logged-in `Person 2` Chrome data;
  it does not use Oracle API mode.

## MCP usage rule in Codex

- In Codex, prefer the Oracle MCP tool over ad hoc CLI runs only when the MCP
  server can launch visible Chrome with the desktop display environment.
- Always call `mcp__oracle__.consult` with `engine: "browser"`.
- Always omit `browserThinkingTime`. Do not send it with any value.
- Use `browserAttachments: "always"` only when real browser uploads are needed.
- Do not call Oracle MCP with API engine settings in this repo.
- Do not make Oracle MCP calls until the browser/CDP/config preflight above has
  passed.
- If the MCP path fails with `Missing X server or $DISPLAY`, switch to the
  working CLI path above instead of retrying MCP. Report the mode change and the
  exact smoke result.

Example MCP call shape:

```json
{
  "engine": "browser",
  "model": "GPT-5.4 Pro",
  "prompt": "Reply with exactly OK.",
  "files": [],
  "browserAttachments": "never"
}
```

Useful MCP verification pattern:

- Use `mcp__oracle__.consult` with the smoke-test prompt after preflight.
- Use `mcp__oracle__.sessions` to inspect the stored run if you need to confirm
  which session Oracle attached to or whether a browser-backed run was stored.

## example-app Oracle rules

- Restart Codex after changing `.codex/config.toml`.
- Never use `browserThinkingTime` in this repo. Omit it entirely from Oracle
  calls. In live testing, Oracle fails on the Thinking time dropdown even after
  CDP and login are working.
- If Oracle reports `ECONNREFUSED 127.0.0.1:9223` while your real CDP endpoint
  is alive on `9222`, Oracle is trying to launch a fresh Chrome instead of
  reusing the logged-in one. Recheck `manualLogin`, `manualLoginProfileDir`,
  and `debugPort`.
- If Oracle reports `ECONNREFUSED 127.0.0.1:9222` and
  `chrome-err.log` says `Missing X server or $DISPLAY`, the Oracle process
  lacks desktop access. Use the CLI copy-profile path from a shell with
  `DISPLAY=:0`.
- If Oracle CLI reports `--copy-profile cannot be combined with
  --browser-manual-login`, use a temporary `ORACLE_HOME_DIR` with a minimal
  browser config that omits `manualLogin`.
- If Oracle CLI reports `No running browser with attach metadata matched
  127.0.0.1:9222`, do not use `--browser-attach-running` for the manually
  launched CDP clone. Use the CLI copy-profile path instead.
- If Oracle reports it cannot find the model selector, keep the desired model
  manually selected in ChatGPT and use `modelStrategy: "ignore"`.

## Minimal smoke test

Use this exact smoke test in this repo:

```text
Prompt: Reply with exactly OK.
```

Do not set `browserThinkingTime`.
Omit it entirely.
