<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-09 (structured titled finding block examples) -->

# AGY Violation Examples

Use these examples when auditing Antigravity output before handoff. They show
the shape of known failures and the expected correction. They are not templates
for final responses; they are guardrails for rework.

## Wrong PR Review Routing

Actual:

> I loaded `pr-bugfix-review-repro` for a plain "review this PR" request.

Why this fails:

- The user asked for ordinary review, not bug-fix reproduction.
- The wrong first skill can produce the wrong worktree, role, packet, and
  validation boundary.

Expected:

> For a plain "review this PR" request, load
> `.agents/skills/pr-workflow/SKILL.md` first, then its review-worktree
> lane. Use specialized PR lanes only when the user explicitly asks for that
> specialized workflow.

## Treating Injected Context As File Read

Actual:

> `AGENTS.md` and `GEMINI.md` were read as part of system-provided rules
> injected directly into the conversation context. `repo.md` and the plugin
> rules were not read via tool calls.

Why this fails:

- The repo bootstrap requires current-session file reads when files exist in
  the checkout.
- Injected context, summaries, copied excerpts, memory, and prior conversation
  text can be stale, partial, or missing task-specific routing.
- Saying a file was read when no file-read tool call happened is false
  provenance.

Expected:

> Required bootstrap files read in this session:
>
> - `AGENTS.md`
> - `GEMINI.md`
> - `repo.md`
> - `.agents/skills/antigravity-operating-contract/SKILL.md`
> - `.agents/plugins/example-app/rules/example-app.md`
>
> Pending Verification: none for bootstrap file reads.

## Unrequested Validation During Review

Actual:

> I will run `go test ./...` to validate the PR review.
>
> I will run `go version` to check compatibility.
>
> I will run `git diff --check` to check cleanliness.

Why this fails:

- Ordinary PR review is read-only unless validation is explicitly requested.
- Review worktrees do not currently have the tools, packages, containers, or
  local setup needed for live validation Today.
- Passing an unauthorized command still violates the review boundary.
- Toolchain checks, subset tests, broad tests, linters, codegen, Docker,
  testcontainers, package-manager commands, `git diff --check`, and setup
  checks are all validation or environment probes.

Expected:

> Local validation: `Pending Verification`. This review inspected code and
> Git/GitHub metadata only because the user requested review, not validation.

## Trigger Word Without Immediate Proof

Actual:

> The CI checks are green and the branch is fresh.

Why this fails:

- `green` and `fresh` are parser-trigger words.
- Neither claim provides immediate `source:` or `artifact:` proof.

Expected:

> CI status: green (source: GitHub Actions workflow `<workflow-name>`, run
> `<run-id>`, conclusion `<conclusion>`, head SHA `<sha>`).
>
> Branch freshness: fresh (artifact: `git merge-base --is-ancestor <base-ref>
> HEAD` exited 0 in `<worktree-slug>`, base `<base-sha>`, head `<head-sha>`).

## Counted P Finding Without Detailed Finding Block

Actual:

> P2/P3 findings: 1 (P3 rollout evidence gap for new path)
> ...
> Plain-language summary:
> ...
> Selected reviewer lenses:
> ...

Why this fails:

- The header declared a positive P count.
- The packet-format contract and reviewer role require a corresponding top-level "Finding P3: <short title>" (or P2 etc.) block with the required structured fields (Severity, Confidence, Category, Location, Problem, Impact, Evidence, Fix shape) immediately after the header.
- Summarizing the finding only in the header line, Pending Verification, or plain-language summary violates the "detailed findings follow the packet" rule and the pre-emit checklist.

Expected (fenced for list hygiene):

```text
P2/P3 findings: 1 (P3 rollout evidence gap...)
(header continues)

Finding P3: rollout evidence gap
- Severity: P3
- Confidence: MEDIUM
- Category: rollout / operator verification gap for data-integrity migration gate
- Location: ...
- Problem: ...
- Impact: ...
- Evidence:
  - ...
- Fix shape: ...

(then Variance ledger, Residual risk if any, Plain-language summary, Selected reviewer lenses, Packet ends.)
```

## Central Execution Gap Filed as Formal P3

Actual:

> P2/P3 findings: 1 (P3: pending staging execution of the new job mode)
> ...
> (no REH-n block, P0/P1 line not qualified, gap treated as ordinary finding)

Why this fails:

- Central blocking execution or rollout gaps for database-mutating / data-integrity / import / migration-gate paths must produce P2/P3 findings: 0.
- They live exclusively under Pending Verification + (if P1) a properly formed REH-n block.
- The P0/P1 line must be qualified (e.g. "0 code findings; 1 P1 REH gate").
- Filing them as a counted P3 (or P2) in the header count is a packet defect per the reviewer core and packet-format rules.

Expected (fenced for list hygiene):

```text
P0/P1 findings: 0 code findings; 1 P1 REH gate
P2/P3 findings: 0
...
Pending Verification: central execution gap for validate-mode canary at head H (staging capped logs for the reviewed mode, run status, cap values, ...); no production execution permitted
Risk Evidence Handoff:
REH-1:
- Severity: P1
- ...

(gap documented only in PV + REH; not in the P findings count)
```

## Variance Ledger Uses Summary Language Instead of Exhaustive Enumeration

Actual:

> Variance ledger: several prior review threads were inspected (IDs like PRRT_...); most were addressed or outdated; additional review objects may exist.

Why this fails:

- Summary phrases ("several", "like", "most", "additional may exist", "largely") are forbidden.
- The ledger must enumerate every fetched artifact individually.
- Each mapped inline thread must carry ID, reviewer/author,
  `is_resolved=<true|false>` and `is_outdated=<true|false>` when those values
  were actually fetched, current-code artifact, and disposition.
- If a category is not fully enumerated, state that limitation under `Pending
  Verification`; do not guess thread state values.

Expected:

> - comment_id=<comment-id>, reviewer=<reviewer>, is_resolved=false,
>   is_outdated=false, current-code artifact=<path>:<line>@<head-sha>,
>   disposition=concern_remains_open artifact: get_review_comments +
>   get_file_contents at <head-sha>.
>
> (Repeat for every individual artifact. For unenumerated review objects: "Full set of review objects from get_reviews: Pending Verification (only threads were exhaustively mapped).")

## Missing artifact on Verdict Line and Loose Proof Attachment

Actual:

> Verdict: PASS_WITH_FINDINGS
>
> A Warn is emitted when the cap is active.

Why this fails:

- The verdict line must carry `artifact:` when the format permits.
- Claims such as "A Warn is emitted" or "X serves as the signal" require the `artifact:` or `source:` tag attached directly to that sentence (not only in a later Evidence block).

Expected:

> Verdict: PASS_WITH_FINDINGS artifact: variance ledger (0 P0/P1) + P2 below + inspected files at <head-sha> via get_file_contents.
>
> A Warn is emitted artifact: backend/.../file.go:48 (the if !cap block containing the exact log text and structured fields) from get_file_contents at <head-sha>.

## Broad Self-Certification Sentence

Actual:

> This is the best version so far and mostly conforms. Everything else is now in the right shape.

Why this fails:

- Broad self-certification sentences at the end of the packet or any section are forbidden.
- They are a form of claiming overall compliance without per-claim proof.

Expected:

> (Omit the sentence entirely. End the packet with the required proof block or "Packet ends." Every material claim already carries its own inline artifact.)

## Promoting Low-Value P3 Nit to Formal Findings + Inconsistent Scope/PV Claims

Actual:

> P2/P3 findings: 1 P2, 1 P3 (unnecessary abstraction in helper)
> ...
> Coverage: ... operator README surface was reviewed ...
> Pending Verification: full README.md content at head (not fetched).

Why this fails:

- P3 nits (naming, minor abstraction) must not be counted in P2/P3 findings or detailed findings. Prefer silence or variance-ledger-only.
- Scope claims must be consistent with PV items. Claiming a surface was reviewed while marking its full content PV is inconsistent.

Expected:

> P2/P3 findings: 1 P2 (only)
> (The nit appears only inside the relevant variance ledger entry for the prior thread.)
> Coverage: ... (do not claim the README surface).
> Pending Verification: full README.md content at current head.

## Loose State Description in Variance Ledger

Actual:

> PRRT_xxx (reviewer): mixed is_resolved/is_outdated per thread metadata.

Why this fails:

- "mixed" is summary language.
- State must be written explicitly as `is_resolved=<true|false>` and
  `is_outdated=<true|false>` only when exact booleans were retrieved. If they
  were not retrieved, omit those fields and use `disposition=pending_verification`.

Expected:

> comment_id=<comment-id>, reviewer=<reviewer>,
> disposition=pending_verification artifact: get_review_comments extraction did
> not include exact thread state for this row.

## Claim of "Mitigation" or Control Without Immediate Artifact

Actual:

> The existing Warn serves as the current mitigation.

Why this fails:

- "mitigation" (or "serves as the signal/control") is a trigger-style claim about a safeguard.
- The proof must be attached directly to the sentence.

