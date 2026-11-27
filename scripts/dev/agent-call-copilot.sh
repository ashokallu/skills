#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-call-copilot.sh [options] --prompt <text>
  scripts/dev/agent-call-copilot.sh [options] --prompt-file <path>
  echo "<prompt>" | scripts/dev/agent-call-copilot.sh [options]

Options:
  --prompt <text>          Prompt to send to Copilot CLI.
  --prompt-file <path>     Read the prompt from a file.
  --context-file <path>    Append a local file's contents to the prompt. Repeatable.
  --allow-sensitive-context
                           Allow context-file paths that look secret-bearing.
  --title <title>          Used for the saved output filename.
  --output <path>          Write Copilot's final text to this path.
  --role <role>            reviewer, critic, or none. Default: reviewer.
  --model <name>           Optional Copilot model argument.
  --effort <level>         Optional Copilot reasoning effort.
  --agent <name>           Optional Copilot custom agent.
  --timeout-sec <num>      Wall-clock timeout for the subprocess. Default: 900.
  --require-vpn            Preflight and monitor VPN reachability while Copilot runs.
  --vpn-url <url>          VPN-only URL to probe. Configure the endpoint before using --require-vpn.
  --vpn-timeout-sec <num>  Per-probe timeout. Default: 5.
  --vpn-check-interval-sec <num>
                           Seconds between in-flight VPN checks. Default: 15.
  --vpn-fail-threshold <n> Consecutive VPN failures before killing Copilot. Default: 2.
  --resume <id|alias:name|latest|last>
                           Resume a specific Copilot session.
  --session-alias <name>   Save/resume a named Copilot session for related calls.
  --lane <name>            Derive a Codex-thread-scoped alias for parallel lanes.
  --allow-unsafe-latest    Permit --resume latest/last. Prefer aliases or raw ids.
  --autopilot              Enable Copilot autopilot continuation mode.
  --max-autopilot-continues <num>
                           Bound autopilot continuation messages.
  --plan                   Start Copilot in plan mode.
  --no-ask-user            Disable Copilot ask_user tool.
  --allow-all              Grant all Copilot permissions.
  --yolo                   Alias for --allow-all.
  --allow-shell            Permit Copilot shell tool calls. Default denies shell.
  --allow-write            Permit Copilot write tools. Default denies write.
  --allow-urls             Permit all URL access.
  --allow-all-paths        Disable Copilot path verification.
  --add-dir <path>         Add a directory to Copilot's allowed path list. Repeatable.
  --disallow-temp-dir      Prevent automatic access to the system temp dir.
  --allow-tool <pattern>   Pass a Copilot allow-tool pattern. Repeatable.
  --deny-tool <pattern>    Pass an extra Copilot deny-tool pattern. Repeatable.
  --available-tools <list> Restrict tools visible to the model.
  --excluded-tools <list>  Hide tools from the model.
  --allow-url <pattern>    Allow a specific URL/domain. Repeatable.
  --deny-url <pattern>     Deny a specific URL/domain. Repeatable.
  --disable-builtin-mcps   Disable Copilot built-in MCP servers.
  --disable-mcp-server <name>
                           Disable a specific Copilot MCP server. Repeatable.
  --additional-mcp-config <json-or-@path>
                           Add session-scoped MCP config. Repeatable.
  --plugin-dir <path>      Load a local Copilot plugin directory. Repeatable.
  --no-custom-instructions Disable AGENTS.md/custom instruction loading.
  --no-remote              Disable GitHub remote control for this session.
  --copilot-bin <path>     Copilot CLI binary. Default: copilot.
  --max-prompt-tokens <n>  Override BYOK prompt token cap for this call.
                           Default: 1000000.
  --max-output-tokens <n>  Override BYOK output token cap for this call.
                           Default: 64000.
  --help                   Show this help.

This bridge is for paid Copilot CLI peer review in project. It uses
Copilot non-interactive mode, keeps the current Codex parent as orchestrator,
captures responses under tmp/codex-claude/calls/, and records reusable session
aliases under tmp/codex-claude/state/.

By default the wrapper grants non-interactive tool approval but denies write and
shell tools so review calls stay read-only. Pass --allow-shell, --allow-write,
or --allow-all only when the parent intentionally delegates that capability.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

