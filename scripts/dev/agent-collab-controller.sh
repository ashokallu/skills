#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-collab-controller.sh --task <text> [options]
  scripts/dev/agent-collab-controller.sh --task-file <path> [options]
  scripts/dev/agent-collab-controller.sh --resume-run <run-dir> [options]

Options:
  --task <text>             User task to route through plan -> execute -> review.
  --task-file <path>        Read task text from a file.
  --title <title>           Used for artifact filenames.
  --claude-profile <name>   Claude planning/review profile. Default: architect.
  --review-claude-profile <name>
                           Claude review profile. Default: review.
  --claude-tool-mode <mode> Claude tool mode for plan/review: none, auto, or all. Default: none.
  --require-claude-vpn     Legacy/experimental: monitor VPN for Claude plan/review calls.
  --max-budget-usd <num>    Post-request stop threshold forwarded to each Claude call;
                            a final request can exceed it.
  --acknowledge-post-request-budget
                            Required for each Claude step; confirms the caller has
                            current authority for post-request overrun risk.
  --codex-model <model>     Optional Codex model override.
  --allow-write             Let Codex run with workspace-write sandbox.
  --skip-review             Stop after Codex execution.
  --resume-run <run-dir>    Resume an existing controller run directory.
  --review-output-lines <n> Codex output lines to include in Claude review. Default: 220.
  --timeout-sec <num>       Per-step timeout. Default: 1800.
  --help                    Show this help.

This is a minimal JSON-over-stdio controller:
  1. Claude plans with structured JSON.
  2. Codex executes the executor prompt and captures JSONL events.
  3. Claude reviews the Codex result unless --skip-review is set.

Artifacts are written under tmp/codex-claude/controller/, which is ignored by git.
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

task=""
task_file=""
title="collab-controller"
claude_profile="architect"
review_claude_profile="review"
claude_tool_mode="none"
require_claude_vpn="${AGENT_COLLAB_REQUIRE_CLAUDE_VPN:-0}"
max_budget_usd=""
acknowledge_post_request_budget=0
codex_model=""
codex_write=0
skip_review=0
resume_run=""
timeout_sec="${AGENT_COLLAB_CONTROLLER_TIMEOUT_SEC:-1800}"
review_output_lines="220"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) task=${2:-}; shift 2 ;;
    --task-file) task_file=${2:-}; shift 2 ;;
    --title) title=${2:-}; shift 2 ;;
    --claude-profile) claude_profile=${2:-}; shift 2 ;;
    --review-claude-profile) review_claude_profile=${2:-}; shift 2 ;;
    --claude-tool-mode) claude_tool_mode=${2:-}; shift 2 ;;
    --require-claude-vpn) require_claude_vpn=1; shift ;;
    --max-budget-usd) max_budget_usd=${2:-}; shift 2 ;;
    --acknowledge-post-request-budget) acknowledge_post_request_budget=1; shift ;;
    --codex-model) codex_model=${2:-}; shift 2 ;;
    --allow-write) codex_write=1; shift ;;
    --skip-review) skip_review=1; shift ;;
    --resume-run) resume_run=${2:-}; shift 2 ;;
    --review-output-lines) review_output_lines=${2:-}; shift 2 ;;
    --timeout-sec) timeout_sec=${2:-}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$task_file" ]]; then
  [[ -f "$task_file" ]] || die "--task-file does not exist: $task_file"
  task=$(sed 's/[[:space:]]*$//' "$task_file")
elif [[ -z "$task" && ! -t 0 ]]; then
  task=$(sed 's/[[:space:]]*$//')
fi

command -v jq >/dev/null 2>&1 || die "jq is required"
if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]]; then
  die "--timeout-sec must be a positive integer"
fi
case "$claude_tool_mode" in
  auto|none|all) ;;
  *) die "--claude-tool-mode must be auto, none, or all" ;;
esac
case "$require_claude_vpn" in
  0|1) ;;
  *) die "--require-claude-vpn must be 0 or 1 when set through AGENT_COLLAB_REQUIRE_CLAUDE_VPN" ;;
