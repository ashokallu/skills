#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-call-claude.sh [options] --prompt <text>
  scripts/dev/agent-call-claude.sh [options] --prompt-file <path>
  echo "<prompt>" | scripts/dev/agent-call-claude.sh [options]

Options:
  --prompt <text>          Prompt to send to Claude Code.
  --prompt-file <path>     Read the prompt from a file.
  --context-file <path>    Append a local file's contents to the prompt. Repeatable.
  --allow-sensitive-context
                           Allow context-file paths that look secret-bearing.
  --title <title>          Used for the saved output filename.
  --output <path>          Write Claude's final text to this path.
  --json-schema <path>     Validate Claude output against a JSON Schema file.
  --fresh-session         Start fresh (default); conflicts with session selectors.
  --resume <id|latest>     Resume a previous Claude session. Alias and latest
                           selectors older than 50 minutes start fresh instead;
                           raw ids carry no recorded age and are unchecked.
  --session-alias <name>   Save/resume a named session alias for related calls.
  --lane <name>            Derive a Codex-thread-scoped alias for parallel lanes.
  --session-id <uuid>      Start a new session with this specific UUID.
  --no-session-persistence Do not save a resumable Claude session.
  --show-session-ids       Print raw Claude session ids in human failure output.
  --profile <name>         haiku, sonnet, opus, opus46, fable, architect, review, implement.
  --model <model>          Optional Claude model argument. Overrides --profile model.
  --effort <level>         Optional Claude effort level: low, medium, high, xhigh, max.
  --autocompact <auto|tokens>
                           Auto-compact window size: auto or 100k-1M tokens
                           (e.g. 500k). Omitted by default. Sets the context
                           headroom trigger for automatic summarization, not a
                           context-percentage control.
  --max-budget-usd <num>   Claude CLI post-request stop threshold. A final request can
                           exceed it; the wrapper rejects and records that outcome.
  --acknowledge-post-request-budget
                           Required for a live call. Confirms the threshold is not
                           a hard cap and that the caller has current spend authority.
  --pricing                Print built-in model pricing assumptions and exit.
  --timeout-sec <num>      Wall-clock timeout for the subprocess.
                           Default is profile-aware: haiku=300, sonnet/implement=900,
                           opus/opus46/fable/architect/review=1800.
  --require-vpn            Preflight and monitor VPN reachability while Claude runs.
  --vpn-url <url>          VPN-only URL to probe. Configure the endpoint before using --require-vpn.
  --vpn-timeout-sec <num>  Per-probe timeout. Default: 5.
  --vpn-check-interval-sec <num>
                           Seconds between in-flight VPN checks. Default: 15.
  --vpn-fail-threshold <n> Consecutive VPN failures before killing Claude. Default: 2.
  --tool-mode <mode>       auto, none, or all. Default: auto.
  --allow-tools            Alias for --tool-mode all.
  --no-tools               Alias for --tool-mode none.
  --setting-sources <list> Opt in to comma-separated Claude setting sources.
                           Omitted by default so --safe-mode disables ambient context.
  --help                   Show this help.

By default this bridge uses Claude Code safe mode, which preserves normal auth
while disabling ambient CLAUDE.md, skills, plugins, hooks, MCP servers, and
settings. Passing --setting-sources explicitly opts back into those setting
sources. Use --tool-mode none for cheap peer discussion where the prompt
already includes all needed context; that mode also replaces Claude Code's
default system prompt with the wrapper's compact peer contract.

Every live call requires --acknowledge-post-request-budget. Do not pass it on a
caller's behalf unless that caller was told that one final request can exceed
the selected threshold and has current authority for that risk.

Context files that look like secrets are rejected unless
--allow-sensitive-context is passed.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

