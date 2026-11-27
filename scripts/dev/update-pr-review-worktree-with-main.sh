#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/update-pr-review-worktree-with-main.sh <worktree-path> [--base <ref>]

Locally updates a PR review worktree with current origin/main before review:
- requires a clean worktree under tmp/worktrees
- fetches origin/main when the base is origin/main
- tries rebase first
- if rebase conflicts, aborts the rebase
- falls back to a synthetic local review branch based on the base ref
- applies the PR's aggregate diff as one staged change
- records that staged tree as a local synthetic commit without running hooks
- if the aggregate diff conflicts, reports the conflicted paths and exits non-zero

This helper is for local review worktrees. It does not push or mutate GitHub.
USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

real_path() {
  local target="$1"

  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  else
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$target"
  fi
}

ensure_clean_worktree() {
  local worktree="$1"
  local short_status

  short_status="$(git -C "$worktree" status --short)"
  [[ -z "$short_status" ]] || {
    printf '%s\n' "$short_status" >&2
    die "target worktree has local changes; commit, stash, or revert them before updating with the base"
  }
}

unmerged_paths() {
  local worktree="$1"

  git -C "$worktree" diff --name-only --diff-filter=U
}

sanitize_branch_component() {
  printf '%s' "$1" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's#[^a-z0-9._-]+#-#g; s#^-+##; s#-+$##' |
    cut -c1-80
}

apply_aggregate_diff() {
  local worktree="$1"
  local diff_base="$2"
  local source_head="$3"

  git -C "$worktree" diff --binary "${diff_base}..${source_head}" |
    git -C "$worktree" apply --3way --index
}

unstage_and_clean_conflicted_apply() {
  local worktree="$1"

  git -C "$worktree" reset --hard >/dev/null
}

create_synthetic_commit() {
  local worktree="$1"
  local parent="$2"
  local source_head="$3"
  local tree
  local commit

  tree="$(git -C "$worktree" write-tree)"
  commit="$(
    printf 'chore: apply PR aggregate diff for local review\n\nSource head: %s\n' "$source_head" |
      git -C "$worktree" commit-tree "$tree" -p "$parent"
  )"
  git -C "$worktree" reset --hard "$commit" >/dev/null
}

base_ref="origin/main"
worktree_arg=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      base_ref="${2:-}"
      [[ -n "$base_ref" ]] || die "missing value for --base"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ -z "$worktree_arg" ]] || die "expected one worktree path"
      worktree_arg="$1"
      shift
      ;;
  esac
done

[[ -n "$worktree_arg" ]] || {
  usage >&2
  exit 2
}

require_cmd git

worktree="$(real_path "$worktree_arg")"
[[ -d "$worktree" ]] || die "worktree path does not exist: $worktree_arg"

allowed_prefix="${repo_root}/tmp/worktrees/"
[[ "$worktree" == "$allowed_prefix"* ]] ||
  die "refusing path outside ${allowed_prefix}: ${worktree}"

git_top="$(git -C "$worktree" rev-parse --show-toplevel)"
[[ "$git_top" == "$worktree" ]] ||
  die "target is not its own git worktree root: ${worktree} (git top: ${git_top})"

ensure_clean_worktree "$worktree"

if [[ "$base_ref" == origin/* ]]; then
  remote_branch="${base_ref#origin/}"
  git -C "$repo_root" fetch origin "$remote_branch" --prune
fi

base_sha="$(git -C "$worktree" rev-parse "$base_ref")" ||
  die "could not resolve base ref: ${base_ref}"
head_before="$(git -C "$worktree" rev-parse HEAD)"
branch_before="$(git -C "$worktree" branch --show-current)"
diff_base="$(git -C "$worktree" merge-base "$base_ref" HEAD)"

printf 'worktree: %s\n' "$worktree"
printf 'branch: %s\n' "$branch_before"
printf 'base: %s (%s)\n' "$base_ref" "$base_sha"
printf 'diff base: %s\n' "$diff_base"
printf 'head before: %s\n' "$head_before"
printf '\n==> Trying rebase first\n'

if git -C "$worktree" rebase "$base_ref"; then
  printf '\nupdated by rebase\n'
  printf 'head after: %s\n' "$(git -C "$worktree" rev-parse HEAD)"
  git -C "$worktree" status --short --branch
  exit 0
fi

conflicts="$(unmerged_paths "$worktree" || true)"
printf '\nrebase failed; aborting rebase before aggregate-diff fallback\n' >&2
if [[ -n "$conflicts" ]]; then
  printf 'rebase conflicts:\n%s\n' "$conflicts" >&2
fi
git -C "$worktree" rebase --abort
ensure_clean_worktree "$worktree"

base_slug="$(sanitize_branch_component "$base_ref")"
source_slug="$(sanitize_branch_component "${branch_before:-review}")"
synthetic_branch="${source_slug}-${base_slug}-aggregate-review"

printf '\n==> Trying aggregate-diff fallback\n'
printf 'synthetic branch: %s\n' "$synthetic_branch"
git -C "$worktree" switch -C "$synthetic_branch" "$base_ref"

if apply_aggregate_diff "$worktree" "$diff_base" "$head_before"; then
  create_synthetic_commit "$worktree" "$base_sha" "$head_before"
  printf '\nupdated by aggregate-diff fallback\n'
  printf 'source head: %s\n' "$head_before"
  printf 'synthetic head: %s\n' "$(git -C "$worktree" rev-parse HEAD)"
  git -C "$worktree" status --short --branch
  exit 0
fi

conflicts="$(unmerged_paths "$worktree" || true)"
if [[ -n "$conflicts" ]]; then
  printf '\nblocked: aggregate-diff fallback has conflicts:\n%s\n' "$conflicts" >&2
  unstage_and_clean_conflicted_apply "$worktree"
  exit 10
fi

unstage_and_clean_conflicted_apply "$worktree"
die "aggregate-diff fallback failed without unmerged paths; inspect the command output above"
