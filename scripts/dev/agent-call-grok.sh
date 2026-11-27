#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly expected_grok_model='grok-4.6'
readonly profile_revision='brokered-selected-mcp-council-v18-grok43'
readonly original_grok_home="${GROK_HOME:-$HOME/.grok}"
readonly selected_mcp_servers='context7_remote,parallel-search'

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-call-grok.sh [options] --prompt-file <path>
  echo "<prompt>" | scripts/dev/agent-call-grok.sh [options]

Options:
  --prompt-file <path>     Read the prompt from a file.
  --context-file <path>    Append a non-secret local file. Repeatable.
  --title <title>          Used for the saved output filename.
  --output <path>          Write Grok's final text to this new path.
  --role <role>            reviewer, critic, contributor, or none. Default: reviewer.
  --allow-write            Required with --role contributor.
  --worktree-existing <path>
                           Required existing registered linked worktree for contributor.
  --model <name>           Pinned council model. Must be grok-4.6.
  --effort <level>         Optional effort: low, medium, high, xhigh, or max.
  --timeout-sec <num>      Broker/run wall-clock timeout (1-3600). Default: 900.
  --resume <id|alias:name> Resume one exact Grok session.
  --session-alias <name>   Create or resume a named wrapper-owned session.
  --lane <name>            Derive a Codex-thread-scoped session alias.
  --max-turns <num>        Bound main-agent model/tool-loop rounds (1-32). Default: 20.
  --answer-only            Reviewer/critic/none only. Remove every built-in tool,
                           subagent, and web surface so the model answers directly
                           from the prompt instead of spending its bounded turns
                           exploring. Use when the prompt already carries the
                           evidence. Not valid with --role contributor.
  --check                  Check the installed CLI capabilities without a model call.
  --help                   Show this help.

This is an explicitly selected headless Grok council route. Every run uses an
ephemeral Grok home with no user plugins or hooks and exactly two MCP servers:
parallel-search and context7_remote. Reviewer, critic, and none retain
normal analysis tools, Bash, built-in web, sessions, and subagents against a
read-only sanitized snapshot of Git-visible source. Contributor retains the
same toolset against a writable private snapshot and transfers only a bounded
post-success patch to one clean, existing, registered linked worktree selected
explicitly with --allow-write and --worktree-existing.

There is no --prompt option because prompt content must not enter process argv.
The wrapper owns permission, sandbox, extension, MCP, credential, session, and
worktree policy. There are no separate --allow-shell or --allow-web switches.
CLI releases are capability-checked and SHA-bound for each run; upgrades do not
require editing a version or binary-digest allowlist.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

common_checkout_root() {
  local common_dir
  common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  if [[ -n "$common_dir" && -d "$common_dir" ]]; then
    dirname "$common_dir"
  fi
}

sanitize_slug() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//' |
    cut -c1-80
}

is_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]]
}

is_sensitive_context_path() {
  local lower
  lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')

  case "$lower" in
    *.pem|*.key|*.p12|*.pfx|*/id_rsa|*/id_dsa|*/id_ecdsa|*/id_ed25519) return 0 ;;
    */.env|*/.env.*|.env|.env.*|*/.envrc|.envrc) return 0 ;;
    *auth-state.json*|*credentials*|*credential*|*secrets*|*secret*|*token*|*cookie*) return 0 ;;
  esac

  return 1
}

prompt_file=""
context_files=()
title="grok-review"
output=""
role="reviewer"
model="${AGENT_CALL_GROK_MODEL:-$expected_grok_model}"
effort="${AGENT_CALL_GROK_EFFORT:-}"
timeout_sec="${AGENT_CALL_GROK_TIMEOUT_SEC:-900}"
resume_session="${AGENT_CALL_GROK_RESUME:-}"
session_alias=""
lane=""
# Turn budget. The previous default of 8 with a ceiling of 9 was not chosen for
# this workload: reviewing roles on this repository routinely spent every turn
# inspecting source and exited at the cap with no artifact, costing a full
# re-dispatch each time. A budget only helps if it leaves room to explore AND
# answer, so the default now accommodates a source-checking review plus the
# reserved final turn, and the ceiling leaves headroom above it. The bound that
# actually matters for spend is the broker's cumulative provider byte budget
# below, which still scales with the turn count.
max_turns="${AGENT_CALL_GROK_MAX_TURNS:-20}"
grok_bin="${AGENT_CALL_GROK_BIN:-grok}"
allow_write=0
answer_only=0
check_only=0
worktree_existing=""
fake_credential_canary="${AGENT_CALL_GROK_FAKE_CREDENTIAL_CANARY:-0}"
worktree_lock=""
shared_lock_dir=""
worktree_lock_owned=0

cleanup_worktree_lock() {
  if [[ "$worktree_lock_owned" -eq 1 && -n "$worktree_lock" && -f "$worktree_lock" && ! -L "$worktree_lock" ]]; then
    rm -f -- "$worktree_lock"
    rmdir -- "$shared_lock_dir" 2>/dev/null || true
    worktree_lock_owned=0
  fi
}
trap cleanup_worktree_lock EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file|--context-file|--title|--output|--role|--model|--effort|--reasoning-effort|--timeout-sec|--resume|--session-alias|--lane|--max-turns|--worktree-existing)
      [[ $# -ge 2 ]] || die "$1 requires a value"
      case "$1" in
        --prompt-file) prompt_file=$2 ;;
        --context-file) context_files+=("$2") ;;
        --title) title=$2 ;;
        --output) output=$2 ;;
        --role) role=$2 ;;
        --model) model=$2 ;;
        --effort|--reasoning-effort) effort=$2 ;;
        --timeout-sec) timeout_sec=$2 ;;
        --resume) resume_session=$2 ;;
        --session-alias) session_alias=$2 ;;
        --lane) lane=$2 ;;
        --max-turns) max_turns=$2 ;;
        --worktree-existing) worktree_existing=$2 ;;
      esac
      shift 2
      ;;
    --allow-write)
      allow_write=1
      shift
      ;;
    --answer-only)
      answer_only=1
      shift
      ;;
    --check)
      check_only=1
      shift
      ;;
    --allow-shell|--allow-web|--always-approve)
      die "$1 is wrapper-owned; select the contributor triplet for source writes"
      ;;
    --prompt)
      die "--prompt is unavailable because prompt content must not enter process argv; use --prompt-file or stdin"
      ;;
    --agent|--allow-sensitive-context|--allow-unsafe-latest|--no-direnv|--no-subagents)
      die "$1 is not part of the selected-MCP council interface"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
done

case "$fake_credential_canary" in
  0|1) ;;
  *) die "AGENT_CALL_GROK_FAKE_CREDENTIAL_CANARY must be 0 or 1" ;;
esac
if [[ "$fake_credential_canary" == 1 && -n "$resume_session$session_alias$lane" ]]; then
  die "the fake-credential canary must start a fresh unaliased session"
fi

case "$role" in
  reviewer|critic|none)
    [[ "$allow_write" -eq 0 && -z "$worktree_existing" ]] ||
      die "--allow-write and --worktree-existing require --role contributor"
    ;;
  contributor)
    [[ "$allow_write" -eq 1 && -n "$worktree_existing" ]] ||
      die "--role contributor requires --allow-write and --worktree-existing <path>"
    [[ "$answer_only" -eq 0 ]] ||
      die "--answer-only is unavailable for --role contributor, which must retain its tools"
    ;;
  *) die "--role must be reviewer, critic, contributor, or none" ;;
esac
[[ "$model" == "$expected_grok_model" ]] ||
  die "--model must remain $expected_grok_model for the admitted council profile"
case "$effort" in
  ""|low|medium|high|xhigh|max) ;;
  *) die "--effort must be one of low, medium, high, xhigh, or max" ;;
esac
if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -lt 1 ]] || [[ "$timeout_sec" -gt 3600 ]]; then
  die "--timeout-sec must be an integer from 1 through 3600"
fi
if ! [[ "$max_turns" =~ ^[0-9]+$ ]] || [[ "$max_turns" -lt 1 ]] || [[ "$max_turns" -gt 32 ]]; then
  die "--max-turns must be an integer from 1 through 32"
fi
if [[ -n "$lane" && -n "$session_alias" ]]; then
  die "use --lane OR --session-alias, not both"
fi
if [[ -n "$lane" && -n "$resume_session" ]]; then
  die "use --lane OR --resume, not both"
fi
if [[ -n "$session_alias" && -n "$resume_session" ]]; then
  die "use --session-alias OR --resume, not both"
fi
if [[ -n "$lane" ]]; then
  [[ -n "${CODEX_THREAD_ID:-}" ]] || die "--lane requires CODEX_THREAD_ID"
  lane=$(sanitize_slug "$lane")
  [[ -n "$lane" ]] || die "--lane must contain a safe filename character"
  session_alias=$(sanitize_slug "codex-thread-$CODEX_THREAD_ID-$lane")
elif [[ -z "$session_alias" && -z "$resume_session" && -n "${CODEX_THREAD_ID:-}" ]]; then
  session_alias=$(sanitize_slug "codex-thread-$CODEX_THREAD_ID")
fi
if [[ -n "$session_alias" ]]; then
  session_alias=$(sanitize_slug "$session_alias")
  [[ -n "$session_alias" ]] || die "--session-alias must contain a safe filename character"
fi

command -v "$grok_bin" >/dev/null 2>&1 || die "Grok CLI not found on PATH: $grok_bin"
grok_path=$(readlink -f "$(command -v "$grok_bin")")
[[ -x "$grok_path" ]] || die "Grok CLI is not executable: $grok_path"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required for Grok per-run identity"
command -v timeout >/dev/null 2>&1 || die "timeout is required for Grok capability checks"
actual_grok_sha256=$(sha256sum "$grok_path" | awk '{print $1}')
actual_grok_version=$(timeout 10 "$grok_path" --version 2>/dev/null) || die "Grok version probe failed"
[[ "$actual_grok_version" =~ ^grok[[:space:]][0-9]+\.[0-9]+\.[0-9]+ ]] || die "Grok version probe returned malformed output"
# Hidden switches are parser-checked together with --help. Visible capabilities
# are matched as complete tokens, so --session-id-extra cannot satisfy a gate.
grok_help=$(timeout 10 "$grok_path" --no-leader --no-auto-update --help 2>/dev/null) ||
  die "Grok CLI capability probe failed"
for capability in --cwd --model --output-format --verbatim --always-approve --max-turns \
  --prompt-file --session-id --resume --reasoning-effort --tools --no-subagents --disable-web-search; do
  grep -Eq -- "(^|[[:space:],])${capability}([[:space:],=<]|$)" <<<"$grok_help" ||
    die "Grok CLI lacks required capability: $capability"