vpn_check() {
  local url=$1
  local timeout_sec=$2
  curl --fail --silent --show-error --location --head --max-time "$timeout_sec" "$url" >/dev/null 2>&1
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

sanitize_slug() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//' |
    cut -c1-80
}

is_sensitive_context_path() {
  local path=$1
  local lower
  lower=$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')

  case "$lower" in
    *.pem|*.key|*.p12|*.pfx|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) return 0 ;;
    */.env|*/.env.*|.env|.env.*|*/.envrc|.envrc) return 0 ;;
    *auth-state.json*|*credentials*|*credential*|*secrets*|*secret*|*token*|*cookie*) return 0 ;;
  esac

  return 1
}

prompt=""
prompt_file=""
context_files=()
allow_sensitive_context=0
title="copilot-review"
output=""
role="reviewer"
model="${AGENT_CALL_COPILOT_MODEL:-}"
effort="${AGENT_CALL_COPILOT_EFFORT:-}"
agent="${AGENT_CALL_COPILOT_AGENT:-}"
timeout_sec="${AGENT_CALL_COPILOT_TIMEOUT_SEC:-900}"
require_vpn="${AGENT_CALL_COPILOT_REQUIRE_VPN:-0}"
vpn_url="${AGENT_CALL_COPILOT_VPN_URL:-${AGENT_COLLAB_VPN_URL:-}}"
vpn_timeout_sec="${AGENT_CALL_COPILOT_VPN_TIMEOUT_SEC:-5}"
vpn_check_interval_sec="${AGENT_CALL_COPILOT_VPN_CHECK_INTERVAL_SEC:-15}"
vpn_fail_threshold="${AGENT_CALL_COPILOT_VPN_FAIL_THRESHOLD:-2}"
resume_session="${AGENT_CALL_COPILOT_RESUME:-}"
session_alias=""
lane=""
allow_unsafe_latest=0
autopilot=0
max_autopilot_continues=""
plan_mode=0
no_ask_user=0
allow_all=0
allow_shell=0
allow_write=0
allow_urls=0
allow_all_paths=0
disallow_temp_dir=0
disable_builtin_mcps=0
no_custom_instructions=0
no_remote=0
add_dirs=()
allow_tools=()
deny_tools=()
allow_urls_specific=()
deny_urls_specific=()
disable_mcp_servers=()
additional_mcp_configs=()
plugin_dirs=()
available_tools=""
excluded_tools=""
copilot_bin="${AGENT_CALL_COPILOT_BIN:-copilot}"
max_prompt_tokens="${AGENT_CALL_COPILOT_MAX_PROMPT_TOKENS:-1000000}"
max_output_tokens="${AGENT_CALL_COPILOT_MAX_OUTPUT_TOKENS:-64000}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt=${2:-}; shift 2 ;;
    --prompt-file) prompt_file=${2:-}; shift 2 ;;
    --context-file) context_files+=("${2:-}"); shift 2 ;;
    --allow-sensitive-context) allow_sensitive_context=1; shift ;;
    --title) title=${2:-}; shift 2 ;;
    --output) output=${2:-}; shift 2 ;;
    --role) role=${2:-}; shift 2 ;;
    --model) model=${2:-}; shift 2 ;;
    --effort|--reasoning-effort) effort=${2:-}; shift 2 ;;
    --agent) agent=${2:-}; shift 2 ;;
    --timeout-sec) timeout_sec=${2:-}; shift 2 ;;
    --require-vpn) require_vpn=1; shift ;;
    --vpn-url) vpn_url=${2:-}; shift 2 ;;
    --vpn-timeout-sec) vpn_timeout_sec=${2:-}; shift 2 ;;
    --vpn-check-interval-sec) vpn_check_interval_sec=${2:-}; shift 2 ;;
    --vpn-fail-threshold) vpn_fail_threshold=${2:-}; shift 2 ;;
    --resume) resume_session=${2:-}; shift 2 ;;
    --session-alias) session_alias=${2:-}; shift 2 ;;
    --lane) lane=${2:-}; shift 2 ;;
    --allow-unsafe-latest) allow_unsafe_latest=1; shift ;;
    --autopilot) autopilot=1; shift ;;
    --max-autopilot-continues) max_autopilot_continues=${2:-}; shift 2 ;;
    --plan) plan_mode=1; shift ;;
    --no-ask-user) no_ask_user=1; shift ;;
    --allow-all|--yolo) allow_all=1; shift ;;
    --allow-shell) allow_shell=1; shift ;;
    --allow-write) allow_write=1; shift ;;
    --allow-urls) allow_urls=1; shift ;;
    --allow-all-paths) allow_all_paths=1; shift ;;
    --add-dir) add_dirs+=("${2:-}"); shift 2 ;;
    --disallow-temp-dir) disallow_temp_dir=1; shift ;;
    --allow-tool) allow_tools+=("${2:-}"); shift 2 ;;
    --deny-tool) deny_tools+=("${2:-}"); shift 2 ;;
    --available-tools) available_tools=${2:-}; shift 2 ;;
    --excluded-tools) excluded_tools=${2:-}; shift 2 ;;
    --allow-url) allow_urls_specific+=("${2:-}"); shift 2 ;;
    --deny-url) deny_urls_specific+=("${2:-}"); shift 2 ;;
    --disable-builtin-mcps) disable_builtin_mcps=1; shift ;;
    --disable-mcp-server) disable_mcp_servers+=("${2:-}"); shift 2 ;;
    --additional-mcp-config) additional_mcp_configs+=("${2:-}"); shift 2 ;;
    --plugin-dir) plugin_dirs+=("${2:-}"); shift 2 ;;
    --max-prompt-tokens) max_prompt_tokens=${2:-}; shift 2 ;;
    --max-output-tokens) max_output_tokens=${2:-}; shift 2 ;;
    --no-custom-instructions) no_custom_instructions=1; shift ;;
    --no-remote) no_remote=1; shift ;;
    --copilot-bin) copilot_bin=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$role" in
  reviewer|critic|none) ;;
  *) die "--role must be reviewer, critic, or none" ;;
