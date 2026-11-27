#!/usr/bin/env bash
set -euo pipefail

project="${GOOGLE_CLOUD_PROJECT:-}"
region="${GOOGLE_CLOUD_REGION:-us-central1}"
service_account="${GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT:-}"
requested_lifetime="${GOOGLE_MCP_ACCESS_TOKEN_LIFETIME:-43200s}"
scope="${GOOGLE_MCP_ACCESS_TOKEN_SCOPE:-https://www.googleapis.com/auth/cloud-platform}"
format="token"

usage() {
  cat <<'EOF'
Usage: scripts/dev/google-mcp-access-token.sh [--token-only|--shell|--dotenv|--summary] [--lifetime DURATION]

Outputs a Google Cloud bearer token for the repo's MCP workflow.

Formats:
  --token-only   Print only the bearer token (default)
  --shell        Print bash exports for the Google MCP environment
  --dotenv       Print dotenv-style KEY=VALUE lines
  --summary      Print non-secret token metadata

Examples:
  scripts/dev/google-mcp-access-token.sh --summary
  eval "$(scripts/dev/google-mcp-access-token.sh --shell)"
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

run_with_timeout() {
  local duration="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$duration" "$@"
    return
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$duration" "$@"
    return
  fi

  "$@"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --token-only)
      format="token"
      ;;
    --shell)
      format="shell"
      ;;
    --dotenv)
      format="dotenv"
      ;;
    --summary)
      format="summary"
      ;;
    --lifetime)
      shift
      [[ $# -gt 0 ]] || die "Missing value for --lifetime"
      requested_lifetime="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

[[ -n "$project" ]] || die "Set GOOGLE_CLOUD_PROJECT"
[[ -n "$service_account" ]] || die "Set GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT"
command -v gcloud >/dev/null 2>&1 || die "gcloud is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"

source_kind="gcloud-impersonation"
expires_at=""
token=""

if caller_token="$(run_with_timeout 20s gcloud auth print-access-token --project "$project" 2>/dev/null)"; then
  if extended_json="$(CALLER_TOKEN="$caller_token" SERVICE_ACCOUNT="$service_account" TOKEN_SCOPE="$scope" TOKEN_LIFETIME="$requested_lifetime" \
    run_with_timeout 25s python3 - <<'PY'
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

caller_token = os.environ["CALLER_TOKEN"]
service_account = os.environ["SERVICE_ACCOUNT"]
scope = os.environ["TOKEN_SCOPE"]
lifetime = os.environ["TOKEN_LIFETIME"]

url = (
    "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/"
    f"{urllib.parse.quote(service_account, safe='')}:generateAccessToken"
)
body = json.dumps({"scope": [scope], "lifetime": lifetime}).encode()
request = urllib.request.Request(
    url,
    data=body,
    headers={
        "Authorization": f"Bearer {caller_token}",
        "Content-Type": "application/json",
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.load(response)
except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
    sys.exit(1)

token = payload.get("accessToken")
if not token:
    sys.exit(1)

print(json.dumps({"token": token, "expireTime": payload.get("expireTime", "")}))
PY
  )"; then
    token="$(EXTENDED_JSON="$extended_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["EXTENDED_JSON"])
print(payload["token"])
PY
)"
    expires_at="$(EXTENDED_JSON="$extended_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["EXTENDED_JSON"])
print(payload.get("expireTime", ""))
PY
)"
    source_kind="iamcredentials-generateAccessToken"
  fi
fi

if [[ -z "$token" ]]; then
  token="$(run_with_timeout 20s gcloud auth print-access-token --project "$project" --impersonate-service-account "$service_account")"
fi

case "$format" in
  token)
    printf '%s\n' "$token"
    ;;
  shell)
    printf 'export GOOGLE_CLOUD_PROJECT=%q\n' "$project"
    printf 'export GOOGLE_CLOUD_REGION=%q\n' "$region"
    printf 'export GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT=%q\n' "$service_account"
    printf 'export GOOGLE_MCP_ACCESS_TOKEN=%q\n' "$token"
    printf 'export GOOGLE_MCP_ACCESS_TOKEN_SOURCE=%q\n' "$source_kind"
    printf 'export GOOGLE_MCP_ACCESS_TOKEN_REQUESTED_LIFETIME=%q\n' "$requested_lifetime"
    if [[ -n "$expires_at" ]]; then
      printf 'export GOOGLE_MCP_ACCESS_TOKEN_EXPIRES_AT=%q\n' "$expires_at"
    fi
    ;;
  dotenv)
    printf 'GOOGLE_CLOUD_PROJECT=%s\n' "$project"
    printf 'GOOGLE_CLOUD_REGION=%s\n' "$region"
    printf 'GOOGLE_MCP_IMPERSONATE_SERVICE_ACCOUNT=%s\n' "$service_account"
    printf 'GOOGLE_MCP_ACCESS_TOKEN=%s\n' "$token"
    printf 'GOOGLE_MCP_ACCESS_TOKEN_SOURCE=%s\n' "$source_kind"
    printf 'GOOGLE_MCP_ACCESS_TOKEN_REQUESTED_LIFETIME=%s\n' "$requested_lifetime"
    if [[ -n "$expires_at" ]]; then
      printf 'GOOGLE_MCP_ACCESS_TOKEN_EXPIRES_AT=%s\n' "$expires_at"
    fi
    ;;
  summary)
    printf 'project=%s\n' "$project"
    printf 'region=%s\n' "$region"
    printf 'service_account=%s\n' "$service_account"
    printf 'token_source=%s\n' "$source_kind"
    printf 'requested_lifetime=%s\n' "$requested_lifetime"
    if [[ -n "$expires_at" ]]; then
      printf 'expires_at=%s\n' "$expires_at"
    else
      printf 'expires_at=unknown\n'
    fi
    ;;
esac
