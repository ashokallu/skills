#!/usr/bin/env bash
set -euo pipefail

# Start a Chrome instance with remote debugging enabled (CDP) based on an existing
# Chrome profile (e.g., "Person 2"), by copying that profile into a non-default
# --user-data-dir.
#
# Why copy?
# Chrome prints: "DevTools remote debugging requires a non-default data directory"
# when you try to use the default user data dir. Copying allows CDP without
# touching your primary profile.

usage() {
	cat <<'EOF'
Usage:
  scripts/dev/start-chrome-cdp-from-profile.sh \
    --profile-name "Person 2" \
    --url "https://app.local.example.com:4443/" \
    [--port 9222] \
    [--src-user-data-dir ~/.config/google-chrome] \
    [--dst-user-data-dir ~/.cache/agent-browser-cdp/google-chrome-Person_2]

Outputs:
  - writes a pid file to: <dst-user-data-dir>/.cdp.pid
  - logs to: /tmp/chrome-cdp.log

Then connect with:
  agent-browser --cdp <port> get url

Stop with:
  scripts/dev/stop-chrome-cdp.sh --pidfile <dst-user-data-dir>/.cdp.pid
EOF
}

require_arg() {
	local flag="$1"
	local value="${2:-}"
	if [[ -z "${value}" ]]; then
		echo "error: ${flag} requires a value" >&2
		usage >&2
		exit 2
	fi
}

ensure_python3() {
	if ! command -v python3 >/dev/null 2>&1; then
		echo "error: python3 is required to inspect Chrome profiles and validate the CDP port" >&2
		exit 1
	fi
}

require_source_chrome_closed() {
	local active_count
	active_count="$(pgrep -x chrome 2>/dev/null | wc -l | tr -d '[:space:]')"
	active_count="${active_count:-0}"
	if (( active_count > 0 )); then
		echo "error: ${active_count} Chrome process(es) are active" >&2
		echo "error: copying a live Chrome profile can produce inconsistent auth/profile state and unreliable CDP startup" >&2
		echo "hint: close every Chrome window, verify no Chrome processes remain, then rerun this command" >&2
		exit 1
	fi
}

validate_port() {
	local port="$1"
	if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
		echo "error: --port must be an integer (got: ${port})" >&2
		exit 2
	fi
	if (( port < 1024 || port > 65535 )); then
		echo "error: --port must be between 1024 and 65535 (got: ${port})" >&2
		exit 2
	fi

	if ! python3 - "${port}" <<'PY'
import socket
import sys

port = int(sys.argv[1])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
try:
    s.bind(("127.0.0.1", port))
except OSError as e:
    sys.stderr.write(f"error: CDP port {port} is already in use ({e})\n")
    sys.exit(1)
finally:
    try:
        s.close()
    except Exception:
        pass
PY
	then
		echo "hint: choose a different port with --port 9223" >&2
		exit 1
	fi
}

sha256_string() {
	# Prefer sha256sum; fall back to python3.
	if command -v sha256sum >/dev/null 2>&1; then
		printf "%s" "$1" | sha256sum | awk '{print $1}'
		return 0
	fi
	if command -v python3 >/dev/null 2>&1; then
		python3 - "$1" <<'PY'
import hashlib
import sys

print(hashlib.sha256(sys.argv[1].encode("utf-8")).hexdigest())
PY
		return 0
	fi
	echo ""  # best-effort; caller should handle empty
}

proc_starttime_ticks() {
	local pid="$1"
	awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null || true
}

proc_cmdline_string() {
	local pid="$1"
	tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null | sed 's/ $//' || true
}

wait_for_cdp() {
	local port="$1"
	local tries=40
	local sleep_s=0.25
	local url="http://127.0.0.1:${port}/json/version"

	if ! command -v curl >/dev/null 2>&1; then
		echo "note: curl not found; skipping CDP responsiveness check (${url})" >&2
		return 0
	fi

	for ((i=1; i<=tries; i++)); do
		if curl -fsS --max-time 1 "${url}" >/dev/null 2>&1; then
			return 0
		fi
		sleep "${sleep_s}"
	done

	echo "error: CDP did not become responsive at ${url}" >&2
	return 1
}

