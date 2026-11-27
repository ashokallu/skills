#!/usr/bin/env bash
set -euo pipefail

root=$(git rev-parse --show-toplevel)
wrapper="$root/scripts/dev/agent-call-claude.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/check-agent-call-claude.XXXXXX")
fixture_repo="$tmpdir/repo"
fake="$tmpdir/claude"
args_log="$tmpdir/args.log"

cleanup() {
  find "$tmpdir" -depth -mindepth 1 -delete
  rmdir "$tmpdir"
}
trap cleanup EXIT

fail() {
  printf 'agent-call-claude contract failed: %s\n' "$*" >&2
  exit 1
}

run_wrapper() {
  (
    cd "$fixture_repo"
    AGENT_CALL_CLAUDE_BIN="$fake" \
      FAKE_CLAUDE_ARGS="$args_log" \
      FAKE_CLAUDE_MODE="${FAKE_CLAUDE_MODE:-success}" \
      "$wrapper" "$@"
  )
}

mkdir -p "$fixture_repo"
git -C "$fixture_repo" init -q

cat >"$fake" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$@" >"$FAKE_CLAUDE_ARGS"
cat >"$FAKE_CLAUDE_ARGS.stdin"
case "${FAKE_CLAUDE_MODE:-success}" in
  success)
    printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"WORKFLOW_OK:42","session_id":"11111111-1111-4111-8111-111111111111","total_cost_usd":0.04}'
    ;;
  overrun)
    printf '%s\n' '{"type":"result","subtype":"success","is_error":false,"result":"completed but over threshold","session_id":"22222222-2222-4222-8222-222222222222","total_cost_usd":0.33}'
    ;;
  budget-error)
    printf '%s\n' '{"type":"result","subtype":"error_max_budget_usd","is_error":true,"errors":["Reached maximum budget ($0.1)"],"session_id":"33333333-3333-4333-8333-333333333333","total_cost_usd":0.33}'
    exit 1
    ;;
  empty)
    exit 124
    ;;
  *)
    printf 'unknown fake mode\n' >&2
    exit 2
    ;;
esac
EOF
chmod +x "$fake"

shellcheck "$wrapper" "$0"

help=$($wrapper --help)
[[ "$help" == *"post-request stop threshold"* ]] || fail "help omits threshold semantics"
[[ "$help" == *"--safe-mode disables ambient context"* ]] || fail "help omits safe-mode default"
[[ "$help" == *"--acknowledge-post-request-budget"* ]] || fail "help omits spend acknowledgement"

set +e
invalid_output=$(run_wrapper --max-budget-usd nope --prompt test 2>&1)
invalid_status=$?
set -e
[[ "$invalid_status" -ne 0 && "$invalid_output" == *"must be a positive decimal number"* ]] ||
  fail "invalid spend threshold did not fail locally"

set +e
unacknowledged_output=$(run_wrapper --max-budget-usd 0.10 --prompt test 2>&1)
unacknowledged_status=$?
set -e
[[ "$unacknowledged_status" -ne 0 && "$unacknowledged_output" == *"is not a hard per-request cap"* ]] ||
  fail "unacknowledged post-request threshold did not fail before dispatch"

run_wrapper \
  --profile haiku \
  --tool-mode none \
  --max-budget-usd 0.10 \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title safe \
  --output "$tmpdir/safe.md" \
  --prompt test >/dev/null
rg -x -q -- '--safe-mode' "$args_log" || fail "default call omitted --safe-mode"
rg -x -q -- '--system-prompt' "$args_log" || fail "tool-free call did not replace the system prompt"
if rg -x -q -- '--append-system-prompt' "$args_log"; then
  fail "tool-free call retained the default system prompt"
fi
if rg -x -q -- '--setting-sources' "$args_log"; then
  fail "default call unexpectedly loaded setting sources"
fi
rg -U -q -- '--prompt-suggestions\nfalse' "$args_log" || fail "prompt suggestions were not disabled"
rg -U -q -- '--system-prompt-snapshot\noff' "$args_log" || fail "system prompt refresh was not pinned"
for profile in opus architect review opus46 fable; do
  expected_model=claude-opus-5-5
  [[ "$profile" != fable ]] || expected_model=claude-fable-5-1
  run_wrapper \
    --profile "$profile" \
    --tool-mode none \
    --acknowledge-post-request-budget \
    --no-session-persistence \
    --title "$profile-model" \
    --output "$tmpdir/$profile-model.md" \
    --prompt test >/dev/null
  rg -U -q -- "--model\n$expected_model" "$args_log" ||
    fail "$profile profile did not select $expected_model"
