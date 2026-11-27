#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-collab-vpn-smoke.sh [options]

Options:
  --url <url>          VPN-only HTTPS URL (or set AGENT_COLLAB_VPN_URL).
  --timeout-sec <num>  Per-request timeout. Default: 8.
  --help              Show this help.

Returns 0 only when the URL is reachable from this execution surface. This is
the preflight for VPN-backed collaborator calls such as the repo Copilot CLI
LiteLLM provider. Use this gate only for providers that require your private network. If this fails inside a
sandboxed agent shell, retry from the non-sandbox shell or browser before
declaring VPN unavailable.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# Set a private probe endpoint that does not require credentials.
url="${AGENT_COLLAB_VPN_URL:-}"
timeout_sec="8"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--url requires a value"
      url="$2"
      shift 2
      ;;
    --timeout-sec)
      [[ $# -ge 2 && -n "${2:-}" ]] || die "--timeout-sec requires a value"
      timeout_sec="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ "$url" == https://* ]] || die "Set AGENT_COLLAB_VPN_URL or pass an HTTPS --url"

command -v curl >/dev/null 2>&1 || die "curl is required"

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]]; then
  die "--timeout-sec must be a positive integer"
fi

if curl --fail --silent --show-error --location --head --max-time "$timeout_sec" "$url" >/dev/null; then
  printf 'vpn-smoke-ok %s\n' "$url"
else
  printf 'vpn-smoke-failed %s\n' "$url" >&2
  exit 1
fi