redact_session_id() {
  local value=$1
  if [[ ${#value} -le 12 ]]; then
    printf '%s' "$value"
    return
  fi
  printf '%s...%s' "${value:0:8}" "${value: -4}"
}

vpn_check() {
  local url=$1
  local timeout_sec=$2
  curl --fail --silent --show-error --location --head --max-time "$timeout_sec" "$url" >/dev/null 2>&1
}

print_pricing() {
  cat <<'PRICING'
Built-in Claude routing and price assumptions. The Opus-class profiles pin
`claude-opus-5-5` so planning and review use the intended model instead of an
evergreen alias. The Opus 5.5 input/output and cache-read rates come from
the installed Claude Code 2.1.280 release notes; older rates are in Anthropic's
public pricing docs:
https://platform.claude.com/docs/en/about-claude/pricing

Profile     Model              Default threshold  Use
haiku       claude-haiku-4-5   $0.50        cheap classification, tiny summaries, formatting checks
sonnet      claude-sonnet-5-5  $2.00        1M-context scans, known-plan implementation, instruction following
implement   claude-sonnet-5-5  $2.00        same as sonnet; use when Codex already did the thinking
opus        claude-opus-5-5    $8.00        hard reasoning, architecture, ambiguous debugging
architect   claude-opus-5-5    $8.00        same as opus; planning and architecture review
review      claude-opus-5-5    $8.00        PR/code review and risk analysis
opus46      claude-opus-5-5    $8.00        compatibility profile alias for the current Opus model
fable       claude-fable-5-1   $16.00       explicit "use Fable" only; hardest long-horizon reasoning

Token prices per million tokens:
Model                                      Input  5m cache write  1h cache write  Cache read  Output
claude-haiku-4-5                           $1     $1.25           $2              $0.10       $5
claude-sonnet-5-5                          $2     $2.50           $4              $0.20       $10
claude-opus-5-5                            $4     $5              $8              $0.20       $20
claude-fable-5-1                           $10    $12.50          $20             $0.25       $50

Rough estimate formula:
  cost = input_mtok*input + cache_write_mtok*cache_write + cache_read_mtok*cache_read + output_mtok*output

Notes:
- Opus-class profiles pin the current `claude-opus-5-5` model identifier.
  Its 5m and 1h cache-write rates are estimates at 1.25x and 2x input.
  The fable profile pins `claude-fable-5-1`. Its cache-write rates are shown
  at the usual 1.25x and 2x of input; treat them as estimates.
  The opus46 name remains a compatibility profile alias for the current Opus
  model; all Opus profiles select `claude-opus-5-5`.
- Use the pinned model id claude-sonnet-5-5 when passing --model directly.
  Sonnet 5.5 uses adaptive thinking by default; control depth with --effort.
- Recheck max-token assumptions and measured cost for the selected model
  rather than treating a lower rate as a guaranteed cheaper call.
- Prompt-cache reads can be cheaper than cache writes. The selected Claude.ai
  Enterprise login uses a one-hour main-conversation cache TTL; verify the
  cache metadata. Resume a session only when its last message is less than
  fifty minutes old; otherwise start fresh. Follow the session-cost
  handoff policy rather than resuming a large cold conversation automatically.
- Use --profile fable only when the user explicitly asks for Fable or the task
  is worth the highest Anthropic cost tier. Prefer --tool-mode none and compact
  context unless repo inspection is essential.
- Tiny smoke prompts can still create large cache writes from loaded
  project/session context. Keep availability checks rare and inspect the
  returned usage metadata instead of inferring cost from prompt length.
- Wall-clock timeouts are separate from the post-request spend threshold.
  A final provider request can exceed `--max-budget-usd`; inspect recorded usage.
  Defaults are haiku=300s,
  sonnet/implement=900s, and opus/opus46/fable/architect/review=1800s.
- Do not use --require-vpn for the default Claude Enterprise path. Keep it only
  for explicit VPN-backed experiments; it fails fast as vpn_lost if VPN drops
  during a long call.
- The wrapper defaults to Claude Code --safe-mode and a compact replacement
  system prompt for tool-free calls. Pass --setting-sources explicitly only
  when the selected call requires custom settings; this disables safe mode.
PRICING
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
title="claude-call"
output=""
json_schema=""
fresh_session=0
resume_session=""
session_id=""
session_alias=""
lane=""
session_persistence=1
show_session_ids=0
profile="sonnet"
model=""
effort="${AGENT_CALL_CLAUDE_EFFORT:-}"
autocompact=""
# Fifty minutes inside the one-hour subscription cache TTL.
CLAUDE_SESSION_REUSE_WINDOW_SEC=3000
max_budget_usd=""
acknowledge_post_request_budget=0
timeout_sec="${AGENT_CALL_CLAUDE_TIMEOUT_SEC:-}"
require_vpn="${AGENT_CALL_CLAUDE_REQUIRE_VPN:-0}"
vpn_url="${AGENT_CALL_CLAUDE_VPN_URL:-${AGENT_COLLAB_VPN_URL:-}}"
vpn_timeout_sec="${AGENT_CALL_CLAUDE_VPN_TIMEOUT_SEC:-5}"
vpn_check_interval_sec="${AGENT_CALL_CLAUDE_VPN_CHECK_INTERVAL_SEC:-15}"
vpn_fail_threshold="${AGENT_CALL_CLAUDE_VPN_FAIL_THRESHOLD:-2}"
tool_mode="auto"
claude_bin="${AGENT_CALL_CLAUDE_BIN:-claude}"
setting_sources="${AGENT_CALL_CLAUDE_SETTING_SOURCES:-}"
setting_sources_explicit=0
if [[ -v AGENT_CALL_CLAUDE_SETTING_SOURCES ]]; then
  setting_sources_explicit=1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt=${2:-}; shift 2 ;;
    --prompt-file) prompt_file=${2:-}; shift 2 ;;
    --context-file) context_files+=("${2:-}"); shift 2 ;;
    --allow-sensitive-context) allow_sensitive_context=1; shift ;;
    --title) title=${2:-}; shift 2 ;;
    --output) output=${2:-}; shift 2 ;;
    --json-schema) json_schema=${2:-}; shift 2 ;;
    --fresh-session) fresh_session=1; shift ;;
    --resume) resume_session=${2:-}; shift 2 ;;
    --session-id) session_id=${2:-}; shift 2 ;;
    --session-alias) session_alias=${2:-}; shift 2 ;;
    --lane) lane=${2:-}; shift 2 ;;
    --no-session-persistence) session_persistence=0; shift ;;
    --show-session-ids) show_session_ids=1; shift ;;
    --profile) profile=${2:-}; shift 2 ;;
    --model) model=${2:-}; shift 2 ;;
    --effort|--reasoning-effort) effort=${2:-}; shift 2 ;;
    --autocompact) autocompact=${2:-}; shift 2 ;;
    --max-budget-usd) max_budget_usd=${2:-}; shift 2 ;;
    --acknowledge-post-request-budget) acknowledge_post_request_budget=1; shift ;;
    --pricing) print_pricing; exit 0 ;;
    --timeout-sec) timeout_sec=${2:-}; shift 2 ;;
    --require-vpn) require_vpn=1; shift ;;
    --vpn-url) vpn_url=${2:-}; shift 2 ;;
    --vpn-timeout-sec) vpn_timeout_sec=${2:-}; shift 2 ;;
    --vpn-check-interval-sec) vpn_check_interval_sec=${2:-}; shift 2 ;;
    --vpn-fail-threshold) vpn_fail_threshold=${2:-}; shift 2 ;;
    --tool-mode) tool_mode=${2:-}; shift 2 ;;
    --allow-tools) tool_mode="all"; shift ;;
    --no-tools) tool_mode="none"; shift ;;
    --setting-sources) setting_sources=${2:-}; setting_sources_explicit=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$prompt_file" ]]; then
  [[ -f "$prompt_file" ]] || die "--prompt-file does not exist: $prompt_file"
  prompt=$(sed 's/[[:space:]]*$//' "$prompt_file")
