#!/usr/bin/env bash
set -euo pipefail

export GOOGLE_WORKSPACE_PROJECT_ID="${GOOGLE_WORKSPACE_PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-}}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
restart_existing=0
dry_run=0
workspace_mcp_env_vars=(
  GOOGLE_MCP_ACCESS_TOKEN
  GOOGLE_CLOUD_PROJECT
  GOOGLE_WORKSPACE_PROJECT_ID
  DEVELOPERKNOWLEDGE_API_KEY
  GH_TOKEN
  GITHUB_PAT_TOKEN
  CONTEXT7_API_KEY
  PARALLEL_SEARCH_API_TOKEN
  SENTRY_AUTH_TOKEN
  APP_STG_MONGO_URL
  NODE_EXTRA_CA_CERTS
  NODE_OPTIONS
)

usage() {
  cat <<'EOF'
Usage: scripts/dev/open-vscode-with-mcp-env.sh [--restart] [--dry-run]

Launch VS Code with the workspace MCP environment loaded.

Flags:
  --restart  Quit an existing VS Code process first if it is missing the workspace MCP env
  --dry-run  Print what would happen without launching VS Code
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

env_key() {
  case "$1" in
    GOOGLE_MCP_ACCESS_TOKEN) printf 'google_mcp_access_token\n' ;;
    GOOGLE_CLOUD_PROJECT) printf 'google_cloud_project\n' ;;
    DEVELOPERKNOWLEDGE_API_KEY) printf 'developerknowledge_api_key\n' ;;
    GH_TOKEN) printf 'gh_token\n' ;;
    GITHUB_PAT_TOKEN) printf 'github_pat_token\n' ;;
    CONTEXT7_API_KEY) printf 'context7_api_key\n' ;;
    PARALLEL_SEARCH_API_TOKEN) printf 'parallel_search_api_token\n' ;;
    SENTRY_AUTH_TOKEN) printf 'sentry_auth_token\n' ;;
    APP_STG_MONGO_URL) printf 'app_stg_mongo_url\n' ;;
    NODE_EXTRA_CA_CERTS) printf 'node_extra_ca_certs\n' ;;
    NODE_OPTIONS) printf 'node_options\n' ;;
    *) printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' ;;
  esac
}

collect_expected_workspace_mcp_envs() {
  expected_workspace_mcp_envs=()

  for env_var in "${workspace_mcp_env_vars[@]}"; do
    if [[ -n "${!env_var:-}" ]]; then
      expected_workspace_mcp_envs+=("$env_var")
    fi
  done
}

snapshot_has_env_var() {
  local snapshot="$1"
  local env_var="$2"
  grep -q "${env_var}=" <<<"$snapshot"
}

print_workspace_mcp_env_summary() {
  local expected_csv=""

  if [[ "${#expected_workspace_mcp_envs[@]}" -gt 0 ]]; then
    expected_csv="$(IFS=,; printf '%s' "${expected_workspace_mcp_envs[*]}")"
  fi

  printf 'workspace_expected_mcp_envs=%s\n' "${expected_csv:-none}"

  for env_var in "${workspace_mcp_env_vars[@]}"; do
    local key
    local present="no"

    key="$(env_key "$env_var")"
    if [[ -n "${!env_var:-}" ]]; then
      present="yes"
    fi

    printf 'workspace_env_has_%s=%s\n' "$key" "$present"
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restart)
      restart_existing=1
      ;;
    --dry-run)
      dry_run=1
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

if command -v code >/dev/null 2>&1; then
  code_binary="code"
elif command -v code-insiders >/dev/null 2>&1; then
  code_binary="code-insiders"
else
  die "VS Code CLI not found. Install the 'code' shell command first."
fi

if command -v direnv >/dev/null 2>&1 && [[ -f "$repo_root/.envrc" ]]; then
  export DIRENV_LOG_FORMAT=
  eval "$(cd "$repo_root" && direnv export bash)"
fi

if [[ -f "$repo_root/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  . "$repo_root/.env"
  set +a
fi

eval "$($repo_root/scripts/dev/google-mcp-access-token.sh --shell)"
collect_expected_workspace_mcp_envs

process_name=""
if pgrep -o -x code >/dev/null 2>&1; then
  process_name="code"
elif pgrep -o -x code-insiders >/dev/null 2>&1; then
  process_name="code-insiders"
fi

if [[ -n "$process_name" ]]; then
  existing_pid="$(pgrep -o -x "$process_name")"
  existing_snapshot="$(ps eww -p "$existing_pid" -o command= 2>/dev/null || true)"
  missing_existing_workspace_mcp_envs=()

  for env_var in "${expected_workspace_mcp_envs[@]}"; do
    if ! snapshot_has_env_var "$existing_snapshot" "$env_var"; then
      missing_existing_workspace_mcp_envs+=("$env_var")
    fi
  done

  if [[ "${#missing_existing_workspace_mcp_envs[@]}" -gt 0 && "$dry_run" -eq 1 ]]; then
    printf 'existing_process_name=%s\n' "$process_name"
    printf 'existing_process_pid=%s\n' "$existing_pid"
    printf 'existing_process_missing_workspace_mcp_envs=%s\n' "$(IFS=,; printf '%s' "${missing_existing_workspace_mcp_envs[*]}")"
    if [[ "$restart_existing" -eq 1 ]]; then
      printf 'would_restart_existing_process=yes\n'
    else
      printf 'would_restart_existing_process=no\n'
      printf '%s\n' 'hint=use --restart or RESTART=1 mise run dev:vscode:open to replace the stale VS Code process'
    fi
  fi

  if [[ "${#missing_existing_workspace_mcp_envs[@]}" -gt 0 && "$restart_existing" -ne 1 ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      printf 'code_binary=%s\n' "$code_binary"
      printf 'workspace=%s\n' "$repo_root"
      "$repo_root/scripts/dev/google-mcp-access-token.sh" --summary
      print_workspace_mcp_env_summary
      exit 0
    fi

    die "A running VS Code process is missing required workspace MCP env vars: $(IFS=,; printf '%s' "${missing_existing_workspace_mcp_envs[*]}"). Fully quit VS Code first or rerun with --restart."
  fi

  if [[ "${#missing_existing_workspace_mcp_envs[@]}" -gt 0 && "$restart_existing" -eq 1 ]]; then
    if [[ "$dry_run" -eq 1 ]]; then
      printf 'code_binary=%s\n' "$code_binary"
      printf 'workspace=%s\n' "$repo_root"
      "$repo_root/scripts/dev/google-mcp-access-token.sh" --summary
      print_workspace_mcp_env_summary
      exit 0
    fi

    pkill -x "$process_name" || true

    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if ! pgrep -x "$process_name" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    if pgrep -x "$process_name" >/dev/null 2>&1; then
      die "Unable to stop the existing VS Code process cleanly. Close it manually and rerun the script."
    fi
  fi
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf 'code_binary=%s\n' "$code_binary"
  printf 'workspace=%s\n' "$repo_root"
  "$repo_root/scripts/dev/google-mcp-access-token.sh" --summary
  print_workspace_mcp_env_summary
  exit 0
fi

(
  cd "$repo_root"
  nohup "$code_binary" --new-window "$repo_root" >/dev/null 2>&1 &
)

printf '%s\n' "Launched $code_binary for $repo_root with the workspace MCP environment."