PROFILE_NAME="Person 2"
URL="https://app.local.example.com:4443/"
PORT="9222"
SRC_USER_DATA_DIR="${HOME}/.config/google-chrome"
DST_USER_DATA_DIR=""
CDP_LOG_PATH="${AGENT_BROWSER_CDP_LOG_PATH:-/tmp/chrome-cdp.log}"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--profile-name)
			require_arg "$1" "${2:-}"
			PROFILE_NAME="$2"; shift 2 ;;
		--url)
			require_arg "$1" "${2:-}"
			URL="$2"; shift 2 ;;
		--port)
			require_arg "$1" "${2:-}"
			PORT="$2"; shift 2 ;;
		--src-user-data-dir)
			require_arg "$1" "${2:-}"
			SRC_USER_DATA_DIR="$2"; shift 2 ;;
		--dst-user-data-dir)
			require_arg "$1" "${2:-}"
			DST_USER_DATA_DIR="$2"; shift 2 ;;
		-h|--help)
			usage; exit 0 ;;
		*)
			echo "error: unknown arg: $1" >&2
			usage >&2
			exit 2
	esac
done

if [[ -z "${DST_USER_DATA_DIR}" ]]; then
	safe_name="${PROFILE_NAME// /_}"
	DST_USER_DATA_DIR="${HOME}/.cache/agent-browser-cdp/google-chrome-${safe_name}"
fi

ensure_python3
require_source_chrome_closed
validate_port "${PORT}"

LOCAL_STATE_SRC="${SRC_USER_DATA_DIR}/Local State"
if [[ ! -f "${LOCAL_STATE_SRC}" ]]; then
	echo "error: Chrome Local State not found: ${LOCAL_STATE_SRC}" >&2
	echo "hint: set --src-user-data-dir to your browser user data dir" >&2
	exit 1
fi

PROFILE_DIR="$(PROFILE_NAME="${PROFILE_NAME}" LOCAL_STATE_SRC="${LOCAL_STATE_SRC}" python3 - <<'PY'
import json
import os
import sys

profile_name = os.environ.get('PROFILE_NAME', '')
local_state = os.environ.get('LOCAL_STATE_SRC', '')

if not profile_name:
	sys.stderr.write('PROFILE_NAME env var is empty\n')
	sys.exit(2)

if not local_state:
	sys.stderr.write('LOCAL_STATE_SRC env var is empty\n')
	sys.exit(2)

data = json.load(open(local_state, 'r', encoding='utf-8'))
info = data.get('profile', {}).get('info_cache', {})
for dir_name, meta in info.items():
	if meta.get('name') == profile_name:
		print(dir_name)
		sys.exit(0)

sys.stderr.write(f"profile name not found in Local State: {profile_name}\n")
sys.exit(1)
PY
)"

PROFILE_PATH_SRC="${SRC_USER_DATA_DIR}/${PROFILE_DIR}"
if [[ ! -d "${PROFILE_PATH_SRC}" ]]; then
	echo "error: profile directory not found: ${PROFILE_PATH_SRC}" >&2
	exit 1
fi

mkdir -p "${DST_USER_DATA_DIR}"

# Copy Local State (contains the cookie encryption key) and the profile directory.
cp -a "${LOCAL_STATE_SRC}" "${DST_USER_DATA_DIR}/Local State"
rm -rf "${DST_USER_DATA_DIR}/${PROFILE_DIR}" || true
cp -a "${PROFILE_PATH_SRC}" "${DST_USER_DATA_DIR}/${PROFILE_DIR}"

CHROME_BIN=""
for candidate in "${CHROME_BIN:-}" "$(command -v google-chrome 2>/dev/null || true)" "$(command -v chromium 2>/dev/null || true)" "$(command -v chromium-browser 2>/dev/null || true)"; do
	if [[ -n "${candidate}" && -x "${candidate}" ]]; then
		CHROME_BIN="${candidate}"
		break
	fi
