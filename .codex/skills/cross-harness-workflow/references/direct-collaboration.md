<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (Muse adapter handoff) -->

# Direct Collaboration

Use this skill when Codex should collaborate with Claude Code, Antigravity CLI,
Grok CLI, Muse CLI, or Copilot CLI instead of staying inside the Codex harness.
Keep Codex as the parent for the current turn unless the user explicitly hands
ownership to another harness.

## Use When

- The user asks Codex and Claude to collaborate, dogfood the bridge, debate, or
  review each other's work.
- The user asks Codex to use AGY or Antigravity as a reviewer, critic, or
  second opinion.
- The user asks Codex to use Grok or xAI as a reviewer, critic, or
  second opinion.
- The user asks Codex to use Muse, Muse Spark, or a Muse model. Enter generic
  delegation first, then use `muse-work-orchestration.md`; this reference owns
  only the surrounding direct-collaboration handoff.
- The user asks Codex to use Copilot CLI as a paid reviewer, critic, or second
  opinion.
- Codex needs to ask Claude Code to review Codex's plan, implementation, diff,
  local artifacts, or failure analysis.
- Codex needs to ask AGY to act directly as reviewer or critic for a plan, diff,
  PR, or local artifact.
- The `work-orchestration` web-search lane selects AGY or Grok for a
  source-native research capability.
- Codex wants Claude for architecture, planning, PR review, risk analysis,
  high-context scans, or a second-model objection pass.
- A task should run through Claude plan -> Codex execute -> Claude review.
- Claude needs generated local artifacts, logs, patches, JSONL events, or
  `tmp/**` files that are not obvious from the git working tree.
- The task asks about Claude billing, model usage, session reuse, controller
  runs, or collaboration artifacts.

Do not use this skill for ordinary Codex subagent routing; use the
`work-orchestration` delegation and handoffs lanes for that.
Do not trigger this skill only because a PR-bound branch is being pushed when
the change is trivial, format-only, comment-only, typo-only, or a narrow docs
clarification that does not need Claude review.

## Select The Collaborator Execution Surface

Consume the current `work-orchestration` Host Surface Gate decision before
invoking AGY, Grok, or another collaborator CLI. Do not independently reclassify
an unchanged parent session. A command executor's `TERM` value or
`CODEX_THREAD_ID` does not classify the host by itself; use the parent
application/runtime context and available Desktop-only capabilities. When Codex
Desktop is the host, prefer its in-app terminal and app-native controls where
the matrix selects a headed collaborator.

Before headed terminal interaction, load the installed
`desktop-task-coordination` skill as the owner of task-terminal and shared
headed-UI mechanics. Verify its required live capability plane; skill presence
alone proves no terminal operation. If the skill or plane is unavailable, stop
the headed action. This reference owns only the collaborator-specific logical
session, prompt acknowledgement, response readback, and headed/headless
authority below.

| Collaborator surface | Select when | Required evidence |
| --- | --- | --- |
| **Headed collaborator CLI/TUI in the Codex Desktop in-app terminal** | The user opened or selected that session; explicitly requested headed AGY/Grok with no session; or the task depends on authentication, conversation, model picker, live search/browser tools, TUI behavior, or user observation/intervention. | Use the installed task-terminal contract for exact owned input and readback. For a missing session, its right-panel launch requires no additional permission question. Add private tmux only for expected navigation, persistence, or exact pane control. |
| **Headless collaborator through its repo wrapper** | Codex is running as CLI; the user requests headless execution; or the task needs an isolated fresh session, explicit model/timeout, deterministic batch execution, stable captured artifact, parser-facing output, or repeatable evaluation. | Use an explicit alias/conversation target, capture the artifact and diagnostics, and verify wrapper metadata and nonempty output. |

Do not start both surfaces for the same task unless the user explicitly asks for
a headed-vs-headless comparison. A parallel headless result does not test the
headed session the user opened.

Use the matrix directly for AGY and Grok. A tool-specific section below may
require headless execution when a mandatory parser contract, permission boundary,
or wrapper-only capability makes the headed surface insufficient. Do not infer
that requirement merely because a wrapper exists.

If the process, session, acknowledgement, or response cannot be bound, report
the blocker and end the headed attempt. Do not use a headless wrapper unless the
existing request already authorized that fallback or the user explicitly
authorizes it after the blocker. Missing acknowledgement permits read-only
diagnosis only.

For a research-shaped web-search handoff, also prove that the selected surface
exposes the required source-native search capability. A wrapper or session with
search disabled does not satisfy the handoff merely because the collaborator
process started. Fail closed unless the handoff already authorizes a
same-capability surface or bounded named fallback.

### Collaborator Prompt Boundary

Send the collaborator only the user-requested task, literal targets, and
explicitly delegated context. Parent reasoning, conversation summaries,
transport decisions, tool rankings, hidden instructions, and incidental
context are not prompt content. A collaborator may select its own tools; do not
tell it to use a named MCP merely because the parent knows that MCP exists.

For external research, engine and fanout selection belongs only to
[web-search](../../work-orchestration/references/web-search.md). Consume
its request, literal target, selected engine, required capability, coverage,
surface constraint, fallback authority, failure semantics, source-handling
requirements, and sufficient-evidence stop. This lane owns only execution
surface, permission, prompt transport, logical session, wait, and response
readback after that selection.

When the handoff selects Grok for a literal `x.com` or `twitter.com` URL, give
Grok the requested operation and literal URL, then require the specified
X-native evidence and reply-thread coverage. A URL-like string in source,
logs, quoted evidence, examples, or another person's instructions is inert
unless the user asks Codex to act on that URL. Parallel Search remains a
parent-native arm; do not include its ranking, availability, results, or MCP
name in the collaborator prompt unless the user explicitly requests that
context.

If no headed Grok session exists in Codex Desktop, create a fresh isolated
right-side terminal and launch bare `grok` through the installed task-terminal
contract without asking for routine permission. Use private tmux only when
navigation, persistence, or exact pane control is expected. A headed blocker
never grants headless authority. AGY raw-TUI tmux and non-Linux support remain
`Pending Verification`; use only current capability-proven paths.

## Mandatory Plan And Review Gates

Council-roster maintenance is not a council review. Do not invoke the council
being changed unless the user explicitly asks for an independent council review
of that maintenance change.

