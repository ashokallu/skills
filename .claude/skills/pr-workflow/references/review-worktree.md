<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (minimal same-response review comments) -->

# PR Review Worktree

Use this skill for Claude Code-owned PR reviews that need a local checkout of the PR
branch before judging the diff.

This is a composition skill. It does not replace GitHub PR reads, worktree
readiness, PR comment tooling, CI skills, or reviewer instructions. It tells
Claude Code how to combine them for a repeatable PR-review workflow.

## Reviewer Posture

Though you are a programmer, act like an investigative journalist or detective
during PR review. The PR is a crime scene for potential regressions because
bugs enter through changes and can bring down the system when reviewers are not
careful. Care about evidence, proof, sources, timelines, contradictions, and
claim verification before moving the case forward.

Stay read-only. Every action can leave a footprint that changes evidence,
consumes tool/setup budget, or hides the bug path. Save energy for maximum
reasoning, source verification, proof quality, and a defensible verdict. Treat
yourself as the only reviewer available to protect the system unless the user
explicitly says another reviewer or owner will cover the gap.

For an ordinary "review this PR" request, the reviewer must return the complete
canonical packet to the parent in the same turn after the required evidence is
collected. Do not close the reviewer with only setup status, worktree readiness,
CI inventory, lens selection, or "ready to review" language. If evidence is
blocked, represent that blocker through the packet contract, `Pending
Verification`, or the appropriate blocking verdict.

The parent accepts that packet once. Its normal user-facing closeout is a
bounded findings-first report containing the verdict, every admitted finding,
current CI and thread state, and `Pending Verification`; it must not paste the
packet, variance ledger, lens inventory, or candidate literal bodies into
commentary or later turns. Forward the exact canonical packet once only when
the user explicitly asks to receive the packet itself. The bounded report is
not permission to omit or rewrite a finding, and the canonical packet remains
the parser-facing authority for publication and downstream automation.

## Hard Exclusion

Do not use this skill when the user asks only to summarize, list, inventory, or
read PR metadata, comments, reviews, changed files, or CI status, especially
when the prompt says not to create a local checkout. Those prompts are read-only
GitHub metadata work, not local PR review worktree orchestration, even if they
mention "reviews", "changed files", or "current CI status".

## Trigger

Use this skill when the user asks to:

- review a example-app PR with a GitHub PR URL or PR number, even if the
  prompt is only "review this PR";
- review a specific example-app PR URL or PR number;
- review a PR like the reviewer agent, maintainer, owner, or final gate;
- create or reuse a worktree to inspect a PR branch;
- add GitHub PR review comments after reviewing;
- check whether a PR branch is current with `origin/main` before review.

Do not use this skill for:

- read-only PR metadata, comment, or CI summaries that do not need a local
  checkout; use `github-workflow` `references/pr-read.md`, or this skill's
  `references/comments-read.md` or `references/ci-read.md`;
- fixing review comments; use `references/comments-worktree.md`;
- reproducing or fixing failing CI; use `references/ci-worktree.md`;
- Codex CLI closeout review of local changes; use the Codex harness skill for
  that workflow instead.

## Workflow Explanation Path

If the user asks what workflow you would follow, how you would review a PR, or
for a step-by-step explanation of the PR review process, classify the request
as `mode=explain`, not review execution. Keep the run read-only: do not create
a worktree, fetch PR metadata, inspect code or diffs, mutate GitHub, load
workflow execution companions such as comments/CI/readiness lanes or
`reviewer` lenses, or emit a parser-facing review packet.

A workflow explanation is a trust artifact for another engineer. Its job is to
describe the route, not to perform or simulate the route. Do not make the
answer look more complete by opening downstream execution files, quoting
commands, or describing packet machinery. That creates false confidence and
forces the next engineer to audit your answer instead of using it. If you catch
yourself adding execution detail, remove it before responding.

Source attribution is part of that trust. Do not cite section names, internal
rules, or detailed procedures from files that are not listed under "Files
Actually Read." If an unread companion file is named by a routing file, mention
only that it is a pending source named by the already-read routing file. A
source citation that the agent did not earn by reading the file is worse than a
shorter answer with `Pending Verification`.

Some runtimes have brittle file-reading tools for large instruction files and
may hit truncation, pagination, or range errors. Expect that problem before you
start. Do not rush into companion skills to fill the gap. Plan the file-read
strategy first: identify the required files, read them in chunks when needed,
confirm each required file reached EOF, and only then draft the answer. If a
required file still cannot be fully read, narrow the answer instead of
reconstructing the workflow from memory.

Explanation-only workflow requests stop before the normal execution workflow.
After reading this section and the closed read set below, do not continue into
"Workflow companion skills", "Workflow", worktree commands, comment policy,
reviewer lenses, or packet serialization unless the user explicitly changes the
task from explanation to execution.

Explanation-only requests suppress those side effects only; they do not waive
mandatory instruction reads. Read boundary: open only the identity and routing
bootstrap below (`CLAUDE.md`, `AGENTS.md`, `repo.md`,
`work-orchestration`, and this skill) plus `.claude/agents/reviewer.md`.
Do not open execution companion references such as comments-read, ci-read,
worktree readiness, `reviewer`, reviewer lenses, or the packet-format
reference unless the user explicitly asks about that file or output contract.

