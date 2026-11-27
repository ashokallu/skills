#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
wrapper="$root/scripts/dev/agent-call-muse.sh"
guard="$root/scripts/dev/muse-git-guard.sh"
proxy="$root/scripts/dev/muse-meta-connect-proxy.mjs"
controller="$root/scripts/dev/muse-msp/muse-msp-controller.mjs"
cleanup_script="$root/scripts/dev/clean-agent-call-muse.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/check-agent-call-muse.XXXXXX")
test_prompt="$tmpdir/prompt.txt"
printf 'test\n' >"$test_prompt"
test_worktree="$root/tmp/worktrees/check-agent-call-muse-$$"
cleanup_run="$root/tmp/codex-claude/calls/20990101T000000Z-muse-cleanup-contract-$$"
unsafe_alias_state="$root/tmp/codex-claude/state/muse-session-unsafe-state-$$"
mkdir -p "$root/tmp/codex-claude/calls" "$root/tmp/codex-claude/state"

cleanup() {
  if git -C "$root" worktree list --porcelain | rg -q -F "worktree $test_worktree"; then
    git -C "$root" worktree remove --force "$test_worktree" >/dev/null
  fi
  if [[ -d "$cleanup_run" && ! -L "$cleanup_run" ]]; then
    find "$cleanup_run" -depth -mindepth 1 -delete
    rmdir "$cleanup_run"
  fi
  [[ ! -L "$unsafe_alias_state" ]] || unlink "$unsafe_alias_state"
  find "$tmpdir" -depth -mindepth 1 -delete
  rmdir "$tmpdir"
}
trap cleanup EXIT

fail() {
  printf 'agent-call-muse contract failed: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local expected=$1
  shift
  local command_output
  if command_output=$("$wrapper" "$@" 2>&1); then
    fail "command unexpectedly passed: $*"
  fi
  [[ "$command_output" == *"$expected"* ]] ||
    fail "missing error '$expected' for: $*; got: $command_output"
}

git -C "$root" worktree add --detach "$test_worktree" HEAD >/dev/null

expect_failure "--role must be" --role nope --prompt-file "$test_prompt"
expect_failure "requires --confirm-contributor-data-use" \
  --role contributor --context-class private-approved --prompt-file "$test_prompt"
expect_failure "prompt text must not appear in process arguments" --prompt test
expect_failure "was removed" --allow-sensitive-context --prompt-file "$test_prompt"
expect_failure "artifacts use a new repository-owned run directory" \
  --target-class public --output "$tmpdir/output.md" --prompt-file "$test_prompt"
calls_before=$(find "$root/tmp/codex-claude/calls" -mindepth 1 -maxdepth 1 -type d | wc -l)
expect_failure "sandbox preflight failed" --target-class public --muse-bin /bin/true --prompt-file "$test_prompt"
calls_after=$(find "$root/tmp/codex-claude/calls" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ "$calls_after" -eq "$calls_before" ]] || fail "preflight failure stranded an incomplete Muse run directory"
expect_failure "valid only with --role researcher" --enable-native-web \
  --target-class public --prompt-file "$test_prompt"
expect_failure "requires --context-class public" --role researcher \
  --enable-native-web --context-class private-approved --confirm-contributor-data-use --prompt-file "$test_prompt"
expect_failure "non-public or unknown mounted target requires" --role researcher \
  --enable-native-web --context-class public --target-class internal --prompt-file "$test_prompt"
expect_failure "session continuity requires both" --role workhorse \
  --worktree-existing "$test_worktree" --context-class private-approved \
  --confirm-contributor-data-use --resume 11111111-1111-4111-8111-111111111111 --prompt-file "$test_prompt"
expect_failure "no isolated Muse state exists for exact session" --role contributor \
  --target-class public --resume 22222222-2222-4222-8222-222222222222 --prompt-file "$test_prompt"
ln -s "$test_prompt" "$unsafe_alias_state"
expect_failure "Muse state file must not be a symlink" --role reviewer \
  --target-class public --resume alias:unsafe-state-$$ --prompt-file "$test_prompt"