done

if [[ -z "${CHROME_BIN}" ]]; then
	echo "error: could not find a Chrome/Chromium executable" >&2
	exit 1
fi

PIDFILE="${DST_USER_DATA_DIR}/.cdp.pid"

if [[ -f "${PIDFILE}" ]]; then
	# Refuse to stomp an existing pidfile unless it's clearly stale.
	if grep -q '^pid=' "${PIDFILE}" 2>/dev/null; then
		existing_pid="$(awk -F= '$1=="pid"{print $2}' "${PIDFILE}" | tail -n 1)"
		if [[ -n "${existing_pid}" && -d "/proc/${existing_pid}" ]]; then
			echo "error: pidfile already exists and process is still running (pid=${existing_pid}): ${PIDFILE}" >&2
			echo "hint: stop it with: scripts/dev/stop-chrome-cdp.sh --pidfile \"${PIDFILE}\"" >&2
			exit 1
		fi
	fi
	echo "note: removing stale pidfile: ${PIDFILE}" >&2
	rm -f "${PIDFILE}" || true
fi

rm -f "${CDP_LOG_PATH}"

nohup "${CHROME_BIN}" \
	--remote-debugging-address=127.0.0.1 \
	--remote-debugging-port="${PORT}" \
	--user-data-dir="${DST_USER_DATA_DIR}" \
	--profile-directory="${PROFILE_DIR}" \
	--disable-gpu \
	--disable-dev-shm-usage \
	--no-sandbox \
	"${URL}" \
	>"${CDP_LOG_PATH}" 2>&1 &

PID="$!"

# Capture metadata for PID-reuse protection.
sleep 0.2
PROC_STARTTIME="$(proc_starttime_ticks "${PID}")"
if [[ -z "${PROC_STARTTIME}" ]]; then
	echo "error: could not read /proc/${PID}/stat to capture start time" >&2
	kill "${PID}" 2>/dev/null || true
	exit 1
fi

CMDLINE="$(proc_cmdline_string "${PID}")"
CMDLINE_SHA256="$(sha256_string "${CMDLINE}")"
if [[ -z "${CMDLINE_SHA256}" ]]; then
	echo "warning: could not compute cmdline sha256; PID reuse protection will be weaker" >&2
fi

cat >"${PIDFILE}" <<EOF
pid=${PID}
port=${PORT}
user_data_dir=${DST_USER_DATA_DIR}
profile_dir=${PROFILE_DIR}
chrome_bin=${CHROME_BIN}
proc_starttime_ticks=${PROC_STARTTIME}
cmdline_sha256=${CMDLINE_SHA256}
created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

sleep 0.5
if command -v ss >/dev/null 2>&1; then
	if ! ss -ltnp 2>/dev/null | grep -q ":${PORT} "; then
		echo "warning: Chrome did not start listening on ${PORT} yet. See /tmp/chrome-cdp.log" >&2
	fi
fi

if ! wait_for_cdp "${PORT}"; then
	echo "hint: see logs: ${CDP_LOG_PATH}" >&2
	kill "${PID}" 2>/dev/null || true
	rm -f "${PIDFILE}" || true
	exit 1
fi

echo "started: ${CHROME_BIN}" >&2
echo "profile name: ${PROFILE_NAME}  (directory: ${PROFILE_DIR})" >&2
echo "user-data-dir: ${DST_USER_DATA_DIR}" >&2
echo "cdp port: ${PORT}" >&2
echo "pidfile: ${PIDFILE}" >&2
echo "next: agent-browser --cdp ${PORT} get url" >&2
echo "note: if 'agent-browser --cdp ${PORT} open <url>' times out on SPAs, use:" >&2
echo "  agent-browser --cdp ${PORT} eval \"window.location.href='${URL}'\"" >&2
echo "  agent-browser --cdp ${PORT} wait 20000   # cold start may need 30000" >&2