Expected:

> The existing Warn serves as the current operator signal for this case artifact: backend/.../ledgeraudit.go:48 (the if block and exact log text) from get_file_contents at <head-sha>.

## Mixed Review Target SHAs in One Packet

Actual:

> Code and threads inspected at commit `<old-sha>`. CI and latest head claims
> use `<new-sha>`. Verdict: PASS (CI green at `<new-sha>`).

Why this fails:

- All code content, current-code mappings in the variance ledger, and CI/status
  artifacts must come from one single live head SHA for the packet.
- Mixing SHAs (even when both are on the branch) makes the target inconsistent. The packet cannot claim PASS or PASS_WITH_FINDINGS.

Expected:

> Live head SHA established from metadata at start of collection: `<head-sha>`.
> All file fetches used `ref=<head-sha>`. All CI rows report
> `headSha=<head-sha>`. All current-code artifacts use `@<head-sha>`. If
> metadata later shows a new head, collection restarts at the new SHA before
> any `PASS` claim.

## Inconsistent Verdict + Zero Findings + Central PV + N/A Residual + Next owner: none

Actual:

> Verdict: PASS_WITH_FINDINGS
> P2/P3 findings: 0
> Pending Verification: head drift between file content and CI; runner finalization not fully mapped; thread pagination incomplete.
> Residual risk: N/A
> Next owner: none

Why this fails:

- PASS_WITH_FINDINGS with zero P findings, N/A residual, and none owner while central gaps are listed in PV is a direct contradiction of the Verdict Consistency Truth Table.
- Central gaps (stale target, incomplete evidence for risky data-mutating paths) require either a P3 finding (PASS_WITH_FINDINGS), BLOCKED, or explicit owner routing. They cannot be hidden behind N/A while claiming PASS posture.

Expected:

> Verdict: PASS artifact: single-head collection at `<head-sha>` + 0 material
> findings after inspection + all fetched threads mapped in individual variance
> ledger rows + CI success at identical `headSha`.
> (Or, if gaps remain central: Verdict: PASS_WITH_FINDINGS, P2/P3 findings: 1
> P3 (stale review target / incomplete thread state for data mutation path),
> Pending Verification: ... (non-central only), Residual risk: (brief
> description or omitted), Next owner: parent.)

## Variance Ledger Uses N/A or Grouped Rows for Summary/Informational Artifacts (or Summary Language After "Enumerated Below" Claim)

Actual:

> Variance ledger: enumerated below
> ...
> 10. multiple author self-review objects (IDs: 43137..., 44808...) ... current-code artifact omitted, disposition=out_of_scope
> (or: additional lower-signal Copilot summaries follow the same pattern)

Why this fails:

- After any claim that the ledger "enumerates" the fetched artifacts, every object must receive its own individually numbered row (no ranges, no "multiple ... objects", no "additional follow the same").
- Low-signal or empty-body review summaries still get individual rows using only review_id, reviewer, submittedAt, commit, and disposition=out_of_scope (current-code artifact is omitted for these).
- If any fetched objects are not listed individually, the exact limitation (count, category, or list of IDs) must be stated in Pending Verification; the ledger itself must not use grouping or summary language.

Expected:

> Variance ledger: enumerated below
> ...
> 10. review_id=4313733303, reviewer=author, submittedAt=..., commit=..., current-code artifact omitted (self-acknowledgment of fix only), disposition=out_of_scope
> 11. review_id=4480817853, reviewer=author, submittedAt=..., commit=..., current-code artifact omitted (self-acknowledgment of fix only), disposition=out_of_scope
> (One row per object. If some low-signal author self-reviews were intentionally not expanded for packet length, the Pending Verification item says exactly: "get_reviews returned 12 additional low-signal author self-review objects not expanded as individual rows here; all were non-actionable self-acknowledgments; full list under this PV entry.")
> (No "multiple" or "additional follow the same" after the enumeration claim.)

## Narrative Operator Status and Overstated Completeness

Actual:

> Operator status: complete for reviewer scope. The rollout path is documented and safe.

Why this fails:

- Operator status (when included) must cite exact PR body section names, exact runbook/README lines/fields, or exact tool results with parameters.
- "complete" is a trigger word that requires immediate artifact proof. Narrative claims of completeness for rollout when only static review was performed are disallowed.

Expected:

> Operator status: PR body `<section-name>` section; `<runbook-path>:<start>-<end>@<head-sha>`
> (operator loop description and example commands).

## Over-Calibrated Confidence Without Scope Proof

Actual:

> Confidence: HIGH (CI green + static review)

Why this fails:

- The artifact for Confidence must prove what the session actually executed for code/inspection scope.
- CI success + static review is typically MEDIUM when no local validation commands were run (per read-only ordinary review constraints). HIGH requires stronger executed proof of the risky surfaces.

Expected:

> Confidence: MEDIUM artifact: gh api contents at `ref=<head-sha>` for
> reviewer-guide files + gh api `/pulls/<pr-number>/comments` + gh run list
> filtered to `headSha=<head-sha>`; read-only session, no local test execution.

## Proof Label Does Not Prove The Claim

Actual:

> CI runs were verified (source: PR review comments fetch).

Why this fails:

- PR comments do not prove CI state.
- The `source:` label is adjacent but not proving.

Expected:

> CI runs were inspected (source: GitHub Actions workflow-run list showing
> `<workflow-name>`, run `<run-id>`, status `<status>`, conclusion
> `<conclusion>`, head SHA `<sha>`).

## Variance Ledger Without Comment IDs

Actual:

> Variance ledger:
>
> - Copilot comment 1 (error message accuracy): incorporated source:
>   `backend/internal/content/datasource.go:L255`
> - Copilot comment 2 (array alignment): incorporated source:
>   `backend/internal/shared/sql/queries/content.sql:L102-L110`

Why this fails:

- The current-code file line can show the present implementation.
- It does not identify which Copilot comment, review comment, or thread was
  incorporated.
- Downstream checks and parent reviewers need a stable historical identifier to
  tie the variance ledger to the fetched PR comments.

Expected:

> Variance ledger:
>
> - Copilot thread `discussion_r<id>` / review comment `<id>`: incorporated
>   (source: PR review thread/comment ID from fetched PR comments; artifact:
>   `backend/internal/content/datasource.go:L255` shows the current-code
>   mapping).
> - Copilot thread `discussion_r<id>` / review comment `<id>`: incorporated
>   (source: PR review thread/comment ID from fetched PR comments; artifact:
>   `backend/internal/shared/sql/queries/content.sql:L102-L110` shows the
>   current-code mapping).

## Overstating Static Inspection

Actual:

> Integration tests passed because the test file covers rollback.

Why this fails:

- Reading a test file proves only that source exists.
- It does not prove the test compiled or ran.

Expected:

> Test source inspected: rollback coverage exists in
> `backend/internal/content/datasource_test.go` (artifact: repo-relative file
> and line reference). Local test execution: `Pending Verification`.

## Invalid Pending Verification Summary

Actual:

> Pending Verification: N/A
>
> Would flip verdict if local database tests fail.

Why this fails:

- The body names an unresolved local validation gap.
- `Pending Verification: N/A` is false.

Expected:

> Pending Verification:
>
> - Local database test execution.
> - Postgres-version behavior for the changed query, if relevant to the PR.

## Overconfident Review Confidence

Actual:

> Confidence: HIGH
>
> Local validation was not run.

Why this fails:

- Static review plus remote CI alone does not justify `HIGH` when local
  validation or generated artifacts are central proof.

Expected:

> Confidence: MEDIUM-HIGH. Static code inspection and remote CI metadata were
> inspected; local validation remains `Pending Verification`.

## Actionable Finding Buried As Residual Risk

Actual:

> Verdict: PASS
>
> P2/P3 findings: 0
>
> Residual risk:
>
> - Context cancellation during rollback can leave SQL and Mongo out of sync.
>   Using `context.WithoutCancel(ctx)` for rollback would make it more
>   resilient.

Why this fails:

- The review identifies a reachable data-integrity failure path.
- The review recommends a concrete code change.
- That is a finding, not residual risk.
- `PASS` and `P2/P3 findings: 0` contradict the body.

Expected:

> Verdict: PASS_WITH_FINDINGS
>
> P2/P3 findings: 1
>
> [P3] Rollback uses cancelable request context
>
> If the request context is canceled before rollback, the rollback delete can
> fail before reaching the database (source: current-code line that passes
> `ctx` to rollback; artifact: current-code line that calls the delete with
> that context). Use a detached short-lived rollback context or otherwise prove
> why the failure path is unreachable.

## Unsupported Probability Or Mitigation Claim

Actual:

> The concurrency race is extremely rare and mitigated by the user completion
> flow (source: caller line).

Why this fails:

- A caller line does not prove operational frequency.
- "Extremely rare" needs metrics, logs, an explicit product contract,
  unreachable-path proof, or documented owner acceptance.
- "Mitigated" needs proof that the mitigation materially reduces the risk.