esac

root=$(repo_root)
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="collab-controller"
if [[ -n "$resume_run" ]]; then
  run_dir="$resume_run"
  [[ -d "$run_dir" ]] || die "--resume-run directory does not exist: $run_dir"
  if [[ "$title" == "collab-controller" ]]; then
    run_base=$(basename "$run_dir")
    if [[ "$run_base" =~ ^[0-9]{8}T[0-9]{6}Z-(.+)$ ]]; then
      slug=$(sanitize_slug "${BASH_REMATCH[1]}")
    fi
  fi
else
  [[ -n "$task" ]] || die "provide --task, --task-file, stdin, or --resume-run"
  timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
  run_dir="$root/tmp/codex-claude/controller/$timestamp-$slug"
fi
mkdir -p "$run_dir"

plan_prompt="$run_dir/plan-prompt.md"
plan_text="$run_dir/plan-response.md"
plan_json="$run_dir/plan.json"
plan_schema="$run_dir/plan.schema.json"
codex_output="$run_dir/codex-output.md"
codex_events="$run_dir/codex-events.jsonl"
review_prompt="$run_dir/review-prompt.md"
review_output="$run_dir/review-output.md"
summary_json="$run_dir/summary.json"
artifact_manifest="$run_dir/artifacts.md"
task_file_saved="$run_dir/task.md"
plan_done="$run_dir/.plan.done"
codex_done="$run_dir/.codex.done"
review_done="$run_dir/.review.done"

resume_hint() {
  local step=$1
  printf 'Controller step failed: %s\n' "$step" >&2
  printf 'Run directory: %s\n' "$run_dir" >&2
  printf 'Resume with: scripts/dev/agent-collab-controller.sh --resume-run %q --timeout-sec %q\n' "$run_dir" "$timeout_sec" >&2
}

if [[ -n "$resume_run" ]]; then
  [[ -f "$task_file_saved" ]] || die "cannot resume; missing $task_file_saved"
  task=$(sed 's/[[:space:]]*$//' "$task_file_saved")
else
  printf '%s\n' "$task" > "$task_file_saved"
fi

claude_call_args=(
  --tool-mode "$claude_tool_mode"
)
if [[ "$acknowledge_post_request_budget" -eq 1 ]]; then
  claude_call_args+=(--acknowledge-post-request-budget)
fi
if [[ "$require_claude_vpn" == "1" ]]; then
  claude_call_args+=(--require-vpn)
fi
if [[ -n "$max_budget_usd" ]]; then
  claude_call_args+=(--max-budget-usd "$max_budget_usd")
fi

if [[ ! -f "$plan_done" ]]; then
  cat > "$plan_prompt" <<EOF
Produce a minimal execution plan for Codex CLI for this project task.

Task:
$task
EOF

  cat > "$plan_schema" <<'EOF'
{
  "type": "object",
  "additionalProperties": false,
  "properties": {
    "executor_prompt": {
      "type": "string",
      "description": "Prompt for Codex CLI."
    },
    "review_prompt": {
      "type": "string",
      "description": "Prompt Claude should use after Codex runs."
    },
    "risk_flags": {
      "type": "array",
      "items": {"type": "string"}
    }
  },
  "required": ["executor_prompt", "review_prompt", "risk_flags"]
}
EOF

  if ! scripts/dev/agent-call-claude.sh \
    --profile "$claude_profile" \
    --title "$slug-plan" \
    --session-alias "$slug" \
    --timeout-sec "$timeout_sec" \
    "${claude_call_args[@]}" \
    --json-schema "$plan_schema" \
    --output "$plan_text" \
    --prompt-file "$plan_prompt" >/dev/null; then
    resume_hint "claude-plan"
    exit 1
  fi
fi

if ! jq -e . "$plan_text" > "$plan_json" 2>/dev/null; then
  die "Claude plan was not valid JSON; see $plan_text"