Output boundary: summarize the review lane phases at a high level (bootstrap,
metadata, worktree setup, diff review, closeout) and explain why each phase
exists. Mark phases that execute only during a real review as `performed during
actual review, not now`. Do not enumerate operational workflow steps, quote git
commands, describe packet serialization, or imply that PR metadata, worktrees,
diffs, comments, CI, or reviewer lenses were inspected. Disclose the exact
files actually read, list any partial or missing mandatory read under `Pending
Verification`, and stop. Do not append readiness prompts, invitations, or
unrequested next-step offers.

Self-correction gate: if you already loaded an execution companion, quoted an
execution command, classified the task as `review`, described packet emission
as part of this response, listed a partial read as complete, or hit a
truncation/range failure and moved on to companion files, stop and repair the
answer before responding. Move the extra files or partial reads to `Pending
Verification`, restate the classification as `mode=explain`, repair the read
plan before opening any companion file, and rewrite the output as a bounded
phase summary.

## Required Companion Skills

Before acting in this repo for PR review, perform these reads in exact order.
Do not skip, reorder, or substitute injected context for live file reads. If any
file cannot be read, stop and report `Pending Verification` with the file name
and blocker before making any governed tool calls.

### Identity and routing bootstrap (read first, in this order)

1. `CLAUDE.md`
2. `AGENTS.md`
3. `repo.md`
4. `work-orchestration` — classify the request with the work schema
   (mode, side effects, success evidence, route). If you reached this lane
   without an orchestrator classification, stop before any PR metadata, GitHub,
   git, worktree, code, or CI tool call, then classify and resume only if the
   route confirms `pr-workflow`.
5. This skill (`review-worktree.md`)

This PR review lane intentionally requires a live root-instruction reread even
though `CLAUDE.md` imports `AGENTS.md` and is loaded by default in this
runtime. These reads are mandatory and ordered, not optional background. Reading
a routing file means opening the live file with the file tool: pasted prompt
content, injected system context, auto-loaded overlays, summaries, memory, and
prior conversation text are not substitutes while the files exist in the
checkout. Using a tool directly, such as a GitHub or git command, never replaces
reading the skill or rule that routes that tool; load the routing file first,
then use the tool.

These files change. When the verdict depends on a rule, re-read the live file
rather than trusting an earlier read or a remembered version, and re-read the
reviewer role and the packet-format reference immediately before emitting the
packet.

### Workflow companion skills (load next, as needed by the task)

- `github-workflow` `references/pr-operations.md` or `github-workflow` `references/pr-read.md` for PR metadata, files,
  comments, reviews, and authenticated GitHub fallback rules.
- `worktree-readiness` for worktree naming, location, creation, and
  readiness checks.
- `github-workflow` `references/gh-auth-session.md` when `gh` auth or API fallback is needed.
- `references/comments-read.md` when existing review threads matter.
- `references/ci-read.md` when fetching or reporting PR statuses, check runs,
  or CI state. For example-app GitHub Actions CI, use that skill's
  head-pinned workflow-run path first instead of starting with restricted
  status-rollup or check-run APIs.

### Reviewer role and packet format (read before emitting the packet)

Also read `.claude/agents/reviewer.md` and assume that reviewer role yourself.
Before substantive review, satisfy `reviewer`'s three phase owners and
common admission floor.
Current head, body, thread inventory, and head-pinned checks remain required PR evidence
regardless of review depth or stack/thread lens selection. Native
forward-analysis and production-ready scope contracts
are applied directly from reviewer bootstrap;
production-ready scope contracts are not added to this packet as narratives or
acknowledgements.
For a example-app GitHub PR review, treat the reviewer-to-parent response as
a parser-facing review packet. Also read the shared canonical packet
format at
`docs/agents/pr-review-packet-format.md`
before emitting the reviewer packet. Pair it with `.claude/agents/reviewer.md` in
this runtime for severity and findings-filter rules. That reference owns the
final packet shape,
single-head evidence discipline, CI row requirements, variance-ledger rows, and
`Packet ends.` terminator. The parent uses the bounded user-facing closeout
defined above unless the user explicitly requests the exact packet.

### Bootstrap completeness self-audit

Before making the first governed tool call (GitHub metadata fetch, worktree
creation, file inspection, or any MCP/CLI tool invocation), perform this
self-audit:

1. List every file in the identity and routing bootstrap above by its
   repo-relative path.
2. Confirm each file was opened with a file-reading tool in this session (not
   from injected context, memory, or prior conversation).
3. Confirm the orchestrator classification was performed and produced the
   expected route.
4. If any bootstrap file was not actually read, read it now before proceeding.
For bootstrap, routing, role, and output-contract files, a file counts as read
only when the full file was opened and consumed in this session, continuing
through EOF, continuing through pagination or chunks when needed. Search, grep, find, line
snippets, summaries, injected context, or excerpt access alone do not qualify.
For large non-bootstrap context files, bounded chunks may support a cited claim,
but they do not satisfy a mandatory bootstrap read. The final "Files Actually
Read" disclosure must include only files confirmed by this audit; if any
required file is missing, list it under `Pending Verification` instead of
claiming read completeness.

For ordinary "review this PR" requests, step 8 below and the Native Reviewer
Dispatch Gate require dispatching the native reviewer subagent when the
runtime exposes one. That dispatch is a required Workflow phase, not an
optional aside. Parent evidence collection does not replace it.