done
safe_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -type f -name '*-claude-safe.json' -print -quit)
[[ -n "$safe_metadata" ]] || fail "successful-call metadata was not retained"
jq -e '
  .requested_budget_usd == 0.10 and
  .budget_semantics == "post_request_stop_threshold" and
  .budget_risk_acknowledged == true and
  .budget_threshold_exceeded == false and
  .total_cost_usd == 0.04
' "$safe_metadata" >/dev/null || fail "successful-call metadata omitted the threshold outcome"

run_wrapper \
  --tool-mode none \
  --setting-sources user,project,local \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title settings \
  --output "$tmpdir/settings.md" \
  --prompt test >/dev/null
if rg -x -q -- '--safe-mode' "$args_log"; then
  fail "explicit setting sources did not disable safe mode"
fi
rg -x -q -- '--setting-sources' "$args_log" || fail "explicit setting sources were not forwarded"
rg -x -q -- 'user,project,local' "$args_log" || fail "setting source value was not forwarded"

run_wrapper \
  --tool-mode auto \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title tools \
  --output "$tmpdir/tools.md" \
  --prompt test >/dev/null
rg -x -q -- '--append-system-prompt' "$args_log" || fail "tool-enabled call did not retain the default system prompt"

set +e
overrun_output=$(FAKE_CLAUDE_MODE=overrun run_wrapper \
  --tool-mode none \
  --max-budget-usd 0.10 \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title overrun \
  --output "$tmpdir/overrun.md" \
  --prompt test 2>&1)
overrun_status=$?
set -e
[[ "$overrun_status" -eq 88 ]] || fail "successful CLI overrun did not fail closed with status 88"
[[ "$overrun_output" == *"observed USD 0.33"* ]] || fail "overrun diagnostic omitted observed spend"
[[ "$overrun_output" == *"do not retry or raise it without fresh spend authority"* ]] ||
  fail "overrun diagnostic omitted the spend-authority boundary"
overrun_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -type f -name '*-claude-overrun.json' -print -quit)
[[ -n "$overrun_metadata" ]] || fail "overrun metadata was not retained"
jq -e '
  .requested_budget_usd == 0.10 and
  .budget_semantics == "post_request_stop_threshold" and
  .budget_risk_acknowledged == true and
  .budget_threshold_exceeded == true and
  .total_cost_usd == 0.33
' "$overrun_metadata" >/dev/null || fail "overrun metadata omitted the threshold outcome"

set +e
budget_error_output=$(FAKE_CLAUDE_MODE=budget-error run_wrapper \
  --tool-mode none \
  --max-budget-usd 0.10 \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title budget-error \
  --output "$tmpdir/budget-error.md" \
  --prompt test 2>&1)
budget_error_status=$?
set -e
[[ "$budget_error_status" -eq 1 ]] || fail "Claude CLI error status was not preserved"
[[ "$budget_error_output" != *"Resume with:"* ]] || fail "wrapper still recommends resumption after an overrun"
[[ "$budget_error_output" == *"no resume command is available"* ]] ||
  fail "non-persistent budget error did not explain the absent resume path"

set +e
empty_output=$(FAKE_CLAUDE_MODE=empty run_wrapper \
  --tool-mode none \
  --max-budget-usd 0.10 \
  --acknowledge-post-request-budget \
  --no-session-persistence \
  --title empty \
  --output "$tmpdir/empty.md" \
  --prompt test 2>&1)
empty_status=$?
set -e
[[ "$empty_status" -eq 124 ]] || fail "empty-output status was not preserved"
[[ "$empty_output" == *"did not return a result"* ]] || fail "empty output was not failure-visible"
empty_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -type f -name '*-claude-empty.json' -print -quit)
[[ -n "$empty_metadata" ]] || fail "empty-output metadata was not retained"
jq -e '
  .requested_budget_usd == 0.10 and
  .budget_semantics == "post_request_stop_threshold" and
  .budget_risk_acknowledged == true and
  .budget_threshold_exceeded == null and
  .total_cost_usd == null and
  .terminal_reason == "timeout"
