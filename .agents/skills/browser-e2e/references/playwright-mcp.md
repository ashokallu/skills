<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-05-30 -->

# Playwright MCP Reference

## Purpose

Use this skill when browser MCP browser tools are available and you
need a deterministic authenticated session for local example-app work.

This skill complements `.agents/skills/vscode-integrated-browser/SKILL.md`.
That VS Code skill remains current for Copilot.

The deterministic local-auth rule is:

1. start the local dependency stacks
2. log in on `https://app.local.example.com:4443/` through unified login
3. prove auth on `https://app.local.example.com:4444/api/users/me`
4. continue work on the authenticated `https://app.local.example.com:4443/`
   session

Use `https://app.local.example.com:8443/` only as a legacy fallback when you are
explicitly debugging the old connect-backed surface. It is no longer the default
local auth entry point.

## Instruction file routing

Load `.github/instructions/e2e-playwright-tests.instructions.md` when MCP
exploration feeds into E2E spec, page-object, fixture, auth-helper, or visual
regression changes. Load
`.github/instructions/github-workflows.instructions.md` when the task asks
about CI parity or active E2E workflow behavior.

For pure local login/session proof, keep context small and use this skill plus
`repo.md` rather than loading CI-focused instructions.

## When to apply

Apply this skill when the task mentions:

- browser tools
- Playwright MCP
- local UI verification on example-app
- login on app-local
- authenticated UI work on `:4443`
- local browser debugging
- local auth smoke tests

## Non-negotiable rules

- **Run local example-app services from `local-dev-reference`, not `main`.**
  This service-hosting rule does not allow E2E test execution or baseline
  generation in `local-dev-reference`; run E2E commands from an `origin/main`-
  based worktree and use `local-dev-reference` only as the source of service,
  instruction, skill, rule, and env-value references.
- **Start connect-backend dependencies before local auth.**
- **Start local auth on `:4443` first.**
- **Always prove the session with `:4444/api/users/me` before trusting the UI.**
- **Use `:8443` only when intentionally reproducing legacy local-auth behavior.**
- **For local dev auth, prefer the static credentials in `e2e/pd/.env.local`.**
- **For visual regression auth, always use static test-user credentials; do not
  create fresh Genesis users.**
- **Only create a fresh Genesis user through the staging bootstrap path in
  `e2e/pd`, and only for regression-test or auth-flow debugging when reusable
  auth is unavailable.**
- Prefer the same Playwright MCP page/context for login, auth probe, and
  follow-up navigation.
- Do not treat a visible avatar by itself as proof of auth.
- Do not paste passwords, cookies, or tokens into chat.

## Local Stack Preconditions

Genesis auth is still built in the sibling `connect-backend` checkout. Even
though login starts from example-app unified login on `:4443`, local dev and
staging Learn both use Genesis staging auth services. Local auth depends on
connect-backend services and its dependencies being available.

Use the sibling checkout beside the main example-app checkout:

```bash
CONNECT_BACKEND_ROOT="$(cd "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")/../connect-backend" && pwd)"
```

Start the required connect-backend containers:

```bash
docker compose -f "$CONNECT_BACKEND_ROOT/docker/docker-compose-development.yml" up -d mp elasticsearch mongo redis redis2
```

Then inspect `dev_server` before starting processes:

```bash
docker exec dev_server ps aux
```

If backend or view-server processes are absent, start them in separate
persistent terminals:

```bash
docker exec -it dev_server bash
cd server && make run
```

```bash
docker exec -it dev_server bash
cd view_server && yarn dev
```

Then start all example-app services from the root checkout on
`local-dev-reference`:

```bash
docker compose -f docker-compose.dev.connect.yml up -d caddy mongo-express postgres pgadmin redis-insight learnapi nextjs
```

Useful status and readiness checks:

```bash
docker compose -f "$CONNECT_BACKEND_ROOT/docker/docker-compose-development.yml" ps
docker compose -f docker-compose.dev.connect.yml ps
docker exec dev_server ps aux
curl -kfsS https://app.local.example.com:4444/api/health-check >/dev/null
curl -kfsS https://app.local.example.com:4443/ >/dev/null
```

The connect-backend view server can take a while to compile. Expect a cold
start to need more than a few seconds before declaring it broken.

## Tool choice

Prefer these tools first:

- `functions.exec_command` - inspect auth run metadata, start Docker services,
  and check local readiness
- `mcp__playwright__browser_navigate` - open `:4443`; use `:8443` only for
  legacy fallback debugging
- `mcp__playwright__browser_snapshot` - inspect live interactive state and refs
- `mcp__playwright__browser_click` - modal dismissal, sign-in button, and other
  non-sensitive interactions
- `mcp__playwright__browser_run_code` - iframe-aware logic and authenticated API
  probes from the current browser context
- `mcp__playwright__browser_take_screenshot` - capture evidence after auth

`Pending Verification`:

- a Chrome DevTools-only equivalent has not been fully exercised for this
  updated unified-login path

## Credential source

Best local-dev source:

- read `e2e/pd/.env.local`
- use `TEST_USER_EMAIL` as the primary local dev auth user
- use `TEST_USER_PASS` as the password
- `e2e-user@example.com` is also valid for local dev auth and uses
  the same `TEST_USER_PASS` value