elif [[ -z "$prompt" && ! -t 0 ]]; then
  prompt=$(sed 's/[[:space:]]*$//')
fi

[[ -n "$prompt" ]] || die "provide --prompt, --prompt-file, or stdin"
command -v "$claude_bin" >/dev/null 2>&1 || die "claude CLI not found on PATH: $claude_bin"
claude_path=$(command -v "$claude_bin")
command -v jq >/dev/null 2>&1 || die "jq is required to parse Claude JSON output"
if [[ "$require_vpn" == "1" ]]; then
  [[ -n "$vpn_url" ]] || die "--require-vpn requires --vpn-url or AGENT_CALL_CLAUDE_VPN_URL"
  command -v curl >/dev/null 2>&1 || die "curl is required for --require-vpn"
  command -v setsid >/dev/null 2>&1 || die "setsid is required for --require-vpn process-group cleanup"
fi
if [[ -n "$json_schema" && ! -f "$json_schema" ]]; then
  die "--json-schema does not exist: $json_schema"
fi
for context_file in "${context_files[@]}"; do
  [[ -f "$context_file" ]] || die "--context-file does not exist: $context_file"
  if [[ "$allow_sensitive_context" -eq 0 ]] && is_sensitive_context_path "$context_file"; then
    die "--context-file looks secret-bearing: $context_file; pass --allow-sensitive-context only if this is intentional"
  fi
