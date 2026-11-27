#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/agent-collab-handoff.sh create --from <claude-code|codex-cli|grok-cli|muse-cli|copilot-cli> --to <claude-code|codex-cli|grok-cli|muse-cli|copilot-cli|either> --title <title> [options]
  scripts/dev/agent-collab-handoff.sh list
  scripts/dev/agent-collab-handoff.sh show [handoff-file|latest]

Options for create:
  --objective <text>       One outcome for the receiving harness.
  --scope <text>           Files, symbols, routes, commands, PR, issue, or docs involved.
  --write-owner <text>     Harness or person allowed to edit the scoped files.
  --readonly <text>        Read-only reviewers or harnesses.
  --do-not-touch <text>    Explicitly excluded files or areas.
  --acceptance <text>      Observable completion condition or validation command.
  --pending <text>         Missing fact, command, auth surface, or external claim.
  --session <text>         Session/conversation id or alias used this thread. Repeatable.
  --body-file <path>       Optional markdown body appended under "Additional Context".

Artifacts are written to tmp/codex-claude/handoffs/, which is ignored by git.
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

git_value() {
  local fallback=$1
  shift
  "$@" 2>/dev/null || printf '%s' "$fallback"
}

create_handoff() {
  local from="" to="" title="" objective="" scope="" write_owner="" read_only=""
  local do_not_touch="" acceptance="" pending="" body_file=""
  local sessions=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from=${2:-}; shift 2 ;;
      --to) to=${2:-}; shift 2 ;;
      --title) title=${2:-}; shift 2 ;;
      --objective) objective=${2:-}; shift 2 ;;
      --scope) scope=${2:-}; shift 2 ;;
      --write-owner) write_owner=${2:-}; shift 2 ;;
      --readonly) read_only=${2:-}; shift 2 ;;
      --do-not-touch) do_not_touch=${2:-}; shift 2 ;;
      --acceptance) acceptance=${2:-}; shift 2 ;;
      --pending) pending=${2:-}; shift 2 ;;
      --session) sessions+=("${2:-}"); shift 2 ;;
      --body-file) body_file=${2:-}; shift 2 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown create option: $1" ;;
    esac
  done

  [[ -n "$from" ]] || die "--from is required"
  [[ -n "$to" ]] || die "--to is required"
  [[ -n "$title" ]] || die "--title is required"

  case "$from" in
    claude-code|codex-cli|grok-cli|muse-cli|copilot-cli) ;;
    *) die "--from must be claude-code, codex-cli, grok-cli, muse-cli, or copilot-cli" ;;
  esac

  case "$to" in
    claude-code|codex-cli|grok-cli|muse-cli|copilot-cli|either) ;;
    *) die "--to must be claude-code, codex-cli, grok-cli, muse-cli, copilot-cli, or either" ;;
  esac

  if [[ -n "$body_file" && ! -f "$body_file" ]]; then
    die "--body-file does not exist: $body_file"
  fi

  local root handoff_dir state_dir timestamp slug file branch status changed
  root=$(repo_root)
  handoff_dir="$root/tmp/codex-claude/handoffs"
  state_dir="$root/tmp/codex-claude/state"
  timestamp=$(date -u '+%Y%m%dT%H%M%SZ')
  slug=$(sanitize_slug "$title")
  [[ -n "$slug" ]] || slug="handoff"
  file="$handoff_dir/$timestamp-$from-to-$to-$slug.md"

  mkdir -p "$handoff_dir"

  branch=$(git_value "unknown" git branch --show-current)
  status=$(git_value "unavailable" git status --short)
  changed=$(git_value "unavailable" git diff --name-only)
  [[ -n "$branch" ]] || branch="detached"
  [[ -n "$status" ]] || status="clean"
  [[ -n "$changed" ]] || changed="none"

  {
    printf '# %s\n\n' "$title"
    printf 'Status: ACTIONABLE\n'
    printf 'fromHarness: %s\n' "$from"
    printf 'toHarness: %s\n' "$to"
    printf 'createdUtc: %s\n\n' "$timestamp"

    printf '## Objective\n'
    printf '%s\n\n' "${objective:-Pending Verification - objective was not provided.}"

    printf '## Current State\n'
    printf -- '- Branch/worktree: `%s`\n' "$branch"
    printf -- '- Changed files:\n'
    printf '%s\n' "$changed" | sed 's/^/  - /'
    printf -- '- Git status:\n'
    printf '%s\n' "$status" | sed 's/^/  - /'
    printf -- '- Relevant commands already run: Pending Verification - not provided.\n'
    printf -- '- Key evidence: Pending Verification - not provided.\n\n'

    printf '## Collaboration Sessions\n'
    if [[ -s "$state_dir/claude-latest-session-id" ]]; then
      printf -- '- Claude latest session id: `%s`\n' "$(sed -n '1p' "$state_dir/claude-latest-session-id")"
    else
      printf -- '- Claude latest session id: Pending Verification - none recorded in `%s`.\n' "tmp/codex-claude/state/claude-latest-session-id"
    fi
    if [[ -s "$state_dir/codex-latest-session-id" ]]; then
      printf -- '- Codex latest thread id: `%s`\n' "$(sed -n '1p' "$state_dir/codex-latest-session-id")"
    else
      printf -- '- Codex latest thread id: Pending Verification - none recorded in `%s`.\n' "tmp/codex-claude/state/codex-latest-session-id"
    fi
    if [[ -s "$state_dir/grok-latest-session-id" ]]; then
      printf -- '- Grok latest session id: `%s`\n' "$(sed -n '1p' "$state_dir/grok-latest-session-id")"
    else
      printf -- '- Grok latest session id: Pending Verification - none recorded in `%s`.\n' "tmp/codex-claude/state/grok-latest-session-id"
    fi
    if [[ -s "$state_dir/muse-latest-session-id" ]]; then
      printf -- '- Muse latest session id: `%s`\n' "$(sed -n '1p' "$state_dir/muse-latest-session-id")"
    else
      printf -- '- Muse latest session id: Pending Verification - none recorded in `%s`.\n' "tmp/codex-claude/state/muse-latest-session-id"
    fi
    if [[ -s "$state_dir/copilot-latest-session-id" ]]; then
      printf -- '- Copilot latest session id/name: `%s`\n' "$(sed -n '1p' "$state_dir/copilot-latest-session-id")"
    else
      printf -- '- Copilot latest session id/name: Pending Verification - none recorded in `%s`.\n' "tmp/codex-claude/state/copilot-latest-session-id"
    fi
    for session in "${sessions[@]}"; do
      [[ -n "$session" ]] && printf -- '- Additional session: %s\n' "$session"
    done
    printf '\n'

    printf '## Scope\n'
    printf '%s\n\n' "${scope:-Pending Verification - scope was not provided.}"

    printf '## Constraints\n'
    printf -- '- Shared repo rules: AGENTS.md and repo.md apply.\n'
    printf -- '- Write owner: %s\n' "${write_owner:-Pending Verification - write owner was not provided.}"
    printf -- '- Read-only reviewers: %s\n' "${read_only:-Pending Verification - read-only reviewers were not provided.}"
    printf -- '- Do not touch: %s\n\n' "${do_not_touch:-Pending Verification - exclusions were not provided.}"

    printf '## Acceptance Criteria\n'
    printf -- '- %s\n\n' "${acceptance:-Pending Verification - acceptance criteria were not provided.}"

    printf '## Pending Verification\n'
    printf -- '- %s\n' "${pending:-None recorded by the creating harness.}"

    if [[ -n "$body_file" ]]; then
      printf '\n## Additional Context\n'
      sed 's/[[:space:]]*$//' "$body_file"
      printf '\n'
    fi
  } > "$file"

  printf '%s\n' "$file"
}

list_handoffs() {
  local root handoff_dir
  root=$(repo_root)
  handoff_dir="$root/tmp/codex-claude/handoffs"
  if [[ ! -d "$handoff_dir" ]]; then
    printf 'No handoffs found at %s\n' "$handoff_dir"
    return 0
  fi
  find "$handoff_dir" -maxdepth 1 -type f -name '*.md' | sort
}

show_handoff() {
  local target=${1:-latest}
  local root handoff_dir file
  root=$(repo_root)
  handoff_dir="$root/tmp/codex-claude/handoffs"

  if [[ "$target" == "latest" ]]; then
    file=$(find "$handoff_dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | tail -n 1)
    [[ -n "$file" ]] || die "no handoffs found at $handoff_dir"
  else
    file="$target"
  fi

  [[ -f "$file" ]] || die "handoff file not found: $file"
  sed -n '1,260p' "$file"
}

main() {
  local command=${1:-}
  case "$command" in
    create) shift; create_handoff "$@" ;;
    list) shift; list_handoffs "$@" ;;
    show) shift; show_handoff "$@" ;;
    -h|--help|"") usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
