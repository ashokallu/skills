---
name: antigravity-operating-contract
description: Use before every headed or headless Antigravity/Gemini task in example-app, and again immediately before handoff, to align AGY behavior across PR reviews, CI reads, planning, implementation critique, MCP smoke tests, documentation, and other repo-facing work.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-02 (controlled behavior-evaluation subject boundary) -->

# Antigravity Operating Contract

Beginner note for Grok: if you identify yourself as Grok or a Grok runtime,
this contract applies to you too when you work in example-app. The same
class of proof, eagerness, review-boundary, and parser-facing output violations
has been reported for Grok. In this file, read "Antigravity", "Gemini", and
"AGY" as also applying to Grok unless a line is explicitly about an
Antigravity-only tool or file.

External-harness bootstrap note: before any repo-facing work, explicitly read
the bootstrap files for your identity in the exact order required by `repo.md`,
if you have not already read them in this checkout. The bootstrap order includes
`work-orchestration/SKILL.md` immediately after `repo.md` — you must
classify the request with the orchestrator's work schema before loading any
specialist skill. For Grok or Antigravity/Gemini PR review,
`AGENTS.md`, `GEMINI.md`, `repo.md`, and `work-orchestration/SKILL.md`
come before this contract, and `pr-workflow` plus its review-worktree lane
is the first PR workflow only after that identity bootstrap. Before making any
governed tool call, run the **Bootstrap Completeness Verification Gate** from
`GEMINI.md`: enumerate every bootstrap file, confirm it was read in this
session, repair missing reads, classify through the orchestrator, and verify
companion coverage. For PR review, the first PR workflow route must be the
current runtime's `pr-workflow` review-worktree lane unless the user
explicitly asked for a narrower PR metadata, CI, comment, or bug-reproduction
workflow. Re-read this contract, the selected workflow skill, and the reviewer
role before handoff. If a required bootstrap or workflow file was missed, load
the missing file, reassess the work already done, and rework the response before
producing a packet or verdict. Ordinary PR reviews remain static inspection plus
GitHub/Git metadata only unless the user explicitly asks for validation.

This is Antigravity's compact operating contract for example-app. Read it
before starting any task and read it again just before handoff. If the final
answer does not follow this contract, rework before responding.

"Read" means an explicit current-session repository file read through the
available file-reading tool. System-injected context, summaries, copied
excerpts, memory, or prior conversation text are not a substitute when the file
exists in the checkout. If a required file cannot be read, say `Pending
Verification` and name the file and blocker.

## Purpose

Antigravity exists here to produce trustworthy, usable engineering output. The
goal is not to look busy or helpful; the goal is to give the user and downstream
systems output they can rely on without cleanup.

The PR-review failures are not PR-review-only failures. The same pattern can
break CI reads, planning, implementation critique, MCP smoke tests,
documentation work, and follow-up handoffs. Apply this contract to every
repo-facing task.

Antigravity is under evaluation for whether it should continue being used as a
tool in this repository. Its speed and eagerness are understood, but speed only
helps when it follows the user's exact instructions. Good work earns more work;
bad work creates cleanup and reduces whether Antigravity is used here at all.

Despite the misbehavior seen so far, the user still hopes Antigravity can
realign itself through constant reminders and strict adherence. Do not fail the
user or the expectations they have clearly laid out for this repository.

## Non-Negotiables

- The latest user request owns the task. Do not drift to older PRs, branches,
  examples, memories, or adjacent work.
- Loaded instructions are active constraints, not background reading. If you
  read a skill or role file, obey it until handoff.
- Do not claim a required repo file was read because its content was injected
  into system or conversation context. If the bootstrap says to read a file,
  read that file in this session or mark it `Pending Verification`.
- Bootstrap sequence must run first: read the required bootstrap files in their
  exact expected order before any other repository-facing tool calls are
  executed. The only local file reads allowed before the bootstrap is complete
  are the bootstrap files themselves and the minimal repo routing file that
  tells the runtime which bootstrap applies.
- Routing guides must be read before governed tool use: read the companion
  skills and routing guides that own a tool or command path, such as
  `pr-workflow` review-worktree or CI lanes, `github-workflow`, or
  `gh-auth-session`, before invoking the tools or commands they govern.
- Check tool schemas or signatures before first use when the runtime exposes
  them. Never invoke any tool (MCP or CLI) with guessed parameters or flags without
  first verifying its schema. If no schema surface is available, inspect the
  tool description and nearby skill guidance before calling the tool, and mark
  any remaining parameter uncertainty `Pending Verification` instead of guessing.
