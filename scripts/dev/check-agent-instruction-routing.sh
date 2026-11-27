#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep is required for agent instruction routing checks" >&2
  exit 1
fi

if ! command -v diff >/dev/null 2>&1; then
  echo "diff is required for agent instruction routing checks" >&2
  exit 1
fi

tmp_out="$(mktemp -t agent-routing-check.out.XXXXXX)"
tmp_err="$(mktemp -t agent-routing-check.err.XXXXXX)"
trap 'rm -f "$tmp_out" "$tmp_err"' EXIT

expected_copilot_agents=(
  critic.agent.md
  database-reviewer.agent.md
  reviewer.agent.md
  security-auditor.agent.md
  tester.agent.md
)

declare -A expected_copilot_agent_names=()
for file in "${expected_copilot_agents[@]}"; do
  expected_copilot_agent_names["${file%.agent.md}"]=1
done

actual_copilot_agents=()
for path in .github/agents/*.agent.md; do
  actual_copilot_agents+=("${path##*/}")
done

if ! diff -u \
  <(printf '%s\n' "${expected_copilot_agents[@]}") \
  <(printf '%s\n' "${actual_copilot_agents[@]}") >"$tmp_out"; then
  echo "Copilot custom-agent roster must contain exactly the shared five roles" >&2
  cat "$tmp_out" >&2
  exit 1
fi

check_copilot_agent_reference() {
  local name="$1"
  local source="$2"

  if [[ -z "${expected_copilot_agent_names[$name]:-}" ]]; then
    echo "Copilot instruction references an agent outside the shared roster: $name ($source)" >&2
    exit 1
  fi
}

while IFS= read -r name; do
  check_copilot_agent_reference "$name" "handoffs.agent"
done < <(
  rg --no-filename -o '^[[:space:]]+agent:[[:space:]]+[A-Za-z0-9_-]+' .github/agents \
    | sed -E 's/.*agent:[[:space:]]+//'
)

while IFS= read -r name; do
  check_copilot_agent_reference "$name" "runSubagent agentName"
done < <(
  rg --no-filename -o '"agentName":[[:space:]]*"[A-Za-z0-9_-]+"' .github/copilot-instructions.md \
    | sed -E 's/.*"([A-Za-z0-9_-]+)"/\1/'
)

while IFS= read -r name; do
  check_copilot_agent_reference "$name" "agent profile path"
done < <(
  rg --no-filename -o '\.github/agents/[A-Za-z0-9_-]+\.agent\.md' \
    README.md docs .github --glob '!agents/*.agent.md' \
    --glob '!docs/plans/**' \
    | sed -E 's#.*agents/([^/]+)\.agent\.md#\1#'
)

retired_agents=(
  backend-engineer
  frontend-engineer
  typescript-pro
  featureImplementer
  performanceEngineer
  refactorEngineer
)

active_surfaces=(
  AGENTS.md
  repo.md
  .codex/agents
  .codex/skills
  .agents/plugins
  .agents/skills
  .claude/agents
  .claude/rules
  .claude/skills
  .github/agents
  .github/instructions
)

for name in "${retired_agents[@]}"; do
  set +e
  rg -n -w -F "$name" "${active_surfaces[@]}" >"$tmp_out" 2>"$tmp_err"
  rg_status=$?
  set -e
  if [[ "$rg_status" -eq 0 ]]; then
    echo "retired implementation agent appears in active instruction surface: $name" >&2
    cat "$tmp_out" >&2
    exit 1
  fi
  if [[ "$rg_status" -ne 1 ]]; then
    echo "retired implementation agent scan failed for: $name" >&2
    cat "$tmp_err" >&2
    exit 1
  fi
done

if rg -n -F 'tests-validation' \
  .codex/skills/code-authoring \
  .agents/skills/code-authoring \
  .claude/skills/code-authoring \
  >"$tmp_out"; then
  echo "stale code-authoring lane reference found: tests-validation" >&2
  cat "$tmp_out" >&2
  exit 1
fi

for skill in improve code-authoring database-reviewer; do
  diff -qr ".codex/skills/$skill" ".agents/skills/$skill" >"$tmp_out" || {
    echo "mirror drift between .codex and .agents for $skill" >&2
    cat "$tmp_out" >&2
    exit 1
  }
  diff -qr ".codex/skills/$skill" ".claude/skills/$skill" >"$tmp_out" || {
    echo "mirror drift between .codex and .claude for $skill" >&2
    cat "$tmp_out" >&2
    exit 1
  }
