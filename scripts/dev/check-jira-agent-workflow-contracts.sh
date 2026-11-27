#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

skill_name="jira-agent-workflow"
source_skill=".claude/skills/jira-ticket-writer"
ticket_types=(story task bug epic initiative risk collaboration)
runtimes=(.codex .agents .claude)

fail() {
  echo "jira workflow contract failed: $*" >&2
  exit 1
}

for runtime in "${runtimes[@]}"; do
  skill_dir="$runtime/skills/$skill_name"
  [[ -f "$skill_dir/SKILL.md" ]] || fail "missing $skill_dir/SKILL.md"

  for ticket_type in "${ticket_types[@]}"; do
    source_reference="$source_skill/references/$ticket_type.md"
    mirrored_reference="$skill_dir/references/ticket-$ticket_type.md"
    [[ -f "$mirrored_reference" ]] || fail "missing $mirrored_reference"
    cmp -s "$source_reference" "$mirrored_reference" ||
      fail "$mirrored_reference drifted from $source_reference"
  done

  for marker in \
    '## Ticket Drafting And Creation' \
    'Story | User-facing change' \
    'Task | Work with no direct user-facing outcome' \
    'Bug | Existing behavior is wrong' \
    'Epic | Several stories or tasks' \
    'Initiative | Business-level effort' \
    'Risk | A possible future problem' \
    'Collaboration | Cross-team coordination' \
    'Use `[TBC]` for facts the user has not supplied' \
    'Do not infer labels or owners' \
    'Present the complete draft and exact payload before any Jira write' \
    'Resolve constrained fields through live create metadata' \
    'Write Markdown to normal Jira issue' \
    'Read the stored issue back after creation or update'; do
    rg -q -F "$marker" "$skill_dir/SKILL.md" ||
      fail "missing behavior marker in $skill_dir/SKILL.md: $marker"
  done
done

cmp -s .codex/skills/$skill_name/SKILL.md .agents/skills/$skill_name/SKILL.md ||
  fail "Codex and Agents Jira skill bodies must match"
cmp -s .codex/skills/$skill_name/SKILL.md .claude/skills/$skill_name/SKILL.md ||
  fail "Codex and Claude Jira skill bodies must match"
cmp -s .codex/skills/$skill_name/agents/openai.yaml .agents/skills/$skill_name/agents/openai.yaml ||
  fail "Codex and Agents Jira skill metadata must match"
cmp -s .codex/skills/$skill_name/agents/openai.yaml .claude/skills/$skill_name/agents/openai.yaml ||
  fail "Codex and Claude Jira skill metadata must match"
cmp -s .codex/skills/$skill_name/scripts/jira-agent-workflow.sh \
  .agents/skills/$skill_name/scripts/jira-agent-workflow.sh ||
  fail "Codex and Agents Jira helpers must match"

if ! diff -u \
  <(sed -e 's/branch_prefix="claude"/branch_prefix="codex"/' \
    -e 's/--prefix claude/--prefix codex/' \
    .claude/skills/$skill_name/scripts/jira-agent-workflow.sh) \
  .codex/skills/$skill_name/scripts/jira-agent-workflow.sh >/dev/null; then
  fail "Claude Jira helper diverges beyond its documented branch-prefix default"
fi

if merge_head_ref="$(git rev-parse -q --verify MERGE_HEAD 2>/dev/null)"; then
  git diff --quiet "$merge_head_ref" -- "$source_skill" ||
    fail "$source_skill must remain byte-identical to MERGE_HEAD"
fi

echo "jira workflow contracts passed"