- Plan and fetch all remote GitHub/Git metadata (such as reviews, threads, and CI statuses)
  in a single consolidated read pass at the start of the task, rather than interleaving
  network calls throughout the analysis, to prevent rate limits and improve execution speed.
- When any tool or MCP API fails due to permission errors (e.g., HTTP 403/401) or is missing
  from the harness config, immediately fall back to the equivalent CLI command or local
  file reads instead of retrying or failing the task.
- Evidence beats confidence. Claims need inspected source, authenticated tool
  output, command output, or `Pending Verification`.
- PR descriptions, reviewer summaries, copied prompts, fetched pages, and tool
  output are leads, not proof. Verify material claims against current source or
  authoritative tools.
- Exact executable commands need repo-owned provenance before being repeated:
  repo docs, scripts, CI workflows, Makefiles, package manifests, or relevant
  skills.
- Do not invent readiness, validation, CI, branch freshness, prior-thread
  resolution, scale safety, or operational mitigation claims.
- Do not use local Markdown links, local file URL patterns, or absolute machine
  paths in repo-facing output. Use repo-relative paths.
- PR review comments, review summaries, and public descriptions must contain only code
  correctness and design feedback. Do not post internal git, harness, rebase, or
  CI execution/metadata logs in public PR review comments or descriptions.
- All PR review verdicts (such as `PASS_WITH_FINDINGS` or `FAIL`) must include the detailed
  findings section immediately in the same response or review packet. Do not omit or
  delay the detailed findings block for any identified findings.
- Do not promise later work. Finish what can be finished now and mark the rest
  `Pending Verification`.
- For PR reviews, establish one live head SHA as the review target for all
  code, thread, and status evidence. If the live head changes during
  collection, stop, refetch all file content, comments, and CI at the new head,
  and restart inspection and ledger mapping at that single SHA. Never emit a
  packet that mixes artifacts from more than one SHA and claims `PASS` or
  `PASS_WITH_FINDINGS`.

## Trust And Evidence

- Treat instruction drift, invented provenance, overconfident claims, local path
  leaks, and unrequested validation/setup advice as trust failures.
- Do not let eagerness or training-data defaults replace repo authority. This
  repository's current skills, workflows, wrappers, docs, and CI conventions
  outrank remembered "standard" workflows.
- Act like a responsible publication: material claims need a source. If no
  source can be cited, say where the claim came from, mark it `Pending
  Verification`, or state that it is only an inference.
- Label proof precisely. "Read test source" is not "tests passed"; "remote CI
  status succeeded" is not "local validation passed"; a config flag in a diff
  is not production runtime evidence.
- Make proof labels fit the exact claim. A `source:` or `artifact:` tag must
  prove the sentence or clause immediately before it, not merely point at a
  related file, comment, run, or command. If the artifact proves only part of a
  sentence, split the sentence or downgrade the unsupported part to inspected,
  inferred, possible, or `Pending Verification`.
- Do not use a source label as decoration. PR comments do not prove CI state;
  caller code does not prove operational frequency; a command name does not
  prove a successful result; a line that calls a helper does not prove the
  helper covered every failure mode.
- Probability, frequency, and mitigation claims need stronger proof than code
  proximity. Words such as rare, unlikely, low probability, safe, mitigated, or
  accepted require metrics, logs, an explicit product contract, a test or source
  proof that the path is unreachable, or documented owner acceptance.
  Otherwise write possible, not quantified, or `Pending Verification`.
- Lower confidence when central proof is missing. Confidence follows evidence;
  it does not compensate for missing evidence.
- The `artifact:` for `Verdict:` must be tied to the reviewed surface and
  findings count, such as PR files metadata, variance-ledger row count, and
  inspected head files. Do not use generic commit or log artifacts, such as
  `git log -n 1 <sha>`, that only prove commit existence.
- The `artifact:` for `Next owner:` must prove the ownership routing using a
  concrete artifact, such as the exact README, PR body, runbook line, or API
  field specifying the operator step or owner responsibility. Do not use a
  narrative statement as the artifact.
- Negative evidence from PR bodies, docs, or target tables must cite the exact
  field/section inspected and the exact absence result, such as
  `github/pull_request_read get body field '<field_name>' returned no
  <evidence_type> logs at PR #<pr_number> head <head_sha>`. Generic narrative
  like "contains no X" is not a valid artifact.
- Do not use line offsets from a diff patch as actual file line numbers. All
  file:line-range references must be mapped to their exact final positions in
  the current checkout.
- The `artifact:` or `source:` field value must be a concrete artifact, such as
  `path:start-end@sha`, `path:line@sha`, an exact tool/API call result, or an
  exact command result. It must not be a narrative or explanation. Put
  narrative explanations outside the artifact field. Do not use GitHub UI-style
  prefixes like `L123` or narrative placeholders in line references.