esac

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]]; then
  die "--timeout-sec must be a positive integer"
fi
if [[ -n "$max_autopilot_continues" ]] && { ! [[ "$max_autopilot_continues" =~ ^[0-9]+$ ]] || [[ "$max_autopilot_continues" -lt 1 ]]; }; then
  die "--max-autopilot-continues must be a positive integer"
fi
if [[ "$autopilot" -eq 1 && -z "$max_autopilot_continues" ]]; then
  max_autopilot_continues=5
fi
if ! [[ "$max_prompt_tokens" =~ ^[0-9]+$ ]] || [[ "$max_prompt_tokens" -lt 1 ]]; then
  die "--max-prompt-tokens must be a positive integer"
fi
if ! [[ "$max_output_tokens" =~ ^[0-9]+$ ]] || [[ "$max_output_tokens" -lt 1 ]]; then
  die "--max-output-tokens must be a positive integer"
fi
if [[ "$autopilot" -eq 1 && "$plan_mode" -eq 1 ]]; then
  die "use --autopilot OR --plan, not both"
fi
case "$effort" in
  ""|none|low|medium|high|xhigh|max) ;;
  *) die "--effort must be one of none, low, medium, high, xhigh, or max" ;;
esac
case "$require_vpn" in
  0|1) ;;
  *) die "--require-vpn must be 0 or 1 when set through AGENT_CALL_COPILOT_REQUIRE_VPN" ;;
