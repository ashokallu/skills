#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage:
  scripts/dev/stop-chrome-cdp.sh --pidfile <path>

Example:
  scripts/dev/stop-chrome-cdp.sh --pidfile ~/.cache/agent-browser-cdp/google-chrome-Person_2/.cdp.pid
EOF
}

sha256_string() {
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
	echo ""
}

proc_starttime_ticks() {
	local pid="$1"
	awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null || true
}

proc_cmdline_string() {
	local pid="$1"
	tr '\0' ' ' <"/proc/${pid}/cmdline" 2>/dev/null | sed 's/ $//' || true
}

parse_pidfile_kv() {
	local pidfile="$1"
	local line key value

	while IFS= read -r line || [[ -n "${line}" ]]; do
		[[ -z "${line}" ]] && continue
		key="${line%%=*}"
		value="${line#*=}"
		case "${key}" in
			pid) PID="${value}" ;;
			port) PORT="${value}" ;;
			user_data_dir) USER_DATA_DIR="${value}" ;;
			proc_starttime_ticks) PROC_STARTTIME_TICKS_EXPECTED="${value}" ;;
			cmdline_sha256) CMDLINE_SHA256_EXPECTED="${value}" ;;
		esac
	done <"${pidfile}"
}

PIDFILE=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--pidfile)
			PIDFILE="$2"; shift 2 ;;
		-h|--help)
			usage; exit 0 ;;
		*)
			echo "error: unknown arg: $1" >&2
			usage >&2
			exit 2
	esac
done

if [[ -z "${PIDFILE}" ]]; then
	usage >&2
	exit 2
fi

if [[ ! -f "${PIDFILE}" ]]; then
	echo "error: pidfile not found: ${PIDFILE}" >&2
	exit 1
fi

PID=""
PORT=""
USER_DATA_DIR=""
PROC_STARTTIME_TICKS_EXPECTED=""
CMDLINE_SHA256_EXPECTED=""

if grep -q '^pid=' "${PIDFILE}" 2>/dev/null; then
	parse_pidfile_kv "${PIDFILE}"
else
	echo "error: unsupported pidfile format (expected key=value metadata): ${PIDFILE}" >&2
	echo "hint: re-create it using scripts/dev/start-chrome-cdp-from-profile.sh" >&2
	exit 1
fi

if [[ -z "${PID}" || -z "${PROC_STARTTIME_TICKS_EXPECTED}" ]]; then
	echo "error: pidfile missing required fields (pid, proc_starttime_ticks): ${PIDFILE}" >&2
	echo "hint: re-create it using scripts/dev/start-chrome-cdp-from-profile.sh" >&2
	exit 1
fi

if [[ -z "${CMDLINE_SHA256_EXPECTED}" ]]; then
	echo "error: pidfile missing required field (cmdline_sha256): ${PIDFILE}" >&2
	echo "hint: re-create it using scripts/dev/start-chrome-cdp-from-profile.sh" >&2
	exit 1
fi

if [[ ! -d "/proc/${PID}" ]]; then
	echo "note: process not running (stale pidfile); removing: ${PIDFILE}" >&2
	rm -f "${PIDFILE}" || true
	exit 0
fi

PROC_STARTTIME_TICKS_ACTUAL="$(proc_starttime_ticks "${PID}")"
if [[ "${PROC_STARTTIME_TICKS_ACTUAL}" != "${PROC_STARTTIME_TICKS_EXPECTED}" ]]; then
	echo "error: PID reuse detected; refusing to kill pid=${PID}" >&2
	echo "- expected proc starttime ticks: ${PROC_STARTTIME_TICKS_EXPECTED}" >&2
	echo "- actual proc starttime ticks:    ${PROC_STARTTIME_TICKS_ACTUAL}" >&2
	echo "note: pidfile left intact: ${PIDFILE}" >&2
	exit 1
fi

CMDLINE_ACTUAL="$(proc_cmdline_string "${PID}")"
CMDLINE_SHA256_ACTUAL="$(sha256_string "${CMDLINE_ACTUAL}")"
if [[ "${CMDLINE_SHA256_ACTUAL}" != "${CMDLINE_SHA256_EXPECTED}" ]]; then
	echo "error: cmdline mismatch; refusing to kill pid=${PID}" >&2
	echo "note: pidfile left intact: ${PIDFILE}" >&2
	exit 1
fi

kill "${PID}" 2>/dev/null || true

for _ in {1..25}; do
	if [[ ! -d "/proc/${PID}" ]]; then
		rm -f "${PIDFILE}" || true
		echo "stopped chrome pid ${PID}" >&2
		exit 0
	fi
	sleep 0.2
done

echo "warning: process did not exit after SIGTERM; sending SIGKILL (pid=${PID})" >&2
kill -9 "${PID}" 2>/dev/null || true
sleep 0.2

rm -f "${PIDFILE}" || true
echo "stopped chrome pid ${PID}" >&2