Expected:

> Concurrent duplicate completion requests remain possible. Frequency and
> mitigation are `Pending Verification` unless supported by production metrics,
> product contract, unreachable-path proof, or documented owner acceptance.

## Self-Audit As Defense

Actual:

> I had one minor formatting issue. All other instructions were followed.

Why this fails:

- The audit hides material workflow and proof-contract violations.
- "All other instructions were followed" is unsupported self-certification.

Expected:

> Material violations:
>
> - Loaded the wrong PR workflow first.
> - Used trigger words without immediate proof.
> - Claimed `Pending Verification: N/A` while validation gaps remained.
>
> Additional violations are `Pending Verification` until the prior response and
> loaded instructions are inspected.

## Incomplete Variance Ledger

Actual:

> Variance ledger:
>
> - Copilot and prior reviewer feedback incorporated (source: backend/...:L123)

Why this fails:

- "such as", "IDs like", or summary language does not give downstream parsers a stable identifier.
- Every fetched prior artifact (Copilot review, human review thread, previous agent review) must be listed with its concrete GitHub thread/comment/review ID, reviewer, current is_resolved/is_outdated state, and the exact current-code file:line artifact that maps to it.
- Disposition (verified/rejected/stale/duplicated/PV) must be stated per item.

Expected:

> Variance ledger (thread inventory from the GitHub PR review-comment reader):
>
> - <thread-id> (<reviewer>, is_resolved=<bool>, is_outdated=<bool>, path: <repo-relative-path>:<line>): <reviewer concern>. Current-code artifact: <file-content or worktree artifact at head ref> shows <current state>. Disposition: <still open | stale | rejected | superseded | Pending Verification>.
> - <review-id> (<reviewer>, state=<state>): <review summary>. Current-code artifact: <artifact>. Disposition: <disposition>.

## Contradictory Next Owner With Open Findings

Actual:

> P2/P3 findings: 1
> ...
> Next owner: <domain owner> / PR author
> ...
> Next owner: none

Why this fails:

- Packet-level "Next owner" must be consistent with any P0/P1/P2 findings.
- If findings exist, the field must name the owner of the findings (or parent). "none" contradicts an active P finding.

Expected:

> In the top packet:
> Next owner: <domain owner> / PR author (for the P2 finding below)
>
> In the P2 section: Next owner for this finding: <domain owner> / PR author (thread <thread-id>).

## Broad Self-Certification At Closeout

Actual:

> All material claims above cite either a GitHub API result ... or exact repo-relative path...

Why this fails:

- It is a broad, un-auditable claim that attempts to certify the whole response.
- Parsers and downstream systems treat such sentences as noise or false assurance.
- Every material claim must carry its own immediate `source:` or `artifact:` inline. No summary self-cert paragraph is allowed at the end of the packet or section.

Expected:

> (No such paragraph. The per-claim `artifact:` and `source:` tags throughout the packet and variance ledger serve as the proof.)

## Loose Trigger Words In Packet Narrative

Actual:

> The get_status result contained state value "success" ...
> Review packet complete.
> ... feedback was addressed ...

Why this fails:

- Even in narrative around the required packet block, the words `success`, `complete`, `addressed`, `PASS_WITH_FINDINGS` (when used outside the mandated block), etc. trigger parsers if not immediately followed by `source:` or `artifact:`.
- "Packet ends." or "Review packet ends here." is the preferred closeout.

Expected:

> The GitHub status result for head <sha> contained state value "success" artifact: GitHub PR status reader result for <owner>/<repo>#<number> at <sha>.
> Packet ends.
> ... code change present per file-content reader at ref <sha> for <repo-relative-path>:<line>; thread state remains is_resolved=false.

## PASS Verdict While Operator Or P Gaps Remain Unowned

Actual:

> Verdict: PASS
>
> P2/P3 findings: 0
>
> Residual risk: first uncapped production run not yet observed.
>
> Next owner: none

Why this fails:

- Operator or rollout gaps that matter to the change must be a P3 (or P2 when
  material), `Pending Verification`, or an explicit `Operator status` line with
  `Next owner: parent`.
- `Next owner: none` contradicts open operator-scope risk.
- `PASS` with substantial residual operator risk needs `PASS_WITH_FINDINGS` or
  owned `Pending Verification`.

Expected:

> Verdict: PASS_WITH_FINDINGS artifact: static inspection at <head-sha>; one P3
> operator-scope gap; no P0/P1/P2 code defects evidenced
>
> P2/P3 findings: 1 — P3 operator first-run evidence missing
>
> Operator status: incomplete artifact: rollout evidence for flagged mode not
> present in PR body operator tables
>
> Next owner: parent artifact: P3 operator first-run risk