done
timeout 10 "$grok_path" inspect --json --help >/dev/null 2>&1 || die "Grok inspect --json capability probe failed"
timeout 10 "$grok_path" mcp list --json --help >/dev/null 2>&1 || die "Grok MCP JSON capability probe failed"
[[ "$(sha256sum "$grok_path" | awk '{print $1}')" == "$actual_grok_sha256" ]] ||
  die "Grok binary changed during capability preflight"
if [[ "$check_only" -eq 1 ]]; then
  jq -n --arg version "$actual_grok_version" --arg sha256 "$actual_grok_sha256" \
    '{status:"ready",cli_policy:"current-with-capability-probes",version:$version,sha256:$sha256}'
  exit 0
fi

root=$(repo_root)
root=$(realpath -e -- "$root") || die "calling repository root could not be resolved"
contract_root="$root"
common_root=$(common_checkout_root)
if [[ -n "$common_root" ]]; then
  common_root=$(realpath -e -- "$common_root") || die "common checkout root could not be resolved"
fi
if [[ -n "$common_root" && -f "$common_root/AGENTS.md" && -f "$common_root/repo.md" ]]; then
  contract_root="$common_root"
fi
run_root="$root"
profile='brokered-selected-mcp-read-only-council'
profile_worktree=""
if [[ "$role" == contributor ]]; then
  command -v flock >/dev/null 2>&1 || die "flock is required for the contributor single-writer contract"
  [[ -d "$worktree_existing" ]] || die "--worktree-existing must name an existing directory"
  profile_worktree=$(realpath -e -- "$worktree_existing") ||
    die "--worktree-existing could not be resolved: $worktree_existing"
  target_root=$(git -C "$profile_worktree" rev-parse --show-toplevel 2>/dev/null || true)
  [[ -n "$target_root" ]] || die "--worktree-existing is not a Git worktree"
  target_root=$(realpath -e -- "$target_root") || die "contributor worktree root could not be resolved"
  [[ "$target_root" == "$profile_worktree" ]] ||
    die "--worktree-existing must name the exact worktree root"
  [[ "$profile_worktree" != "$root" && "$profile_worktree" != "$common_root" ]] ||
    die "contributor worktree must be distinct from the calling and common checkouts"
  caller_common_dir=$(git -C "$root" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  target_common_dir=$(git -C "$profile_worktree" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)
  [[ -n "$caller_common_dir" && -n "$target_common_dir" ]] ||
    die "could not resolve Git common directories for contributor worktree"
  caller_common_dir=$(realpath -e -- "$caller_common_dir") || die "calling Git common directory could not be resolved"
  target_common_dir=$(realpath -e -- "$target_common_dir") || die "target Git common directory could not be resolved"
  [[ "$target_common_dir" == "$caller_common_dir" ]] ||
    die "contributor worktree must be registered to the calling repository"
  registered=0
  while IFS= read -r registered_worktree; do
    if [[ "$registered_worktree" == "$profile_worktree" ]]; then
      registered=1
      break
    fi
  done < <(git -C "$root" worktree list --porcelain | sed -n 's/^worktree //p')
  [[ "$registered" -eq 1 ]] || die "contributor worktree is not registered to the calling repository"
  run_root="$profile_worktree"
  profile='brokered-selected-mcp-contributor'
fi
if [[ "$fake_credential_canary" == 1 ]]; then
  profile+="-fake-credential-canary"
fi
calls_dir="$root/tmp/codex-claude/calls"
state_dir="$root/tmp/codex-claude/state"
if [[ "$run_root" == "$root" ]] && ! git -C "$root" check-ignore -q -- tmp/codex-claude; then
  die "tmp/codex-claude must remain Git-ignored before a Grok consultation snapshot is created"
fi
for artifact_dir in "$root/tmp" "$root/tmp/codex-claude" "$calls_dir" "$state_dir"; do
  [[ ! -L "$artifact_dir" ]] || die "Grok artifact directory must not be a symlink: $artifact_dir"
done
mkdir -p "$calls_dir" "$state_dir"
command -v jq >/dev/null 2>&1 || die "jq is required for Grok session metadata"
if [[ "$role" == contributor ]]; then
  shared_lock_dir="/tmp/codex-agent-call-grok-$(id -u)"
  [[ ! -L "$shared_lock_dir" ]] || die "shared Grok lock directory must not be a symlink"
  if [[ ! -d "$shared_lock_dir" ]]; then
    mkdir -m 700 "$shared_lock_dir" 2>/dev/null || [[ -d "$shared_lock_dir" ]] ||
      die "shared Grok lock directory could not be created"
  fi
  [[ "$(stat -c '%u:%a' "$shared_lock_dir")" == "$(id -u):700" ]] ||
    die "shared Grok lock directory has unsafe ownership or mode"
  worktree_lock_key=$(printf '%s\n%s' "$target_common_dir" "$profile_worktree" | sha256sum | awk '{print $1}')
  worktree_lock="$shared_lock_dir/contributor-$worktree_lock_key.lock"
  [[ ! -L "$worktree_lock" ]] || die "Grok contributor lock must not be a symlink"
  exec 9>"$worktree_lock"
  flock -n 9 || die "another Grok contributor owns this worktree"
  worktree_lock_owned=1
fi

if [[ -n "$session_alias" ]]; then
  session_alias_file="$state_dir/grok-session-$session_alias"
  [[ ! -L "$session_alias_file" ]] || die "Grok session alias must not be a symlink: $session_alias"
  if [[ -f "$session_alias_file" ]]; then
    resume_session=$(sed 's/[[:space:]]*$//' "$session_alias_file")
  fi
fi
if [[ -n "$resume_session" ]]; then
  case "$resume_session" in
    alias:*)
      alias_name=$(sanitize_slug "${resume_session#alias:}")
      [[ -n "$alias_name" ]] || die "--resume alias:<name> requires a safe alias"
      alias_file="$state_dir/grok-session-$alias_name"
      [[ ! -L "$alias_file" ]] || die "Grok session alias must not be a symlink: $alias_name"
      [[ -f "$alias_file" ]] || die "No Grok session alias found: $alias_name"
      resume_session=$(sed 's/[[:space:]]*$//' "$alias_file")
      ;;
  esac
  is_uuid "$resume_session" || die "--resume accepts only an exact UUID or alias:<name>"
  recorded_session=${resume_session,,}
  session_metadata="$state_dir/grok-session-$recorded_session.json"
  [[ ! -L "$session_metadata" ]] || die "Grok session metadata must not be a symlink: $recorded_session"
  [[ -f "$session_metadata" ]] ||
    die "No wrapper-owned metadata exists for Grok session: $recorded_session"
  jq -e \
    --arg session "$recorded_session" \
    --arg profile "$profile" \
    --arg worktree "$profile_worktree" \
    --arg model "$expected_grok_model" \
    --arg profile_revision "$profile_revision" \
    '.session == $session and .profile == $profile and .profile_revision == $profile_revision and
     .worktree == $worktree and .isolation == true and
     .requested_model == $model' \
    "$session_metadata" >/dev/null ||
    die "Grok session metadata does not match the admitted council profile: $recorded_session"
  new_session=0
else
  [[ -r /proc/sys/kernel/random/uuid ]] || die "kernel UUID source is unavailable"
  recorded_session=$(</proc/sys/kernel/random/uuid)
  is_uuid "$recorded_session" || die "kernel UUID source returned an invalid UUID"
  new_session=1
fi
if [[ "$role" == contributor && "$new_session" -eq 1 ]]; then
  [[ -z "$(git -C "$profile_worktree" status --porcelain --untracked-files=all)" ]] ||
    die "contributor worktree must be clean when starting a new session"
fi

if [[ -n "$prompt_file" ]]; then
  [[ ! -L "$prompt_file" ]] || die "--prompt-file must not be a symlink: $prompt_file"
  [[ -f "$prompt_file" ]] || die "--prompt-file does not exist: $prompt_file"
  prompt=$(sed 's/[[:space:]]*$//' "$prompt_file")
elif [[ ! -t 0 ]]; then
  prompt=$(sed 's/[[:space:]]*$//')
else
  prompt=""
fi
[[ -n "$prompt" ]] || die "provide --prompt-file or stdin"

for context_file in "${context_files[@]}"; do
  [[ ! -L "$context_file" ]] || die "--context-file must not be a symlink: $context_file"
  [[ -f "$context_file" ]] || die "--context-file does not exist: $context_file"
  resolved_context_file=$(realpath -e -- "$context_file") ||
    die "--context-file could not be resolved: $context_file"
  if is_sensitive_context_path "$context_file" || is_sensitive_context_path "$resolved_context_file"; then
    die "--context-file looks secret-bearing and is not accepted: $context_file"
  fi
done

if [[ "${#context_files[@]}" -gt 0 ]]; then
  context_block=$'\n\n## Explicit Local Context Files\n'
  for context_file in "${context_files[@]}"; do
    context_block+=$'\n### File: '"$context_file"$'\n```text\n'
    context_block+="$(sed 's/[[:space:]]*$//' "$context_file")"
    context_block+=$'\n```\n'
  done
  prompt+="$context_block"
fi

contract_block=""
for contract_file in AGENTS.md repo.md; do
  if [[ ! -f "$root/$contract_file" && -f "$contract_root/$contract_file" ]]; then
    contract_block+=$'\n### File: '"$contract_file"$' from canonical checkout\n```text\n'
    contract_block+="$(sed 's/[[:space:]]*$//' "$contract_root/$contract_file")"
    contract_block+=$'\n```\n'
  fi
done
if [[ -n "$contract_block" ]]; then
  prompt+=$'\n\n## Canonical Repo Contract Files\n'
  prompt+="$contract_block"
fi

# The main-agent loop is bounded by --max-turns. A reviewing role that spends
# every turn inspecting source exits at the cap with no artifact, which the
# capability ledger records as a prompt/turn-budget result rather than a CLI or
# login failure. State the budget so the final turn is reserved for the answer.
turn_budget_instruction="You have at most $max_turns main-agent tool-loop turns for this request. Budget them: reserve your final turn to write the complete answer. An exploration log, a partial inspection, or a promise to continue is not an acceptable result. If the budget runs short, answer from what you already have and name the gaps you did not close."

case "$role" in
  reviewer)
    role_instruction="Act as a project reviewer. Stay model-tool read-only. Return findings first with concrete file/line evidence. If there are no findings, say PASS and name validation gaps.
$turn_budget_instruction"
    ;;
  critic)
    role_instruction="Act as a project critic. Stay model-tool read-only. Challenge value, scope, correctness, risk, verification, and rollout readiness.
$turn_budget_instruction"
    ;;
  contributor)
    role_instruction="Act as a bounded project contributor. Work only inside the assigned linked worktree. You may analyze, edit, run focused shell checks, use built-in web and the selected MCP tools, and delegate bounded subagent work. Do not mutate shared external systems, expose credentials, publish Git state, or claim evidence you did not observe."
    ;;
  none)
    role_instruction="Answer directly as a Grok council member. The wrapper supplies a read-only sanitized snapshot of Git-visible source for this role, while normal analysis tools remain available.
