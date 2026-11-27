#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
helper="$repo_root/.codex/skills/work-orchestration/references/scripts/codex-review"
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-review-helper.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT

target_root="$tmp_root/target"$'"\\\'\t\r'
mkdir -p "$target_root"
git -C "$target_root" init --quiet
printf 'baseline\n' > "$target_root/example.txt"
git -C "$target_root" add example.txt
git -C "$target_root" \
  -c user.name='Codex Review Helper Test' \
  -c user.email='codex-review-helper@example.invalid' \
  commit --quiet -m baseline
printf 'changed\n' >> "$target_root/example.txt"

if [[ -e "$target_root/.codex" || -e "$target_root/docs" ]]; then
  echo "test setup failed: target unexpectedly contains reviewer context" >&2
  exit 1
fi

fake_codex="$tmp_root/fake-codex"
cat > "$fake_codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

selector=false
positional_prompt=false
after_review=false
skip_value=false
developer_instructions=

for arg in "$@"; do
  if [[ "$skip_value" == true ]]; then
    if [[ "$arg" == developer_instructions=* ]]; then
      developer_instructions=$arg
    fi
    skip_value=false
    continue
  fi

  case "$arg" in
    --model|-c|--config)
      skip_value=true
      ;;
    review)
      after_review=true
      ;;
    --base)
      selector=true
      skip_value=true
      ;;
    --uncommitted)
      selector=true
      ;;
    --*) ;;
    *)
      if [[ "$after_review" == true ]]; then
        positional_prompt=true
      fi
      ;;
  esac
done

if [[ "$selector" == true && "$positional_prompt" == true ]]; then
  echo "native review target cannot be combined with a positional prompt" >&2
  exit 2
fi

if [[ -z "$developer_instructions" ]]; then
  echo "missing developer_instructions config" >&2
  exit 2
fi

