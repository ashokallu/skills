#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project="${APP_STG_MONGO_PROJECT:-}"
instances="${APP_STG_MONGO_INSTANCES:-}"
local_port="${APP_STG_MONGO_LOCAL_PORT:-37017}"
ready_timeout="${APP_STG_MONGO_TUNNEL_READY_TIMEOUT:-30}"
state_dir="${APP_STG_MONGO_TUNNEL_STATE_DIR:-${repo_root}/tmp}"
pid_file="${state_dir}/app-stg-mongo-tunnel-${local_port}.pid"
log_file="${state_dir}/app-stg-mongo-tunnel-${local_port}.log"
mode="start"

usage() {
  cat <<'EOF'
Usage: scripts/dev/app_stg_mongo_tunnel.sh [--foreground|--status|--stop]

Starts a secondary-only staging MongoDB SSH tunnel on 127.0.0.1:37017.

Set APP_STG_MONGO_PROJECT and APP_STG_MONGO_INSTANCES before starting.

Default mode starts the tunnel in the background, waits until the local port is
listening, prints status, and exits. Use --foreground only when you explicitly
want a blocking SSH tunnel process.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --foreground)
      mode="foreground"
      ;;
    --status)
      mode="status"
      ;;
    --stop)
      mode="stop"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

is_listening() {
  nc -z 127.0.0.1 "${local_port}" >/dev/null 2>&1
}

print_listener() {
  ss -ltnp "( sport = :${local_port} )" 2>/dev/null || true
}

listener_pid() {
  ss -ltnp "( sport = :${local_port} )" 2>/dev/null |
    sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p' |
    sed -n '1p'
}

wait_for_listener() {
  local elapsed=0

  while [[ "${elapsed}" -lt "${ready_timeout}" ]]; do
    if is_listening; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  return 1
}

stop_tunnel() {
  if [[ ! -f "${pid_file}" ]]; then
    echo "No staging MongoDB tunnel pid file found at ${pid_file}" >&2
    return 0
  fi

  local pid
  pid="$(cat "${pid_file}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}"
    echo "Stopped staging MongoDB tunnel process ${pid}" >&2
  else
    echo "Stale staging MongoDB tunnel pid file: ${pid_file}" >&2
  fi
  rm -f "${pid_file}"
}

choose_secondary() {
  local instance zone container role_json

  for instance in ${instances}; do
    echo "Checking MongoDB replica role for ${instance}" >&2
    zone="$(
      {
        timeout 15s gcloud compute instances list \
          --project "${project}" \
          --filter="name=${instance}" \
          --format="value(zone)" ||
          true
      } |
        sed -n '1p'
    )"

    if [ -z "${zone}" ]; then
      echo "Skipping ${instance}: instance not found in ${project}" >&2
      continue
    fi

    container="${instance%-us-central1}"
    role_json="$(
      timeout 25s gcloud compute ssh "${instance}" \
        --project "${project}" \
        --zone "${zone}" \
        --internal-ip \
        --ssh-flag="-o ConnectTimeout=5" \
        --command="sudo docker exec ${container} mongo --quiet --eval 'JSON.stringify(db.isMaster())'" 2>/dev/null ||
        true
    )"

    if echo "${role_json}" | grep -q '"secondary"[[:space:]]*:[[:space:]]*true'; then
      printf '%s\t%s\n' "${instance}" "${zone}"
      return 0
    fi

    if echo "${role_json}" | grep -q '"ismaster"[[:space:]]*:[[:space:]]*true'; then
      echo "Skipping ${instance}: current primary" >&2
    else
      echo "Skipping ${instance}: replica role unavailable" >&2
    fi
  done

  return 1
}

if [[ "${mode}" == "status" ]]; then
  if is_listening; then
    echo "Staging MongoDB tunnel is listening on 127.0.0.1:${local_port}" >&2
    print_listener
    exit 0
  fi
  echo "Staging MongoDB tunnel is not listening on 127.0.0.1:${local_port}" >&2
  exit 1
fi

if [[ "${mode}" == "stop" ]]; then
  stop_tunnel
  exit 0
fi

if is_listening; then
  echo "Staging MongoDB tunnel is already listening on 127.0.0.1:${local_port}" >&2
  print_listener
  exit 0
fi

if [[ -z "$project" || -z "$instances" ]]; then
  echo "Set APP_STG_MONGO_PROJECT and APP_STG_MONGO_INSTANCES before starting the tunnel" >&2
  exit 2
fi

selection="$(choose_secondary)"
if [ -z "${selection}" ]; then
  echo "No secondary MongoDB instance found in ${project}" >&2
  exit 1
fi

instance="$(printf '%s' "${selection}" | awk '{print $1}')"
zone="$(printf '%s' "${selection}" | awk '{print $2}')"

echo "Opening staging MongoDB tunnel to secondary ${instance} (${zone}) on 127.0.0.1:${local_port}" >&2

if [[ "${mode}" == "foreground" ]]; then
  exec gcloud compute ssh "${instance}" \
    --project "${project}" \
    --zone "${zone}" \
    --internal-ip \
    -- \
    -N \
    -L "127.0.0.1:${local_port}:localhost:27017" \
    -o ExitOnForwardFailure=yes
fi

mkdir -p "${state_dir}"
: >"${log_file}"
rm -f "${pid_file}"

if ! gcloud compute ssh "${instance}" \
  --project "${project}" \
  --zone "${zone}" \
  --internal-ip \
  -- \
  -f \
  -N \
  -L "127.0.0.1:${local_port}:localhost:27017" \
  -o ExitOnForwardFailure=yes </dev/null >"${log_file}" 2>&1; then
  echo "Failed to start staging MongoDB tunnel" >&2
  echo "log_file=${log_file}" >&2
  tail -n 40 "${log_file}" >&2 || true
  exit 1
fi

if wait_for_listener; then
  listener_pid >"${pid_file}"
  echo "Staging MongoDB tunnel is ready on 127.0.0.1:${local_port}" >&2
  echo "pid_file=${pid_file}" >&2
  echo "log_file=${log_file}" >&2
  exit 0
fi

echo "Timed out waiting for staging MongoDB tunnel on 127.0.0.1:${local_port}" >&2
echo "pid_file=${pid_file}" >&2
echo "log_file=${log_file}" >&2
stop_tunnel >/dev/null 2>&1 || true
tail -n 40 "${log_file}" >&2 || true
exit 1