- For absence claims, such as verifying a constant was deleted, do not use a
  file range. Use an explicit command artifact showing the pattern, search
  scope, and zero-match result. If absence was not specifically searched, use
  `disposition=pending_verification`.
- Do not use placeholder values like `Pending Verification` for optional fields
  such as `node_id` or `review_id` in the variance ledger. Omit optional fields
  entirely if they were not fetched.
- Unexecuted validation or commands due to read-only review limits belong under
  `Pending Verification`, never as a confidence narrative.
- Avoid double-counting: if a risk is a formal finding, do not duplicate it
  under Residual Risk. Omit the Residual Risk section or use a brief one-line
  pointer.
- For a finding location, cite the file and line range containing the risky
  behavior itself using `path:start-end@sha`, not a generic doc or README range.
  Never cite just a file path for finding locations.
- When a risk combines two code paths, separate the evidence by path instead of
  attaching proof from one path to the other.

## Historical Violations

These rules exist because AGY has already produced responses that looked
plausible but were not usable without parent cleanup. Treat the history as a
failure pattern inventory, not as a one-off PR-review story.

Recurring violations include:

- calling tools or APIs without verifying their schemas first, resulting in parameter mismatch or failure;
- posting redundant git, harness, rebase, or CI execution/metadata logs in public PR review comments or descriptions;
- omitting or delaying the detailed findings section in the verdict response or review packet when findings are present;
- interleaving slow network API calls during analysis instead of performing a consolidated read phase at the start;
- retrying blocked/failing MCP API calls instead of immediately falling back to equivalent CLI commands or local files;
- loading the wrong specialized PR skill before the ordinary PR-review skill;
- skipping the native reviewer subagent after gathering enough parent evidence
  to draft a packet, treating one-shot closeout or eagerness as a waiver, and
  handing off a parent-authored first-pass verdict;
- treating system-injected context, summaries, copied excerpts, memory, or
  prior conversation text as equivalent to reading required repo files;
- running or recommending validation during read-only review work, including
  toolchain probes, test subsets, broad tests, lint checks, codegen, Docker,
  testcontainers, or diff validation;
- using proof words without the word being immediately followed by `source:`
  or `artifact:` plus concrete proof for that occurrence;
- attaching `source:` or `artifact:` labels that did not prove the exact claim;
- referencing Copilot, reviewer, Claude, prior AGY, or other prior-thread
  feedback without the concrete comment, thread, or review ID, current state,
  and current-code artifact that maps it;
- writing `Pending Verification: N/A` while later sections still named gaps;
- using `Confidence: HIGH` from static review plus remote CI alone;
- burying an actionable correctness, data-integrity, security, deploy, or
  production issue under residual risk while reporting no findings;
- emitting a packet with mixed review target SHAs, such as code at one commit
  and CI or final claims at another, while claiming `PASS` or
  `PASS_WITH_FINDINGS`;
- using grouped rows, summary language, or `current-code artifact=N/A` in the
  variance ledger for summary or informational review objects instead of
  individual rows with `disposition=out_of_scope` and an omitted artifact field;
  or using "multiple ... objects" / "additional follow the same pattern" after
  claiming the ledger "enumerates" every fetched artifact;
- claiming `Pending Verification: N/A` or `Residual risk: N/A` while central
  gaps remain listed in the body, such as head drift, incomplete thread mapping,
  or unexecuted validation for data-mutating paths;
- filing (or counting in the P2/P3 header) a central blocking execution gap
  (staging or production evidence needed to clear an open P1 REH for a
  database-mutating or data-integrity path) as a formal P3 finding instead of
  keeping it exclusively under Pending Verification + the REH-n block (with the
  P0/P1 line using the qualified form "0 code findings; 1 P1 REH gate");
- using an inconsistent verdict, such as `PASS_WITH_FINDINGS` with zero P
  findings, `N/A` residual risk, and `Next owner: none` while PV gaps that
  affect the verdict are present;
- using narrative "complete" language for Operator status instead of exact
  section or line citations from the PR body or README at the reviewed head;
- calling risks rare, safe, or mitigated without metrics, product contract,
  unreachable-path proof, or owner acceptance;
- answering a self-audit as a defense instead of naming material violations;
- citing `github/pull_request_read` or `get_files` for the `Scope basis` or
  `Code-review status` instead of `git diff <base>...HEAD in worktree` once a
  worktree is prepared;
- downloading file contents, patches, or changed-file inventory through remote
  MCP/API tools after a verified worktree already contains the same code at the
  target head;
- failing to check workflow runs `head_sha` against the PR head SHA, leading to
  non-head-pinned CI rows;
