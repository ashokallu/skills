#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-call-codex.sh [options] --prompt <text>
  scripts/dev/agent-call-codex.sh [options] --prompt-file <path>
  echo "<prompt>" | scripts/dev/agent-call-codex.sh [options]

Options:
  --prompt <text>        Prompt to send to Codex CLI.
  --prompt-file <path>   Read the prompt from a file.
  --context-file <path>  Append a local file's contents to the prompt. Repeatable.
  --allow-sensitive-context
                         Allow context-file paths that look secret-bearing.
  --no-review-context    Do not auto-append repo reviewer context for review-style calls.
  --title <title>        Used for the saved output filename.
  --output <path>        Write Codex's final text to this path.
  --events-output <path> Write Codex event transcript or JSONL to this path.
  --resume <id|latest|last|alias:name>
                       Resume a previous Codex exec session.
  --session-alias <name>
                       Save/resume a named Codex session alias for related calls.
  --allow-unsafe-latest
                       Permit --resume latest/last. Prefer aliases or raw ids.
  --no-session-persistence
                       Do not save latest or alias state for this call.
  --model <model>        Optional Codex model argument.
  --effort <level>       Optional Codex reasoning effort: low, medium, high, xhigh,
                         max, or ultra. gpt-6.1-sol defaults to high; gpt-6-astra
                         defaults to medium. User-requested Sol xhigh, max, or
                         ultra also requires --allow-user-requested-elevated-effort.
                         Explicit model selections are checked against a recent
                         local model cache from this Codex CLI.
  --allow-user-requested-elevated-effort
                         Confirm the current user explicitly requested xhigh,
                         max, or ultra. Never use this as an agent-selected
                         escalation.
                         Legacy alias: --allow-user-requested-max-ultra.
  --sandbox <mode>       Codex sandbox mode. Default: read-only.
  --json-events          Use a .events.jsonl suffix for the captured JSONL events.
  --timeout-sec <num>    Wall-clock timeout for the subprocess. Default: 180.
  --allow-write          Shortcut for --sandbox workspace-write.
  --help                 Show this help.

This bridge unsets OPENAI_API_KEY for the Codex subprocess so calls use the
logged-in ChatGPT subscription auth path instead of API billing.

Context files that look like secrets are rejected unless
--allow-sensitive-context is passed.

Review-style calls automatically receive the repo reviewer context, including
the reviewer contract and Codex review output contract. Use
--no-review-context only for non-review debugging where that extra context
would be harmful.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
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

contains_context_file() {
  local wanted=$1
  local context_file

  for context_file in "${context_files[@]}"; do
    if [[ "$context_file" == "$wanted" ]]; then
      return 0
    fi
  done

  return 1
}

looks_like_review_call() {
  local haystack
  haystack=$(printf '%s\n%s\n' "$title" "$prompt" | tr '[:upper:]' '[:lower:]')

  case "$haystack" in
    *review*|*verdict*|*finding*|*pull\ request*|*pr\ #*|*pr[0-9]*)
      return 0
      ;;
  esac

  return 1
}

resolve_session_reference() {
  local reference=$1
  local state_dir=$2
  local latest_file="$state_dir/codex-latest-session-id"
  local alias_name
  local alias_file

  case "$reference" in
    latest)
      [[ -s "$latest_file" ]] || die "no latest Codex session recorded at $latest_file"
      sed 's/[[:space:]]*$//' "$latest_file"
      ;;
    last)
      printf '%s' "__CODEx_LAST__"
      ;;
    alias:*)
      alias_name=$(sanitize_slug "${reference#alias:}")
      [[ -n "$alias_name" ]] || die "--resume alias:<name> must contain at least one safe filename character"
      alias_file="$state_dir/codex-session-$alias_name"
      [[ -s "$alias_file" ]] || die "no Codex session alias recorded at $alias_file"
      sed 's/[[:space:]]*$//' "$alias_file"
      ;;
    *)
      printf '%s' "$reference"
      ;;
  esac
}

prompt=""
prompt_file=""
context_files=()
allow_sensitive_context=0
title="codex-call"
output=""
events_output=""
resume_session=""
session_alias=""
allow_unsafe_latest=0
session_persistence=1
model=""
effort=""
sandbox="read-only"
timeout_sec="180"
json_events=0
auto_review_context=1
allow_user_requested_elevated_effort=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt=${2:-}; shift 2 ;;
    --prompt-file) prompt_file=${2:-}; shift 2 ;;
    --context-file) context_files+=("${2:-}"); shift 2 ;;
    --allow-sensitive-context) allow_sensitive_context=1; shift ;;
    --title) title=${2:-}; shift 2 ;;
    --output) output=${2:-}; shift 2 ;;
    --events-output) events_output=${2:-}; shift 2 ;;
    --resume) resume_session=${2:-}; shift 2 ;;
    --session-alias) session_alias=${2:-}; shift 2 ;;
    --allow-unsafe-latest) allow_unsafe_latest=1; shift ;;
    --no-session-persistence) session_persistence=0; shift ;;
    --model) model=${2:-}; shift 2 ;;
    --effort|--reasoning-effort) effort=${2:-}; shift 2 ;;
    --allow-user-requested-elevated-effort|--allow-user-requested-max-ultra)
      allow_user_requested_elevated_effort=1
      shift
      ;;
    --sandbox) sandbox=${2:-}; shift 2 ;;
    --json-events) json_events=1; shift ;;
    --timeout-sec) timeout_sec=${2:-}; shift 2 ;;
    --allow-write) sandbox="workspace-write"; shift ;;
    --no-review-context) auto_review_context=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$sandbox" in
  read-only|workspace-write) ;;
  *) die "--sandbox must be read-only or workspace-write" ;;