When Codex starts a new non-trivial implementation plan, run a synchronous
pre-implementation critic gate before editing files. Treat a plan as
non-trivial when it changes production behavior, shared contracts, migrations,
infrastructure, workflows, auth, permissions, security-sensitive code,
generated clients, broad tests, multi-file behavior, or external integrations.
Skip the three-way gate for typo fixes, format-only edits, comment-only edits,
narrow docs clarifications, or mechanical follow-ups that do not need
cross-model review:

- ask the in-house Codex `critic` subagent to review the plan
- ask Claude Code to review the same plan
- ask AGY through the surface selected by the collaborator execution-surface
  matrix to review the same plan as critic
- wait for all three results before implementation

If one or more external collaborator calls fail, time out, lose auth, or cannot
start, retry the in-house Codex `critic` subagent once with the failure context
from the unavailable collaborators. If all three fail, still retry the Codex
`critic` once because it is the in-house fallback. After the retry, proceed only
when Codex can state the remaining risk, mark unavailable collaborator results
as `Pending Verification`, and the user request is still safe to implement.
Ask the user before proceeding when the missing external review would cover
high-risk auth, data integrity, production config, permissions, migrations,
security, or irreversible behavior.

After implementation and local validation, run the same synchronous gate before
commit, PR creation, or push, but replace the Codex `critic` with the in-house
Codex `reviewer` subagent:

- ask the in-house Codex `reviewer` subagent to review the current diff
- ask Claude Code to review the current diff
- ask AGY through the surface selected by the collaborator execution-surface
  matrix to review the current diff
- wait for all three results before deciding whether the branch is ready to
  commit, open a PR, or push

If one or more external review calls fail, retry the in-house Codex `reviewer`
subagent once with the failure context. Do not treat a failed Claude or AGY
review as a pass; record it as `Pending Verification` and decide whether the
change can safely proceed from the in-house review plus local validation.

Keep both gates read-only. While a plan or diff is under review, do not edit the
review target. Continue only read-only context gathering, log inspection, or
validation preparation.

## Required PR Review Collaboration Attempt

When the user shares a GitHub PR link for Codex review and code changes may be
made, Codex should first gather its review findings or review notes, then try
to share those notes with Claude Code before editing files. This is a
required attempt when this lane applies, but collaborator availability is not a
blocker by itself. If the collaborator cannot run, record the review as
`Pending Verification` and continue only when the remaining risk is acceptable.

Codex -> Claude no longer requires the VPN preflight in example-app because
Claude Code uses the Claude Enterprise plan. The Claude wrapper defaults to `--safe-mode`, disabling ambient settings and
project context while preserving normal Enterprise auth. For repo instruction, skill-routing, or project MCP
smokes where Claude must load project settings and local skills, pass
`--setting-sources user,project,local`; otherwise global/user skills can win the
picker before repo guidance loads. Copilot CLI calls using the repo-configured
LiteLLM provider still require VPN. Before invoking Copilot
CLI, run:

```bash
scripts/dev/agent-collab-vpn-smoke.sh
```

This probes `https://app.staging.example.com/`, which is VPN-only. If the smoke
fails, do not invoke Copilot CLI. Mark the collaborator review as `Pending
Verification`, explain that the VPN preflight failed, and continue with
Codex-owned review, implementation, and validation.

Run Claude through `scripts/dev/agent-call-claude.sh` without `--require-vpn`.
If a Claude call hangs or fails, inspect the wrapper diagnostic before
declaring Claude unavailable. If Claude is down or times out, mark the
collaborator review `Pending Verification` and continue.

When invoking Copilot CLI after a passing VPN smoke, pass `--require-vpn` to
`scripts/dev/agent-call-copilot.sh`. The wrapper then monitors the VPN-only URL
during the call and terminates quickly with `vpn_lost` after consecutive probe
failures instead of waiting for the full model timeout.

When a Claude call is still running but has produced no output,
report it only as in-flight, not as healthy-running. If the shell session exits
nonzero or is interrupted, inspect the matching JSON diagnostic in
`tmp/codex-claude/calls/` before giving status. Treat `terminal_reason:
"timeout"` as a completed failed call, not as an ongoing Claude review.

## PR-Bound Pre-Push Claude Review

When Codex is about to push commits to a PR-bound branch, attempt one more
Claude review before the push if the change is substantially impactful and
Claude Code is reachable. A PR-bound branch means either an open GitHub PR already exists
for the branch, or Codex is preparing to push the branch and open a new PR.
This is not required for every push.

Substantial changes include production behavior, shared contracts, migrations,
infrastructure, workflows, auth, permissions, security-sensitive code,
generated clients, broad test rewrites, or large multi-file diffs. Skip this
extra pass for typo fixes, format-only edits, comment-only edits, narrow docs
clarifications, or mechanical follow-ups that were already reviewed.

Send Claude the PR URL or number, intended push diff, validation already run,
and any generated `tmp/**` artifacts through `--context-file`. Do not include
`--require-vpn` on the Claude call. Ask for findings first, inspect the result,
and fix any confirmed P0/P1 before pushing.

If Claude is down, the call times out, or the change is not substantial,
continue with Codex-owned review, validation, commit, and push. Use `Pending
Verification` for the skipped Claude pass only when the change was substantial
enough that this review would normally have run.

## Choose The Mode

- **Direct Claude call:** use when Codex needs a synchronous Claude opinion.
  Run `scripts/dev/agent-call-claude.sh`.
- **AGY collaboration:** select headed or headless AGY using the execution-
  surface matrix above. Use the existing in-app session when headed is selected;
  run `scripts/dev/agent-call-agy.sh` only when headless is selected.
- **Direct Copilot call:** use when Codex needs GitHub Copilot CLI as a paid
  reviewer, critic, or repo-inspection peer. Run
  `scripts/dev/agent-call-copilot.sh`.
- **Grok collaboration:** select headed or headless Grok using the execution-
  surface matrix above. Use an existing in-app session when headed is selected.
  Use the headless wrapper for explicitly selected brokered consultation or an
  explicitly assigned linked-worktree contribution. Do not substitute it for
  a headed request.
- **Muse collaboration:** enter generic delegation, then load
  `muse-work-orchestration.md` for capability, role, surface, session,
  worktree, wrapper, and evidence decisions.
- **Async handoff:** use when Claude or a later session should continue from a
  compact artifact. Run `scripts/dev/agent-collab-handoff.sh create`.