unlink "$unsafe_alias_state"

prompt_link="$tmpdir/prompt-link.txt"
ln -s "$test_prompt" "$prompt_link"
expect_failure "--prompt-file must not be a symlink" --target-class public --prompt-file "$prompt_link"
forbidden_prompt="$tmpdir/.env"
printf 'not-a-real-secret\n' >"$forbidden_prompt"
expect_failure "forbidden secret/private-data class" --target-class public --prompt-file "$forbidden_prompt"
large_prompt="$tmpdir/large-prompt.txt"
truncate -s 1048577 "$large_prompt"
expect_failure "exceeds the 1 MiB prompt limit" --target-class public --prompt-file "$large_prompt"
binary_prompt="$tmpdir/binary-prompt.txt"
printf '\377' >"$binary_prompt"
expect_failure "must be valid UTF-8 text" --target-class public --prompt-file "$binary_prompt"
nul_prompt="$tmpdir/nul-prompt.txt"
printf 'before\000after\n' >"$nul_prompt"
expect_failure "must not contain NUL bytes" --target-class public --prompt-file "$nul_prompt"

small_context_args=()
for ordinal in {1..17}; do
  fixture="$tmpdir/context-$ordinal.txt"
  printf 'fixture %s\n' "$ordinal" >"$fixture"
  small_context_args+=(--context-file "$fixture")
done
expect_failure "at most 16 files" --target-class public --prompt-file "$test_prompt" "${small_context_args[@]}"

large_context="$tmpdir/large-context.txt"
truncate -s 1048577 "$large_context"
expect_failure "exceeds the 1 MiB per-file limit" --target-class public \
  --prompt-file "$test_prompt" --context-file "$large_context"

total_context_args=()
for ordinal in {1..5}; do
  fixture="$tmpdir/total-context-$ordinal.txt"
  truncate -s 1048576 "$fixture"
  total_context_args+=(--context-file "$fixture")
done
expect_failure "exceeds the 4 MiB total limit" --target-class public \
  --prompt-file "$test_prompt" "${total_context_args[@]}"

symlink_context="$tmpdir/context-link.txt"
ln -s "$tmpdir/context-1.txt" "$symlink_context"
expect_failure "must not be a symlink" --target-class public \
  --prompt-file "$test_prompt" --context-file "$symlink_context"

binary_context="$tmpdir/non-utf8.txt"
printf '\377' >"$binary_context"
expect_failure "must be valid UTF-8 text" --target-class public \
  --prompt-file "$test_prompt" --context-file "$binary_context"

invalid_source="$tmpdir/source.txt"
printf 'missing provenance\n' >"$invalid_source"
expect_failure "Source-URL" --role researcher --target-class public \
  --prompt-file "$test_prompt" --source-file "$invalid_source"

rg -q -- '--api-key-stdin' "$wrapper" || fail "wrapper does not use Muse stdin credential transport"
rg -q 'env -i PATH=/usr/bin:/bin' "$wrapper" || fail "wrapper does not launch from a clean environment"
rg -q 'Muse owned directory is missing or symlinked' "$wrapper" ||
  fail "wrapper does not reject symlinked artifact/state roots"
rg -q 'Muse state file must not be a symlink' "$wrapper" ||
  fail "wrapper does not reject symlinked session metadata"
rg -q 'per-run Muse control snapshot changed during preflight' "$wrapper" ||
  fail "wrapper does not bind execution to per-run control snapshots"
rg -q 'meta_proxy_sha256: \$sandbox_meta_proxy_sha256' "$wrapper" ||
  fail "run manifest does not record the pinned Meta proxy identity"
if rg -q '\.\.\.process\.env' "$controller"; then
  fail "dormant MSP startup still inherits ambient process environment"