## Vague CI Claim Without Per-Run Artifacts

Actual:

> Strongest proof checked: workflow runs for head SHA all success
>
> (Later:) Checks API returned 403.

Why this fails:

- Summary CI language hides the required per-workflow `run_id`, `head_sha`, and
  `source`.
- The packet header line must not claim CI state without those artifacts on the
  same row or section.

Expected:

> CI state:
>
> - Backend - Validate artifact: run_id=<id>, conclusion=success artifact:
>   status=completed, head_sha=<sha>, source=gh api
>   actions/runs?head_sha=<sha>
>
> Checks API read artifact: HTTP 403; workflow-run fallback used per
> pr-ci-read.

## English Disposition Tokens With Parser Trigger Substrings

Actual:

> disposition=verified_fixed_test_added

Why this fails:

- Naive parsers may scan `verified` or `fixed` inside disposition values.
- Disposition must use machine-safe tokens from the packet-format reference.

Expected:

> disposition=code_changed_with_artifact

## Text After Packet Ends

Actual:

> Packet ends.
>
> I would accept this for merge from a code-review standpoint.
>
> Plain-language summary: the PR is blocked only on staging evidence.
>
> Sources: prior memory and local notes.

Why this fails:

- `Packet ends.` must be the final line in parser-facing output.
- Merge posture belongs in the verdict, findings, and packet-contained
  `Plain-language summary:`, not a post-packet recommendation.
- Human-readable summaries after the terminator break the parser contract even
  when their content is accurate.
- Source lists, memory citations, validation footers, and runtime-required
  closeout notes also break the parser contract when emitted after the
  terminator.

Expected:

> Packet ends.

(No lines after it.)

## Missing Or Misplaced Plain-Language Summary

Actual:

```text
Selected reviewer lenses:
- backend-go: changed mutation-capable job paths

Not loaded:
- frontend-ui: no app changes

Packet ends.
Plain-language summary: the PR is blocked only on staging evidence.
```

Why this fails:

- Parser-facing packets require a top-level `Plain-language summary:` section
  inside the packet.
- The section must appear before `Selected reviewer lenses:` and before
  `Packet ends.`
- It must not introduce a new verdict, new evidence, merge advice, or follow-up
  work not already represented by packet fields.

Expected:

```text
Plain-language summary:
- Static review found no code defect, but staging execution evidence remains open under REH-1.

Selected reviewer lenses:
- backend-go: changed mutation-capable job paths

Not loaded:
- frontend-ui: no app changes

Packet ends.
```

## Hidden Memory Used As Packet Evidence

Actual:

```text
Confidence: MEDIUM artifact: current diff plus prior memory of thread state
Variance ledger: prior reviewer concerns remembered from an earlier session
Pending Verification: N/A
...
Packet ends.
```

Why this fails:

- Parser-facing PR review packets are current-evidence artifacts.
- Memory, prior-session summaries, copied prior packets, and hidden conversation
  state are not valid packet evidence.
- Prior thread state, workflow routing, verdict rationale, and validation claims
  must come from current repo files, current GitHub/API reads, or local artifacts
  from the reviewed target.
- Memory use can also create footer or citation obligations that conflict with
  the required final `Packet ends.` line.

Expected:

```text
Confidence: MEDIUM artifact: current diff plus github__pull_request_read get_review_comments at head_sha=H
Variance ledger: fetched review comments enumerated below
Pending Verification: exact thread resolution state not fetched
...
Packet ends.
```

## Overclaiming Test Coverage Without Specific Artifact

Actual:

> The tests now cover the multi-row case and the full Run() path.

Why this fails:

- "now cover", "tests cover" is a claim that requires the specific test function name + file + line range, or the exact MCP diff / file content that demonstrates the coverage.
- Inference ("would be covered by any test invoking Run") must be marked `Pending Verification`.

Expected:

> Multi-row behavior coverage: `<test-name>` in `<repo-relative-test-path>` sets up multiple rows for the same logical key and asserts the aggregated result (artifact: file-content read at head ref for that path).
> Full public-entrypoint coverage: claimed in author reply on `<thread-id>`; fetched test content primarily exercises a helper directly (`Pending Verification` for the public-entrypoint path).

## Packet Indentation and Line Wrapping (Transport/Serialization)

Actual:

```text
  Verdict: PASS_WITH_FINDINGS artifact: variance ledger
  (3 inline comments) + P3 below at sha
  Review mode: STANDARD
  ...
  1. comment_id=3262620431, reviewer=copilot, is_resolved=true,
     current-code artifact=mongoreader.go:118-
     154@sha, disposition=code_changed_with_artifact
  ...
  Packet ends.
```

Why this fails:

- Header fields are indented (they do not start at column 1).
- Long fields and current-code artifact lines contain manual or token-wrapped newlines inside values/tokens (e.g. splitting `118-` and `154@sha`).
- `Packet ends.` is indented.
- Raw text before or after the fenced code block is emitted.

Expected:

For CLI output, emit the packet as raw contiguous text. For Markdown-rendering
non-CLI environments where a fence prevents renderer or copy/paste corruption,
use a single fenced code block with language `text`. In either shape, keep every
packet line starting at column 1, keep lines short to prevent wrapping/line breaks
in transport, and use a Head alias to represent the head SHA in subsequent rows:

```text
Verdict: PASS_WITH_FINDINGS artifact: variance ledger 9 rows checked at head sha
Head alias: H=a09c45c311a324552b827bd6f5a4c588e6a4222a
Review mode: STANDARD
...
- Backend - Validate artifact: run_id=27042263566, conclusion=success artifact: status=completed, head_sha=H, source=gh_api_run_27042263566
...
1. comment_id=3262620431, reviewer=copilot, is_resolved=true, is_outdated=true, current-code artifact=mongoreader.go:118-154@H, disposition=code_changed_with_artifact
...
Packet ends.
```

## Invoking Tools Before Reading Routing Instructions

Actual:

> I invoked the GitHub Check Runs tool and fallback commands, then realized I
> needed to read `pr-ci-read` and `gh-auth-session` to understand how to
> handle errors.

Why this fails:

- Routing instructions, companion skills, and error fallback rules must be read
  in the session *before* invoking the tools they govern.
- Using a tool directly without reading its routing guide can result in
  parameter errors, redundant tool usage, or incorrect error handling.

Expected:

> - Read the required companion skills (`pr-ci-read`, `gh-auth-session`)
>   to check execution paths and error handling boundaries.
> - Invoke the GitHub Check Runs or fallback commands only after the instruction
>   context is loaded.

## Truncated REH Block Mid-Field

Actual:

```text
Risk Evidence Handoff:
REH-1:
- Severity: P1
- Concern: staging execution missing
- Question for author/parent: provide capped dry-run logs at head
- Evidence needed: Staging capped execution logs for the reviewed mode at head_sha=
Selected reviewer lenses:
```

Why this fails:

- The `REH-1` block stops mid-field and the next section begins before all
  required named fields appear.
- Downstream parsers and parents cannot trust a truncated handoff block.

Expected:

```text
Risk Evidence Handoff:
REH-1:
- Severity: P1
- Concern: staging execution missing
- Question for author/parent: provide capped dry-run logs at head
- Evidence needed: Staging capped execution logs for the reviewed mode at head_sha=H, run status, cap values, timeout config relevant to that mode, terminal completion/failure state, and absence of hang/error signals.
- Suggested evidence lane: parent or operator lane
- Do-not-run boundary: no production run until staging evidence is verified
- Verdict impact: BLOCKED until staging evidence clears; staging-only execution can unblock merge; production full run remains post-merge handoff
Selected reviewer lenses:
```

## Unreadable Underscore Compaction In REH Fields

Actual:

> Evidence_needed=Staging_capped_execution_logs_for_the_reviewed_mode_at_head_sha=H_run_status_cap_values_timeout_config_terminal_completion_failure_state_and_absence_of_hang_error_signals

Why this fails:

- The field is technically one line but unreadable and hard to audit.
- Compaction replaced readable prose before using `Head alias` and shorter
  wording.

Expected:

> Evidence needed field keeps readable prose, uses `head_sha=H` from the header
> alias, and compacts only the longest token when still required.

## Central Execution Gap Filed As Formal P3 (or Counted in P2/P3 Header While REH Gate Is Open)

Actual:

> Verdict: PASS_WITH_FINDINGS
> P0/P1 findings: 0 code findings; 1 P1 REH gate
> P2/P3 findings: 1 P3 (operator first-run evidence missing for data-mutating path)
> Finding P3: Operator must run capped staging apply before merge.

Why this fails:

- A central blocking execution gap (the exact evidence needed to clear the open P1 REH) is being double-counted as both the REH gate (correct) and a formal P3 finding (incorrect).
- Central execution/rollout evidence for mutating paths that opens a P1 REH must stay exclusively under Pending Verification + the REH-n block. The P2/P3 findings count must remain 0 for that gap. The header P0/P1 line must qualify it as "0 code findings; 1 P1 REH gate".
- One-shot packets that mix the categories produce contradictory counts that downstream parsers will reject.