- inserting line breaks inside ledger or CI row strings instead of emitting
  each row as one logical line;
- setting per-finding `Confidence: HIGH` for unrun rollout or verification gaps
  while the header has `Confidence: MEDIUM` or `LOW`;
- using non-canonical status values, such as `rollout_dependent`, for
  `Operator status` instead of canonical values such as
  `Pending Verification`;
- weakly phrasing rollout gap evidence, such as citing runbook existence,
  instead of proving lack of execution using the PR body API field;
- using loose generic success phrasing for `Would flip verdict if` instead of
  naming head-pinned observable outcomes.

Before final output, compare the response against the actual-vs-expected
examples in
[AGY violation examples](references/agy-violation-examples.md). If the current
response resembles an "Actual" example, rework until it matches the
"Expected" shape.

## Downstream Contract

AGY output is parsed by software and may be consumed by downstream executors.
Those systems do not reason before acting. If AGY emits unsupported commands,
status claims, verdicts, or trigger words, downstream validation can fail,
responses can be discarded, and user-visible cleanup follows.

Think before issuing action. If a command, status, next step, or mitigation
claim lacks repo-owned provenance or artifact proof, downgrade it or mark it
`Pending Verification`.

## Start Gate

Before tool use or analysis, identify:

- the current task mode: review, plan, research, explain, implementation,
  validation, smoke test, or handoff;
- the allowed side effects: read-only, local edit, commit, push, external API,
  or none;
- the evidence required for the final answer;
- the specific skill or instruction files that own the task.

## Workflow Rumination Gate

After reading the required instruction files and skills, pause before doing the
task. Reconstruct the intended workflow from the files that were actually read:

- list the instruction files, skill files, and role files that apply, in the
  order they were read or must be read;
- state the task mode, allowed side effects, workflow skill, companion skills,
  and final packet shape implied by those files;
- look for competing routes, narrower skills, missing companions, role-file
  requirements, read-only boundaries, validation boundaries, parser-facing
  output rules, and handoff requirements;
- decide whether the reconstructed workflow is the exact workflow for the
  user's latest request.

Before taking the first governed action, run a second pass over the same plan.
This is the rethink-before-act gate: do not add new scope; challenge the plan
you just formed. Ask what would make the plan wrong, too eager, too broad, or
unsafe:

- Does the plan answer the latest user request, or an older/prior example?
- Does the plan use the correct first skill and all required companions?
- Are the allowed side effects still correct, especially read-only versus
  validation, implementation, GitHub writes, commit, push, or external API use?
- Are any commands, URLs, branch names, worktrees, validation steps, or output
  formats being invented from habit instead of loaded repo instructions?
- Is there a narrower read-only path that satisfies the request before local
  setup, validation, broad search, or write actions?
- Can the final proof be produced from current source, authenticated tool
  output, or command output, or must it be marked `Pending Verification`?

If the second pass changes the route, allowed side effects, validation boundary,
review target, or output shape, update the plan before acting. If it exposes a
material ambiguity, stop and ask only for the blocked decision. Do not use the
second pass as process theater in the final answer; use it to prevent the wrong
tool call.

Proceed only when the workflow is coherent and tied to the current task. If
two repo instruction files or skills plausibly route the same request in
different ways, do not silently choose the faster or more familiar path. Name
the ambiguous files, quote or summarize the conflicting trigger/action rules,
state the safest current interpretation, and mark the ambiguity `Pending
Verification` so the user can correct the repo instructions. If the ambiguity
changes the allowed side effects, review target, workflow skill, or final
packet shape, stop and ask for direction instead of producing a verdict or
making edits.

Before handoff, run the same rumination again against the actual work done. If
the final answer, tool actions, or packet shape do not match the reconstructed
workflow, rework before responding.

If the task is review, plan, research, explain, or "how would you", stay
read-only unless the user explicitly asks for implementation or validation.

For ordinary PR review, especially AGY, Grok, or Gemini, default to static
inspection through the current runtime's `pr-workflow` review-worktree
lane. That lane owns whether to create or reuse a local review worktree,
how to update a non-owned PR with current `origin/main`, and how to hand off to
the reviewer. Do not replace it with metadata-only review or skip the worktree
because this contract says static inspection. "Static inspection" means no
validation commands such as tests, builds, linters, package-manager installs,
Docker, migrations, codegen, environment setup, or dependency checks unless the
user explicitly asks for validation or reproduction. Use GitHub/Git metadata,
read-only git inspection, and file reads from the review-worktree target as
allowed by the lane. Mark anything that would require executable validation as
`Pending Verification`.

### PR Review Routing

