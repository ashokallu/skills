---
name: skill-quality-evals
description: Use when changing example-app skills, instructions, Waza evals, mirrored agents, or skill routing quality.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-05 (deterministic Pi and Luna runtime binding) -->

# Skill Quality Evals

Use this skill after repo skill or instruction edits so Waza becomes part of the
normal quality gate instead of an optional memory from a previous session.

## Route Boundary Contract

This specialist consumes the shared
[Route Node Interface and Lane Journey Contract](../work-orchestration/references/workflow-contracts.md#lane-journey-contract).
Before evaluation work, the parent names the exact candidate, authorized cost
and execution boundary, proof that ends the phase, and next authoring or review
consumer. Report deterministic, provider, candidate, grader, and transcript
evidence separately before transitioning; internal eval steps do not each
become user-visible route nodes.

## Trigger

Apply this skill when work creates or changes:

- `.codex/skills/**/SKILL.md`
- `.agents/skills/**/SKILL.md`
- `.claude/skills/**/SKILL.md`
- `AGENTS.md`, `repo.md`, `.github/instructions/**`, or other instruction files
  that affect skill routing
- `evals/**` or `.waza.yaml`
- reviewer agent instructions in `.agents/plugins/example-app/agents/reviewer.md`,
  `.codex/agents/reviewer.toml`, `.claude/agents/reviewer.md`, or
  `.github/agents/reviewer.agent.md`
- critic agent instructions in `.agents/plugins/example-app/agents/critic.md`,
  `.codex/agents/critic.toml`, `.claude/agents/critic.md`, or
  `.github/agents/critic.agent.md`

Also apply it when the user asks for Waza, skill evals, trigger precision,
skill quality, or actionable signals from skills.

## Do Not Use For

- Pure product code edits that do not change skills, instructions, evals, or
  agent instruction files.
- Trivial local command requests where no instruction routing or skill quality
  decision is involved.
- Ordinary code review, PR review, CI triage, or validation work unless the
  review explicitly covers skill/instruction behavior or Waza coverage.

## Core Workflow

1. Identify changed skills from `git diff --name-only` and
   `git diff --cached --name-only`.
2. For each changed skill, map runtime-specific names to the Codex eval target:
   - `.codex/skills/<skill>/SKILL.md` maps to `evals/<skill>/eval.yaml`
   - `.agents/skills/<skill>/SKILL.md` maps to the same name when a Codex mirror
     exists
   - `.claude/skills/<skill>/SKILL.md` maps to the Codex mirror when one exists
3. When mirrored skill folders differ only by runtime suffixes or historical
   tool details, normalize to the canonical workflow name before syncing. For
   example, CI workflow skills should use the `pr-workflow` ci-read and
   ci-worktree lanes across `.agents`, `.codex`, and `.claude`; exact MCP
   function names belong inside the skill body only when they are currently
   visible in that runtime. Do not let a `-mcp` suffix hide a Codex mirror from
   sync or Waza coverage unless MCP access is the actual domain boundary of the
   skill, such as a database or language-server MCP skill.
   Naming rule: keep `-mcp` only when the MCP is the skill's durable domain
   boundary, such as read-only MCP data access, database access, language-server
   navigation, or browser automation. Drop `-mcp` when MCP is only an
   implementation detail inside a broader workflow, such as PR comment fixes,
   CI reproduction, bug-fix review, or PR publication.
4. Before replacing a skill, agent, or reference folder from a candidate
   artifact, produce a preservation ledger instead of copying blindly:
   - current-only files and reference paths
   - current-only trigger language and eval-covered prompts
   - stale candidate references, obsolete skill names, or runtime-specific paths
   - version-specific claims that must be gated by repo-confirmed package,
     module, toolchain, or CI evidence
   - evals, callers, PR workflow lanes, or docs that depend on the old shape
   Preserve or deliberately retire each item before committing the replacement.
5. If a Claude or Agents skill intentionally diverges from the Codex skill, say
   Waza only covers the Codex mirror unless a dedicated eval path exists.
6. Treat Agent Skills as portable Markdown workflows first. Prefer one shared
   skill shape across `.codex/skills` and `.claude/skills` when the workflow is
   portable, including umbrella skills that lazy-load `references/*.md` lane
   files. Add runtime-specific wording only for real differences such as
   installed tool names, unavailable MCPs, invocation paths, or frontmatter
   fields that are not portable.
7. Do not preserve extra Claude or Codex first-class skill directories just
   because one runtime can invoke them. Extra directories increase picker
   surface, trigger collisions, and drift. When a workflow is consolidated into
   an umbrella skill, retire equivalent granular first-class skill directories
   in each runtime and keep durable lane content under the umbrella's
   `references/` directory. Document any retained runtime-specific directory as
   an intentional exception with the operational reason.
8. Do not trim monolithic agent or instruction bodies into lazy-loaded
   references until that runtime has a verified route to load the replacement
   skill or reference set. Keep the monolithic fallback for runtimes without
   proven lazy loading, or document the intentional staged divergence.
9. If reviewer agent instructions changed, sync the durable reviewer guidance
   across all reviewer surfaces in the same change:

   - `.agents/plugins/example-app/agents/reviewer.md`
   - `.codex/agents/reviewer.toml`
   - `.claude/agents/reviewer.md`
   - `.github/agents/reviewer.agent.md`

   Keep runtime-specific frontmatter/tool fields intact, but do not let the
   shared review policy drift silently. If a divergence is intentional, document
   it in the changed file and call it out in the final response. When one
   surface is the canonical source, run a mechanical body-parity check after
   the runtime heading or TOML `developer_instructions` body rather than
   relying on visual comparison.
10. If critic agent instructions changed, sync the durable critic guidance across
   all critic surfaces in the same change:

   - `.agents/plugins/example-app/agents/critic.md`
   - `.codex/agents/critic.toml`
   - `.claude/agents/critic.md`
   - `.github/agents/critic.agent.md`

   Keep runtime-specific frontmatter/tool fields intact, but do not let the
   shared critic policy drift silently. If a divergence is intentional, document
   it in the changed file and call it out in the final response. When one
   surface is the canonical source, run a mechanical body-parity check after
   the runtime heading or TOML `developer_instructions` body rather than
   relying on visual comparison.
11. Run coverage:

   ```bash
   tmp/waza-bin/waza --no-update-check coverage --path .codex/skills --format markdown
   ```

12. For every changed skill with an eval suite, run:

   ```bash
   tmp/waza-bin/waza --no-update-check run evals/<skill>/eval.yaml -v
   ```

13. If a changed skill lacks a suite, either add a narrow trigger eval when the
    routing boundary is meaningful, or report that Waza coverage is missing.
14. For instruction changes that retire implementation agents, move code
    authoring lanes, or depend on `.codex`/`.agents`/`.claude` mirror parity,
    also run:

   ```bash
   scripts/dev/check-agent-instruction-routing.sh
   ```

   This check is intentionally not a Waza trigger eval. It catches stale active
   references to retired implementation agents, stale code-authoring lane
   names, and byte-level parity drift for skills that are expected to match.
15. Reference-only skill edits still count as skill changes. Mirror them across
    the applicable runtime trees, run markdownlint and `git diff --check` on
    the changed reference files, and run the owning skill's eval suite when it
    exists. Do not skip validation because the edited file is under
    `references/` instead of `SKILL.md`.
16. When eval files changed, run YAML and diff hygiene:

   ```bash
   ruby -e 'require "yaml"; ARGV.each { |f| YAML.load_file(f) }; puts "yaml ok"' .waza.yaml evals/*/eval.yaml evals/*/tasks/*.yaml
   git diff --check -- evals
   ```

## Real-model behavior evaluation

When a behavior suite will call a real model, any participating task uses a
prompt grader, or a provider/model/grader failure needs recovery, load
[references/real-model-behavior-evaluation.md](references/real-model-behavior-evaluation.md).
That lane owns candidate provenance, explicit execution and grader model
resolution, focused-case-first execution, skill-path attestation, cost gating,
verdict integrity, and bounded recovery. Mock trigger suites and behavior
suites graded entirely by deterministic program graders do not activate it.
For Pi/Luna, the repo runner owns absolute Pi/Node binding and its child
runtime path. Never manually sanitize `PATH` around the runner or treat a mise
shim failure as a paid model attempt.

## Markdown Hygiene

When editing Markdown instructions, skills, prompt templates, or agent docs,
the editing harness owns Markdown shape before handoff:

- Preserve the existing document structure and local wrapping style. Add small,
  readable bullets instead of dense single-line paragraphs.
- Keep blank lines around headings, lists, and fenced code blocks. Keep nested
  lists consistently indented.
- Keep examples generic unless a real repo fact is required. Use placeholders
  like `<pr-number>`, `<branch>`, `<sha>`, `<run-id>`, and `<path>` instead of
  incident-specific IDs, branch names, local paths, or run output.
- Do not add local file URLs, absolute machine paths, disposable `tmp/` paths,
  or one-off debugging breadcrumbs to durable instructions.
- Before handoff, run markdownlint on every changed Markdown instruction file:

  ```bash
  npx markdownlint-cli2 <changed-markdown-paths>
  ```

- Also run `git diff --check -- <changed-paths>` to catch whitespace and patch
  formatting drift.
- If markdownlint cannot run in the current harness, state the exact blocker
  and the command under `Pending Verification`; do not claim the Markdown is
  lint-clean.

## Interpretation

- `model: mock-trigger-grader` is a schema-required label for mock runs, not a
  real model-backed evaluation.
- Passing trigger evals means the skill routing boundary still matches the
  prompt examples. It does not prove the skill body is complete or that a live
  workflow works.
- Failing positives usually mean the prompt is too vague or the skill metadata
  lacks trigger language. Failing negatives usually mean the skill overlaps
  another workflow and needs a sharper `DO NOT USE FOR` boundary.
- Prefer improving skill metadata or boundaries over weakening thresholds.

## Reporting

Close with:

- changed skill names
- eval suites run and pass/fail result
- skills without Waza coverage
- whether Claude or Agents changes were covered through a Codex mirror or left
  `Pending Verification`
- whether mirrored reviewer or critic agent bodies passed mechanical parity
  checks, or which divergence is intentional