fi
rg -q 'meta_base_url=https://api.meta.ai/v1' "$wrapper" || fail "wrapper does not pin the Meta base URL"
# Load only the preflight's pure helpers; do not run its probes for version cases.
# shellcheck disable=SC1090
source <(sed '/^root=$(git rev-parse --show-toplevel)/,$d' "$root/scripts/dev/check-muse-linux-sandbox.sh")
for candidate in 1.0.3-R2198.1 1.0.3-R2198.2 1.1.1-R2514.1 1.10.0-R1 2.0.0-R1; do
  version_at_least "$candidate" 1.0.3-R2198.1 || fail "new enough version rejected: $candidate"
done
for candidate in 1.0.2-R9999.9 1.0.3-R2198 1.0.3-R2197.9 garbage 1.1.1-R2514.1-beta; do
  if version_at_least "$candidate" 1.0.3-R2198.1; then fail "old/malformed version accepted: $candidate"; fi
done
version_at_least 1.1.1-R2514 1.1.1-R2514.0 || fail "implicit revision patch comparison failed"
rg -q 'native Muse web requires --target-class public' "$wrapper" || fail "public target gate is missing"
rg -q 'non-public or unknown mounted target requires --context-class private-approved' "$wrapper" ||
  fail "non-public target context gate is missing"
rg -q 'session_durability=.*lane_scoped_retained.*unretained' "$wrapper" ||
  fail "ordinary calls are not explicitly unretained"
rg -q 'payload.event.task_kind' "$wrapper" || fail "structured web invocation parser is missing"
rg -q 'payload.correlation_facts.tool_name' "$wrapper" || fail "structured web result parser is missing"
if rg -q -- '--ro-bind / /' "$guard"; then
  fail "guard still exposes the whole host read-only"
fi
rg -q -- '--ro-bind /usr /usr' "$guard" || fail "guard runtime allowlist is missing /usr"
rg -q -- '--clearenv' "$guard" || fail "guard does not clear launcher-only environment metadata"
rg -q -- '--unshare-pid' "$guard" || fail "guard does not isolate Muse from host process metadata"
rg -q 'ALLOWED_AUTHORITY = "api.meta.ai:443"' "$proxy" || fail "proxy authority is not exact"

ready="$tmpdir/proxy-ready.json"
proxy_log="$tmpdir/proxy-events.jsonl"
proxy_stderr="$tmpdir/proxy.stderr"
node "$proxy" --ready-file "$ready" --log-file "$proxy_log" 2>"$proxy_stderr" &
proxy_pid=$!
for _ in {1..100}; do
  [[ -s "$ready" ]] && break
  sleep 0.02
done
[[ -s "$ready" ]] || fail "proxy did not become ready"
proxy_port=$(jq -r .port "$ready")
curl -sS -o /dev/null --max-time 5 --proxy "http://127.0.0.1:$proxy_port" \
  https://example.com >/dev/null 2>&1 || true
kill -TERM "$proxy_pid"
wait "$proxy_pid" || true
jq -e 'select(.outcome == "rejected_authority" and .authority == "example.com:443")' \
  "$proxy_log" >/dev/null || fail "proxy did not reject a foreign CONNECT authority"

prompt_file="$tmpdir/msp-prompt.txt"
printf 'test\n' >"$prompt_file"
set +e
msp_output=$(node "$controller" --worktree-existing "$test_worktree" \
  --prompt-file "$prompt_file" 2>&1)
msp_status=$?
set -e
[[ "$msp_status" -ne 0 && "$msp_output" == *"live Meta MSP is disabled"* ]] ||
  fail "MSP did not fail closed before live Meta startup"

mkdir -p "$cleanup_run"
printf '{"outcome":"completed"}\n' >"$cleanup_run/run.json"
"$cleanup_script" --run "$cleanup_run" --apply >/dev/null
[[ ! -e "$cleanup_run" ]] || fail "exact private-run cleanup did not remove its owned run"