esac

case "$effort" in
  ""|low|medium|high|xhigh|max|ultra) ;;
  *) die "--effort must be one of low, medium, high, xhigh, max, or ultra" ;;
esac

case "$effort" in
  xhigh|max|ultra)
    [[ "$allow_user_requested_elevated_effort" -eq 1 ]] ||
      die "--effort $effort requires --allow-user-requested-elevated-effort because xhigh, max, and ultra are explicit-user-only"
    ;;
esac

if [[ "$model" == "gpt-6.1-sol" ]]; then
  if [[ -z "$effort" ]]; then
    effort="high"
  fi
  case "$effort" in
    high|xhigh|max|ultra) ;;
    *) die "--model gpt-6.1-sol requires high, or user-requested xhigh, max, or ultra" ;;
  esac
fi

if [[ "$model" == "gpt-6-astra" ]]; then
  if [[ -z "$effort" ]]; then
    effort="medium"
  fi
  case "$effort" in
    low|medium|high|xhigh|max|ultra) ;;
    *) die "--model gpt-6-astra requires low, medium, high, or user-requested xhigh, max, or ultra" ;;
  esac
fi

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]]; then
  die "--timeout-sec must be a positive integer"
fi

if [[ -n "$prompt_file" ]]; then
  [[ -f "$prompt_file" ]] || die "--prompt-file does not exist: $prompt_file"
  prompt=$(sed 's/[[:space:]]*$//' "$prompt_file")
elif [[ -z "$prompt" && ! -t 0 ]]; then
  prompt=$(sed 's/[[:space:]]*$//')
fi

[[ -n "$prompt" ]] || die "provide --prompt, --prompt-file, or stdin"
command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH"
command -v jq >/dev/null 2>&1 || die "jq is required to parse Codex JSONL events"
root=$(repo_root)

codex_home=${CODEX_HOME:-${HOME:-}/.codex}
models_cache_file=${CODEX_MODELS_CACHE_FILE:-$codex_home/models_cache.json}
codex_version=$(codex --version | awk '{print $NF}')
cache_client_version=""
cache_fetched_epoch=""
cache_age_seconds=""
if [[ -r "$models_cache_file" ]]; then
  cache_client_version=$(jq -r '.client_version // empty' "$models_cache_file" 2>/dev/null || true)
  cache_fetched_at=$(jq -r '.fetched_at // empty' "$models_cache_file" 2>/dev/null || true)
  cache_fetched_epoch=$(date -u -d "$cache_fetched_at" '+%s' 2>/dev/null || true)
  if [[ -n "$cache_fetched_epoch" ]]; then
    cache_age_seconds=$(( $(date -u '+%s') - cache_fetched_epoch ))
  fi
fi

# Treat the cache as authoritative only when it belongs to this CLI and was
# fetched recently. Otherwise let Codex refresh or validate the pair itself.
if [[ -n "$model" && -n "$effort" &&
      "$cache_client_version" == "$codex_version" &&
      "$cache_age_seconds" =~ ^[0-9]+$ && "$cache_age_seconds" -le 86400 ]] &&
  jq -e --arg model "$model" '.models[]? | select(.slug == $model)' \
    "$models_cache_file" >/dev/null; then
  if ! jq -e --arg model "$model" --arg effort "$effort" '
    .models[]?
    | select(.slug == $model)
    | any(.supported_reasoning_levels[]?; .effort == $effort)
  ' "$models_cache_file" >/dev/null; then
    die "--effort $effort is not supported by --model $model in $models_cache_file"
  fi
fi

if [[ "$auto_review_context" -eq 1 ]] && looks_like_review_call; then
  review_context_files=(
    "$root/.codex/agents/reviewer.toml"
    "$root/docs/agents/codex-review-output-contract.md"
  )
  for review_context_file in "${review_context_files[@]}"; do
    [[ -f "$review_context_file" ]] || die "required review context file does not exist: $review_context_file"
    if ! contains_context_file "$review_context_file"; then
      context_files+=("$review_context_file")
    fi
  done
fi

for context_file in "${context_files[@]}"; do
  [[ -f "$context_file" ]] || die "--context-file does not exist: $context_file"
  if [[ "$allow_sensitive_context" -eq 0 ]] && is_sensitive_context_path "$context_file"; then
    die "--context-file looks secret-bearing: $context_file; pass --allow-sensitive-context only if this is intentional"
  fi