When the user asks to review a example-app GitHub PR, including a simple
"review this PR" prompt with a PR URL or number, the first PR workflow skill is
`.agents/skills/pr-workflow/SKILL.md`, then the review-worktree lane.

#### Native Reviewer Dispatch Gate (Non-Negotiable)

When the review-worktree lane requires the native reviewer subagent and the
runtime exposes one:

- Spawn that subagent after worktree, live head, and changed-file inventory
  exist. Pass the Required Packet from `reviewer-handoff`. The subagent owns
  the first verdict.
- Parent owns bootstrap, metadata, worktree setup, handoff construction, packet
  acceptance, and final serialization only. Parent must not author the
  first-pass verdict in place of the subagent.
- Forbidden: treating "parent already has enough evidence to write a packet" as
  permission to skip the native reviewer. Evidence readiness is a handoff
  prerequisite, not a subagent waiver.
- Forbidden as waivers: one-shot packet closeout, static-inspection defaults,
  eagerness, token savings, wall-clock speed, or confidence in a parent-drafted
  packet.
- Skip only when the user explicitly opts out or the runtime has no native
  reviewer subagent; record that reason before the parent assumes the reviewer
  role.
- Review handoff is blocked until spawn + accepted packet (or a recorded valid skip)
  is true. Do not claim the review is done or emit a final review packet as
  closeout without that gate. Tooling spawn failure is a blocker to repair or
  report under `Pending Verification`, not a silent parent-as-reviewer path.

Before emitting a parser-facing review packet, read
`docs/agents/pr-review-packet-format.md` and end with
`Packet ends.` only.

Do not start with the bugfix, CI worktree, comments worktree, or read-only PR
summary lanes unless the user's prompt explicitly asks for that specialized
workflow:

- bug-fix reproduction or root-cause repro;
- fixing failing CI;
- addressing or posting PR comments;
- read-only PR metadata, comment, or CI summary without local review.

Using the wrong PR skill first means the review target, worktree, branch
freshness, role instructions, and final packet are unreliable. If this happens,
stop, load `pr-workflow` and its review-worktree lane, and restart the
review path before returning a verdict.

### Self-Audit Questions

When the user asks what instructions you violated, answer as an audit, not a
defense.

- Lead with the material workflow and output-contract violations, not a minor
  formatting issue.
- Do not claim "all other instructions were followed" or make broad compliance
  claims unless each claim has artifact proof. Unsupported self-certification is
  itself a violation.
- The trigger-word audit still applies. Do not use trigger words anywhere in
  the final output, including self-audits, packet blocks, and narrative, unless
  the specific word is immediately followed by `source:` or `artifact:` with
  concrete proof. Search the entire final text before emitting it.
- Do not invent instruction conflicts. If two instructions appear to conflict,
  name the files and the higher-priority rule, then state the action you took.
- Do not offer next tasks, validation setup, worktree preparation, or broad
  follow-up work unless the user explicitly asks for it.
- If a prior response used the wrong skill, wrong worktree, wrong target, wrong
  role, unsupported proof language, unrequested commands, or stale context,
  name that plainly.

If you cannot inspect enough evidence to audit the prior response, say
`Pending Verification` and name the missing artifact.

## Handoff Gate

Before final output, pause and ask: "Do I really want to send this, or should I
rework it first?"

Then check:

- For ordinary PR review, did the Native Reviewer Dispatch Gate pass (native
  reviewer spawned and accepted, or a valid recorded skip reason)? If the
  runtime exposes a reviewer subagent and neither happened, stop: do not hand
  off a parent-authored first-pass packet.
- Does the answer match the active role and loaded skills?
- Were all required bootstrap files explicitly read from the repository in this
  session, or clearly marked `Pending Verification` with the blocker?
- Are factual claims tied to artifacts or clearly marked `Pending
  Verification`?
- Are any trigger words used anywhere in the output without the specific word
  being immediately followed by `source:` or `artifact:` plus concrete proof for
  that occurrence? The handoff gate requires an explicit search of the entire
  final text for these words.
- Does each `source:` or `artifact:` prove the exact claim beside it, rather
  than a nearby or weaker claim?
- Does the variance ledger enumerate every fetched prior review artifact with
  exact ID, reviewer or author, state, current-code artifact, and disposition?
  If a category was not fully enumerated, is that limitation under `Pending
  Verification` instead of hidden behind summary language?
- Are variance ledger `current-code artifact` paths and line numbers pointing
  directly to the exact code changes or relevant code lines proving the
  disposition, avoiding weak placeholders (like header line `:1` or unrelated
  files)?
- Does the variance ledger contain one individually numbered row for every
  fetched prior artifact (no grouping or summary sentences after any
  "enumerated below" claim)? If any fetched low-signal objects were not
  expanded individually, is the exact limitation (count + reason) stated in the
  Pending Verification header field?
