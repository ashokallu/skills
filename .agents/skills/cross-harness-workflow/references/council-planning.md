<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (Muse added to the default council roster) -->

# Council Planning

Use this skill when a broad example-app planning question needs several
harnesses to produce independent plans, cross-review each other, steal the best
ideas, and then review or aggregate the final documents.

In this repo, "council", "council opinion", and "council review" mean the
cross-harness council roster: Grok, Muse with
`muse-spark-1.3-contributor`, Claude Code with Opus, and Codex with high
reasoning. Council does not mean native
runtime `reviewer` or `critic` subagents. Do not replace council lanes with
native subagent calls unless the user separately asks for reviewer or critic
subagent gates.

When Pi is explicitly requested for council or bounded contribution, use the
[direct Pi candidate call](direct-collaboration.md#direct-pi-candidate-call).
Pi is not part of the default council roster and has no autonomous admission.

Maintaining the council roster is not itself a council run. Do not invoke the
council being changed as a prerequisite unless the user explicitly requests an
independent council review of that maintenance change.

Do not use this skill for ordinary PR review, one-document cleanup, or prompts
that name only one harness/model. Route those to the normal repo review,
markdown, or harness-collaboration workflow instead. Exception: when the user
explicitly asks for a multi-harness council review of a PR, diff, plan, or
artifact, use the read-only council review mode below.

Hard negative categories:

- narrow edits to exactly one Markdown document;
- proofreading, wording, or plan feedback requested from exactly one named
  harness or model;
- ordinary PR review without an explicit council or multi-harness request.

## Core Rule

The parent harness is the orchestrator. It owns worktree hygiene, prompt
boundaries, file ownership, linting, commits, pushes, and the final summary.
Harness outputs are evidence and drafts, not proof.

For implementation or instruction-repair councils, create one isolated
worktree per harness from the same pinned base and treat each branch as a
proposal surface. The parent must inspect diffs, select or reapply the durable
pieces into the canonical branch, and avoid wholesale merges just because a
harness produced a plausible patch. After consolidation, remove disposable
worktrees, scratch branches, and untracked harness artifacts unless the user
asked to keep them.

After this skill is selected, load `agent-personality` before drafting a
high-touch user-facing council synthesis, peer-consultation, or handoff
response. This companion rule does not expand this skill's trigger scope: do
not use this skill for one-document cleanup, single-harness proofreading, or
ordinary PR review. Do not load personality for parser-facing packets, formal
review findings, incidents, security, data loss, production operations, or
stricter evidence-only output contracts.

For detailed copyable prompt templates, read
`references/prompt-templates.md` only when composing harness prompts or
debugging a failed harness handoff. Keep `SKILL.md` as the operational spine;
do not inline long prompt blocks unless the user asks for the full prompt.

For Codex headless planning runs, select `gpt-6.1-sol` with `high` for normal
planning, review, and final synthesis. Use the same `high` effort for bounded
follow-ups. Do not autonomously choose
`xhigh`, `max`, or `ultra` with Sol. When the current user explicitly requests one of
those levels, pass `--allow-user-requested-elevated-effort`; that flag records user
authorization and is not an agent escalation mechanism.

```bash
(
  cd "$WORKTREE"
  scripts/dev/agent-call-codex.sh \
    --model gpt-6.1-sol \
    --effort high \
    --no-review-context \
    --timeout-sec 1800 \
    --sandbox workspace-write \
    --output "$OUTPUT" \
    --prompt "$PROMPT"
)
```

Use the repo wrapper so model and reasoning selection, subscription auth,
session capture, and output paths follow one checked contract.

For Codex code-review lanes, do not use plain headless `codex exec` as the
default. Use the Codex `work-orchestration` closeout-review lane and its
`codex review` target selection instead, because code review needs a stable
diff, commit, or branch target plus review closeout semantics. Use plain
headless Codex for code review only when `codex review` is unavailable or the
user explicitly asks for a plain headless review; record that fallback as
`Pending Verification` in the manifest.

After every harness run, check write scope before accepting the output:

```bash
git -C "$WORKTREE" status --short
```

Only the harness-owned output path, run manifest, or explicitly approved local
scratch files should be changed. Mark the output `Contaminated` if the harness
changed unrelated files.

## Captured Output Contract

Many example-app harness wrappers capture the final assistant message into
the requested output path. Therefore every document-producing prompt must make
the output contract explicit:

- The final response must be the complete requested Markdown document itself.
- The final response must start with the document title or first required
  heading, not with status prose.
- Do not end with or replace the document with status summaries such as
  "Done", "I wrote the report", "The report is available at", "Summary", or
  "Validation passed".
- Do not rely on shell, Python, `apply_patch`, or another side-effect write
  unless the prompt explicitly asks for tool-written files and the wrapper is
  known to preserve them. When in doubt, assume only the final response will be
  saved.
- Before finalizing, the harness must ask: "If only my final message were
  saved to disk, would it be the complete requested document?" If not, it must
  rewrite the final response before handoff.

Markdown hygiene is also the harness's responsibility before handoff. Require
the harness to run markdownlint on its owned Markdown document whenever the
runtime can execute commands:

```bash
npx markdownlint-cli2 <owned-output-path>
```

If markdownlint cannot run, the harness must state the exact blocker in the
document under `Pending Verification`. It must not claim lint passed unless it
actually ran the check and saw zero errors. The orchestrator still verifies
artifacts after collection, but repeated wrapper/status cleanup is treated as a
harness-output defect and should trigger a rerun with this stricter contract.

## Artifact Output Contracts

Use an artifact-specific contract whenever the requested output is not a normal
Markdown report. The prompt must name the exact file type, first-line sentinel,
forbidden wrapper prose, and orchestrator validation command.

For TOML artifacts:

- Final response must be raw TOML only.
- It must start with the exact first line expected for that artifact, such as
  `name = "critic"` for agent TOML files.
- Do not include Markdown fences, headings, status summaries, path prose, or
  explanations outside the TOML.
- Preserve required config keys and ownership boundaries from the source file.
- The orchestrator must parse every candidate with Python `tomllib` before
  accepting it.

```bash
python - <<'PY'
from pathlib import Path
import tomllib

for path in sorted(Path("<planning-root>").glob("*/critic.toml")):
    data = tomllib.loads(path.read_text())
    required = {
        "name",
        "description",
        "model",
        "model_reasoning_effort",
        "sandbox_mode",
        "nickname_candidates",
        "developer_instructions",
    }
    missing = required - set(data)
    if missing:
        raise SystemExit(f"{path}: missing {sorted(missing)}")
    print(f"{path}: parse=pass")
PY
```

For prompt, instruction, skill, or agent artifacts, also check readability:
line length, TOML/Markdown parseability, and whether a future agent can follow
the file without checklist bloat. Reformatting generated local `tmp/` artifacts
is acceptable when it is mechanical, parser-preserving, and recorded in the
manifest.

## Instruction Mirror Upgrade Policy

When a multi-harness run selects a best candidate for an agent, skill, prompt,
or instruction file, do not blindly overwrite every runtime mirror. First split
the candidate into:

- portable core: durable judgment rules, hard gates, output shape, safety
  boundaries, and validation expectations that should be shared across
  runtimes;
- runtime adapter: tool names, handoff formats, dispatch contracts, branch
  rules, local skill paths, model knobs, and other harness-specific mechanics.

Adopt the winning portable core deliberately, then preserve or reapply each
runtime's adapter-only contracts. Before accepting a mirror update, compare the
old and new file for removed sections whose headings mention dispatch,
artifact handoff, path safety, hooks, handoffs, model routing, branch rules,
skill paths, or validation policy. Treat an unexplained removal of those
sections as a blocker until reviewed.

When the user provides a "PRO", "best model", "world's best model", or similar
candidate, treat the model label as metadata, not evidence. Require a
candidate-vs-current comparison based on effective behavior contracts:

- name the baseline and candidate artifacts;
- classify material deltas as kept, strengthened, weakened, contradicted,
  duplicated, removed, or newly introduced;
- identify guardrails that would be lost by wholesale replacement;
- separate better wording from rules that actually change future decisions,
  evidence gates, routing, validation, or maintenance outcomes.

If a council vote favors wholesale replacement but any reviewer identifies
fold-backs from the current file, the orchestrator must apply or explicitly
reject those fold-backs before commit. A replacement that drops a guardrail
must either preserve it, justify the removal in the aggregate, or be treated as
not ready for merge.

For instruction files that discuss secrets, tokens, cookies, auth state, or
credentials, keep the security rule explicit but avoid detector-triggering
headings such as `secrets:` inside TOML strings when equivalent wording such
as `sensitive material` preserves meaning. Let pre-commit and detect-secrets
validate the final wording instead of bypassing hooks.

For main-based or open-source-ready PRs, adapt only the portable first-agent
content that belongs on the target branch. Strip internal branch names,
runtime-mirror references, council workflows, local-only artifact paths,
project-specific agent rosters, and adapter contracts that do not exist on the
base branch. Validate with a focused forbidden-term scan in addition to
markdownlint or parser checks.

When the rewrite is substantial, ask at least one independent reviewer or
harness to review the final diff specifically for dropped runtime contracts,
not just prose quality. Provide the old file, new file, validation already run,
and the list of adapter contracts expected to survive. Fix confirmed adapter
regressions before commit or push.

## Capture Repair Policy

Some wrappers prepend stale prior messages, append status summaries, duplicate
the requested artifact, or preserve progress lines before the real document.
Prefer rerun when the output is ambiguous. Deterministic repair is allowed only
when all of these are true:

- the requested artifact has an exact sentinel, such as
  `# Critic TOML Candidate Review` or `name = "critic"`;
- the intended artifact body is complete after that sentinel;
- repair is limited to trimming unrelated prefix/suffix text, removing a
  duplicated complete artifact, or deleting a clearly corrupted duplicate
  wrapper line;
- the repaired artifact passes its parser/linter;
- the manifest records the repair and still treats the wrapper behavior as a
  harness-output defect.

For prompts that include explicit context files, some wrappers append those
context files after the requested artifact. If the requested artifact is
complete and the appended context starts at a clear wrapper heading such as
`## Explicit Local Context Files`, deterministic repair may trim that suffix.
Record the trim in the manifest and do not alter the substantive artifact body.

Do not silently rewrite substantive content to make a harness look correct.
If the requested artifact is incomplete, mixed with another artifact in a way
that changes meaning, or cannot pass validation after deterministic trimming,
rerun that lane with a narrower output contract and a fresh alias when needed.

## Run Manifest And Session Hygiene

Create or update a small run manifest for every multi-harness run. The
manifest is orchestrator-owned evidence, not a harness-authored plan. Store it
under the task's repo-local `tmp/` folder unless the user asks for a tracked
artifact.

Record these fields per harness lane:

```yaml
run_id: <slug>-<date>
phase: independent | stealing | review | aggregation
harness: claude | codex | grok | muse
model_and_reasoning: <exact model/profile/reasoning used>
tool_or_entrypoint: <codex exec high | Codex closeout-review lane | wrapper command>
worktree: tmp/worktrees/<slug>
branch: <branch>
base_commit: <pinned-sha>
session: fresh | reused
session_alias: <alias-or-pending-verification>
session_id: <id-or-pending-verification>
agent_profile: <agent/profile if separate from model>
reasoning_effort: <explicit-effort | default-profile-effort | pending-verification>
reasoning_effort_source: <prompt | wrapper-flag | model-default | pending-verification>
rerun_of: <prior lane id or none>
allowed_inputs: [<paths>]
forbidden_inputs: [<paths>]
source_surface_requirements: [<web | reddit | x-twitter | github | docs | none>]
output_path: <single owned path>
write_scope_check: pending | pass | fail
lint: pending | pass | fail
contamination: none | <reason>
```

Require every harness response in a bias-controlled phase to include a short
session hygiene declaration: worktree, branch, model/reasoning, whether the
session is fresh, allowed inputs seen, forbidden artifacts accidentally seen,
owned output path, and lint result. If any field is unknown, record `Pending
Verification` in the manifest.

Do not guess reasoning effort. Record explicit reasoning settings when a prompt,
wrapper flag, or command line provides them. For Claude Code lanes that need
maximum reasoning, pass `--effort max` through
`scripts/dev/agent-call-claude.sh` and record `wrapper-flag` as the effort
source. Otherwise record `Pending Verification` and state that the runtime did
not expose or receive a separate reasoning-effort knob.

Do not reuse the same implicit session alias across different harness lanes,
agent profiles, phases, or tasks. If a wrapper defaults to a shared session
alias, pass an explicit `--session-alias <task>-<harness>-<phase>` or start a
fresh session before accepting the output. Treat output that refers to a prior
unrelated task as `Contaminated`; rerun the lane in a fresh session rather than
trying to clean the prose after the fact.

## Agent Instruction Preread

Headless harnesses do not reliably invoke repo subagents or inherit their
agent profiles. Every multi-harness prompt must therefore make the applicable
agent instruction file an explicit preread before the harness starts planning
or reviewing.

- For planning, architecture, plan critique, stealing, and aggregation lanes,
  require the harness to read `.codex/agents/critic.toml` first.
- For code review, PR review, diff review, or implementation-review council
  lanes, require the harness to read `.codex/agents/reviewer.toml` first.
- If the user explicitly asks for a reviewer-style planning pass, use
  `.codex/agents/reviewer.toml` for that planning lane and record the override.
- If the user explicitly asks for a critic-style code review, use
  `.codex/agents/critic.toml` for that review lane and record the override.
- Tell the harness to declare the exact agent instruction file it read in its
  session hygiene declaration. If the harness does not declare a successful
  preread, mark the lane `Pending Verification`; if it used the wrong file
  without an explicit user override, mark the lane `Contaminated` before
  aggregation.

Record the selected preread in the run manifest:

```yaml
agent_instruction_preread: .codex/agents/critic.toml | .codex/agents/reviewer.toml
agent_instruction_override: none | <user-requested override reason>
agent_instruction_declared_by_harness: pending | pass | fail
```

Planning and code-review prompts may still include harness-specific mandates
and guardrails, but those do not replace the critic or reviewer preread. The
agent instruction file is the default behavioral contract; the harness mandate
is the lane specialization.

## Codex Lane Selection

Codex has two different lane types in this workflow:

- Planning lane: use `scripts/dev/agent-call-codex.sh --model gpt-6.1-sol
  --effort high` and `.codex/agents/critic.toml`.
- Code-review lane: use the Codex `work-orchestration` closeout-review lane
  and `.codex/agents/reviewer.toml`.

Do not treat Codex high planning output as a substitute for the
Codex closeout-review lane on code, PR, diff, or implementation-review council lanes.
If both Codex planning and Codex code review are requested in one council,
create separate manifest
entries with separate `tool_or_entrypoint`, `agent_instruction_preread`, output
paths, and closeout status.

## Evaluation Contract

Tell every harness that it is one of multiple agents working in parallel on the
same task and that the output is an evaluation artifact. The prompt must say
that the harness will be evaluated against the criteria below, so it should
optimize for intelligence, diligence, evidence quality, and constraint
following rather than speed or generic coverage.

Every plan or review prompt should include this table, or a concise pointer to
it when the table is already present in a requirements file:

| Criterion | What the harness must optimize for |
| --- | --- |
| Writing clarity | Clear structure, readable flow, precise terminology, useful diagrams, and stakeholder usability. |
| Repo grounding | Claims tied to real repo files, workflows, Terraform, services, tests, configs, and command output. |
| Evidence traceability | Major recommendations trace to file paths, source docs, inspected code, command output, or explicit `Pending Verification`. |
| Truthiness / factual discipline | Verified facts, assumptions, and unresolved claims are separated; uncertainty is not over-sold. |
| Non-hallucination | No invented APIs, fake IDs, unsupported product claims, imaginary repo behavior, or plausible-but-false details. |
| Constraint adherence | Correct worktree, branch, model/reasoning mode, allowed inputs, forbidden inputs, output path, linting, and no commit/push unless asked. |
| Operational usefulness | Real workflows, maintenance, failure recovery, handoff paths, and day-2 ownership are covered. |
| Architecture quality | Sound system boundaries, state model, failure modes, simplicity, reversibility, and extensibility. |
| Security and access judgment | Least privilege, trust boundaries, identity design, secrets handling, permission scope, and blast-radius control. |
| Decision-confidence model | Hard gates, scoring, hold states, backtesting or replay, promotion criteria, revert criteria, and graduation criteria. |
| Risk identification | Material failure modes, unsafe assumptions, access risks, data risks, operational edge cases, and rollout risks are surfaced. |
| Prioritization quality | Correct sequencing: mechanical safety before automation, advisory before autonomy, prerequisites before optional features. |
| Simplicity / buildability | A buildable POC with minimal speculative platform sprawl, avoidable swarm complexity, and unnecessary abstractions. |
| Verification plan | How to prove the plan works: lint, tests, backtests, historical replay, simulations, drills, and revert checks. |
| Actionability | Concrete phases, workstreams, commands, files to change, validation gates, owners or owner placeholders, and measurable next steps. |
| Bias control | Independent phases avoid forbidden context; stealing phases are labeled; contamination, reused sessions, or wrong model settings are disclosed. |
| Web/search-source capability | External-source claims disclose whether they came from direct fetches, search snippets, authenticated-only pages, blocked fetches, or `Pending Verification`. |
| Overall score | Combined judgment across the criteria above. |

Make `Constraint adherence`, `Evidence traceability`, and `Bias control`
non-negotiable: a plan that violates them can be useful as raw material, but it
must be marked contaminated or `Pending Verification` before aggregation.

For research tasks that require current external sources, Reddit, X/Twitter,
or broader sentiment, score source reach separately from factual discipline.
Broad sentiment coverage is useful only when the underlying threads, posts,
issues, or pages are linked or explicitly marked as search-snippet-only,
blocked, authenticated-only, or `Pending Verification`.

## Harness Strengths

Give each harness a differentiated mandate so the plans do not collapse into
the same generic answer. Include the relevant row in that harness's prompt.

| Harness | Primary mandate | Guardrail |
| --- | --- | --- |
| Claude Code / Opus | Optimize for deep architecture, state machines, policy design, failure modes, security boundaries, and uncomfortable risk analysis. | Lead with the few decisions that matter; put sprawl in appendices; mark unverified environmental facts `Pending Verification`. |
| Codex / high planning | Optimize for repo-grounded implementation detail, exact files to change, buildable slices, validation commands, and operational constraints. | Use only for planning lanes; state the highest-impact architecture tradeoff before implementation slices; every repo claim should cite an inspected file or command. |
| Codex Review | Optimize for stable-target code review findings through the Codex `work-orchestration` closeout-review lane, including accepted/rejected findings and focused validation. | Use for code, PR, diff, and implementation-review lanes when the Codex lane is available; do not replace this with plain headless Codex unless unavailable or explicitly requested. |
| Grok | Optimize for pragmatic workflows, recovery mechanics, operator handoffs, edge cases, and concise action sequencing. | Include at least one concrete execution/checklist/drill or stop condition for substantial plans; external landscape claims need sources or `Pending Verification`. |
| Muse / `muse-spark-1.3-contributor` | Optimize for a concrete alternative contribution with implementation tradeoffs, edge cases, and observable validation. | Keep the lane read-only unless separately delegated; cite current repo evidence and mark unverified model, runtime, or external claims `Pending Verification`. |

## Council Review Mode

Use council review mode only when the user explicitly asks multiple harnesses
to review the same PR, diff, plan, or artifact. Ordinary single-review PR work
still belongs to the PR review skills.

1. Create a neutral read-only packet under `tmp/council-<slug>/` with the
   prompt, target metadata, diff or document paths, and any allowed command
   output. Keep the packet factual; do not seed preferred conclusions. Include
   the captured-output contract in the prompt: the final response must be the
   complete review document, start with the requested review heading, and avoid
   progress logs or status prose before the heading.
2. Give every lane the same packet, the same allowed inputs, and a single owned
   output file such as `tmp/council-<slug>/<harness>-review.md`.
3. Keep council lanes read-only unless the user explicitly asks a harness to
   implement. Do not let council runs mutate PRs, resolve review threads,
   commit, push, or edit shared docs.
4. Require each lane to declare session alias, session id, model/reasoning,
   allowed inputs, forbidden inputs, and whether it inspected the assigned
   branch or only a packet.
5. Verify material findings against the real target before reporting or
   applying them. A consensus finding is still only a lead until the
   orchestrator checks the correct branch, base, caller, config, or command.
6. Reject or mark `Contaminated` any finding based on a different checkout,
   stale branch, wrong base branch, forbidden folder, or prior session context.
7. If a review suggestion changes code or configuration, validate the resulting
   implementation with the target tool. Do not copy a reviewer's proposed
   expression, command, or config as proof that it is valid.
8. When the accepted fix is narrow and low-risk, such as reviewer-facing docs,
   comments, or metadata, do not rerun the whole council just to confirm the
   wording. Verify the fix locally, push when appropriate, and check the new PR
   head plus relevant CI or workflow runs. Rerun affected review lanes only
   when the fix changes runtime behavior, generated contracts, migrations,
   security/data boundaries, or a previously contested finding.
9. After applying accepted council findings to an open PR, treat the PR body as
   part of the reviewer-facing artifact. Re-read the live title/body and update
   stale scope, risk, validation, dependency, operator-note, or status-block
   text before final handoff. If the PR body already matches the final diff and
   CI state, say that it was checked.
10. When a final review rerun emits tool stderr, broad validation attempts, or
    harness setup failures, separate harness noise from code findings. Fix
    discrete findings that cite the current target and verified behavior; record
    harness-only validation gaps without treating them as PR defects.

## Plan Quality Gates

For substantial plans, require these sections before handoff unless the user
explicitly asks for a shorter artifact:

1. **Assumption Ledger:** assumption, current evidence, risk if false, and how
   to verify it.
2. **Decision Log:** key decisions, rejected alternatives, and why the chosen
   path is safer or easier to operate.
3. **Tradeoff Table:** compare at least two viable architecture or rollout
   options for the highest-impact decisions.
4. **Failure-Mode Inventory:** cover the planned workflow, revert path,
   observability, access controls, data/state changes, automation runtime,
   external dependencies, and handoff points.
5. **Implementation Slice Map:** P0/P1/P2/P3 or equivalent reviewable slices,
   each with validation gates and revert/stop criteria.
6. **Novel Contributions:** at least three non-obvious ideas, checks, or
   simplifications beyond restating the prompt and existing docs.
7. **What Would Change My Mind:** evidence or discoveries that would change the
   recommendation, sequence, or autonomy level.
8. **Self-Critique And Fixes Applied:** the harness must red-team its own draft,
   list the top problems it found, and state what it changed before handoff.

The self-critique is a required gate: if the harness cannot name at least three
meaningful weaknesses, missing facts, or failure paths in its own plan, ask it
to run another pass before accepting the output.

For small planning artifacts, use lite mode: require the evaluation contract,
session hygiene declaration, evidence traceability, a concise risk list, and
markdownlint, but do not force every quality-gate section. Use the full gates
for architecture, security, data, workflow, automation, or multi-week plans.

## Bias Control

Treat bias as a workflow risk, not a prose problem. The orchestrator must choose
which artifacts a harness can see at each phase and record any contamination
that could change how results are interpreted.

1. First-pass plans must be independent. Give each harness the same user
   requirements and repo access, but do not provide other harness plans,
   review documents, score tables, or summaries.
   Prefer context construction over prohibition: do not copy or integrate peer
   outputs into a harness worktree until the phase where that harness is
   allowed to read them.
2. Cross-harness stealing is intentionally biased. Make that phase explicit:
   each harness may read only the other first-pass plans named in the prompt,
   may update only its own plan, and must preserve attribution when a stolen
   idea materially changes its recommendation, priority, validation plan, or
   risk framing.
3. Independent review folders must not see prior review folders. When a harness
   writes `<planning-root>/<reviewer>/`, forbid reads of every sibling reviewer
   folder, not only the folder most likely to bias it.
4. The orchestrator must follow the same restriction. Do not use broad `find`,
   `rg`, `cat`, or summarization commands that inspect forbidden folders during
   a bias-controlled run.
5. Aggregation is allowed to read all completed review folders only after every
   reviewer folder is finished and linted.
6. If a harness saw a forbidden artifact, reused a contaminated session, ran
   with the wrong model or reasoning effort, or could not prove isolation,
   label that result `Pending Verification` or disclose the bias before using
   it in eval tables.
7. Use these contamination states in manifests and summaries:
   `Independent`, `Biased-Stealing`, `Biased-Review`, `Contaminated`, and
   `Pending Verification`.
8. Default to one stealing round. If more rounds are needed, record what
   converged across plans so aggregation does not mistake shared contamination
   for independent agreement.
9. When a harness output names the wrong task, cites unrelated documents, or
   appears to continue an older conversation, stop using that output as a
   review or plan. Rerun the lane with a fresh explicit session alias and a
   narrowed input packet.
10. When a reviewer claims the target is stale, conflicted, or based on the
    wrong branch, verify that claim against the assigned branch and base before
    aggregating it. A reviewer inspecting the orchestrator's root checkout
    instead of the assigned worktree is a contaminated evidence path.

## Phase 1: Fan Out Independent Plans

1. Start from the current root branch, usually `local-dev-reference`, but cut each
   harness worktree from `main` unless the user says otherwise.
2. Preflight the root checkout and existing worktrees:

   ```bash
   git status --short --branch
   git worktree list
   git fetch origin main
   BASE_SHA="$(git rev-parse origin/main)"
   ```

3. Create one worktree per harness under `tmp/worktrees/<slug>` from the pinned
   base SHA; never switch
   the root checkout:

   ```bash
   git worktree add -b <branch-slug> tmp/worktrees/<slug> "$BASE_SHA"
   ```

4. Give each harness one owned worktree and one owned output path. Do not let
   two harnesses write the same file.
5. Tell each harness to inspect the repo directly from its assigned worktree,
   use current external docs when the request requires current facts, and write
   a markdown plan under the requested docs folder with a harness suffix.
6. Tell each harness this is a parallel evaluation against the criteria in
   `Evaluation Contract`; require it to optimize for evidence, diligence, and
   constraint adherence.
7. Include that harness's row from `Harness Strengths` in the prompt and require
   the `Plan Quality Gates` sections for substantial planning artifacts.
8. Require each harness to run markdownlint on its own document before handoff:

   ```bash
   npx markdownlint-cli2 <doc-path>
   ```

9. Commit each harness document in its own worktree when the user asks for
   per-worktree commits. Do not push those scratch branches unless requested.

## Phase 2: Cross-Harness Stealing

After all first-pass plans exist:

1. For each harness, provide the other harness plan documents as read-only
   context. Exclude that harness's own draft unless the task is to revise it.
2. Tell the harness to identify the best ideas to steal, update only its own
   plan document, and preserve attribution for material adopted ideas.
3. Keep write scopes stable: each harness edits only its own document in its
   own worktree.
4. Tell the harness that this phase is intentionally biased and that it will
   still be evaluated for attribution, bias disclosure, and constraint
   adherence.
5. Require a short self-critique after stealing: what it adopted, what it
   rejected, what became weaker or riskier, and what it fixed.
6. Require a steal ledger: adopted from, rejected from, changed recommendation,
   and remaining bias or `Pending Verification`.
7. Require markdownlint before handoff.
8. Inspect each updated document and integrate or copy the final documents back
   to the root branch path requested by the user.

## Phase 3: Independent Review Folders

When the user asks for review folders such as
`<planning-root>/grok`, `<planning-root>/claude`, or
`<planning-root>/codex`:

1. Start a fresh session for the reviewing harness.
2. Pass only the source plan documents and a requirements file as context.
3. Add an explicit bias-control rule that forbids reading other review folders.
   Example: when writing `<planning-root>/codex`, forbid reads of
   `<planning-root>/grok` and
   `<planning-root>/claude`.
4. Ask for one review document per source plan in the reviewer-owned folder.
5. Tell the reviewer that its review quality will be evaluated against the
   `Evaluation Contract`, especially evidence traceability, truthiness,
   non-hallucination, risk identification, and bias control.
6. Require each review to include:
   - reviewed document path
   - executive verdict
   - rating table
   - GOOD
   - BAD
   - UGLY
   - best ideas to steal
   - required corrections
   - `Pending Verification`
   - structured score block when aggregation will parse numeric scores
7. Require markdownlint before handoff:

   ```bash
   npx markdownlint-cli2 <planning-root>/<reviewer>/*.md
   ```

8. Spot-check the reviewer-owned folder only. Avoid broad `find` or `rg`
   commands that inspect forbidden review folders during bias-controlled runs.
9. Do not ask a harness to score a plan it authored or materially rewrote
   during a stealing phase unless unavoidable. If unavoidable, label the score
   `Pending Verification` and do not let it dominate the average.

## Phase 4: Recursive Final-Package Evaluation

Use this phase when the user asks the harnesses to evaluate the revised or
final packages that were already produced from an earlier stealing, review, or
scoring round.

Do not use this phase for proofreading, linting, rewriting, or cleaning up one
document. It requires multiple harness-authored final packages and a request to
compare or aggregate verdicts across them.

1. Wait until every final package is present, linted, and listed in the run
   manifest. A package can be one final artifact or a folder pair such as
   `updated-plan.md` plus `rating-table.md`.
2. Give every evaluator the same final-package list and the same aggregate
   context allowed by the user, such as a prior average-score table. Forbid
   reads of sibling recursive-evaluation folders until all evaluator verdicts
   are complete.
3. Reuse sessions only when the user explicitly asks for reuse and the manifest
   records the session id. Otherwise start fresh explicit aliases per harness,
   phase, model/profile, and output folder.
4. Ask each harness to write one verdict document in its own folder. Require:
   - session hygiene declaration
   - final packages read
   - forbidden recursive-evaluation folders not read
   - ranked winner list
   - chosen best final package and rationale
   - strongest objection to the winner
   - what non-winners contributed better than the winner
   - compact score table when numeric aggregation may follow
   - relationship to any prior average-score table
5. Aggregate only after every verdict is complete and linted. Report first-place
   votes, dissenting winners, top-tier clusters, consistent weak placements,
   and how the final-package verdict differs from earlier score averages.
6. Treat repeated conclusions from reused sessions as converged judgment, not
   independent evidence. Disclose reuse in the aggregate and avoid overstating
   vote independence.

## Phase 5: Artifact Implementation And Review Loops

Use this phase when the user asks harnesses to turn the winning plans or final
packages into concrete local artifacts, such as TOML agent files, prompt
templates, instructions, ADRs, or scripts, and then compare those artifacts.

This phase is still draft-oriented unless the user explicitly asks to edit the
real tracked source of truth. By default, each harness writes only inside its
owned `tmp/<task>/<harness>/` folder.

1. Give each harness the source artifact, the aggregate judgment, its own final
   plan/review, and the exact owned output path.
2. Require raw artifact output, not a report, when the deliverable is code,
   TOML, JSON, YAML, or another parser-backed file.
3. Validate every candidate by artifact type before any review round:
   - Markdown: `npx markdownlint-cli2 <paths>`
   - TOML: Python `tomllib`
   - JSON: `python -m json.tool`
   - YAML: repo-approved YAML tooling, or `Pending Verification` if none is
     configured
   - Shell scripts: `bash -n`
   - Instruction/prompt files: parser or lint plus line-length/readability
     checks
4. If the user asks for candidate review, feed all parser-valid candidates back
   to the harnesses as artifacts, not as plans. Require a ranking table, best
   base to ship, required edits before shipping, ideas to steal, and bloat or
   maintainability risks.
5. If the user asks for self-review refinement, allow only the named harnesses
   to update their own candidate artifacts. Validate again and record line
   counts, max line length, parser result, and changed phase in the manifest.
6. Distinguish the peer-vote winner from the production base. The best concept
   or most popular artifact may not be the safest tracked-file base if another
   candidate is shorter, easier to merge, parser-cleaner, or less likely to
   cause checklist theater. Record both when they diverge.
7. For replacement candidates, require a change ledger against the current
   tracked artifact before accepting the candidate as production-ready. The
   ledger should list kept, strengthened, weakened, removed, duplicated, and
   newly introduced behavior contracts. Do not accept "better" claims that are
   not present in the saved candidate file.
8. Only after candidate review and validation should the orchestrator synthesize
   the real tracked artifact. The orchestrator owns the final edit, mirror
   parity, validation, commit, and push.

## Operational Edge Cases During Orchestration

- If a harness times out, loses auth, or produces an unusable artifact, proceed
  with the surviving harnesses only when useful. Label the run partial, record
  the missing evidence, and rerun the failed lane only in a clean worktree and
  fresh session.
- If a harness repeatedly hits a turn cap or max-turns failure, rerun once with
  a shorter prompt, a tighter output contract, and the same read-only input
  boundaries before marking the lane blocked. Record both failed attempts and
  the final retry session id when it succeeds.
- If a harness returns low-evidence but plausible output, keep it as raw input
  but cap its aggregation influence until its claims are verified or labeled
  `Pending Verification`.
- If planning is happening under urgent time pressure, use fast mode: shorten
  prompts, ask each harness for "what to do now" versus durable design, and
  default to the smallest reversible action with the lowest blast radius.
- If worktree creation collides with an existing branch/path, inspect status
  and either reuse it only when it is clean and intentionally continuing, or
  create a new slug. Do not clean broad repo-root `tmp/` paths.
- Do not remove worktrees until final documents are copied back, linted, and
  either committed where requested or explicitly marked disposable. Remove with
  `git worktree remove <path>`, not broad shell deletion.

## Harness Defaults

Use the strongest practical mode for planning/review quality:

- Claude Code: `scripts/dev/agent-call-claude.sh --profile opus --effort max`
  for Opus planning/review lanes that need maximum reasoning.
- Grok: use `scripts/dev/agent-call-grok.sh --model grok-4.6` for an
  explicitly selected brokered council lane. Supply the prompt by file or
  stdin. Use the explicit contributor role/write/worktree triplet only when
  the lane owns one clean registered linked worktree.
- Muse: use `scripts/dev/agent-call-muse.sh --model
  muse-spark-1.3-contributor` with `--role contributor` for planning or
  alternative-contribution lanes and `--role reviewer` for review lanes. Both
  roles are read-only. Use aliases/resume only for public council material;
  private-approved calls are memory-only and must not resume.
  Treat the mounted checkout as context: for this private repository, add
  `--target-class private --context-class private-approved
  --confirm-contributor-data-use` without asking a second wrapper-only question.
  For later stealing, review, or recursive-evaluation phases, start a fresh Muse
  call and re-inject only the approved phase inputs. Do not relabel private
  council material as public merely to reuse a session.
- Codex: use `gpt-6.1-sol` with `high` for normal planning, review, final
  synthesis, and bounded follow-up lanes. Use `xhigh`, `max`, or `ultra`
  only when the current user explicitly requests it, and pass
  `--allow-user-requested-elevated-effort`. If Sol is unavailable through the active
  auth path, mark the lane `Pending Verification` rather than silently changing
  its model.

## Aggregation

When producing eval tables:

1. Read the run manifest first. Exclude or cap outputs marked `Contaminated` or
   unresolved `Pending Verification`.
2. Parse rating tables from all review folders rather than averaging manually.
3. Require or normalize stable numeric rating-table columns. Preferred columns
   are `Criterion`, one column per evaluated harness/report, `Winner`, and an
   optional rationale column. Require one `Overall score` row when an average
   ranking will be produced.
4. Normalize equivalent labels such as `Criterion`, `Criteria`, `Dimension`,
   and `Category`.
5. Treat `Constraint adherence`, `Evidence traceability`, and `Bias control` as
   gating criteria. A plan that fails one of them cannot win on overall score
   until the failure is disclosed and corrected.
6. Report score spread or disagreement when reviewers diverge materially; high
   variance is a signal, not noise.
7. Separate "best idea/concept winner" from "best production base" when the
   artifact will be merged into a tracked instruction, prompt, config, or code
   file. Vote count and average score identify the strongest peer preference;
   production-base choice should also weigh parser validity, line count,
   readability, merge safety, mirror impact, and risk of checklist bloat.
   Model prestige, self-described model strength, or prose fluency must not
   override lost-contract evidence.
8. When evidence conflicts on blast radius, revert safety, or user-facing
   risk, default to the most conservative posture that still preserves a
   buildable POC slice.
9. Include evaluator metadata in any user-facing aggregate document: evaluator
   name, harness, model/profile, reasoning effort, reasoning-effort source, and
   session id. Use `Pending Verification` for reasoning effort when the runtime
   does not expose a separate knob. Use durable profile defaults when known,
   such as Claude Opus 5 high reasoning by default.
10. Report model/harness labels in user-facing terms, for example:

    - `Claude Opus 5 / Claude Code`
    - `Grok / Grok`
    - `Muse Spark 1.3 Contributor / Muse`
    - `GPT-5.6-Sol (high, or user-requested xhigh|max|ultra) / Codex`

11. If a model was accidentally run with the wrong reasoning effort, state that
   plainly and use the correct setting in future runs.
12. For external-research councils, keep `Sentiment coverage` distinct from
    `Truthiness / factual discipline`, `Evidence traceability`, and
    `Web/search-source capability`. A harness may win sentiment breadth while
    still losing factual discipline if its social claims are not directly
    linked or are only snippet-backed.

## Closeout

Before commit or push:

1. Run markdownlint for the changed docs.
2. Check mirror parity for `.codex`, `.agents`, and `.claude` copies when the
   skill exists in more than one runtime.
3. Run the Waza eval suite for this skill when the skill or its evals changed.
4. Check `git status --short --branch`.
5. Stage explicit paths only.
6. Let repo hooks run through `git commit`.
7. Push only when the user asks.

After worktree-based fan-out is complete and final docs are integrated, delete
only the explicit worktrees the workflow created. Never clean the whole
repo-local `tmp/` directory.