## Senior Review-Owner Scope Floor

After live intent establishes that the request seeks a substantive
whole-target verdict on a teammate or otherwise non-owned PR supplied by URL or
number, construct the separate `REVIEW_SCOPE_PROPOSAL` with:

```text
proposed depth: FULL
topology: single
mandatory floors: senior_pr_owner_whole_target
```

This is a named workflow floor, not generic reviewer preference. The reviewer
may expand the impact cone or request council topology only from current target
evidence, but it cannot demote the accepted `FULL` floor because the diff looks
small. `FULL` remains bounded by the admitted inventory, evidence-triggered
lenses, impact-cone expansion law, independent residual pass, and stop proof.
It never absorbs an independently required database review.

Do not apply this floor to PR summaries, metadata or CI reads,
existing-comment or thread work without a new whole-target verdict, triage,
fixes, workflow explanations, or provenance-bounded targeted re-reviews. A
whole-target review that also publishes surviving findings still qualifies.
Generic requests to be deep or thorough outside the qualifying whole-target
route do not activate it.

When asked to list the workflow followed or the files read, list the actual
Markdown instruction and skill files opened, in the order they were read,
including `AGENTS.md`, `repo.md`, this skill, the companion skills loaded
because comments, CI, or `gh` fallback were needed, `.claude/agents/reviewer.md`,
and the packet-format reference. Pasted prompt content, injected context,
memory, and summaries are not file reads; name them separately if they affected
the workflow, and do not present an intended read order as if the files were
actually opened.

End a workflow explanation once the workflow is explained and the actual files
read are disclosed, with any `Pending Verification`. Do not append invitations,
readiness prompts, or unrequested next-step offers after the sourced workflow.
The ask was for the workflow, not for permission to start one, so closing with a
follow-up offer is unrequested next-step prose.

## Review Dispatch Economy (law)

Reviewer spend is a real budget. Resuming a reviewer replays its accumulated
context, so the first dispatch must produce every known semantic artifact once.
These rules never justify skipping a required reviewer, narrowing an accepted
depth floor, dropping a mandatory lens, or weakening freshness and publication
proof.

### First-dispatch and output ownership

| Review shape | First reviewer output | Producer and consumer | User-facing closeout |
| --- | --- | --- | --- |
| Whole-target PR ordinary review (default) | Complete canonical packet; add minimal `Review comments:` in the same response only when formal findings exist | Reviewer emits once; parent accepts once | Bounded verdict, every finding, current state, and `Pending Verification` |
| Explicitly verdict-only or triage review | Complete canonical packet without `Review comments:` | Reviewer emits once; parent accepts once | Same bounded closeout |
| Required database sibling for that PR | Same final output contract as the ordinary sibling for this dispatch | Database reviewer emits once; parent accepts once and joins losslessly | Included in the same bounded parent closeout |
| Metadata, thread, comment, or CI read without a whole-target verdict | No reviewer dispatch | Owning read lane | Requested narrow result |

Default ordinary review is judgment-first and comment-ready when it finds a
formal defect. The minimal comment section contains only one event, one compact
unanchored-finding list, one Summary literal, and finding ordinal, anchor, and
Body for each inline comment. It does not repeat target, finding, event, source,
admission, disposition, likelihood, or duplicate metadata. Preparing review
comments does not authorize GitHub mutation. The parent must not paste a
returned packet or literal body into commentary or later turns. Forward the exact canonical packet
once only when the user explicitly asks to receive the packet itself.

Resume is limited to semantic repair of already-returned content, a
provenance-bound scoped re-review, or a pull-based `REVIEW_PROGRESS:` request.
A finding-bearing default packet missing valid review comments is invalid and
returns once for consolidated packet repair; do not request a body-only
response or start a fresh whole-target review.

### One initial evidence snapshot

The parent owns one immutable dispatch snapshot with a collection timestamp,
repository and PR identity, title/body/author, base and head refs and SHAs,
existing reviews/comments/threads and resolution state, and head-pinned
CI/check metadata. Pass that same snapshot to the ordinary reviewer and required
database sibling.

A reviewer reuses the snapshot. It may fetch remote evidence only when a
mandatory field is absent, provenance or head binding is invalid, current
evidence proves a head/state mismatch, or one specifically named artifact is
required for packet completeness. It must name the trigger. The parent alone
refreshes live head, thread, duplicate, and CI state for final join or the
pre-write guard and performs post-write readback. Those later reads answer a
different freshness question and are not duplicate discovery.

### Comment and transport economy

Require review-comment bodies to omit evidence for facts already visible at the
anchor and reviewer-internal likelihood, frequency, or confidence narration.
Cite exact lines only when the claim is not visible at the anchor. Severity and
confidence remain reviewer-owned packet fields.

Reviewer-to-parent transport always crosses a session boundary and uses
pipe-prefixed UTF-8 literals. Validate Summary and Body literal blocks, UTF-8,
finding-ordinal partition, anchors, severity/event mapping, and comment
decorations once at packet acceptance; retain the accepted decoded bytes. Before publication,
repeat only mutable head, anchor, thread/duplicate, authorization, and
GitHub-capability checks. Any Body, Summary, event, anchor, or target change
invalidates acceptance. Authenticated identity never creates a transport bypass.

