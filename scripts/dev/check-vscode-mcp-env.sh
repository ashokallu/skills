#!/usr/bin/env bash
set -euo pipefail

export GOOGLE_WORKSPACE_PROJECT_ID="${GOOGLE_WORKSPACE_PROJECT_ID:-${GOOGLE_CLOUD_PROJECT:-}}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

print_shell_workspace_mcp_env_summary() {
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

    printf 'shell_env_has_%s=%s\n' "$key" "$present"
  done
}

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

shell_has_token="no"
if [[ -n "${GOOGLE_MCP_ACCESS_TOKEN:-}" ]]; then
  shell_has_token="yes"
fi

shell_has_developerknowledge_key="no"
if [[ -n "${DEVELOPERKNOWLEDGE_API_KEY:-}" ]]; then
  shell_has_developerknowledge_key="yes"
fi

detect_process_name() {
  if pgrep -o -x code >/dev/null 2>&1; then
    printf 'code\n'
    return
  fi

  if pgrep -o -x code-insiders >/dev/null 2>&1; then
    printf 'code-insiders\n'
    return
  fi

  printf '\n'
}

process_name="$(detect_process_name)"
if [[ -z "$process_name" ]]; then
  printf 'shell_has_token=%s\n' "$shell_has_token"
  print_shell_workspace_mcp_env_summary
  printf 'vscode_process_found=no\n'
  printf 'status=not-running\n'
  exit 0
fi

process_pid="$(pgrep -o -x "$process_name")"
process_snapshot="$(ps eww -p "$process_pid" -o command= 2>/dev/null || true)"
vscode_has_token="no"
vscode_has_project="no"
vscode_has_developerknowledge_key="no"
missing_vscode_workspace_mcp_envs=()

if snapshot_has_env_var "$process_snapshot" 'GOOGLE_MCP_ACCESS_TOKEN'; then
  vscode_has_token="yes"
fi

if snapshot_has_env_var "$process_snapshot" 'GOOGLE_CLOUD_PROJECT'; then
  vscode_has_project="yes"
fi

if snapshot_has_env_var "$process_snapshot" 'DEVELOPERKNOWLEDGE_API_KEY'; then
  vscode_has_developerknowledge_key="yes"
fi

for env_var in "${expected_workspace_mcp_envs[@]}"; do
  if ! snapshot_has_env_var "$process_snapshot" "$env_var"; then
    missing_vscode_workspace_mcp_envs+=("$env_var")
  fi
done

status="ready"
if [[ "${#missing_vscode_workspace_mcp_envs[@]}" -gt 0 ]]; then
  status="restart-required"
fi

printf 'shell_has_token=%s\n' "$shell_has_token"
printf 'shell_has_developerknowledge_api_key=%s\n' "$shell_has_developerknowledge_key"
print_shell_workspace_mcp_env_summary
printf 'vscode_process_found=yes\n'
printf 'vscode_process_name=%s\n' "$process_name"
printf 'vscode_process_pid=%s\n' "$process_pid"
printf 'vscode_env_has_token=%s\n' "$vscode_has_token"
printf 'vscode_env_has_project=%s\n' "$vscode_has_project"
printf 'vscode_env_has_developerknowledge_api_key=%s\n' "$vscode_has_developerknowledge_key"
for env_var in "${workspace_mcp_env_vars[@]}"; do
  key="$(env_key "$env_var")"
  present="no"
  if snapshot_has_env_var "$process_snapshot" "$env_var"; then
    present="yes"
  fi
  printf 'vscode_env_has_%s=%s\n' "$key" "$present"
done
if [[ "${#missing_vscode_workspace_mcp_envs[@]}" -gt 0 ]]; then
  printf 'vscode_missing_workspace_mcp_envs=%s\n' "$(IFS=,; printf '%s' "${missing_vscode_workspace_mcp_envs[*]}")"
else
  printf 'vscode_missing_workspace_mcp_envs=none\n'
fi
printf 'status=%s\n' "$status"

if [[ "$status" == "restart-required" ]]; then
  printf '%s\n' 'hint=fully quit VS Code and relaunch with scripts/dev/open-vscode-with-mcp-env.sh or RESTART=1 mise run dev:vscode:open'
fi
