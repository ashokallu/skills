#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  scripts/dev/run-backend-ci-checks.sh <worktree-path> [--all|--setup|--lint|--test|--validate|--cover] [--base <ref>]

Runs local backend PR CI parity checks from one clean worktree.

Modes:
  --all       Run setup, lint, test, and validate. This is the default.
  --setup     Run go.mod tidy drift check.
  --lint      Run the workflow-pinned golangci-lint from backend/bin.
  --test      Run the race/Testcontainers backend test command.
  --validate  Run migration order, generated-source drift, and build checks.
  --cover     Run head coverage. With --base <ref>, also generate local cover diff.

This is a push-grade helper. The target worktree must have clean tracked state.
Coverage artifacts are written outside the target worktree under tmp/.
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

run_step() {
  local name="$1"
  shift

  printf '\n==> %s\n' "$name"
  "$@"
}

ensure_clean_tracked() {
  local worktree="$1"
  local status

  status="$(git -C "$worktree" status --short --untracked-files=no)"
  [[ -z "$status" ]] || {
    printf '%s\n' "$status" >&2
    die "target worktree has tracked changes; commit/stash/revert them before push-grade backend CI parity"
  }
}

ensure_no_tracked_diff() {
  local worktree="$1"
  local context="$2"

  if ! git -C "$worktree" diff --quiet; then
    printf 'tracked files changed during %s:\n' "$context" >&2
    git -C "$worktree" diff --name-only >&2
    die "${context} produced tracked diff"
  fi
}

extract_tool_pin() {
  local workflow="$1"
  local module="$2"
  local pin

  pin="$(
    sed -n -E "s#^[[:space:]]*go install ${module}@(v[0-9]+(\\.[0-9]+){1,3}).*#\\1#p" "$workflow" |
      head -n1
  )"
  [[ -n "$pin" ]] || die "could not parse ${module} pin from ${workflow}"
  printf '%s' "$pin"
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
  local expected
  local actual

  [[ -f "$go_mod" ]] || die "missing backend Go module file: ${go_mod}"

  expected="$(extract_go_minor_from_mod "$go_mod")"
  actual="$(go_minor_from_binary)"

  [[ -n "$expected" ]] || die "could not parse Go version from ${go_mod}"
  [[ -n "$actual" ]] || die "could not parse current Go version from: $(go version)"
  [[ "$actual" == "$expected" ]] ||
    die "current Go ${actual} does not match backend/go.mod Go ${expected}; cannot claim backend CI parity"
}

install_tool() {
  local worktree="$1"
  local module="$2"
  local version="$3"
  local binary="$4"
  local backend="${worktree}/backend"

  mkdir -p "${backend}/bin" "${backend}/.gopath"
  GOBIN="${backend}/bin" GOPATH="${backend}/.gopath" go install "${module}@${version}"
  [[ -x "${backend}/bin/${binary}" ]] || die "expected tool was not installed: ${backend}/bin/${binary}"
}

docker_preflight() {
  require_cmd docker
  docker info >/dev/null 2>&1 ||
    die "Docker is unavailable; Testcontainers backend CI checks are blocked by local setup"
}

run_setup() {
  local worktree="$1"
  local backend="${worktree}/backend"

  (cd "$backend" && go mod tidy)
  git -C "$worktree" diff --exit-code -- backend/go.mod backend/go.sum
}

run_lint() {
  local worktree="$1"
  local backend="${worktree}/backend"

  [[ -x "${backend}/bin/golangci-lint" ]] ||
    die "missing worktree-local golangci-lint; readiness helper should have installed it"
  (cd "$backend" && ./bin/golangci-lint run ./... --path-mode=abs)
}

run_test() {
  local worktree="$1"
  local backend="${worktree}/backend"

  docker_preflight
  (cd "$backend" && env CGO_ENABLED=1 ENABLE_TESTCONTAINERS=1 go test -shuffle=on -race ./...)
}

run_validate() {
  local worktree="$1"
  local backend="${worktree}/backend"
  local workflow="${worktree}/.github/workflows/backend-validate.yml"
  local mockery_version
  local sqlc_version

  mockery_version="$(extract_tool_pin "$workflow" "github.com/vektra/mockery/v3")"
  sqlc_version="$(extract_tool_pin "$workflow" "github.com/sqlc-dev/sqlc/cmd/sqlc")"

  (cd "$backend" && ./migrations-check.sh internal/shared/sql/migrations)
  install_tool "$worktree" "github.com/vektra/mockery/v3" "$mockery_version" "mockery"
  install_tool "$worktree" "github.com/sqlc-dev/sqlc/cmd/sqlc" "$sqlc_version" "sqlc"

  (cd "$backend" && PATH="${backend}/bin:${PATH}" go generate ./...)
  ensure_no_tracked_diff "$worktree" "go generate"
  (cd "$backend" && go build -v ./...)
}

coverage_command() {
  local output="$1"

  env ENABLE_TESTCONTAINERS=1 go test -cover ./... |
    grep -v "no test files" |
    awk '{printf "%s b %d\n", $2, $5}' |
    sed -e 's/%//' >"$output"
}

