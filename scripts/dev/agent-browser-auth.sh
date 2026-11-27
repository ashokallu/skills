#!/usr/bin/env bash
set -euo pipefail

# agent-browser auth persistence helper.
#
# This script standardizes the recommended workflow:
# 1) log in once in a named agent-browser session
# 2) save cookies/localStorage/sessionStorage to a file
# 3) later load the state file and continue without re-login

usage() {
	cat <<'EOF'
Usage:
	scripts/dev/agent-browser-auth.sh login [--url <url>] [--session <name>] [--state <path>] [--headed]
	scripts/dev/agent-browser-auth.sh bootstrap [--legacy-url <url>] [--url <url>] [--session <name>] [--state <path>] [--headed] [--manual-wait-s <seconds>]
	scripts/dev/agent-browser-auth.sh save  [--session <name>] [--state <path>]
	scripts/dev/agent-browser-auth.sh load  [--session <name>] [--state <path>]
	scripts/dev/agent-browser-auth.sh open  [--url <url>] [--session <name>] [--state <path>] [--headed]
	scripts/dev/agent-browser-auth.sh open-local [--legacy-url <url>] [--url <url>] [--session <name>] [--state <path>] [--headed]
	scripts/dev/agent-browser-auth.sh verify [--url <url>] [--session <name>] [--state <path>] [--api-url <url>] [--legacy-api-url <url>] [--headed]
	scripts/dev/agent-browser-auth.sh cookie [--state <path>] [--domain <domain>] [--format <cookie|header|pairs>] [--raw]

Optional:
	--wait-ms <ms>  Navigation wait budget.
	                - Used for origin/href confirmation after navigation.
	                - Note: this script does NOT pass any wait flag to `agent-browser open`.
	                  (The CLI flag name/units have differed across agent-browser versions.)
	--manual-wait-s <seconds>
									During 'bootstrap', wait up to this long for you to complete headed login.
								Default: 90.
	--open-attempts <count>
							Max attempts per URL for 'open' (includes fallback navigation + confirmation).
							Default: 3.
	--legacy-url <url>
									During 'bootstrap', open this URL first for interactive login.
									Default: https://app.local.example.com:8443/
	--api-url <url> During 'verify', fetch this endpoint with cookies.
									Default: https://app.local.example.com:4444/api/users/me
	--legacy-api-url <url>
							During 'verify', attempt an authenticated fetch against a legacy endpoint.
							Default: https://app.local.example.com:8443/api/resumableUpload
  --domain <name> Domain suffix match for cookies (default: app.local.example.com)
  --format <fmt>  Output format for the extracted cookies:
                  - cookie (default): "LS=<...>; SALS=<...>" (ready for a Cookie header)
                  - header: "Cookie: LS=<...>; SALS=<...>"
                  - pairs: one NAME=VALUE per line
  --raw           Print full cookie values (treat as a secret). Default prints redacted values.

Defaults:
	--legacy-url https://app.local.example.com:8443/
  --url     https://app.local.example.com:4443/
	--api-url https://app.local.example.com:4444/api/users/me
	--legacy-api-url https://app.local.example.com:8443/api/resumableUpload
  --session auth
	--state   .agent-browser/auth-state.json (relative to repo root)
	--wait-ms 30000 (minimum 20000)
	--open-attempts 3
	--manual-wait-s 90
  --domain  app.local.example.com
  --format  cookie

Notes:
  - 'login' opens the URL and expects you to complete login manually.
	- 'bootstrap' opens legacy login, waits for manual login, verifies auth on :4443 and :4444, then saves state.
  - 'save' writes cookies/localStorage/sessionStorage to the state file.
  - 'load' loads state into the current session (ensures a browser/page exists first).
  - 'open' loads state and then opens the target URL.
	- 'open-local' loads state and then opens both legacy (:8443) and project (:4443) local UIs.
	- 'verify' loads state (if present) and checks UI + API auth.
  - 'cookie' reads the saved state file and extracts `LS`/`SALS` for curl/Postman.
    Do not paste raw cookie values into chat logs or issue trackers.
	- If you pass --state with a relative path, it is resolved from your current working directory.
EOF
}

CMD="${1:-}"
shift || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

URL="https://app.local.example.com:4443/"
LEGACY_URL="https://app.local.example.com:8443/"
API_URL="https://app.local.example.com:4444/api/users/me"
LEGACY_API_URL="https://app.local.example.com:8443/api/resumableUpload"
SESSION="auth"
STATE_FILE_DEFAULT="${REPO_ROOT}/.agent-browser/auth-state.json"
STATE_FILE="${STATE_FILE_DEFAULT}"
STATE_FILE_EXPLICIT=false
HEADED=false
headed_args=()  # Global; set to (--headed) in bootstrap command
# Learn local dev can be slow on first load (asset compilation).
# Default is intentionally conservative; pass --wait-ms 45000+ on cold starts.
WAIT_MS="30000"
MANUAL_WAIT_S="90"
OPEN_ATTEMPTS="3"
COOKIE_DOMAIN="app.local.example.com"
COOKIE_FORMAT="cookie"
COOKIE_RAW=false