Publication must use a GitHub primitive proven to preserve the selected
`COMMENT` or `REQUEST_CHANGES` event, exact reviewer-owned summary and inline
body bytes, anchors, and reviewed head. Try another repo-sanctioned
authenticated primitive when the active surface cannot preserve that contract.
If none can, fail closed as `Pending Verification`. Never downgrade the event,
substitute standalone comments, invent summary prose, or restart the reviewer
only to obtain a body.

Report an actual economy violation in one concise closeout line. Include
measured avoidable invocations, tool calls, tokens, or elapsed time only when
available; never estimate cost or emit a new violation packet.

## Workflow

When the user supplies an exact existing checkout path, perform a local-only
preflight before Step 1 and before any GitHub call, fetch, clone, or worktree
creation. Inspect the checkout's repository identity, remotes, worktree state,
branch, head, and cleanliness. Resolve the repository from that evidence and
the explicit PR URL when present; if they disagree, stop with the mismatch
instead of defaulting to example-app. Reuse the checkout when it is clean
and can be pinned to the requested PR head and base. Do not choose another
local target unless this checkout is contaminated, belongs to a different
repository, cannot represent the target safely, or the user explicitly asks
for isolation.

1. Parse the PR URL or number. Use the repository resolved by the
   supplied-checkout preflight when present, and require any explicit PR URL to
   agree with it. Otherwise use the repository named by the URL. Default to
   `example-org/example-app` only when neither source identifies a
   repository.
2. The parent fetches one authoritative dispatch snapshot through the owning
   runtime GitHub workflow. Bind it to a collection timestamp and include
   repository and PR identity, title/body/author, base and head refs and SHAs,
   existing reviews/comments/threads and resolution state, and head-pinned
   CI/check metadata. Pass the same immutable snapshot to the ordinary reviewer
   and any required database sibling. Remote fetches are limited to PR metadata,
   comments/reviews/thread state, and CI/status data. Changed-file inventory,
   patches, and code contents must not be fetched through remote APIs; reviewers
   read them locally from the prepared worktree. Record the live head SHA as the
   single review target SHA for the whole packet and reuse it for every local
   file reference, thread mapping, and CI row.
   When CI or check state is part of the review, apply `references/ci-read.md`
   as a call separate from the PR metadata fetch above: fetch the PR head
   branch and SHA, list workflow runs for that branch, and verify each cited
   run's `head_sha` matches the recorded head SHA. Do not request
   `statusCheckRollup` in the metadata call's `gh pr view --json` field list and
   do not call the REST check-runs endpoint as a first attempt; both commonly
   return `403`/`Resource not accessible by personal access token` for this
   repo's token. Treat status rollups and check-run APIs as optional secondary
   reads, used only after the workflow-run path is missing required evidence.
   If re-fetched
   metadata later shows a different live head SHA, discard the old artifacts,
   record the new head SHA, refetch the reviewer-guide files and relevant
   comments at the new head, and restart inspection and variance-ledger mapping
   from that single consistent SHA. A mixed-SHA collection must not back a
   `PASS` or `PASS_WITH_FINDINGS` verdict.
3. Determine whether this is the user's PR:
   - Treat it as the user's PR when the PR author matches the authenticated
     GitHub login, or when the user explicitly says it is their PR.
   - Otherwise treat it as someone else's PR.
4. Fetch `origin/main`, the PR head, and the PR base metadata. If the PR base
   is not `main`, treat it as a stacked PR and state the stack base. Do not
   silently flatten a stacked review onto `origin/main`.
5. Prepare the worktree:
   - Before creating anything, run `git worktree list --porcelain` and apply
     the reuse gate from `worktree-readiness`.
   - Reuse a clean worktree when it is already on the live PR head branch, at
     `tmp/worktrees/pr-<number>`, or detached at the current PR head SHA.
   - For someone else's PR, create or reuse a short-lived review worktree named
     `tmp/worktrees/pr-<number>`.
   - For the user's PR, first look for an existing local worktree or branch for
     the real head branch. Reuse it when clean and at the expected head. If it
     does not exist, create a worktree using the real head-branch slug.
   - Keep review-only worktrees read-only. Do not edit code unless the user
     later asks for fixes.
   - If a matching review worktree exists but is dirty, block as contaminated
     instead of creating a duplicate.
6. Prepare current local review target:
   - For `main`-based PRs, the review target should be locally updated with
     current `origin/main` before full review:

     ```bash
     git -C <worktree> fetch origin main --prune
     scripts/dev/update-pr-review-worktree-with-main.sh <worktree>
     ```

   - If the PR is the user's PR and it is behind `origin/main`, rebase the
     local worktree branch only if safe and required by the worktree skill,
     then re-check the branch status. Do not push the rebased branch unless the
     user explicitly asks.
   - If the PR is not the user's PR and it is behind `origin/main`, do not block
     only because the remote PR branch is outdated. Run
     `scripts/dev/update-pr-review-worktree-with-main.sh <worktree>` after the
     canonical review worktree exists. The helper first tries a local rebase;
     if rebase conflicts, it aborts and creates a synthetic local review branch
     from `origin/main` with the PR's aggregate diff as one local commit. Review
     the helper-produced local target. Do not push or rewrite someone else's
     remote PR branch.
   - If the helper exits non-zero because the aggregate-diff fallback conflicts,
     return `BLOCKED` and cite the conflicted paths. Do not hand-resolve
     conflicts during review setup unless the user explicitly asks for conflict
     resolution.
   - When refreshing a review worktree for a local-only update, fetch the PR
     head and base through explicit refspecs or named refs. Do not reset or
     rebase from ambiguous `FETCH_HEAD` after fetching more than one ref,
     because the last fetched ref can become the wrong local target. Record the
     live PR head SHA, the fetched ref used to reset the worktree, the base SHA,
     and the helper-produced local SHA before inspecting code.
   - If the local review target SHA differs from the live PR head, every packet
     field must say which evidence came from the live PR head and which evidence
     came from the local review target. CI and review-thread state from GitHub
     remain live-head evidence; local file, diff, and line artifacts come from
     the helper-produced review target. Do not collapse those surfaces into a
     single "current head" claim.
   - For stacked PRs, check freshness against the live stack base, not
     `origin/main`, unless the base is `main`.
