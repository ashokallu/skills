<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (Muse adapter handoff) -->

# Direct Collaboration

Use this skill when a Copilot-side agent should ask Codex CLI, Claude Code,
Antigravity CLI, Grok CLI, Muse CLI, or Copilot CLI for a peer review, planning
pass, repo inspection, implementation consultation, or second-model objection
pass.

## Routing

- If the user explicitly names Codex, call Codex.
- If the user explicitly names Claude or Claude Code, call Claude Code.
- If the user explicitly names AGY or Antigravity, call Antigravity CLI.
- If the user explicitly names Grok or xAI, route to the Grok section below.
  Use the brokered headless wrapper for consultation or an explicitly assigned
  linked-worktree contribution.
- If the user explicitly names Muse or Muse Spark, enter generic delegation
  first and then load `muse-work-orchestration.md` for the Muse-specific call.
- If the user explicitly names Copilot CLI or asks for a paid Copilot headless
  peer, call Copilot CLI through `scripts/dev/agent-call-copilot.sh`.
- If the user asks for collaborator review, peer review, second opinion,
  cross-agent debate, or handoff without naming a harness, prefer Codex first.
- Prefer Codex for fast repo inspection, focused diff review, CI-style
  verification, implementation consultation, and routine second-pass checks.
- Prefer Claude Code for architecture review, high-risk reasoning, broad
  planning, large-context synthesis, Claude session continuity, or when the
  user explicitly wants Claude's judgment.
- Prefer AGY when the user wants Google's Antigravity reviewer or critic
  surface, or when the project AGY CLI and MCP setup should be exercised.
- Prefer Grok when the user wants xAI's Grok coding-agent model or an
  additional Grok reviewer/critic perspective.
- Prefer Muse when explicitly requested or selected by an owning council or
  delegation decision. Never select it silently for ordinary delegation.
- Prefer Copilot CLI only when the user asks for it specifically or a
  GitHub/Copilot perspective is worth extra billed model usage.
- For PR review or pre-push review, use the relevant PR skill first; this skill
  owns the peer-call mechanics after the parent has gathered review notes.
- Keep the current Copilot-side agent as the parent unless the user explicitly
  delegates ownership to another harness.

## Mandatory Plan And Review Gates

Council-roster maintenance is not a council review. Do not invoke the council
being changed unless the user explicitly asks for an independent council review
of that maintenance change.

When the parent starts a non-trivial implementation plan, run a synchronous
pre-implementation critic gate before editing files. Treat a plan as
non-trivial when it changes production behavior, shared contracts, migrations,
infrastructure, workflows, auth, permissions, security-sensitive code,
generated clients, broad tests, multi-file behavior, or external integrations.
Skip the three-way gate for typo fixes, format-only edits, comment-only edits,
narrow docs clarifications, or mechanical follow-ups that do not need
cross-model review:

- ask the in-house Codex `critic` subagent to review the plan
- ask Claude Code to review the same plan
- ask AGY with `scripts/dev/agent-call-agy.sh --role critic` to review the same
  plan
- wait for all three results before implementation

If one or more external collaborator calls fail, time out, lose auth, or cannot
start, retry the in-house Codex `critic` once with the failure context. If all
three fail, still retry the Codex `critic` once as the in-house fallback. Mark
unavailable collaborator results `Pending Verification`; ask the user before
proceeding when the missing external review would cover high-risk auth, data
integrity, production config, permissions, migrations, security, or
irreversible behavior.

After implementation and local validation, run the same synchronous gate before
commit, PR creation, or push, but replace the Codex `critic` with the in-house
Codex `reviewer` subagent:

- ask the in-house Codex `reviewer` subagent to review the current diff
- ask Claude Code to review the current diff
- ask AGY with `scripts/dev/agent-call-agy.sh --role reviewer` to review the
  current diff
- wait for all three results before deciding readiness