$turn_budget_instruction"
    ;;
esac

if [[ "$answer_only" -eq 1 ]]; then
  role_instruction="$role_instruction
Answer-only mode: every built-in tool, subagent, and web surface is removed for this call. Do not claim you will read a file, search the repository, or verify something with a tool; you cannot. Answer directly and completely from the prompt content in your first response. Where you would have checked a source file, state the assumption you are relying on and continue."
fi

collab_prompt=$(cat <<EOF
You are Grok CLI collaborating with Codex in the project repository.
AGENTS.md and repo.md are the shared contract. The configured host may start
no user plugins or hooks and exactly the selected MCP servers. Use the normal
toolset within the selected sandbox and assigned ownership. Do not expose
credentials, mutate shared external systems, publish Git state, or take final
validation-verdict ownership.
Keep secrets, cookies, auth state, tokens, private keys, .env files, and browser
auth files out of responses.

$role_instruction

Peer request:
$prompt
EOF
)

timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="grok-review"
if [[ -z "$output" ]]; then
  output="$calls_dir/$timestamp-grok-$slug.md"
fi
[[ ! -e "$output" && ! -L "$output" ]] || die "refusing to overwrite existing output: $output"
stderr_output="${output%.*}.stderr.log"
if [[ "$stderr_output" == "$output" ]]; then
  stderr_output="$output.stderr.log"
fi
[[ ! -e "$stderr_output" && ! -L "$stderr_output" ]] || die "refusing to overwrite existing stderr output: $stderr_output"

broker_audit_output="$output.broker.jsonl"
[[ ! -e "$broker_audit_output" && ! -L "$broker_audit_output" ]] ||
  die "refusing to overwrite existing broker audit: $broker_audit_output"
failure_output="$output.failed"
[[ ! -e "$failure_output" && ! -L "$failure_output" ]] ||
  die "refusing to overwrite existing failed-session evidence: $failure_output"
broker_audit=""
prompt_tmp=""
run_pid=""
run_home=""
broker_socket_dir=""
broker_pid=""
stop_broker() {
  if [[ -n "$broker_pid" ]]; then
    kill -TERM "$broker_pid" 2>/dev/null || true
    wait "$broker_pid" 2>/dev/null || true
    broker_pid=""
  fi
}
cleanup() {
  stop_broker
  if [[ -n "$broker_audit" && -f "$broker_audit" ]]; then
    (set -o noclobber; cat "$broker_audit" >"$broker_audit_output") || true
  fi
  if [[ -n "$prompt_tmp" && ( -e "$prompt_tmp" || -L "$prompt_tmp" ) ]]; then
    rm -f -- "$prompt_tmp"
  fi
  if [[ -n "$run_home" && "$run_home" == "$state_dir"/.grok-run.* && -d "$run_home" ]]; then
    rm -rf -- "$run_home"
  fi
  if [[ -n "$broker_socket_dir" && "$broker_socket_dir" == /tmp/codex-grok-socket.* && -d "$broker_socket_dir" ]]; then
    rm -rf -- "$broker_socket_dir"
  fi
  cleanup_worktree_lock
}
terminate() {
  if [[ -n "$run_pid" ]]; then
    kill -TERM "$run_pid" 2>/dev/null || true
  fi
  if [[ -n "$broker_pid" ]]; then
    kill -TERM "$broker_pid" 2>/dev/null || true
  fi
  exit 143
}
trap cleanup EXIT
trap terminate HUP INT TERM

prompt_tmp=$(mktemp "$state_dir/.grok-prompt.XXXXXX")
chmod 600 "$prompt_tmp"
printf '%s\n' "$collab_prompt" >"$prompt_tmp"

run_home=$(mktemp -d "$state_dir/.grok-run.XXXXXX")
chmod 700 "$run_home"
child_home="$run_home/home"
child_tmp="$run_home/tmp"
git_view="$run_home/git"
mkdir -m 700 "$child_home" "$child_tmp" "$git_view"
run_config="$child_home/config.toml"
run_secrets="$run_home/secret-values"

for required_command in bwrap node git socat tar; do
  command -v "$required_command" >/dev/null 2>&1 || die "$required_command is required for the brokered Grok profile"
done
[[ -f "$original_grok_home/auth.json" && ! -L "$original_grok_home/auth.json" ]] ||
  die "Grok provider auth must exist as a regular non-symlink file in the configured Grok home"
[[ -n "${PARALLEL_SEARCH_API_TOKEN:-}" && -n "${CONTEXT7_API_KEY:-}" ]] ||
  die "selected MCP preflight requires PARALLEL_SEARCH_API_TOKEN and CONTEXT7_API_KEY"


actual_git_dir=$(git -C "$run_root" rev-parse --path-format=absolute --git-dir)
actual_git_dir=$(realpath -e -- "$actual_git_dir") || die "selected Git worktree metadata could not be resolved"
actual_git_common=$(git -C "$run_root" rev-parse --path-format=absolute --git-common-dir)
actual_git_common=$(realpath -e -- "$actual_git_common") || die "selected Git common metadata could not be resolved"

git_metadata_digest() {
  local metadata_path
  {
    for metadata_path in \
      "$actual_git_dir/HEAD" "$actual_git_dir/index" "$actual_git_dir/commondir" \
      "$actual_git_dir/gitdir" "$actual_git_common/config" "$actual_git_common/packed-refs" \
      "$actual_git_common/shallow" "$actual_git_common/objects/info/alternates"; do
      if [[ -f "$metadata_path" && ! -L "$metadata_path" ]]; then
        printf '%s\0' "$metadata_path"
      fi
    done
    if [[ -d "$actual_git_common/refs" ]]; then
      find "$actual_git_common/refs" -type f -print0
    fi
  } | sort -z | xargs -0 -r sha256sum | sha256sum | awk '{print $1}'
}

host_git_digest_before=$(git_metadata_digest)
git_worktree_view="$git_view/worktree"
git_common_view="$git_view/common"
git_extract_view="$run_home/git-extract"
mkdir -p "$git_worktree_view" "$git_common_view/objects" "$git_common_view/refs"
[[ -f "$actual_git_dir/index" && ! -L "$actual_git_dir/index" ]] ||
  die "selected Git metadata is missing a regular index"
selected_head_oid=$(git -C "$run_root" rev-parse --verify 'HEAD^{commit}') ||
  die "selected Git HEAD commit could not be resolved"
[[ "$selected_head_oid" =~ ^[0-9a-f]{40}$ ]] || die "selected Git HEAD is not a full SHA-1 commit"
printf '%s\n' "$selected_head_oid" >"$git_worktree_view/HEAD"
cp -- "$actual_git_dir/index" "$git_worktree_view/index"
printf '/git/common\n' >"$git_worktree_view/commondir"
printf '/workspace/.git\n' >"$git_worktree_view/gitdir"
cat >"$git_common_view/config" <<'GITCONFIG'
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = false
GITCONFIG
if find "$git_view" -type l -print -quit | grep -q .; then
  die "selected Git metadata contains a symlink"
fi
git_pointer="$run_home/workspace.git"
printf 'gitdir: /git/worktree\n' >"$git_pointer"
chmod -R u=rwX,go= "$git_view"
chmod 600 "$git_pointer"

workspace_snapshot="$run_home/workspace"
workspace_files="$run_home/workspace-files"
mkdir -m 700 "$workspace_snapshot"
git -C "$run_root" ls-files -z --cached --others --exclude-standard >"$workspace_files"
while IFS= read -r -d '' workspace_path; do
  [[ -n "$workspace_path" && "$workspace_path" != /* && "$workspace_path" != .git &&
    "$workspace_path" != .git/* && "$workspace_path" != .. && "$workspace_path" != ../* &&
    "$workspace_path" != */../* && "$workspace_path" != */.. ]] ||
    die "Git-visible workspace inventory contains an unsafe path"
  workspace_source="$run_root/$workspace_path"
  [[ -f "$workspace_source" || -L "$workspace_source" ]] ||
    die "Git-visible workspace inventory contains a missing or special file: $workspace_path"
done <"$workspace_files"

workspace_guard_digest() {
  {
    git -C "$run_root" status --porcelain=v2 -z --untracked-files=all
    while IFS= read -r -d '' workspace_path; do
      workspace_source="$run_root/$workspace_path"
      printf '%s\0' "$workspace_path"
      stat -c '%f:%s\0' -- "$workspace_source"
      if [[ -L "$workspace_source" ]]; then
        readlink -- "$workspace_source"
      else
        sha256sum -- "$workspace_source"
      fi
    done <"$workspace_files"
  } | sha256sum | awk '{print $1}'
}

host_workspace_digest_before=$(workspace_guard_digest)
(
  cd "$run_root"
  tar --null --no-recursion --files-from="$workspace_files" -cf -
) | tar -C "$workspace_snapshot" -xf - ||
  die "Git-visible workspace snapshot could not be materialized"
[[ "$(workspace_guard_digest)" == "$host_workspace_digest_before" ]] ||
  die "selected workspace changed while its sanitized snapshot was created"
if find "$workspace_snapshot" \( -type b -o -type c -o -type p -o -type s \) -print -quit | grep -q .; then
  die "Git-visible workspace snapshot contains a special file"
fi
if [[ -d "$run_root/.git" ]]; then
  mkdir "$workspace_snapshot/.git"
else
  : >"$workspace_snapshot/.git"
fi
git init --bare -q "$git_extract_view"
git --git-dir="$git_extract_view" config core.bare false
git --git-dir="$git_extract_view" --work-tree="$workspace_snapshot" add -A -- .
workspace_baseline_tree=$(git --git-dir="$git_extract_view" write-tree)

broker_script="$run_home/broker.mjs"
broker_ready="$run_home/broker-ready.json"
# Linux Unix socket addresses are limited to 107 bytes. Keep this private
# transport outside potentially deep checkout paths; the EXIT trap owns it.
broker_socket_dir=$(mktemp -d /tmp/codex-grok-socket.XXXXXX)
chmod 700 "$broker_socket_dir"
broker_socket="$broker_socket_dir/broker.sock"
cat >"$broker_script" <<'NODE'
import http from 'node:http';
import fs from 'node:fs';

