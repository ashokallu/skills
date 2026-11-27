#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
wrapper="$root/scripts/dev/agent-call-grok.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/check-agent-call-grok.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'agent-call-grok contract failed: %s\n' "$*" >&2
  exit 1
}

expect_failure() {
  local expected=$1
  shift
  local output
  if output=$("$wrapper" "$@" 2>&1); then
    fail "command unexpectedly passed: $*"
  fi
  [[ "$output" == *"$expected"* ]] || fail "missing error '$expected' for: $*"
}

shellcheck "$wrapper" "$0"
help=$("$wrapper" --help)
[[ "$help" == *"parallel-search and context7_remote"* ]] || fail "help omits selected MCP set"
[[ "$help" == *"There is no --prompt option"* ]] || fail "help omits argv privacy boundary"
[[ "$help" == *"--role contributor requires"* || "$help" == *"Required with --role contributor"* ]] ||
  fail "help omits contributor admission"

rg -q -F "readonly selected_mcp_servers='context7_remote,parallel-search'" "$wrapper" ||
  fail "selected MCP registry drifted"
if rg -q -i 'gopls|codex-desktop|scripts/harness' "$wrapper"; then
  fail "wrapper retains product-specific or source-repository coupling"
fi

expect_failure "--prompt is unavailable" --prompt secret-text
expect_failure "--model must remain grok-4.6" --model grok-unreviewed --prompt-file "$root/repo.md"
expect_failure "--role contributor requires --allow-write" --role contributor --prompt-file "$root/repo.md"
expect_failure "--allow-write and --worktree-existing require --role contributor" --allow-write --prompt-file "$root/repo.md"
expect_failure "--effort must be one of" --effort impossible --prompt-file "$root/repo.md"
expect_failure "--timeout-sec must be an integer from 1 through 3600" --timeout-sec 3601 --prompt-file "$root/repo.md"
# Derive the ceiling from the wrapper instead of restating it, so a deliberate
# budget change is not indistinguishable from a regression.
turn_ceiling=$(grep -oE 'max_turns" -gt [0-9]+' \
  "$root/scripts/dev/agent-call-grok.sh" | head -1 | grep -oE '[0-9]+')
[[ "$turn_ceiling" =~ ^[0-9]+$ ]] || fail "could not read the wrapper turn ceiling"
expect_failure "--max-turns must be an integer from 1 through $turn_ceiling" \
  --max-turns "$(( turn_ceiling + 1 ))" --prompt-file "$root/repo.md"
expect_failure "use --session-alias OR --resume" --session-alias one --resume two --prompt-file "$root/repo.md"

fake="$tmpdir/grok"
cat >"$fake" <<'EOF'
#!/usr/bin/env bash
printf 'grok 1.0.30 (04b7ffed98c6)\n'
EOF
chmod +x "$fake"
output=$(AGENT_CALL_GROK_BIN="$fake" "$wrapper" --prompt-file "$root/repo.md" 2>&1 || true)
[[ "$output" == *"Grok CLI lacks required capability"* ]] || fail "missing CLI capabilities did not fail closed"

node --test "$root/scripts/dev/test-grok-broker.mjs" "$root/scripts/dev/test-grok-wrapper.mjs"
python3 "$root/scripts/dev/test_grok_cli_offline.py"

printf 'agent-call-grok contract passed\n'