' "$empty_metadata" >/dev/null || fail "empty-output metadata omitted the threshold contract"


# The inherited task identity must not silently resume an old consultation.
mkdir -p "$fixture_repo/tmp/codex-claude/state"
printf '%s\n' 'old-session' > "$fixture_repo/tmp/codex-claude/state/claude-session-codex-thread-fixture"
CODEX_THREAD_ID=fixture run_wrapper --tool-mode none --acknowledge-post-request-budget \
  --title fresh-default --prompt FRESH_DEFAULT >/dev/null
if rg -x -q -- '--resume' "$args_log"; then fail "task identity implicitly resumed"; fi
rg -q FRESH_DEFAULT "$args_log.stdin" || fail "prompt did not reach stdin"
if rg -q FRESH_DEFAULT "$args_log"; then fail "prompt leaked into argv"; fi

run_wrapper --resume 11111111-1111-4111-8111-111111111111 --tool-mode none \
  --acknowledge-post-request-budget --title explicit-resume --prompt RESUME >/dev/null
rg -U -q -- '--resume\n11111111-1111-4111-8111-111111111111' "$args_log" || fail "explicit resume lost identity"
set +e
run_wrapper --fresh-session --resume old --acknowledge-post-request-budget --prompt bad >/dev/null 2>&1
conflict_status=$?
set -e
[[ "$conflict_status" -ne 0 ]] || fail "fresh/resume conflict was accepted"

python3 - "$tmpdir/large.txt" <<'PYLARGE'
import sys
from pathlib import Path
Path(sys.argv[1]).write_text('LARGE_BEGIN\n' + 'x' * 262144 + '\nLARGE_END\n')
PYLARGE
run_wrapper --fresh-session --tool-mode none --acknowledge-post-request-budget \
  --title large-stdin --prompt-file "$tmpdir/large.txt" >/dev/null
cmp "$tmpdir/large.txt" "$args_log.stdin" || fail "large prompt was altered or truncated"
if rg -q LARGE_BEGIN "$args_log"; then fail "large prompt passed in argv"; fi

# Explicit aliases and lanes reuse only their own binding.
printf '%s\n' '11111111-1111-4111-8111-111111111111' > "$fixture_repo/tmp/codex-claude/state/claude-session-named"
run_wrapper --session-alias named --tool-mode none --acknowledge-post-request-budget \
  --title alias-reuse --prompt ALIAS >/dev/null
rg -U -q -- '--resume\n11111111-1111-4111-8111-111111111111' "$args_log" || fail "alias reuse lost binding"
printf '%s\n' '11111111-1111-4111-8111-111111111111' > "$fixture_repo/tmp/codex-claude/state/claude-session-codex-thread-fixture-review"
CODEX_THREAD_ID=fixture run_wrapper --lane review --tool-mode none --acknowledge-post-request-budget \
  --title lane-reuse --prompt LANE >/dev/null
rg -U -q -- '--resume\n11111111-1111-4111-8111-111111111111' "$args_log" || fail "lane reuse lost binding"
[[ "$(cat "$fixture_repo/tmp/codex-claude/state/claude-session-codex-thread-fixture")" == old-session ]] || fail "fresh call overwrote inherited alias"
for selector in --resume --lane --session-alias --session-id; do
  set +e
  conflict=$(CODEX_THREAD_ID=fixture run_wrapper --fresh-session "$selector" old --acknowledge-post-request-budget --prompt bad 2>&1)
  conflict_status=$?
  set -e
  [[ "$conflict_status" -ne 0 && "$conflict" == *"conflicts with session selectors"* ]] || fail "fresh conflict missing: $selector"
done
fresh_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -name '*-claude-fresh-default.json' -print -quit)
jq -e '.session_mode == "fresh" and .prompt_transport == "stdin"' "$fresh_metadata" >/dev/null || fail "fresh metadata missing"

# Exercise the actual background/setsid branch without network access.
mkdir -p "$tmpdir/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmpdir/bin/curl"
chmod +x "$tmpdir/bin/curl"
PATH="$tmpdir/bin:$PATH" run_wrapper --fresh-session --tool-mode none --acknowledge-post-request-budget \
  --require-vpn --vpn-url http://fixture.invalid --vpn-check-interval-sec 1 \
  --title vpn-large-stdin --prompt-file "$tmpdir/large.txt" >/dev/null