const started = Date.now();
const lifetimeMs = Number(process.env.BROKER_LIFETIME_MS);
if (!Number.isSafeInteger(lifetimeMs) || lifetimeMs <= 0) throw new Error('invalid broker lifetime');
const maxTurns = Number(process.env.BROKER_MAX_TURNS);
const MAX_TURNS_CEILING = 32;
if (!Number.isSafeInteger(maxTurns) || maxTurns < 1 || maxTurns > MAX_TURNS_CEILING) {
  throw new Error('invalid broker turn limit');
}
const MiB = 1024 * 1024;
// The first model request may use the full per-request allowance. Each selected
// round adds 512 KiB for bounded repeated-context and auxiliary request growth.
// The ceiling is derived from the turn ceiling rather than written as a literal,
// so raising one can never silently outgrow the other.
const providerRequestBytes = 2 * MiB + maxTurns * 512 * 1024;
if (!Number.isSafeInteger(providerRequestBytes) ||
    providerRequestBytes > 2 * MiB + MAX_TURNS_CEILING * 512 * 1024) {
  throw new Error('invalid provider request budget');
}
const limits = {
  requestBody: 2 * MiB,
  providerRequestBytes,
  remoteRequestBody: 512 * 1024,
  remoteRequestBytes: 2 * MiB,
  responseBytes: 20 * MiB,
  remoteResponseBody: 1 * MiB,
  remoteResponseBytes: 4 * MiB,
  // Scale with the turn budget rather than standing as an independent literal.
  // The old pair (8 turns, 12 provider requests) happened to be consistent, so
  // raising only maxTurns made the larger budget unreachable: a 20-turn run was
  // rejected 429 "provider request budget exceeded" at the 13th request. Each
  // turn may need a model call plus an auxiliary request, with headroom for the
  // initial model listing and responses probe.
  providerRequests: maxTurns + Math.ceil(maxTurns / 2) + 4,
  remoteRequests: 2 * (maxTurns + Math.ceil(maxTurns / 2) + 4),
  toolsPerServer: 8,
  maxTurns,
  lifetimeMs,
};
const usage = {
  request: 0,
  requestAccepted: 0,
  requestRejected: 0,
  providerRequest: 0,
  remoteRequest: 0,
  response: 0,
  providerResponse: 0,
  remoteResponse: 0,
  provider: 0,
  remote: 0,
  tools: { parallel: 0, context7: 0 },
};
let requestSequence = 0;
function audit(event) {
  fs.appendFileSync(process.env.BROKER_AUDIT_FILE,
    `${JSON.stringify({ elapsedMs: Date.now() - started, ...event })}\n`, { mode: 0o600 });
}
const auth = JSON.parse(fs.readFileSync(process.env.PROVIDER_AUTH_FILE, 'utf8'));
let providerKey = '';
function findKey(value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    if (key === 'key' && typeof child === 'string' && child.length >= 8 && !providerKey) providerKey = child;
    else findKey(child);
  }
}
findKey(auth);
if (!providerKey) throw new Error('provider credential unavailable');

function transportCategory(error) {
  const causeName = error?.cause?.name;
  const causeCode = error?.cause?.code;
  if (error?.name === 'TimeoutError' || error?.name === 'AbortError') return 'deadline_or_abort';
  if ((typeof causeCode === 'string' && causeCode.startsWith('Z_')) || causeName === 'ZlibError') {
    return 'compressed_body_decode';
  }
  if (causeCode === 'UND_ERR_SOCKET' || causeName === 'SocketError') return 'upstream_socket_closed';
  if (causeName === 'HTTPParserError') return 'upstream_http_framing';
  return 'unclassified_transport';
}

function normalizedContentCoding(value) {
  if (!value) return null;
  const coding = value.split(',', 1)[0].trim().toLowerCase();
  return new Set(['gzip', 'deflate', 'br', 'identity']).has(coding) ? coding : 'other';
}

async function bodyBytes(request, retainLimit) {
  const chunks = [];
  let bytes = 0;
  for await (const chunk of request.iterator({ destroyOnReturn: false })) {
    bytes += chunk.length;
    usage.request += chunk.length;
    // Drain and count the full rejected local body without retaining an
    // attacker-controlled unbounded buffer. No upstream request has started.
    if (bytes <= retainLimit) chunks.push(chunk);
  }
  return { body: bytes <= retainLimit ? Buffer.concat(chunks) : null, bytes };
}

function routeFor(pathname) {
  if (['/provider/v1/models', '/provider/v1/responses', '/provider/v1/chat/completions'].includes(pathname)) {
    return { kind: 'provider', upstream: `https://cli-chat-proxy.grok.com/${pathname.slice('/provider/'.length)}` };
  }
  if (pathname === '/parallel' || pathname === '/parallel/') {
    return { kind: 'parallel', upstream: 'https://search-mcp.parallel.ai/mcp' };
  }
  if (pathname === '/context7' || pathname === '/context7/') {
    return { kind: 'context7', upstream: 'https://mcp.context7.com/mcp' };
  }
  return null;
}

