---
name: vscode-integrated-browser
description: Deterministic example-app local auth and UI work using VS Code integrated browser tools. Use when browser tools are available and you need an authenticated session on app-local without relying on agent-browser or playwright-cli.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-08 -->

# vscode-integrated-browser

## Purpose

Use this skill when you have access to the VS Code browser tool family and need
an authenticated session for local example-app work.

This skill exists to remove the auth ambiguity.

It is also the preferred first lane for live example-app UI triage when the
problem might be route drift, control mismatch, or selector brittleness. Use it
to inspect the whole page state — route, accessible controls, visible menus,
and post-click behavior — before translating the result into Playwright code.
Screenshots are supporting evidence only; they are not the primary selector
source when interactive browser state is available.

The same rule applies to authenticated Sanity Studio triage on staging or
production. Recent Learn Workspace checks showed that a valid logged-in Studio
session can still present very different UI states depending on how you reach a
route: direct `page.goto()` opens of `/structure` or content-type paths can
land on a shell with `Drafts` and pane errors, while user-style navigation from
the workspace root exposes the real content-type list. Treat the integrated
browser as the source of truth for those route and control differences before
changing Playwright selectors or assuming a missing storage-state file is the
only failure.

When the task needs repeatable read-only Sanity validation in a git worktree,
keep the saved-session artifacts environment-specific: staging and production
should use distinct gitignored files under `e2e/pd/.auth/` rather than one
shared `sanity-studio-state.json`. The current helper flow uses
`sanity-studio-state-stg.json` and `sanity-studio-state-prod.json`, resolved
from the active env.

The deterministic rule is:

1. log in on `https://app.local.example.com:4443/`
2. verify auth on `https://app.local.example.com:4444/api/users/me`
3. continue work on the authenticated `https://app.local.example.com:4443/` session

Use `:8443` only as a legacy fallback when you are explicitly debugging the old
connect-backed surface. It is no longer the default local auth entry point.

## When to apply

Apply this skill when the task mentions any of these:

- VS Code integrated browser
- browser tools
- local UI verification on example-app
- login on app-local
- authenticated UI work on `:4443`
- UI debugging that requires a real logged-in session
- local E2E exploration without `agent-browser` or `playwright-cli`

## Non-negotiable rules

- **Start local auth on `:4443` first.**
- **Always prove the session with `:4444/api/users/me` before trusting the UI.**
- **Use `:8443` only when intentionally reproducing a legacy local-auth behavior.**
- **For local dev auth, prefer the static credentials in `e2e/pd/.env.local`.**
- **For visual regression auth, always use static test-user credentials; do not
  create fresh Genesis users.**
- **Only create a fresh Genesis user through the staging bootstrap path in
  `e2e/pd`, and only for regression-test or auth-flow debugging when reusable
  auth is unavailable.**
- Prefer the **same integrated-browser page/context** for login, auth probe, and
  follow-up navigation.
- Do not treat a visible avatar by itself as proof of auth.
- Do not make direct Playwright `storageState.json` import the primary workflow.
  That is unnecessary for the verified path here.
- Do not print raw passwords, cookies, or tokens into chat.

If the user explicitly asks for the VS Code integrated browser on staging auth
triage, use this skill as a **read-only proof lane** before changing Playwright
selectors. Verify which staging `Sign In` control actually opens
`https://login.staging.example.com/en/sign-in` and do not assume the first
visible `/sign in/i` control matches the automation target. Logged-out staging
Learn pages can expose more than one visible `Sign In` control at once (for
example a hero CTA plus a header/user-menu entry), and the header/user-menu path
may be the one that matches the real auth handoff.

For authenticated staging or prod UI triage, use the integrated browser as a
ground-truth lane for route-changing controls before changing Playwright page
objects. On production Learn, manually opening `My Learning` and clicking
`In Progress` updated the route to `?tab=inProgress` even when the E2E tab
button click later proved flaky in trace. When browser automation and manual UI
behavior disagree, capture the live integrated-browser route/state first and
then decide whether the page object or the assertion is the brittle piece.

## Tool choice inside the integrated browser

Prefer these browser tools first:

- `open_browser_page` or `navigate_page` — open `:4443` first; use `:8443` only for legacy fallback debugging
- `read_page` — inspect the full current interactive state, route, and refs before writing or changing selectors
- `click_element` / `type_in_page` — simple page interactions
- `run_playwright_code` — use this when:
    - the Genesis login iframe must be resolved
    - a legacy modal/backdrop intercepts clicks
    - you need an authenticated API probe from the current browser context