esac
for numeric_option in \
  "vpn-timeout-sec:$vpn_timeout_sec" \
  "vpn-check-interval-sec:$vpn_check_interval_sec" \
  "vpn-fail-threshold:$vpn_fail_threshold"; do
  name=${numeric_option%%:*}
  value=${numeric_option#*:}
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
    die "--$name must be a positive integer"
  fi
done

if [[ "$require_vpn" == "1" ]]; then
  [[ "$vpn_url" == https://* ]] || die "--require-vpn requires an HTTPS --vpn-url or AGENT_CALL_COPILOT_VPN_URL"
  command -v curl >/dev/null 2>&1 || die "curl is required for --require-vpn"
  command -v setsid >/dev/null 2>&1 || die "setsid is required for --require-vpn process-group cleanup"
fi

if [[ -n "$lane" && -n "$session_alias" ]]; then
  die "use --lane OR --session-alias, not both"
fi
if [[ -n "$lane" && -n "$resume_session" ]]; then
  die "use --lane OR explicit Copilot resumption flags, not both"
fi
if [[ -n "$lane" ]]; then
  if [[ -z "${CODEX_THREAD_ID:-}" ]]; then
    die "--lane requires CODEX_THREAD_ID to be set in the environment"
  fi
  lane=$(sanitize_slug "$lane")
  [[ -n "$lane" ]] || die "--lane must contain at least one safe filename character"
fi

root=$(repo_root)
calls_dir="$root/tmp/codex-claude/calls"
state_dir="$root/tmp/codex-claude/state"
mkdir -p "$calls_dir" "$state_dir"

latest_session_file="$state_dir/copilot-latest-session-id"
latest_session_meta="$state_dir/copilot-latest-session.json"

if [[ -z "$session_alias" && -z "$resume_session" && -n "${CODEX_THREAD_ID:-}" ]]; then
  if [[ -n "$lane" ]]; then
    session_alias=$(sanitize_slug "codex-thread-$CODEX_THREAD_ID-$lane")
  else
    session_alias=$(sanitize_slug "codex-thread-$CODEX_THREAD_ID")
  fi
fi

if [[ -n "$session_alias" ]]; then
  session_alias=$(sanitize_slug "$session_alias")
  [[ -n "$session_alias" ]] || die "--session-alias must contain at least one safe filename character"
fi

if [[ -n "$session_alias" && -z "$resume_session" && -f "$state_dir/copilot-session-$session_alias" ]]; then
  resume_session="alias:$session_alias"
fi

if [[ -n "$resume_session" ]]; then
  case "$resume_session" in
    latest|last)
      if [[ "$allow_unsafe_latest" -ne 1 ]]; then
        die "--resume $resume_session is unsafe when multiple Copilot sessions may run; use --resume alias:<name> or a raw session id/name, or pass --allow-unsafe-latest for a manual/debug call"
      fi
      [[ -f "$latest_session_file" ]] || die "No Copilot latest session recorded at $latest_session_file"
      resume_session=$(sed 's/[[:space:]]*$//' "$latest_session_file")
      ;;
    alias:*)
      alias_name=$(sanitize_slug "${resume_session#alias:}")
      [[ -n "$alias_name" ]] || die "--resume alias:<name> must contain at least one safe filename character"
      alias_file="$state_dir/copilot-session-$alias_name"
      [[ -f "$alias_file" ]] || die "No Copilot session alias found: $alias_name"
      resume_session=$(sed 's/[[:space:]]*$//' "$alias_file")
      ;;
  esac
  [[ -n "$resume_session" ]] || die "Resolved Copilot session is empty"
fi

if [[ -n "$prompt_file" ]]; then
  [[ -f "$prompt_file" ]] || die "--prompt-file does not exist: $prompt_file"
  prompt=$(sed 's/[[:space:]]*$//' "$prompt_file")
elif [[ -z "$prompt" && ! -t 0 ]]; then
  prompt=$(sed 's/[[:space:]]*$//')
fi

[[ -n "$prompt" ]] || die "provide --prompt, --prompt-file, or stdin"
command -v "$copilot_bin" >/dev/null 2>&1 || die "Copilot CLI not found on PATH: $copilot_bin"
for context_file in "${context_files[@]}"; do
  [[ -f "$context_file" ]] || die "--context-file does not exist: $context_file"
  if [[ "$allow_sensitive_context" -eq 0 ]] && is_sensitive_context_path "$context_file"; then
    die "--context-file looks secret-bearing: $context_file; pass --allow-sensitive-context only if this is intentional"
  fi
done
for add_dir in "${add_dirs[@]}"; do
  [[ -d "$add_dir" ]] || die "--add-dir is not a directory: $add_dir"
done
for plugin_dir in "${plugin_dirs[@]}"; do
  [[ -d "$plugin_dir" ]] || die "--plugin-dir is not a directory: $plugin_dir"
done

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="copilot-review"

if [[ -z "$output" ]]; then
  output="$calls_dir/$timestamp-copilot-$slug.md"
fi
share_output="$calls_dir/$timestamp-copilot-$slug-session.md"

if [[ "${#context_files[@]}" -gt 0 ]]; then
  context_block=$'\n\n## Explicit Local Context Files\n'
  for context_file in "${context_files[@]}"; do
    context_block+=$'\n### File: '"$context_file"$'\n```text\n'
    context_block+="$(sed 's/[[:space:]]*$//' "$context_file")"
    context_block+=$'\n```\n'
  done
  prompt+="$context_block"
fi

case "$role" in
  reviewer)
    role_instruction="Act directly as a project reviewer. Stay read-only. Return findings first with concrete file/line evidence where applicable. If there are no findings, say PASS and mention any validation gap."
    ;;
  critic)
    role_instruction="Act directly as a project critic. Stay read-only. Challenge the plan for value, scope, correctness, risk, verification, and rollout readiness. Return APPROVED FOR IMPLEMENTATION only when no blocking issue remains."
    ;;
  none)
    role_instruction="Answer directly as Copilot CLI. Stay read-only unless the prompt explicitly asks for implementation."
    ;;