done

calls_dir="$root/tmp/codex-claude/calls"
state_dir="$root/tmp/codex-claude/state"
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="codex-call"
mkdir -p "$calls_dir" "$state_dir"

if [[ -n "$session_alias" ]]; then
  session_alias=$(sanitize_slug "$session_alias")
  [[ -n "$session_alias" ]] || die "--session-alias must contain at least one safe filename character"
fi

case "$resume_session" in
  latest|last)
    if [[ "$allow_unsafe_latest" -ne 1 ]]; then
      die "--resume $resume_session is unsafe when multiple sessions may run; use --resume alias:<name> or a raw session id, or pass --allow-unsafe-latest for a manual/debug call"
    fi
    ;;
esac

if [[ -z "$output" ]]; then
  output="$calls_dir/$timestamp-codex-$slug.md"
fi
if [[ -z "$events_output" ]]; then
  if [[ "$json_events" -eq 1 ]]; then
    events_output="$calls_dir/$timestamp-codex-$slug.events.jsonl"
  else
    events_output="$calls_dir/$timestamp-codex-$slug.events.log"
  fi
fi

if [[ "${#context_files[@]}" -gt 0 ]]; then
  context_block=$'\n\n## Explicit Local Context Files\n'
  for context_file in "${context_files[@]}"; do
    context_block+=$'\n### File: '"$context_file"$'\n```text\n'
    context_block+="$(sed 's/[[:space:]]*$//' "$context_file")"
    context_block+=$'\n```\n'
  done
  prompt+="$context_block"
fi

collab_prompt=$(cat <<EOF
You are Codex CLI working through a headless collaboration wrapper in the
project repository. AGENTS.md and repo.md are the shared contract. Follow
the peer, council, planning, review, or execution role in the request below.
Return concise, actionable analysis with evidence, objections, failure scenarios,
and Pending Verification for unproven claims. Do not claim you changed files
unless you actually did.

Peer request:
$prompt
EOF
)

args=(
  --ask-for-approval never
  --cd "$root"
  --sandbox "$sandbox"
)

if [[ -n "$resume_session" ]]; then
  args+=(exec resume)
else
  args+=(exec)
fi

args+=(
  --output-last-message "$output"
  --json
)

if [[ -n "$model" ]]; then
  args+=(--model "$model")
fi

if [[ -n "$effort" ]]; then
  args+=(-c "model_reasoning_effort=\"$effort\"")
fi

if [[ -n "$resume_session" ]]; then
  resolved_session=$(resolve_session_reference "$resume_session" "$state_dir")
  if [[ "$resolved_session" == "__CODEx_LAST__" ]]; then
    args+=(--last)
  else
    args+=("$resolved_session")
  fi
fi

if ! timeout "$timeout_sec" env -u OPENAI_API_KEY codex "${args[@]}" "$collab_prompt" > "$events_output" 2>&1; then
  cat "$events_output" >&2
  exit 1
fi

actual_session_id=$(jq -Rr 'fromjson? | select(.type == "thread.started") | .thread_id // empty' "$events_output" | tail -1)
usage_json=$(jq -Rsc '[split("\n")[] | fromjson? | select(.type == "turn.completed") | .usage] | last // {}' "$events_output")
if [[ -n "$actual_session_id" && "$session_persistence" -eq 1 ]]; then
  latest_session_file="$state_dir/codex-latest-session-id"
  latest_session_json="$state_dir/codex-latest-session.json"
  printf '%s\n' "$actual_session_id" > "$latest_session_file"
  jq -n \
    --arg session_id "$actual_session_id" \
    --arg title "$title" \
    --arg output "$output" \
    --arg events_output "$events_output" \
    --arg effort "$effort" \
    --arg resumed_from "$resume_session" \
    --arg session_alias "$session_alias" \
    --arg timestamp "$timestamp" \
    --argjson usage "$usage_json" \
    '{session_id:$session_id,title:$title,output:$output,events_output:$events_output,effort:(if $effort == "" then null else $effort end),resumed_from:$resumed_from,session_alias:$session_alias,timestamp:$timestamp,usage:$usage}' \
    > "$latest_session_json"
  if [[ -n "$session_alias" ]]; then
    printf '%s\n' "$actual_session_id" > "$state_dir/codex-session-$session_alias"
    jq -n \
      --arg session_id "$actual_session_id" \
      --arg title "$title" \
      --arg output "$output" \
      --arg events_output "$events_output" \
      --arg effort "$effort" \
      --arg resumed_from "$resume_session" \
      --arg session_alias "$session_alias" \
      --arg timestamp "$timestamp" \
      --argjson usage "$usage_json" \
      '{session_id:$session_id,title:$title,output:$output,events_output:$events_output,effort:(if $effort == "" then null else $effort end),resumed_from:$resumed_from,session_alias:$session_alias,timestamp:$timestamp,usage:$usage}' \
      > "$state_dir/codex-session-$session_alias.json"
  fi
fi

cat "$output"