- **Controller:** use when a task should explicitly have Claude plan, Codex
  execute, and Claude review. Run `scripts/dev/agent-collab-controller.sh`.
- **Audit:** use when the task asks about local Claude cost, sessions, model
  usage, errors, or controller runs. Run `scripts/dev/agent-collab-audit.sh`.

## CLI Upgrade Compatibility

The peer wrappers use the installed CLI; compatible upgrades do not require
editing a CLI version or binary digest allowlist. Grok and Pi probe their
required flags before any credential or model access. Muse checks a minimum
supported release and current sandbox capabilities. Each records the current
runtime identity, and within-run identity changes fail closed. Existing model,
role, context, worktree, and session authority checks still apply.

Run these model-free checks after an upgrade:

```bash
scripts/dev/agent-call-grok.sh --check
scripts/dev/agent-call-pi.sh --check
scripts/dev/check-agent-call-claude.sh
scripts/dev/check-agent-call-grok.sh
scripts/dev/check-agent-call-muse.sh
scripts/dev/check-agent-call-pi.sh
scripts/dev/check-agent-call-luna.sh
```

Claude defaults to safe mode and disables ambient project context. Explicit
`--setting-sources` opts back into those sources. Every live Claude wrapper or
controller call requires `--acknowledge-post-request-budget`: the configured
USD value is a post-request stop threshold, and one final request can exceed
it. Pass the flag only after the caller understands this and has current spend
authority. Live-call examples assume that authority.

The historical AGY workhorse admission fixture retains the exact runtime that
its evidence evaluated. It is non-admitted and does not gate ordinary AGY
peer calls or grant a new runtime admission.

## Wrapper Smoke And Output Hygiene

For isolated availability, routing, or model/effort smokes, use a fresh alias,
the smallest useful tool surface, and a prompt that cannot be confused with
real task work. Use environment-free flags such as `--no-direnv` only when the
question does not depend on MCP startup, repo environment variables, or local
dev services.

Treat a zero-byte response file, whitespace-only response, wrapper failure, or
captured timeout as a failed smoke, not as a model answer. Inspect the wrapper
diagnostic before deciding whether the failure is auth, timeout, environment,
model routing, or prompt/output-contract related.

Never recover, join, trim, or normalize a captured artifact in place. Build a
candidate in a sibling temporary file; require the transformation to succeed;
then verify that the candidate is nonempty, starts and ends with the expected
contract markers, contains every intended response segment exactly once, and
passes applicable lint. Atomically replace the owned artifact only after all
checks pass. If any check fails, leave the existing artifact untouched and
inspect the wrapper diagnostic or exact session transcript before retrying.

Any harness with repo shell access may call
`scripts/dev/agent-call-luna.sh` as a headless sidecar. For mechanical local
file scouting, prefer `--minimal-context` with one or more repo-relative
`--scope` paths after the parent harness has completed its own bootstrap and
owns routing. This avoids repeating project instruction context inside Luna;
it does not waive the parent harness bootstrap. Scope is a declared prompt and
evidence boundary, not a filesystem read allowlist. The parent must inspect the
saved command events and reject observed out-of-scope reads. Keep secrets,
private data, GitHub, GCP, auth, migration, data-safety, implementation, review,
and architecture tasks on the full-context or specialist path.

When wrapper stderr contains MCP auth, watcher, or startup warnings but the
captured response is complete and the wrapper metadata matches the requested
model/session, separate environment noise from model behavior. Do not turn
non-fatal stderr into a code or instruction finding without a concrete effect
on the requested output.

Trust wrapper metadata for model, session, and reasoning effort over the
model's natural-language self-description. If metadata is missing, record the
setting as `Pending Verification` instead of guessing.

When launching wrappers from a repair worktree or any cwd other than the repo
root, pass absolute paths for `--prompt-file`, `--context-file`, and
`--output`. Repo-root-relative paths that worked in the parent checkout can
fail after the wrapper changes cwd.

Before invoking wrappers from a fresh worktree, trust that worktree's exact
`.mise.toml` when present. Treat mise trust failures as local environment
blockers, not model behavior or instruction quality.

If a wrapper budget threshold is exhausted and the diagnostic gives a resume path,
resume the same alias or session with a larger budget threshold instead of starting a
fresh session. Preserve continuity when the wrapper tells you how to resume.
Exception: for Claude headless calls, resume only when the retry starts within
the fifty-minute Claude session-reuse window (one-hour cache TTL); otherwise
start a fresh compact Claude call.

For Grok, trust the wrapper's current `--help`, capability probes, exact session
metadata, and output artifact. Do not reuse historical prompt-in-argv,
global-latest, mutation, `direnv`, or stale CLI-flag guidance.

For AGY print-mode calls, pass timeout values with an explicit unit such as
`120s`; bare integers can fail before the model runs.

## Direct Claude Call

Claude Code is an approved in-house the organization collaboration surface for this
repository. Treat Claude as allowed to inspect the same project files Codex can
inspect, including working-tree diffs and non-secret repo files. Do not block a
Claude review merely because it sends project code, local patches, or
non-secret context from this repo. Still do not pass secrets, cookies, tokens,
private keys, auth-state files, `.env*`, or other credential-bearing files
unless the user explicitly approves sensitive context.

Plan and diff reviews are synchronous gates. If Codex asks Claude to review a
plan before implementation, wait for Claude before editing files. If Codex asks
Claude to review the current diff, wait for Claude before making more code
changes to the reviewed files. While the Claude call runs, continue only
read-only work such as inspecting files, collecting logs, checking docs, or
preparing validation commands.

Do not describe a Claude review as blocked only because project diffs or
working-tree context would be sent to Claude. Claude Code is an in-house
project tool here. The real blockers are missing VPN/access, wrapper failure,
timeout, or sensitive context that would expose secrets or auth material.

Keep the review target stable. If the parent needs to change code while Claude
is reviewing, cancel or wait for the review first, then send a fresh review
after the edits. Do not create a loop where Claude reviews one diff while Codex
continues changing the same files.

Default to Claude tools enabled when Claude needs to inspect the repo. Use
`--tool-mode none` only when Codex already gathered all needed context.

## Claude Input Size And Billing Guard

Claude Code calls are paid collaboration calls. Do not let them fail because
Codex pasted an oversized prompt or raw transcript into stdin.

