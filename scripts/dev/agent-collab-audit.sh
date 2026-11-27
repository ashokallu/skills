#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-collab-audit.sh [options]

Options:
  --since <YYYYMMDD|YYYYMMDDTHHMMSSZ>
                         Include call files at or after this UTC timestamp.
  --calls-dir <path>     Override Claude/Codex call artifact directory.
  --controller-dir <path>
                         Override controller run directory.
  --show-session-ids     Include raw Claude session ids in output.
  --json                 Emit machine-readable JSON summary.
  --help                 Show this help.

Summarizes local gitignored collaboration artifacts. Claude billing is based on
total_cost_usd fields returned by Claude Code JSON output; Codex subscription
calls do not include billable API cost in these artifacts.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

since=""
calls_dir=""
controller_dir=""
json_output=0
show_session_ids=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) since=${2:-}; shift 2 ;;
    --calls-dir) calls_dir=${2:-}; shift 2 ;;
    --controller-dir) controller_dir=${2:-}; shift 2 ;;
    --show-session-ids) show_session_ids=1; shift ;;
    --json) json_output=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required"

root=$(repo_root)
[[ -n "$calls_dir" ]] || calls_dir="$root/tmp/codex-claude/calls"
[[ -n "$controller_dir" ]] || controller_dir="$root/tmp/codex-claude/controller"

tmp_calls=$(mktemp)
tmp_controllers=$(mktemp)
trap 'rm -f "$tmp_calls" "$tmp_controllers"' EXIT

if [[ -d "$calls_dir" ]]; then
  while IFS= read -r file; do
    base=$(basename "$file")
    ts=${base%%-*}
    if [[ -n "$since" && "$ts" < "$since" ]]; then
      continue
    fi
    jq -c --arg file "$file" --arg ts "$ts" '
      . as $doc
      | {
          file: $file,
          timestamp: $ts,
          kind: (if ($file | test("/[0-9TZ]+-claude-")) then "claude" else "other" end),
          session_id: ($doc.session_id // null),
          is_error: ($doc.is_error // false),
          stop_reason: ($doc.stop_reason // $doc.terminal_reason // null),
          total_cost_usd: (($doc.total_cost_usd // 0) | tonumber),
          duration_ms: ($doc.duration_ms // null),
          model_usage: ($doc.modelUsage // {})
        }
    ' "$file" 2>/dev/null || true
  done < <(find "$calls_dir" -maxdepth 1 -name '*.json' -type f | sort) > "$tmp_calls"
fi

if [[ -d "$controller_dir" ]]; then
  while IFS= read -r file; do
    run_dir=$(dirname "$file")
    run_base=$(basename "$run_dir")
    ts=${run_base%%-*}
    if [[ -n "$since" && "$ts" < "$since" ]]; then
      continue
    fi
    jq -c --arg file "$file" --arg run_dir "$run_dir" '
      {
        file: $file,
        run_dir: $run_dir,
        review_output: (.review_output // null),
        codex_output: (.codex_output // null),
        codex_events: (.codex_events // null),
        risk_flags: (.risk_flags // []),
        has_review: ((.review_output // null) != null)
      }
    ' "$file" 2>/dev/null || true
  done < <(find "$controller_dir" -mindepth 2 -maxdepth 2 -name 'summary.json' -type f | sort) > "$tmp_controllers"
fi

if [[ "$json_output" -eq 1 ]]; then
  jq -n \
    --slurpfile calls "$tmp_calls" \
    --slurpfile controllers "$tmp_controllers" \
    --arg show_session_ids "$show_session_ids" '
    def redact_session:
      if . == null then null
      elif (length <= 12) then .
      else .[0:8] + "..." + .[-4:]
      end;
    ($show_session_ids == "1") as $raw_sessions
    |
    {
      calls: (
        $calls
        | map(
            if $raw_sessions or (.session_id == null) then .
            else . + {session_id: (.session_id | redact_session)}
            end
          )
      ),
      controllers: $controllers,
      totals: {
        call_count: ($calls | length),
        claude_call_count: ($calls | map(select(.kind == "claude")) | length),
        error_count: ($calls | map(select(.is_error == true)) | length),
        total_cost_usd: ($calls | map(.total_cost_usd) | add // 0),
        controller_run_count: ($controllers | length),
        controller_review_count: ($controllers | map(select(.has_review == true)) | length)
      },
      by_model: (
        $calls
        | map(.model_usage | to_entries[])
        | group_by(.key)
        | map({
            model: .[0].key,
            calls: length,
            cost_usd: (map(.value.costUSD // 0) | add // 0),
            input_tokens: (map(.value.inputTokens // 0) | add // 0),
            output_tokens: (map(.value.outputTokens // 0) | add // 0),
            cache_read_input_tokens: (map(.value.cacheReadInputTokens // 0) | add // 0),
            cache_creation_input_tokens: (map(.value.cacheCreationInputTokens // 0) | add // 0)
          })
      ),
      by_session: (
        $calls
        | map(select(.session_id != null))
        | group_by(.session_id)
        | map({
            session_id: (if $raw_sessions then .[0].session_id else (.[0].session_id | redact_session) end),
            calls: length,
            cost_usd: (map(.total_cost_usd) | add // 0),
            first_file: .[0].file,
            last_file: .[-1].file,
            errors: (map(select(.is_error == true)) | length)
          })
      )
    }'
  exit 0
fi

summary_args=(
  --calls-dir "$calls_dir"
  --controller-dir "$controller_dir"
  --json
)
if [[ -n "$since" ]]; then
  summary_args+=(--since "$since")
fi
if [[ "$show_session_ids" -eq 1 ]]; then
  summary_args+=(--show-session-ids)
fi
summary=$(scripts/dev/agent-collab-audit.sh "${summary_args[@]}")

printf 'Collaboration audit\n'
printf 'Calls dir: %s\n' "$calls_dir"
printf 'Controller dir: %s\n' "$controller_dir"
if [[ -n "$since" ]]; then
  printf 'Since: %s\n' "$since"
fi
printf '\nTotals\n'
printf '%s\n' "$summary" | jq -r '
  .totals
  | "- calls: \(.call_count)\n- Claude calls: \(.claude_call_count)\n- errored calls: \(.error_count)\n- recorded Claude cost: $\(.total_cost_usd | . * 10000 | round / 10000)\n- controller runs: \(.controller_run_count)\n- controller runs with review: \(.controller_review_count)"'

printf '\nBy model\n'
printf '%s\n' "$summary" | jq -r '
  if (.by_model | length) == 0 then
    "- none"
  else
    .by_model[]
    | "- \(.model): calls=\(.calls), cost=$\(.cost_usd | . * 10000 | round / 10000), input=\(.input_tokens), output=\(.output_tokens), cache_read=\(.cache_read_input_tokens), cache_create=\(.cache_creation_input_tokens)"
  end'

printf '\nBy session\n'
printf '%s\n' "$summary" | jq -r '
  if (.by_session | length) == 0 then
    "- none"
  else
    .by_session[]
    | "- \(.session_id): calls=\(.calls), cost=$\(.cost_usd | . * 10000 | round / 10000), errors=\(.errors)"
  end'
if [[ "$show_session_ids" -eq 0 ]]; then
  printf '\nSession ids are redacted. Re-run with --show-session-ids for local raw ids.\n'
fi
