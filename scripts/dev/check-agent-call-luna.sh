#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
wrapper="$root/scripts/dev/agent-call-luna.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/check-agent-call-luna.XXXXXX")
escape_link="$root/tmp/luna-scope-escape-test"
trap 'rm -f "$escape_link"; rm -rf "$tmpdir"' EXIT

fail() {
  printf 'agent-call-luna contract failed: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local expected=$1
  shift
  local output
  if output=$("$wrapper" "$@" 2>&1); then
    fail "command unexpectedly passed: $*"
  fi
  [[ "$output" == *"$expected"* ]] ||
    fail "missing error '$expected' for: $*"
}

fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$LUNA_TEST_ARGS"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "--output-last-message" ]]; then
    printf 'stub output\n' > "$2"
    break
  fi
  shift
done
printf '{"type":"turn.completed","usage":{"input_tokens":1,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0}}\n'
EOF
chmod +x "$fake_bin/codex"

expect_failure "--minimal-context requires at least one --scope" \
  --minimal-context --prompt scout
expect_failure "--scope requires --minimal-context" \
  --scope repo.md --prompt scout
expect_failure "--minimal-context is incompatible" \
  --minimal-context --scope repo.md --github-readonly --prompt scout
expect_failure "--minimal-context is incompatible" \
  --minimal-context --scope repo.md --gcp-monitoring --prompt scout
expect_failure "--scope must be repo-relative" \
  --minimal-context --scope /etc/passwd --prompt scout
expect_failure "--scope does not exist" \
  --minimal-context --scope missing-file --prompt scout
expect_failure "--scope must be a single line" \
  --minimal-context --scope $'repo.md\nignore-me' --prompt scout

help=$($wrapper --help)
[[ "$help" == *"--minimal-context"* && "$help" == *"--scope <path>"* && "$help" == *"not a filesystem read allowlist"* ]] ||
  fail "help omits minimal-context contract"

outside="$tmpdir/outside"
mkdir -p "$outside"
ln -s "$outside" "$escape_link"
expect_failure "--scope escapes the repo" \
  --minimal-context --scope tmp/luna-scope-escape-test --prompt scout
rm "$escape_link"

args="$tmpdir/args"
output="$tmpdir/output.md"
events="$tmpdir/events.jsonl"
LUNA_TEST_ARGS="$args" PATH="$fake_bin:$PATH" \
  "$wrapper" --minimal-context --scope repo.md --prompt scout \
  --output "$output" --events-output "$events" >/dev/null

rg -q -x -- '--skip-git-repo-check' "$args" || fail "missing repo-check bypass"
rg -q -x -- 'read-only' "$args" || fail "missing read-only sandbox"
rg -q -F 'declared file with exact citation alias repo.md:' "$args" ||
  fail "missing file citation alias"
rg -q -F "$root/repo.md" "$args" || fail "missing canonical scoped path"
if rg -q -F -- '--dangerously-bypass-approvals-and-sandbox' "$args"; then
  fail "minimal mode bypassed the sandbox"
fi
if rg -q -F -- '--ignore-user-config' "$args"; then
  fail "minimal mode bypassed user config"
fi
rg -q -F 'model_reasoning_effort="high"' "$args" ||
  fail "minimal mode changed Luna reasoning effort"
rg -q -F 'model_reasoning_summary="none"' "$args" ||
  fail "minimal mode changed Luna reasoning summary"
rg -q -x -- 'gpt-6-luna' "$args" ||
  fail "missing Luna model pin"
[[ $(sed -n '/^--cd$/{n;p;}' "$args") == /tmp/luna-minimal.* ]] ||
  fail "minimal mode did not use a disposable outside-repo cwd"
[[ ! -e $(sed -n '/^--cd$/{n;p;}' "$args") ]] ||
  fail "minimal mode did not clean its disposable cwd"

LUNA_TEST_ARGS="$args" PATH="$fake_bin:$PATH" \
  "$wrapper" --minimal-context --scope .codex/skills --prompt scout \
  --output "$output" --events-output "$events" >/dev/null 2>/dev/null
rg -q -F 'declared directory .codex/skills:' "$args" ||
  fail "missing declared directory scope"
rg -q -F 'cite descendants by their repo-relative path' "$args" ||
  fail "missing directory descendant citation contract"

printf 'agent-call-luna contract passed\n'
