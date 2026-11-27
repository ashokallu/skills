#!/usr/bin/env bash
# shellcheck shell=bash

# Source this file to make common CLI tools trust the repo's local HTTPS cert
# WITHOUT installing it into the OS trust store.
#
# Example:
#   source scripts/dev/local-ca-env.sh
#   curl https://app.local.example.com:4443/
#
# Note: this helps CLI tools (curl/git/python/node), but browsers (Playwright Chromium,
# Firefox, etc.) generally rely on OS/NSS trust stores. For browser automation,
# prefer scripts/dev/trust-local-dev-cert.sh.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "error: scripts/dev/local-ca-env.sh must be sourced (not executed)" >&2
	echo "usage: source scripts/dev/local-ca-env.sh" >&2
	exit 2
fi

__lp_local_ca_env_prev_set_opts="$(set +o)"
__lp_local_ca_env_prev_shopt_opts="$(shopt -p)"
__lp_local_ca_env_prev_return_trap="$(trap -p RETURN || true)"

__lp_local_ca_env_restore() {
	local status=$?

	# Clear our RETURN trap first to avoid recursion.
	trap - RETURN

	# Restore caller shell options and shopt settings.
	eval "${__lp_local_ca_env_prev_set_opts}"
	eval "${__lp_local_ca_env_prev_shopt_opts}"

	# Restore previous RETURN trap (if any).
	if [[ -n "${__lp_local_ca_env_prev_return_trap}" ]]; then
		eval "${__lp_local_ca_env_prev_return_trap}"
	fi

	unset __lp_local_ca_env_prev_set_opts __lp_local_ca_env_prev_shopt_opts __lp_local_ca_env_prev_return_trap
	unset -f __lp_local_ca_env_restore
	return "${status}"
}

trap __lp_local_ca_env_restore RETURN

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CERT_SRC="${LOCAL_DEV_CA_CERT:-${REPO_ROOT}/infrastructure/caddy/local-dev.crt}"

if [[ ! -f "${CERT_SRC}" ]]; then
	echo "error: expected cert at: ${CERT_SRC}" >&2
	return 1
fi

mkdir -p "${HOME}/.cache/project"
CA_BUNDLE="${HOME}/.cache/project/ca-bundle-with-local-dev.pem"

# Find the system CA bundle and append the local cert.
SYSTEM_BUNDLE=""
for candidate in \
	"/etc/ssl/certs/ca-certificates.crt" \
	"/etc/pki/tls/certs/ca-bundle.crt" \
	"/etc/ssl/cert.pem"; do
	if [[ -f "${candidate}" ]]; then
		SYSTEM_BUNDLE="${candidate}"
		break
	fi
done

if [[ -n "${SYSTEM_BUNDLE}" ]]; then
	cat "${SYSTEM_BUNDLE}" "${CERT_SRC}" >"${CA_BUNDLE}"
else
	# Worst-case fallback: we can still help Node by adding the cert,
	# but we should NOT override global CA bundle env vars because that would
	# likely break unrelated HTTPS traffic.
	echo "warning: could not locate a system CA bundle; will only set NODE_EXTRA_CA_CERTS." >&2
fi

if [[ -n "${SYSTEM_BUNDLE}" ]]; then
	# curl/libcurl
	export CURL_CA_BUNDLE="${CA_BUNDLE}"

	# git over HTTPS
	export GIT_SSL_CAINFO="${CA_BUNDLE}"

	# Python requests
	export REQUESTS_CA_BUNDLE="${CA_BUNDLE}"

	# Generic OpenSSL consumers
	export SSL_CERT_FILE="${CA_BUNDLE}"
fi

# Node.js: add (don't replace) CA roots
export NODE_EXTRA_CA_CERTS="${CERT_SRC}"

echo "local CA env enabled"
if [[ -n "${SYSTEM_BUNDLE}" ]]; then
	echo "- CA bundle: ${CA_BUNDLE}"
fi
echo "- NODE_EXTRA_CA_CERTS: ${NODE_EXTRA_CA_CERTS}"