done
if [[ "$fresh_session" -eq 1 && ( -n "$resume_session" || -n "$session_id" || -n "$session_alias" || -n "$lane" ) ]]; then
  die "--fresh-session conflicts with session selectors"
fi
if [[ -n "$resume_session" && -n "$session_id" ]]; then
  die "use --resume OR --session-id, not both"
fi
if [[ -n "$lane" && -n "$session_alias" ]]; then
  die "use --lane OR --session-alias, not both"
fi
if [[ -n "$lane" && ( -n "$resume_session" || -n "$session_id" ) ]]; then
  die "use --lane OR explicit Claude resumption flags, not both"
fi
if [[ -n "$session_alias" ]]; then
  session_alias=$(sanitize_slug "$session_alias")
  [[ -n "$session_alias" ]] || die "--session-alias must contain at least one safe filename character"
fi
if [[ -n "$lane" ]]; then
  if [[ -z "${CODEX_THREAD_ID:-}" ]]; then
    die "--lane requires CODEX_THREAD_ID to be set in the environment"
  fi
  lane=$(sanitize_slug "$lane")
  [[ -n "$lane" ]] || die "--lane must contain at least one safe filename character"
fi

profile_model=""
profile_budget=""
profile_timeout=""
case "$profile" in
  haiku)
    profile_model="claude-haiku-4-5"
    profile_budget="0.50"
    profile_timeout="300"
    ;;
  sonnet|implement)
    profile_model="claude-sonnet-5-5"
    profile_budget="2.00"
    profile_timeout="900"
    ;;
  opus|architect|review)
    profile_model="claude-opus-5-5"
    profile_budget="8.00"
    profile_timeout="1800"
    ;;
  opus46)
    profile_model="claude-opus-5-5"
    profile_budget="8.00"
    profile_timeout="1800"
    ;;
  fable)
    profile_model="claude-fable-5-1"
    profile_budget="16.00"
    profile_timeout="1800"
    ;;
  *)
    die "--profile must be haiku, sonnet, implement, opus, architect, review, opus46, or fable"
    ;;
esac

if [[ -z "$model" ]]; then
  model="$profile_model"
fi

case "$effort" in
  ""|low|medium|high|xhigh|max) ;;
  *) die "--effort must be one of low, medium, high, xhigh, or max" ;;
esac

case "$autocompact" in
  "") ;;
  auto) ;;
  *)
    if [[ "$autocompact" =~ ^([0-9]+)([kKmM])?$ ]]; then
      autocompact_tokens="${BASH_REMATCH[1]}"
      case "${BASH_REMATCH[2]:-}" in
        [kK]) autocompact_tokens=$((autocompact_tokens * 1000)) ;;
        [mM]) autocompact_tokens=$((autocompact_tokens * 1000000)) ;;
      esac
      if [[ "$autocompact_tokens" -lt 100000 || "$autocompact_tokens" -gt 1000000 ]]; then
        die "--autocompact must be auto or 100k-1M tokens"
      fi
    else
      die "--autocompact must be auto or 100k-1M tokens"
    fi
    ;;
esac

if [[ -z "$max_budget_usd" ]]; then
  max_budget_usd="$profile_budget"
fi
if ! [[ "$max_budget_usd" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] ||
   ! awk -v value="$max_budget_usd" 'BEGIN { exit !(value > 0) }'; then
  die "--max-budget-usd must be a positive decimal number"
fi
[[ "$acknowledge_post_request_budget" -eq 1 ]] ||
  die "--acknowledge-post-request-budget is required because --max-budget-usd is not a hard per-request cap"

if [[ "$setting_sources_explicit" -eq 1 && -z "$setting_sources" ]]; then
  die "--setting-sources must name at least one source"
fi

if [[ -z "$timeout_sec" && -n "$profile_timeout" ]]; then
  timeout_sec="$profile_timeout"
fi

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]]; then
  die "--timeout-sec must be a positive integer"
fi
case "$require_vpn" in
  0|1) ;;
  *) die "--require-vpn must be 0 or 1 when set through AGENT_CALL_CLAUDE_REQUIRE_VPN" ;;
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

case "$tool_mode" in
  auto|none|all) ;;
  *) die "--tool-mode must be auto, none, or all" ;;