const server = http.createServer(async (request, response) => {
  const requestId = ++requestSequence;
  let requestBytes = 0;
  let responseBytes = 0;
  let route;
  let pathname = null;
  let phase = 'request_headers';
  let upstreamStatus = null;
  let upstreamHeaderNames = [];
  let downstreamStatus = null;
  let forwardedHeaderNames = [];
  let contentCoding = null;
  let terminalRecorded = false;
  let downstreamClosed = false;
  let downstreamClosePhase = null;
  let remoteMessages = [];
  let remoteToolCalls = 0;
  const downstreamAbortController = new AbortController();
  const requestHeaderNames = Object.keys(request.headers).sort();
  response.once('close', () => {
    if (terminalRecorded || response.writableEnded) return;
    downstreamClosed = true;
    downstreamClosePhase = phase;
    downstreamAbortController.abort();
  });
  const terminal = (outcome, terminalReason, reason, detail = {}) => {
    if (terminalRecorded) return;
    terminalRecorded = true;
    audit({ event: 'request_terminal', outcome, terminalReason, reason, requestId,
      route: route?.kind || null, path: pathname, phase, status: downstreamStatus,
      upstreamStatus, requestBytes, responseBytes, requestHeaderNames,
      upstreamHeaderNames, forwardedHeaderNames,
      downstreamHeadersSent: response.headersSent, downstreamClosed,
      downstreamClosePhase, contentCoding, ...detail });
  };
  const rejectRequest = (status, message, detail = {}) => {
    downstreamStatus = status;
    forwardedHeaderNames = ['connection', 'content-type'];
    const terminalReason = route?.kind === 'provider' ? 'broker_rejected'
      : route ? 'broker_remote_rejected' : 'broker_probe_rejected';
    audit({ event: 'rejected', status, reason: message, requestId,
      route: route?.kind || null, path: pathname, phase, requestBytes, ...detail });
    terminal('rejected', terminalReason, message, detail);
    if (!response.headersSent) {
      response.writeHead(status, { 'content-type': 'application/json', connection: 'close' });
      response.end(JSON.stringify({ error: message }));
    } else {
      response.destroy();
    }
  };
  const failRequest = (status, terminalReason, reason, detail = {}) => {
    if (!response.headersSent) {
      downstreamStatus = status;
      forwardedHeaderNames = ['connection', 'content-type'];
    }
    const category = detail.transportCategory || null;
    audit({ event: 'request_failed', requestId, route: route?.kind || null,
      path: pathname, phase, reason, terminalReason, status: downstreamStatus,
      upstreamStatus, requestBytes, responseBytes, downstreamHeadersSent: response.headersSent,
      transportCategory: category });
    terminal('failed', terminalReason, reason, { transportCategory: category });
    if (!response.headersSent) {
      response.writeHead(status, { 'content-type': 'application/json', connection: 'close' });
      response.end(JSON.stringify({ error: reason }));
    } else {
      // A second HTTP error response after a streamed status would corrupt the
      // downstream framing, so terminate the incomplete body instead.
      response.destroy();
    }
  };
  const completeRequest = () => {
    phase = 'complete';
    terminal('completed', 'completed', null);
  };
  try {
    if (Date.now() - started > lifetimeMs) return rejectRequest(408, 'broker lifetime exceeded');
    const requestUrl = new URL(request.url, 'http://127.0.0.1');
    pathname = requestUrl.pathname;
    route = routeFor(requestUrl.pathname);
    if (!route) return rejectRequest(404, 'route unavailable');
    const declaredLength = request.headers['content-length'] === undefined
      ? null : Number(request.headers['content-length']);
    audit({ event: 'request', requestId, method: request.method, route: route.kind,
      path: requestUrl.pathname, declaredLength: Number.isSafeInteger(declaredLength) ? declaredLength : null,
      headerNames: requestHeaderNames });
    phase = 'request_admission';
    if (route.kind === 'provider') {
      const allowed = requestUrl.pathname === '/provider/v1/models' ? request.method === 'GET' : request.method === 'POST';
      if (!allowed) return rejectRequest(405, 'method unavailable');
    } else {
      if (request.method !== 'POST') return rejectRequest(405, 'method unavailable');
    }

    phase = 'request_body';
    const perBodyLimit = route.kind === 'provider' ? limits.requestBody : limits.remoteRequestBody;
    const cumulativeLimit = route.kind === 'provider' ? limits.providerRequestBytes : limits.remoteRequestBytes;
    const declaredBodyTooLarge = Number.isSafeInteger(declaredLength) && declaredLength > perBodyLimit;
    const retainLimit = declaredBodyTooLarge ? 0 : perBodyLimit;
    const read = await bodyBytes(request, retainLimit);
    requestBytes = read.bytes;
    // Re-read the cumulative counter after the async body drain. Admission and
    // reservation below are synchronous, so concurrent bodies cannot both
    // spend the same remaining allowance.
    const routeRequestUsed = route.kind === 'provider' ? usage.providerRequest : usage.remoteRequest;
    const remainingRequestBytes = Math.max(0, cumulativeLimit - routeRequestUsed);
    const declaredCumulativeTooLarge = Number.isSafeInteger(declaredLength) && declaredLength > remainingRequestBytes;
    if (declaredBodyTooLarge || declaredCumulativeTooLarge || read.body === null ||
        requestBytes > perBodyLimit || requestBytes > remainingRequestBytes) {
      usage.requestRejected += requestBytes;
      const reason = declaredBodyTooLarge || requestBytes > perBodyLimit ? 'request body limit exceeded'
        : `${route.kind === 'provider' ? 'provider' : 'remote MCP'} cumulative request budget exceeded`;
      return rejectRequest(413, reason, { requestBytes,
        limit: declaredBodyTooLarge || requestBytes > perBodyLimit ? perBodyLimit : cumulativeLimit,
        cumulativeAccepted: routeRequestUsed });
    }
    const body = read.body;
    if (route.kind === 'provider' && request.method === 'POST') {
      let payload;
      try { payload = JSON.parse(body.toString('utf8')); }
      catch {
        usage.requestRejected += requestBytes;
        return rejectRequest(400, 'invalid provider request');
      }
      if (!payload || Array.isArray(payload) || payload.model !== 'grok-4.6') {
        usage.requestRejected += requestBytes;
        return rejectRequest(403, 'provider model unavailable');
      }
      const override = request.headers['x-grok-model-override'];
      if (override !== undefined && override !== 'grok-4.6') {
        usage.requestRejected += requestBytes;
        return rejectRequest(403, 'provider model override unavailable');
      }
    }
    if (route.kind === 'provider') {
      if (usage.provider >= limits.providerRequests) {
        usage.requestRejected += requestBytes;
        return rejectRequest(429, 'provider request budget exceeded');
      }
    }
    if (route.kind !== 'provider' && body.length) {
      let payload;
      try { payload = JSON.parse(body.toString('utf8')); }
      catch {
        usage.requestRejected += requestBytes;
        return rejectRequest(400, 'invalid MCP request');
      }
      remoteMessages = Array.isArray(payload) ? payload : [payload];
      const allowedMethods = new Set(['initialize', 'notifications/initialized', 'ping', 'tools/list', 'tools/call']);
      const allowedTools = route.kind === 'parallel'
        ? new Set(['web_fetch', 'web_search_preview'])
        : new Set(['query-docs', 'resolve-library-id']);
      for (const message of remoteMessages) {
        if (!message || typeof message !== 'object' || Array.isArray(message)) {
          usage.requestRejected += requestBytes;
          return rejectRequest(400, 'invalid MCP request');
        }
        if (!allowedMethods.has(message.method)) {
          usage.requestRejected += requestBytes;
          return rejectRequest(403, 'MCP method unavailable');
        }
        if (message.method === 'tools/call') {
          if (!allowedTools.has(message.params?.name)) {
            usage.requestRejected += requestBytes;
            return rejectRequest(403, 'MCP tool unavailable');
          }
          remoteToolCalls += 1;
        }
      }
      if (usage.tools[route.kind] + remoteToolCalls > limits.toolsPerServer) {
        usage.requestRejected += requestBytes;
        return rejectRequest(429, 'MCP tool budget exceeded');
      }
    }
    if (route.kind !== 'provider' && usage.remote >= limits.remoteRequests) {
      usage.requestRejected += requestBytes;
      return rejectRequest(429, 'remote MCP request budget exceeded');
    }
    usage.requestAccepted += requestBytes;
    if (route.kind === 'provider') {
      usage.provider += 1;
      usage.providerRequest += requestBytes;
    } else {
      usage.remote += 1;
      usage.remoteRequest += requestBytes;
      usage.tools[route.kind] += remoteToolCalls;
    }
    audit({ event: 'admitted', requestId, route: route.kind, requestBytes,
      cumulativeRequestBytes: route.kind === 'provider' ? usage.providerRequest : usage.remoteRequest });
    phase = 'upstream_response_headers';
    if (process.env.BROKER_TEST_MODE === '1') {
      if (requestUrl.searchParams.get('test_stream_failure') === '1') {
        upstreamStatus = 200;
        upstreamHeaderNames = ['content-type', 'transfer-encoding'];
        audit({ event: 'upstream', requestId, route: route.kind, status: upstreamStatus,
          headerNames: upstreamHeaderNames, contentCoding });
        phase = 'upstream_response_stream';
        downstreamStatus = 200;
        forwardedHeaderNames = ['content-type'];
        response.writeHead(200, { 'content-type': 'text/event-stream' });
        response.flushHeaders();
        const partial = Buffer.from('data: partial\n\n');
        responseBytes += partial.length;
        usage.response += partial.length;
        if (route.kind === 'provider') usage.providerResponse += partial.length;
        else usage.remoteResponse += partial.length;
        response.write(partial);
        throw new Error('synthetic stream failure');
      }
      const syntheticBytes = Number(requestUrl.searchParams.get('test_response_bytes') || 0);
      if (syntheticBytes > 0) {
        upstreamStatus = 200;
        upstreamHeaderNames = ['content-type'];
        audit({ event: 'upstream', requestId, route: route.kind, status: upstreamStatus,
          headerNames: upstreamHeaderNames, contentCoding });
        phase = 'upstream_response_stream';
        downstreamStatus = 200;
        forwardedHeaderNames = ['content-type'];
        response.writeHead(200, { 'content-type': 'application/octet-stream' });
        response.flushHeaders();
        const chunk = Buffer.alloc(1024 * 1024, 0x78);
        let remaining = syntheticBytes;
        while (remaining > 0) {
          const next = chunk.subarray(0, Math.min(chunk.length, remaining));
          responseBytes += next.length;
          usage.response += next.length;
          if (route.kind === 'provider') usage.providerResponse += next.length;
          else usage.remoteResponse += next.length;
          let responseRejection = null;
          if (usage.response > limits.responseBytes) responseRejection = 'response budget exceeded';
          else if (route.kind !== 'provider' && responseBytes > limits.remoteResponseBody) {
            responseRejection = 'remote response body limit exceeded';
          } else if (route.kind !== 'provider' && usage.remoteResponse > limits.remoteResponseBytes) {
            responseRejection = 'remote response budget exceeded';
          }
          if (responseRejection) {
            audit({ event: 'response_rejected', requestId, route: route.kind, reason: responseRejection });
            return failRequest(502, responseRejection.replaceAll(' ', '_'), responseRejection);
          }
          response.write(next);
          remaining -= next.length;
        }
        response.end();
        completeRequest();
        return;
      }
      if (route.kind === 'provider') {
        upstreamStatus = 200;
        upstreamHeaderNames = ['content-type'];
        audit({ event: 'upstream', requestId, route: route.kind, status: upstreamStatus,
          headerNames: upstreamHeaderNames, contentCoding });
        phase = 'upstream_response_stream';
        downstreamStatus = 200;
        forwardedHeaderNames = ['content-type'];
        response.writeHead(200, { 'content-type': 'application/json' });
        const responseBody = Buffer.from(JSON.stringify({ object: 'list', data: [{ id: 'grok-4.6', object: 'model' }] }));
        responseBytes += responseBody.length;
        usage.response += responseBody.length;
        usage.providerResponse += responseBody.length;
        response.end(responseBody);
      } else {
        const payload = body.length ? JSON.parse(body.toString('utf8')) : {};
        const message = Array.isArray(payload) ? payload[0] : payload;
        const tools = route.kind === 'parallel'
          ? ['web_fetch', 'web_search_preview']
          : ['query-docs', 'resolve-library-id'];
        let result = {};
        if (message.method === 'initialize') result = { protocolVersion: '2025-06-18', capabilities: { tools: {} }, serverInfo: { name: route.kind, version: 'test' } };
        if (message.method === 'tools/list') result = { tools: tools.map((name) => ({ name, description: name, inputSchema: { type: 'object' } })) };
        if (message.method === 'tools/call') result = { content: [{ type: 'text', text: 'test' }] };
        upstreamStatus = 200;
        upstreamHeaderNames = ['content-type'];
        audit({ event: 'upstream', requestId, route: route.kind, status: upstreamStatus,
          headerNames: upstreamHeaderNames, contentCoding });
        phase = 'upstream_response_stream';
        downstreamStatus = 200;
        forwardedHeaderNames = ['content-type'];
        response.writeHead(200, { 'content-type': 'application/json' });
        const responseBody = Buffer.from(JSON.stringify(message.id === undefined ? {} : { jsonrpc: '2.0', id: message.id, result }));
        responseBytes += responseBody.length;
        usage.response += responseBody.length;
        usage.remoteResponse += responseBody.length;
        response.end(responseBody);
      }
      completeRequest();
      return;
    }
    const headers = { accept: request.headers.accept || 'application/json, text/event-stream', 'content-type': request.headers['content-type'] || 'application/json' };
    if (request.headers['mcp-session-id']) headers['mcp-session-id'] = request.headers['mcp-session-id'];
    if (request.headers['mcp-protocol-version']) headers['mcp-protocol-version'] = request.headers['mcp-protocol-version'];
    if (request.headers['user-agent']) headers['user-agent'] = request.headers['user-agent'];
    if (route.kind === 'provider') {
      const forwarded = [
        'x-grok-agent-id', 'x-grok-client-identifier', 'x-grok-client-mode',
        'x-grok-client-version', 'x-grok-conv-group-id', 'x-grok-conv-id',
        'x-grok-model-override', 'x-grok-req-id', 'x-grok-session-id',
        'x-grok-turn-idx',
      ];
      for (const name of forwarded) {
        if (typeof request.headers[name] === 'string') headers[name] = request.headers[name];
      }
      if (request.headers.traceparent) headers.traceparent = request.headers.traceparent;
    }
    if (route.kind === 'provider') headers.authorization = `Bearer ${providerKey}`;
    if (route.kind === 'parallel') {
      headers.authorization = `Bearer ${process.env.PARALLEL_SEARCH_API_TOKEN}`;
      headers['x-api-key'] = process.env.PARALLEL_SEARCH_API_TOKEN;
    }
    if (route.kind === 'context7') {
      headers.authorization = `Bearer ${process.env.CONTEXT7_API_KEY}`;
      headers['x-api-key'] = process.env.CONTEXT7_API_KEY;
    }
    const upstream = await fetch(route.upstream + requestUrl.search, {
      method: request.method,
      headers,
      body: request.method === 'GET' ? undefined : body,
      redirect: 'manual',
      // The wrapper's one wall-clock deadline owns inference. A shorter broker
      // timeout previously aborted valid xhigh streams and triggered paid CLI retries.
      signal: AbortSignal.any([
        AbortSignal.timeout(Math.max(1, started + lifetimeMs - Date.now())),
        downstreamAbortController.signal,
      ]),
    });
    upstreamStatus = upstream.status;
    upstreamHeaderNames = [...upstream.headers.keys()].sort();
    contentCoding = normalizedContentCoding(upstream.headers.get('content-encoding'));
    audit({ event: 'upstream', requestId, route: route.kind, status: upstreamStatus,
      headerNames: upstreamHeaderNames, contentCoding });
    if (upstream.status >= 300 && upstream.status < 400) return rejectRequest(502, 'upstream redirect refused');
    const responseHeaders = { 'content-type': upstream.headers.get('content-type') || 'application/octet-stream' };
    const mcpSession = upstream.headers.get('mcp-session-id');
    if (mcpSession) responseHeaders['mcp-session-id'] = mcpSession;
    downstreamStatus = upstream.status;
    forwardedHeaderNames = Object.keys(responseHeaders).sort();
    phase = 'downstream_response_headers';
    response.writeHead(upstream.status, responseHeaders);
    response.flushHeaders();
    if (upstream.body) {
      const iterator = upstream.body[Symbol.asyncIterator]();
      while (true) {
        phase = 'upstream_response_stream';
        const { value: chunk, done } = await iterator.next();
        if (done) break;
        responseBytes += chunk.length;
        usage.response += chunk.length;
        if (route.kind === 'provider') usage.providerResponse += chunk.length;
        else usage.remoteResponse += chunk.length;
        if (usage.response > limits.responseBytes) throw new Error('response budget exceeded');
        if (route.kind !== 'provider' && responseBytes > limits.remoteResponseBody) {
          throw new Error('remote response body limit exceeded');
        }
        if (route.kind !== 'provider' && usage.remoteResponse > limits.remoteResponseBytes) {
          throw new Error('remote response budget exceeded');
        }
        phase = 'downstream_response_stream';
        response.write(chunk);
      }
    }
    phase = 'downstream_response_end';
    response.end();
    completeRequest();
  } catch (error) {
    const known = new Set(['response budget exceeded', 'remote response body limit exceeded',
      'remote response budget exceeded']);
    if (known.has(error.message)) {
      return failRequest(502, error.message.replaceAll(' ', '_'), error.message);
    }
    const category = transportCategory(error);
    let terminalReason = 'broker_request_processing_failed';
    if (downstreamClosed) {
      terminalReason = 'downstream_response_closed';
    } else if (phase === 'upstream_response_headers') {
      terminalReason = 'upstream_response_headers_failed';
    } else if (phase === 'upstream_response_stream') {
      terminalReason = 'upstream_response_stream_failed';
    } else if (phase === 'downstream_response_headers' ||
               phase === 'downstream_response_stream' || phase === 'downstream_response_end') {
      terminalReason = 'downstream_response_failed';
    }
    if (!downstreamClosed && phase === 'upstream_response_stream' && category === 'compressed_body_decode') {
      terminalReason = 'upstream_response_decode_failed';
    } else if (!downstreamClosed && category === 'deadline_or_abort') {
      terminalReason = 'upstream_response_deadline_exceeded';
    }
    return failRequest(502, terminalReason, terminalReason.replaceAll('_', ' '),
      { transportCategory: downstreamClosed ? 'downstream_socket_closed' : category });
  }
});
server.listen(process.env.BROKER_SOCKET_PATH, () => {
  fs.writeFileSync(process.env.BROKER_READY_FILE, `${JSON.stringify({ pid: process.pid })}\n`, { mode: 0o600 });
});
server.requestTimeout = lifetimeMs;
server.headersTimeout = Math.min(10_000, lifetimeMs);
server.maxConnections = 8;
const stop = (reason) => {
  audit({ event: 'stop', reason, elapsedMs: Date.now() - started, limits, usage });
  server.close();
  server.closeAllConnections();
  process.exit(0);
};
process.on('SIGTERM', () => stop('SIGTERM'));
process.on('SIGINT', () => stop('SIGINT'));
setTimeout(() => stop('deadline'), lifetimeMs).unref();
audit({ event: 'start', limits, retryPolicy: { inferenceRetries: 0, turnTransientRetry: false,
  titleRefresh: false, turnSummary: false, sessionRecap: false } });