- `screenshot_page` — capture proof after auth succeeds or after `read_page` has already established the live UI state; do not treat screenshots as the primary diagnosis surface

Important runtime note for `run_playwright_code` in this workflow:

- treat the top-level snippet as **Playwright-only**, not a full Node.js shell
- do **not** assume top-level `require(...)` is available
- do **not** assume top-level `fetch(...)` is available outside `page.evaluate(...)`
- when you need browser-network access, run it inside `page.evaluate(...)`
- when a click triggers navigation, expect the current execution context to be
  destroyed; re-read the page or run a fresh snippet after navigation settles

## Preconditions

Before using this skill, make sure the local stack is reachable:

- `https://app.local.example.com:4443/`
- `https://app.local.example.com:4444/api/health-check`
- `https://app.local.example.com:8443/` only if you also need to compare legacy local auth behavior

If auth credentials are needed for automated sign-in, do **not** create a fresh
user by default. Use the local static credentials first.

Best local-dev credential source:

- read `e2e/pd/.env.local`
- use `TEST_USER_EMAIL` as the primary local dev auth user
- use `TEST_USER_PASS` as the password
- `e2e-user@example.com` is also valid for local dev auth and uses
  the same `TEST_USER_PASS` value

Do not hardcode the password or paste it into chat. Read the value from
`e2e/pd/.env.local` or the current process environment, then fill the Genesis
iframe directly.

Fallback source for generated or CI-like auth flows:

- inspect `e2e/pd/.auth/run-*/meta/run-meta.json`
- prefer a run where `baseURL` is `https://app.staging.example.com`
- prefer a run where `env` is `stg`
- if multiple `stg` runs exist, prefer the newest one by `timestamp`
- then read that run's `users/worker-0.json`

Do **not** make `e2e/pd/.auth/run-*/storage/` a dependency for this workflow.
Those session artifacts can be stale, and the verified integrated-browser path
does not need them.

Fast-prep shortcut:

- if you already have one or more fresh `stg` runs in `e2e/pd/.auth`, you can
  usually skip `tests:stg-auth-bootstrap` entirely for integrated-browser prep
- pick the newest valid `stg` run from `meta/run-meta.json`
- use only `users/worker-0.json` for the browser login
- leave `storage/` artifacts for Playwright-based reuse workflows

Why this matters:

- local example-app and staging Learn both use Genesis staging auth services
- a staging-backed run already contains reusable Genesis credentials for
  generated or CI-like fallback flows
- prod-backed runs are not the right source when you need local or staging auth

Auth-selection rule by workflow:

- regression tests or auth-flow debugging: reuse compatible `.auth` run
  metadata first; if no valid reusable run exists, create a fresh staging user
  through the E2E bootstrap path
- visual regression: force static-user auth from the relevant `TEST_USER_EMAIL`
  and `TEST_USER_PASS` values; if static credentials are unavailable, stop and
  report the missing static auth config instead of bootstrapping a new user

If no valid staging-backed run exists for a regression-test or auth-flow debug
task, or available runs are only `prod`, create a fresh staging user from
`e2e/pd` first:

```bash
cd e2e/pd && npm run tests:stg-auth-bootstrap
```

If you also need refreshed local auth artifacts, you can then run:

```bash
cd e2e/pd && npm run tests:local-auth-bootstrap
```

Repo note: `e2e/pd/scripts/bootstrap-local-auth.ts` already follows this order:

1. reuse a valid local run if available
2. otherwise reuse a valid staging run
3. otherwise create a fresh staging run, then bootstrap local

Fresh-bootstrap nuance:

- `tests:stg-auth-bootstrap` provisions an ephemeral Genesis user and still
  posts fixed term versions during user creation via
  `e2e/pd/api/CreateUser.api.ts`
- however, live validation on `2026-04-15` showed that a fresh staging-backed
  user can still hit a the organization updated-terms interstitial after iframe submit
- after accepting the interstitial, local unified login can return through
  `https://app.local.example.com:4443/?signup=true`, then the authenticated
  `:4444/api/users/me` probe should return `200`
- do **not** assume that a fresh staging-backed user will skip the updated-terms
  branch just because the bootstrap path posted earlier TOS versions

