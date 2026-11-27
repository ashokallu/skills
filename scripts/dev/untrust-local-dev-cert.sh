#!/usr/bin/env bash
set -euo pipefail

# Undo scripts/dev/trust-local-dev-cert.sh

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "error: this helper is for Linux." >&2
	exit 1
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
	if command -v sudo >/dev/null 2>&1; then
		SUDO="sudo"
	else
		echo "error: need root privileges (sudo not found)." >&2
		exit 1
	fi
fi

removed_any=false

if [[ -f "/usr/local/share/ca-certificates/project-local-dev.crt" ]]; then
	${SUDO} rm -f "/usr/local/share/ca-certificates/project-local-dev.crt"
	removed_any=true
fi

if [[ -f "/etc/pki/ca-trust/source/anchors/project-local-dev.crt" ]]; then
	${SUDO} rm -f "/etc/pki/ca-trust/source/anchors/project-local-dev.crt"
	removed_any=true
fi

if command -v update-ca-certificates >/dev/null 2>&1; then
	${SUDO} update-ca-certificates
elif command -v update-ca-trust >/dev/null 2>&1; then
	${SUDO} update-ca-trust extract
fi

NSS_NICKNAME="project-local-dev"
if command -v certutil >/dev/null 2>&1; then
	NSS_DB_DIR="${HOME}/.pki/nssdb"
	certutil -d "sql:${NSS_DB_DIR}" -D -n "${NSS_NICKNAME}" >/dev/null 2>&1 || true
fi

if [[ "${removed_any}" == "true" ]]; then
	echo "system trust: removed project-local-dev.crt"
else
	echo "system trust: nothing to remove"
fi

echo "done"
