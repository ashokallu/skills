---
name: connect-backend-services
description: Use when starting, stopping, restarting, or verifying local connect-backend dev_server services for app-local/connect-local.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-05-08 -->

# connect-backend-services

## Purpose

Use this skill when work depends on the sibling `connect-backend` local dev stack and you need to manage it without guesswork.

This skill covers:

- bringing up the `mp` Docker service
- entering `dev_server` correctly
- checking whether backend and view-server processes are already running
- stopping stale or duplicate processes before restart
- starting backend from `server/` with `make run` or `make watch`
- starting the view server from `view_server/` with `yarn dev`
- reading the right log files
- verifying readiness before auth, browser, or API testing

## When to apply

Apply this skill when you see tasks like:

- "restart connect-backend"
- "start mp"
- "docker exec dev_server bash"
- "make watch"
- "make run"
- "yarn dev" in `view_server`
- "check /var/tmp/mp_server/logs/main.log"
- "check /var/tmp/mp_view_server/logs/main.log"
- "ps aux in dev_server"
- local legacy Learn or Connect issues on `https://app.local.example.com:8443/` or `https://service.local.example.com:8443/`
- local auth flows that depend on connect-backend being alive

## Ground truth

### Container model

The `mp` service comes from:

- `<connect-backend-root>/docker/docker-compose-development.yml`

Important detail:

- the container itself is **not** the app server
- the container starts `/sbin/my_init` and holds the environment open
- backend and view-server processes are started manually inside `dev_server`

That means a healthy `docker compose ... ps` result is **not enough**. After a container restart, the app processes may still be down.

### Backend start contract

Source of truth:

- `<connect-backend-root>/server/Makefile`
- `<connect-backend-root>/README.md`

Relevant targets:

- `make run`
    - builds and starts:
        - `connect web`
        - `rdsworker rdsworker --queue jobs --health-port 10080`
        - `rdsworker rdsworker --queue video_process --health-port 10081`
        - `mp_mediagw mediagw`
        - `caddy run --config ./cmd/mp_caddy/Caddyfile --adapter caddyfile`
- `make watch`
    - installs `fswatch`
    - watches files
    - reruns `make run`

Use:

- `make watch` for active local dev / hot reload
- `make run` for a one-shot foreground start when hot reload is unnecessary

### View-server start contract

Source of truth:

- `<connect-backend-root>/view_server/package.json`
- `<connect-backend-root>/README.md`

Start command:

- `yarn dev`

Current script body:

- `yarn install && gulp dll && gulp`

This can take a while on startup. Do not treat the first few seconds of noise as failure.

## Safe operating rules

- Always check `ps aux` inside `dev_server` **before** starting anything.
- Do not start duplicate backend or view-server copies.
- If the backend or view-server is already running, either:
    - leave it alone, or
    - stop it intentionally before starting a fresh copy.
- Keep backend and view-server in **separate persistent terminals**.
- When testing auth or browser flows, keep both processes running the whole time.
- Prefer targeted restarts over restarting the whole Docker stack.

## Standard workflow

### 1. Ensure the container exists and is running

```bash
docker compose -f <connect-backend-root>/docker/docker-compose-development.yml up -d mp
```

Optional status check:

```bash
docker compose -f <connect-backend-root>/docker/docker-compose-development.yml ps mp
```

### 2. Inspect running processes inside `dev_server`

```bash
docker exec dev_server ps aux
```

Backend-related processes to look for:

- `make watch`
- `fswatch watch -- make run`
- `make run`
- `connect web`
- `rdsworker rdsworker --queue jobs --health-port 10080`
- `rdsworker rdsworker --queue video_process --health-port 10081`
- `mp_mediagw mediagw`
- `caddy run --config ./cmd/mp_caddy/Caddyfile --adapter caddyfile`

View-server-related processes to look for:

- `node /usr/share/yarn/bin/yarn.js dev`
- `gulp`
- `/gopath/src/gitlab.example.com/the organization-connect/connect/view_server/src/server.js`

### 3. Stop stale or duplicate processes if a clean restart is needed

Prefer PID-based kills after inspecting `ps aux`.

Example approach:

```bash
docker exec dev_server bash -lc 'kill <pid> <pid> ... || true; ps aux'
```

Be deliberate. Do not use broad shotgun kills if you have not inspected the process table first.

### 4. Start backend in one shell

Open a persistent shell:

```bash
docker exec -it dev_server bash
```

Then inside the container:

```bash
cd server
make watch
```

Alternative:

```bash
cd server
make run
```

### 5. Start view server in a second shell

Open another persistent shell:

```bash
docker exec -it dev_server bash
```

Then inside the container:

```bash
cd view_server
yarn dev
```

## Logs and readiness checks

### Log files

Backend log:

- `/var/tmp/mp_server/logs/main.log`

View-server log:

- `/var/tmp/mp_view_server/logs/main.log`

Tail both from inside the container:

```bash
docker exec dev_server bash -lc 'tail -n 200 /var/tmp/mp_server/logs/main.log'
docker exec dev_server bash -lc 'tail -n 200 /var/tmp/mp_view_server/logs/main.log'
```

### What healthy startup looks like

Backend:

- `connect web` appears in `ps aux`
- both `rdsworker` processes appear
- `mp_mediagw mediagw` appears
- `caddy run --config ./cmd/mp_caddy/Caddyfile --adapter caddyfile` appears
- backend log shows request handling, not just startup spam

View server:

- `yarn dev` / `gulp` is running
- `view_server/src/server.js` is running
- output eventually includes:
    - `view_server (v1.0) listening at port 18088`
    - `Development server listening.`

### Startup timing expectations

The connect-backend services are slow enough that you should expect to wait roughly 10 to 30 seconds after restart before calling it broken.

Good verification options:

- tail the two log files
- load local pages in a browser
- inspect `ps aux`

### Browser and HTTP verification

Useful browser targets:

- `https://app.local.example.com:8443/`
- `https://service.local.example.com:8443/`

Practical note:

- browser loads are often a better signal than raw `HEAD` probes for this stack
- use the page you actually care about during testing
- confirm success from the logs when possible

## Troubleshooting

### `mp` container is up, but app is still down

Likely cause:

- only the container is running
- backend and/or view-server processes were not started inside `dev_server`

Fix:

- open `docker exec -it dev_server bash`
- start backend from `server/`
- start view server from `view_server/`

### `make watch` exited earlier

Likely cause:

- the watch process died on reload or was terminated

Fix:

- inspect `ps aux`
- ensure no duplicate backend processes remain
- start a fresh backend shell
- rerun `cd server && make watch`

### Caddy or backend looks alive, but UI is still broken

Check:

- `/var/tmp/mp_server/logs/main.log`
- `/var/tmp/mp_view_server/logs/main.log`
- whether `view_server/src/server.js` is running

### Temporary `sockjs-node` / `127.0.0.1:3081` connection refused

A transient webpack dev-server socket error during view-server startup can happen before `yarn dev` finishes booting.

Do not panic immediately.

Re-check after webpack/gulp finishes and the view server reports it is listening.

## Agent execution hints

When using terminal tools:

- use one persistent terminal for backend
- use a second persistent terminal for the view server
- do not run both long-lived commands in the same terminal session
- after startup, use short read-only commands for:
    - `docker exec dev_server ps aux`
    - `tail -n ... /var/tmp/mp_server/logs/main.log`
    - `tail -n ... /var/tmp/mp_view_server/logs/main.log`

## References

- `<connect-backend-root>/docker/docker-compose-development.yml`
- `<connect-backend-root>/server/Makefile`
- `<connect-backend-root>/view_server/package.json`
- `<connect-backend-root>/README.md`
- `local-browser-workflow`
- `browser-e2e`