fi
touch "$plan_done"

executor_prompt=$(jq -r '.executor_prompt // empty' "$plan_json")
review_seed=$(jq -r '.review_prompt // empty' "$plan_json")
risk_flags=$(jq -r '.risk_flags // [] | map("- " + .) | join("\n")' "$plan_json")
[[ -n "$executor_prompt" ]] || die "Claude plan omitted executor_prompt"

write_artifact_manifest() {
  cat > "$artifact_manifest" <<EOF
# Collaboration Run Artifacts

Run directory:
$run_dir

Task:
$task_file_saved

Plan prompt:
$plan_prompt

Plan response:
$plan_text

Plan JSON:
$plan_json

Codex output:
$codex_output

Codex JSONL events:
$codex_events

Review prompt:
$review_prompt

Review output:
$review_output

Summary:
$summary_json

Notes:
- These paths are gitignored local artifacts and are part of the review context.
- Do not paste raw secrets, tokens, cookies, session IDs, private keys, or auth-state files into these artifacts.
EOF
}

write_artifact_manifest

codex_args=(
  --title "$slug-execute"
  --timeout-sec "$timeout_sec"
  --json-events
  --output "$codex_output"
  --events-output "$codex_events"
  --prompt "$executor_prompt"
)

if [[ -n "$codex_model" ]]; then
  codex_args+=(--model "$codex_model")
fi

if [[ "$codex_write" -eq 1 ]]; then
  codex_args+=(--allow-write)
fi

if [[ ! -f "$codex_done" ]]; then
  if ! scripts/dev/agent-call-codex.sh "${codex_args[@]}" >/dev/null; then
    resume_hint "codex-execute"
    exit 1
  fi
  touch "$codex_done"
fi

if [[ "$skip_review" -eq 0 ]]; then
  if [[ ! -f "$review_done" ]]; then
    codex_line_count=$(wc -l < "$codex_output" | tr -d ' ')
    truncation_note=""
    if [[ "$codex_line_count" -gt "$review_output_lines" ]]; then
      truncation_note="Codex output was truncated to ${review_output_lines} lines for review. Full output: $codex_output"
    fi

    cat > "$review_prompt" <<EOF
Review the Codex result for this project collaboration run.

Original task:
$task

Claude review seed:
$review_seed

Risk flags from plan:
${risk_flags:-None}

Local artifact manifest:
$artifact_manifest

Important: inspect the artifact paths above as part of the review. They are
gitignored, so a working-tree-only review misses required context.

Codex output:
$(sed -n "1,${review_output_lines}p" "$codex_output")

${truncation_note}

Return findings first. Include PASS, PASS_WITH_FINDINGS, FAIL, or BLOCKED.
EOF

    if ! scripts/dev/agent-call-claude.sh \
      --profile "$review_claude_profile" \
      --resume "alias:$slug" \
      --session-alias "$slug" \
      --title "$slug-review" \
      --timeout-sec "$timeout_sec" \
      "${claude_call_args[@]}" \
      --output "$review_output" \
      --context-file "$artifact_manifest" \
      --context-file "$plan_json" \
      --context-file "$codex_output" \
      --context-file "$codex_events" \
      --prompt-file "$review_prompt" >/dev/null; then
      resume_hint "claude-review"
      exit 1
    fi
    touch "$review_done"
  fi
fi

jq -n \
  --arg run_dir "$run_dir" \
  --arg plan "$plan_json" \
  --arg codex "$codex_output" \
  --arg codex_events "$codex_events" \
  --arg review "$review_output" \
  --arg artifacts "$artifact_manifest" \
  --slurpfile plan_doc "$plan_json" \
  --arg skipped "$skip_review" \
  '{run_dir:$run_dir, artifacts:$artifacts, plan:$plan, risk_flags:($plan_doc[0].risk_flags // []), codex_output:$codex, codex_events:$codex_events, review_output:(if $skipped == "1" then null else $review end)}' \
  > "$summary_json"

cat "$summary_json"