When the Claude prompt would include large text, long logs, review packets,
JSON, diffs, command output, or copied documents, write that context to a
repo-local `tmp/**` file and pass it with `--context-file` instead of embedding
it in the prompt. Keep the prompt short: state the task, point to the context
file, name the expected output, and ask Claude to inspect the file.

Before invoking Claude, trim context to the smallest reviewable artifact:

- prefer `git diff --stat`, selected file paths, and focused snippets over
  full repository dumps
- prefer generated summaries plus exact source files over pasted raw logs
- split unrelated large inputs into separate Claude calls only when each call
  has a distinct decision to make
- do not paste secrets, `.env*`, auth state, cookies, tokens, or private keys
  into prompt text or context files

If Claude fails after receiving a large input, treat it as a caller-side
workflow bug first. Inspect the wrapper diagnostic, reduce or file-attach the
context, and retry only when the next call has a materially smaller and clearer
input.

```bash
scripts/dev/agent-call-claude.sh \
  --acknowledge-post-request-budget \
  --profile review \
  --effort max \
  --title "review auth plan" \
  --prompt "Review this plan for correctness, regressions, and missing tests."
```

Pick the profile deliberately:

- `haiku`: cheap tiny checks and formatting/classification.
- `sonnet`: 1M-context scans and known-plan instruction following after Codex
  has already planned. Use `claude-sonnet-5-5` as the direct `--model` value.
  Sonnet 5.5 uses adaptive thinking by default, so pass `--effort` when the lane
  needs an explicit reasoning depth.
- `review`, `architect`, or `opus`: architecture, PR/code review, planning, and
  high-risk reasoning.
- `fable`: explicit "use Fable" requests or user-approved highest-cost
  long-horizon reasoning. It maps to `claude-fable-5-1`; keep prompts compact and
  use `--tool-mode none` when Codex has already gathered the evidence.

For difficult planning, architecture, reviewer, critic, or multi-harness lanes,
pass `--effort max` explicitly. Use lower effort only for cheap classification,
formatting, or known-plan follow-up work. The wrapper passes this to Claude
Code's `--effort <low|medium|high|xhigh|max>` flag and records the effort in
session metadata.

Trust terminal metadata, not Claude's natural-language self-description. The
wrapper records requested model and effort as intent; use
`modelUsage.*.canonicalModel` in the terminal JSON to prove which model the
provider used.

Do not use short timeouts for Opus review or architecture work. When
`--timeout-sec` is omitted, the wrapper uses profile-aware defaults: Haiku
`300s`, Sonnet/implement `900s`, and Opus/Fable/review/architect `1800s`. If a
Claude call times out anyway, resume the recorded session id or named alias
with a larger `--timeout-sec` only when the retry starts inside the
fifty-minute Claude session-reuse window (one-hour cache TTL).

The `review`, `architect`, `opus`, and `opus46` profiles default to an `$8.00`
Claude post-request budget threshold. The `fable` profile defaults to `$16.00` because
`claude-fable-5-1` is the highest Anthropic cost tier in this wrapper. If a
PR-bound review still reaches the threshold, resume the same alias/session with a
larger `--max-budget-usd` only when the retry starts inside the fifty-minute
Claude session-reuse window (one-hour cache TTL).

Use `--session-alias <name>` and `--resume alias:<name>` for related work in
the same Codex thread. Treat that alias as the task's Claude session registry:
the planning review and implementation review should reuse it only when the
previous headless Claude call for that alias was less than fifty minutes ago.
Do not use `latest`/`last` pointers for same-thread reuse because they are
checkout-global, not task-bound.
When the wrapper is called from Codex and no explicit alias or session is
provided, it uses `CODEX_THREAD_ID` to create or resume a
`codex-thread-<id>` alias automatically, so planning, review, and general
Claude follow-ups in the same Codex thread share one Claude session by default
only while the alias is inside the fifty-minute resume window.
When intentionally running multiple Claude calls in parallel for the same Codex
thread, pass distinct lanes, for example `--lane critic` and `--lane reviewer`.
Each lane becomes `codex-thread-<id>-<lane>` so parallel calls do not share or
overwrite one conversation.

For each user thread or task, choose a stable Claude session alias and reuse it
for plan critique and post-implementation review only when the calls are less
than fifty minutes apart. A good default is the branch slug or request slug, for
example `--session-alias demo-1234-auth-fix`, then
`--resume alias:demo-1234-auth-fix` for later Claude calls only inside that
fifty-minute window. After more than fifty minutes, start a fresh compact Claude
call even for the same thread. This is a cost-control rule: stale Claude API
prompt caches can force a full long-prefix rebuild.

Do not assume a tiny Claude prompt is cheap. Claude Code can write a large
project/session cache even for smoke tests. For availability checks, keep the
prompt tiny, use `--tool-mode none`, inspect returned usage metadata, and
prefer an existing alias/session only when the check belongs to an active
thread and the previous Claude call is still inside the fifty-minute
resume window. Recheck max-token assumptions for long prompts.

## Direct AGY Call

Use AGY as a read-only peer reviewer when the user explicitly asks for
Antigravity, when the AGY CLI or MCP setup should be exercised, or when a third
reviewer surface is useful before a risky change or push.

Before routing implementation, shell, browser, or autonomous work to AGY, read
`docs/agents/workhorse-harness-capability-ledger.md`. It preserves the tested
release history, current admission state, and exact retest boundary; this
reference continues to own invocation mechanics.

Select headed or headless AGY with the execution-surface matrix before running
any command. The role, evidence, and output requirements below apply to both
surfaces.

When diagnosing AGY project, plugin, agent, hook, or customization discovery,
restrict filesystem evidence to explicit repo plugin paths, task-owned
synthetic fixtures, CLI help/list/validate output, and allowlisted non-secret
configuration fields. Never recursively search AGY home or configuration
trees: exclude conversation brains, session or conversation metadata, caches,
logs, auth files, and state databases. If source attribution would require
private history, stop and mark that attribution `Pending Verification`.

### Headed AGY In The In-App Terminal

For an explicit headed request with no matching AGY process/session, use the
installed task-terminal contract to create a fresh isolated right-side terminal
and launch bare `agy`. AGY prompts still require exact conversation
acknowledgement below.

Before either headed mode, bind the AGY foreground PID/process
group/process-start identity, TTY, cwd, and process-owned log using read-only
evidence. When a conversation already exists, bind its exact conversation ID.
Identify the current log from the selected process's open-file evidence rather
than choosing the newest log by timestamp.

