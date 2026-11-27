<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (Muse adapter handoff) -->

# Direct Collaboration

Use this skill when Claude Code should collaborate with Codex CLI, Antigravity
CLI, Grok CLI, Muse CLI, or Copilot CLI instead of staying inside the Claude
harness. Keep Claude as the parent for the current turn unless the user
explicitly hands ownership to another harness.

## Use When

- The user asks Claude and Codex to collaborate, dogfood the bridge, debate, or
  review each other's work.
- Claude needs to ask Codex to review Claude's plan, inspect the repo, execute
  scoped work, or validate implementation.
- Claude wants Codex for fast repo inspection, focused implementation, test
  repair, final diff review, or CI-style verification.
- Claude needs to ask Grok CLI for an explicitly requested Grok/xAI
  reviewer, critic, or coding-agent perspective.
- Claude needs to ask Muse CLI for an explicitly requested Muse Spark task.
  Enter generic delegation first, then use `muse-work-orchestration.md`; this
  reference owns only the surrounding direct-collaboration handoff.
- A task should run through Claude plan -> Codex execute -> Claude review.
- Codex needs generated local artifacts, logs, patches, JSONL events, or
  `tmp/**` files that are not obvious from the git working tree.
- The task asks about Claude billing, model usage, session reuse, controller
  runs, or collaboration artifacts.

Do not use this skill for ordinary Claude subagent routing; use the
`work-orchestration` delegation and handoffs lanes for that.

## Mandatory Plan And Review Gates

Council-roster maintenance is not a council review. Do not invoke the council
being changed unless the user explicitly asks for an independent council review
of that maintenance change.

When Claude starts a non-trivial implementation plan, run a synchronous
pre-implementation critic gate before editing files. Treat a plan as
non-trivial when it changes production behavior, shared contracts, migrations,
infrastructure, workflows, auth, permissions, security-sensitive code,
generated clients, broad tests, multi-file behavior, or external integrations.
Skip the gate for typo fixes, format-only edits, comment-only edits, narrow
docs clarifications, or mechanical follow-ups that do not need cross-model
review.

For the pre-implementation gate, ask Codex CLI and any explicitly requested
collaborator such as AGY or Grok to review the same plan, then wait for the
results before implementation. If a collaborator call fails, times out, loses
auth, or cannot start, do not treat it as a pass. Record it as `Pending
Verification`; ask the user before proceeding when the missing review would
cover high-risk auth, data integrity, production config, permissions,
migrations, security, or irreversible behavior.

After implementation and local validation, run the same synchronous gate before
commit, PR creation, or push, but ask for a current-diff review instead of plan
critique. Keep both gates read-only. While a plan or diff is under review, do
not edit the review target; continue only read-only context gathering, log
inspection, or validation preparation.

## Required PR Review Collaboration Attempt

When the user shares a GitHub PR link for Claude review and code changes may be
made, Claude should first gather its review findings or review notes, then try
to share those notes with Codex before editing files. This is a required
attempt when this lane applies, but collaborator availability is not a blocker
by itself. If the collaborator cannot run, record the review as
`Pending Verification` and continue only when the remaining risk is acceptable.

No VPN preflight is required for Claude -> Codex collaboration. Codex does not
need VPN access for this repository's collaboration path. Use
`scripts/dev/agent-call-codex.sh` directly unless another task-specific blocker
exists. If Codex is unavailable or times out, mark the collaborator review as
`Pending Verification`, explain why, and continue with Claude-owned review,
implementation, and validation.

## Choose The Mode

- **Direct Codex call:** use when Claude needs a synchronous Codex opinion or
  read-only repo check. Run `scripts/dev/agent-call-codex.sh`.
- **Direct Grok call:** use the brokered headless wrapper for explicitly
  selected consultation or an explicitly assigned linked-worktree
  contribution; do not silently substitute another harness.
- **Muse collaboration:** enter generic delegation, then load
  `muse-work-orchestration.md` for capability, role, surface, session,
  worktree, wrapper, and evidence decisions.
- **Async handoff:** use when Codex or a later session should continue from a
  compact artifact. Run `scripts/dev/agent-collab-handoff.sh create`.
- **Controller:** use when Claude should plan, Codex should execute, and Claude
  should review. Run `scripts/dev/agent-collab-controller.sh`.
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

## PR-Bound Pre-Push Collaboration

When Claude Code is preparing to push commits to a PR-bound branch, it should
attempt a Codex review first only when the intended change is substantially
impactful. This call path does not require VPN (see below). PR-bound means an
open GitHub PR already exists for the branch, or Claude Code is preparing to
push the branch and open a new PR. This is a selective quality accelerator, not
a requirement for trivial pushes.

Substantial changes include production behavior, shared contracts, migrations,
infrastructure, workflows, auth, permissions, security-sensitive code,
generated clients, broad test rewrites, or large multi-file diffs. Trivial
typos, format-only edits, comment-only edits, narrow docs clarifications, and
already-reviewed mechanical follow-ups can skip the extra pass.