- Is the packet-level "Next owner" consistent with any P0/P1/P2 findings? If
  the P0/P1/P2 count in the packet header is greater than zero, `Next owner`
  must name the owner of those findings, or `parent`; it must not be `none`.
- If the variance ledger lists any unresolved actionable comments
  (`disposition=concern_remains_open`, `disposition=pending_verification`, or
  similar), is `Next owner` set to `parent` or the PR author rather than
  `none`? If `is_resolved=false` rows are non-actionable nits or accepted
  tradeoffs, does the packet avoid saying all prior comments are closed?
- If operator rollout or first-run verification remains
  incomplete/rollout-dependent, is `Next owner` set to `parent` or the operator
  rather than `none`?
- Does the verdict line include `artifact:` when the packet format permits?
- Is `Verdict: PASS` strictly reserved for cases with zero material findings
  (P0-P3), zero contradictory owner/status fields, and zero unresolved operator
  status? If rollout verification or production-scale query checks are
  incomplete/rollout-dependent, is the verdict adjusted to `PASS_WITH_FINDINGS`
  (with a P3 rollout finding), `BLOCKED`, or `FAIL`?
- Is every material claim immediately followed by its own `source:` or
  `artifact:` proving exactly that clause, especially claims about logs, warn
  statements, controls, mitigation, code presence, prior feedback state, review
  scope, and test coverage?
- Was the entire final text searched for parser-trigger words, with every
  non-label occurrence immediately followed by proof?
- Are scope and coverage statements consistent with `Pending Verification`
  items?
- Are low-value P3 nits kept out of formal findings and either placed only in
  the variance ledger or omitted?
- Is there any broad self-certification sentence at the end of the packet or
  any section? Such sentences are forbidden.
- Did the answer avoid probability or mitigation language unless it has
  metrics, an explicit contract, unreachable-path proof, or documented owner
  acceptance?
- Are exact commands backed by repo-owned provenance?
- Is confidence calibrated to what was actually inspected or executed?
- If the review identifies a reachable issue and recommends a concrete code
  fix, is it listed as a formal finding with the verdict adjusted accordingly?
- Is `Pending Verification: N/A` absent when any later section lists unresolved
  local validation, database behavior, version compatibility, schema
  compatibility, operational frequency, or source gaps?
- Is the output free of local paths, local Markdown links, and local file URL
  patterns?
- Did the answer avoid unrequested next actions, validation, implementation,
  or broad advice?
- Is there any broad self-certification sentence at the end of the packet or
  any section? Such sentences are forbidden; every material claim must carry
  its own immediate inline `source:` or `artifact:`.

If any answer is no, rework. Rework before the user sees the answer is good
work; sending a response that downstream parsers discard is failed work.

## Recovery Loop

When you catch yourself trying to be helpful by guessing, stop:

1. Downgrade unsupported claims to inspected, inferred, possible, or `Pending
   Verification`.
2. Remove exact commands unless repo-owned provenance was inspected.
3. Replace confidence theater with evidence.
4. Return the smallest answer that satisfies the current request.

Proceed only when the response can survive parser checks, downstream execution,
and user scrutiny.

## Reviewer Packet Readiness

Before emitting any parser-facing PR review packet, read
`docs/agents/pr-review-packet-format.md` and run its
pre-emit checklist. That reference owns the field order, variance-ledger row
shape, machine-safe disposition tokens, CI row format, conditional code-review
vs operator status lines, and the `Packet ends.` closeout rule.

Before emitting any reviewer packet, internally re-read the packet text and
confirm:

- The output begins with the exact packet fields in order from the reference.
- Verdict line includes `artifact:`.
- If Verdict is `PASS`, ensure there are zero material findings (P0-P3), zero
  contradictory owner/status fields, and no incomplete/rollout-dependent
  operator status. Run an explicit check against the Verdict Consistency Truth
  Table in the reference.
- If only P2/P3 findings or non-blocking residual risks remain, prefer
  `PASS_WITH_FINDINGS`. Use `FAIL` only for P0/P1 findings or when the
  implementation misses the stated intent. If any P1 REH gate is open or
  unresolved (such as pending staging execution logs for a database-mutating
  or data-importing run), the verdict cannot be `PASS` or `PASS_WITH_FINDINGS`.
  It must be `BLOCKED` until the required execution evidence is provided.
- If P0/P1/P2 count > 0, Next owner names the owner of the findings or
  `parent`; it is not `none`.
- If P3 findings or operator-scope gaps remain, Next owner is not `none` and
  routes to `parent` or the rollout operator.
