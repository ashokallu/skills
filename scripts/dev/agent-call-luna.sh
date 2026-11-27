#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-call-luna.sh [options] --prompt <text>
  scripts/dev/agent-call-luna.sh [options] --prompt-file <path>
  echo "<prompt>" | scripts/dev/agent-call-luna.sh [options]

Options:
  --prompt <text>        Prompt to send to GPT-6-Luna.
  --prompt-file <path>   Read the prompt from a file.
  --title <title>        Used for the saved output filename.
  --output <path>        Write Luna's final text to this path.
  --events-output <path> Write Codex JSONL events to this path.
  --timeout-sec <num>    Wall-clock timeout. Default: 180.
  --minimal-context      Run a mechanical local-repo scout outside the repo so
                         Codex does not auto-load project instructions. Requires
                         at least one repeatable --scope path.
  --scope <path>         Repo-relative file or directory declared as the
                         minimal task/evidence boundary. Repeatable. This is
                         prompt scope, not a filesystem read allowlist.
  --github-readonly      Run a GitHub read-only scout. Allows read-only gh/API
                         inventory but forbids PR comments, reviews, reruns,
                         cancellations, merges, edits, and reviewer requests.
  --gcp-monitoring       Run from a disposable writable temp directory with a
                         copied gcloud config so read-only gcloud/logging/
                         monitoring polling can refresh local auth/cache files.
  --gcp-monitoring-network
                         Trusted operator mode for live GCP polling. Runs from
                         the same disposable directory but bypasses the Codex
                         sandbox so Google API DNS/network works. Use only for
                         bounded read-only monitoring.
  --help                 Show this help.

This wrapper always runs with model_reasoning_summary="none" and
model_reasoning_effort="high". Luna acceptance of this pair was verified by
wrapper smoke on 2026-10-07; rerun scripts/dev/check-agent-call-luna.sh plus
a tiny live smoke after model changes. Luna supports reasoning summaries, but
none keeps scout output focused. Use it only for bounded read-only scout work.

Use --gcp-monitoring only for long-running read-only polling. It does not give
Luna repo write access; the repo remains outside the writable workspace.
Use --gcp-monitoring-network only when Luna must reach Google APIs directly;
this bypasses the sandbox, so keep prompts narrow and operator-owned.
Use --github-readonly for bounded GitHub inventory, CI monitoring, and Copilot
review-state monitoring. It does not bypass the sandbox or grant mutation
permission; keep prompts scoped to read-only gh/API calls and supplied evidence.
Use --minimal-context only for mechanical local file scouting after the parent
has loaded and owns repo routing. It is incompatible with GitHub/GCP modes and
must not own secrets, auth, private-data, migration, data-safety, review, or
architecture judgment. Read-only sandboxing blocks writes but does not make
--scope a confidentiality boundary; inspect command events after every call.
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