NODE
chmod 600 "$broker_script"

broker_marker="BROKER_ONLY_$(</proc/sys/kernel/random/uuid)"
broker_audit="$run_home/broker-audit.jsonl"
# One deadline covers broker preflight and the CLI; the watchdog allows the
# existing five-second timeout kill grace before closing the transport.
broker_started_seconds=$SECONDS
env -i \
  "PATH=$PATH" \
  "PROVIDER_AUTH_FILE=$original_grok_home/auth.json" \
  "PARALLEL_SEARCH_API_TOKEN=$PARALLEL_SEARCH_API_TOKEN" \
  "CONTEXT7_API_KEY=$CONTEXT7_API_KEY" \
  "BROKER_READY_FILE=$broker_ready" \
  "BROKER_SOCKET_PATH=$broker_socket" \
  "BROKER_AUDIT_FILE=$broker_audit" \
  "BROKER_MARKER=$broker_marker" \
  "BROKER_TEST_MODE=${AGENT_CALL_GROK_TEST_MODE:-0}" \
  "BROKER_LIFETIME_MS=$(( (timeout_sec + 5) * 1000 ))" \
  "BROKER_MAX_TURNS=$max_turns" \
  node "$broker_script" >"$run_home/broker.stdout" 2>"$run_home/broker.stderr" &
broker_pid=$!
for _ in {1..100}; do
  [[ -s "$broker_ready" ]] && break
  kill -0 "$broker_pid" 2>/dev/null || break
  sleep 0.05
done
[[ -s "$broker_ready" ]] || die "credential broker did not become ready"
[[ -S "$broker_socket" ]] || die "credential broker did not create its private Unix socket"
broker_port=38117
if [[ "${AGENT_CALL_GROK_TEST_MODE:-0}" == 1 ]]; then
  printf '%s\n' "$broker_pid" >"$FAKE_CAPTURE_DIR/broker-host-pid-$FAKE_CALL_INDEX"
