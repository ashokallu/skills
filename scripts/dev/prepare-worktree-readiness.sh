#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/prepare-worktree-readiness.sh <worktree-path>

Prepares one project git worktree for agent work:
- bootstraps worktree-local Husky hooks
- installs the branch-pinned backend golangci-lint into backend/bin
- keeps Go module cache local to backend/.gopath and excluded from status

This script intentionally refuses paths outside this repo's tmp/worktrees.

USAGE
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

die_go_mismatch() {
  local expected="$1"
  local actual="$2"
  local worktree="$3"
  local mise_go="${HOME}/.local/share/mise/installs/go/${expected}/bin"

  printf 'error: current Go %s does not match backend/go.mod Go %s\n' "$actual" "$expected" >&2
  printf 'error: readiness must use the Go version pinned by the target worktree, not a root/global Go\n' >&2
  if [[ -x "${mise_go}/go" ]]; then
    printf 'hint: rerun readiness with the matching mise Go first on PATH:\n' >&2
    printf 'hint:   PATH="%s:$PATH" %s %s\n' "$mise_go" "$0" "$worktree" >&2
  else
    printf 'hint: install or activate Go %s for this shell, then rerun this helper for the same worktree\n' "$expected" >&2
  fi
  printf 'hint: do not install global linters or copy root-checkout binaries as worktree readiness proof\n' >&2
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

extract_golangci_version_from_file() {
  local file="$1"

  [[ -f "$file" ]] || return 0

  sed -n -E \
    's/^[[:space:]]*version:[[:space:]]*(v[0-9]+(\.[0-9]+){1,3}).*$/\1/p;
     s/^.*golangci-lint(\/v2)?\/cmd\/golangci-lint@(v[0-9]+(\.[0-9]+){1,3}).*$/\2/p' \
    "$file" | head -n1
}

extract_go_minor_from_mod() {
  local go_mod="$1"

  sed -n -E 's/^go[[:space:]]+([0-9]+\.[0-9]+)(\.[0-9]+)?.*$/\1/p' "$go_mod" | head -n1
}

go_minor_from_binary() {
  go version | sed -n -E 's/^go version go([0-9]+\.[0-9]+)(\.[0-9]+)?.*$/\1/p'
}

enforce_go_version() {
  local worktree="$1"
  local go_mod="${worktree}/backend/go.mod"

  [[ -f "$go_mod" ]] || return 0

  local expected
  local actual
  expected="$(extract_go_minor_from_mod "$go_mod")"
  actual="$(go_minor_from_binary)"

  [[ -n "$expected" ]] || die "could not parse Go version from ${go_mod}"
  [[ -n "$actual" ]] || die "could not parse current Go version from: $(go version)"
  [[ "$actual" == "$expected" ]] ||
    die_go_mismatch "$expected" "$actual" "$worktree"
}

ensure_info_exclude() {
  local worktree="$1"
  local pattern="$2"
  local exclude_path

  if git -C "$worktree" check-ignore -q "$pattern" 2>/dev/null; then
    return 0
  fi

  exclude_path="$(git -C "$worktree" rev-parse --git-path info/exclude)"
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"

  if ! grep -Fxq "$pattern" "$exclude_path"; then
    printf '%s\n' "$pattern" >>"$exclude_path"
  fi
}

main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return 0
  fi

  [[ "$#" -eq 1 ]] || {
    usage >&2
    return 2
  }

  require_cmd git
  require_cmd yarn
  require_cmd go
  require_cmd sed
  require_cmd grep

  local worktree
  worktree="$(real_path "$1")"
  [[ -d "$worktree" ]] || die "worktree path does not exist: $1"

  local allowed_prefix="${repo_root}/tmp/worktrees/"
  [[ "$worktree" == "$allowed_prefix"* ]] ||
    die "refusing path outside ${allowed_prefix}: ${worktree}"

  local git_top
  git_top="$(git -C "$worktree" rev-parse --show-toplevel)"
  [[ "$git_top" == "$worktree" ]] ||
    die "target is not its own git worktree root: ${worktree} (git top: ${git_top})"

  local hooks_path
  hooks_path="$(git -C "$worktree" config --get core.hooksPath || true)"
  if [[ "$hooks_path" != ".husky" ]]; then
    git -C "$worktree" config core.hooksPath .husky
  fi

  [[ -f "$worktree/.husky/package.json" ]] ||
    die "missing Husky package file: ${worktree}/.husky/package.json"
  yarn --cwd "$worktree/.husky" install --non-interactive --frozen-lockfile >/dev/null
  [[ -f "$worktree/.husky/_/husky.sh" ]] ||
    die "Husky bootstrap failed: ${worktree}/.husky/_/husky.sh is missing"
  hooks_path="$(git -C "$worktree" config --get core.hooksPath || true)"
  [[ "$hooks_path" == ".husky" ]] ||
    die "Husky bootstrap failed: core.hooksPath is ${hooks_path:-unset}, expected .husky"

  if [[ -d "$worktree/backend" ]]; then
    enforce_go_version "$worktree"

    local version
    version="$(
      extract_golangci_version_from_file "$worktree/.github/workflows/backend-validate.yml"
    )"
    if [[ -z "$version" ]]; then
      version="$(extract_golangci_version_from_file "$worktree/backend/tools.go")"
    fi
    [[ -n "$version" ]] || die "could not determine golangci-lint version from target worktree"

    local module_path="github.com/golangci/golangci-lint/cmd/golangci-lint"
    if [[ "$version" =~ ^v2\. ]]; then
      module_path="github.com/golangci/golangci-lint/v2/cmd/golangci-lint"
    fi

    mkdir -p "$worktree/backend/bin" "$worktree/backend/.gopath"
    ensure_info_exclude "$worktree" "backend/.gopath/"

    GOBIN="$worktree/backend/bin" GOPATH="$worktree/backend/.gopath" \
      go install "${module_path}@${version}"
    ln -sf golangci-lint "$worktree/backend/bin/golangci-lint-v2"

    local version_without_v="${version#v}"
    "$worktree/backend/bin/golangci-lint" --version | grep -F "$version_without_v" >/dev/null ||
      die "installed golangci-lint does not report expected version ${version}"
  fi

  if [[ -n "$(git -C "$worktree" status --short --untracked-files=no)" ]]; then
    git -C "$worktree" status --short --untracked-files=no >&2
    die "tracked files changed during readiness preparation"
  fi

  printf 'worktree ready: %s\n' "$worktree"
  printf 'hooksPath: %s\n' "$(git -C "$worktree" config --get core.hooksPath)"
  if [[ -x "$worktree/backend/bin/golangci-lint" ]]; then
    "$worktree/backend/bin/golangci-lint" --version
  fi
}

main "$@"