Claude -> Codex does not require the VPN smoke. Use the Direct Codex Call
section below for the synchronous review mechanics, target-stability rule, and
fallback handling. If Codex is unavailable, inspect the wrapper diagnostic
before deciding whether to retry, continue with Claude-owned review, or mark
the Codex review as `Pending Verification`.

## Direct Codex Call

Plan and diff reviews are synchronous gates. If Claude asks Codex to review a
plan before implementation, wait for Codex before editing files. If Claude asks
Codex to review the current diff, wait for Codex before making more code
changes to the reviewed files. While the Codex call runs, continue only
read-only work such as inspecting files, collecting logs, checking docs, or
preparing validation commands.

Keep the review target stable. If Claude needs to change code while Codex is
reviewing, cancel or wait for the review first, then send a fresh review after
the edits. Do not create a loop where Codex reviews one diff while Claude
continues changing the same files.

Codex calls default to read-only and unset `OPENAI_API_KEY` so they use the
logged-in ChatGPT subscription path.

Before a first handoff in a fresh shell, validate the local Codex surface:

```bash
command -v codex
codex --version
scripts/dev/agent-call-codex.sh --help
```

Then run a tiny read-only smoke:

```bash
scripts/dev/agent-call-codex.sh \
  --title "codex cli bridge smoke" \
  --timeout-sec 120 \
  --prompt "Read-only bridge smoke. Reply exactly: codex-bridge-ok"
```

Expected result: stdout contains `codex-bridge-ok`; the final response and
event log are written under `tmp/codex-claude/calls/`. If the wrapper reports
`codex CLI not found on PATH`, fix the shell environment before retrying. If
Codex reports a read-only filesystem while initializing its own runtime state,
rerun from a normal Claude shell with filesystem access; that is a harness
environment problem, not a VPN problem and not a collaboration-script failure.
No VPN preflight is required for Claude -> Codex.

```bash
scripts/dev/agent-call-codex.sh \
  --title "review current diff" \
  --prompt "Review the current diff for regressions. Stay read-only and return findings first."
```

Use `--allow-write` only when Claude intentionally delegates implementation to
Codex. Keep one parent harness responsible for final validation and publication.
Codex peer calls keep a shorter default timeout than Opus Claude calls because
they run read-only `codex exec`; pass `--timeout-sec` explicitly when Claude is
asking Codex for a broad repo review or long-running validation.

Use Codex session reuse for related follow-ups because token economics matter.
The wrapper records the latest Codex thread id under
`tmp/codex-claude/state/codex-latest-session-id`, supports
`--resume latest`, `--resume last`, raw thread ids, and
`--resume alias:<name>`, and records usage including cached input tokens in
the matching state JSON. Prefer `--session-alias <name>` plus
`--resume alias:<name>` for scripted or concurrent workflows; use a fresh
session for unrelated reviews to avoid context contamination.

When asking Codex to review PR notes, plans, logs, generated files, or
gitignored `tmp/**` artifacts, write the notes to a local file and pass them
with `--context-file`. The wrapper appends those files to the prompt and
rejects obvious secret-bearing paths such as `.envrc`, `.env*`, auth state,
credentials, tokens, cookies, and private keys unless
`--allow-sensitive-context` is explicitly passed.

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

## Direct Grok Call

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

## Explicit Context Files

When Claude generated files Codex needs, pass each one:

```bash
scripts/dev/agent-call-codex.sh \
  --context-file tmp/codex-claude/handoffs/<handoff>.md \
  --prompt "Use this handoff as context and inspect the repo read-only."
```

Do not assume Codex can infer gitignored files or scratch paths. The wrapper
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

Controller steps default to `1800s` so Opus and Fable planning/review have room
for tool use. Use `--claude-profile fable` or `--review-claude-profile fable`
only when the user explicitly says to use Fable or accepts the highest
Anthropic cost tier for long-horizon reasoning. Pass a smaller `--timeout-sec`
only for intentionally fast smokes. If a step times out or fails, resume with
the printed `--resume-run <run-dir>` command instead of restarting from scratch.
Claude plan/review steps default to `--claude-tool-mode none`; pass
`--claude-tool-mode auto` or `--claude-tool-mode all` only when Claude needs
repo tool access and the task explicitly accounts for that access.

Use `--allow-write` only when implementation is intentionally delegated to the
Codex subprocess. Inspect `artifacts.md`, `plan.json`,
`codex-output.md`, `codex-events.jsonl`, `review-output.md`, and
`summary.json`.

## Closeout

- Treat Codex output as evidence or review input, not automatic truth.
- Verify cheap `Pending Verification` items locally before finalizing.
- Keep commits, pushes, PR comments, production writes, and destructive git
  actions parent-owned unless the user explicitly delegates them.
- For current completed and pending bridge work, see
  `docs/adrs/0031-claude-codex-peer-collaboration-bridge.md`.