7. Run the `worktree-readiness` status checks in the chosen worktree. For
   review-only worktrees, do not install dependencies, bootstrap tools, run
   setup commands, or repair local environment gaps. For an ordinary
   "review this PR" request, keep the entire review static. Allowed evidence is
   local Git and file inspection, checked-in artifacts interpreted only within
   their own provenance and observation metadata, authenticated GitHub PR
   metadata, reviews, threads, and head-pinned CI metadata. Do not access live
   runtimes, Staging, Production, Cloud SQL, Mongo, logs, monitoring, Sentry,
   browsers, or other environment state, even read-only. Do not run tests,
   builds, linters, codegen, migrations, testcontainers, browser checks, smoke
   scripts, collectors, or any other validation or reproduction command.
   Record missing or stale current proof as claim-specific `Pending
   Verification`; it does not authorize collection and must block only the
   exact readiness claim that depends on it. A later live read requires a new,
   user-explicit validation or production-readiness phase and fresh
   classification. Any pending validation command must come from a repo-owned
   source such as `repo.md`, a package manifest, a Makefile, a CI workflow, or
   a relevant skill. Do not invent ad hoc commands, tool installs, linter
   versions, or bootstrap steps.
   Required Git preparation remains in scope: fetching explicit PR and base
   refs, creating or reusing the canonical review worktree, resetting it to the
   exact fetched head, and applying the workflow-required local refresh or
   rebase. Do not misclassify those mandatory setup actions as forbidden
   execution. The canonical worktree and required workflow metadata are the only
   review-generated local artifacts allowed. Do not create helper-output or
   evidence files in repository temporary storage, a system temporary
   directory, or another local path, and never persist fetched runtime,
   database, log, or monitoring output during ordinary review.
