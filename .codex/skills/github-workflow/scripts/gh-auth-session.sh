#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi
ENVRC_PATH="${REPO_ROOT}/.envrc"

usage() {
  cat <<'EOF'
Usage:
  <skill-dir>/scripts/gh-auth-session.sh shell
  <skill-dir>/scripts/gh-auth-session.sh summary
  <skill-dir>/scripts/gh-auth-session.sh gh <args...>

Commands:
  shell    Print shell exports only when GH_AUTH_SESSION_ALLOW_SHELL=1.
  summary  Print non-secret token source metadata.
  gh       Run gh with GH_TOKEN/GITHUB_TOKEN injected from env or .envrc.

Notes:
  - This script reads only GH_TOKEN, GITHUB_PAT_TOKEN, and COPILOT_GITHUB_TOKEN
    from the active environment or .envrc. It does not source env files.
  - Token lookup order is GH_TOKEN, then GITHUB_PAT_TOKEN, then COPILOT_GITHUB_TOKEN.

Examples:
  <skill-dir>/scripts/gh-auth-session.sh summary
  <skill-dir>/scripts/gh-auth-session.sh gh api user
  eval "$(GH_AUTH_SESSION_ALLOW_SHELL=1 <skill-dir>/scripts/gh-auth-session.sh shell)"
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

extract_env_file_value() {
  local file="$1"
  local key="$2"
  local raw

  [[ -f "${file}" ]] || return 0

  raw="$(
    sed -n -E \
      "s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$/\\1/p;
       s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*'([^']*)'[[:space:]]*(#.*)?$/\\1/p;
       s/^export[[:space:]]+${key}[[:space:]]*=[[:space:]]*([^#[:space:]]*)[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*\"([^\"]*)\"[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*'([^']*)'[[:space:]]*(#.*)?$/\\1/p;
       s/^${key}[[:space:]]*=[[:space:]]*([^#[:space:]]*)[[:space:]]*(#.*)?$/\\1/p" \
      "${file}" \
      | head -n1
  )" || true

  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"

  printf '%s' "${raw}"
}

lookup_token_key() {
  local key="$1"
  local value

  if [[ -n "${!key:-}" ]]; then
    printf '%s' "${!key}"
    return 0
  fi

  extract_env_file_value "${ENVRC_PATH}" "${key}"
}

resolve_token() {
  local token=""
  local source_key=""

  token="$(lookup_token_key GH_TOKEN)"
  source_key="GH_TOKEN"

  if [[ -z "${token}" ]]; then
    token="$(lookup_token_key GITHUB_PAT_TOKEN)"
    source_key="GITHUB_PAT_TOKEN"
  fi

  if [[ -z "${token}" ]]; then
    token="$(lookup_token_key COPILOT_GITHUB_TOKEN)"
    source_key="COPILOT_GITHUB_TOKEN"
  fi

  [[ -n "${token}" ]] || die "No GitHub token found in environment or ${ENVRC_PATH}"

  printf '%s\n%s\n' "${token}" "${source_key}"
}

command="${1:-}"
shift || true

load_resolved_token() {
  local resolved_text
  resolved_text="$(resolve_token)"
  mapfile -t resolved <<<"${resolved_text}"
}

case "${command}" in
  shell)
    [[ "${GH_AUTH_SESSION_ALLOW_SHELL:-}" == "1" ]] ||
      die "shell prints raw token exports; set GH_AUTH_SESSION_ALLOW_SHELL=1 only for an interactive shell, or use summary/gh instead"
    load_resolved_token
    printf 'export GH_TOKEN=%q\n' "${resolved[0]}"
    printf 'export GITHUB_TOKEN=%q\n' "${resolved[0]}"
    printf 'export GH_TOKEN_SOURCE=%q\n' "${resolved[1]}"
    ;;
  summary)
    load_resolved_token
    printf 'envrc=%s\n' "${ENVRC_PATH}"
    printf 'token_source=%s\n' "${resolved[1]}"
    printf 'gh_path=%s\n' "$(command -v gh 2>/dev/null || printf 'missing')"
    ;;
  gh)
    [[ $# -gt 0 ]] || die "Missing gh arguments"
    command -v gh >/dev/null 2>&1 || die "'gh' is required"
    load_resolved_token
    GH_TOKEN="${resolved[0]}" GITHUB_TOKEN="${resolved[0]}" gh "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    die "Unknown command: ${command}"
    ;;
esac
