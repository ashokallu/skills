<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-05-08 -->

# playwright-mcp (Claude Code edition)

## Purpose

Use this skill when Claude Code has access to browser automation through
Playwright MCP, Chrome DevTools MCP, or an equivalent native browser tool and
you need a deterministic authenticated session for local example-app work.

The deterministic rule is:

1. log in on `https://app.local.example.com:4443/`
2. prove auth on `https://app.local.example.com:4444/api/users/me`
3. continue work in the authenticated `https://app.local.example.com:4443/`
   session

Use `:8443` only as a legacy fallback when explicitly debugging the old
connect-backed surface.

## Tool Portability

Use Claude's available browser capability. The exact tool names vary by
runtime/session; prefer the capability over another runtime's tool spelling:

- navigation to `:4443`
- page snapshot or DOM inspection
- clicking and typing non-sensitive controls
- page-context JavaScript for iframe-aware login and auth probes
- screenshots for evidence
- repo file reads through Claude `Read` or `Bash`

Prefer Playwright MCP when it is available because the workflow was originally
validated there. Chrome DevTools MCP or other native browser tools are
acceptable when they can prove the same auth checks.

## Non-negotiable rules

- **Start local auth on `:4443` first.**
- **Always prove the session with `:4444/api/users/me` before trusting the UI.**
- **Use `:8443` only when intentionally reproducing legacy local-auth behavior.**
- **Prefer credentials from staging-backed `e2e/pd/.auth` runs.**
- **Only create a fresh Genesis user through the staging bootstrap path in `e2e/pd`.**
- Prefer the **same Playwright MCP page/context** for login, auth probe, and navigation.
- Do not treat a visible avatar by itself as proof of auth.
- Do not paste passwords, cookies, or tokens into chat.

## Credential source

Best source — use `Read` or `Bash` (not browser tools) to access these files:

- inspect `e2e/pd/.auth/run-*/meta/run-meta.json`
- prefer a run where `baseURL` is `https://app.staging.example.com`
- prefer a run where `env` is `stg`
- then read that run's `users/worker-0.json`

If no valid staging-backed run exists:

```bash
cd e2e/pd && npm run tests:stg-auth-bootstrap
```

If you also need refreshed local auth artifacts:

```bash
cd e2e/pd && npm run tests:local-auth-bootstrap
```

## Claude-specific secret handling

Do **not** pass raw passwords directly to:

- `mcp__playwright__browser_fill_form`
- `mcp__playwright__browser_type`
- a literal `mcp__playwright__browser_run_code` snippet

Why:

- browser tooling may echo literal fill values in command logs
- browser page-code snippets may not have top-level Node globals such as
  `require` or `process`

Safe pattern:

1. read `worker-0.json` with the **`Read` tool** outside browser tools
2. start a short-lived localhost helper under repo `tmp/` with explicit CORS headers for
   `https://app.local.example.com:*`
3. fetch the credential payload from `page.evaluate(...)` inside `browser_run_code`
4. fill the iframe from the same snippet
5. tear the helper down immediately after use

## Deterministic auth workflow

### 1. Read credentials from the repo

Use the `Read` tool (or `Bash` for glob patterns) — not browser tools:

```
Read: e2e/pd/.auth/run-<id>/meta/run-meta.json   → confirm baseURL + env = stg
Read: e2e/pd/.auth/run-<id>/users/worker-0.json   → email + password
```

### 2. Open the local app origin

Navigate:

```
browser navigate → https://app.local.example.com:4443/
```

Use `:8443` only when the task is explicitly about legacy connect-backed auth
behavior.

### 3. Dismiss blockers

The page may present concurrent blockers:

1. A welcome modal/backdrop — contains a visible `Dismiss` button
2. A OneTrust cookie banner — contains `Reject All` / `Accept All Cookies`

Both appeared at the same time in the live run. Dismiss them in sequence before
clicking `Sign in` — either one can intercept the click.

```
browser snapshot  → inspect for modal ref (Dismiss) + banner ref (Reject All)
browser click     → Dismiss button (modal), if present
browser snapshot  → confirm modal gone
browser click     → Reject All button (cookie banner), if present
browser snapshot  → confirm page ready, Sign in button interactive
```

### 4. Open the Genesis login dialog

```
browser click → Sign in button on :4443
browser snapshot → fresh snapshot after iframe loads
```

If the snapshot exposes iframe controls directly, use them. Otherwise use
page-context JavaScript to locate the Genesis iframe.

### 5. Submit login without surfacing credentials in logs

Use page-context JavaScript with a `page.evaluate(...)` pattern. Fetch
credentials from the short-lived localhost helper (see secret handling above).

Minimal credential fetch + iframe fill pattern:

```ts
const creds = await page.evaluate(async () => {
    const res = await fetch("http://127.0.0.1:<PORT>/creds.json", {
        headers: { Accept: "application/json" },
    });
    return res.json();
});

const loginFrame = page
    .frames()
    .find((f) => f.url().includes("id.staging.example.com/en/conversations/"));

if (!loginFrame) throw new Error("Genesis login frame not found on :4443");

await loginFrame.getByRole("textbox", { name: /email/i }).fill(creds.email);
await loginFrame
    .getByRole("textbox", { name: /password/i })
    .fill(creds.password);
await loginFrame.getByRole("button", { name: /^sign in$/i }).click();
// Do NOT add waitForTimeout or return page.url()/page.title() here.
// The login submit triggers navigation; the MCP snapshot will time out if you
// hold the execution context open. Let the function return immediately and
// treat any resulting TimeoutError as a navigation signal (see Troubleshooting).
```

### 6. Handle post-submit branches

Observed branches:

- direct return to `:4443` or `:4443/?signup=true`
- verified on 2026-03-19: redirect to the organization ID updated-terms interstitial at
  `https://id.staging.example.com/en/conversations/...`

If the updated-terms page appears:

- do **not** click `Accept` without explicit user approval
- dismiss the cookie banner on that page first if it intercepts the `Accept` button
- report that auth is blocked on legal consent if approval is not granted

### 7. Probe `:4444` before trusting the UI

```ts
const authProbe = await page.evaluate(async () => {
    const res = await fetch("https://app.local.example.com:4444/api/users/me", {
        credentials: "include",
        headers: {
            "X-Requested-With": "XMLHttpRequest",
            Accept: "application/json",
        },
    });
    return { status: res.status, body: (await res.text()).slice(0, 200) };
});

if (authProbe.status !== 200) {
    throw new Error(`Auth probe failed with status ${authProbe.status}`);
}
```

Expected: HTTP `200`.

### 8. Confirm authenticated `:4443`

```
browser navigate → https://app.local.example.com:4443/
browser snapshot → confirm authenticated UI
```

Strong authenticated signals:

- `My Learning` links to `/u/<user-id>`
- user menu shows `Settings`
- user menu shows `Sign out`

## Docker preflight

Before starting browser work, confirm the stack is up:

```bash
docker compose -f docker-compose.dev.connect.yml ps
docker compose -f <connect-backend-root>/docker/docker-compose-development.yml ps
curl -fsS https://app.local.example.com:4443/ >/dev/null
curl -fsS https://app.local.example.com:4444/api/health-check >/dev/null
```

## What to avoid

- calling another runtime's tool names when Claude has different native names
- using another runtime's command tools; use Claude `Read` or `Bash`
- opening `:8443` first unless the task is explicitly about legacy local auth
- passing raw passwords to `browser_fill_form`, `browser_type`, or inline snippets
- treating `browser_run_code` as a full Node runtime (`require` and `process` are absent)
- trusting auth because the page looks logged in without the `:4444` probe
- accepting the organization legal terms without explicit user approval

## Troubleshooting

### `mcp__playwright__browser_run_code` fails with `ReferenceError: require is not defined`

- Do not use top-level `require` in browser page-code snippets
- Keep repo file reads in `Read` tool calls outside the browser snippet
- Keep network calls inside `page.evaluate(...)`

### `:4444/api/users/me` returns `401`

- Login did not complete or wrong context was used
- Repeat the `:4443` login flow in the same page/context
- Re-run the auth probe from the same page/context

### Cookie banner intercepts `Accept` on the organization ID terms page

- Take a fresh `browser_snapshot` to find the cookie banner dismiss control
- Click it first, then retry `Accept`
- Obtain explicit user approval before accepting terms

### Localhost credential fetch fails with CORS

- Plain `http.server` fetches fail from `https://app.local.example.com:*`
- Serve with explicit `Access-Control-Allow-Origin: https://app.local.example.com:4443`
- Keep the helper bound to `127.0.0.1`, smallest possible payload, removed after use

## Success criteria

Done only when all of these are true:

- credential source checked in `e2e/pd/.auth/run-*/meta/run-meta.json`
- reused credentials came from a staging-backed run (`baseURL=https://app.staging.example.com`, `env=stg`)
- login initiated on `:4443`
- Genesis form submitted
- any legal-consent interstitial was explicitly approved or reported as a blocker
- `:4444/api/users/me` returned `200`
- `:4443` showed authenticated UI in the same page/context
- any temporary localhost credential helper was removed after use

## References

- `docs/claude-playwright-mcp-auth.md` — companion doc with tool mapping rationale
- `docs/vscode-integrated-browser-auth.md` — current local-auth workflow reference
- `docs/playwright-mcp-auth.md` — historical Playwright MCP auth workflow doc
- `e2e/pd/utils/legacyIframeLogin.ts` — iframe login utility (reference implementation)
- `e2e/pd/docs/PLAYWRIGHT-AUTH-WORKFLOW.md` — e2e auth workflow docs