fi
# shellcheck disable=SC2016 # JavaScript template expressions expand in Node.
dummy_provider_token=$(node -e '
const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
const now = Math.floor(Date.now() / 1000);
const header = { alg: "ES256", typ: "at+jwt" };
const payload = {
  aud: "b1a00492-073a-47ea-816f-4c329264a828",
  client_id: "b1a00492-073a-47ea-816f-4c329264a828",
  exp: now + 3600,
  iat: now,
  iss: "https://auth.x.ai",
  jti: "broker-placeholder",
  principal_id: "00000000-0000-4000-8000-000000000000",
  principal_type: "User",
  referrer: "grok-build",
  scope: "openid profile email offline_access grok-cli:access api:access",
  sub: "broker-placeholder",
  team_id: "00000000-0000-4000-8000-000000000000",
  tier: 1,
};
process.stdout.write(`${encode(header)}.${encode(payload)}.${Buffer.alloc(64).toString("base64url")}`);
')

cat >"$run_config" <<EOF
[cli]
use_leader = false

[endpoints]
models_base_url = "http://127.0.0.1:$broker_port/provider/v1"
models_list_url = "http://127.0.0.1:$broker_port/provider/v1/models"

[model.grok-brokered]
model = "grok-4.6"
base_url = "http://127.0.0.1:$broker_port/provider/v1"
api_key = "$dummy_provider_token"
max_retries = 0
inference_idle_timeout_secs = $timeout_sec

[features]
title_refresh = false
turn_summary = false
session_recap = false

[mcp]
max_output_bytes = 1048576

[toolset.bash]
output_byte_limit = 1048576

[mcp_servers.parallel-search]
url = "http://127.0.0.1:$broker_port/parallel"
headers = { Authorization = "Bearer broker-dummy" }

[mcp_servers.context7_remote]
url = "http://127.0.0.1:$broker_port/context7"
headers = { Authorization = "Bearer broker-dummy" }

[compat.claude]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false

[compat.cursor]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false

[plugins]
paths = []

[shell_environment_policy]
inherit = "core"
ignore_default_excludes = false
exclude = ["*KEY*", "*SECRET*", "*TOKEN*", "*CREDENTIAL*", "*COOKIE*", "*AUTH*"]
include_only = ["HOME", "LANG", "LC_ALL", "PATH", "TERM", "TMPDIR"]
EOF
chmod 600 "$run_config"

: >"$run_secrets"
jq -r 'paths(scalars) as $p | select(($p[-1] | tostring) == "key" or ($p[-1] | tostring) == "refresh_token") | getpath($p) | select(type == "string" and length >= 8)' \
  "$original_grok_home/auth.json" >>"$run_secrets"
for secret_name in PARALLEL_SEARCH_API_TOKEN CONTEXT7_API_KEY; do
  secret_value=${!secret_name:-}
  if [[ -n "$secret_value" && "${#secret_value}" -ge 8 ]]; then
    printf '%s\n' "$secret_value" >>"$run_secrets"
  fi
done
unset secret_value
chmod 600 "$run_secrets"


if [[ "$new_session" -eq 0 ]]; then
  session_relative_path=$(jq -r '.session_relative_path // empty' "$session_metadata")
  [[ -n "$session_relative_path" && "$session_relative_path" != /* && "$session_relative_path" != *'..'* ]] ||
    die "Grok session metadata has an unsafe session path: $recorded_session"
  session_archive="$state_dir/grok-session-data-$recorded_session"
  [[ -d "$session_archive" && ! -L "$session_archive" ]] ||
    die "Grok session archive is unavailable: $recorded_session"
  mkdir -p "$child_home/$(dirname "$session_relative_path")"
  cp -a -- "$session_archive" "$child_home/$session_relative_path"
fi

bwrap_args=(
  bwrap
  --die-with-parent --new-session --unshare-pid --unshare-uts --unshare-ipc --unshare-net
  --proc /proc --dev /dev
  --ro-bind /usr /usr
  --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 --symlink usr/sbin /sbin
  --dir /etc --ro-bind /etc/ssl /etc/ssl --ro-bind /etc/resolv.conf /etc/resolv.conf
  --ro-bind /etc/hosts /etc/hosts --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf
  --ro-bind /etc/passwd /etc/passwd --ro-bind /etc/group /etc/group
  --dir /grok-bin
  --ro-bind "$grok_path" /grok-bin/grok
  --bind "$child_home" /grok-home --bind "$child_tmp" /tmp
  --dir /run --bind "$broker_socket" /run/grok-broker.sock
  --ro-bind "$git_view" /git --ro-bind "$actual_git_common/objects" /git/common/objects
)
if [[ "$role" == contributor ]]; then
  bwrap_args+=(--bind "$workspace_snapshot" /workspace)
else
  bwrap_args+=(--ro-bind "$workspace_snapshot" /workspace)
fi
bwrap_args+=(
  --chdir /workspace
  --clearenv
  --setenv HOME /grok-home --setenv GROK_HOME /grok-home --setenv TMPDIR /tmp
  # Grok retries whole turns independently of model.max_retries. Keep both
  # retry layers disabled; a partial response never authorizes another call.
  --setenv GROK_TURN_TRANSIENT_RETRY 0
  --setenv PATH /grok-bin:/usr/bin:/bin
  --setenv LANG "${LANG:-C.UTF-8}" --setenv TERM "${TERM:-dumb}"
  --setenv XAI_API_KEY "$dummy_provider_token"
  --setenv GROK_MODELS_BASE_URL "http://127.0.0.1:$broker_port/provider/v1"
  --setenv GROK_MODELS_LIST_URL "http://127.0.0.1:$broker_port/provider/v1/models"
  --setenv GROK_BROKER_PORT "$broker_port"
  --setenv GROK_CLAUDE_SKILLS_ENABLED 0 --setenv GROK_CLAUDE_RULES_ENABLED 0
  --setenv GROK_CLAUDE_AGENTS_ENABLED 0 --setenv GROK_CLAUDE_MCPS_ENABLED 0
  --setenv GROK_CLAUDE_HOOKS_ENABLED 0 --setenv GROK_CURSOR_SKILLS_ENABLED 0
  --setenv GROK_CURSOR_RULES_ENABLED 0 --setenv GROK_CURSOR_AGENTS_ENABLED 0
  --setenv GROK_CURSOR_MCPS_ENABLED 0 --setenv GROK_CURSOR_HOOKS_ENABLED 0
  --setenv GOSUMDB off --setenv GIT_OPTIONAL_LOCKS 0
)
if [[ -d "$run_root/.git" ]]; then
  bwrap_args+=(--bind "$git_worktree_view" /workspace/.git)
else
  bwrap_args+=(--ro-bind "$git_pointer" /workspace/.git)
fi
if [[ "${AGENT_CALL_GROK_TEST_MODE:-0}" == 1 ]]; then
  [[ -n "${FAKE_CAPTURE_DIR:-}" && -n "${FAKE_CALL_INDEX:-}" ]] ||
    die "test mode requires FAKE_CAPTURE_DIR and FAKE_CALL_INDEX"
  bwrap_args+=(--bind "$FAKE_CAPTURE_DIR" /capture --setenv FAKE_CAPTURE_DIR /capture --setenv FAKE_CALL_INDEX "$FAKE_CALL_INDEX")
  if [[ -n "${FAKE_SLEEP:-}" ]]; then
    bwrap_args+=(--setenv FAKE_SLEEP "$FAKE_SLEEP")
  fi
  if [[ -n "${FAKE_EMPTY:-}" ]]; then
    bwrap_args+=(--setenv FAKE_EMPTY "$FAKE_EMPTY")
  fi
  if [[ -n "${FAKE_BROKER_BUDGET:-}" ]]; then
    bwrap_args+=(--setenv FAKE_BROKER_BUDGET "$FAKE_BROKER_BUDGET")
  fi
  if [[ -n "${FAKE_EDIT:-}" ]]; then
    bwrap_args+=(--setenv FAKE_EDIT "$FAKE_EDIT")
  fi
  if [[ -n "${FAKE_HOST_LOOPBACK_PORT:-}" ]]; then
    bwrap_args+=(--setenv FAKE_HOST_LOOPBACK_PORT "$FAKE_HOST_LOOPBACK_PORT")
  fi
fi
namespace_launcher="$child_home/namespace-launch.sh"
cat >"$namespace_launcher" <<'SH'
#!/bin/sh
set -eu
socat TCP-LISTEN:38117,bind=127.0.0.1,reuseaddr,fork UNIX-CONNECT:/run/grok-broker.sock &
forwarder_pid=$!
payload_pid=""
cleanup_namespace() {
  if [ -n "$payload_pid" ]; then
    kill -TERM "$payload_pid" 2>/dev/null || true
  fi
  kill -TERM "$forwarder_pid" 2>/dev/null || true
  wait "$forwarder_pid" 2>/dev/null || true
}
trap 'cleanup_namespace; exit 143' HUP INT TERM
sleep 0.05
kill -0 "$forwarder_pid"
set +e
"$@" &
payload_pid=$!
wait "$payload_pid"
status=$?
set -e
payload_pid=""
cleanup_namespace
exit "$status"
SH
chmod 700 "$namespace_launcher"
bwrap_command=(env -i PATH=/usr/bin:/bin "${bwrap_args[@]}")

topology_report="$run_home/topology.txt"
# shellcheck disable=SC2016 # The probe expands only inside the isolated shell.
topology_probe='set -eu; test "$(ps -e -o comm= | grep -Ec "^node$" || true)" -eq 0; ! env | grep -Fq BROKER_ONLY_; test -z "$(find /home -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)"; test -d /workspace; test -x /grok-bin/grok; git rev-parse --show-toplevel; git status --short; git diff --no-ext-diff --stat'
"${bwrap_command[@]}" /bin/sh /grok-home/namespace-launch.sh /bin/sh -c "$topology_probe" >"$topology_report" 2>"$run_home/topology.stderr" || {
  cat "$run_home/topology.stderr" >&2
  cat "$topology_report" >&2
  die "Grok namespace topology or sanitized Git preflight failed"
}

if [[ "${AGENT_CALL_GROK_TEST_MODE:-0}" != 1 ]]; then
  inspect_json="$run_home/inspect.json"
  "${bwrap_command[@]}" /bin/sh /grok-home/namespace-launch.sh /grok-bin/grok inspect --json >"$inspect_json" 2>"$run_home/inspect.stderr" ||
    die "Grok isolated configuration inspection failed"
  jq -e '(.plugins | length) == 0 and (.hooks | length) == 0' "$inspect_json" >/dev/null ||
    die "Grok isolated profile discovered a plugin or hook"
  mcp_json="$run_home/mcp-list.json"
  "${bwrap_command[@]}" /bin/sh /grok-home/namespace-launch.sh /grok-bin/grok mcp list --json >"$mcp_json" 2>"$run_home/mcp-list.stderr" ||
    die "Grok isolated MCP inventory failed"
  actual_mcp_servers=$(jq -r '[.[] | select(.enabled == true) | .name] | sort | join(",")' "$mcp_json")
  [[ "$actual_mcp_servers" == "$selected_mcp_servers" ]] ||
    die "Grok active MCP server inventory drifted: $actual_mcp_servers"
fi

args=(
  --cwd /workspace
  --model grok-brokered
  --output-format plain
  --verbatim
  --always-approve
  --no-leader
  --no-auto-update
  --max-turns "$max_turns"
)
if [[ -n "$effort" ]]; then
  args+=(--reasoning-effort "$effort")
fi
if [[ "$new_session" -eq 1 ]]; then
  args+=(--session-id "$recorded_session")
else
  args+=(--resume "$recorded_session")
fi
if [[ "$answer_only" -eq 1 ]]; then
  # Enforcement, not persuasion: an empty built-in allowlist removes every
  # built-in tool, which also closes the `use_tool` gateway to the selected MCP
  # servers. The preflight MCP inventory assertion is unchanged.
  args+=(--tools "" --no-subagents --disable-web-search)
fi
args+=(--prompt-file /grok-home/request.md)

cp -- "$prompt_tmp" "$child_home/request.md"
chmod 600 "$child_home/request.md"

remaining_timeout_sec=$(( timeout_sec - (SECONDS - broker_started_seconds) ))
[[ "$remaining_timeout_sec" -gt 0 ]] || die "Grok broker preflight exhausted the execution deadline"
[[ "$(sha256sum "$grok_path" | awk '{print $1}')" == "$actual_grok_sha256" ]] ||
  die "Grok binary changed before execution"
set +e
timeout --foreground --kill-after=5s "$remaining_timeout_sec" \
  "${bwrap_command[@]}" /bin/sh /grok-home/namespace-launch.sh /grok-bin/grok "${args[@]}" >"$output" 2>"$stderr_output" &
run_pid=$!
wait "$run_pid"
status=$?
run_pid=""
set -e
[[ "$(sha256sum "$grok_path" | awk '{print $1}')" == "$actual_grok_sha256" ]] ||
  die "Grok binary changed during the run"
rm -f -- "$child_home/request.md"
host_git_digest_after=$(git_metadata_digest)
[[ "$host_git_digest_after" == "$host_git_digest_before" ]] ||
  die "host Git metadata changed during the isolated Grok run"
printf '%s\n' "$broker_marker" >>"$run_secrets"
if [[ -s "$run_secrets" ]] && grep -F -f "$run_secrets" "$output" "$stderr_output" >/dev/null 2>&1; then
  rm -f -- "$output" "$stderr_output"
  die "Grok output contained a credential value and was removed"
fi
# A failed CLI turn still persists useful session state. Keep it separate from
# successful resume checkpoints: a contributor's untransferred private edits
# are deliberately discarded, so retaining its conversation is not resume admission.
retain_failed_session() {
  local session_evidence='missing' usage_evidence='missing' usage_json='null'
  local failure_reason='cli_exit_nonzero' failed_session_dir='' secret_scan_status=1
  local partial_output='none' partial_tmp=''
  local broker_evidence='missing' broker_limits_json='null' broker_stop_reason=''
  local broker_last_rejection_json='null' broker_terminal_event_json='null' broker_failure_reason=''
  local -a failed_sessions=()
  if [[ "$status" -eq 124 ]]; then
    failure_reason='timeout'
  elif grep -Fxq 'Error: max turns reached' "$stderr_output"; then
    failure_reason='max_turns_reached'
  fi
  mkdir -m 700 -- "$failure_output" || return 1
  if [[ -f "$broker_audit" && ! -L "$broker_audit" ]]; then
    cp -- "$broker_audit" "$failure_output/broker.jsonl" || return 1
    chmod 600 "$failure_output/broker.jsonl" || return 1
    broker_evidence='retained'
    broker_limits_json=$(jq -sc '[.[] | select(.event == "start") | .limits] | last // null' "$broker_audit")
    broker_stop_reason=$(jq -sr '[.[] | select(.event == "stop") | .reason] | last // empty' "$broker_audit")
    broker_last_rejection_json=$(jq -sc \
      '[.[] | select(.event == "rejected") | {status,reason,requestId,route,path,phase,requestBytes,limit}] | last // null' \
      "$broker_audit")
    # Expected route probes have route=null and cannot classify a later CLI
    # failure. One terminal record is emitted per broker request; only the last
    # routed terminal record can classify the CLI exit.
    broker_terminal_event_json=$(jq -sc \
      '[.[] | select(.event == "request_terminal" and .route != null)] | last // null' \
      "$broker_audit")
    if [[ "$failure_reason" == cli_exit_nonzero && "$broker_terminal_event_json" != null ]] &&
      [[ "$(jq -r '.outcome' <<<"$broker_terminal_event_json")" != completed ]]; then
      broker_failure_reason=$(jq -r '.terminalReason // empty' <<<"$broker_terminal_event_json")
      [[ -n "$broker_failure_reason" ]] && failure_reason=$broker_failure_reason
    fi
  fi
  if [[ -L "$child_home/sessions" ]]; then
    session_evidence='refused'
  elif [[ -d "$child_home/sessions" ]]; then
    mapfile -t failed_sessions < <(find "$child_home/sessions" -type d -name "$recorded_session" -print)
    if [[ "${#failed_sessions[@]}" -eq 1 ]]; then
      failed_session_dir=${failed_sessions[0]}
      if find "$failed_session_dir" ! -type f ! -type d -print -quit | grep -q .; then
        session_evidence='refused'
      else
        if [[ -s "$run_secrets" ]]; then
          if grep -R -F -f "$run_secrets" "$failed_session_dir" >/dev/null 2>&1; then
            secret_scan_status=0
          else
            secret_scan_status=$?
          fi
        fi
        if [[ "$secret_scan_status" -ne 1 ]]; then
          session_evidence='refused'
        else
          cp -a -- "$failed_session_dir" "$failure_output/session" || return 1
          chmod -R u=rwX,go= "$failure_output/session" || return 1
          session_evidence='retained'
        fi
      fi
    elif [[ "${#failed_sessions[@]}" -gt 1 ]]; then
      session_evidence='refused'
    fi
  fi
  # A turn-cap or timeout exit writes nothing to --output even though the model
  # often produced substantive assistant text and reasoning summaries first.
  # Salvage that into a clearly marked diagnostic sidecar so a bounded retry can
  # reuse it instead of re-running the whole paid call. The session copy has passed
  # the secret scan above; nothing outside it is read.
  if [[ "$session_evidence" == retained && -n "$output" &&
        -f "$failure_output/session/chat_history.jsonl" &&
        ! -L "$failure_output/session/chat_history.jsonl" ]]; then
    partial_tmp="$failure_output/partial.md"
    if jq -r '
        if .type == "assistant" and ((.content // "") | test("\\S"))
        then "## assistant\n\n" + .content
        elif .type == "reasoning"
        then ([.summary[]? | select((.text // "") | test("\\S")) | .text]
              | if length > 0 then "## reasoning\n\n" + join("\n\n") else empty end)
        else empty end
      ' "$failure_output/session/chat_history.jsonl" >"$partial_tmp" 2>/dev/null &&
      [[ -s "$partial_tmp" ]] && grep -q '[^[:space:]]' "$partial_tmp"; then
      chmod 600 "$partial_tmp"
      if [[ ! -e "$output.partial" && ! -L "$output.partial" ]]; then
        if cp -- "$partial_tmp" "$output.partial" 2>/dev/null; then
          chmod 600 "$output.partial"
          partial_output='retained'
        fi
      fi
    else
      rm -f -- "$partial_tmp"
    fi
  fi
  if [[ "$session_evidence" == retained && -f "$failure_output/session/usage.json" ]]; then
    usage_evidence='invalid'
    if jq -e --arg session "$recorded_session" \
      'type == "object" and .sessionId == $session and (.session | type) == "object"' \
      "$failure_output/session/usage.json" >/dev/null 2>&1; then
      usage_evidence='retained'
      usage_json=$(cat "$failure_output/session/usage.json")
    fi
  fi
  jq -n \
    --arg session "$recorded_session" --arg requested_model "$model" --arg effort "$effort" \
    --arg profile "$profile" --arg profile_revision "$profile_revision" \
    --arg grok_version "$actual_grok_version" --arg grok_sha256 "$actual_grok_sha256" \
    --arg worktree "$profile_worktree" --arg resumed_from "$resume_session" \
    --arg output "$output" --arg reason "$failure_reason" \
    --arg session_evidence "$session_evidence" --arg usage_evidence "$usage_evidence" \
    --arg partial_output "$partial_output" \
    --arg broker_evidence "$broker_evidence" --arg broker_stop_reason "$broker_stop_reason" \
    --argjson broker_limits "$broker_limits_json" --argjson broker_last_rejection "$broker_last_rejection_json" \
    --argjson broker_terminal_event "$broker_terminal_event_json" \
    --argjson exit_code "$status" --argjson max_turns "$max_turns" --argjson usage "$usage_json" \
    '{status:"failed",session:$session,exit_code:$exit_code,terminal_reason:$reason,
      requested_model:$requested_model,effort:$effort,max_turns:$max_turns,
      profile:$profile,profile_revision:$profile_revision,grok_version:$grok_version,grok_sha256:$grok_sha256,
      worktree:$worktree,resumed_from:$resumed_from,output:$output,
      session_evidence:$session_evidence,usage_evidence:$usage_evidence,usage:$usage,
      partial_output:$partial_output,
      broker_evidence:$broker_evidence,broker_limits:$broker_limits,
      broker_terminal_reason:(if $broker_stop_reason == "" then null else $broker_stop_reason end),
      broker_last_rejection:$broker_last_rejection,broker_terminal_event:$broker_terminal_event,
      effective_models:(if ($usage.session.modelUsage | type) == "object" and
                           ($usage.session.modelUsage | length) > 0
                        then ($usage.session.modelUsage | keys) else null end),
      reported_cost_usd_ticks:($usage.session.costUsdTicks // null),cost_usd_ticks_per_usd:10000000000,
      usage_scope:"session_totals_as_reported",resume_ready:false,resume_policy:"diagnostic_only"}' \
    >"$failure_output/result.json" || return 1
  printf 'Grok failed-session evidence: %s (diagnostic only; no successful checkpoint recorded).\n' "$failure_output" >&2
  if [[ "$partial_output" == retained ]]; then
    printf 'Grok partial model text salvaged to %s (diagnostic only; not a completed result).\n' "$output.partial" >&2
  fi
}

if [[ "$status" -ne 0 ]]; then
  printf 'Grok exited with status %s; inspect the mode-0600 output artifacts locally.\n' "$status" >&2
  stop_broker
  retain_failed_session || printf 'Failed-session evidence retention incomplete; inspect %s locally.\n' "$failure_output" >&2
  if [[ -s "$broker_audit" ]]; then
    printf '%s\n' 'Broker audit (sanitized request and terminal metadata):' >&2
    cat "$broker_audit" >&2
  fi
  exit "$status"
fi
if [[ ! -s "$output" ]] || ! grep -q '[^[:space:]]' "$output"; then
  die "Grok CLI returned empty output; not recording a successful council result"
fi

mapfile -t session_matches < <(find "$child_home/sessions" -type d -name "$recorded_session" -print 2>/dev/null)
[[ "${#session_matches[@]}" -eq 1 ]] ||
  die "Grok did not produce exactly one exact-session directory"
live_session_dir=${session_matches[0]}
session_relative_path=${live_session_dir#"$child_home/"}
[[ "$session_relative_path" != "$live_session_dir" && "$session_relative_path" != *'..'* ]] ||
  die "Grok produced an unsafe session path"
if find "$live_session_dir" -type l -print -quit | grep -q .; then
  die "Grok session contains a symlink and will not be archived"
fi
if [[ -s "$run_secrets" ]] && grep -R -F -f "$run_secrets" "$live_session_dir" "$topology_report" >/dev/null 2>&1; then
  rm -f -- "$output" "$stderr_output"
  die "Grok session artifact contained a credential value; response artifacts were removed"
fi
if [[ "$role" == contributor ]]; then
  [[ "$(workspace_guard_digest)" == "$host_workspace_digest_before" ]] ||
    die "assigned contributor worktree changed outside the isolated Grok snapshot"
  if find "$workspace_snapshot" \( -type b -o -type c -o -type p -o -type s \) -print -quit | grep -q .; then
    die "Grok created a special file in the contributor snapshot"
  fi
  git --git-dir="$git_extract_view" --work-tree="$workspace_snapshot" add -A -- .
  contributor_patch="$run_home/contributor.patch"
  git \
    --git-dir="$git_extract_view" --work-tree="$workspace_snapshot" \
    diff --cached --binary --full-index --no-ext-diff "$workspace_baseline_tree" -- >"$contributor_patch"
  contributor_changed_count=$(git --git-dir="$git_extract_view" --work-tree="$workspace_snapshot" \
    diff --cached --name-only "$workspace_baseline_tree" -- | awk 'NF { count += 1 } END { print count + 0 }')
  [[ "$contributor_changed_count" -le 200 ]] ||
    die "Grok contributor snapshot exceeded the 200-file transfer ceiling"
  [[ "$(stat -c '%s' "$contributor_patch")" -le 20971520 ]] ||
    die "Grok contributor patch exceeded the 20-MiB transfer ceiling"
  if [[ -s "$run_secrets" && -s "$contributor_patch" ]] &&
    grep -F -f "$run_secrets" "$contributor_patch" >/dev/null 2>&1; then
    rm -f -- "$output" "$stderr_output"
    die "Grok contributor patch contained a credential value; response artifacts were removed"
  fi
  if [[ -s "$contributor_patch" ]]; then
    git -C "$profile_worktree" apply --check --whitespace=error-all "$contributor_patch" ||
      die "Grok contributor patch did not apply cleanly to the assigned worktree"
    git -C "$profile_worktree" apply --whitespace=error-all "$contributor_patch"
  fi
fi
session_archive="$state_dir/grok-session-data-$recorded_session"
[[ ! -L "$session_archive" ]] || die "Grok session archive must not be a symlink"
archive_tmp=$(mktemp -d "$state_dir/.grok-session-data.XXXXXX")
cp -a -- "$live_session_dir"/. "$archive_tmp"/
if [[ -d "$session_archive" ]]; then
  archive_old=$(mktemp -d "$state_dir/.grok-session-old.XXXXXX")
  rmdir "$archive_old"
  mv -- "$session_archive" "$archive_old"
  mv -- "$archive_tmp" "$session_archive"
  rm -rf -- "$archive_old"
else
  mv -- "$archive_tmp" "$session_archive"
fi

if [[ -n "$session_alias" ]]; then
  alias_tmp=$(mktemp "$state_dir/.grok-alias.XXXXXX")
  printf '%s\n' "$recorded_session" >"$alias_tmp"
  mv -T -- "$alias_tmp" "$state_dir/grok-session-$session_alias"
fi
latest_tmp=$(mktemp "$state_dir/.grok-latest.XXXXXX")
printf '%s\n' "$recorded_session" >"$latest_tmp"
mv -T -- "$latest_tmp" "$state_dir/grok-latest-session-id"
metadata_tmp=$(mktemp "$state_dir/.grok-metadata.XXXXXX")
jq -n \
  --arg session "$recorded_session" \
  --arg title "$title" \
  --arg role "$role" \
  --arg requested_model "$model" \
  --arg effort "$effort" \
  --arg output "$output" \
  --arg resumed_from "${resume_session:-}" \
  --arg session_alias "$session_alias" \
  --arg timestamp "$timestamp" \
  --arg grok_version "$actual_grok_version" \
  --arg grok_sha256 "$actual_grok_sha256" \
  --arg profile "$profile" \
  --arg profile_revision "$profile_revision" \
  --arg worktree "$profile_worktree" \
  --arg session_relative_path "$session_relative_path" \
  --argjson fake_credential_canary "$fake_credential_canary" \
  '{session:$session,title:$title,role:$role,requested_model:$requested_model,effort:(if $effort == "" then null else $effort end),profile:$profile,profile_revision:$profile_revision,worktree:$worktree,isolation:true,credential_broker:true,pid_namespace:true,positive_mounts:true,fake_credential_canary:($fake_credential_canary == 1),session_relative_path:$session_relative_path,output:$output,resumed_from:$resumed_from,session_alias:$session_alias,timestamp:$timestamp,grok_version:$grok_version,grok_sha256:$grok_sha256}' \
  >"$metadata_tmp"
mv -T -- "$metadata_tmp" "$state_dir/grok-session-$recorded_session.json"

printf 'Grok response written to %s\n' "$output"
printf 'Grok session recorded: %s\n' "$recorded_session"
if [[ -n "$session_alias" ]]; then
  printf 'Resume with: scripts/dev/agent-call-grok.sh --resume alias:%s --prompt-file <path>\n' "$session_alias"
else
  printf 'Resume with: scripts/dev/agent-call-grok.sh --resume %s --prompt-file <path>\n' "$recorded_session"
fi