prompt=""
prompt_file=""
title="luna-call"
output=""
events_output=""
timeout_sec="180"
github_readonly=0
gcp_monitoring=0
gcp_monitoring_network=0
minimal_context=0
scopes=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt=${2:-}; shift 2 ;;
    --prompt-file) prompt_file=${2:-}; shift 2 ;;
    --title) title=${2:-}; shift 2 ;;
    --output) output=${2:-}; shift 2 ;;
    --events-output) events_output=${2:-}; shift 2 ;;
    --timeout-sec) timeout_sec=${2:-}; shift 2 ;;
    --minimal-context) minimal_context=1; shift ;;
    --scope) scopes+=("${2:-}"); shift 2 ;;
    --github-readonly) github_readonly=1; shift ;;
    --gcp-monitoring) gcp_monitoring=1; shift ;;
    --gcp-monitoring-network) gcp_monitoring=1; gcp_monitoring_network=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if [[ "$minimal_context" -eq 0 && ${#scopes[@]} -gt 0 ]]; then
  die "--scope requires --minimal-context"
fi
if [[ "$minimal_context" -eq 1 && ${#scopes[@]} -eq 0 ]]; then
  die "--minimal-context requires at least one --scope"
fi
if [[ "$minimal_context" -eq 1 && ( "$github_readonly" -eq 1 || "$gcp_monitoring" -eq 1 ) ]]; then
  die "--minimal-context is incompatible with GitHub and GCP modes"
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

root=$(repo_root)
calls_dir="$root/tmp/codex-luna/calls"
timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
slug=$(sanitize_slug "$title")
[[ -n "$slug" ]] || slug="luna-call"
mkdir -p "$calls_dir"

if [[ -z "$output" ]]; then
  output="$calls_dir/$timestamp-luna-$slug.md"
fi
if [[ -z "$events_output" ]]; then
  events_output="$calls_dir/$timestamp-luna-$slug.events.jsonl"
fi

workdir="$root"
sandbox_mode="read-only"
bypass_sandbox=0
skip_git_repo_check=()
extra_env=()
cleanup_paths=()
repo_status_before=""
minimal_scope_lines=()

if [[ "$minimal_context" -eq 1 ]]; then
  for scope in "${scopes[@]}"; do
    [[ -n "$scope" ]] || die "--scope must not be empty"
    [[ "$scope" != *$'\n'* && "$scope" != *$'\r'* ]] ||
      die "--scope must be a single line"
    [[ "$scope" != /* ]] || die "--scope must be repo-relative: $scope"
    scope_path=$(realpath -e -- "$root/$scope" 2>/dev/null) ||
      die "--scope does not exist: $scope"
    case "$scope_path" in
      "$root"|"$root"/*) ;;
      *) die "--scope escapes the repo: $scope" ;;
    esac
    scope_alias=${scope#./}
    if [[ -d "$scope_path" ]]; then
      minimal_scope_lines+=("- declared directory $scope_alias: $scope_path; cite descendants by their repo-relative path under $scope_alias")
    else
      minimal_scope_lines+=("- declared file with exact citation alias $scope_alias: $scope_path")
    fi
  done

  workdir=$(mktemp -d "/tmp/luna-minimal.XXXXXX")
  case "$workdir" in
    "$root"|"$root"/*)
      rm -rf "$workdir"
      die "minimal-context workdir must be outside the repo"
      ;;
  esac
  skip_git_repo_check=(--skip-git-repo-check)
  cleanup_paths+=("$workdir")
fi

if [[ "$gcp_monitoring" -eq 1 ]]; then
  workdir="$root/tmp/codex-luna/gcp-monitoring/$timestamp-$slug"
  gcloud_config="$workdir/gcloud-config"
  mkdir -p "$gcloud_config"
  source_gcloud_config="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
  [[ -d "$source_gcloud_config" ]] || die "gcloud config directory not found: $source_gcloud_config"
  (cd "$source_gcloud_config" && tar --exclude='logs' -cf - .) | (cd "$gcloud_config" && tar -xf -)
  chmod -R go-rwx "$gcloud_config" 2>/dev/null || true
  sandbox_mode="workspace-write"
  if [[ "$gcp_monitoring_network" -eq 1 ]]; then
    bypass_sandbox=1
    repo_status_before="$workdir/repo-status-before.z"
    git -C "$root" status --porcelain=v1 -z > "$repo_status_before"
  fi
  skip_git_repo_check=(--skip-git-repo-check)
  extra_env=(CLOUDSDK_CONFIG="$gcloud_config" PYTHONPATH="$root${PYTHONPATH:+:$PYTHONPATH}")
  cleanup_paths+=("$workdir")
fi

if [[ "$minimal_context" -eq 1 ]]; then
  minimal_scope=$(printf '%s\n' "${minimal_scope_lines[@]}")
  luna_prompt=$(cat <<EOF
You are GPT-6-Luna running as a bounded read-only scout for Codex.
The parent has already loaded and owns the project repository workflow.
Stay within the declared task/evidence scope below. Do not discover or load
repository instructions, skills, or other files. This scope is prompt guidance,
not a filesystem read allowlist: read-only sandboxing blocks writes but may
still permit reads of host-accessible files. Do not edit files, use network, or
run validation. Preserve original source line numbers when reading excerpts,
for example with nl -ba. Cite a declared file using its exact alias. For a
declared directory, cite each descendant by its repo-relative path under that
directory. Never cite an absolute path or parent-checkout-relative path.
Mark materially requested but unproven facts Pending Verification. Do not add
Pending Verification merely because the parent intentionally bounded scope.
If the task needs auth, migrations, data safety, implementation, final review,
or architecture judgment, stop and return it to the parent.

Declared scope:
$minimal_scope

Scout request:
$prompt
EOF
)
elif [[ "$gcp_monitoring" -eq 1 ]]; then
  luna_prompt=$(cat <<EOF
You are GPT-6-Luna running as a bounded read-only GCP monitoring
scout for Codex in the project repository. The parent gave you a
disposable writable working directory only so gcloud can refresh its local
config/cache. In network operator mode, the sandbox is bypassed only so Google
API DNS/network works. Do not edit repo files. Do not write outside this
working directory. Do not print tokens, secrets, DSNs, raw environment values,
auth headers, or full logs. Run only read-only inventory, logging, monitoring,
and read-only SQL checks requested by the parent. Do not execute, cancel,
rerun, or mutate Cloud Run jobs. Do not mutate SQL, secrets, IAM, or
infrastructure.
Return concise summarized evidence and mark unproven scope as Pending
Verification. The parent owns all GO/NO-GO, abort, cleanup, and data-safety
decisions.

Monitoring request:
$prompt
EOF
)
elif [[ "$github_readonly" -eq 1 ]]; then
  luna_prompt=$(cat <<EOF
You are GPT-6-Luna running as a bounded GitHub read-only scout for
Codex in the project repository. Read repo.md first. You may use
read-only GitHub evidence supplied by the parent and read-only commands such as
gh pr view, gh run list, gh run view, gh api GET requests, and local rg/file
reads. Do not mutate GitHub. Do not post comments, submit reviews, request
reviewers, edit PR metadata, rerun or cancel workflows, merge, close, resolve
threads, create branches, push, or write repo files. Do not print tokens,
cookies, auth headers, raw credential-bearing output, or huge logs.

Keep the task bounded to the requested PR, head SHA, run, review state, or
evidence packet. Treat stale head evidence as stale. Return concise summarized
evidence with URLs, IDs, check names, or file:line references when available.
Mark unsearched or unproven scope as Pending Verification. The parent owns
final GitHub judgment, comment interpretation, fixes, reruns, PR-body updates,
and ready/green/fixed/complete wording.

GitHub read-only scout request:
$prompt
EOF
)
else
  luna_prompt=$(cat <<EOF
You are GPT-6-Luna running as a read-only scout for Codex in the
project repository. Read repo.md first. Keep the task bounded. Use rg and
targeted file reads. Do not edit files. Return concise evidence with file:line
references. Mark unsearched or unproven scope as Pending Verification. If the
task needs deep reasoning, implementation, final review, migrations, auth, data
safety, or architecture judgment, say that the parent should handle it.

Scout request:
$prompt
EOF
)
fi

cleanup() {
  if [[ ${#cleanup_paths[@]} -gt 0 ]]; then
    rm -rf "${cleanup_paths[@]}"
  fi
}
trap cleanup EXIT

sandbox_args=(--sandbox "$sandbox_mode")
if [[ "$bypass_sandbox" -eq 1 ]]; then
  sandbox_args=(--dangerously-bypass-approvals-and-sandbox)
fi

codex_cmd=(
  timeout "$timeout_sec"
  env -u OPENAI_API_KEY "${extra_env[@]}"
  codex
  --ask-for-approval never
  exec
  --cd "$workdir"
  "${skip_git_repo_check[@]}"
  "${sandbox_args[@]}"
  --model gpt-6-luna
  --config 'model_reasoning_effort="high"'
  --config 'model_reasoning_summary="none"'
  --output-last-message "$output"
  --json
  "$luna_prompt"
)

if ! "${codex_cmd[@]}" > "$events_output" 2>&1; then
  if [[ "$gcp_monitoring" -eq 1 ]]; then
    rm -f "$events_output"
    printf 'Luna GCP monitoring call failed; raw events were deleted; final output is %s if present\n' "$output" >&2
  else
    cat "$events_output" >&2
  fi
  exit 1
fi

if [[ "$bypass_sandbox" -eq 1 ]]; then
  repo_status_after="$workdir/repo-status-after.z"
  git -C "$root" status --porcelain=v1 -z > "$repo_status_after"
  if ! cmp -s "$repo_status_before" "$repo_status_after"; then
    printf 'warning: repo status changed during Luna network monitoring; inspect git status before continuing\n' >&2
  fi
fi

if [[ "$gcp_monitoring" -eq 1 ]]; then
  rm -f "$events_output"
fi

if [[ "$minimal_context" -eq 1 ]]; then
  printf 'Minimal context uses declared prompt scope, not a filesystem read allowlist. Inspect command events in %s and reject observed out-of-scope reads.\n' "$events_output" >&2
fi

cat "$output"