## Deterministic auth workflow

### 1. Open the unified-login origin

Start at:

- `https://app.local.example.com:4443/`

Do not begin on `:8443` unless you are deliberately debugging the legacy
connect-backed surface.

### 2. Dismiss blockers before clicking Sign in

Clear whichever cookie or consent blocker is actively intercepting the current
action. Do not over-clean the page if the Genesis iframe is already open and
interactive.

If normal click tools get intercepted, use `run_playwright_code` to dismiss directly:

```ts
const dismiss = page.getByRole("button", { name: /^dismiss$/i }).first();
if (await dismiss.isVisible().catch(() => false)) {
    await dismiss.click();
}
// then dismiss the cookie banner if present
const rejectAll = page.getByRole("button", { name: /reject all/i }).first();
if (await rejectAll.isVisible().catch(() => false)) {
    await rejectAll.click();
}
```

### 3. Open the Genesis login dialog

Click the `Sign in` control on `:4443`.

### 4. Resolve the login iframe by frame URL

The iframe selector can be unstable. Do not rely only on a static DOM attribute
such as `iframe[title="Login dialog"]`.

Use the frame whose URL contains one of:

- `id.staging.example.com/en/conversations/`
- `login.staging.example.com`

Minimal pattern:

```ts
const loginFrame = page
    .frames()
    .find(
        (f) =>
            f.url().includes("id.staging.example.com/en/conversations/") ||
            f.url().includes("login.staging.example.com"),
    );

if (!loginFrame) {
    throw new Error("Genesis login frame not found on :4443");
}
```

### 5. Fill credentials inside the frame

Inside that frame, fill:

- `Email`
- `Password`
- click `Sign in`

Minimal pattern:

```ts
await loginFrame.getByRole("textbox", { name: /email/i }).fill(email);
await loginFrame.getByRole("textbox", { name: /password/i }).fill(password);
await loginFrame.getByRole("button", { name: /^sign in$/i }).click();
```

### 6. Confirm post-submit auth settled

A successful post-submit handoff can produce a frame URL containing:

- `/public/pages/auth/cbiframe.html?...&code=...`

That is a useful signal when it appears, but it is **not required**.

Two post-submit branches are now live-verified:

1. **Static local-dev user branch**:
    - page can return directly to `https://app.local.example.com:4443/`
2. **Fresh staging-backed user branch**:
    - after iframe submit, the page surfaced a the organization updated-terms interstitial
      with an `Accept` button
    - after accepting, the page navigated through a relay/navigation hop and
      settled on `https://app.local.example.com:4443/?signup=true`

For both branches, the decisive proof of success is a `200` from
`:4444/api/users/me`, plus authenticated UI on `:4443`.

Also live-verified on 2026-04-15:

- accepting the updated-terms interstitial can immediately destroy the current
  browser execution context because the page navigates during settlement
- when that happens, treat `Execution context was destroyed` as a navigation
  signal, re-read the page, and continue from the settled `:4443` page instead
  of restarting login

### 7. Probe authenticated API access on `:4444`

Do this before trusting the UI.

Current working request shape:

- URL: `https://app.local.example.com:4444/api/users/me`
- `credentials: 'include'`
- optional header: `X-Requested-With: XMLHttpRequest`

Minimal pattern:

```ts
const authProbe = await page.evaluate(async () => {
    const res = await fetch("https://app.local.example.com:4444/api/users/me", {
        credentials: "include",
        headers: {
            "X-Requested-With": "XMLHttpRequest",
            Accept: "application/json",
        },
    });

    return {
        status: res.status,
        snippet: (await res.text()).slice(0, 200),
    };
});

if (authProbe.status !== 200) {
    throw new Error(`Auth probe failed with status ${authProbe.status}`);
}
```

Keeping `X-Requested-With: XMLHttpRequest` is fine, but recent unified-login
validation did not require it.

### 8. Continue in the same page/context on `:4443`

Navigate the already-authenticated integrated-browser page to:

- `https://app.local.example.com:4443/`
- or a specific target route such as `/pathways`

Then verify authenticated UI affordances.

Strong UI signals:

- `My Learning` points to `/u/<user-id>`
- user-menu button renders the user's initial instead of a generic sign-in icon
- home page shows personalized content such as `Welcome back ...`

Live validation note:

- navigating the same page to `:4443/` can time out while waiting for
  `domcontentloaded` even when the page has already landed successfully