esac

collab_prompt=$(cat <<EOF
You are GitHub Copilot CLI collaborating with Codex in the project repository.
AGENTS.md and repo.md are the shared contract. Treat this as a paid peer
consultation unless the prompt explicitly asks otherwise. Keep secrets, cookies,
auth state, tokens, private keys, .env files, and browser auth files out of
responses. Do not claim you changed files unless you actually did.

$role_instruction

Peer request:
$prompt
EOF
)

args=(
  -C "$root"
  --prompt "$collab_prompt"
  --silent
  --stream off
  --no-color
  --no-auto-update
  --secret-env-vars=COPILOT_PROVIDER_API_KEY,COPILOT_PROVIDER_BEARER_TOKEN,ANTHROPIC_AUTH_TOKEN,GH_TOKEN,GITHUB_TOKEN,COPILOT_GITHUB_TOKEN
  --share "$share_output"
)
copilot_env=(
  "COPILOT_PROVIDER_MAX_PROMPT_TOKENS=$max_prompt_tokens"
  "COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=$max_output_tokens"
)

if [[ "$allow_all" -eq 1 ]]; then
  args+=(--allow-all)
else
  args+=(--allow-all-tools)
fi

if [[ -n "$model" ]]; then
  args+=(--model "$model")
fi
if [[ -n "$effort" ]]; then
  args+=(--effort "$effort")
fi
if [[ -n "$agent" ]]; then
  args+=(--agent "$agent")
fi

if [[ -n "$resume_session" ]]; then
  args+=(--resume="$resume_session")
elif [[ -n "$session_alias" ]]; then
  args+=(--name "$session_alias")
fi

if [[ "$autopilot" -eq 1 ]]; then
  args+=(--autopilot --max-autopilot-continues "$max_autopilot_continues")
fi
if [[ "$plan_mode" -eq 1 ]]; then
  args+=(--plan)
fi
if [[ "$no_ask_user" -eq 1 ]]; then
  args+=(--no-ask-user)
fi
if [[ "$allow_all_paths" -eq 1 ]]; then
  args+=(--allow-all-paths)
fi
if [[ "$disallow_temp_dir" -eq 1 ]]; then
  args+=(--disallow-temp-dir)
fi
if [[ "$disable_builtin_mcps" -eq 1 ]]; then
  args+=(--disable-builtin-mcps)
fi
if [[ "$no_custom_instructions" -eq 1 ]]; then
  args+=(--no-custom-instructions)
fi
if [[ "$no_remote" -eq 1 ]]; then
  args+=(--no-remote)
fi
if [[ -n "$available_tools" ]]; then
  args+=(--available-tools "$available_tools")
fi
if [[ -n "$excluded_tools" ]]; then
  args+=(--excluded-tools "$excluded_tools")
fi

for add_dir in "${add_dirs[@]}"; do
  args+=(--add-dir "$add_dir")
done
for allow_tool in "${allow_tools[@]}"; do
  args+=(--allow-tool "$allow_tool")
done
for deny_tool in "${deny_tools[@]}"; do
  args+=(--deny-tool "$deny_tool")
done
for allow_url in "${allow_urls_specific[@]}"; do
  args+=(--allow-url "$allow_url")
done
for deny_url in "${deny_urls_specific[@]}"; do
  args+=(--deny-url "$deny_url")
done
for disable_mcp_server in "${disable_mcp_servers[@]}"; do
  args+=(--disable-mcp-server "$disable_mcp_server")
done
for additional_mcp_config in "${additional_mcp_configs[@]}"; do
  args+=(--additional-mcp-config "$additional_mcp_config")
done
for plugin_dir in "${plugin_dirs[@]}"; do
  args+=(--plugin-dir "$plugin_dir")
