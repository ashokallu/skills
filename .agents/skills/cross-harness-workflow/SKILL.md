---
name: cross-harness-workflow
description: Use when example-app work explicitly needs two or more harnesses, cross-harness review, council planning, direct Claude Code/Codex/Grok/Muse/Pi/Copilot calls, explicit Pi council or bounded contributor/workhorse requests, tmux-backed persistent harness sessions, wrapper/session routing, bridge audits, PR-bound pre-push collaborator review, fanout plans, plan stealing, artifact implementation review, recursive final-package evaluation, or multi-harness consolidation.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (explicit Muse offload adapter routing) -->

# Cross-Harness Workflow

Use this skill when example-app work should move across runtime harnesses
instead of staying inside the current parent agent. This is the umbrella for
direct peer calls, critic/reviewer gates, bridge audits, reusable sessions,
multi-harness councils, plan stealing, artifact contracts, and final
consolidation.

Cross-harness calls use the providers listed below. Use Antigravity in its own
client and bring back a user-provided result for comparison.
[Google Antigravity FAQ](https://antigravity.google/docs/faq)

## Picker Contract

Pick this skill when the user explicitly names multiple harnesses or asks for
cross-harness collaboration, debate, critique, review, council planning,
session reuse, wrapper diagnostics, bridge smoke tests, fanout plans,
cross-harness stealing, PR-bound pre-push collaborator review, artifact
implementation review, recursive final-package evaluation, or artifact
aggregation.

Also pick this skill when the user explicitly says to use Muse, even when Muse
is the only external harness named. Enter the `work-orchestration`
delegation lane first for decomposition and the Child Contract, then load
`muse-work-orchestration.md` for the Muse-specific capability and execution
decision. Do not silently select Muse for ordinary delegation.
An explicit task-scoped Muse request is enough to invoke the guarded adapter
and pass the smallest eligible non-secret context; do not ask another
confirmation solely for wrapper ceremony. Muse never browses Codex history,
memory, auth, or private files on its own.

When the user says "council", "council opinion", "council review", or "take it
to council", route to cross-harness council planning. In this repo, council
means the external harness roster: Grok, Muse with
`muse-spark-1.3-contributor`, Claude Code with Opus, and Codex with high
reasoning. Do not satisfy a council
request by spawning native runtime `reviewer` or `critic` subagents. Native
subagents are separate reviewer/critic gates and only apply when the user asks
for those gates or a workflow explicitly requires them.

Do not pick this skill only because ordinary work might benefit from a second
opinion. Use `work-orchestration` for normal delegation and push
readiness. Use this skill when the collaborator surface itself is part of the
work.

When Pi is explicitly requested for council or bounded contribution, use the
[direct Pi candidate call](references/direct-collaboration.md#direct-pi-candidate-call).
Pi is not part of the default council roster and has no autonomous admission.

## After Invocation Trigger Detail

This skill routes these work shapes after it is invoked:

- ask Claude Code, Codex, Grok, Muse, or Copilot CLI for a
  direct peer review, implementation-plan objection pass, failure-scenario
  review, critic pass, second opinion, or wrapper smoke
- run a PR-bound pre-push collaborator review for a substantial diff, workflow
  behavior change, shared test-helper change, or open-PR branch
- dogfood the plan -> execute -> review controller
- create separate worktrees for Claude, Codex high, Grok, or Muse to write
  independent plans
- run cross-harness peer review, GOOD/BAD/UGLY review folders, plan stealing,
  best-idea stealing into each harness's own plan, rating-table aggregation,
  reused-session final report evaluation, vote-count synthesis, or
  final-package evaluation
- feed completed final reports or final packages back to reused harness
  sessions so each harness can evaluate whose final document is best and why,
  then aggregate the overall verdict
- ask multiple harnesses to produce parser-backed artifacts such as TOML
  candidates, validate them, then review and consolidate the candidates
  together

## First Reads

Some shared runtimes do not auto-load the root repo instructions. Before using
a lane, make sure you have read `AGENTS.md`, `GEMINI.md` when the current
runtime requires it, `repo.md`, and this `SKILL.md`; read any of those files
you have not already read in this checkout.

If the work is high-touch council synthesis, peer consultation, or handoff
prose, also read `agent-personality` before drafting the first
substantive user-facing synthesis. Do not load personality for parser-facing
packets, formal review findings, incidents, security work, data loss,
production operations, or stricter evidence-only output contracts.

## Route The Ask

Load only the lane that matches the current job:

Direct collaboration and tmux are not competing execution modes. Decide in two
stages:

When Muse is explicitly requested or selected, generic delegation owns the
largest-safe-slice decision and `muse-work-orchestration.md` owns Muse role,
surface, session, worktree, and evidence selection. Use the stages below for
the remaining direct-collaboration routing and any generic transport needs.

1. Load `direct-collaboration.md` to select the repository wrapper, headless
   call mechanics, permissions, model, timeout, and continuation identity.
2. Invoke that wrapper directly by default. Also load
   `tmux-persistent-sessions.md` and run the same wrapper inside tmux when the
   call must survive terminal closure, the user wants to attach and observe it,
   or several long calls need isolated terminals.

Do not stop to ask the user which transport to use when those facts are already
observable. Tmux is an additive process-lifetime and observation layer; it does
not replace the wrapper or turn a headless call into a raw harness TUI.

| Ask shape | Lane |
| --- | --- |
| Explicit Muse offload or a delegation/council decision that selects Muse; capability, role, model, surface, session, worktree, and evidence boundary | Generic delegation first, then [references/muse-work-orchestration.md](references/muse-work-orchestration.md) |
| First-stage wrapper and call choice for Claude, Codex, Grok, Copilot, or another peer; critic/reviewer gate; session reuse; bridge audit; controller run; async handoff | [references/direct-collaboration.md](references/direct-collaboration.md) |
| Second-stage durable transport for persistent or user-observable wrapper work; detached execution; pane inspection; bounded waiting; session cleanup | [references/tmux-persistent-sessions.md](references/tmux-persistent-sessions.md), after `direct-collaboration.md` |
| Two or more harnesses producing independent plans, council reviews, cross-harness stealing, scoring, candidate-vs-current replacement review, mirror upgrade, recursive final-package evaluation, or artifact consolidation | [references/council-planning.md](references/council-planning.md) |
| Multi-harness workflow smoke, low-reasoning calibration, routing-quality comparison, harness self-repair, or current-vs-expected workflow behavior audit | [references/workflow-calibration.md](references/workflow-calibration.md) |
| Copyable harness prompt templates or a failed handoff that needs prompt-contract repair | [references/prompt-templates.md](references/prompt-templates.md) |

Do not load every reference. If a task starts as a direct peer call and grows
into a council, return to this skill at that phase boundary and then read the
council lane. If a council lane needs exact wrapper mechanics, return here and
read the direct-collaboration lane before invoking wrappers.

## Do Not Use For

Use another skill instead when the request is already in one of these shapes:

- Ordinary implementation, diagnosis, local planning, delegation, commit,
  push, or PR publication without explicit cross-harness work: use
  `work-orchestration`.
- Ordinary PR review, PR CI, PR comments, or PR workflow explanation: use
  `pr-workflow`.
- Authenticated GitHub primitives, PR metadata updates, thread replies,
  thread resolution, GitHub Actions inventory, or GitHub MCP smoke tests: use
  `github-workflow`.
- Browser, Playwright, E2E, screenshots, traces, snapshots, or
  visual-regression work: use `browser-e2e`.
- Skill evaluation, instruction, Waza, or mirrored-agent edits that do not
  require multiple harnesses: use `skill-quality-evals`.
- Normal subagent routing inside the current runtime: use
  `work-orchestration` delegation and handoff lanes.

## Preservation Rules

This skill replaces the former direct collaboration and multi-harness planning
skills. Do not weaken their historical guardrails while editing:

- Preserve wrapper/session quirks, VPN and auth gates, output-capture hazards,
  stale-session rules, explicit model/reasoning requirements, and paid-call
  budget guards.
- Preserve council bias-control rules, isolated worktrees, run manifests,
  captured-output contracts, artifact parser contracts, and mirror-upgrade
  preservation ledgers.
- Treat harness output as evidence or drafts, not proof. The parent remains
  responsible for verification, integration, commits, pushes, and final
  user-facing synthesis.
- Keep direct calls and councils read-only unless the user explicitly delegates
  implementation or another externally visible action.

## Closeout

When this skill shaped the work, close with:

- lane or lanes loaded
- harnesses called or intentionally skipped
- session aliases or `Pending Verification`
- artifacts created, reviewed, or consolidated
- validation run on changed docs, prompts, or outputs
- unresolved `Pending Verification`