- when that happens, immediately follow with `read_page` and verify the URL plus
  authenticated UI before retrying navigation
- on 2026-04-15, `:4443/` timed out exactly this way while already showing
  authenticated UI (`My Learning` user link, user-menu initial, `Welcome back`)

## Golden path snippet

Use this when the task needs a single integrated-browser login routine.

```ts
const dismiss = page.getByRole("button", { name: /^dismiss$/i }).first();
if (await dismiss.isVisible().catch(() => false)) {
    await dismiss.click();
}
const rejectAll = page.getByRole("button", { name: /reject all/i }).first();
if (await rejectAll.isVisible().catch(() => false)) {
    await rejectAll.click();
}

await page.goto("https://app.local.example.com:4443/", {
    waitUntil: "domcontentloaded",
});

await page
    .getByRole("button", { name: /^sign in$/i })
    .first()
    .click();

const loginFrame = page
    .frames()
    .find(
        (f) =>
            f.url().includes("id.staging.example.com/en/conversations/") ||
            f.url().includes("login.staging.example.com"),
    );
if (!loginFrame) {
    throw new Error("Genesis login frame not found on :4443");
}

await loginFrame.getByRole("textbox", { name: /email/i }).fill(email);
await loginFrame.getByRole("textbox", { name: /password/i }).fill(password);
await loginFrame.getByRole("button", { name: /^sign in$/i }).click();

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
    throw new Error(`Local auth probe failed with status ${authProbe.status}`);
}
```

## What to avoid

Avoid these mistakes:

- opening `:8443` first and assuming it is still the deterministic local auth
  path
- skipping `e2e/pd/.env.local` when local static test credentials are available
- creating a brand-new Genesis user when local static credentials or a reusable
  staging-backed run already fit the task
- creating a fresh user from a `prod` run
- relying on `iframe[title="Login dialog"]` as the only iframe selector
- assuming `run_playwright_code` can read local files with top-level
  `require("fs")` or fetch localhost resources without CORS handling
- diagnosing a UI mismatch from screenshots alone when `read_page`, live clicks,
  and browser-context inspection could prove the actual route/control state
- assuming Sanity Studio deep links such as `/structure` or `/quiz`
  are equivalent to clicking through the authenticated workspace home
- assuming the current Learn Workspace exposes a visible `Create New` button or
  a `Learn Content` menu item without first proving those controls in the live UI
- trusting auth because the page “looks logged in” without the `:4444` probe
- opening a fresh browser page and abandoning the authenticated context before
  verifying the session
- printing credentials from `.env.local` or `worker-0.json` into the chat response

## Troubleshooting

### Clicks on `:4443` are intercepted

Cause:

- OneTrust cookie banner, updated terms, or another consent surface is
  intercepting

Fix:

- dismiss the visible blocker and re-read the page
- continue if the Genesis iframe is already open and interactive

### The Genesis iframe is visible in snapshot output but form controls cannot be found

Cause:

- wrong iframe selector

Fix:

- resolve by frame URL containing `id.staging.example.com/en/conversations/` or
  `login.staging.example.com`

### `:4444/api/users/me` returns `401`

Cause candidates:

- login did not actually complete
- wrong browser context or page was used after login

Fix:

- repeat the `:4443` login flow in the same page/context
- re-run the auth probe from the same page/context
- inspect session state and navigation first

### A the organization ID updated-terms interstitial appears after iframe submit

Cause:

- the selected local static or staging-backed user still needs a current the organization
  web-terms accept
- this can happen even for a fresh staging-backed user despite
  `CreateUser.api.ts` posting earlier fixed term versions during bootstrap

Fix:

- treat this as a valid auth branch, not an automatic failure
- dismiss any cookie banner that intercepts the `Accept` button
- obtain explicit user approval before clicking `Accept`
- once the page returns to app-local, continue with the normal
  `:4444/api/users/me` probe
- if accepting the terms destroys the current execution context, re-read the
  settled page and continue from there instead of re-running login

### `run_playwright_code` fails with `ReferenceError: require is not defined`

Cause:

- the browser automation snippet is not running with unrestricted Node globals

Fix:

- do not plan around top-level `require(...)` for local file reads
- keep browser fetches inside `page.evaluate(...)`
- default to reading `e2e/pd/.env.local` or `users/worker-0.json` outside the
  browser snippet and pass `email` / `password` into the iframe-fill steps
  directly