done

if [[ "$allow_write" -eq 0 && "$allow_all" -eq 0 ]]; then
  args+=(--deny-tool write)
fi
if [[ "$allow_shell" -eq 0 && "$allow_all" -eq 0 ]]; then
  args+=(--deny-tool 'shell')
fi
if [[ "$allow_urls" -eq 1 && "$allow_all" -eq 0 ]]; then
  args+=(--allow-all-urls)
fi

set +e
status=0
terminal_reason=""
if [[ "$require_vpn" == "1" ]]; then
  if ! vpn_check "$vpn_url" "$vpn_timeout_sec"; then
    status=90
    terminal_reason="vpn_preflight_failed"
  else
    setsid timeout "$timeout_sec" env "${copilot_env[@]}" "$copilot_bin" "${args[@]}" > "$output" &
    runner_pid=$!
    consecutive_vpn_failures=0

    while kill -0 "$runner_pid" 2>/dev/null; do
      sleep "$vpn_check_interval_sec"
      if ! kill -0 "$runner_pid" 2>/dev/null; then
        break
      fi

      if vpn_check "$vpn_url" "$vpn_timeout_sec"; then
        consecutive_vpn_failures=0
      else
        consecutive_vpn_failures=$((consecutive_vpn_failures + 1))
        if [[ "$consecutive_vpn_failures" -ge "$vpn_fail_threshold" ]]; then
          terminal_reason="vpn_lost"
          kill -TERM -- "-$runner_pid" 2>/dev/null || kill "$runner_pid" 2>/dev/null || true
          sleep 2
          if kill -0 "$runner_pid" 2>/dev/null; then
            kill -KILL -- "-$runner_pid" 2>/dev/null || kill -KILL "$runner_pid" 2>/dev/null || true
          fi
          break
        fi
      fi
    done

    wait "$runner_pid"
    status=$?
  fi
else
  timeout "$timeout_sec" env "${copilot_env[@]}" "$copilot_bin" "${args[@]}" > "$output"
  status=$?
fi
set -e

if [[ "$status" -ne 0 ]]; then
  if [[ -n "$terminal_reason" ]]; then
    printf 'Copilot call failed: %s\n' "$terminal_reason" >&2
  fi
  if [[ -f "$output" ]]; then
    cat "$output" >&2 || true
  fi
  exit "$status"
fi

if [[ ! -s "$output" ]]; then
  die "Copilot CLI returned empty output; not recording a successful review"
fi

recorded_session="${resume_session:-$session_alias}"
if [[ -n "$recorded_session" ]]; then
  printf '%s\n' "$recorded_session" > "$latest_session_file"
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg session "$recorded_session" \
      --arg title "$title" \
      --arg role "$role" \
      --arg model "$model" \
      --arg output "$output" \
      --arg share_output "$share_output" \
      --arg resumed_from "$resume_session" \
      --arg session_alias "$session_alias" \
      --arg timestamp "$timestamp" \
      '{session:$session,title:$title,role:$role,model:$model,output:$output,share_output:$share_output,resumed_from:$resumed_from,session_alias:$session_alias,timestamp:$timestamp}' \
      > "$latest_session_meta"
  fi

  if [[ -n "$session_alias" ]]; then
    printf '%s\n' "$recorded_session" > "$state_dir/copilot-session-$session_alias"
    if command -v jq >/dev/null 2>&1; then
      jq -n \
        --arg alias "$session_alias" \
        --arg session "$recorded_session" \
        --arg title "$title" \
        --arg role "$role" \
        --arg model "$model" \
        --arg output "$output" \
        --arg share_output "$share_output" \
        --arg timestamp "$timestamp" \
        '{alias:$alias,session:$session,title:$title,role:$role,model:$model,output:$output,share_output:$share_output,timestamp:$timestamp}' \
        > "$state_dir/copilot-session-$session_alias.json"
    fi
  fi
fi

printf 'Copilot response written to %s\n' "$output"
if [[ -n "$recorded_session" ]]; then
  printf 'Copilot session recorded: %s\n' "$recorded_session"
  if [[ -n "$session_alias" ]]; then
    printf 'Resume with: scripts/dev/agent-call-copilot.sh --resume alias:%s --prompt <text>\n' "$session_alias"
  fi
fi