coverage_base_command() {
  local output="$1"

  env ENABLE_TESTCONTAINERS=1 go test -cover ./... |
    grep -v "no test files" |
    awk '{printf "%s a %d\n", $2, $5}' |
    sed -e 's/%//' >"$output"
}

generate_cover_diff() {
  local new_cover="$1"
  local old_cover="$2"
  local diff_file="$3"

  {
    echo "Test coverage changes:"
    echo "| Package | Before | After | Diff |"
    echo "| :--- | :---: | :---: | :---: |"
    awk '
    END {
      for (pkg in pkgs) {
        if (!A[pkg, "b"]) continue;
        shortPkg = pkg;
        if (A[pkg, "a"] != A[pkg, "b"]) {
          printf "| %s | %s% | %s% | %s |\n", shortPkg, A[pkg, "a"]?A[pkg, "a"]:":new:", A[pkg, "b"], (A[pkg, "a"] > A[pkg, "b"]) ? ":x:" : ":white_check_mark:"
        };
      }
    }
    {
      pkgs[$1]=1;
      A[$1, $2]=$3;
    }' "$new_cover" "$old_cover"
  } >"$diff_file"
}

run_cover() {
  local worktree="$1"
  local base_ref="$2"
  local artifact_dir
  local backend="${worktree}/backend"

  docker_preflight
  artifact_dir="$(mktemp -d "${repo_root}/tmp/backend-ci-cover.XXXXXX")"
  printf 'coverage artifacts: %s\n' "$artifact_dir"

  (cd "$backend" && coverage_command "${artifact_dir}/new.cover")

  if [[ -n "$base_ref" ]]; then
    local base_tree="${artifact_dir}/base"
    git -C "$repo_root" worktree add --detach "$base_tree" "$base_ref" >/dev/null
    trap 'git -C "'"$repo_root"'" worktree remove --force "'"$base_tree"'" >/dev/null 2>&1 || true' RETURN
    enforce_go_version "$base_tree"
    (cd "${base_tree}/backend" && coverage_base_command "${artifact_dir}/old.cover")
    generate_cover_diff "${artifact_dir}/new.cover" "${artifact_dir}/old.cover" "${artifact_dir}/diff"
    cat "${artifact_dir}/diff"
    git -C "$repo_root" worktree remove --force "$base_tree" >/dev/null
    trap - RETURN
  fi
}

main() {
  [[ "$#" -ge 1 ]] || {
    usage >&2
    return 2
  }

  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    return 0
  fi

  local worktree="$1"
  shift

  local run_setup_flag=0
  local run_lint_flag=0
  local run_test_flag=0
  local run_validate_flag=0
  local run_cover_flag=0
  local base_ref=""
  local explicit_mode=0

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --all)
        run_setup_flag=1
        run_lint_flag=1
        run_test_flag=1
        run_validate_flag=1
        explicit_mode=1
        shift
        ;;
      --setup)
        run_setup_flag=1
        explicit_mode=1
        shift
        ;;
      --lint)
        run_lint_flag=1
        explicit_mode=1
        shift
        ;;
      --test)
        run_test_flag=1
        explicit_mode=1
        shift
        ;;
      --validate)
        run_validate_flag=1
        explicit_mode=1
        shift
        ;;
      --cover)
        run_cover_flag=1
        explicit_mode=1
        shift
        ;;
      --base)
        [[ "$#" -ge 2 ]] || die "--base requires a ref"
        base_ref="$2"
        shift 2
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
  done

  if [[ "$explicit_mode" -eq 0 ]]; then
    run_setup_flag=1
    run_lint_flag=1
    run_test_flag=1
    run_validate_flag=1
  fi
  if [[ -n "$base_ref" && "$run_cover_flag" -ne 1 ]]; then
    die "--base is only valid with --cover"
  fi

  require_cmd git
  require_cmd go
  require_cmd awk
  require_cmd sed
  require_cmd grep
  require_cmd mktemp

  worktree="$(real_path "$worktree")"
  [[ -d "$worktree" ]] || die "worktree path does not exist: $worktree"
  [[ -d "${worktree}/backend" ]] || die "target worktree has no backend directory: $worktree"
  [[ "$(git -C "$worktree" rev-parse --show-toplevel)" == "$worktree" ]] ||
    die "target is not its own git worktree root: $worktree"

  enforce_go_version "$worktree"
  "${repo_root}/scripts/dev/prepare-worktree-readiness.sh" "$worktree" >/dev/null
  ensure_clean_tracked "$worktree"

  [[ "$run_setup_flag" -eq 1 ]] && run_step "setup: go.mod tidy drift" run_setup "$worktree"
  [[ "$run_lint_flag" -eq 1 ]] && run_step "lint: golangci-lint" run_lint "$worktree"
  [[ "$run_test_flag" -eq 1 ]] && run_step "test: race with Testcontainers" run_test "$worktree"
  [[ "$run_validate_flag" -eq 1 ]] && run_step "validate: migrations, generate, build" run_validate "$worktree"
  [[ "$run_cover_flag" -eq 1 ]] && run_step "cover: backend coverage" run_cover "$worktree" "$base_ref"

  ensure_clean_tracked "$worktree"
  printf '\nbackend CI parity checks passed for %s\n' "$worktree"
}

main "$@"
