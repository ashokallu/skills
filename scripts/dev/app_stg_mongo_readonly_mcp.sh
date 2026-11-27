#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dependency_dir="${APP_STG_MONGO_MCP_DEP_DIR:-/tmp/app-stg-mongo-readonly-mcp}"

if [ -z "${APP_STG_MONGO_URL:-}" ] && [ -f "${repo_root}/.envrc" ]; then
  set -a
  # shellcheck disable=SC1091
  . "${repo_root}/.envrc" >/dev/null 2>&1
  set +a
fi

if [ ! -d "${dependency_dir}/node_modules/mongodb" ]; then
  npm install --prefix "${dependency_dir}" mongodb@3.7.4 >/dev/null
fi

export NODE_PATH="${dependency_dir}/node_modules${NODE_PATH:+:${NODE_PATH}}"
cd "${repo_root}"
exec node ./scripts/dev/app_stg_mongo_readonly_mcp.js