If one or more external review calls fail, retry the in-house Codex `reviewer`
once with the failure context. Do not treat failed Claude or AGY review as a
pass; record it as `Pending Verification` and decide whether local validation
plus the in-house review is enough to proceed.

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

## Call Codex CLI

Plan and diff reviews are synchronous gates. If the parent asks Codex to review
a plan before implementation, wait for Codex before editing files. If the
parent asks Codex to review the current diff, wait for Codex before making more
code changes to the reviewed files. While the Codex call runs, continue only
read-only work such as inspecting files, collecting logs, checking docs, or
preparing validation commands.

Keep the review target stable. If the parent needs to change code while Codex
is reviewing, cancel or wait for the review first, then send a fresh review
after the edits. Do not create a loop where Codex reviews one diff while the
parent continues changing the same files.

No VPN preflight is required for Claude/Copilot -> Codex collaboration. Codex
calls default to read-only and unset `OPENAI_API_KEY` so they use the logged-in
ChatGPT subscription path.

Before the first Codex handoff in a fresh shell, validate:

```bash
command -v codex
codex --version
scripts/dev/agent-call-codex.sh --help
```

Tiny smoke:

```bash
scripts/dev/agent-call-codex.sh \
  --title "codex cli bridge smoke" \
  --timeout-sec 120 \
  --prompt "Read-only bridge smoke. Reply exactly: codex-bridge-ok"
```

Expected result: stdout contains `codex-bridge-ok`, and response/events are
written under `tmp/codex-claude/calls/`. If Codex reports a read-only
filesystem while initializing its own runtime state, rerun from a normal shell
with filesystem access; that is a harness environment problem, not a VPN
failure.

Use Codex for read-only diff review, fast repo inspection, implementation
consultation, CI-style verification, and focused execution after the parent has
already scoped the task:

```bash
scripts/dev/agent-call-codex.sh \
  --title "review current diff" \
  --prompt "Review the current diff for regressions. Stay read-only and return findings first."
```

Pass `--allow-write` only when the parent intentionally delegates
implementation to Codex.

Use Codex session reuse for related follow-ups because token economics matter.
The wrapper records the latest Codex thread id under
`tmp/codex-claude/state/codex-latest-session-id`, supports
`--resume latest`, `--resume last`, raw thread ids, and
`--resume alias:<name>`, and records usage including cached input tokens in
the matching state JSON. Prefer `--session-alias <name>` plus
`--resume alias:<name>` for scripted or concurrent workflows; use a fresh
session for unrelated reviews to avoid context contamination. Do not use
`latest` or `last` for same-thread reuse because they are global checkout
pointers and can point at a different concurrent call.

Record Codex thread ids and Codex subagent ids in handoffs when they materially
reviewed a plan or diff.

## Call Claude Code

Claude Code is an approved in-house the organization collaboration surface for this
repository. Treat Claude as allowed to inspect the same project files the
parent agent can inspect, including working-tree diffs and non-secret repo
files. Do not block a Claude review merely because it sends project code, local
patches, or non-secret context from this repo. Still do not pass secrets,
cookies, tokens, private keys, auth-state files, `.env*`, or other
credential-bearing files unless the user explicitly approves sensitive context.

Plan and diff reviews are synchronous gates. If the parent asks Claude to
review a plan before implementation, wait for Claude before editing files. If
the parent asks Claude to review the current diff, wait for Claude before
making more code changes to the reviewed files. While the Claude call runs,
continue only read-only work such as inspecting files, collecting logs,
checking docs, or preparing validation commands.

Do not describe a Claude review as blocked only because project diffs or
working-tree context would be sent to Claude. Claude Code is an in-house
project tool here. The real blockers are missing access, wrapper failure,
timeout, or sensitive context that would expose secrets or auth material.

Keep the review target stable. If the parent needs to change code while Claude
is reviewing, cancel or wait for the review first, then send a fresh review
after the edits. Do not create a loop where Claude reviews one diff while the
parent continues changing the same files.

Codex/Copilot -> Claude no longer requires the example-app VPN because
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