cmp "$tmpdir/large.txt" "$args_log.stdin" || fail "VPN large prompt altered or truncated"
if rg -q LARGE_BEGIN "$args_log"; then fail "VPN large prompt passed in argv"; fi
# Stale alias/latest selectors fall back to fresh instead of resuming.
touch -d '2 hours ago' "$fixture_repo/tmp/codex-claude/state/claude-latest-session-id"
set +e
stale_latest_output=$(run_wrapper --resume latest --tool-mode none --acknowledge-post-request-budget \
  --title stale-latest --prompt STALE_LATEST 2>&1)
stale_latest_status=$?
set -e
[[ "$stale_latest_status" -eq 0 ]] || fail "stale latest fallback failed instead of starting fresh"
[[ "$stale_latest_output" == *"starting a fresh session instead"* ]] || fail "stale latest fallback was not announced"
if rg -x -q -- '--resume' "$args_log"; then fail "stale latest was resumed"; fi
stale_latest_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -name '*-claude-stale-latest.json' -print -quit)
jq -e '.session_mode == "fresh"' "$stale_latest_metadata" >/dev/null || fail "stale latest metadata is not fresh"

printf '%s\n' '11111111-1111-4111-8111-111111111111' > "$fixture_repo/tmp/codex-claude/state/claude-session-stale"
touch -d '2 hours ago' "$fixture_repo/tmp/codex-claude/state/claude-session-stale"
set +e
stale_output=$(run_wrapper --session-alias stale --tool-mode none --acknowledge-post-request-budget \
  --title stale-fallback --prompt STALE 2>&1)
stale_status=$?
set -e
[[ "$stale_status" -eq 0 ]] || fail "stale alias fallback failed instead of starting fresh"
[[ "$stale_output" == *"starting a fresh session instead"* ]] || fail "stale alias fallback was not announced"
if rg -x -q -- '--resume' "$args_log"; then fail "stale alias was resumed"; fi
stale_metadata=$(find "$fixture_repo/tmp/codex-claude/calls" -name '*-claude-stale-fallback.json' -print -quit)
jq -e '.session_mode == "fresh"' "$stale_metadata" >/dev/null || fail "stale alias metadata is not fresh"

# Raw session ids carry no recorded age, so they proceed with a visible note.
set +e
raw_output=$(run_wrapper --resume 11111111-1111-4111-8111-111111111111 --tool-mode none \
  --acknowledge-post-request-budget --no-session-persistence --title raw-resume --prompt RAW 2>&1)
raw_status=$?
set -e
[[ "$raw_status" -eq 0 ]] || fail "raw-id resume did not proceed"
[[ "$raw_output" == *"no recorded age"* ]] || fail "raw-id resume omitted the unchecked-age note"
rg -U -q -- '--resume\n11111111-1111-4111-8111-111111111111' "$args_log" || fail "raw-id resume lost identity"

# --autocompact is opt-in and validated locally before dispatch.
[[ "$help" == *"--autocompact"* ]] || fail "help omits --autocompact"
for window in auto 500k 100k 1M; do
  run_wrapper --autocompact "$window" --tool-mode none --acknowledge-post-request-budget \
    --no-session-persistence --title "ac-$window" --prompt AC >/dev/null
  rg -U -q -- "--autocompact\n$window" "$args_log" || fail "--autocompact $window was not forwarded"
done
run_wrapper --tool-mode none --acknowledge-post-request-budget --no-session-persistence \
  --title ac-default --prompt AC_DEFAULT >/dev/null
if rg -x -q -- '--autocompact' "$args_log"; then fail "default call forwarded --autocompact"; fi
for window in foo 99k 1000001; do
  set +e
  rejected=$(run_wrapper --autocompact "$window" --tool-mode none --acknowledge-post-request-budget \
    --prompt bad 2>&1)
  rejected_status=$?
  set -e
  [[ "$rejected_status" -ne 0 && "$rejected" == *"must be auto or"* ]] ||
    fail "invalid --autocompact $window was not rejected locally"
done
printf 'agent-call-claude contract checks passed\n'