# agent-browser daemon/transport glitches can surface as JSON parse errors.
# Treat these as retryable and give clear recovery guidance.
AB_TRANSPORT_RETRIES="3"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--legacy-url)
			LEGACY_URL="$2"
			shift 2
			;;
		--url)
			URL="$2"
			shift 2
			;;
		--api-url)
			API_URL="$2"
			shift 2
			;;
		--legacy-api-url)
			LEGACY_API_URL="$2"
			shift 2
			;;
		--session)
			SESSION="$2"
			shift 2
			;;
		--state)
			STATE_FILE="$2"
			STATE_FILE_EXPLICIT=true
			shift 2
			;;
		--headed)
			HEADED=true
			shift 1
			;;
		--wait-ms)
			WAIT_MS="$2"
			shift 2
			;;
		--manual-wait-s)
			MANUAL_WAIT_S="$2"
			shift 2
			;;
		--open-attempts)
			OPEN_ATTEMPTS="$2"
			shift 2
			;;
		--domain)
			COOKIE_DOMAIN="$2"
			shift 2
			;;
		--format)
			COOKIE_FORMAT="$2"
			shift 2
			;;
		--raw)
			COOKIE_RAW=true
			shift 1
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "error: unknown arg: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

# Function definitions need to come before usage
resolve_state_file() {
	local path="$1"
	if [[ -z "${path}" ]]; then
		echo "${STATE_FILE_DEFAULT}"
		return 0
	fi
	if [[ "${path}" == /* ]]; then
		echo "${path}"
		return 0
	fi
	if [[ "${STATE_FILE_EXPLICIT}" == "true" ]]; then
		echo "${path}"
		return 0
	fi
	echo "${REPO_ROOT}/${path}"
}

STATE_FILE="$(resolve_state_file "${STATE_FILE}")"

if ! command -v agent-browser >/dev/null 2>&1; then
	echo "error: 'agent-browser' is not installed (command not found)" >&2
	echo "hint: npm install -g agent-browser && agent-browser install" >&2
	echo "see: docs/agent-browser.md" >&2
	exit 127
fi

if ! [[ "${WAIT_MS}" =~ ^[0-9]+$ ]]; then
	echo "error: --wait-ms must be an integer number of milliseconds (got: ${WAIT_MS})" >&2
	exit 2
fi

if ! [[ "${MANUAL_WAIT_S}" =~ ^[0-9]+$ ]]; then
	echo "error: --manual-wait-s must be an integer number of seconds (got: ${MANUAL_WAIT_S})" >&2
	exit 2
fi

if ! [[ "${OPEN_ATTEMPTS}" =~ ^[0-9]+$ ]]; then
	echo "error: --open-attempts must be an integer count (got: ${OPEN_ATTEMPTS})" >&2
	exit 2
fi

if (( OPEN_ATTEMPTS < 1 )); then
	echo "error: --open-attempts must be >= 1 (got: ${OPEN_ATTEMPTS})" >&2
	exit 2
fi

# Local Learn dev pages can take a long time on cold starts (asset compilation).
# We enforce a minimum to avoid flaky automation.
if (( WAIT_MS < 20000 )); then
	echo "note: bumping --wait-ms from ${WAIT_MS} to 20000 (minimum for local dev)" >&2
	WAIT_MS=20000
fi

headed_args=()
if [[ "${HEADED}" == "true" ]]; then
	headed_args+=(--headed)
fi

now_ms() {
	# GNU date supports %3N for millis; if not, fall back to seconds precision.
	date +%s%3N 2>/dev/null || echo "$(( $(date +%s) * 1000 ))"
}

url_origin() {
	# Extract scheme://host:port (origin) from a URL.
	# Example: https://app.local.example.com:4443/path -> https://app.local.example.com:4443
	printf '%s' "$1" | sed -E 's#^(https?://[^/]+).*#\1#'
}

ensure_state_dir() {
	mkdir -p "$(dirname -- "${STATE_FILE}")"
}

is_execution_context_destroyed_error() {
	local msg="$1"
	[[ "${msg}" == *"Execution context was destroyed"* ]] && return 0
	return 1
}

is_page_goto_timeout_error() {
	# agent-browser wraps Playwright errors; on slow local stacks we often hit
	# page.goto timeouts even though the page continues loading.
	local msg="$1"
	[[ "${msg}" == *"page.goto: Timeout"* ]] && return 0
	return 1
}

is_browser_not_launched_error() {
	# Some agent-browser versions can leave a session in a stale state after a prior run,
	# where subsequent commands return:
	#   "Browser not launched. Call launch first."
	# Empirically, running `agent-browser close` for the session resets it.
	local msg="$1"
	[[ "${msg}" == *"Browser not launched"* ]] && return 0
	return 1
}

is_retryable_daemon_transport_error() {
	local msg="$1"
	[[ "${msg}" == *"Invalid response: EOF while parsing a value"* ]] && return 0
	[[ "${msg}" == *"ECONNRESET"* ]] && return 0
	[[ "${msg}" == *"socket hang up"* ]] && return 0
	return 1
}

AB_DID_STALE_SESSION_RECOVERY=false

recover_stale_session_if_needed() {
	# Best-effort and intentionally quiet: users only care that the command succeeds.
	# Global flags must remain BEFORE --session.
	if [[ "${AB_DID_STALE_SESSION_RECOVERY}" != "true" ]]; then
		echo "note: resetting agent-browser session '${SESSION}' (stale browser state)" >&2
		AB_DID_STALE_SESSION_RECOVERY=true
	fi
	agent-browser "${headed_args[@]}" --session "${SESSION}" close >/dev/null 2>&1 || true
}

print_agent_browser_error_summary() {
	# Keep this concise (stderr can be very large). Do not rely on exit codes here.
	local msg="$1"
	# Print up to the first ~8 lines.
	echo "${msg}" | sed -n '1,8p' >&2
}

agent_browser_eval_soft() {
	# Captures combined stdout/stderr into AGENT_BROWSER_LAST_OUT and exit code into AGENT_BROWSER_LAST_RC.
	# Never returns non-zero (so it is safe under `set -e`).
	local js="$1"
	local out rc
	local attempt=1
	set +e
	while true; do
		out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" eval "${js}" 2>&1)"
		rc=$?
		if (( rc != 0 )) && is_browser_not_launched_error "${out}"; then
			recover_stale_session_if_needed
			out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" eval "${js}" 2>&1)"
			rc=$?
		fi
		if (( rc != 0 )) && is_retryable_daemon_transport_error "${out}"; then
			if (( attempt < AB_TRANSPORT_RETRIES )); then
				echo "warning: agent-browser daemon transport error (attempt ${attempt}/${AB_TRANSPORT_RETRIES}); retrying..." >&2
				attempt=$(( attempt + 1 ))
				sleep 0.4
				continue
			fi
			echo "error: agent-browser daemon transport error persisted after ${AB_TRANSPORT_RETRIES} attempt(s)." >&2
			echo "Fix: restart the agent-browser daemon:" >&2
			echo "  bash scripts/dev/restart-agent-browser-daemon.sh" >&2
		fi
		break
	done
	set -e
	AGENT_BROWSER_LAST_OUT="${out}"
	AGENT_BROWSER_LAST_RC=${rc}
	return 0
}

agent_browser_open_soft() {
	# Captures combined stdout/stderr into AGENT_BROWSER_LAST_OUT and exit code into AGENT_BROWSER_LAST_RC.
	# Never returns non-zero (so it is safe under `set -e`).
	local url="$1"
	local out rc

	local attempt=1
	set +e
	while true; do
		out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" open "${url}" 2>&1)"
		rc=$?
		if (( rc != 0 )) && is_browser_not_launched_error "${out}"; then
			recover_stale_session_if_needed
			out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" open "${url}" 2>&1)"
			rc=$?
		fi
		if (( rc != 0 )) && is_retryable_daemon_transport_error "${out}"; then
			if (( attempt < AB_TRANSPORT_RETRIES )); then
				echo "warning: agent-browser daemon transport error (attempt ${attempt}/${AB_TRANSPORT_RETRIES}); retrying..." >&2
				attempt=$(( attempt + 1 ))
				sleep 0.4
				continue
			fi
			echo "error: agent-browser daemon transport error persisted after ${AB_TRANSPORT_RETRIES} attempt(s)." >&2
			echo "Fix: restart the agent-browser daemon:" >&2
			echo "  bash scripts/dev/restart-agent-browser-daemon.sh" >&2
		fi
		break
	done
	set -e
	AGENT_BROWSER_LAST_OUT="${out}"
	AGENT_BROWSER_LAST_RC=${rc}
	return 0
}

agent_browser_wait_soft() {
	# Never returns non-zero (so it is safe under `set -e`).
	local wait_ms="$1"
	local out rc
	local attempt=1
	set +e
	while true; do
		out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" wait "${wait_ms}" 2>&1)"
		rc=$?
		if (( rc != 0 )) && is_retryable_daemon_transport_error "${out}"; then
			if (( attempt < AB_TRANSPORT_RETRIES )); then
				echo "warning: agent-browser daemon transport error (attempt ${attempt}/${AB_TRANSPORT_RETRIES}); retrying..." >&2
				attempt=$(( attempt + 1 ))
				sleep 0.4
				continue
			fi
			echo "error: agent-browser daemon transport error persisted after ${AB_TRANSPORT_RETRIES} attempt(s)." >&2
			echo "Fix: restart the agent-browser daemon:" >&2
			echo "  bash scripts/dev/restart-agent-browser-daemon.sh" >&2
		fi
		break
	done
	set -e
	AGENT_BROWSER_LAST_OUT="${out}"
	AGENT_BROWSER_LAST_RC=${rc}
	return 0
}

has_auth_cookie_in_document_cookie() {
	# Only detects non-HttpOnly cookies. That's fine for our local `auth` cookie.
	agent_browser_eval_soft "document.cookie"
	if (( AGENT_BROWSER_LAST_RC != 0 )); then
		echo "(unknown; could not read document.cookie)" >&2
		return 2
	fi
	# Don't print cookie values; just detect presence by name.
	if echo "${AGENT_BROWSER_LAST_OUT}" | grep -qE '(^|;[[:space:]]*)auth='; then
		echo "true" >&2
		return 0
	fi
	echo "false" >&2
	return 1
}

print_auth_cookie_diagnostics() {
	# Keep output redacted: names/booleans only.
	local has_auth="unknown"
	local rc=0
	set +e
	has_auth="$(has_auth_cookie_in_document_cookie 2>/dev/null)"
	rc=$?
	set -e
	if (( rc == 0 )); then
		echo "Diagnostics: hasAuthCookie=true" >&2
	elif (( rc == 1 )); then
		echo "Diagnostics: hasAuthCookie=false" >&2
	else
		echo "Diagnostics: hasAuthCookie=unknown" >&2
	fi
}

load_state_cookies_manually() {
	# agent-browser `state load` is expected to restore cookies/localStorage/sessionStorage.
	# When cookie restore is unreliable, we apply non-HttpOnly cookies via document.cookie.
	if [[ ! -f "${STATE_FILE}" ]]; then
		echo "error: state file not found: ${STATE_FILE}" >&2
		return 1
	fi
	if ! command -v python3 >/dev/null 2>&1; then
		echo "error: python3 is required to load auth state" >&2
		return 1
	fi

	# Navigate to a local origin first so Secure cookies can be set.
	if ! open_with_fallback "${URL}"; then
		echo "warning: failed to open ${URL}; trying legacy origin ${LEGACY_URL}" >&2
		if ! open_with_fallback "${LEGACY_URL}"; then
			echo "error: could not open local origins to apply cookies" >&2
			return 1
		fi
	fi

	# Clear potentially-conflicting cookies first for determinism.
	# (This avoids mixing a fresh anonymous session with the saved auth cookie.)
	agent-browser "${headed_args[@]}" --session "${SESSION}" cookies clear >/dev/null 2>&1 || true

	# Attempt native state restore first (best chance to restore HttpOnly cookies).
	local state_out state_rc
	set +e
	state_out="$(agent-browser "${headed_args[@]}" --session "${SESSION}" state load "${STATE_FILE}" 2>&1)"
	state_rc=$?
	set -e
	if (( state_rc != 0 )); then
		echo "warning: agent-browser state load failed; continuing with manual cookie replay" >&2
		print_agent_browser_error_summary "${state_out}"
	else
		echo "State load: agent-browser state restore applied (cookies/storage when supported)." >&2
	fi

	local js
	js="$(python3 - "${STATE_FILE}" "${COOKIE_DOMAIN}" <<'PY'
import json
import sys

state_path = sys.argv[1]
domain_suffix = sys.argv[2].lstrip('.')

with open(state_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

cookies = data.get('cookies') or []

def domain_matches(cookie_domain: str, suffix: str) -> bool:
    if not cookie_domain:
        return False
    d = cookie_domain.lstrip('.')
    return d == suffix or d.endswith('.' + suffix)

target = []
matched_count = 0
skipped_http_only = 0
for c in cookies:
    if not isinstance(c, dict):
        continue
    if not domain_matches(c.get('domain') or '', domain_suffix):
        continue
    matched_count += 1
    # JS cannot set HttpOnly cookies.
    if c.get('httpOnly') is True:
        skipped_http_only += 1
        continue
    name = c.get('name')
    value = c.get('value')
    if not name or value is None:
        continue

    parts = [f"{name}={value}"]
    parts.append(f"Path={c.get('path') or '/'}")
    same_site = c.get('sameSite')
    if same_site:
        parts.append(f"SameSite={same_site}")
    if c.get('secure'):
        parts.append('Secure')

    target.append('; '.join(parts))

# Build a compact JS program that sets cookies and returns only non-sensitive diagnostics.
lines = [
    "(() => {",
    "  const cookies = [];",
]
for s in target:
    # JSON-escape safely.
    lines.append(f"  cookies.push({json.dumps(s)});")
lines += [
    "  for (const c of cookies) { document.cookie = c; }",
    "  const names = (document.cookie || '').split(';').map(p => p.split('=')[0].trim()).filter(Boolean);",
    "  return { matchedCount: " + str(matched_count) + ", setCount: cookies.length, skippedHttpOnlyCount: " + str(skipped_http_only) + ", cookieNameCount: names.length, hasAuthCookie: names.includes('auth') };",
    "})()",
]
sys.stdout.write('\n'.join(lines))
PY
)"

	echo "Loading auth cookies from state into browser context (redacted)..." >&2
	agent_browser_eval_soft "${js}"
	if (( AGENT_BROWSER_LAST_RC != 0 )); then
		echo "error: failed to apply cookies from state file" >&2
		echo "note: details are intentionally suppressed to avoid leaking cookie values." >&2
		echo "hint: re-run bootstrap to refresh state: bash scripts/dev/agent-browser-auth.sh bootstrap" >&2
		return 1
	fi
	# Print only booleans/counts.
	echo "State load (manual): ${AGENT_BROWSER_LAST_OUT}" >&2
	if echo "${AGENT_BROWSER_LAST_OUT}" | grep -Eq '"skippedHttpOnlyCount"[[:space:]]*:[[:space:]]*[1-9]'; then
		echo "warning: Your saved auth state includes HttpOnly cookies that cannot be restored via document.cookie." >&2
		echo "warning: If you still see legacy 401s (for example /api/resumableUpload), use a real Chrome profile via CDP instead of state replay." >&2
		echo "hint: scripts/dev/start-chrome-cdp-from-profile.sh --profile-name \"Person 2\" --url \"${URL}\"" >&2
	fi
	return 0
}

assert_headed_mode_if_required() {
	# agent-browser runs a long-lived daemon which inherits environment variables
	# (notably DISPLAY/WAYLAND_DISPLAY) at startup.
	# If the daemon was started without a usable display, `--headed` calls can
	# silently run headless and the user will never see a browser window.
	if [[ "${HEADED}" != "true" ]]; then
		return 0
	fi

	agent_browser_eval_soft "navigator.userAgent"
	if (( AGENT_BROWSER_LAST_RC != 0 )); then
		# Don't fail the main flow on a diagnostic read.
		return 0
	fi

	local ua
	ua="${AGENT_BROWSER_LAST_OUT}"
	if [[ "${ua}" == *"HeadlessChrome"* ]]; then
		echo "error: agent-browser is running headless even though headed mode is required." >&2
		echo "  observed userAgent: ${ua}" >&2
		echo "" >&2
		echo "This usually means the agent-browser daemon was started without a usable display (DISPLAY/WAYLAND_DISPLAY)." >&2
		echo "Fix:" >&2
		echo "  bash scripts/dev/restart-agent-browser-daemon.sh" >&2
		echo "Then re-run your prior command (for example):" >&2
		echo "  bash scripts/dev/agent-browser-auth.sh open-local --headed" >&2
		echo "Or to refresh state:" >&2
		echo "  bash scripts/dev/agent-browser-auth.sh bootstrap" >&2
		return 1
	fi

	return 0
}

confirm_navigation_to_origin() {
	# Best-effort confirmation loop that checks current origin/href until it matches expected origin,
	# or until max_wait_ms elapses.
	#
	# On return:
	# - CONFIRM_LAST_ORIGIN, CONFIRM_LAST_HREF are set (may be empty if eval failed)
	# - returns 0 if confirmed, 1 otherwise
	local expected_origin="$1"
	local max_wait_ms="$2"
	local poll_ms=500
	local start_ms elapsed
	local origin_out href_out

	CONFIRM_LAST_ORIGIN=""
	CONFIRM_LAST_HREF=""

	start_ms="$(now_ms)"
	while true; do
		agent_browser_eval_soft "window.location.origin"
		origin_out="${AGENT_BROWSER_LAST_OUT}"
		if (( AGENT_BROWSER_LAST_RC != 0 )) && is_execution_context_destroyed_error "${origin_out}"; then
			# Navigation is in-flight; treat as non-fatal and keep waiting.
			origin_out=""
		elif (( AGENT_BROWSER_LAST_RC == 0 )); then
			CONFIRM_LAST_ORIGIN="${origin_out}"
			if [[ "${origin_out}" == *"${expected_origin}"* ]]; then
				agent_browser_eval_soft "window.location.href"
				href_out="${AGENT_BROWSER_LAST_OUT}"
				if (( AGENT_BROWSER_LAST_RC == 0 )); then
					CONFIRM_LAST_HREF="${href_out}"
				fi
				return 0
			fi
		fi

		elapsed=$(( $(now_ms) - start_ms ))
		if (( elapsed >= max_wait_ms )); then
			# Capture href for diagnostics if possible.
			agent_browser_eval_soft "window.location.href"
			if (( AGENT_BROWSER_LAST_RC == 0 )); then
				CONFIRM_LAST_HREF="${AGENT_BROWSER_LAST_OUT}"
			fi
			return 1
		fi

		agent_browser_wait_soft "${poll_ms}" >/dev/null
		# Even if wait fails, we'll try again until timeout; failures will be surfaced in caller logs.
	done
}

open_with_fallback() {
	local url="$1"
	local expected_origin
	expected_origin="$(url_origin "${url}")"
	local attempt=1
	local last_error=""
	local last_observed_href=""

	while (( attempt <= OPEN_ATTEMPTS )); do
		# agent-browser open waits for Playwright's default navigation completion.
		# Some SPAs (including Learn) can fail to emit the 'load' event quickly, causing timeouts.
		# NOTE: global flags (--headed) must come BEFORE --session for agent-browser to work correctly.
		agent_browser_open_soft "${url}"
		if (( AGENT_BROWSER_LAST_RC == 0 )); then
			# Confirm we're actually at the intended origin (helps catch redirects / partial navigations).
			if confirm_navigation_to_origin "${expected_origin}" "${WAIT_MS}"; then
				if [[ -n "${CONFIRM_LAST_HREF}" ]]; then
					echo "Opened ${url} (confirmed href: ${CONFIRM_LAST_HREF})" >&2
				else
					echo "Opened ${url} (confirmed origin: ${CONFIRM_LAST_ORIGIN})" >&2
				fi
				return 0
			fi
			last_error="agent-browser open succeeded but did not confirm origin within ${WAIT_MS}ms"
			last_observed_href="${CONFIRM_LAST_HREF}"
		else
			last_error="${AGENT_BROWSER_LAST_OUT}"

			# If this was just a page.goto timeout, treat it as potentially non-fatal.
			# The page often continues loading; give it a chance to settle and confirm origin.
			if is_page_goto_timeout_error "${AGENT_BROWSER_LAST_OUT}"; then
				if confirm_navigation_to_origin "${expected_origin}" "${WAIT_MS}"; then
					echo "Opened ${url} (open timed out, but navigation confirmed via origin/href)" >&2
					return 0
				fi
				last_observed_href="${CONFIRM_LAST_HREF}"
				if [[ -z "${last_error}" ]]; then
					last_error="page.goto timed out and could not confirm origin within ${WAIT_MS}ms"
				fi
				echo "warning: agent-browser open timed out and could not confirm navigation within ${WAIT_MS}ms; attempt ${attempt}/${OPEN_ATTEMPTS}" >&2
			else
				echo "warning: agent-browser open failed (rc=${AGENT_BROWSER_LAST_RC}); attempt ${attempt}/${OPEN_ATTEMPTS}" >&2
				print_agent_browser_error_summary "${AGENT_BROWSER_LAST_OUT}"
				echo "note: falling back to JS navigation" >&2
				local escaped
				escaped="${url//\'/\\\'}"
				agent_browser_eval_soft "window.location.assign('${escaped}')"
				if (( AGENT_BROWSER_LAST_RC != 0 )); then
					# A navigation-triggering eval can legitimately report that its execution context was destroyed.
					# Treat that signature as non-fatal and proceed to confirm navigation.
					if is_execution_context_destroyed_error "${AGENT_BROWSER_LAST_OUT}"; then
						echo "note: JS navigation triggered a navigation (execution context destroyed); continuing" >&2
					else
						last_error="${AGENT_BROWSER_LAST_OUT}"
					fi
				fi

				if confirm_navigation_to_origin "${expected_origin}" "${WAIT_MS}"; then
					echo "Opened ${url} via fallback (confirmed href: ${CONFIRM_LAST_HREF})" >&2
					return 0
				fi
				last_observed_href="${CONFIRM_LAST_HREF}"
				if [[ -z "${last_error}" ]]; then
					last_error="failed to confirm navigation after fallback within ${WAIT_MS}ms"
				fi
			fi
		fi

		attempt=$(( attempt + 1 ))
	done

	echo "error: failed to open URL after ${OPEN_ATTEMPTS} attempt(s)" >&2
	echo "  attempted url:   ${url}" >&2
	if [[ -n "${last_observed_href}" ]]; then
		echo "  last observed:   ${last_observed_href}" >&2
	else
		echo "  last observed:   (unknown; could not read window.location.href)" >&2
	fi
	if [[ -n "${last_error}" ]]; then
		echo "  last error:      ${last_error}" >&2
	else
		echo "  last error:      (unknown)" >&2
	fi
	echo "hint: if :4443 is slow on cold start, re-run with a larger --wait-ms (e.g., 30000-60000) or --open-attempts 5." >&2
	return 1
}

open_legacy_for_manual_login() {
	# Step 1 (bootstrap) should reach the manual login wait even if Playwright's
	# default page.goto timeout is hit. In that specific case, avoid re-navigation
	# (including JS fallback) and proceed; the page often continues loading in the
	# headed window.
	local url="$1"
	local expected_origin
	expected_origin="$(url_origin "${url}")"
	LEGACY_OPEN_TIMED_OUT=false

	agent_browser_open_soft "${url}"
	if (( AGENT_BROWSER_LAST_RC == 0 )); then
		echo "Opened ${url} for manual login" >&2
		return 0
	fi

	if is_page_goto_timeout_error "${AGENT_BROWSER_LAST_OUT}"; then
		LEGACY_OPEN_TIMED_OUT=true
		echo "note: legacy UI open timed out. Proceeding to manual login wait without fallback navigation." >&2
		return 0
	fi

	echo "error: failed to open legacy UI for manual login: ${url}" >&2
	print_agent_browser_error_summary "${AGENT_BROWSER_LAST_OUT}"
	return 1
}

ensure_browser_context() {
	# agent-browser can't reliably `open about:blank` (it may treat it as https://about:blank).
	# Ensure a real HTTPS page has been opened at least once in this session before we try
	# to do things like `eval` or `state load`.
	#
	# If the local stack isn't up, this will fail (which is OK: state load won't be useful
	# without the site anyway).
	open_with_fallback "${URL}"
	# Now it's safe to navigate to about:blank via eval (optional, but keeps subsequent
	# state load operations deterministic).
	agent-browser "${headed_args[@]}" --session "${SESSION}" eval "window.location.href='about:blank'" >/dev/null 2>&1 || true
}

manual_login_wait() {
	local seconds="$1"
	if (( seconds <= 0 )); then
		return 0
	fi

	echo "Waiting up to ${seconds}s for manual login..." >&2
	echo "(Tip: if you finish early, you can just keep going; this script will proceed automatically.)" >&2
	for ((i=seconds; i>0; i--)); do
		printf '\rmanual-login countdown: %2ds remaining ' "${i}" >&2
		sleep 1
	done
	printf '\n' >&2
}

verify_auth() {
	# 0) Legacy UI reachability (best-effort). Some environments may not run legacy stack.
	# If legacy isn't up, continue verifying project UI + API.
	if ! open_with_fallback "${LEGACY_URL}"; then
		echo "warning: could not open legacy UI (${LEGACY_URL}); continuing" >&2
	fi

	# 1) UI navigation check (not a strong auth proof, but helpful diagnostics)
	open_with_fallback "${URL}"

	# 2) API auth check (strong signal)
	# NOTE: Build JS with real newlines. Literal "\n" sequences can cause SyntaxError
	# in agent-browser eval depending on CLI version.
	local api_url_escaped
	api_url_escaped="${API_URL//\'/\\\'}"
	local health_api_url health_api_url_escaped
	health_api_url="$(url_origin "${API_URL}")/api/health-check"
	health_api_url_escaped="${health_api_url//\'/\\\'}"
	local legacy_api_url_escaped
	legacy_api_url_escaped="${LEGACY_API_URL//\'/\\\'}"
	local js
	js="$(cat <<JS
(async () => {
  const urls = [
    '${api_url_escaped}',
    '${health_api_url_escaped}',
  ];
  const out = {};
  for (const u of urls) {
    try {
      const r = await fetch(u, {
        credentials: 'include',
        headers: { 'X-Requested-With': 'XMLHttpRequest' },
      });
      const body = await r.text();
      out[u] = { status: r.status, body: body.slice(0, 400) };
      if (r.status === 200) break;
    } catch (e) {
      out[u] = { error: String(e) };
    }
  }
  return out;
})()
JS
)"

	print_auth_cookie_diagnostics
	echo "Verifying API auth via fetch (cookies included)..." >&2
	agent_browser_eval_soft "${js}"
	if (( AGENT_BROWSER_LAST_RC != 0 )); then
		print_agent_browser_error_summary "${AGENT_BROWSER_LAST_OUT}"
		return 1
	fi
	echo "${AGENT_BROWSER_LAST_OUT}"

	# 3) Legacy API auth check (detects missing legacy cookies/session backing)
	# We intentionally accept *any* non-401/403 response as a sign that cookies are being sent.
	# Many legacy endpoints require additional params; they may return 4xx for validation even when authenticated.
	local legacy
	legacy="$(cat <<JS
(async () => {
  const u = '${legacy_api_url_escaped}';
  try {
    const r = await fetch(u, {
      method: 'POST',
      credentials: 'include',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
    });
    const body = await r.text();
    return { url: u, status: r.status, body: body.slice(0, 200) };
  } catch (e) {
    return { url: u, error: String(e) };
  }
})()
JS
)"

	echo "Verifying legacy auth via fetch (cookies included)..." >&2
	agent_browser_eval_soft "${legacy}"
	if (( AGENT_BROWSER_LAST_RC != 0 )); then
		print_agent_browser_error_summary "${AGENT_BROWSER_LAST_OUT}"
		# Legacy check is additive diagnostics; keep going.
	else
		echo "${AGENT_BROWSER_LAST_OUT}"
		if echo "${AGENT_BROWSER_LAST_OUT}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*(401|403)|status:[[:space:]]*(401|403)'; then
			echo "Legacy auth check: FAIL (${LEGACY_API_URL} returned 401/403)" >&2
			echo "hint: This usually means your auth state is valid for learnapi (:4444) but not for legacy (:8443)." >&2
			echo "hint: Re-auth on the legacy UI and re-bootstrap state, or use CDP to reuse a real Chrome profile." >&2
		fi
	fi

	# Best-effort final signal: attempt to fetch users/me again and require 200 unless it 404s.
	# (Some environments may not expose /api/users/me; in that case, health-check is the best available signal.)
	local final
	final="$(cat <<JS
(async () => {
  const r = await fetch('${api_url_escaped}', {
    credentials: 'include',
    headers: { 'X-Requested-With': 'XMLHttpRequest' },
  });
  return { url: '${api_url_escaped}', status: r.status, body: (await r.text()).slice(0, 200) };
})()
JS
)"

	local out
	agent_browser_eval_soft "${final}"
	out="${AGENT_BROWSER_LAST_OUT}"
	if echo "${out}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*200|status:[[:space:]]*200'; then
		echo "Auth check: PASS (${API_URL} returned 200)" >&2
		return 0
	fi
	if echo "${out}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*(401|403)|status:[[:space:]]*(401|403)'; then
		echo "Auth check: FAIL (${API_URL} returned 401/403)" >&2
		print_auth_cookie_diagnostics
		echo "Diagnostics hints:" >&2
		echo "  - If you logged in on :8443 but :4443/:4444 still look unauthenticated, your legacy stack may not share Redis/session backing." >&2
		echo "  - Verify the local stack is up and TLS is trusted (see docs/local-dev-tls.md)." >&2
		echo "  - Some routes on :4443 redirect to :8443; ensure both are reachable." >&2
		return 1
	fi
	if echo "${out}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*404|status:[[:space:]]*404'; then
		echo "Auth check: PARTIAL (${API_URL} returned 404; falling back to /api/health-check only)" >&2
		echo "If you need a strict auth assertion, confirm the correct endpoint for your env and pass --api-url." >&2
		return 0
	fi

	echo "Auth check: INCONCLUSIVE (unexpected response from ${API_URL})" >&2
	echo "hint: re-run with --api-url pointing at a known authenticated endpoint." >&2
	return 1
}

case "${CMD}" in
	login)
		ensure_state_dir
		echo "Opening ${URL} in agent-browser session '${SESSION}'. Complete login in the browser UI." >&2
		open_with_fallback "${URL}"
		echo "After login, save state:" >&2
		echo "  agent-browser --session \"${SESSION}\" state save \"${STATE_FILE}\"" >&2
		;;

	bootstrap)
		# Force headed by default; manual login without UI is a footgun.
		HEADED=true
		headed_args=(--headed)
		ensure_state_dir
		echo "Step 1/4: Opening legacy UI for manual login: ${LEGACY_URL}" >&2
		open_legacy_for_manual_login "${LEGACY_URL}"
		# Fail fast if the daemon is actually running headless (no visible browser = no manual login).
		assert_headed_mode_if_required
		# Best-effort click; if already signed in or the UI differs, ignore.
		# If legacy open timed out, skip these (they can block) and go straight to manual login.
		if [[ "${LEGACY_OPEN_TIMED_OUT:-false}" != "true" ]]; then
			agent-browser "${headed_args[@]}" --session "${SESSION}" find text "Sign In" click >/dev/null 2>&1 || true
			agent-browser "${headed_args[@]}" --session "${SESSION}" find text "Sign in" click >/dev/null 2>&1 || true
		fi
		manual_login_wait "${MANUAL_WAIT_S}"
		echo "Step 2/4: Verifying authenticated navigation on project UI: ${URL}" >&2
		# Navigate to the project UI. If cookies are hostname-scoped (not port-scoped),
		# auth set on :8443 should carry over to :4443/:4444.
		open_with_fallback "${URL}"
		echo "Step 3/4: Verifying authenticated API access" >&2
		if ! verify_auth; then
			echo "error: auth verification failed; not saving state" >&2
			exit 1
		fi
		echo "Step 4/4: Saving auth state to ${STATE_FILE}" >&2
		agent-browser "${headed_args[@]}" --session "${SESSION}" state save "${STATE_FILE}"
		echo "Saved auth state to ${STATE_FILE}" >&2
		;;

	save)
		ensure_state_dir
		agent-browser --session "${SESSION}" state save "${STATE_FILE}"
		echo "Saved auth state to ${STATE_FILE}" >&2
		;;

	load)
		if [[ ! -f "${STATE_FILE}" ]]; then
			echo "error: state file not found: ${STATE_FILE}" >&2
			exit 1
		fi
		# Ensure a browser/page exists before loading state.
		ensure_browser_context
		assert_headed_mode_if_required
		load_state_cookies_manually
		echo "Loaded auth state from ${STATE_FILE} (state load + manual cookie apply)" >&2
		;;

	open)
		if [[ ! -r "${STATE_FILE}" ]]; then
			echo "error: state file not found: ${STATE_FILE}" >&2
			echo "hint: run: scripts/dev/agent-browser-auth.sh login --headed" >&2
			exit 1
		fi
		ensure_browser_context
		assert_headed_mode_if_required
		load_state_cookies_manually
		# Navigate again after state load so cookies/storage definitely apply to the target page.
		open_with_fallback "${URL}"
		;;

	open-local)
		if [[ ! -r "${STATE_FILE}" ]]; then
			echo "error: state file not found or not readable: ${STATE_FILE}" >&2
			echo "hint: run: scripts/dev/agent-browser-auth.sh bootstrap" >&2
			exit 1
		fi
		ensure_browser_context
		assert_headed_mode_if_required
		load_state_cookies_manually
		# Open both URLs in separate tabs so they are simultaneously available in headed mode.
		echo "Opening local legacy UI (tab 1): ${LEGACY_URL}" >&2
		open_with_fallback "${LEGACY_URL}"
		agent-browser "${headed_args[@]}" --session "${SESSION}" tab new >/dev/null 2>&1 || true
		echo "Opening local project UI (tab 2): ${URL}" >&2
		open_with_fallback "${URL}"
		;;

	verify)
		if [[ ! -f "${STATE_FILE}" ]]; then
			echo "error: state file not found: ${STATE_FILE}" >&2
			echo "hint: run: scripts/dev/agent-browser-auth.sh bootstrap" >&2
			exit 1
		fi
		ensure_browser_context
		assert_headed_mode_if_required
		load_state_cookies_manually
		if ! verify_auth; then
			exit 1
		fi
		;;

	cookie)
		if [[ ! -f "${STATE_FILE}" ]]; then
			echo "error: state file not found: ${STATE_FILE}" >&2
			echo "hint: run: scripts/dev/agent-browser-auth.sh login --headed && scripts/dev/agent-browser-auth.sh save" >&2
			exit 1
		fi
		if ! command -v python3 >/dev/null 2>&1; then
			echo "error: python3 is required for the 'cookie' command" >&2
			exit 1
		fi
		case "${COOKIE_FORMAT}" in
			cookie|header|pairs)
				;;
			*)
				echo "error: --format must be one of: cookie, header, pairs (got: ${COOKIE_FORMAT})" >&2
				exit 2
		esac

		if [[ "${COOKIE_RAW}" == "true" ]]; then
			echo "warning: printing raw cookie values; treat as secrets" >&2
		fi

		python3 - "${STATE_FILE}" "${COOKIE_DOMAIN}" "${COOKIE_FORMAT}" "${COOKIE_RAW}" <<'PY'
import json
import sys

state_path = sys.argv[1]
domain_suffix = sys.argv[2]
fmt = sys.argv[3]
raw = sys.argv[4].lower() == "true"

with open(state_path, "r", encoding="utf-8") as f:
    data = json.load(f)

cookies = data.get("cookies") or []
target_names = ["LS", "SALS"]

def domain_matches(cookie_domain: str, suffix: str) -> bool:
    if not cookie_domain:
        return False
    d = cookie_domain.lstrip(".")
    s = suffix.lstrip(".")
    return d == s or d.endswith("." + s)

def redact(value: str) -> str:
    if raw:
        return value
    if value is None:
        return ""
    value = str(value)
    if len(value) <= 8:
        return "***"
    return value[:4] + "..." + value[-4:]

found = {}
for name in target_names:
    for c in cookies:
        if c.get("name") != name:
            continue
        if not domain_matches(c.get("domain", ""), domain_suffix):
            continue
        found[name] = c.get("value", "")
        break

if not found:
    sys.stderr.write(f"error: no matching cookies found in state for domain suffix: {domain_suffix}\n")
    sys.exit(1)

pairs = [f"{k}={v}" for k, v in found.items()]
if fmt == "pairs":
    out = "\n".join(pairs)
elif fmt == "cookie":
    out = "; ".join([f"{k}={redact(v)}" for k, v in found.items()])
elif fmt == "header":
    out = "Cookie: " + "; ".join([f"{k}={redact(v)}" for k, v in found.items()])
else:
    raise SystemExit(2)

sys.stdout.write(out + "\n")
PY
		;;

	-h|--help|"" )
		usage
		if [[ -z "${CMD}" ]]; then
			exit 2
		fi
		;;

	*)
		echo "error: unknown command: ${CMD}" >&2
		usage >&2
		exit 2
esac