esac

root=$(repo_root)
calls_dir="$root/tmp/codex-claude/calls"
state_dir="$root/tmp/codex-claude/state"
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="claude-call"
mkdir -p "$calls_dir"
mkdir -p "$state_dir"

if [[ -z "$output" ]]; then
  output="$calls_dir/$timestamp-claude-$slug.md"
fi
json_output="$calls_dir/$timestamp-claude-$slug.json"
latest_session_file="$state_dir/claude-latest-session-id"
latest_session_meta="$state_dir/claude-latest-session.json"

# Reuse requires an explicit selector. A task ID alone never resumes context.
if [[ -n "$lane" ]]; then
  [[ -n "${CODEX_THREAD_ID:-}" ]] || die "--lane requires CODEX_THREAD_ID"
  session_alias=$(sanitize_slug "codex-thread-$CODEX_THREAD_ID-$lane")
fi

if [[ -n "$session_alias" && -z "$resume_session" && -z "$session_id" && -f "$state_dir/claude-session-$session_alias" ]]; then
  resume_session="alias:$session_alias"
fi

resume_state_file=""
if [[ "$resume_session" == "latest" ]]; then
  [[ -f "$latest_session_file" ]] || die "no latest Claude session recorded at $latest_session_file"
  resume_state_file="$latest_session_file"
  resume_session=$(sed -n '1p' "$latest_session_file")
elif [[ "$resume_session" == alias:* ]]; then
  alias_name=$(sanitize_slug "${resume_session#alias:}")
  [[ -n "$alias_name" ]] || die "resume alias must contain at least one safe filename character"
  alias_file="$state_dir/claude-session-$alias_name"
  [[ -f "$alias_file" ]] || die "no Claude session alias recorded at $alias_file"
  resume_state_file="$alias_file"
  resume_session=$(sed -n '1p' "$alias_file")
fi

# Enforce the 50-minute session-reuse window. A stale alias/latest selector
# starts fresh instead of rebuilding an expired cache prefix; the alias keeps
# its name and is rebound to the new session below.
if [[ -n "$resume_session" && -n "$resume_state_file" ]]; then
  resume_mtime=$(stat -c %Y "$resume_state_file" 2>/dev/null) ||
    die "cannot read Claude session state age: $resume_state_file"
  resume_age_sec=$(( $(date +%s) - resume_mtime ))
  if [[ "$resume_age_sec" -lt 0 ]]; then
    resume_age_sec=0
  fi
  if [[ "$resume_age_sec" -gt "$CLAUDE_SESSION_REUSE_WINDOW_SEC" ]]; then
    printf 'Claude resume: selector is stale (last used %s minutes ago); starting a fresh session instead of resuming\n' \
      "$((resume_age_sec / 60))" >&2
    resume_session=""
  fi
elif [[ -n "$resume_session" ]]; then
  printf 'Claude resume: raw session id has no recorded age; 50-minute reuse rule unchecked\n' >&2
fi

system_prompt='You are Claude Code collaborating with Codex CLI in the project repository. AGENTS.md and repo.md are the shared contract. Treat this as a peer consultation unless the prompt explicitly asks otherwise. Return concise, actionable analysis with evidence, objections, failure scenarios, and Pending Verification for unproven claims. Do not claim you changed files unless you actually did.'

if [[ "${#context_files[@]}" -gt 0 ]]; then
  context_block=$'\n\n## Explicit Local Context Files\n'
  for context_file in "${context_files[@]}"; do
    context_block+=$'\n### File: '"$context_file"$'\n```text\n'
    context_block+="$(sed 's/[[:space:]]*$//' "$context_file")"
    context_block+=$'\n```\n'
  done
  prompt+="$context_block"
fi

args=(
  --print
  --output-format json
  --max-budget-usd "$max_budget_usd"
  --prompt-suggestions false
  --system-prompt-snapshot off
)

if [[ "$tool_mode" == "none" ]]; then
  args+=(--system-prompt "$system_prompt")
else
  args+=(--append-system-prompt "$system_prompt")
fi

if [[ "$setting_sources_explicit" -eq 1 ]]; then
  args+=(--setting-sources "$setting_sources")
else
  args+=(--safe-mode)
fi

if [[ "$session_persistence" -eq 0 ]]; then
  args+=(--no-session-persistence)
fi