done

source_handling="skills/work-orchestration/references/source-handling.md"
cmp -s ".codex/$source_handling" ".agents/$source_handling" || {
  echo "source-handling mirror drift between .codex and .agents" >&2
  exit 1
}
cmp -s ".codex/$source_handling" ".claude/$source_handling" || {
  echo "source-handling mirror drift between .codex and .claude" >&2
  exit 1
}

if rg -n -F 'migration-reviewer' \
  .codex .agents .claude .github evals AGENTS.md repo.md \
  docs/agents/agent-audit-workflow.md \
  --glob '!**/copilot-agent-*-ledger.md' >"$tmp_out"; then
  echo "active migration-reviewer name remains after database-reviewer rename" >&2
  cat "$tmp_out" >&2
  exit 1
fi

if rg -n -F 'reviewer' \
  .codex/skills/database-reviewer \
  .agents/skills/database-reviewer \
  .claude/skills/database-reviewer \
  .codex/agents/database-reviewer.toml \
  .claude/agents/database-reviewer.md \
  .github/agents/database-reviewer.agent.md \
  evals/database-reviewer >"$tmp_out"; then
  echo "database-reviewer depends on the ordinary reviewer" >&2
  cat "$tmp_out" >&2
  exit 1
fi

for marker in \
  'the native reviewer immediately' \
  'No environment preflight belongs to an' \
  'not live-access authority' \
  'Do not refresh them or route through' \
  'Spawn `database-reviewer` immediately when required, including when' \
  'This packet does not curate the' \
  'without refreshing live state in the ordinary review phase'; do
  rg -q -F "$marker" \
    .codex/skills/pr-workflow/references/review-worktree.md || {
    echo "ordinary static-review dispatch contract missing: $marker" >&2
    exit 1
  }
done

for surface in \
  .codex/agents/database-reviewer.toml \
  .claude/agents/database-reviewer.md \
  .github/agents/database-reviewer.agent.md; do
  rg -q -F 'complete independent' "$surface" || {
    echo "database reviewer lacks independent verdict ownership: $surface" >&2
    exit 1
  }
  rg -q -F 'Never run shell or' "$surface" || {
    echo "database reviewer lacks static no-command contract: $surface" >&2
    exit 1
  }
  rg -q -F 'verdict-closeout reference exactly once' "$surface" || {
    echo "database reviewer lacks lazy final-closeout trigger: $surface" >&2
    exit 1
  }
  rg -q -F 'review-control-plane.md' "$surface" || {
    echo "database reviewer lacks shared scope-control owner: $surface" >&2
    exit 1
  }
  rg -q -F 'SCOPE_DISPUTE_BLOCKED' "$surface" || {
    echo "database reviewer can be forced under disputed narrowing: $surface" >&2
    exit 1
  }
  if rg -q -e 'Fix shape:' -e 'Selected lanes:' -e 'Problem:' "$surface"; then
    echo "database reviewer wrapper duplicates packet schema: $surface" >&2
    exit 1
  fi
done

if rg -q -F 'Bash' .claude/agents/database-reviewer.md; then
  echo "Claude database reviewer still exposes Bash" >&2
  exit 1
fi

if rg -q -e 'execute/' -e 'dbcode\.dbcode/' \
  .github/agents/database-reviewer.agent.md; then
  echo "Copilot database reviewer still exposes execution or DB query tools" >&2
  exit 1
fi

for marker in \
  'This reviewer is static' \
  'parent readiness packet' \
  'Missing evidence is not a defect' \
  'Block only the exact decision' \
  'references/verdict-closeout.md' \
  'load' \
  'exactly once'; do
  rg -q -F "$marker" .codex/skills/database-reviewer/SKILL.md || {
    echo "database static evidence contract missing: $marker" >&2
    exit 1
  }
done

if [[ "$(rg -c -F 'exactly once' .codex/skills/database-reviewer/SKILL.md)" -ne 1 ]]; then
  echo "database reviewer must route final closeout exactly once" >&2
  exit 1
fi