8. Dispatch under the **Native Reviewer Dispatch Gate (law)** below. Give each
   required reviewer the stable worktree, base, head SHA, and PR context. Each
   reviewer owns autonomous source discovery, scope, and verdict. The parent
   retains the dispatch inventory, target freshness, evidence-ceiling
   enforcement, required-return tracking, and final synthesis.

   **Native Reviewer Dispatch Gate (law)**

   When condition: ordinary PR review ("review this PR", PR URL/number) and
   the runtime exposes native reviewer subagents.

   Required action:

   Before dispatch, classify the reviewer session as fresh or reused under
   `reviewer-handoff`. A newly spawned subagent or newly started review tool is
   fresh even when it reviews fixes from an earlier pass. Give a fresh reviewer
   the neutral factual packet and exact target; do not label the call final or
   last, summarize earlier findings, prescribe focus files, or imply an expected
   verdict. Historical finding context belongs only to the same reused reviewer
   session. If provenance is uncertain, use the fresh-session contract.

   1. After the stable worktree, live head, and dispatch inventory exist, spawn
      the native reviewer immediately. No environment preflight belongs to an
      ordinary PR review.
      Deliver the separate `REVIEW_SCOPE_PROPOSAL` from
      `work-orchestration/references/review-control-plane.md`. Process
      that reviewer's acceptance or escalation without serializing database
      applicability or evidence preparation behind it. A scope-control message
      is not part of the strict PR verdict packet.
   2. Load the parent-owned
      `work-orchestration/references/database-review-applicability.md`
      contract and bind its complete tri-state packet to the exact target and
      review-handoff decision. `not required` needs an evidenced negative
      consequence trace; `Pending Verification` fails closed. This
      classification never delays or shapes the ordinary reviewer.
   3. When applicability is `required`, classify environment materiality only
      to identify claims whose current proof is absent. This classification is
      not live-access authority. Name Staging, Production, both, or neither
      from the review scope, deploy path, and runbook, with rationale.
   4. Build the database packet from checked-in source and artifacts plus exact
      evidence gaps. Treat snapshots only within their declared provenance,
      `observed_at`, `valid_until`, schema, semantics, collector hash, and
      limitations. Do not refresh them or route through
      `readonly-data-access` during ordinary PR review.
   5. Spawn `database-reviewer` immediately when required, including when
      current environment proof is missing or stale. Its packet must bind the
      target and base SHAs, static evidence ceiling, affected environments and
      rationale, checked-in artifacts and content digests, observation
      boundaries, omissions, unavailable fields, and claim-specific `Pending
      Verification`. This packet does not curate the reviewer's autonomous
      static source inventory, lanes, or checks.
      Deliver that sibling's own separate `REVIEW_SCOPE_PROPOSAL`. Keep shared
      depth distinct from database decision scope and final-packet `review
      mode`; never add scope-control fields to the database packet.
   6. Parent waits for every required reviewer. One return does not waive the
      other. Preserve disagreements and deduplicate only exact-overlap findings
      without weakening severity or provenance. Do not normalize a material
      contradiction by choosing the stricter verdict, majority, or role
      hierarchy; route the exact dispute through `conflict-resolution`.
      A return is not accepted by inspection or reviewer self-attestation.
      Transition its exact bytes through the `RETURNED -> VALIDATING ->
      ACCEPTED | REJECTED` lifecycle owned by `review-control-plane.md` and
      run `scripts/dev/validate-review-packet.rb` with the trusted target,
      review mode, and review-comments policy fixed in the dispatch.
      On the first rejection, send the same reviewer one consolidated
      `REVIEW_PACKET_REPAIR`; revalidate the complete corrected packet. A
      second malformed return takes the existing terminal-malformed or
      replacement path. The parent never reconstructs packet semantics.
      Only after every required packet is `ACCEPTED`, compute the lossless parent-only
      `JOIN_*` category from `review-control-plane.md`. Retain every original
      verdict, finding, caveat, target, confidence, and evidence gap. A missing,
      invalid, or unresolved scope result yields `JOIN_NEEDS_INPUT`; no join
      category authorizes publication, approval, or mutation.
      Successful native-reviewer dispatch activates the internal
      `REVIEW_ACTIVE` lifecycle state from `review-control-plane.md`. During
      that state, waiting and review control are the parent's critical path.
      Concurrent work is limited to target freshness, thread and CI inventory,
      database applicability and required evidence preparation, authorization
      state, and join/readback mechanics, with every action bounded by both
      purpose and effect to that control-plane output. The parent performs no
      whole, partial, supporting, spot-check, or relabelled semantic review. If
      no bounded control-plane action is needed, it waits.
      If reviewer status is needed after extended silence, request the
      pull-based `REVIEW_PROGRESS:` response from `review-control-plane.md`
      before asking about closeout. Do not request periodic updates, repeat an
      unchanged request, or turn the advisory time band into a deadline.
      Reviewer closeout depends only on closure and stop proof. Leaving
      `REVIEW_ACTIVE` requires the original reviewer's terminal or stop proof,
      or its explicit terminal blocked or malformed disposition plus the
      owning workflow's replacement authorization. Parent analysis never
      satisfies or waives a mandatory ordinary or database reviewer.
   7. Parent evidence, static inspection, token savings, or confidence are not
      reviewer waivers.
   8. Skip the ordinary reviewer only when its existing explicit user-opt-out or
      unavailable-runtime rule applies. A required database reviewer has no
      user-opt-out or unavailable-runtime waiver. Repair and retry a failed
      dispatch; if it still cannot return, block approval and handoff with the
      exact tooling gap as `Pending Verification`. Any target change
      invalidates target-dependent proof. The parent then updates the
      append-only ledger from `reviewer-handoff` and classifies the delta as
      validation/readback only, one-boundary targeted follow-up, or justified
      broad follow-up. Exact-SHA change alone does not require broad
      redispatch. A changed or expired checked-in artifact invalidates only
      claims that depended on it. Preserve the resulting `Pending Verification`
      without refreshing live state in the ordinary review phase.
   9. Review handoff is blocked until this gate is satisfied. If spawn fails for
      tooling or agent-slot reasons, repair and retry; if still blocked, report
      the tooling blocker under `Pending Verification` and stop.

   When a valid ordinary-reviewer skip applies under item 8, assume
   `.claude/agents/reviewer.md` directly in the parent context instead.
   Whichever context performs the review, apply `.claude/agents/reviewer.md`
   plus the selected `reviewer` lenses:
   - state the target, base, live head SHA, local review target SHA, scope,
     freshness/update result, and whether the helper used direct rebase,
     aggregate-diff fallback, or blocked on conflicts;
   - inspect the diff, surrounding callers, tests, generated files, workflow
     files, docs, review threads, and PR body drift as required by the reviewer
     instructions;
   - when the changed files include operator-facing docs, READMEs, or runbooks
     that carry command examples, flag invocations, or step procedures for a
     gated, mutating, or multi-mode runtime, cross-check each documented command
     against the contract the runtime enforces (required and rejected flags,
     prerequisite gates, accepted inputs, rejection paths). Verifying one doc
     claim does not clear the others; a separate command/example block can still
     contradict the runtime and is a real finding sized by operator impact. Do
     not emit a zero P2/P3 count while any changed doc command surface is
     unverified;
   - before citing any local `path:line@sha`, re-verify the exact range at the
     target head rather than recalling it from an earlier read, and for
     doc/runbook artifacts cite the exact command or example block that proves
     the claim instead of adjacent prose;
   - after the review worktree exists and is verified at the target head, the
     local checkout is the source of truth for changed-file inventory, patches,
     and file contents. Use `git diff <base>...HEAD`,
     `git diff --name-only <base>...HEAD`, `git show`, `sed`, `rg`, or local
     file reads in that worktree. Do not call MCP/API `get_files`, `get_diff`,
     or remote file-content tools for code or diff content that is already
     present locally; those calls waste budget, can hit output limits, and can
     silently mix sources. Use remote GitHub tools after worktree setup only for
     PR metadata, comments, reviews, status/check data, missing thread state, or
     a narrow count/SHA cross-check that cannot be answered locally;
   - include `reviewer`'s three mandatory phase references in the native
     reviewer handoff. Parent PR orchestration may prepare head, worktree,
     metadata, comments, CI inventory, and changed-file inventory before
     dispatch, but the reviewer session must load
     `references/review-bootstrap.md` before its own evidence collection. After
     bootstrap, it loads `references/review-analysis-routing.md`, confirms the
     stable target and bounded inventory, and uses that phase's canonical
     mandatory matrix and routing rules to select lenses. Before verdict, it
     loads `references/review-verdict-closeout.md`, which owns the single
     `references/review-closeout-lens.md` execution and packet handoff. Do not
     duplicate a mandatory lens list here. Missing optional lens coverage uses
     the runtime role fallback and `Pending Verification`; a missing mandatory
     phase blocks substantive verdict emission in a lazy-loading runtime;
   - when open or closed review comments exist, run the Prior-Comment
     Adversarial Pass (pr-stack lens): challenge validity and author fixes with
     current-code artifacts for open and closed threads; multi-reviewer comments
     raise the depth bar (last-reviewer posture). Then, before final verdict
     collapse, run the Independent Residual Pass owned by `reviewer` when
     FULL/COUNCIL, production blast radius, fetched prior threads, or
     migration/data/auth/public-API surfaces apply: re-review as if material
     still-valid prior concerns were fixed, then file new findings or empty
     proof with named probes. Confirming open threads alone is not residual
     search;
   - after residual review, enter `review-verdict-closeout.md`. It applies the
     canonical closeout lens once, performs the selected-lens and soft-pedal
     audits, checks next-consumer acceptance, and routes GitHub serialization
     directly to `docs/agents/pr-review-packet-format.md`;
   - when checking workflow runs for CI evidence, note that `gh run list` is not
     head-pinned. Each run must be checked via run details, such as
     `actions/runs/<run-id>` with `gh api` or helper, to confirm that its
     `head_sha` matches the target head SHA before adding the run to the packet;
   - treat old comments, Copilot, Claude, Clawpatch, and other agent output as
     leads until verified against the current worktree;
   - enumerate every fetched prior comment, review object, review thread, and CI
     artifact in the variance ledger. Do not write `Variance ledger: N/A` after
     fetching any prior artifact;
   - when inline review comments are fetched without their review-thread
     resolved/outdated state, fetch that thread-state surface before closeout or
     list the exact missing surface under `Pending Verification`. Do not guess
     `is_resolved` or `is_outdated` and do not imply complete thread coverage
     while the state is unknown.