- only if the active workflow is constrained to browser-only execution and
  cannot receive those values normally, use a **short-lived localhost helper**
  as a fallback and tear it down immediately after login

Safe fallback pattern:

1. start a localhost-only helper from repo `tmp/`
2. serve exactly one tiny JSON payload such as
   `{"email":"...","password":"..."}`
3. add permissive localhost CORS headers if the browser context must fetch it
4. fetch the file from `page.evaluate(...)`
5. kill the helper and delete the temporary script when done

Never paste the credential values into chat.

### `page.evaluate: Execution context was destroyed`

Cause:

- login submit or route navigation replaced the current document while the script
  was still running

Fix:

- treat this as a likely **successful navigation signal**, not immediate failure
- re-run `read_page` or `read_file` on the tool-generated page snapshot
- verify post-navigation state directly:
    - authenticated UI on `:4443`, or
    - `:4444/api/users/me` returns `200`
- continue with a fresh automation snippet after the page settles

### `navigate_page` or `page.goto` to `:4443` times out even though the page loads

Cause:

- local Next.js navigation can miss the tool's waiting condition while still
  rendering the target page successfully

Fix:

- treat the timeout as inconclusive, not automatic failure
- immediately call `read_page`
- if the URL is already the target route and authenticated UI signals are
  present, continue from that page instead of re-running login

### Localhost credential fetch fails with CORS in `page.evaluate(...)`

Cause:

- browser-context fetches obey origin policy
- a plain localhost file server does not emit `Access-Control-Allow-Origin`

Fix:

- do not assume `http://127.0.0.1:<port>/...` is readable from
  `https://app.local.example.com:*`
- if a localhost bridge is necessary, serve the file with explicit CORS headers
- keep the bridge localhost-only and short-lived

### `open_browser_page` or `read_page` returns a large side-file instead of inline text

Cause:

- the tool emitted a large result payload and stored it on disk

Fix:

- immediately read the referenced side-file
- recover the real page ID, URL, and snapshot state from that file
- continue using that page ID; do not open duplicate pages unless necessary

### `:4443` still looks logged out after successful `:4444` probe

Cause candidates:

- navigation happened in a different context
- page needs a clean navigation after auth settles

Fix:

- navigate the same page/context directly to `:4443`
- then re-read the page and open the user menu again

### Authenticated Sanity Studio loads only the shell or `Drafts`

Cause candidates:

- direct deep-link navigation reached an incomplete Studio pane state even
  though the session is valid
- the current workspace expects user-style navigation from the workspace root

Fix:

- re-open the authenticated workspace root first
- inspect the visible content-type links from that root
- click through the live workspace links instead of freezing selectors from a
  blank-shell deep link
- do not treat a saved Studio storage-state file as proof that selectors such
  as `button[name=/new|create/i]` or `menuitem[name="Learn Content"]` exist in
  the current workspace

### Login button was clicked, the iframe still shows populated fields, and auth is not complete yet

Cause candidates:

- the submit is still in progress
- the iframe has not been torn down yet even though auth is succeeding

Fix:

- wait a few seconds first and inspect the iframe state
- if the iframe `Sign in` button is disabled, treat that as an in-flight submit
- probe `:4444/api/users/me` before clicking again
- only retry the iframe submit if the button becomes enabled again and the auth
  probe is still non-`200`

## Success criteria

You are done only when all of these are true:

- credential source was checked in `e2e/pd/.env.local`, or fallback generated
  credentials were checked in `e2e/pd/.auth/run-*/meta/run-meta.json`
- local credentials came from `TEST_USER_EMAIL` plus `TEST_USER_PASS`, or
  fallback generated credentials came from a staging-backed run
  (`baseURL=https://app.staging.example.com`, `env=stg`) or a new staging user
  was created first
- login was initiated on `:4443`
- the Genesis frame was resolved and submitted
- any updated-terms interstitial was handled if it appeared
- `:4444/api/users/me` returned `200`
- `:4443` showed authenticated UI
- any temporary localhost auth bridge was removed after use

## References

- `docs/vscode-integrated-browser-auth.md`
- `e2e/pd/utils/legacyIframeLogin.ts`
- `e2e/pd/docs/PLAYWRIGHT-AUTH-WORKFLOW.md`
- `docs/agent-browser.md`
- `docs/agent-browser-cli.md`
