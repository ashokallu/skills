#!/usr/bin/env bash
set -euo pipefail

# Trust the repo's local development TLS cert (local-dev.crt)
# in common Linux trust stores.
#
# This enables CLI tools (curl, git, node, etc.) to access:
#   https://app.local.example.com:4443
#   https://app.local.example.com:4444
# (and the legacy stack on :8443) without needing --cacert.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CERT_SRC="${LOCAL_DEV_CA_CERT:-${REPO_ROOT}/infrastructure/caddy/local-dev.crt}"

if [[ ! -f "${CERT_SRC}" ]]; then
	echo "error: expected cert at: ${CERT_SRC}" >&2
	exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "error: this helper is for Linux. On macOS/Windows, install the cert into the OS trust store instead." >&2
	exit 1
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
	if command -v sudo >/dev/null 2>&1; then
		SUDO="sudo"
	else
		echo "error: need root privileges (sudo not found)." >&2
		echo "hint: if you can't use sudo, use: source scripts/dev/local-ca-env.sh" >&2
		exit 1
	fi
fi

installed_system=false

if command -v update-ca-certificates >/dev/null 2>&1; then
	# Debian/Ubuntu
	DEST_DIR="/usr/local/share/ca-certificates"
	DEST_FILE="${DEST_DIR}/project-local-dev.crt"
	${SUDO} mkdir -p "${DEST_DIR}"
	${SUDO} cp "${CERT_SRC}" "${DEST_FILE}"
	${SUDO} update-ca-certificates
	installed_system=true

elif command -v update-ca-trust >/dev/null 2>&1; then
	# RHEL/Fedora/CentOS
	DEST_DIR="/etc/pki/ca-trust/source/anchors"
	DEST_FILE="${DEST_DIR}/project-local-dev.crt"
	${SUDO} mkdir -p "${DEST_DIR}"
	${SUDO} cp "${CERT_SRC}" "${DEST_FILE}"
	${SUDO} update-ca-trust extract
	installed_system=true
fi

if [[ "${installed_system}" == "true" ]]; then
	echo "system trust: installed project-local-dev.crt"
else
	echo "system trust: could not find update-ca-certificates or update-ca-trust" >&2
	echo "hint: you can still do per-shell trust with: source scripts/dev/local-ca-env.sh" >&2
fi

# Optional: add to the per-user NSS trust DB (helps Chromium/Firefox on some Linux setups).
NSS_NICKNAME="project-local-dev"
if command -v certutil >/dev/null 2>&1; then
	NSS_DB_DIR="${HOME}/.pki/nssdb"
	mkdir -p "${NSS_DB_DIR}"

	# NOTE: local-dev.crt is a self-signed server certificate and does not include
	# Basic Constraints (CA:TRUE). For NSS/Chromium trust, it should be trusted as
	# a peer cert (P,P,P), not as a CA (C,,).
	NSS_TRUST_ARGS="P,P,P"
	if command -v openssl >/dev/null 2>&1; then
		if openssl x509 -in "${CERT_SRC}" -noout -text 2>/dev/null | grep -q "CA:TRUE"; then
			NSS_TRUST_ARGS="C,,"
		fi
	fi

	# Initialize DB if needed (no password)
	if ! certutil -d "sql:${NSS_DB_DIR}" -L >/dev/null 2>&1; then
		certutil -d "sql:${NSS_DB_DIR}" -N --empty-password
	fi

	# Replace existing entry if present
	certutil -d "sql:${NSS_DB_DIR}" -D -n "${NSS_NICKNAME}" >/dev/null 2>&1 || true
	certutil -d "sql:${NSS_DB_DIR}" -A -t "${NSS_TRUST_ARGS}" -n "${NSS_NICKNAME}" -i "${CERT_SRC}"
	echo "nssdb trust: added '${NSS_NICKNAME}' to sql:${NSS_DB_DIR}"

else
	echo "nssdb trust: skipped (certutil not installed)." >&2
	echo "hint (Ubuntu/Debian): sudo apt-get install -y libnss3-tools" >&2
fi

echo "done"

echo "note: if agent-browser (or Chrome/Chromium) was already running, restart it to pick up the new trust." >&2
echo "      agent-browser close" >&2