if [[ -n "$json_schema" ]]; then
  args+=(--json-schema "$(cat "$json_schema")")
fi

if [[ -n "$resume_session" ]]; then
  args+=(--resume "$resume_session")
fi

if [[ -n "$session_id" ]]; then
  args+=(--session-id "$session_id")
fi

if [[ -n "$model" ]]; then
  args+=(--model "$model")
fi

if [[ -n "$effort" ]]; then
  args+=(--effort "$effort")
fi

if [[ -n "$autocompact" ]]; then
  args+=(--autocompact "$autocompact")
fi

if [[ "$tool_mode" == "none" ]]; then
  args+=(--tools="")
elif [[ "$tool_mode" == "all" ]]; then
  args+=(--tools=default)
fi

session_mode="fresh"
[[ -z "$session_id" ]] || session_mode="fixed-id"
[[ -z "$resume_session" ]] || session_mode="resume"
selected_session="${resume_session:-$session_id}"
printf 'Claude dispatch: session=%s; selector=%s; prompt-transport=stdin\n' \
  "$session_mode" "${selected_session:+$(redact_session_id "$selected_session")}" >&2

set +e
terminal_reason=""
if [[ "$require_vpn" == "1" ]]; then
  if ! vpn_check "$vpn_url" "$vpn_timeout_sec"; then
    status=90
    terminal_reason="vpn_preflight_failed"
  else
    setsid timeout "$timeout_sec" "$claude_path" "${args[@]}" <<< "$prompt" > "$json_output" &
    runner_pid=$!
    status=""
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
  timeout "$timeout_sec" "$claude_path" "${args[@]}" <<< "$prompt" > "$json_output"
  status=$?
fi
set -e

if [[ ! -s "$json_output" ]]; then
  if [[ -z "$terminal_reason" ]]; then
    terminal_reason="empty_output"
  fi
  if [[ "$status" -eq 124 ]]; then
    terminal_reason="timeout"
  fi
  jq -n \
    --arg terminal_reason "$terminal_reason" \
    --arg title "$title" \
    --arg profile "$profile" \
    --arg model "$model" \
    --arg effort "$effort" \
    --arg status "$status" \
    --arg timeout_sec "$timeout_sec" \
    --arg require_vpn "$require_vpn" \
    --arg vpn_url "$vpn_url" \
    --arg vpn_timeout_sec "$vpn_timeout_sec" \
    --arg vpn_check_interval_sec "$vpn_check_interval_sec" \
    --arg vpn_fail_threshold "$vpn_fail_threshold" \
    --arg output "$output" \
    '{type:"claude-call-diagnostic",is_error:true,errors:["Claude CLI produced no JSON output"],terminal_reason:$terminal_reason,title:$title,profile:$profile,model:$model,effort:(if $effort == "" then null else $effort end),exit_status:($status|tonumber),timeout_sec:($timeout_sec|tonumber),require_vpn:($require_vpn == "1"),vpn_url:$vpn_url,vpn_timeout_sec:($vpn_timeout_sec|tonumber),vpn_check_interval_sec:($vpn_check_interval_sec|tonumber),vpn_fail_threshold:($vpn_fail_threshold|tonumber),output:$output,total_cost_usd:null}' \
    > "$json_output"
fi

budget_threshold_exceeded=0
budget_threshold_known=0
actual_cost_usd=""
if jq -e . "$json_output" >/dev/null 2>&1; then
  actual_cost_usd=$(jq -r 'if (.total_cost_usd | type) == "number" then .total_cost_usd else empty end' "$json_output")
  if [[ -n "$actual_cost_usd" ]]; then
    budget_threshold_known=1
    if awk -v actual="$actual_cost_usd" -v threshold="$max_budget_usd" \
      'BEGIN { exit !(actual > threshold) }'; then
      budget_threshold_exceeded=1
    fi
  fi

  enriched_json="${json_output}.budget.$$"
  jq \
    --arg session_mode "$session_mode" \
    --arg requested_budget_usd "$max_budget_usd" \
    --argjson budget_threshold_known "$budget_threshold_known" \
    --argjson budget_threshold_exceeded "$budget_threshold_exceeded" \
    '. + {
      session_mode: $session_mode,
      prompt_transport: "stdin",
      requested_budget_usd: ($requested_budget_usd | tonumber),
      budget_semantics: "post_request_stop_threshold",
      budget_risk_acknowledged: true,
      budget_threshold_exceeded: (
        if $budget_threshold_known == 1
        then ($budget_threshold_exceeded == 1)
        else null
        end
      )
    }' \
    "$json_output" > "$enriched_json"
  mv "$enriched_json" "$json_output"
