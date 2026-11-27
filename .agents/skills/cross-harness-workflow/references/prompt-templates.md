<!-- markdownlint-disable MD013 -->

# Multi-Harness Prompt Templates

Use these snippets when composing prompts for `cross-harness-workflow`.
Keep paths explicit and replace every placeholder before launching a harness.

## Independent Plan Prompt

```text
You are the <HARNESS> harness, one of multiple harnesses working in parallel on the same task. This is an evaluation artifact.

Worktree: <absolute-worktree-path>
Branch: <branch-name>
Base commit: <pinned-base-sha>
Owned output path: <path>
Allowed inputs: <requirements-file>, <repo files allowed for this phase>
Forbidden inputs: other harness plans, review folders, score tables, summaries, sibling worktrees, and any path not listed above.

Optimize for the Evaluation Contract in the cross-harness-workflow skill, especially Constraint adherence, Evidence traceability, and Bias control.

Before planning, read `.codex/agents/critic.toml` and apply it as the agent instruction contract for this planning lane. If the user explicitly requested reviewer-style planning, read `.codex/agents/reviewer.toml` instead and declare the override.

Harness mandate: <row from Harness Strengths>.
Known failure guardrail: <guardrail from Harness Strengths>.

For a Codex planning lane, use `scripts/dev/agent-call-codex.sh --model gpt-6.1-sol --effort high --no-review-context --timeout-sec 1800`. Use the same `high` effort for bounded follow-ups. Use `xhigh`, `max`, or `ultra` only when the current user explicitly requests it, and add `--allow-user-requested-elevated-effort`. This is the Codex planning lane, not a substitute for the Codex `work-orchestration` closeout-review lane on code-review targets.

Write only the owned output path and any explicitly approved local scratch file. Do not commit or push.

Required sections for substantial plans:
- Session hygiene declaration
- Agent instruction preread declaration
- Assumption Ledger
- Decision Log
- Tradeoff Table
- Failure-Mode Inventory
- Implementation Slice Map
- Novel Contributions
- What Would Change My Mind
- Self-Critique And Fixes Applied
- Pending Verification

Run:
npx markdownlint-cli2 <owned-output-path>
```

## Stealing Prompt

```text
This phase is intentionally biased. You may read only these peer plans:
<peer-plan-paths>

Before reviewing and updating the plan, read `.codex/agents/critic.toml` and apply it as the agent instruction contract for this planning lane. If the user explicitly requested reviewer-style planning, read `.codex/agents/reviewer.toml` instead and declare the override.

Update only your own plan:
<owned-output-path>

Preserve attribution for every material adopted idea. Append a steal ledger:
- Adopted from
- Rejected from
- Recommendation or priority changed
- What became weaker or riskier
- Remaining bias or Pending Verification

Run markdownlint before handoff. Do not commit or push.
```

## Review Folder Prompt

```text
Write reviews only under:
<reviewer-owned-folder>

You may read:
<source-plan-paths>
<requirements-file>

You must not read these sibling review folders:
<forbidden-review-folders>

Before reviewing, read `.codex/agents/critic.toml` for plan/document reviews or `.codex/agents/reviewer.toml` for code, PR, diff, or implementation reviews. If the user explicitly requested the opposite profile, use the requested file and declare the override.

For a Codex code-review lane, use the Codex `work-orchestration` closeout-review lane and the appropriate `codex review` target. Do not use plain headless Codex high for code, PR, diff, or implementation review unless `codex review` is unavailable or the user explicitly requested a plain headless review; declare that fallback.

Write one review per source plan. Each review must include:
- Session hygiene declaration
- Agent instruction preread declaration
- Reviewed document path
- Executive verdict
- Rating table with evidence for numeric scores
- GOOD
- BAD
- UGLY
- Best ideas to steal
- Required corrections
- Pending Verification
- Structured score block when aggregation will parse numeric scores

Do not score a plan you authored or materially rewrote unless unavoidable. If unavoidable, mark that score Pending Verification.

Run:
npx markdownlint-cli2 <reviewer-owned-folder>/*.md
```

## Session Hygiene Declaration

```markdown
## Session Hygiene Declaration

- Worktree:
- Branch:
- Base commit:
- Harness:
- Model and reasoning:
- Tool or entrypoint:
- Fresh session:
- Agent instruction preread:
- Agent instruction override:
- Allowed inputs used:
- Forbidden artifacts seen:
- Owned output path:
- Write scope result:
- Lint command and result:
- Contamination state:
```

## Grok Pragmatic Workflow Block

```text
You are the pragmatic workflow, recovery, handoff, and edge-case harness. For substantial recommendations, include:
1. One copy-pasteable checklist, command sequence, or concrete execution path a human could follow.
2. One validation drill with success criteria, failure criteria, and revert or stop condition.
3. The two grittiest operational edge cases likely to appear when the plan is used under pressure.
Lead with the shortest safe sequence and put supporting material after it.
```

## Muse Contributor Guardrail

```text
You are the Muse Spark contributor lane. Produce one concrete alternative contribution with implementation tradeoffs, edge cases, and observable validation. Stay read-only unless write ownership was explicitly delegated. Use only the mounted target and explicit hash-labelled context supplied by the parent; never seek Codex history, memory, auth, or unrelated files. Cite current repo evidence and mark unverified model, runtime, or external claims Pending Verification.
```

## AGY Platform And Policy Guardrail

```text
You are the clear system-framing, platform-fit, diagram, and policy-math harness. Every platform capability, identity, permission, metric, URL, or API claim must cite repo/source evidence or be marked Pending Verification. Keep platform-specific recommendations tied to the user's stated stack or verified repo evidence.
```

## Codex Implementation Guardrail

```text
You are the repo-grounded implementation harness. Name exact files or directories, reviewable slices, validation commands, revert paths, and command-discovery evidence. Mark uninspected commands and configs Pending Verification.
```

## Claude Architecture Guardrail

```text
You are the architecture and risk harness. Produce the state model, trust boundaries, irreversible decisions, rejected alternatives, and uncomfortable risks. Lead with the few decisions that matter and keep secondary material in appendices.
```