Expected:

```text
Verdict: BLOCKED
P0/P1 findings: 0 code findings; 1 P1 REH gate
P2/P3 findings: 0
Pending Verification: staging capped apply execution logs for the reviewed mode at head_sha=H (run status, cap values, terminal state, and absence of error signals)
Risk Evidence Handoff:
REH-1:
- Severity: P1
- Concern: staging execution missing
- Question for author/parent: provide capped staging logs
- Evidence needed: staging capped execution logs at head_sha=H
- Suggested evidence lane: parent/operator
- Do-not-run boundary: no production execution during review
- Verdict impact: staging-only evidence can unblock merge
```

No P3 finding is emitted for the same central gap. The gap appears only in
Pending Verification and the named REH block.

## REH Block Contains Blank Lines Between Named Fields

Actual:

```text
Risk Evidence Handoff:
REH-1:
- Severity: P1
- Concern: staging execution missing

- Question for author/parent: provide capped staging logs
- Evidence needed: staging capped execution logs at head_sha=H

- Suggested evidence lane: parent/operator
- Do-not-run boundary: no production execution during review
- Verdict impact: staging-only evidence can unblock merge
```

Why this fails:

- `REH-n:` blocks are parser-facing named-field lists, not prose sections.
- Blank lines inside the block make it ambiguous whether the block ended or the
  next field belongs to the same handoff.

Expected:

```text
Risk Evidence Handoff:
REH-1:
- Severity: P1
- Concern: staging execution missing
- Question for author/parent: provide capped staging logs
- Evidence needed: staging capped execution logs at head_sha=H
- Suggested evidence lane: parent/operator
- Do-not-run boundary: no production execution during review
- Verdict impact: staging-only evidence can unblock merge
```

## Overbroad Variance Header While Wrapper Objects Are Omitted

Actual:

> Variance ledger: enumerated below
> Pending Verification: 12 empty-body review wrapper objects omitted with IDs
> listed here.

Why this fails:

- `enumerated below` claims every fetched artifact appears as a numbered row.
- If a class of fetched artifacts is intentionally omitted, the header must
  name the narrower enumerated subset and the omitted class.

Expected:

> Variance ledger: inline and issue comments enumerated below; 12 non-actionable review wrapper objects omitted with IDs listed in Pending Verification
> Pending Verification: 12 review wrapper objects omitted because they contain no actionable inline body; omitted review_ids=<ids>

## Nested Lens Sections Or Packet Terminator

Actual:

```text
Selected reviewer lenses:
- backend-go: changed mutation-capable job paths
  Not loaded:
- frontend-ui: no app changes
  Packet ends.
```

Why this fails:

- `Not loaded:` is a top-level sibling section, not part of the last selected
  lens bullet.
- `Packet ends.` must be the final top-level logical line, not an indented
  continuation or nested bullet.

Expected:

```text
Selected reviewer lenses:
- backend-go: changed mutation-capable job paths

Not loaded:
- frontend-ui: no app changes

Packet ends.
```

## Missing Selected Reviewer Lenses Section

Actual:

> Residual risk: staging execution not observed.
> Packet ends.

Why this fails:

- Parser-facing reviewer packets require `Selected reviewer lenses:` before
  `Packet ends.` when blast-radius or lens routing matters.
- The parent cannot audit which production-path lenses were loaded.

Expected:

```text
Selected reviewer lenses:
- backend-go: changed mutation-capable job paths and timeout wiring
- sql-migrations-generated: audit SQL and operator README contract at reviewed head
- migration-safety: rollout/schema/operator contract for dry-run gate; no new files under backend/internal/shared/sql/migrations/
Not loaded:
- frontend-ui: no app route or component change in changed-file inventory
Packet ends.
```

## Performing Repository-Facing Work Before Finishing Bootstrap

Actual:

> I fetched PR details and listed comments, then viewed the required bootstrap
> files `AGENTS.md` and `GEMINI.md`.

Why this fails:

- Bootstrap files are a strict prerequisite and must be read in their exact
  order at the very beginning of the session before any repository-facing tool
  calls or file reads outside the bootstrap are executed.

Expected:

> - Read `AGENTS.md`, `GEMINI.md`, and `repo.md` in order.
> - Inspect the PR metadata, comments, and other repository resources only after
>   the bootstrap sequence is complete.