for runtime in .codex .agents .claude; do
  closeout="$runtime/skills/database-reviewer/references/verdict-closeout.md"
  [[ -f "$closeout" ]] || {
    echo "database reviewer closeout reference missing: $closeout" >&2
    exit 1
  }
  for marker in '## Actionable finding core' '## Selected-lane audit' \
    'central missing proof' 'one to three evidence bullets' \
    'trigger:' 'surface:' 'disposition:' 'decision outcome' 'blocked decision'; do
    rg -q -F "$marker" "$closeout" || {
      echo "database reviewer closeout contract missing from $closeout: $marker" >&2
      exit 1
    }
  done
done

python3 evals/database-reviewer/validate_evidence_candidate.py \
  .codex/skills/database-reviewer/evidence/production-content-user-progress-created-at-index-20260716.yaml \
  .agents/skills/database-reviewer/evidence/production-content-user-progress-created-at-index-20260716.yaml \
  .claude/skills/database-reviewer/evidence/production-content-user-progress-created-at-index-20260716.yaml
python3 -m unittest evals/database-reviewer/test_evidence_candidate.py
python3 evals/database-reviewer/graders/behavior_contract.py --self-test
python3 -m unittest evals/database-reviewer/graders/test_behavior_contract.py
python3 evals/pr-workflow/graders/database_applicability_contract.py --self-test
python3 evals/pr-workflow/graders/review_fix_topology_contract.py --self-test
python3 evals/pr-workflow/graders/test_review_fix_topology_contract.py

required_markers=(
  "pr-workflow/references/publish-pr.md|Do not publish a new PR from a topic-only branch"
  "pr-workflow/references/publish-pr.md|pause before push or PR creation"
  "pr-workflow/references/publish-pr.md|Never open a new PR with multiple commits"
  "pr-workflow/references/publish-pr.md|git rev-list --count <base>..HEAD = 1"
  "pr-workflow/SKILL.md|used to publish a new multi-commit PR"
  "code-authoring/SKILL.md|temporary local review provenance"
  "worktree-readiness/SKILL.md|must contain exactly one commit"
  "jira-agent-workflow/SKILL.md|## Route Audit"
  "jira-agent-workflow/SKILL.md|## Workflow 1.5: Publish A Non-Jira Worktree As A PR"
  "skill-quality-evals/SKILL.md|scripts/dev/check-agent-instruction-routing.sh"
  "skill-quality-evals/SKILL.md|references/real-model-behavior-evaluation.md"
)

for marker in "${required_markers[@]}"; do
  path="${marker%%|*}"
  text="${marker#*|}"
  for runtime in .codex .agents .claude; do
    file="$runtime/skills/$path"
    if [[ ! -f "$file" ]]; then
      echo "required mirrored instruction file is missing: $file" >&2
      exit 1
    fi
    if ! rg -q -F "$text" "$file"; then
      echo "required mirrored instruction marker missing from $file: $text" >&2
      exit 1
    fi
  done
done

real_model_eval_reference="skills/skill-quality-evals/references/real-model-behavior-evaluation.md"
for runtime in .codex .agents .claude; do
  file="$runtime/$real_model_eval_reference"
  if [[ ! -f "$file" ]]; then
    echo "real-model behavior evaluation lane is missing: $file" >&2
    exit 1
  fi
  for marker in '## Effective-model Preflight' \
    'still `auto`' \
    'stop before the provider' \
    'Run exactly the selected focused task first' \
    'canonical `skill_invocations` attestation' \
    'classify grader integrity as' \
    'unresolved and stop' \
    'Before inspecting provider configuration after an auth failure' \
    'never run a broad provider-name search across `.envrc`' \
    '## Cost And Expansion Gate'; do
    if ! rg -q -F "$marker" "$file"; then
      echo "real-model behavior evaluation contract missing from $file: $marker" >&2
      exit 1
    fi
  done
done

if ! cmp -s \
  ".codex/$real_model_eval_reference" \
  ".agents/$real_model_eval_reference" || \
  ! cmp -s \
  ".codex/$real_model_eval_reference" \
  ".claude/$real_model_eval_reference"; then
  echo "real-model behavior evaluation mirrors have drifted" >&2
  exit 1
fi

scripts/dev/check-reviewer-contract-fixtures.sh
scripts/dev/check-jira-agent-workflow-contracts.sh
scripts/dev/check-agent-workflow-contracts.sh
scripts/dev/check-agent-call-luna.sh
python3 scripts/dev/check-agent-destructive-command-guard.py

echo "agent instruction routing check passed"