printf '%s\n' "$@" > "$CAPTURE_ARGS"
pwd -P > "$CAPTURE_CWD"
cat > "$CAPTURE_STDIN"
DEVELOPER_INSTRUCTIONS_TOML=${developer_instructions#developer_instructions=} \
  CAPTURE_DEVELOPER_INSTRUCTIONS="$CAPTURE_DEVELOPER_INSTRUCTIONS" \
  python3 - <<'PY'
import os
import pathlib
import json

encoded = os.environ["DEVELOPER_INSTRUCTIONS_TOML"]
decoded = json.loads(encoded)
pathlib.Path(os.environ["CAPTURE_DEVELOPER_INSTRUCTIONS"]).write_text(decoded)
PY
printf 'fake review complete\n'
EOF
chmod +x "$fake_codex"

if "$fake_codex" review --uncommitted - >/dev/null 2>&1; then
  echo "fake Codex accepted --uncommitted with a positional prompt" >&2
  exit 1
fi
if "$fake_codex" review --base HEAD - >/dev/null 2>&1; then
  echo "fake Codex accepted --base with a positional prompt" >&2
  exit 1
fi

local_args_file="$tmp_root/local-args"
local_cwd_file="$tmp_root/local-cwd"
local_stdin_file="$tmp_root/local-stdin"
local_instructions_file="$tmp_root/local-instructions"
local_review_output="$tmp_root/local-review-output"
local_stdout="$tmp_root/local-stdout"
status_before=$(git -C "$target_root" status --porcelain=v1 -uall)

if ! (
  cd "$target_root"
  CAPTURE_ARGS="$local_args_file" \
    CAPTURE_CWD="$local_cwd_file" \
    CAPTURE_STDIN="$local_stdin_file" \
    CAPTURE_DEVELOPER_INSTRUCTIONS="$local_instructions_file" \
    "$helper" \
      --mode local \
      --codex-bin "$fake_codex" \
      --output "$local_review_output" >"$local_stdout"
); then
  cat "$local_stdout" >&2
  exit 1
fi

status_after=$(git -C "$target_root" status --porcelain=v1 -uall)
if [[ "$status_before" != "$status_after" ]]; then
  echo "codex-review helper mutated the target worktree" >&2
  exit 1
fi

if [[ "$(cat "$local_cwd_file")" != "$target_root" ]]; then
  echo "codex-review helper did not invoke Codex from the target root" >&2
  exit 1
fi

rg -q -x -- '-c' "$local_args_file"
rg -q -F -x 'sandbox_mode="read-only"' "$local_args_file"
rg -q -x -- '--uncommitted' "$local_args_file"
rg -q -F 'developer_instructions=' "$local_args_file"
if rg -q -x -- '-' "$local_args_file"; then
  echo "codex-review helper combined --uncommitted with a positional prompt" >&2
  exit 1
fi
if [[ -s "$local_stdin_file" ]]; then
  echo "codex-review helper sent review context through stdin" >&2
  exit 1
fi
if ! rg -q -F 'canonical-review-context' "$local_stdout"; then
  echo "codex-review helper did not redact the displayed review context" >&2
  exit 1
fi
if rg -q -F 'Review the target repository at:' "$local_stdout"; then
  echo "codex-review helper printed the full review context" >&2
  exit 1
fi

required_context=(
  "$repo_root/.codex/agents/reviewer.toml"
  "$repo_root/.codex/skills/reviewer/SKILL.md"
  "$repo_root/.codex/skills/reviewer/references/review-bootstrap.md"
  "$repo_root/.codex/skills/reviewer/references/review-analysis-routing.md"
  "$repo_root/.codex/skills/reviewer/references/review-verdict-closeout.md"
  "$repo_root/docs/agents/codex-review-output-contract.md"
)
for context_file in "${required_context[@]}"; do
  rg -q -F "$context_file" "$local_instructions_file"
done

expected_instructions=$(cat <<EOF
Review the target repository at:
$target_root

The canonical instruction checkout is separate from the target worktree. Before
collecting review evidence, use file-reading tools to read every file below in
full from the filesystem. A path in this prompt, pasted content, memory, prior
conversation, or a grep/snippet does not satisfy a full-read requirement. If a
file cannot be read through EOF, stop and report the exact blocker.

$(printf '%s\n' "${required_context[@]}")

After those reads, review the selected target with native independent judgment
and the canonical reviewer workflow. Reconstruct applicable changed-boundary
states from the stable diff before consulting author matrices, prior findings,
or summaries. Keep the review read-only. Do not edit files, install tools,
commit, push, resolve threads, or mutate local or remote state.

This invocation is noninteractive. Follow the Headless Instruction-Read
Adaptation in the Codex Review Output Contract. The reviewer role owns judgment;
the output contract owns compact final serialization.
EOF
)

if ! cmp -s <(printf '%s' "$expected_instructions") "$local_instructions_file"; then
  echo "codex-review helper did not preserve the exact review context" >&2
  exit 1
fi

git -C "$target_root" add example.txt
git -C "$target_root" \
  -c user.name='Codex Review Helper Test' \
  -c user.email='codex-review-helper@example.invalid' \
  commit --quiet -m change
base_ref=$(git -C "$target_root" rev-parse HEAD^)

branch_args_file="$tmp_root/branch-args"
branch_cwd_file="$tmp_root/branch-cwd"
branch_stdin_file="$tmp_root/branch-stdin"
branch_instructions_file="$tmp_root/branch-instructions"
branch_stdout="$tmp_root/branch-stdout"
branch_status_before=$(git -C "$target_root" status --porcelain=v1 -uall)

if ! (
  cd "$target_root"
  CAPTURE_ARGS="$branch_args_file" \
    CAPTURE_CWD="$branch_cwd_file" \
    CAPTURE_STDIN="$branch_stdin_file" \
    CAPTURE_DEVELOPER_INSTRUCTIONS="$branch_instructions_file" \
    "$helper" \
      --mode branch \
      --base "$base_ref" \
      --codex-bin "$fake_codex" >"$branch_stdout"
); then
  cat "$branch_stdout" >&2
  exit 1
fi

branch_status_after=$(git -C "$target_root" status --porcelain=v1 -uall)
if [[ "$branch_status_before" != "$branch_status_after" ]]; then
  echo "codex-review branch mode mutated the target worktree" >&2
  exit 1
fi
if [[ "$(cat "$branch_cwd_file")" != "$target_root" ]]; then
  echo "codex-review branch mode did not invoke Codex from the target root" >&2
  exit 1
fi
rg -q -x -- '--base' "$branch_args_file"
rg -q -F -x "$base_ref" "$branch_args_file"
rg -q -F 'developer_instructions=' "$branch_args_file"
if rg -q -x -- '-' "$branch_args_file"; then
  echo "codex-review helper combined --base with a positional prompt" >&2
  exit 1
fi
if [[ -s "$branch_stdin_file" ]]; then
  echo "codex-review branch mode sent review context through stdin" >&2
  exit 1
fi
if ! cmp -s "$local_instructions_file" "$branch_instructions_file"; then
  echo "codex-review modes did not receive the same review context" >&2
  exit 1
fi
if ! rg -q -F 'canonical-review-context' "$branch_stdout"; then
  echo "codex-review branch mode did not redact the displayed review context" >&2
  exit 1
fi

broken_root="$tmp_root/broken-instruction-root"
broken_helper="$broken_root/.codex/skills/work-orchestration/references/scripts/codex-review"
mkdir -p "$(dirname "$broken_helper")"
cp "$helper" "$broken_helper"
chmod +x "$broken_helper"
git -C "$broken_root" init --quiet

broken_called="$tmp_root/broken-called"
if (
  cd "$target_root"
  CAPTURE_ARGS="$broken_called" \
    CAPTURE_CWD="$tmp_root/broken-cwd" \
    CAPTURE_STDIN="$tmp_root/broken-stdin" \
    CAPTURE_DEVELOPER_INSTRUCTIONS="$tmp_root/broken-instructions" \
    "$broken_helper" --mode local --codex-bin "$fake_codex"
) >"$tmp_root/broken-stdout" 2>"$tmp_root/broken-stderr"; then
  echo "codex-review helper did not fail closed without canonical context" >&2
  exit 1
fi

if [[ -e "$broken_called" ]]; then
  echo "codex-review helper invoked Codex without canonical context" >&2
  exit 1
fi
rg -q -F 'required canonical review context is unreadable' "$tmp_root/broken-stderr"

printf 'codex-review helper contract passed\n'