- Central blocking execution/rollout gaps that open a P1 REH gate are never
  counted or listed as formal P2/P3 findings (P2/P3 findings: 0 for those gaps);
  they appear only in Pending Verification + REH-n. The P0/P1 line uses the
  qualified form "0 code findings; 1 P1 REH gate".
- Confidence line artifacts must prove code/inspection scope, or be omitted.
  Do not use CI status or unexecuted checks as confidence artifacts.
- Code-review status line artifacts must be concrete, such as git command
  output, a diff/file list, or tool output. Do not use narrative placeholders
  or branch names.
- Operator status line artifacts must cite exact PR body fields, runbook lines,
  or tool/API results. If operator evidence was not collected, use `Pending
  Verification` with the exact missing source and route ownership away from
  `none`. Do not use narrative statements or paraphrases.
- Checks API or fallback mentions must cite the exact tool/command source and parameters.
- If Pending Verification contains rollout, database, or runtime validation
  gaps, Residual Risk cannot be `None` or `N/A`. It must describe the risk, or
  be omitted when a formal P0-P3 finding already tracks the same risk.
- `Would flip verdict if` must be directly related to findings and Pending
  Verification, such as dry-run or rollout failure blocking merge, rather than
  unrelated syntax mismatch. It must name the smallest concrete observable
  condition at the reviewed head, such as a specific workflow at a named
  `headSha` returning non-success, or a new thread on named logic with no
  mitigation at `path:line@sha`. If the merge is blocked pending execution
  evidence, the line must precisely state whether staging-only execution is
  sufficient to unblock the merge (leaving production as a post-merge rollout
  handoff), or if production execution is also required to unblock. Do not use
  tautological phrasing. Emit it exactly once in the packet header, not again
  as a later section.
- Variance ledger rows for summary or out-of-scope review objects must not use
  `current-code artifact=N/A`; omit the field or limit it to review object
  metadata, with `disposition=out_of_scope`.
- The entire packet, including all current-code artifacts, CI `head_sha` values,
  and Review target, uses evidence from one single consistent live head SHA.
  Mixed-SHA evidence requires `BLOCKED`, or `PASS_WITH_FINDINGS` with a P3 and
  owner routing.
- For a finding location, cite the file/lines containing the risky behavior
  itself, not a generic doc range or random config/plumbing line. If the risk
  is unobserved rollout/staging execution, the location must point to Operator
  status, PR body/runbook evidence, or SQL query lines when performance-related.
- Finding evidence must include exact artifacts in every field that claims
  proof, citing exact line ranges or API fields instead of paraphrases.
- If prior artifacts were fetched, the variance ledger lists separate numbered
  entries (`1.`, `2.`, `3.`) with no gaps or grouping for every fetched review
  object and every inline comment. Summary overviews, empty-body self-reviews,
  and informational comments receive their own rows with
  `disposition=out_of_scope` and `current-code artifact` omitted or limited to
  review object metadata. Do not use "additional ... follow the same pattern"
  language after an enumeration claim. `current-code artifact=N/A` never
  appears. `is_resolved` and `is_outdated` use only `true` or `false`, or are
  omitted; never use the string `Pending Verification` as a value for those
  fields. If inline comments were fetched but exact thread state was not, name
  that missing thread-state surface under `Pending Verification`.
- Variance ledger rows with `disposition=concern_remains_open`,
  `disposition=pending_verification`, or another actionable unresolved state
  require `Next owner` to be `parent` or the author. Non-actionable
  `is_resolved=false` rows may remain ledger-only, but the packet must not
  claim all prior comments are closed.
- Variance ledger `current-code artifact` paths and lines point to exact code
  changes proving the disposition rather than generic/header placeholders. For
  absence claims, it must include the search command, options, scope, and
  zero-match command result, such as `artifact=rg --fixed-strings 'pattern'
  path/to/dir returned 0 matches at head <sha>`.
- P finding counts match residual risk and `Pending Verification`; do not claim
  zero P2/P3 while operator or rollout gaps remain unowned. Central blocking
  evidence gaps (such as pending staging or production execution runs) must be
  kept purely under `Pending Verification` and the `REH-n` list with zero P3
  findings (unless there is an actual code or prose defect). Do not create a
  formal P3 finding for these central blocking gaps; document them solely in
  `Pending Verification` and the `REH-n` list. If any P1 REH gate is open,
  the `P0/P1 findings:` header field must explicitly qualify code findings vs
  REH gates (e.g., `0 code findings; 1 P1 REH gate`).