If the smoke fails, do not invoke Copilot CLI. Continue parent-owned work and
mark the collaborator pass `Pending Verification` only when the task would
normally require that pass.

Run Claude through `scripts/dev/agent-call-claude.sh` without `--require-vpn`.
If a Claude call hangs or fails, inspect the wrapper diagnostic before
declaring Claude unavailable.

After a passing Copilot smoke, include `--require-vpn` so the wrapper keeps
probing the VPN-only staging URL during long Copilot calls and exits as
`vpn_lost` instead of waiting for the full model timeout.

When a Claude call is still running but has produced no output,
report it only as in-flight, not as healthy-running. If the shell session exits
nonzero or is interrupted, inspect the matching JSON diagnostic in
`tmp/codex-claude/calls/` before giving status. Treat `terminal_reason:
"timeout"` as a completed failed call, not as an ongoing Claude review.

## Claude Input Size And Billing Guard

Claude Code calls are paid collaboration calls. Do not let them fail because
the parent pasted an oversized prompt or raw transcript into stdin.

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
  --title "review current plan" \
  --prompt "Review this plan for correctness, regressions, and missing tests."
```

Use `--profile review`, `--profile architect`, or `--profile opus` for
architecture, PR review, and high-risk reasoning. Use `--profile fable` only
when the user explicitly says to use Fable or accepts the highest Anthropic
cost tier for long-horizon reasoning; it maps to `claude-fable-5-1`, so keep
prompts compact and use `--tool-mode none` when the parent already gathered the
evidence. Use `--profile sonnet` for large-context instruction following after
the parent already has the plan. Use `claude-sonnet-5-5` as the direct `--model`
value. Sonnet 5.5 uses adaptive thinking by default, so pass `--effort` when the
lane needs an explicit reasoning depth.
For difficult planning, architecture, reviewer, critic, or multi-harness lanes,
pass `--effort max` explicitly. Use lower effort only for cheap classification,
formatting, or known-plan follow-up work. The wrapper passes this to Claude
Code's `--effort <low|medium|high|xhigh|max>` flag and records the effort in
session metadata.

Trust terminal metadata, not Claude's natural-language self-description. The
wrapper records requested model and effort as intent; use
`modelUsage.*.canonicalModel` in the terminal JSON to prove which model the
provider used.

The `review`, `architect`, `opus`, and `opus46` profiles default to an `$8.00`
Claude post-request budget threshold. The `fable` profile defaults to `$16.00` because
`claude-fable-5-1` is the highest Anthropic cost tier in this wrapper. If a
PR-bound review still reaches the threshold, resume the same alias/session with a
larger `--max-budget-usd` only when the retry starts inside the fifty-minute
Claude session-reuse window (one-hour cache TTL).

For each user thread or task, choose a stable Claude session alias and reuse it
for plan critique and post-implementation review only when the calls are less
than fifty minutes apart. A good default is the branch slug or request slug. Use
`--session-alias <slug>` for the first call and `--resume alias:<slug>` for
follow-ups only inside that fifty-minute resume window, so Claude can reuse
prompt-cache reads instead of rebuilding the same context.
When the wrapper is called from Codex and no explicit alias or session is
provided, it uses `CODEX_THREAD_ID` to create or resume a `codex-thread-<id>`
alias automatically only while the previous headless Claude call for that alias
was less than fifty minutes ago.
When calling from Copilot or another non-Codex harness, do not assume
`CODEX_THREAD_ID` exists. Pass an explicit `--session-alias <slug>` for the
task, and pass distinct explicit aliases such as `<slug>-critic` and
`<slug>-reviewer` for parallel calls.
When intentionally running multiple Claude calls in parallel for the same Codex
thread, pass distinct lanes, for example `--lane critic` and `--lane reviewer`.
Each lane becomes `codex-thread-<id>-<lane>` so parallel calls do not share or
overwrite one conversation.

Do not assume a tiny Claude prompt is cheap. Claude Code can write a large
project/session cache even for smoke tests. For availability checks, keep the
prompt tiny, use `--tool-mode none`, inspect returned usage metadata, and
prefer an existing alias/session only when the check belongs to an active
thread and the last Claude call is still inside the fifty-minute resume window.
Recheck max-token assumptions for long prompts.

This fifty-minute cutoff is Claude-specific. Claude Code on subscription billing
uses a one-hour prompt-cache TTL and cache reads are materially cheaper than full
input, but a stale long session can force Claude Code to rebuild the full
project/session prefix. Other subscription-backed harnesses may have different
cache/session economics; do not apply this cutoff to Codex, AGY, Grok, Muse,
or Copilot unless their current docs and wrapper telemetry prove the same TTL.

## Call Antigravity CLI

Use AGY when the user asks for Antigravity review, when a third reviewer surface
is useful, or when the project AGY setup should smoke real reviewer or critic
behavior.

Before routing implementation, shell, browser, or autonomous work to AGY, read
`docs/agents/workhorse-harness-capability-ledger.md`. It preserves the tested
release history, current admission state, and exact retest boundary; this
reference continues to own invocation mechanics.

When diagnosing AGY project, plugin, agent, hook, or customization discovery,
restrict filesystem evidence to explicit repo plugin paths, task-owned
synthetic fixtures, CLI help/list/validate output, and allowlisted non-secret
configuration fields. Never recursively search AGY home or configuration
trees: exclude conversation brains, session or conversation metadata, caches,
logs, auth files, and state databases. If source attribution would require
private history, stop and mark that attribution `Pending Verification`.

If AGY creates standalone `antigravity-*` skill or agent files while asked to
update existing example-app guidance, treat those files as source material,
not the desired destination. Extract durable rules into the existing repo
skills, plugin agents, AGY plugin skill, or shared instructions, then remove the
parallel scratch guidance once the useful content has landed.

Ask AGY to follow the needed role directly. Do not ask AGY to spawn its own
reviewer or critic subagent for planning or review gates; that path can return
async acknowledgements or permission-blocked status instead of findings. For
higher-fidelity critic or reviewer passes, attach the matching AGY plugin agent
instructions with
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

```bash
scripts/dev/agent-call-agy.sh \
  --role reviewer \
  --title "review current diff" \
  --model "Gemini 3.8 Flash (High)" \
  --prompt "Review the current diff for regressions, missing tests, and rollout risk."