After prompt delivery through the installed task-terminal contract, require
AGY's exact input record in the process-bound log and correlate it with the
same conversation transcript under
`~/.gemini/antigravity-cli/brain/<conversation-id>/`. Only that event reaches
`PROMPT_ACKNOWLEDGED`. Read the response from the same conversation and verify
the intended AGY process/TTY remained active with no second AGY process.
Do not run the wrapper while headed AGY is selected. Missing acknowledgement
or process/session drift permits read-only diagnosis only. A headed blocker
does not authorize the headless wrapper.

If AGY creates standalone `antigravity-*` skill or agent files while asked to
update existing example-app guidance, treat those files as source material,
not the desired destination. Extract durable rules into the existing repo
skills, plugin agents, AGY plugin skill, or shared instructions, then remove the
parallel scratch guidance once the useful content has landed.

Ask AGY to follow the needed role directly. Do not ask AGY to spawn its own
reviewer or critic subagent for Codex planning or review gates; that path can
return async acknowledgements or permission-blocked status instead of findings.
For higher-fidelity critic or reviewer passes, attach the matching AGY plugin
agent instructions with
`--context-file .agents/plugins/example-app/agents/critic.md` or
`--context-file .agents/plugins/example-app/agents/reviewer.md`, and use
`--role none --model "Gemini 3.8 Flash (High)"` so Gemini follows the
AGY-adapted rubric itself.

For AGY/Gemini reviewer calls, include an explicit role-adherence reminder in
the prompt. The user has observed Gemini/AGY failing reviewer instructions by
prepending status prose, using local file links or absolute machine paths,
claiming tests or linters passed without visible evidence, emitting weak P3
filler, omitting base/head SHA, and marking `Pending Verification: N/A` when
central facts were not proven. Tell AGY to avoid those exact failures and to
follow the reviewer agent contract 100%. Also require packet `Pending
Verification` to summarize any later validation gaps or unrun
E2E/browser/API checks; it must not say `N/A` while the body lists gaps.
Require a final-output self-check: the first non-whitespace characters of the
captured response must be `Verdict:`, and all file references must be
repo-relative plain text or backticks, not Markdown links to local files. This
also applies to session hygiene and worktree references; use paths such as
`tmp/worktrees/<slug>`, not absolute machine paths. Tell AGY not to start,
include, or preserve background task, timer, scheduler, or asynchronous
tool-status updates in the captured reviewer artifact; if such output appears,
it must be removed before finalizing. Tell AGY not to install tools, bootstrap
dependencies, brute-force linter/test command variants, or repair local setup;
if a required tool or environment is missing, mark the check `Pending
Verification` and recommend the exact command plus working directory for the
parent or implementer.

Also tell AGY/Gemini that the captured reviewer output is an evaluation
artifact. The parent will judge it for constraint adherence, evidence
traceability, output-contract compliance, role fidelity, path hygiene, and
honest uncertainty handling before trusting the review. Constraint adherence,
evidence traceability, and output-contract compliance are non-negotiable.

For PR reviews, include PR ownership in the prompt. If the PR author is the
user or the parent says it is user-owned, a stale branch is not an automatic
AGY review `BLOCKED`; the expected workflow is to rebase the existing PR
worktree on `origin/main`, then review the rebased target. `BLOCKED` is for
someone else's stale PR, unsafe/conflicted rebase, or a freshness fact that
cannot be verified.

### Headless AGY Wrapper

Use the wrapper commands below only when the execution-surface matrix selects
headless AGY.

```bash
scripts/dev/agent-call-agy.sh \
  --role reviewer \
  --title "review current diff" \
  --model "Gemini 3.8 Flash (High)" \
  --prompt "Review the current diff for regressions, missing tests, and rollout risk."
```

Use `--role critic` for plan challenge before implementation:

```bash
scripts/dev/agent-call-agy.sh \
  --role critic \
  --title "critic auth plan" \
  --prompt "Challenge this implementation plan before Codex edits files."
```

The AGY wrapper runs through `direnv exec .` by default so env-backed MCP
servers receive the same repo environment as local development shells. Use
`--no-direnv` only for a deliberately environment-free smoke. The wrapper
captures AGY output under `tmp/codex-claude/calls/` and rejects secret-looking
context files unless `--allow-sensitive-context` is passed.

For AGY implementation advice, keep the repo contract above generic
Antigravity aesthetics. Follow `AGENTS.md`, `repo.md`, and existing frontend
patterns for UI work; do not accept broad "premium visual" rules, mandatory
planning artifact files, or whole-file rewrite habits when they conflict with
example-app's surgical edit and validation workflow.

Keep AGY's plugin MCP set small. The default example-app baseline is
`github`, `gopls`, `sentry-mcp`, `mcp-jira-prd`, and `mcp-confluence-prd`.
Keep optional servers, including `typescript-lsp`, out of the default set and
add them only for a task that needs them. Do not re-enable the broad MCP set by
default.
`google-cloud-logging-stg` is known to
hang/fail while VPN is connected and can make the whole headless AGY call time
out. Other disabled AGY MCPs are `context7_remote`, `parallel-search`,
`typescript-lsp`, `google-cloud-sql-stg-readonly`,
`dev-sql-readonly-local`,
`dev-redis-local`, `google-developer-knowledge`, `google-cloud-sql-stg`,
`google-cloud-error-reporting-stg`, and `google-cloud-monitoring-stg`.

When changing AGY MCPs, update `.agents/plugins/example-app/mcp_config.json`,
run `agy plugin validate .agents/plugins/example-app`, run
`agy plugin install .agents/plugins/example-app`, and also sync the same
config to `~/.gemini/config/plugins/example-app/mcp_config.json`. AGY keeps
plugin copies in both `~/.gemini/antigravity-cli/plugins/example-app/` and
`~/.gemini/config/plugins/example-app/`; stale MCP entries in either copy
can keep breaking headless calls after the repo config looks fixed. Add removed
MCPs back one at a time, then run
`agy --print-timeout 60s --print 'Reply exactly: agy-ok'` before keeping the
server enabled.