node --test "$root/scripts/dev/muse-msp/test/controller.test.mjs" >/dev/null
# Assert the reporting contract, not this host's readiness. Namespace
# readiness is a host fact that legitimately varies (a host enforcing
# kernel.apparmor_restrict_unprivileged_userns denies the bundled backend), so
# pinning "ready" here would encode one machine's policy as a repository
# invariant. Capability and namespace results must stay separate, and neither
# may be reported as proof of inner managed-shell operation.
sandbox_json=$("$root/scripts/dev/check-muse-linux-sandbox.sh" --json)
jq -e '(.status | IN("ready", "blocked_selected_outer_backend",
      "blocked_no_usable_outer_backend")) and
    .backend == "muse_bundled_bwrap" and
    .capability_probe == "ok" and
    (.namespace_probe.bundled | IN("ok", "denied", "failed")) and
    (.namespace_probe.system_bwrap | IN("ok", "denied", "failed", "absent")) and
    (.outer_backend_selected | IN("muse_bundled_bwrap", "system_bwrap")) and
    .inner_backend == "muse_bundled_bwrap" and
    .inner_managed_shell_proven == false and
    (.meta_proxy_sha256 | length) == 64' <<<"$sandbox_json" >/dev/null ||
  fail "sandbox preflight did not report the separated capability/namespace contract"

python3 -m unittest discover -s "$root/scripts/dev" -p 'test_muse_sandbox.py'

# Exercise the complete guard and real Muse CLI without credentials or provider
# traffic. Capability help and a bare namespace probe cannot prove this launch.
if [[ "$(jq -r .status <<<"$sandbox_json")" == ready ]]; then
  echo_target="$tmpdir/echo-target"
  git init -q "$echo_target"
  printf 'MUSE_SANDBOX_ECHO_OK\n' >"$tmpdir/echo-prompt.txt"
  cat >"$tmpdir/inner-bwrap" <<'BRIDGE'
#!/bin/sh
export TBH_INTERNAL_MODE=bwrap
exec /opt/muse-guard/muse __tbh_internal_bwrap "$@"
BRIDGE
  chmod 700 "$tmpdir/inner-bwrap"
  outer_bwrap=$(jq -r .selector <<<"$sandbox_json")
  if [[ "$(jq -r .outer_backend_selected <<<"$sandbox_json")" == system_bwrap ]]; then
    outer_bwrap=/usr/bin/bwrap
  fi
  timeout 30 env -i PATH=/usr/bin:/bin LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    MUSE_GIT_GUARD_ELF="$(jq -r .binary <<<"$sandbox_json")" \
    MUSE_GIT_GUARD_VERSION="$(jq -r .version <<<"$sandbox_json")" \
    MUSE_GIT_GUARD_SHA256="$(jq -r .sha256 <<<"$sandbox_json")" \
    MUSE_GIT_GUARD_BWRAP="$outer_bwrap" \
    MUSE_GIT_GUARD_WORKTREE="$echo_target" \
    MUSE_GIT_GUARD_COMMON_DIR="$echo_target/.git" \
    MUSE_GIT_GUARD_TARGET_MODE=ro \
    MUSE_GIT_GUARD_PROMPT_FILE="$tmpdir/echo-prompt.txt" \
    MUSE_GIT_GUARD_INNER_BWRAP="$tmpdir/inner-bwrap" \
    MUSE_GIT_GUARD_HTTPS_PROXY=http://127.0.0.1:9 \
    "$guard" exec --json --provider echo --workspace "$echo_target" \
      --approval-mode never --approval-judge off --no-foreign-personal-context \
      --no-session-log --disable-shell --disable-write --disable-web-tools \
      --max-model-steps 1 --prompt-file /run/muse-input/prompt.txt \
      >"$tmpdir/echo-events.jsonl" 2>"$tmpdir/echo-stderr.log" || {
        cat "$tmpdir/echo-stderr.log" >&2
        fail 'guarded Muse echo launch failed after namespace admission'
      }
  jq -se 'any(.[]; .payload_type == "run.terminal.completed" and
    (.payload.text | contains("MUSE_SANDBOX_ECHO_OK")))' \
    "$tmpdir/echo-events.jsonl" >/dev/null || fail 'guarded Muse echo did not complete'
else
  printf 'guarded Muse echo launch: SKIP (host namespace unavailable)\n'
fi

printf 'agent-call-muse contract checks passed\n'