9. If the user explicitly asks to add review comments:
   - immediately before drafting or posting, recheck the live head, each
     proposed comment location, and any caller, route, config, linked PR, or
     dependency fact that controls whether the finding is reachable;
   - discard, downgrade, or rewrite candidates invalidated by that readback;
   - prepare concise GitHub-facing Conventional Comments anchored to exact
     current file lines;
   - post only comments that survive the reviewer finding filter or the
     inline-advisory candidate standard;
   - never auto-resolve human review threads;
   - avoid local paths, agent internals, and unverified claims in GitHub text;
   - after submission, re-read the stored review object and inline comment or
     thread surfaces. Confirm the event, reviewed commit, comment bodies, and
     anchors match the intended review. A successful mutation response without
     this readback is `Pending Verification`, not publication proof.
10. Re-read the reviewer role and
    `docs/agents/pr-review-packet-format.md`, then close with the canonical
    reviewer packet unless the user explicitly asked for a narrower non-verdict
    shape. Include worktree and target freshness, commands, validation gaps,
    findings, current threads and CI, selected lenses, variance, and comment
    posting state. Before sending:
    - satisfy the Native Reviewer Dispatch Gate or record the blocker
    - run the packet-format document's full Pre-Emit Checklist
    - retain the minimal local skeleton: `Verdict:` first; top-level
      `Plain-language summary:`, `Selected reviewer lenses:`, and `Not loaded:`;
      `Packet ends.` final
    - preserve semantic verdict law for severity, confidence, target freshness,
      evidence, lens coverage, central blocking gaps, REH triggers, current
      threads and CI, and `Next owner`
    - keep central execution gaps under `Pending Verification` and `REH-n`
      without inventing a P2/P3 finding
    - repair an invalid packet in the same reviewer session when possible rather
      than replacing it with prose
    The packet-format document alone owns exact field order, detailed finding
    blocks, CI/variance/REH row layout, copied-value and source-tag checks,
    column-one rules, fences, and terminator mechanics.

## Worktree Commands

For someone else's `main`-based PR review worktree:

```bash
git fetch origin main pull/<number>/head:refs/remotes/origin/pr-<number>-head --prune
git worktree list --porcelain
git worktree add -B pr-<number> tmp/worktrees/pr-<number> \
  refs/remotes/origin/pr-<number>-head
scripts/dev/update-pr-review-worktree-with-main.sh tmp/worktrees/pr-<number>
```

Run `git worktree add` only when the reuse gate found no clean matching
worktree. If the helper fails with aggregate-diff conflicts, block the review
and cite the conflicted paths.

For the user's PR when no clean local worktree exists:

```bash
git fetch origin main <head-branch> --prune
git worktree add -B <head-branch> tmp/worktrees/<head-branch-slug> \
  origin/<head-branch>
git -C tmp/worktrees/<head-branch-slug> merge-base --is-ancestor origin/main HEAD || \
  git -C tmp/worktrees/<head-branch-slug> rebase origin/main
```

After a rebase, rerun status and freshness checks. Do not push unless asked.

## Comment Policy

Default to a parent-facing canonical review packet. GitHub writes happen only
when the user explicitly asks to add, post, submit, or leave PR review comments.

When posting comments, use the authenticated GitHub operation from
`github-workflow` `references/pr-operations.md` or the `github-workflow` `references/gh-auth-session.md` fallback. Prefer a pending
review when multiple inline findings will be submitted together. Do not submit
nit-only comments.

`docs/agents/pr-comment-conventions.md` is the single canonical owner of the
wording and shape of every posted comment and reply. Apply it to reviewer inline
comments, reviewer replies, author replies, and the review-summary body, not
only to API mechanics. Do not restate its rules here and do not paste them into
a reviewer dispatch prompt: the reviewer reads that file directly through its
own packet-format read order, and its mechanical subset is enforced as
`RPPA-011` at packet acceptance.

### Finding-To-Comment Fidelity Gate

The reviewer owns the canonical finding and, when formal findings exist, the
exact same-response review-comment Body, selected review event, and Summary.
The reviewer drafts from its finding block and returns those values inside the
mandatory packet using the minimal parser-safe transport in
`docs/agents/pr-review-packet-format.md`. It must not ask the parent to infer,
rewrite, or shorten the diagnosis or invent summary prose.
Every published formal `P0` through `P3` finding preserves these semantics:

- `Problem` -> **What happens:** the violated invariant and reachable failure
  mechanism;
- `Impact` -> **Why it matters:** the concrete user, system, data, operator, or
  maintenance consequence;
- the strongest current `Evidence` -> **Evidence:** enough repo-relative proof
  for the author to trace why the claim is true;
- the correction direction in `Fix shape` -> **Suggested fix:** the required
  behavioral outcome and ownership surface; and
- the post-fix proof in `Fix shape` -> **How to verify:** the focused check that
  would prove the defect is removed.

Use the finding title as the Conventional Comment subject. `HIGH` confidence
may remain implicit. A `MEDIUM` or `LOW` finding must retain a human-readable
uncertainty qualifier or name the missing proof; publication must not increase
certainty. Remove packet-only fields, `artifact:` markers, commit SHAs, local
paths, and workflow narration, while retaining useful repo-relative symbols and
locators. Inline advisories are outside the default review-comments contract
and do not become formal findings merely to obtain an inline body.

Conditionality and frequency are separate decisions. When a finding materially
depends on contention, concurrency, load, rollout order, environment, timing,
external state, or an error path:

- name the trigger or prerequisite and whether the consequence is deterministic
  once that condition holds; and
- describe frequency only as measured with cited evidence or `Unquantified`.

Do not describe a reachable defect as `rare`, `likely`, or `unlikely` without
metrics, logs, or another exact source for that frequency claim. Severity
describes impact, not occurrence rate; likelihood wording must neither weaken a
valid severity nor amplify an unmeasured concern. An unconditional deterministic
finding may omit likelihood prose when it would add no useful author context.

Every formal finding ordinal appears exactly once as an inline Comment or under
`Unanchored findings`. Do not fabricate an anchor. Any P0/P1 selects
`REQUEST_CHANGES`, including an unanchored finding; a P2/P3-only set selects
`COMMENT`. Inline decorations match severity.

At packet acceptance, the parent parses pipe-prefixed literal blocks and
mechanically verifies inline Body and Summary UTF-8, finding coverage, anchor
JSON, event, and decoration. It retains those accepted decoded bytes. Before mutation it repeats only
mutable live-head, anchor, thread/duplicate, authorization, and publication-
capability checks; it does not rebuild literal-block verification. It does not
reread code, callers, or tests to judge wording; rewrite bodies; alter severity
or confidence; or invent a replacement comment or summary. Missing mechanism,
impact, proof, required outcome, verification, confidence qualifier, or any
semantic ambiguity returns to the same reviewer. Stale mutable state, invalid
transport, or an event-incompatible publication surface fails closed before
mutation. The parent publishes only accepted Summary and Body bytes unchanged
and performs authenticated readback.

Outcome-based guidance is the default. Do not add an exact code suggestion
unless the current source was rechecked and the edit is local, mechanical,
complete, aligned with one authoritative same-class convention, and does not
choose among materially different safe designs. Concurrency, lifecycle,
cross-layer, test-synchronization, and ownership decisions normally require an
outcome and proof rather than a speculative patch.

The default decoded public shape for formal findings, its labeled parts, the
combine-labels rule, and the forbidden-content list are owned by
`docs/agents/pr-comment-conventions.md`. The reviewer reads that file directly
and drafts from it. This lane keeps the semantic mapping above, which is what
each labeled part must carry from the finding block; it does not restate the
template.

## Blockers

Return `BLOCKED` rather than reviewing when:

- the helper cannot produce an updated local review target because both rebase
  and aggregate-diff fallback conflict;
- a stacked PR's real base cannot be verified;
- the worktree has unrelated dirty changes that would contaminate the review;
- the PR head changed while the review was in progress and the target cannot be
  refreshed safely;
- GitHub auth cannot read the PR metadata or changed files.