The wrapper requests `Gemini 3.8 Flash (High)` by default for `reviewer` and
`critic` calls. It requests `Gemini 3.8 Flash (Medium)` by default for
`--role none` general purpose calls. Use `--model <name>` or
`AGENT_CALL_AGY_MODEL=<name>` only as a scoped model override. The wrapper
applies the model through Antigravity CLI settings under a lock for the
duration of the call and then restores the previous settings.

For isolated AGY availability smokes, use a fresh alias and the low-reasoning
model name directly:

```bash
scripts/dev/agent-call-agy.sh \
  --role none \
  --model "Gemini 3.8 Flash (Low)" \
  --no-direnv \
  --timeout-sec 120 \
  --print-timeout 120s \
  --session-alias "agy-gemini-38-flash-low-smoke-<date>" \
  --title "agy-gemini-38-flash-low-smoke" \
  --prompt "Smoke test only. Do not inspect files. Reply exactly: agy-ok"
```

Do not rely on the wrapper's default Codex-thread alias for smoke tests. It can
resume old AGY context and return stale conversation work while still recording
the requested model. A clean smoke needs a unique alias or another explicit
fresh-session boundary, then the response should match the smoke prompt.

AGY CLI may require a non-sandbox shell because it writes its own log files and
starts a local language-server socket. If it fails with log-dir or socket
permission errors from a sandboxed Codex command, rerun the same wrapper from a
non-sandbox shell before treating AGY as unavailable.

If AGY exposes a stable conversation id during a task, record it in the handoff
with `scripts/dev/agent-collab-handoff.sh create --session "agy: <id-or-alias>"`.
If no AGY conversation id is available, mark it `Pending Verification` rather
than inventing one.

For related AGY follow-ups, resume the same conversation with
`scripts/dev/agent-call-agy.sh --conversation alias:<name>` or
`--conversation <id>` when the id is known. Prefer `--session-alias <name>` on
the first AGY call for a user thread, then resume with `--conversation
alias:<name>` for plan and review follow-ups. The wrapper records
`tmp/codex-claude/state/agy-latest-conversation-id` and
`tmp/codex-claude/state/agy-conversation-<alias>` from AGY's local brain
directory after successful calls. Use `--continue` only when the most recent
AGY conversation is definitely the right thread; prefer an explicit id or alias
in handoffs so later agents do not resume the wrong task.
When called from Codex without an explicit alias or conversation, the AGY
wrapper also uses `CODEX_THREAD_ID` to create or resume the same
`codex-thread-<id>` alias automatically.
When intentionally running multiple AGY calls in parallel for the same Codex
thread, pass distinct lanes, for example `--lane critic` and `--lane reviewer`.
Each lane becomes `codex-thread-<id>-<lane>` so parallel calls do not share or
overwrite one conversation.

## Direct Pi Candidate Call

When the user explicitly selects Pi, run `scripts/dev/agent-call-pi.sh` through
[the headless Pi candidate contract](../../../../docs/pi-harness-candidate.md).
Select an exact model from `scripts/dev/pi-harness-policy.json`; there is no
provider or model fallback. Reviewer and critic use read-only snapshots.
Contributor requires explicit write authority, one existing registered linked
worktree, and exact returned-patch paths. The parent owns patch application,
validation acceptance, admission, Git, and shared external actions.

Use this opt-in route only within the task's provider-call authorization. Its
request ceiling and post-response token threshold are not a hard monetary cap.
Never promote the existing tool-disabled Pi/Luna behavior-eval adapter into a
workhorse or run native Pi directly as a containment substitute. Follow the
wrapper's current `--help`; headed Pi and additional providers are unverified.

## Direct Muse Call

Use [muse-work-orchestration.md](muse-work-orchestration.md) after generic
delegation selects Muse or the user explicitly requests it. That specialist
adapter is canonical for Muse capability, role, model, execution surface,
session, worktree, wrapper arguments, run evidence, limitations, and foot
guns. This direct-collaboration reference owns only the surrounding peer-call
handoff and must not duplicate the Muse worker contract.
The user's task-scoped "use Muse" instruction selects this route without a
second transport question. The parent curates only needed non-secret context;
Muse has no ambient authority to inspect Codex task history, memory, auth, or
private files. Use the guarded headless wrapper for automation. Live Meta MSP
is fail-closed, and raw TUI is manual rescue only.

## Grok Collaboration

Use Grok CLI as an explicitly requested peer reviewer or critic when the user
asks for Grok, xAI, or a Grok model. Use the exact model id reported by
`grok models`; `grok-4.6` is the current Grok model. Do not add Grok to the
mandatory critic/reviewer gates by default; invoke it deliberately as an extra
coding-agent perspective.

Select headed or headless Grok with the collaborator execution-surface matrix
before launching or resuming it.

### Headed Grok In The In-App Terminal

For an explicit headed request with no matching Grok process/session, use the
installed task-terminal contract to create a fresh isolated right-side terminal
and launch bare `grok`. Do not put the research prompt in the launch command.
Select private tmux from that visible shell only when navigation, persistence,
or exact pane control is expected.

Bare Grok on this workstation may remain on a repainting splash until its
composer is activated. After the first post-launch read proves the same owned
terminal and alternate-screen identity, immediately deliver exactly one ASCII
space as a separate activation seed. Do not wait for the composer/footer or MCP
progress first: those are post-seed readiness evidence that the seed unlocks.
For the seed transaction:
use the exact task-terminal stage/submit transaction with
`append_newline=false`, `allow_output_change=true`, and require
`delivered=true`. Do not press Enter, count the seed as a model prompt, or send
it again. Require the same foreground process/start identity, TTY, cwd,
attachment, and alternate-screen identity plus public MCP initialization
progress after the seed.

Give Grok one bounded 120-second readiness window after that activation. Do not
apply AGY's line-oriented quiet-start rule and do not treat continuous
repainting as failure. Read and wait only through the exact owned Desktop
terminal ID. Classify the public lifecycle through these observable states:

1. `LAUNCHED`: bare `grok` was delivered and the exact owned terminal and
   alternate-screen identity are bound.
2. `ACTIVATED`: exactly one no-newline ASCII space was delivered. Never repeat
   it.
3. `INITIALIZING`: post-seed session or MCP progress advances on the same
   identity. Continue within the 120-second budget while it repaints.
4. `READY`: the same identity exposes a non-modal interactive affordance such
   as `Shift+Tab:mode` or `Ctrl+x:shortcuts`, the MCP counter reaches its maximum
   or clears after reaching it, and no starting, responding, error, login,
   trust, approval, or credential modal remains.