Do not hardcode the password or paste it into chat. Read the value from
`e2e/pd/.env.local` or the current process environment, then fill the Genesis
iframe without printing secrets.

Fallback source for generated or CI-like auth flows:

- inspect `e2e/pd/.auth/run-*/meta/run-meta.json`
- prefer a run where `baseURL` is `https://app.staging.example.com`
- prefer a run where `env` is `stg`
- if multiple `stg` runs exist, prefer the newest one by `timestamp`
- then read that run's `users/worker-0.json`

Do not make `e2e/pd/.auth/run-*/storage/` a dependency for this browser workflow.
Those session artifacts can be stale, and interactive unified login does not
need them.

Auth-selection rule by workflow:

- regression tests or auth-flow debugging: reuse compatible `.auth` run
  metadata first; if no valid reusable run exists, create a fresh staging user
  through the E2E bootstrap path
- visual regression: force static-user auth from the relevant `TEST_USER_EMAIL`
  and `TEST_USER_PASS` values; if static credentials are unavailable, stop and
  report the missing static auth config instead of bootstrapping a new user

If no valid staging-backed run exists for a regression-test or auth-flow debug
task, create one first:

```bash
cd e2e/pd && npm run tests:stg-auth-bootstrap
```

If you also need refreshed local auth artifacts:

```bash
cd e2e/pd && npm run tests:local-auth-bootstrap
```

Repo note: `e2e/pd/scripts/bootstrap-local-auth.ts` already follows this order:

1. reuse a valid local run if available
2. otherwise reuse a valid staging run
3. otherwise create a fresh staging run, then bootstrap local

## .agents-specific secret handling rule

Do **not** pass raw passwords directly to:

- `mcp__playwright__browser_fill_form`
- `mcp__playwright__browser_type`
- a literal `mcp__playwright__browser_run_code` snippet

Why:

- `browser_fill_form` was verified to echo literal fill values in its command
  log
- `browser_run_code` was verified to have neither top-level `require` nor
  `process`

Safe pattern:

1. read `worker-0.json` outside browser tools
2. start a short-lived localhost helper under repo `tmp/` with explicit CORS
3. fetch those credentials inside `page.evaluate(...)`
4. fill the iframe from the same `browser_run_code` snippet
5. tear the helper down immediately after use

## Deterministic auth workflow

### 1. Open the unified-login origin

Start at:

- `https://app.local.example.com:4443/`

Do not begin on `:8443` unless you are deliberately debugging the legacy surface.

### 2. Dismiss blockers

Dismiss cookie or consent modals that intercept the current action. Do not
over-clean the page if the Genesis iframe is already open and interactive.

If normal click tools get intercepted, use `browser_run_code` for the visible
blocking control, then take a fresh snapshot before continuing.

### 3. Open the Genesis login dialog

Click the `Sign in` control on `:4443`.

Resolve the login iframe by live state rather than assuming a static selector.
Useful signals include iframe URLs containing:

- `id.staging.example.com/en/conversations/`
- `login.staging.example.com`

### 4. Submit login from the same page/context

Use `mcp__playwright__browser_run_code` when you need to:

- fetch short-lived localhost credentials inside `page.evaluate(...)`
- fill the iframe without surfacing secrets in tool logs
- probe authenticated API access after submit

Keep the post-click snippet minimal. Login submit can trigger navigation and
destroy the execution context, so treat a resulting `TimeoutError` as
inconclusive until a fresh snapshot or auth probe confirms state.

### 5. Handle post-submit branches honestly

Observed branches from previous local auth validation include:

- direct return to authenticated Learn after a previously accepted-terms
  staging user
- a the organization ID updated-terms interstitial on
  `https://id.staging.example.com/en/conversations/...`

If the updated-terms page appears:

- do not click `Accept` without explicit user approval
- report that auth is blocked on legal consent if approval is not granted
- if the click is intercepted, dismiss the cookie banner on that page first and
  retry with a fresh snapshot

### 6. Probe `:4444` before trusting `:4443`

Probe:

- `https://app.local.example.com:4444/api/users/me`
- `credentials: "include"`
- optional header: `X-Requested-With: XMLHttpRequest`

Expected result:

- `200`

### 7. Continue on `:4443`

Navigate the already-authenticated page to:

- `https://app.local.example.com:4443/`
- or a target route like `/pathways`

Strong authenticated signals:

- `My Learning` points to `/u/<user-id>`
- user menu contains `Settings`
- user menu contains `Sign out`

## What to avoid

Avoid these mistakes:

- running the local example-app stack from `main`
- starting example-app without the connect-backend dependencies needed for
  Genesis auth
- opening `:8443` first and assuming it is still the deterministic local login
  path
- reusing credentials from a non-staging run
- typing passwords directly into `browser_fill_form` or `browser_type`
- treating `browser_run_code` as a full Node shell
- trusting auth because the page looks logged in without the `:4444` probe
- accepting the organization legal terms without explicit user approval

## References

- `repo.md`
- `.github/instructions/e2e-playwright-tests.instructions.md`
- `.github/instructions/github-workflows.instructions.md`
- `e2e/pd/docs/scripts-guide.md`
- `e2e/pd/scripts/bootstrap-local-auth.ts`
- `.agents/skills/vscode-integrated-browser/SKILL.md`
- `.agents/skills/connect-backend-services/SKILL.md`
- `docs/vscode-integrated-browser-auth.md`