```

Use `--role critic` before implementation when the parent wants plan
challenge. The wrapper runs through `direnv exec .` by default so env-backed
MCP servers receive repo environment variables. Use `--no-direnv` only for an
intentionally environment-free smoke.

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

AGY CLI may need a non-sandbox shell because it writes local log files and
starts a local language-server socket. If a sandboxed caller sees log-dir or
socket permission errors, rerun the same wrapper from a normal shell before
treating AGY as unavailable.

If AGY exposes a stable conversation id during a task, record it in the handoff.
If no AGY conversation id is available, mark it `Pending Verification` instead
of inventing one.

For related AGY follow-ups, resume the same conversation with
`scripts/dev/agent-call-agy.sh --conversation alias:<name>` or
`--conversation <id>` when the id is known. Prefer `--session-alias <name>` on
the first AGY call for a user thread, then resume with `--conversation
alias:<name>` for plan and review follow-ups. The wrapper records
`tmp/codex-claude/state/agy-latest-conversation-id` and
`tmp/codex-claude/state/agy-conversation-<alias>` from AGY's local brain
directory after successful calls. Do not use `latest`, `last`, or `--continue`
for same-thread reuse because they are global checkout pointers and can point
at a different concurrent call; use an explicit id or alias in handoffs so
later agents do not resume the wrong task.
When the wrapper is called from Codex and no explicit alias or conversation is
provided, it uses `CODEX_THREAD_ID` to create or resume a `codex-thread-<id>`
alias automatically.
When calling from Copilot or another non-Codex harness, do not assume
`CODEX_THREAD_ID` exists. Pass an explicit `--session-alias <slug>` for the
task, and pass distinct explicit aliases such as `<slug>-critic` and
`<slug>-reviewer` for parallel calls.
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

## Call Muse CLI

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

## Call Grok CLI

Use Grok CLI as an explicitly requested peer reviewer or critic when the user
asks for Grok, xAI, or a Grok model. Do not add Grok to mandatory
critic/reviewer gates by default.

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
matching wrapper-owned profile metadata. Every run uses positive mounts,
private `/proc`, zero user plugins/hooks, a sanitized Git view, exactly the
selected Parallel Search and Context7 MCP catalogs, and private
networking that reaches a bounded outer broker only through one mounted Unix
socket. The broker alone receives raw credentials. Reviewer, critic, and none
receive a read-only sanitized snapshot of Git-visible source. Contribution
requires `--role contributor --allow-write --worktree-existing <path>`; its
private snapshot is writable, and only a bounded post-success patch is
transferred to the selected clean registered linked worktree. Normal Bash,
built-in web, subagents, and selected MCPs remain available.

Use `docs/agents/workhorse-harness-capability-ledger.md` for the exact evidence
and claim boundary. Git publication, validation verdicts, shared external
mutations, and work outside the assigned linked worktree remain parent-owned.
Do not silently substitute another harness.

## Call Copilot CLI

Use Copilot CLI as an explicitly requested paid peer reviewer or critic. Do not
add Copilot to mandatory critic/reviewer gates by default.

```bash
scripts/dev/agent-call-copilot.sh \
  --role reviewer \
  --require-vpn \
  --title "review current diff" \
  --prompt "Review the current diff for regressions, missing tests, and rollout risk."