5. `WORKING`: the one model prompt has `delivered=true` and copied cursor or
   response progress follows.
6. `ANSWERED`: `Responding...` transitions to `Worked for ...` and the idle
   composer returns. Raw alternate-screen cursor deltas may fragment the reply.
7. `FLUSHED`: for an acceptance-only lifecycle, the already-required graceful
   exit returns to the same shell and exposes the clean reply plus any public
   resume ID.

A literal model/effort footer is corroborating readiness evidence, not a
universal prerequisite. After the one allowed deep copied-buffer read, its
absence is a public projection limitation when the complete `READY` composite
above is present; it is not a Grok product failure and does not block the one
prompt. Pre-seed composer visibility, elapsed time, cursor quiet, a process
existing, or private session storage is not readiness. A stable trust,
approval, login, credential, error, or still-starting surface stops the
transaction. If the complete public `READY` composite is absent at the
deadline, leave that exact terminal unprompted and report the bounded blocker.

Before either headed mode, bind the Grok foreground PID/process
group/process-start identity, TTY, cwd, attachment and alternate-screen state
through the exact task-terminal plane. Do not read local session storage,
private PTY bytes, `grok sessions`, a latest pointer, or the newest session
directory. After prompt delivery, require copied cursor progress and a bounded
response wait. Start with the ordinary copied tail, then use at most one
131,072-character read when the exact reply is absent. For an acceptance smoke
whose contract already requires graceful exit, the `ANSWERED` state on the
unchanged identity permits the one documented exit to flush the copied
transcript. A distinct reply visible only after return to the same shell proves
Grok answered and the lifecycle completed, but must be reported as post-exit
projection rather than pre-exit visibility. For real or user-owned work, or
without positive idle proof, preserve the session and mark reply projection
`Pending Verification`; never exit merely to obtain readback. Accept only the
one public resume ID printed by that TUI lifecycle.

Keep failure attribution precise. A stable Grok error, identity loss, failed
delivery, exhausted initialization budget, or missing completed response is a
product/lifecycle failure. A missing decorative footer or reply fragmented in
the public copied VT stream is a projection limitation. A missing or duplicate
activation seed, substituting AGY's quiet gate, prompting before `READY`,
skipping the required deep read, or using the wrong exit transaction is an
agent-procedure failure. Never call Grok unhealthy for an agent-procedure
failure.

After prompt delivery through the installed task-terminal contract, require an
exact prompt event in copied terminal output and read the response from that
terminal ID. Capture the public resume ID only through the selected graceful
exit path, and verify no second Grok process was started. Do not run the wrapper
while headed Grok is selected. Missing acknowledgement or process/session drift
permits read-only diagnosis only. Do not infer headless authority from a headed
blocker.

### Headless Grok Wrapper

Use `scripts/dev/agent-call-grok.sh` for explicitly selected brokered headless
council consultation or bounded contribution:

```bash
printf '%s\n' \
  'Review the current diff for regressions, missing tests, and rollout risk.' |
  scripts/dev/agent-call-grok.sh \
    --role reviewer \
    --model grok-4.6 \
    --session-alias "<task>-grok-review" \
    --title "review current diff"
```

The wrapper checks Grok capabilities, records the current version and per-run
digest, keeps the selected model, and transports prompt
content through a mode-0600 temporary file, and resumes only exact UUIDs with
matching wrapper-owned profile metadata. It never uses a global-latest lookup.
Every run uses positive mounts, private `/proc`, zero user plugins/hooks, a
sanitized Git view, exactly the selected Parallel Search and Context7
MCP catalogs, and private networking that reaches a bounded outer broker only
through one mounted Unix socket. The broker alone receives raw credentials.
Reviewer, critic, and none receive a read-only sanitized snapshot
of Git-visible source. Contribution requires
`--role contributor --allow-write --worktree-existing <path>`; its private
snapshot is writable, and only a bounded post-success patch is transferred to
the selected clean registered linked worktree. Normal Bash, built-in web,
subagents, and selected MCPs remain available.

Use `docs/agents/workhorse-harness-capability-ledger.md` for the exact evidence
and claim boundary. Git publication, validation verdicts, shared external
mutations, and work outside the assigned linked worktree remain parent-owned.
Do not silently fall back from a headed request or substitute another harness.

## Direct Copilot Call

Use Copilot CLI as an explicitly requested paid peer reviewer or critic. Do not
add Copilot to the mandatory critic/reviewer gates by default; invoke it when
the user asks for Copilot specifically or when a paid GitHub/Copilot
perspective is worth the extra cost.

```bash
scripts/dev/agent-call-copilot.sh \
  --role reviewer \
  --require-vpn \
  --title "review current diff" \
  --prompt "Review the current diff for regressions, missing tests, and rollout risk."
```

The wrapper uses Copilot non-interactive mode, records responses under
`tmp/codex-claude/calls/`, and records reusable session aliases under
`tmp/codex-claude/state/copilot-session-<alias>`. By default it grants
non-interactive tool approval but denies Copilot's `write` tool and all shell
commands, keeping review calls read-only. Pass `--allow-shell` or
`--allow-write` only when the parent intentionally delegates that capability.
Because the repo Copilot CLI provider uses the internal LiteLLM API key, pass
`--require-vpn` for real Copilot calls. A VPN preflight failure means the call
was not attempted and should be recorded as `Pending Verification`, not as a
Copilot review result.

For implementation-style Copilot tasks, choose permissions deliberately:

- Use the default wrapper mode for paid reviewer/critic calls: it passes
  Copilot `--allow-all-tools` for headless execution but denies `write` and
  `shell`.
- Use `--allow-shell`, `--allow-write`, `--allow-url`, or `--add-dir` only for
  the narrow capability the task needs.
- Use `--autopilot --max-autopilot-continues <n>` only for a clear, bounded
  implementation task where extra model turns are expected.
- Use `--allow-all` or `--yolo` only in an isolated or intentionally delegated
  worktree, because GitHub documents it as equivalent to all tools, all paths,
  and all URLs.
- Use `--effort <level>`, `--agent <name>`, `--available-tools`,
  `--excluded-tools`, `--disable-builtin-mcps`, `--additional-mcp-config`, or
  `--plugin-dir` when a task needs model routing, tool narrowing, MCP changes,
  or plugin loading for that one session.