fi

actual_session_id=$(jq -r '.session_id // empty' "$json_output" 2>/dev/null || true)
if [[ -n "$actual_session_id" && "$session_persistence" -eq 1 ]]; then
  printf '%s\n' "$actual_session_id" > "$latest_session_file"
  jq -n \
    --arg session_id "$actual_session_id" \
    --arg timestamp "$timestamp" \
    --arg title "$title" \
    --arg profile "$profile" \
    --arg model "$model" \
    --arg effort "$effort" \
    --arg output "$output" \
    --arg json_output "$json_output" \
    '{session_id:$session_id,timestamp:$timestamp,title:$title,profile:$profile,model:$model,effort:(if $effort == "" then null else $effort end),output:$output,json_output:$json_output}' \
    > "$latest_session_meta"
  if [[ -n "$session_alias" ]]; then
    printf '%s\n' "$actual_session_id" > "$state_dir/claude-session-$session_alias"
    jq -n \
      --arg alias "$session_alias" \
      --arg session_id "$actual_session_id" \
      --arg timestamp "$timestamp" \
      --arg title "$title" \
      --arg profile "$profile" \
      --arg model "$model" \
      --arg effort "$effort" \
      --arg output "$output" \
      --arg json_output "$json_output" \
      '{alias:$alias,session_id:$session_id,timestamp:$timestamp,title:$title,profile:$profile,model:$model,effort:(if $effort == "" then null else $effort end),output:$output,json_output:$json_output}' \
      > "$state_dir/claude-session-$session_alias.json"
  fi
fi

if jq -e '.structured_output?' "$json_output" >/dev/null 2>&1; then
  jq -c '.structured_output' "$json_output" | tee "$output"
elif jq -e '.result?' "$json_output" >/dev/null 2>&1; then
  jq -r '.result // empty' "$json_output" | tee "$output"
else
  {
    printf 'Claude call did not return a result.\n'
    printf 'Inspect JSON metadata: %s\n' "$json_output"
  } | tee "$output"
fi

if [[ "$budget_threshold_exceeded" -eq 1 ]]; then
  printf 'Claude spend exceeded its USD %s post-request stop threshold (observed USD %s). The threshold is not a hard per-request cap; do not retry or raise it without fresh spend authority.\n' \
    "$max_budget_usd" "$actual_cost_usd" >&2
fi

if [[ "$status" -ne 0 ]]; then
  jq -r '"Claude call failed: " + ((.errors // []) | join("; "))' "$json_output" >&2 || true
  if [[ -n "$actual_session_id" ]]; then
    if [[ "$show_session_ids" -eq 1 ]]; then
      printf 'Claude session_id: %s\n' "$actual_session_id" >&2
    else
      printf 'Claude session_id: %s (redacted)\n' "$(redact_session_id "$actual_session_id")" >&2
    fi
    if [[ "$session_persistence" -eq 0 ]]; then
      printf 'The session was not persisted; no resume command is available.\n' >&2
    elif [[ "$budget_threshold_exceeded" -eq 1 ]]; then
      printf 'The session was retained for audit, but no resume command is shown after a spend overrun.\n' >&2
    elif [[ "$show_session_ids" -eq 1 ]]; then
      printf 'Resume with: scripts/dev/agent-call-claude.sh --resume %s --acknowledge-post-request-budget --prompt <text>\n' "$actual_session_id" >&2
    elif [[ -n "$session_alias" ]]; then
      printf 'Resume with: scripts/dev/agent-call-claude.sh --resume alias:%s --acknowledge-post-request-budget --prompt <text>\n' "$session_alias" >&2
      printf 'Raw session id is stored in: %s\n' "$state_dir/claude-session-$session_alias" >&2
    else
      printf '%s\n' "Resume with: scripts/dev/agent-call-claude.sh --resume \"\$(cat $latest_session_file)\" --acknowledge-post-request-budget --prompt <text>" >&2
      printf 'Pass --show-session-ids to print raw session ids in human output.\n' >&2
    fi
  fi
  exit "$status"
fi

if [[ "$budget_threshold_exceeded" -eq 1 ]]; then
  exit 88
fi
