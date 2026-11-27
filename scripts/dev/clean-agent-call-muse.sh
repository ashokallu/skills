#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/clean-agent-call-muse.sh --older-than-days <positive-integer> [--apply]
  scripts/dev/clean-agent-call-muse.sh --run <owned-run-directory> --apply

Default is dry-run. With --apply, remove only completed per-run directories
directly beneath tmp/codex-claude/calls whose run.json is older than the given
age. Symlinks, active/running runs, traversal, unexpected names, and anything
outside that exact owned directory are refused.
The exact --run form is the private-context lane closeout path and requires
--apply; it removes one completed owned run regardless of age.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

days=""
exact_run=""
apply=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --older-than-days) days=${2:-}; shift 2 ;;
    --run) exact_run=${2:-}; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if [[ -n "$exact_run" ]]; then
  [[ -z "$days" ]] || die "use --run or --older-than-days, not both"
  [[ "$apply" -eq 1 ]] || die "--run requires --apply"
else
  [[ "$days" =~ ^[1-9][0-9]*$ ]] || die "--older-than-days must be a positive integer"
fi
command -v jq >/dev/null 2>&1 || die "jq is required"

root=$(git rev-parse --show-toplevel)
root=$(realpath "$root")
calls_dir="$root/tmp/codex-claude/calls"
mkdir -p "$calls_dir"
[[ ! -L "$calls_dir" ]] || die "calls directory must not be a symlink"
[[ "$(realpath "$calls_dir")" == "$root/tmp/codex-claude/calls" ]] ||
  die "calls directory escaped the repository-owned tmp root"

while IFS= read -r -d '' symlink_entry; do
  symlink_name=${symlink_entry##*/}
  if [[ "$symlink_name" =~ ^[0-9]{8}T[0-9]{6}Z-muse-[a-z0-9._-]+-[0-9]+$ ]]; then
    die "refusing symlink candidate in owned calls directory: $symlink_entry"
  fi
done < <(find -P "$calls_dir" -mindepth 1 -maxdepth 1 -type l -print0)

removed=0
eligible=0
process_candidate() {
  local candidate=$1 resolved name manifest outcome
  [[ ! -L "$candidate" && -d "$candidate" ]] || die "refusing symlink or non-directory candidate: $candidate"
  resolved=$(realpath "$candidate")
  [[ "$resolved" == "$calls_dir/"* && "${resolved%/*}" == "$calls_dir" ]] ||
    die "cleanup candidate escaped the owned calls directory: $candidate"
  name=${resolved##*/}
  [[ "$name" =~ ^[0-9]{8}T[0-9]{6}Z-muse-[a-z0-9._-]+-[0-9]+$ ]] ||
    die "cleanup candidate has an unexpected name: $name"
  manifest="$resolved/run.json"
  [[ -f "$manifest" && ! -L "$manifest" ]] || die "cleanup candidate lacks a regular run.json: $name"
  outcome=$(jq -er '.outcome | select(. != "running")' "$manifest" 2>/dev/null || true)
  [[ -n "$outcome" ]] || die "refusing active or malformed run: $name"
  eligible=$((eligible + 1))
  if [[ "$apply" -eq 1 ]]; then
    rm -rf -- "$resolved"
    removed=$((removed + 1))
    printf 'removed %s\n' "$name"
  else
    printf 'would-remove %s outcome=%s\n' "$name" "$outcome"
  fi
}

if [[ -n "$exact_run" ]]; then
  if [[ "$exact_run" != /* ]]; then
    exact_run="$root/$exact_run"
  fi
  process_candidate "$exact_run"
else
  while IFS= read -r -d '' candidate; do
    process_candidate "$candidate"
  done < <(find -P "$calls_dir" -mindepth 1 -maxdepth 1 -type d -mtime "+$days" -print0)
fi

printf 'eligible=%s removed=%s mode=%s\n' "$eligible" "$removed" "$([[ "$apply" -eq 1 ]] && printf apply || printf dry-run)"