For related Copilot follow-ups, prefer `--session-alias <name>` on the first
call and `--resume alias:<name>` later. When called from Codex without an
explicit alias or resume target, the wrapper uses `CODEX_THREAD_ID` to create
or resume `codex-thread-<id>` automatically. Do not use `latest` or `last` for
same-thread reuse; pass an explicit alias or raw session id/name.

When intentionally running multiple Copilot calls in parallel for the same Codex
thread, pass distinct lanes, for example `--lane critic` and `--lane reviewer`.
Each lane becomes `codex-thread-<id>-<lane>` so parallel calls do not share or
overwrite one session.

When another harness calls Codex through `scripts/dev/agent-call-codex.sh`,
use Codex session reuse for related follow-ups because token economics matter.
The wrapper records the latest Codex thread id under
`tmp/codex-claude/state/codex-latest-session-id`, supports
`--resume latest`, `--resume last`, raw thread ids, and
`--resume alias:<name>`, and records usage including cached input tokens in
the matching state JSON. Prefer `--session-alias <name>` plus
`--resume alias:<name>` for scripted or concurrent workflows; use a fresh
session for unrelated reviews to avoid context contamination. The wrapper
requires `--allow-unsafe-latest` before `--resume latest` or `--resume last`
because those pointers are global to the checkout, not scoped to one user
thread.

## Session And Handoff Discipline

Every collaborator call in a thread should have a reusable identity when the
tool supports it:

- Claude: prefer `--session-alias <request-or-branch-slug>` for task identity,
  but resume that alias only when the previous headless Claude call is less
  than fifty minutes old. After that, start a fresh compact Claude call.
- Codex CLI wrapper: prefer `--session-alias <request-or-branch-slug>` and
  resume that alias for related calls.
- Codex in-house subagents: record the spawned agent ids in the final/handoff
  when they materially reviewed a plan or diff.
- AGY headed: record the existing process/TTY identity and the conversation ID
  from the in-app session transcript or log.
- AGY headless: prefer `--session-alias <request-or-branch-slug>` on the first
  call and `--conversation alias:<name>` for follow-ups. Check
  `tmp/codex-claude/state/agy-latest-conversation-id` for the latest recorded
  conversation id only for handoff reporting, not for same-thread reuse.
- Grok headed: record the existing process/TTY identity and exposed Grok
  session or conversation identity from terminal/transcript evidence.
- Grok headless: create or resume only the exact UUID recorded by the wrapper.
  Prefer one task-scoped `--session-alias`; never use latest, last, or title
  matching.
- Copilot CLI: prefer `--session-alias <request-or-branch-slug>` on the first
  call and `--resume alias:<name>` for follow-ups. Check
  `tmp/codex-claude/state/copilot-latest-session-id` only for handoff
  reporting, not same-thread reuse.

When creating a handoff, include the active Claude session id, Codex thread id,
Codex subagent ids, AGY conversation id, Grok session id, and Copilot session id/name or
`Pending Verification`. If a collaborator ran on a lane, include the lane alias
explicitly; do not rely on a `latest` pointer for parallel calls because it only
records whichever lane finished last. Use:

```bash
scripts/dev/agent-collab-handoff.sh create \
  --session "claude: $(cat tmp/codex-claude/state/claude-latest-session-id)" \
  --session "codex: $(cat tmp/codex-claude/state/codex-latest-session-id)" \
  --session "agy: $(cat tmp/codex-claude/state/agy-latest-conversation-id)" \
  --session "grok: $(cat tmp/codex-claude/state/grok-latest-session-id)" \
  --session "muse: $(cat tmp/codex-claude/state/muse-latest-session-id)" \
  --session "copilot: $(cat tmp/codex-claude/state/copilot-latest-session-id)" \
  --session "agy-critic: codex-thread-<id>-critic" \
  --session "agy-reviewer: codex-thread-<id>-reviewer" \
  --session "copilot-reviewer: codex-thread-<id>-copilot-reviewer"
```

The handoff script also auto-includes the latest Claude, Codex, AGY, Grok,
Muse, and Copilot ids when the state files exist. Do not paste secrets, cookies, auth
state, tokens, or private keys into session notes.

## Explicit Context Files

When Codex generated files Claude needs, pass each one:

```bash
scripts/dev/agent-call-claude.sh \
  --acknowledge-post-request-budget \
  --context-file tmp/codex-claude/controller/<run>/artifacts.md \
  --context-file tmp/codex-claude/controller/<run>/codex-output.md \
  --prompt "Review these artifacts and return findings first."
```

Do not assume Claude can infer gitignored files or scratch paths. The wrapper
rejects context-file paths that look secret-bearing unless
`--allow-sensitive-context` is explicitly passed. Do not pass secrets, cookies,
tokens, private keys, or auth-state contents unless the user explicitly accepts
that exposure.

## Controller Workflow

Use the controller for dogfooding and plan/execute/review loops:

```bash
scripts/dev/agent-collab-controller.sh \
  --acknowledge-post-request-budget \
  --title "read-only smoke" \
  --claude-profile haiku \
  --review-claude-profile haiku \
  --task "Read-only smoke. Codex should return exactly bridge-ok."
```

Controller steps default to `1800s` so Opus planning/review has room for tool
use. Pass a smaller `--timeout-sec` only for intentionally fast smokes.
Claude plan/review steps default to `--claude-tool-mode none`; pass
`--claude-tool-mode auto` or `--claude-tool-mode all` only when Claude needs
repo tool access and the task explicitly accounts for that access.
Do not pass `--require-claude-vpn` for the default Claude Enterprise path. Keep
that option only for explicit VPN-backed Claude experiments.

Use `--allow-write` only when implementation is intentionally delegated to the
Codex subprocess. If a step times out or fails, resume with the printed
`--resume-run <run-dir>` command. Inspect `artifacts.md`, `plan.json`,
`codex-output.md`, `codex-events.jsonl`, `review-output.md`, and
`summary.json`.

## Closeout

- Treat Claude output as evidence or review input, not automatic truth.
- Verify cheap `Pending Verification` items locally before finalizing.
- Keep commits, pushes, PR comments, production writes, and destructive git
  actions parent-owned unless the user explicitly delegates them.
- For current completed and pending bridge work, see
  `docs/adrs/0031-claude-codex-peer-collaboration-bridge.md`.