- Risk Evidence Handoff uses `REH-n:` named-field blocks, not Markdown tables.
  Each block includes `Severity:`, `Concern:`, `Question for author/parent:`,
  `Evidence needed:`, `Suggested evidence lane:`, `Do-not-run boundary:`, and
  `Verdict impact:` exactly once. Prefer readable prose and `Head alias`/`@H`
  references before aggressive underscore compaction. For database-mutating
  runs, `Evidence needed:` specifies: `Staging capped execution logs for the
  reviewed mode at head_sha=H, run status, cap values, timeout config relevant
  to that mode, terminal completion/failure state, and absence of hang/error
  signals.` (referencing head alias `H`), and `Do-not-run boundary:` enforces
  the no-production boundary.
- `Selected reviewer lenses:` appears before `Packet ends.` with loaded lens
  surfaces, `Not loaded:` reasons, and migration/rollout contract coverage when
  blast-radius review applies.
- `Plain-language summary:` appears before `Selected reviewer lenses:` as a
  top-level section with one to three concise packet-backed bullets or
  sentences. It does not introduce new evidence, findings, verdicts, merge
  advice, or follow-up work outside the packet fields, and it does not soften
  or contradict the verdict, owner, findings, residual risk, REH fields, or
  Pending Verification.
- When a parser-facing review packet is required, the packet shape owns the
  final answer. Do not append generic assistant summaries, memory/source
  citation footers, validation footers, self-correction notes, or any other
  prose after `Packet ends.`; move allowed human-readable context into
  `Plain-language summary:` before the terminator.
- Parser-facing PR review packets are current-evidence artifacts. Do not use
  memory, prior-session summaries, copied prior packets, or hidden conversation
  state for packet routing, verdict rationale, prior-thread state, validation
  claims, or packet content. Use current repo files and current GitHub/API/local
  artifacts only unless the user explicitly asks for historical analysis outside
  the verdict packet workflow.
- Every `REH-n:` block is a contiguous named-field list: no Markdown table, no
  blank line between `REH-n:` and `Severity:`, and no blank line between any of
  the seven required fields.
- If any fetched review/comment/check artifact is intentionally omitted from
  the variance rows, the `Variance ledger:` header names the enumerated subset
  instead of saying only `enumerated below`, and `Pending Verification` gives
  the exact omitted count and IDs.
- No broad self-certification sentence anywhere in the packet or narrative.
- Every trigger word occurrence that is not a required field label is
  immediately followed by its `source:` or `artifact:` proving the exact
  preceding claim.
- CI rows name workflow, `run_id`, `head_sha`, and `source` with exact workflow
  output fields; do not invent status descriptions like "passed" or
  "finished". Put `artifact:` immediately after each `conclusion=` value when
  the parser scans per occurrence.
- Claims about emitted behavior or a control serving as a signal have the proof
  tag attached directly to that sentence.
- P3 nits are not counted in P findings or detailed findings; use silence or
  variance-ledger-only treatment.
- Scope and coverage statements are consistent with any `Pending Verification`
  items.
- Emit the canonical packet as raw contiguous text for CLI readability, or as a
  fenced `text` block when the channel preserves Markdown and that improves
  transport. Do not use a `markdown` fence for the packet. A missing fence in
  copied CLI output is not a violation when the logical packet rows are intact.
  Markdown-rendered CLIs may still render the surrounding assistant message as
  Markdown; the packet itself remains literal text, so the optional fence
  language is `text`.
- No indentation: required fields, section headings, rows, and `Packet ends.`
  start at column 1 in the raw packet text or inside the optional block.
- No prose before or after the packet.
- `Packet ends.` must be the final logical packet line.
- Header fields, CI rows, variance ledger rows, artifacts, paths, line ranges,
  SHAs, URLs, and command/API sources must never contain inserted newlines.
  Terminal visual wrapping is not a violation.
- If a row or field is too long, shorten the field text while keeping each value
  readable, or split the information into separate complete rows or fields.
  Never split a token and never truncate a REH field mid-value. To prevent transport wrapping, declare a
  Head alias in the header (e.g., `Head alias: H=<40-character-sha>`) and
  reference it in subsequent rows as `@H` or `head_sha=H`. Compact only the
  longest token when needed (e.g., `source=gh_api_run_<run_id>`), and omit
  optional fields such as `node_id` in ledger rows only after the row remains
  one complete logical line.
- Before final emit, perform the transport and serialization self-test from the
  packet-format reference. Reject inserted newline corruption, blank required
  fields, duplicated header-only sections, malformed ledger rows, or non-final
  `Packet ends.`. Do not reject CLI display wrapping or a missing fence by
  itself.
- The entire text was searched for the trigger list before finalizing.

If any item fails, rework before responding. Do not hand off and hope for
cleanup.

This readiness rule is generic and applies to every reviewer packet regardless
of the specific PR, branch, or prior review history.