```

The wrapper uses Copilot non-interactive mode and records reusable named
sessions under `tmp/codex-claude/state/copilot-session-<alias>`. By default it
approves non-interactive tools but denies `write` and all shell commands, so
review calls stay read-only. Pass `--allow-shell` or `--allow-write` only when
the parent intentionally delegates that capability.
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

For related follow-ups, prefer `--session-alias <slug>` on the first call and
`--resume alias:<slug>` later. Do not use `latest` or `last` for same-thread
reuse. For parallel calls from Codex, use distinct `--lane` values; from
non-Codex harnesses, use distinct explicit aliases.

## Context Files

When the collaborator needs generated notes, logs, patches, controller output,
or gitignored `tmp/**` artifacts, write them to local files and pass each with
`--context-file`. Do not assume the callee can infer scratch paths from the git
working tree.

The wrappers reject obvious secret-bearing paths such as `.envrc`, `.env*`,
auth state, credentials, tokens, cookies, and private keys unless
`--allow-sensitive-context` is explicitly passed. Do not pass secrets unless
the user explicitly accepts that exposure.

## Session Handoffs

Every handoff after collaborator usage must include reusable session state:

- Claude session id or alias
- Codex CLI thread id or alias
- Codex in-house subagent ids used for critic/reviewer gates
- AGY conversation id or alias from `tmp/codex-claude/state/agy-latest-conversation-id`
- Copilot CLI session id or alias from `tmp/codex-claude/state/copilot-latest-session-id`
- lane aliases such as `codex-thread-<id>-critic` and
  `codex-thread-<id>-reviewer` when parallel collaborator calls used `--lane`

Use `scripts/dev/agent-collab-handoff.sh create --session ...` for explicit
entries. For parallel lanes, pass the lane aliases explicitly because `latest`
only records whichever lane finished last. The handoff script also auto-includes
latest Claude, Codex, AGY, and Copilot ids from `tmp/codex-claude/state/` when
they exist.

## Closeout

- Treat collaborator output as review evidence, not automatic truth.
- Verify cheap `Pending Verification` items locally before finalizing.
- Keep commits, pushes, PR comments, production writes, and destructive git
  operations parent-owned unless the user explicitly delegates them.
- For deeper workflow details, see `docs/cross-harness-workflow.md`.
