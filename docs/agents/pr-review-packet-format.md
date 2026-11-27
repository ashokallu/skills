<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (same-response minimal review comments) -->

# Parser-Facing PR Review Packet Format

Use this reference when an agent emits a parent-facing project GitHub PR
review verdict. External harnesses such as Grok, Antigravity, and
Gemini are always parser-facing. Codex and Claude PR review verdicts are also
parser-facing by default unless the user explicitly asks for a summary,
inventory, explanation, metadata read, or another narrower non-verdict shape.

This is a machine-facing contract. Downstream parsers scan the full text for
trigger words and structural fields. A human-readable summary is not a
substitute for the packet shape below.

## When This Applies

- The user asked to review a project GitHub PR and the harness owns the
  verdict.
- The project PR workflow and reviewer skill were selected for a GitHub
  PR in another repository. The target repository does not cancel this output
  contract; use the packet unless the user explicitly asks for a narrower
  non-verdict shape.
- The response is parser-facing or may be consumed by automation. Treat
  project PR review verdicts as automation-consumable by default.
- The harness loaded `pr-workflow/references/review-worktree.md`, the
  reviewer role, and the operating contract for the active identity.

Ordinary PR review remains read-only unless the user explicitly asks for
validation or fixes.

## Read Order Before Emitting

Use the reviewer role for findings-filter and severity rules, then this file
for packet shape, then the operating contract when the active identity requires
its handoff gate and trigger-word audit.

| Runtime | Reviewer role | Operating contract |
| --- | --- | --- |
| Claude Code | `.claude/skills/reviewer/SKILL.md` | not required unless cross-runtime identity rules apply |
| Codex | `.codex/skills/reviewer/SKILL.md` | follow the active runtime overlay |
| GitHub Copilot | `.agents/skills/reviewer/SKILL.md` | follow `.github` instructions and agent overlays |
| Antigravity / Grok / Gemini | `.agents/skills/reviewer/SKILL.md` | `.agents/skills/antigravity-operating-contract/SKILL.md` |

Read order for every runtime:

1. The reviewer role row above — findings filter and severity rules.
2. This file — packet shape, variance ledger, CI rows, closeout rules.
3. `docs/agents/pr-comment-conventions.md` when the assignment requires
   `Review comments:`. It owns
   the wording and shape of every body this packet will carry, and its
   mechanical subset is enforced as `RPPA-011`. Read it before drafting any
   review-comment Body or Summary; the parent must never supply those
   conventions in the dispatch prompt.
4. The operating-contract row above when it applies to the active identity.

Re-read this file immediately before emitting `Packet ends.`

## Packet Serialization and Transport Rules

- Emit the packet as raw contiguous text by default for CLI readability. Use a
  single fenced `text` block only when the channel preserves Markdown and the
  fence prevents transport corruption. When the channel may strip fences, such
  as terminal copy or paste from a CLI, raw contiguous packet text is compliant
  as long as the content rules in this section hold. A fenced block is a
  fallback shape, not the test of compliance.
- In Markdown-rendering non-CLI environments, such as web chat UIs or PR
  comments, use a single fenced code block with the `text` language when the
  fence prevents renderer or copy/paste corruption. Do not use a `markdown`
  fence. For CLI output, raw contiguous packet text remains the default.
- No indentation: every required field and row starts at column 1.
- No prose before or after the packet. Human-readable explanation belongs in
  the required `Plain-language summary:` packet section, not outside the packet.
  The packet contract owns final serialization for PR review verdicts: generic
  final-answer style, memory citations, source footers, self-audits, or
  "outside the packet" summaries are not allowed after the terminator.
- Do not use memory, prior-session summaries, copied prior packets, or hidden
  conversation state as evidence or workflow authority for a parser-facing PR
  review verdict. Build the packet from current repo files, the live review
  target, and authenticated/current PR evidence. If historical context is
  useful, re-derive the relevant fact from current repo/GitHub artifacts or
  keep it out of the packet. Use memory only when the user explicitly asks for
  historical analysis or a non-verdict explanation outside the packet workflow.
- When a reviewer subagent produces the packet, the parent accepts it once and
  must not paste it into commentary or repeat it in later turns. The parent
  reports a bounded verdict, every finding, current CI/thread state, and
  `Pending Verification` by default. It forwards the exact packet once only
  when the user explicitly asks to receive the packet itself. The packet
  remains the parser-facing authority for publication and downstream consumers.
  A parent that owns the review itself still emits the packet directly.
- `Packet ends.` must be the final line.
- Header fields, CI rows, variance ledger rows, artifacts, paths, line ranges, SHAs, URLs, and command/API sources must never contain inserted newlines.
- Every variance ledger row and CI row must be emitted as one continuous
  logical line with no manual newline, formatting break, or token split inside
  the row. Terminal display wrapping is acceptable only when the copied packet
  still preserves one logical row.
- If a row is too long, shorten the field text or split the information into separate complete rows. Never split a token.
- To shorten rows or fields without corrupting parser-facing content, use this order:
  1. Keep readable prose in fields and narrative values first. Human and parser
     consumers must be able to read each field as one complete thought.
  2. Declare a Head alias field in the header immediately below the `Verdict:`
     line, e.g. `Head alias: H=<40-character-sha>`, and reference `@H` or
     `head_sha=H` in later rows instead of repeating the full 40-character SHA.
  3. Shorten only the longest token in a row, such as a repeated SHA, a long
     workflow name, or a verbose `source=` value. Prefer compact but legible
     tokens such as `source=gh_api_run_<run_id>` over mangled underscore chains
     that hide meaning.
  4. Omit optional fields such as `node_id` in the variance ledger only when the
     row is still one complete logical line after omission.
  5. Never truncate a field mid-value to fit transport width. If a row still
     cannot fit as one logical line after the steps above, shorten wording while
     preserving every required field; do not drop the tail of a REH field or
     any other required value.

### Formatting Examples

#### Bad (Indented, Wrapped, and Broken Tokens)

```text
  Verdict: PASS_WITH_FINDINGS artifact: variance ledger
  (3 inline comments) + P3 below
  ...
  1. comment_id=3262620431, reviewer=copilot, is_resolved=true,
     current-code artifact=mongoreader.go:118-
     154@sha
  ...
  Packet ends.
```

#### Good (Start at Column 1, Unwrapped, CLI-Readable Raw Packet)

```text
Verdict: PASS_WITH_FINDINGS artifact: variance ledger + P3 below at sha
Review mode: STANDARD
...
1. comment_id=3262620431, reviewer=copilot, is_resolved=true, is_outdated=true, current-code artifact=mongoreader.go:118-154@sha, disposition=code_changed_with_artifact
...
Packet ends.
```

The code block above shows the raw packet shape for documentation. In CLI
output, emit those lines directly unless the channel needs the `text` fence to
preserve them.

#### Good Fallback (Single Fenced Text Block)

```text
Verdict: PASS_WITH_FINDINGS artifact: variance ledger + P3 below at sha
Review mode: STANDARD
...
1. comment_id=3262620431, reviewer=copilot, is_resolved=true, is_outdated=true, current-code artifact=mongoreader.go:118-154@sha, disposition=code_changed_with_artifact
...
Packet ends.
```

## Channel Tolerance And Judging Pasted Packets

The raw CLI packet is the default emit shape. A fenced `text` block is a
transport fallback, not the test of compliance. Some channels, such as terminal
copy from a CLI, drop fences or re-wrap long lines on display. Judge the
durable content rules, not the surviving Markdown:

- A required field or row starts at column 1 in the raw text.
- No newline is inserted inside a token, field, row, artifact, path, line
  range, SHA, URL, or command/API source. Visual wrapping on a narrow terminal
  is not a violation.
- `Packet ends.` is exactly the final line.
- Each CI row and each variance ledger row is one logical line.

When judging a packet someone pasted from a CLI, do not treat a missing fence or
display wrapping as a violation. Treat as real violations only inserted
newlines, blank required fields, duplicated sections, wrong severity, malformed
ledger rows, or a non-final `Packet ends.`

## Evidence Response Packet For Reassessment

This packet is parent-to-reviewer input for reassessing one previously emitted
`REH-n` concern. It is not a final parser-facing PR review verdict packet and
must not inherit the verdict packet's `Verdict:`-first, section-order, or
`Packet ends.` rules. The parent may send it to the original reviewer session
or a fresh reviewer together with the original Risk Evidence Handoff.

Emit these fields once and in this exact order:

```text
Evidence Response Packet:
Original concern ID: REH-<n>
Emitting review target: <original review target and exact base/head or commit>
Evidence target: <environment, resource, revision, and time window inspected>
Evidence lane: <read-only or owner-approved lane used to collect the evidence>
Environment: <local, CI, staging, production, or other exact environment>
Safety boundary: <read-only, capped rehearsal, no-production, or other enforced boundary>
Result: <observable outcome without unsupported interpretation>
Artifact: <repo-relative path, command result, run ID, API result, or other concrete proof>
Raw artifact or transcript: <location or bounded excerpt needed for independent reassessment>
Redactions: <what was removed and why, or none>
Remaining Pending Verification: <unproved facts that still affect the concern, or none>
Reassessment request: <the exact verdict, finding, or REH decision to reconsider>
```

The `Original concern ID` and `Emitting review target` must match one prior
Risk Evidence Handoff block. Evidence proves only the named evidence target,
environment, time window, result, and safety boundary. Missing or unmatched
fields leave the concern `Pending Verification` or `BLOCKED` according to its
original risk. If the review target changed, the reviewer must restart the
affected review slice instead of applying this packet to a different target.

## Packet Header

Emit these fields first, in order, as plain `Key: value` lines inside a single
fenced `text` block or as contiguous parser-facing lines:

```text
Verdict: PASS | PASS_WITH_FINDINGS | FAIL | BLOCKED artifact: <proof for verdict at current head>
Head alias: H=<40-character-sha> (optional, used to shorten row-level SHA references)
Review mode: LITE | STANDARD | FULL | COUNCIL
Review target: PR | branch | commit | dirty | staged, with base/head SHAs when known
Scope basis: stated intent, changed-file inventory source, prior findings, limits
Coverage: reviewed surfaces; sampled surfaces; explicitly unreviewed surfaces
Confidence: HIGH | MEDIUM | LOW artifact: <what was and was not executed>
Session hygiene: fresh or reused target; inputs; forbidden inputs; contamination notes
P0/P1 findings: <count and short labels, or 0>
P2/P3 findings: <count and short labels, or 0>
Strongest proof checked: <repo-relative file:line symbols or command/API artifacts>
Variance ledger: enumerated below | <bounded enumerated scope and omitted artifact note> | N/A only when zero prior artifacts were fetched
Pending Verification: enumerated gaps | N/A only when no gaps remain anywhere in body
Would flip verdict if: <smallest artifact or failure condition>
Next owner: none | parent | <one specialist> artifact: <why this owner matches open findings and PV>
```

When rollout, operator, production, or environment evidence matters to the
review outcome, add these lines immediately after `Next owner`:

```text
Code-review status: <bounded reviewer-scope status> artifact: <proof scope boundary>
Operator status: <rollout/operator-scope status> artifact: <proof scope boundary>
```

### Strict Header Field Requirements

Header fields must use concrete artifacts instead of narrative, placeholder
branch names, or generic statements.

- **Verdict line**: The `artifact:` for `Verdict:` must be tied to the
  reviewed surface and findings count, such as the API tools used to retrieve
  files, the number of variance ledger rows checked, and the inspected head
  files. Do not use generic commit or log artifacts, such as
  `git log -n 1 <sha>`, that only prove commit existence rather than the review
  verdict.
- **Scope basis line**: When a local review worktree is prepared, `Scope basis`
  must cite the worktree-based git diff command, such as
  `git diff <base>...HEAD in worktree`, as the source for the changed-file
  inventory and diff path. Do not cite `github/pull_request_read` or other
  GitHub MCP metadata tools for the diff scope once a worktree exists, as those
  APIs are prone to truncation and limits. After a verified worktree exists,
  local git and file reads are also the source of truth for code contents and
  patches; remote file-content or diff APIs are allowed only before checkout, or
  for a narrow count/SHA cross-check that cannot be answered locally.
- **Confidence line**: The `artifact:` for `Confidence:` must prove the
  code/inspection scope instead of only listing CI status, metadata access, or
  unexecuted checks. Omit the artifact when no session-run tool proves the
  scope.
- **Code-review status line**: The `artifact:` for `Code-review status:` must
  be a concrete artifact showing the inspected code/diff scope, such as the
  output of a specific git command in the prepared worktree, such as
  `git diff --name-only <base>...HEAD in worktree` plus inspected paths, rather
  than broad metadata/files reads. Use bounded,
  machine-safe status values such as `bounded`, `blocked_by_P1`,
  `blocked_by_P2`, or `Pending Verification`; avoid narrative values such as
  "looks good", "not assessed", or "complete for reviewer scope".
- **Operator status line**: Only canonical status values, such as
  `Pending Verification`, `blocked`, `bounded`, or `complete`, may be used for
  `Operator status`. Non-canonical status values such as `rollout_dependent`
  are prohibited. The `artifact:` for `Operator status:` must cite an
  exact PR body field, runbook line, or tool/API result. It must not be a
  narrative statement or paraphrase. If operator, rollout, staging, or
  production evidence was not collected, write `Operator status: Pending
  Verification artifact: <exact missing evidence source>`, route `Next owner`
  away from `none`, and do not use narrative placeholders such as "not
  assessed".
- **Next owner line**: The `artifact:` for `Next owner:` must prove ownership
  routing using a concrete artifact, such as the exact README, PR body, runbook
  line, or API field specifying the operator step or owner responsibility. Do
  not use a narrative statement as the artifact.
- **Header artifact precision**: When a header `artifact:` points to a doc,
  README, runbook, or PR-body location that is also cited more precisely
  elsewhere in the packet, reuse the most precise locator already established,
  such as the finding's exact `path:start-end@sha`. Do not cite a broad
  "section" when an exact line range is known.
- **Artifact range re-verification**: Confirm every local `path:line@sha` or
  `path:start-end@sha` by opening or grepping that exact range at the reviewed
  head immediately before emit. Do not cite a remembered, approximate, or
  "nearby" range from an earlier read. When the artifact points into a doc,
  runbook, or README, verify whether the cited range is prose or the specific
  command/example/table block that contains the referenced behavior, and cite
  the block that actually proves the claim, not adjacent narrative.
- **Line range required on every local artifact**: Every local file artifact in
  any field (header, `Strongest proof checked`, `Proof checked`, finding
  `Location`/`Evidence`, variance ledger `current-code artifact`, REH evidence
  lane, and `Next owner`) must carry `:line` or `:start-end`. This includes
  short files such as migrations and generated stubs; cite `path:1-2@sha` rather
  than `path@sha`.
- **Checks API read artifact**: When reporting Checks API read or fallback
  status, cite the exact tool name, parameters, and fallback actions used. Do
  not write generic narrative.
- **Absence Proof and Negative Evidence**: When proving negative or absence
  claims in PR bodies, docs, or target tables, cite the exact field/section
  inspected and the exact absence result, such as `github/pull_request_read get
  body field '<field_name>' returned no <evidence_type> logs at PR
  #<pr_number> head <head_sha>`. Generic narrative like "contains no X" is not
  a valid artifact.
- **Absence Proof in Variance Ledger**: When proving the absence of a deleted
  code element, the `current-code artifact` must include the search command,
  options, searched scope, and zero-match command result.
- **P findings count qualification**: If any Risk Evidence Handoff (REH) gate of
  P0/P1 severity is open, the count field `P0/P1 findings:` must explicitly
  qualify both code findings and REH gates (e.g., `0 code findings; 1 P1 REH gate`)
  to prevent logical conflicts in parser validation.
- **Pending Verification line**: The header `Pending Verification` field must
  list the concise gap items inline, each naming the missing surface or command.
  Do not defer with `enumerated below` or a bare pointer; a reader must see the
  gaps in the header itself.
- **Residual Risk vs Pending Verification**: If `Pending Verification` contains
  rollout, database, or runtime validation gaps, Residual Risk cannot be
  `None` or `N/A`. It must describe the risk of the unrun or unobserved steps,
  or be omitted when the same risk is already captured as a formal P0-P3
  finding.
- **Residual Risk cross-references**: Residual Risk must describe each risk
  directly and must not cite a `Pending Verification` item by number unless it
  describes the identical gap. Do not claim a residual risk is tracked by a PV
  item that covers a different surface, such as pointing a production-execution
  risk at a local-test PV entry.
- **Would flip verdict if**: The flip condition must be directly related to the
  findings and Pending Verification. If the verdict is blocked or
  `PASS_WITH_FINDINGS` due to pending rollout or dry-run execution, the flip
  condition must describe a rollout, staging, or dry-run failure severe enough
  to block merge or require code changes, such as `<environment> execution
  returns <failure_type> requiring code change`, not an unrelated syntax/schema
  mismatch. When the open finding is a verification or rollout gap rather than a
  proven defect, state both directions in this one line: the evidence that
  clears the finding and raises the verdict, and the failure that lowers it to
  `FAIL` or forces a code change. The flip condition must name the exact
  observable head-pinned canary status or DB metrics, such as
  `staging canary run at head_sha=<sha> completes with expected selected user count, zero blocking exceptions, and acceptable DB metrics`,
  instead of loose or generic success wording. If the merge is blocked pending
  execution evidence, the line must precisely state whether staging-only
  execution is sufficient to unblock the merge (leaving production as a
  post-merge rollout handoff), or if production execution is also required to
  unblock. Emit this field exactly once in the packet header. Do not repeat it
  as a later section or closeout paragraph; if supporting detail is needed,
  put the detail in findings, `Pending Verification`, or `Residual risk`.
- **Canonical line ranges**: All local line references in packet artifacts, such
  as `current-code artifact` in the variance ledger, finding locations, or
  other packet line cites, must use the canonical format `path:start-end@sha` or
  `path:line@sha` for a single line. Do not use GitHub UI-style prefixes like
  `L123` or narrative placeholders.
- **Finding Location**: The `Location:` field in formal findings must always
  specify a precise line range such as `path:start-end@sha`, or an API field
  containing the risky behavior. Never cite just a file path. For defects that
  combine a risky behavior with a missing upstream guard, set `Location:` to the
  narrowest reachable risky behavior, and put the missing guard or normalization
  point in `Evidence:` with its own line artifact. The `Location:` value is only
  the artifact locator: do not prefix it with narrative or a packet field name
  such as `Operator status`. Field references belong in `Evidence:`. For a
  rollout or operator-verification finding, set `Location:` to the README,
  runbook, or PR-body line range, or to the SQL or query lines, never to a
  packet field name.
- **Finding Confidence and Evidence Consistency**: Every formal finding, such
  as `Finding P3`, must have a `Confidence:` level that is consistent with the
  overall header confidence. Do not use `Confidence: HIGH` for a finding that
  describes a rollout, verification, or execution gap that cannot be proven in
  the current session. Findings that track unrun rollout or first-run
  verification steps must prove the lack of execution using a concrete field
  check, such as verifying that a specific PR body field or stack-status field
  contains no staging execution logs, rather than citing only the existence of
  runbooks or README files.

### Verdict Consistency Truth Table

Downstream parsers enforce strict consistency across packet fields. The review
verdict and header fields must follow this truth table:

- **Severity to verdict**: `PASS_WITH_FINDINGS` is the default verdict when the
  packet contains only P2 and/or P3 findings or non-blocking residual risks.
  Use `FAIL` when any P0 or P1 remains, or when the implementation does not
  satisfy the stated intent. Do not escalate a standalone P2 to `FAIL` unless
  the finding proves the implementation misses the PR's stated purpose rather
  than a bounded follow-up fix.

- **P1 REH gating**: If any P1 Risk Evidence Handoff (REH) gate is open or
  unresolved (such as pending staging execution logs for a database-mutating
  or data-importing run), the verdict cannot be `PASS` or `PASS_WITH_FINDINGS`.
  It must be `BLOCKED` until the required execution evidence is provided.
- **Operator status incomplete**: If `Operator status` is not complete, the
  verdict cannot be `PASS`. It must be `PASS_WITH_FINDINGS` with a P3 rollout
  finding, `BLOCKED`, or `FAIL`.
- **Ownership Routing**: If `Next owner` is not `none` due to active findings or
  operator/rollout gaps, the verdict cannot be `PASS` unless the owner is for a
  minor non-review administrative follow-up explicitly marked non-material.
- **Residual Risk consistency**: If `Pending Verification` contains rollout or
  runtime validation gaps, Residual Risk cannot be `None` or `N/A`. It must
  describe the risk of the unverified execution, or be omitted when a formal
  finding already tracks the same risk.
- **P findings count**: `P2/P3 findings: 0` requires no operator-status or
  rollout gap that changes ownership. Central blocking evidence gaps (such as
  pending staging or production execution runs for database-mutating or
  data-integrity paths) must be kept purely under `Pending Verification` and the
  `REH-n` list **with zero P3 findings** (unless there is an actual code or prose
  defect at the reviewed head). Do not create a formal P3 (or P2) finding for
  these central blocking gaps; document them solely in `Pending Verification` and
  the `REH-n` list. When the evidence must be collected outside the reviewer,
  `Next owner` must identify the owner, usually `parent`; use `none` only when no
  P findings, no central `Pending Verification`, and no owner decision remain.
  One-shot packets must never double-count the same gap as both an open REH gate
  in the P0/P1 header qualifier and a P3 finding.

### Verdict line

- The verdict line must include `artifact:` on the same line.
- Do not emit `Verdict: PASS` while the body still contains unowned operational
  gaps, open P2/P3 findings, or `Pending Verification` items that control the
  verdict. Use `PASS_WITH_FINDINGS`, raise a finding, or move the gap into
  `Pending Verification` with `Next owner: parent`.
- A verdict of `PASS` is strictly reserved for codebases with zero unresolved
  operator status, zero material findings (P0-P3), and zero contradictory
  owner/status fields. If operator rollout is incomplete, or if local
  validation/production-scale behavior remains unverified or dependent on
  rollout events, the verdict must be `PASS_WITH_FINDINGS` (with a P3 rollout
  finding), `BLOCKED`, or `FAIL`.

### Next owner

- `Next owner` must name exactly one routing token from the allowed set, such as
  `none`, `parent`, or one specialist. Do not combine two owners in the field,
  such as routing to `parent` while also naming a human author, and do not put a
  narrative sentence where the single token belongs. When several open items
  have different natural owners, route to `parent` and let the parent fan out.
- If any P0, P1, or P2 finding is listed, `Next owner` must name the owner of
  those findings or `parent`. It must not be `none`.
- If only P3 findings remain, `Next owner` may be `parent` when operator or
  rollout work is still required; do not use `none` while operator-scope risk
  remains open.
- `Next owner: none` is allowed only when there are zero P0–P3 findings, no
  unresolved actionable comments in the variance ledger, and no remaining owner
  decision or operator-scope gap tracked in the packet. Non-actionable
  `is_resolved=false` rows may remain ledger-only when their disposition shows
  an accepted tradeoff, a declined nit, or another settled state, but the
  packet must not claim all prior comments are closed.
- If `Operator status` is rollout-dependent or incomplete, `Next owner` must never be
  `none` and must route to `parent` or the specific migration/rollout operator.
- When operator evidence matters, separate reviewer scope from operator scope:
  - `Code-review status` — what static review at the current head did or did
    not prove.
  - `Operator status` — what staging, production, or manual rollout evidence
    is still missing.

### Severity calibration for missing tests

Severity definitions live in the reviewer role; calibrate the common
missing-test case before emitting. A missing regression test is `P3`, not `P2`,
when the invariant it would cover is already proven by current code plus an
existing test and no reachable code path bypasses that proven guarantee. Reserve
`P2` or higher for a missing test where the behavior is unproven at the reviewed
head, or where a distinct code path can reach the risky outcome without the
shared, already-tested guard. Do not record a finding as `P2` while the same
packet states the guarantee currently holds; that is a regression-lock gap and
is `P3`.

### Formal-finding bar for cleanup and maintainability observations

A maintainability, cleanup, naming, redundancy, or abstraction observation is a
formal finding only when the current head is already wrong, or a concrete
reachable path produces a wrong result today. Speculative future risk, such as
"a later edit could diverge" or "ownership is ambiguous", does not qualify.

- Redundant-but-correct code, idempotent duplicate work, harmless extra
  normalization, and stylistic ownership questions are not formal findings.
  Omit them, or mention them only when they actively mislead an operator.
- Do not file a formal finding whose only harm is a hypothetical future change.
  Prefer silence: a clean verdict with no weak findings is the better outcome.
- PR-body, reviewer-guide, doc, log-wording, and file-count drift are low-value
  unless they hide a material reviewed surface or mislead an operator. Keep them
  out of formal findings and out of residual risk.

### Confidence calibration

Set the header `Confidence` from what this session actually proved, not from
green CI or from how thorough the read felt:

- Use `HIGH` only when session-run deterministic evidence exercised the changed
  behavior, or when direct static reading proves the exact invariant the verdict
  depends on and no unobserved dynamic gap controls the verdict.
- Use `MEDIUM` when the review is static-only, no tests, build, or reproduction
  were run in this session, and correctness rests on reading plus external CI.
  Green CI raises trust but is not session-run proof, so it does not by itself
  justify `HIGH`.
- Use `LOW` when key behavior is inferred with a material unclosed gap.

When the packet also lists a `Pending Verification` rollout, execution, or
runtime gap that bears on the change, the overall `Confidence` cannot be `HIGH`.

### P finding counts vs residual risk

- Every material residual risk in the body must appear as a formal P2/P3
  finding, a `Pending Verification` entry, or an explicitly bounded
  operator-status line with owner routing.
- Do not write `P2/P3 findings: 0` while the body still describes uncapped
  production behavior, missing operator runs, or other rollout evidence gaps
  that matter to the change. Either file a P3 (or P2 when material) or list the
  gap under `Pending Verification` and set `Next owner: parent`.
- If operator rollout risk (such as first-run verification or production-scale
  query plan execution) is significant enough to mention, it must be documented
  as a formal P3 finding (under `PASS_WITH_FINDINGS` or `BLOCKED`), or kept
  purely under `Pending Verification` with no descriptive/evaluative finding
  language in the narrative. Do not mix them.
- For a finding location, cite the file/lines containing the risky behavior
  itself, not a generic doc range or random config/plumbing line. If the risk
  is unobserved rollout/staging execution, the location must point to Operator
  status, PR body/runbook evidence, or SQL query lines when performance-related.
- Finding evidence must include exact artifacts in every field that claims proof.
- Claims referencing a PR body, README, or runbook must cite the exact line
  range, API field, or file section instead of a paraphrase.
- When a risk combines two code paths, separate the evidence by path instead of
  attaching proof from one path to the other.
- The `artifact:` value must be an artifact, not a sentence. Accepted artifact
  forms are `file:line@sha`, exact tool/API call result, or exact command
  result. Put narrative explanations outside the artifact field.
- For absence claims, require a command artifact with pattern, scope, and
  zero-match result.
- Low-value naming or abstraction nits from prior threads belong in the
  variance ledger only. Do not promote them to formal findings.

## Review Target Consistency (Single Head SHA)

All code content, diff hunks, inline thread current-code mappings, CI status
rows, Code-review status, and Operator status artifacts used to justify the
verdict, findings counts, Pending Verification, Residual Risk, Confidence, and
Next owner must be collected against exactly one SHA: the live head SHA at the
time the packet's evidence collection is finalized or restarted.

- Establish the review target SHA early from authoritative metadata, such as
  `gh pr view` or API head SHA. Use that exact value for every file content
  fetch (`ref=<sha>`) and every `path:line@sha` in the packet.
- Use the full 40-character head SHA everywhere in a parser-facing packet:
  every `path:line@sha`, every CI `head_sha`, and every status artifact.
  Abbreviated SHAs are not valid in parser-facing artifacts because they are
  ambiguous to downstream tooling.
- If the live head SHA changes during collection, stop, discard prior
  file-content and mapping artifacts from the old SHA, refetch the
  reviewer-guide files and relevant comments at the new head, re-inspect, and
  rebuild the variance ledger, proof checked, and status lines against the
  single new head.
- Mixed-SHA packets are invalid for `PASS` or `PASS_WITH_FINDINGS`. Use
  `BLOCKED`, or `PASS_WITH_FINDINGS` with a P3 stale/incomplete review target
  finding and owner routing, until a fully consistent single-head collection is
  complete.

## Variance Ledger

Required when any prior PR comment, inline review comment, review summary,
Copilot output, or other review artifact was fetched. Do not write
`Variance ledger: N/A` after fetching prior artifacts.

The header `Variance ledger:` field must not claim full enumeration while a
fetched class of artifacts is intentionally omitted from the rows. When every
fetched artifact has its own row, `enumerated below` is correct. When a
non-actionable class is held out (for example empty-body or summary-only review
wrapper objects), use bounded header wording that names what is enumerated and
what is omitted, such as
`inline and issue comments enumerated below; N non-actionable wrapper objects listed in Pending Verification as omitted IDs`,
and list the exact count and IDs in the `Pending Verification` field. The header
field, the `Pending Verification` omission item, and the row set must agree on
what was and was not enumerated.

Enumerate every fetched root comment or review object individually as its own
numbered row (`1.`, `2.`, `3.`) with no gaps or summaries. Do not group rows,
do not append a parenthetical "additional ... follow the same pattern", "multiple
...", or any summary language after an "enumerated below" claim, and do not claim
"every fetched" if any artifact was left unenumerated. If any category of
fetched artifacts (e.g., review summaries from get_reviews that lack inline
bodies) is intentionally omitted from the ledger because it is low-value and
non-actionable, the exact limitation, count, and reason must appear as an
explicit item in the Pending Verification header field and the packet body.
The `Variance ledger:` header must then use bounded wording that names the
exact artifact type and count represented by the rows, and it must mention the
omitted object count and ID list location.

For high-level review summaries, empty-body self-reviews, and purely
informational comments that do not raise a specific actionable line-level
concern on the current diff, use `disposition=out_of_scope`, or
`pending_verification` if the row itself could not be evaluated. Either omit
the `current-code artifact` field or cite only the review object metadata, such
as `review_id`, `submittedAt`, and commit oid. Even when `current-code
artifact` is omitted for these rows, include the stable review or comment
metadata available from the fetched artifact, such as numeric `review_id`,
numeric `comment_id`, reviewer, submitted time, and commit oid. Never emit
`current-code artifact=N/A` or any placeholder value for these rows.

### Row template

Use one numbered row per artifact:

```text
N. comment_id=<numeric id>, node_id=<PRRC_... when available>, review_id=<numeric review id when available>, reviewer=<login>, is_resolved=<true|false>, is_outdated=<true|false>, current-code artifact=<repo-relative/path:line@head-sha or omitted for pure review objects>, disposition=<machine-safe token>
```

Use only `true` or `false`, or omit the optional `is_resolved`/`is_outdated`
fields entirely if the exact thread resolution state was not retrieved via the
thread API. When omitting those fields after fetching inline comments, add one
`Pending Verification` entry naming the missing thread-state surface, for
example `reviewThreads resolved/outdated state was not fetched`. The string
`Pending Verification` must not appear as a value for `is_resolved` or
`is_outdated`. If thread state controls the disposition of a row and is
unknown, use `disposition=pending_verification` for that row.

Optional reply reference when disposition depends on author response:

```text
author_reply_id=<numeric id>
```

### Machine-safe disposition tokens

Use only these tokens in `disposition=` values. Do not embed parser trigger
words such as `verified`, `fixed`, `resolved`, `addressed`, `success`, or
`complete` inside disposition strings.

| Token | Meaning |
| --- | --- |
| `code_changed_with_artifact` | Current head contains a code or test change that maps to the thread concern |
| `no_change_author_accepted` | Author declined the change; current head still matches the declined shape |
| `rejected_stale_thread` | Thread target line, path, or claim does not apply at current head |
| `rejected_invalid_claim` | Thread concern is not supported by current-code evidence |
| `concern_remains_open` | Thread concern still applies at current head; not fixed |
| `duplicated_prior_finding` | Same concern already tracked under another row |
| `out_of_scope` | Outside the review target boundary |
| `pending_verification` | Current head not mapped; missing artifact |

### ID requirements and Verification

- Prefer numeric `comment_id` from the GitHub review-comment API.
- Include `node_id` when available.
- Include `review_id` when the row maps to a review summary.
- A fetched PR review object (summary or empty-body review) is keyed by
  `review_id=<id>`. Do not copy its id into a `comment_id=` field. Reserve
  `comment_id=` for issue comments and inline review comments that own a
  distinct numeric comment id.
- If only thread metadata was partially fetched, omit the `is_resolved` and
  `is_outdated` fields or set them to `true`/`false` based on what was actually
  retrieved. Never use the literal string `Pending Verification` as a field
  value. Use `disposition=pending_verification` for the row when the mapping
  itself is incomplete. Do not guess.
- **Current-Code Artifact Verification**: Every `current-code artifact` path and
  line reference in the variance ledger must point to the exact files and lines
  of code that prove the disposition, such as where the concern was addressed
  or why it is stale. Weak placeholders, such as file header line `:1` or
  unrelated files, do not prove the disposition and constitute a
  validation/proof violation. If the current head does not contain a specific
  code location that maps to the disposition, use
  `disposition=pending_verification` or map it to a concrete test or
  documentation file showing the change.
- **Unresolved Comments Owner Routing**: Do not state `Next owner: none` with a
  claim that all prior comments are closed or resolved when any variance ledger
  row lists `is_resolved=false`. Rows with `disposition=concern_remains_open`,
  `disposition=pending_verification`, or another actionable unresolved state
  require `Next owner: parent` or the PR author. Non-actionable open nits or
  accepted tradeoffs may remain ledger-only when the disposition makes that
  clear.

## CI State Section

When CI or check state is part of the review, add a **CI state** section after
the packet header.

### Checks API permission failure

If check-run reads return HTTP 403, say so explicitly and use the workflow-run
fallback from `pr-ci-read` before calling CI unknown.

### Per-workflow row format

List each relevant workflow run on its own line. When the parser scans per
occurrence, put `artifact:` immediately after the conclusion word:

```text
- <workflow name> artifact: run_id=<id>, conclusion=<value> artifact: status=<value>, head_sha=<sha>, source=<gh api path or MCP tool used>
```

Example shape (generic placeholders only):

```text
- Backend - Validate artifact: run_id=<id>, conclusion=success artifact: status=completed, head_sha=<sha>, source=gh api actions/runs?head_sha=<sha>
```

Do not write "all checks green" or "CI passed" without naming each workflow
run_id, head_sha, and source on the same row.

Do not invent status descriptions like "status finished" or "passed" in the
narrative or summary. Use the exact conclusion/status values returned by the
API, such as `conclusion=success` and `status=completed`. Align the text
description with the exact workflow field values.

## Proof Blocks After The Header

Before drafting section text, assemble the packet skeleton from the evidence
actually fetched in the session. This is a required construction step, not an
optional polish pass. A packet with a correct verdict and a valid finding is
still invalid when it omits required sections that correspond to fetched
evidence.

Use this assembly rule:

- Always start with the complete header field list in order.
- Add `Proof checked:` when local file, diff, command, or API artifacts are
  part of the verdict proof.
- Add one complete `Finding Px:` block for every positive P finding count.
- Add `Review comments:` when a default whole-target review has one or more
  formal findings. Omit it for a clean review. An explicit verdict-only or
  triage assignment forbids it.
- Add `CI state:` when CI, checks, workflow runs, or status were fetched,
  discussed, or used to bound confidence.
- Add `Variance ledger:` when comments, review threads, review summaries,
  bot reviews, human replies, or other prior review artifacts were fetched.
- Add `Residual risk:` only for material non-central gaps not already tracked
  by a finding, `Pending Verification`, `Operator status`, or `REH-n`.
- Add `Risk Evidence Handoff:` when the verdict rules require it.
- Always add `Plain-language summary:`, `Selected reviewer lenses:`,
  `Not loaded:`, and final `Packet ends.`.

Do not emit the packet from the first valid finding. Fill or intentionally omit
each section according to this reference, then run the pre-emit checklist over
the complete packet string. If a required section is not applicable, the header
or owning section must make that clear with `N/A`, bounded scope wording, or
`Pending Verification` as allowed below.

After the packet header, emit only evidence-backed sections in this required order (each top-level section starts at column 1):

- **Proof checked** (optional but recommended when strong local artifacts exist) — bullet list; each bullet ends with or contains `artifact:` pointing to `repo-relative/path:line@head-sha` or an authenticated API result.
- **Finding P0/P1/P2/P3** — one top-level section per formal finding that contributes to a positive count in the packet header. The header lines supply only the summary count and short label. Every counted finding requires its own full structured expansion immediately after the header (or after Proof checked) and before Variance ledger, Residual risk, Plain-language summary, Selected reviewer lenses, or Packet ends. Use exactly this form for each:

  Finding P0: <short unique title>
  - Severity: P0
  - Confidence: HIGH | MEDIUM | LOW
  - Category: <concise category e.g. correctness, data-integrity, security, rollout, maintainability>
  - Location: <primary repo-relative/path:line-range@head-sha, exact PR-body/README/API-field citation, or combined key implementation/docs locations when together they prove the defect>
  - Target relevance: <how the reviewed target introduces, worsens, activates, or newly depends on the condition, plus the direct/protective link to stated intent or invariant>
  - Decision affected: <implementation correctness, merge/deploy, exact Production operation, documentation truth, or other named decision>
  - Problem: <one to three sentences describing the code, prose, workflow, or contract defect at the reviewed head>
  - Impact: <concrete impact on user-visible behavior, data safety, deploy/rollback safety, operator trust, or future maintenance>
  - Evidence:
    - <strongest concrete artifact at the reviewed head>
    - <second concrete artifact at the reviewed head>
    - <optional third artifact when needed to prove the finding>
  - Fix shape: <exact change surface, correction direction, and focused post-fix proof that removes the defect at head>

  Example:

  ```text
  Finding P2: partial-apply inserted_count
  - Severity: P2
  - Confidence: HIGH
  - Category: operator-truth / data-migration run-state
  - Location: backend/internal/pathwayprogressimport/postgres.go:129-131@H
  - Target relevance: The changed apply error path newly persists terminal
    inserted_count from a value that excludes already committed batches, which
    directly violates the PR's exact run-accounting invariant.
  - Decision affected: implementation correctness and merge readiness
  - Problem: On mid-apply failure after one or more batches committed,
    insertCandidates returns (0, err) without counting rows already tagged with
    migration_run_id, and importCandidates overwrites tally.insertCount with
    that 0 before persistTerminalRun.
  - Impact: pathway_progress_import_runs.inserted_count can report 0 for a
    failed run that already mutated content_user_progress; operators can
    misread revert scope, progress, or whether a re-run is a no-op despite
    durable partial inserts.
  - Evidence:
    - postgres.go:129-131@H returns 0 on insertBatchInTx error before
      CountPathwayProgressImportInserts at postgres.go:142-147@H.
    - runner.go:149-152@H assigns tally.insertCount = inserted even when
      err != nil.
    - pathway_progress_import.sql:84-90@H and postgres.go:104-107@H claim
      exact per-run counts via migration_run_id, but the failure path skips the
      count.
  - Fix shape: On batch or interrupt failure, still run
    CountPathwayProgressImportInserts(runID) or track committed batch totals,
    persist that count on the failed terminal run, and add an integration test
    that commits batch 1, fails batch 2, and asserts inserted_count matches
    migration_run_id rows.
  ```

  The title must be short, unique, and specific enough to distinguish the
  finding from nearby issues. The same structure applies for Finding P1,
  Finding P2, and Finding P3. Prefer two or three evidence bullets; add more
  only when the extra artifact proves a distinct part of the claim. Each
  evidence bullet must cite the most precise locator possible, such as
  `path:line@H`, an exact API field, or the command/tool result that proves the
  sentence beside it. Merge duplicate or overlapping findings into the single
  strongest root-cause finding and keep the appropriate severity. Low-value
  nits and pure style observations must not become formal Finding P3 blocks;
  they belong only in the variance ledger or are omitted. Pure rollout,
  first-use, or operator execution evidence gaps are not formal Finding P3
  blocks unless there is also a code, prose, workflow, or contract defect at
  the reviewed head; use `Pending Verification`, `Operator status`, and
  `REH-n` instead.

  A finding is a direct author handoff, not merely a defect label. `Problem`
  names the violated invariant and reachable failure; `Impact` names the
  concrete consequence. Keep `Evidence` to one to three distinct proof bullets
  normally. Keep `Fix shape` to one or two sentences naming the exact code,
  prose, workflow, schema, query, or test surface to change, the required
  behavioral direction, and the focused proof that should pass afterward. It
  must let the author start without rediscovering the issue, but must not
  contain patch code, a full implementation plan, an invented API, or an
  unsupported redesign. When several safe designs could satisfy the invariant,
  state the required outcome and proof instead of choosing one speculatively.
- **Review comments** — conditionally required for default whole-target review.
  Emit it exactly once when one or more formal findings exist, after all formal
  finding blocks and before `CI state:`, `Variance ledger:`, `Residual risk:`,
  `Risk Evidence Handoff:`, and `Plain-language summary:`. Omit it when there
  are zero formal findings. An explicit verdict-only or triage contract forbids
  it. Every review still emits the complete verdict packet; comment-only output
  is invalid.

  The reviewer owns diagnosis, exact public wording, the review event, and the
  exact summary body required to submit that event. Do not ask the parent to
  reconstruct prose from a finding or invent a review summary. Use this shape:

  ```text
  Review comments:
  Review event: REQUEST_CHANGES | COMMENT
  Unanchored findings: none | 2, 4
  Summary:
    | <line>
  Comment C-1:
  - Finding: <1-based formal-finding block ordinal>
  - Anchor JSON: <single-line canonical JSON object>
  - Body:
    | <line>
  ```

  After `Summary:` or `- Body:`, every
  continuation line is a pipe-prefixed UTF-8 literal: two spaces, then `|`,
  then optional remainder. Decode by stripping those two spaces and the `|`,
  then at most one following space. A line that is exactly two spaces and `|`
  is an empty line. Join with `\n`. If the decoded text is non-empty and does
  not already end with `\n`, append exactly one `\n`. A terminal empty
  two-space `|` line is equivalent to that trailing newline, not additive.
  Same-line values such as `- Body: text` are invalid. At least one two-space
  `|` continuation is required, and published Summary and Body bytes must be
  non-empty valid UTF-8.

  `Unanchored findings` is exactly `none` or a comma-space list of unique,
  strictly ascending positive ordinals, such as `2, 4`. Inline `Finding`
  ordinals and unanchored ordinals are disjoint and their union is exactly
  `1..N` for the N formal finding blocks. An unanchored finding must be
  represented in the reviewer-owned Summary; never fabricate an anchor. Inline
  comments appear in finding order. `Body` and `Summary` are exact bytes the
  parent may publish unchanged; prose elsewhere is not a substitute.

  Any P0/P1 finding, anchored or unanchored, selects `REQUEST_CHANGES`.
  P2/P3-only findings select `COMMENT`. Inline bodies for P0/P1 use the
  `(blocking)` decoration; P2/P3 use `(non-blocking)`. The validator enforces
  this severity-to-event and severity-to-decoration mapping.

  The wording and shape of public `Body` and `Summary` values are owned by
  `docs/agents/pr-comment-conventions.md`. Read that file before drafting them.
  `RPPA-011` enforces only deterministic mechanics: the body starts with a
  recognized backticked label and blocking decoration, and public body/summary
  bytes contain no common absolute local path rooted under `/home`, `/Users`,
  `/tmp`, or `/var`, no `file://` URL, and no em dash (U+2014). The reviewer
  owns the remaining semantic rules. The parent does not supply conventions or repair
  wording; ambiguous or non-conforming wording returns to the same reviewer.

  The closing boundary of this section is transport data, not prose. The
  review comments section ends at the first evidence section that follows it, which is
  normally `CI state:`, and the resolution order lives in
  `evals/reviewer/contract-fixtures/canonical-transport.yaml` under
  `fixed_before` and `fixed_before_patterns`. Keep this documented order and
  that contract in agreement.

  Pipe prefixes keep text containing newlines, backticks, `Finding P2:`,
  `REVIEW_SCOPE_ACCEPTED:`, or `Packet ends.` from becoming packet structure.
  Reject raw unprefixed continuation lines, empty Summary or Body bytes,
  invalid UTF-8, malformed anchors, incomplete finding coverage, or an event or
  decoration that disagrees with finding severity.

  Reviewer-to-parent transport always crosses a session boundary, even when
  both agents later publish through the same authenticated GitHub identity.
  Pipe-prefixed literal bodies are therefore mandatory. The parent parses
  those literal blocks once at packet acceptance and retains the exact decoded
  UTF-8 bytes. Before publication it repeats only mutable head, anchor,
  thread/duplicate, authorization, and GitHub-capability checks. It must not
  rebuild literal-block verification for already accepted unchanged bytes.

  `Anchor JSON` uses UTF-8 JSON with keys sorted lexicographically and no
  insignificant whitespace. In that order, it must name `line`, `path`,
  `side`, `start_line`, `start_side`, and `subject_type`; use JSON `null` only for fields that
  do not apply to a file-level or single-line anchor. `path` is a non-empty
  repository-relative path with no parent traversal. A `line` anchor requires a
  positive integer `line` and `LEFT` or `RIGHT` side; its optional positive
  `start_line` must be lower than `line` and requires the same start side. A `file` anchor
  requires all line and side fields to be `null`. The `Review target`
  header binds the target SHA once for the complete packet; do not repeat it in
  each comment.
- **CI state** — when applicable; see above.
- **Variance ledger** — enumerated rows; see above. The label
  `Variance ledger:` is a header field and must appear on exactly one
  column-one line in the whole packet. Its numbered rows follow that field's
  position in the section order and carry no repeated `Variance ledger:` label
  of their own. Emitting the label twice, once as the header field and again as
  a section heading above row 1, fails `RPPA-010`.
- **Residual risk** — only for material, plausible, non-central gaps such as
  unobserved rollout or operator execution, scale or performance risk, or a
  partially sampled high-risk surface. Do not hide material reachable risk here,
  and do not pad it with low-value nits, doc drift, or style observations. Omit
  the section when a formal finding or `Pending Verification` entry already
  tracks the gap.
- **Plain-language summary** — required for parser-facing reviewer packets.
  Emit `Plain-language summary:` as a top-level section after formal findings,
  CI, variance ledger, residual risk, and REH, and before
  `Selected reviewer lenses:`. It gives the human reader a concise explanation
  of what changed, why the verdict is what it is, and what remains. Keep it to
  one to three bullets or sentences. It must not introduce new evidence, new
  findings, a second verdict, merge advice, or claims not already represented by
  packet fields and artifacts. It must not soften, narrow, or contradict the
  `Verdict:`, `Pending Verification:`, `Would flip verdict if:`, `Next owner:`,
  formal findings, residual risk, or REH fields. It must not appear after
  `Packet ends.`.
- **Selected reviewer lenses** — required for parser-facing reviewer packets.
  List each loaded lens with its current-target trigger, the concrete PR surface
  covered, and its finding, verified-clean, rejected-candidate, or
  `Pending Verification` disposition. Use `Scope basis` and `Coverage` to name
  the admitted inventory, proved impact cone, evidence-backed expansions, and
  explicitly unreviewed surfaces. Then add a `Not loaded:` subsection with a
  short reason for skipped common lenses. When
  production blast-radius or rollout evidence matters, a loaded
  migration-safety or SQL lens row must name the rollout/schema/operator contract
  surface reviewed and whether Postgres migration files under
  `backend/internal/shared/sql/migrations/` changed in this PR. When those
  migration files did not change, say so explicitly in the lens row or in
  `Not loaded:` rather than implying migration review happened.
- **Top-level packet sections** — `Plain-language summary:`,
  `Selected reviewer lenses:`, `Not loaded:`, and `Packet ends.` must each
  start at column 1. `Not loaded:` is a sibling subsection after the selected
  lens rows, not a bullet nested under the final lens. `Packet ends.` is the
  final top-level line, never a bullet and never indented.
- **Higher-level response rules** — when this packet is required, the packet
  shape is the reviewer session's final answer to the parent. The parent's
  bounded user-facing closeout remains governed by the serialization boundary
  above. Do not append memory citation blocks,
  ordinary assistant summaries, validation footers, self-correction notes, or
  any other framework-required prose after `Packet ends.`. If another runtime
  instruction would normally require a footer or final summary, avoid relying on
  that source for packet evidence or keep the information inside an allowed
  packet field before the terminator.
- **Memory boundary** — parser-facing PR review packets are current-evidence
  artifacts. Do not consult memory for packet content, workflow selection,
  verdict rationale, prior thread state, or validation claims unless the user
  explicitly asks for historical comparison. Memory-derived facts are not packet
  evidence and must not create a citation-footer obligation.
- **Would flip verdict if** — use only the header field. Do not add a second
  section with different wording.

Do not add a separate human recommendation section such as "approve for merge"
after the packet. The verdict, findings, and `Plain-language summary:` section
carry the human-readable merge posture.

## Risk Evidence Handoff

For P0/P1 findings, production-impact P2 findings, and BLOCKED verdicts where
live, operational, owner, or specialist evidence could change the verdict, emit
this named-field list after detailed findings:

```text
Risk Evidence Handoff:
REH-1:
- Severity: <P0-P2>
- Concern: <failure mode>
- Question for author/parent: <specific question>
- Evidence needed: <artifact or proof>
- Suggested evidence lane: <lane or owner>
- Do-not-run boundary: <safety limit>
- Verdict impact: <verdict effect>
```

### REH List Rules

- **No Markdown tables**: REH must use `REH-n:` blocks with named fields.
  Markdown table rows are invalid because CLI transport can split or truncate
  values.
- **One complete block per REH gate**: Each `REH-n:` block must include exactly
  one `Severity:`, `Concern:`, `Question for author/parent:`, `Evidence
  needed:`, `Suggested evidence lane:`, `Do-not-run boundary:`, and `Verdict
  impact:` field. A block that stops mid-field or omits a required field is
  invalid.
- **Contiguous named fields**: Do not put blank lines inside an `REH-n:` block.
  The seven named fields must immediately follow the `REH-n:` line as
  contiguous parser-facing lines.
- **Readable fields before aggressive compaction**: Write REH fields in plain
  prose first. Use the header `Head alias` and `@H` references before replacing
  spaces with underscores or other mangling. Underscore-compacted text that is
  hard to audit is a transport failure, not a compliance win.
- **Database-mutating runs**: For database-mutating, migration, backfill, or
  data-importing runs, the required `Evidence needed:` field must specify:
  `Staging capped execution logs for the reviewed mode at head_sha=H, run status, cap values, timeout config relevant to that mode, terminal completion/failure state, and absence of hang/error signals.`
  (referencing head alias `H`).
- **No-production boundary**: Database-mutating or data-importing runs must
  explicitly enforce a do-not-run boundary on production until staging evidence
  is verified.
- **Staging-only unblock clarity**: When merge is blocked only for staging
  execution evidence, the `Verdict impact:` field must say that staging-only
  evidence can unblock merge and that production full execution remains a
  post-merge operator handoff unless production proof is required pre-merge.

## Trigger Words

Search the entire final text for trigger words before emit. Non-label occurrences
must be immediately followed by `source:` or `artifact:` proving that exact
clause.

Common parser triggers include: `success`, `green`, `passed`, `fresh`,
`resolved`, `addressed`, `verified`, `complete`, `coverage`, `mitigated`, `rare`,
`safe`, `tight`, `correct`, `approve`.

Required packet field labels (`Verdict:`, `Review mode:`, etc.) are exempt from
the per-word rule only for the label itself, not for unqualified claims in the
value side. Prefer `Code-review status: bounded artifact: ...` over bare
`complete` without proof.

Disposition values must use the machine-safe token table above, not English
verbs that contain trigger substrings.

## Parent Packet Admission

The reviewer owns packet semantics; the parent owns mechanical admission. A
returned packet is not accepted merely because it looks complete or claims
conformance. The parent validates the exact returned bytes against trusted
dispatch inputs before sibling join, bounded closeout, publication, or any
packet-compliance claim.

Use the repository validator rather than reconstructing this checklist in a
prompt or parent response:

```bash
scripts/dev/validate-review-packet.rb \
  --packet <reviewer-return-file-or-dash> \
  --expected-target '<exact Review target value fixed at dispatch>' \
  --expected-mode FULL \
  --review-comments required_if_findings
```

`--packet -` reads stdin. `--review-comments` accepts
`required_if_findings`, `optional`, or `forbidden`; the parent fixes that value
at dispatch. Default whole-target review uses `required_if_findings`; explicit
verdict-only or triage review uses `forbidden`. Packet content cannot select or
weaken the trusted target, mode, or output contract.
The version 3 JSON result records the source-byte digest, extracted
canonical-packet digest, transport kind, trusted inputs, decision, failed rule
IDs, and `review_comments_payload`. For an accepted finding-bearing packet,
that payload contains the selected review event plus exact decoded UTF-8
summary and comment bodies. Rejected and clean packets return no publishable
payload, so unaccepted bytes cannot reach GitHub. Raw and exact fenced
transport containing identical packet bytes share the canonical packet digest
while retaining different source-byte digests. These locally calculated whole-
packet digests are validator diagnostics, never model-emitted packet fields or
an extra reviewer step.

The deterministic rule inventory is versioned by these stable IDs:

- `RPPA-001`: exactly one unambiguous raw packet or fenced `text` packet, with
  no prose outside it;
- `RPPA-002`: `Verdict:` is first and mandatory header fields exist in order;
- `RPPA-003`: `Review target:` and `Review mode:` exactly match trusted inputs;
- `RPPA-004`: header finding counts match formal finding blocks;
- `RPPA-005`: every formal finding has the required ordered fields;
- `RPPA-006`: required packet sections occur in canonical order;
- `RPPA-007`: `Packet ends.` occurs once as the final logical packet line;
- `RPPA-008`: review-comment presence follows the trusted output contract and
  formal finding count;
- `RPPA-009`: review event, summary, body, anchor, literal-block, ordinal
  partition, and severity mapping integrity holds; and
- `RPPA-010`: singleton fields and sections are not duplicated or ambiguous;
  in particular `Variance ledger:` appears exactly once, as the header field,
  with its numbered rows following it directly and no repeated section label;
  and
- `RPPA-011`: every inline body starts with a recognized backticked
  Conventional Comment label and blocking decoration, and no inline body or
  Summary contains a common absolute local path rooted under `/home`,
  `/Users`, `/tmp`, or `/var`, a `file://` URL, or an em dash (U+2014).

These checks are deliberately mechanical. They do not judge whether a finding
is true, whether evidence is persuasive, whether severity is correct, or
whether a verdict follows from the code. Those remain reviewer-owned semantic
decisions. The lifecycle and bounded repair protocol are owned solely by
`work-orchestration/references/review-control-plane.md`; consumers must
link there rather than create another acceptance or retry contract.

## Closeout

- Parser-facing output must start with `Verdict:` or with a single fenced
  `text` block whose first packet line is `Verdict:`.
- No prose, apology, status recap, findings summary, or self-correction note
  may appear before the packet.
- Parser-facing output must end with exactly: `Packet ends.`
- No text, summary, recommendation, self-audit, or follow-up may appear after
  that line.
- No memory citation block, source list, "plain-language" addendum, or
  runtime-required footer may appear after that line.
- Do not append "approve for merge", "LGTM", or broad self-certification after
  the packet.

## Pre-Emit Checklist

Before running the numbered checks, reject any draft that is a normal prose or
Markdown code-review summary instead of the canonical packet. Correct findings
inside the wrong shape still fail the packet contract.

1. Verdict line includes `artifact:`.
2. P finding counts match body, residual risk, and `Pending Verification`. If `P2/P3 findings: 0` and no central operator or PV gaps affect merge posture, the verdict must be `PASS`, not `PASS_WITH_FINDINGS`. Contradictory combinations, such as `PASS_WITH_FINDINGS` with zero findings, Residual Risk `N/A`, and `Next owner: none` while central PV gaps are listed, are forbidden. If any P1 REH gate is open, the verdict must be `BLOCKED`, and the `P0/P1 findings:` header field must explicitly qualify code findings vs REH gates (e.g., `0 code findings; 1 P1 REH gate`).
3. For every positive count in the `P0/P1 findings:` or `P2/P3 findings:` header line there exists one or more top-level "Finding P0: <title>", "Finding P1: <title>", etc. blocks immediately after the header (following Proof checked if present) that use the exact structured fields defined in the Proof Blocks section. A count without the corresponding detailed Finding block(s), a finding without a unique title, or a finding that uses the older loose summary shape is a packet defect.
   For default whole-target review, positive counts require one `Review
   comments:` section. Inline and unanchored finding ordinals partition every
   formal finding exactly once, and the section contains one selected event and
   one pipe-prefixed UTF-8 literal Summary. Missing summary bytes invalidate the
   packet.
4. Central blocking execution or rollout evidence gaps for database-mutating, data-integrity, import, reconciliation, or migration-gate paths result in `P2/P3 findings: 0` in the header. They appear only under `Pending Verification` and `Operator status` (and `REH-n` when P1), using the canonical phrasing "Staging capped execution logs for the reviewed mode at head_sha=H, run status, cap values, timeout config relevant to that mode, terminal completion/failure state, and absence of hang/error signals." When the PR body, README, runbook, or workflow contains exact bounded canary commands or job names, the evidence request should ask the owner to run that bounded lane, capture the run ID, final status, relevant counts, cap/rollback/timeout behavior, sample exception rows when applicable, wall time, and confirmation that protected/core tables were not mutated when that is part of the contract, then add the artifact to the appropriate staging-evidence section. The header never increments the formal P count for pure gaps; the P0/P1 line uses the qualified form when needed. A formal Finding P3 block is used only when there is also a code, prose, workflow, or contract defect at the head.
5. `Next owner` matches open findings and operator-scope gaps. `Next owner: none` is only valid when there are zero P0-P3 findings, no unresolved actionable variance ledger rows, and no central rollout/PV gaps.
6. Every fetched prior artifact, including review summaries, empty-body reviews, and inline comments, has its own individually numbered variance ledger row, or the `Variance ledger:` header uses bounded wording that exactly names the enumerated subset while `Pending Verification` lists the omitted object count and IDs. No grouped rows or "additional follow the same" sentences appear after an enumeration claim.
7. For summary, informational, or empty-body review objects, `current-code artifact` is omitted or cites only review object metadata such as `review_id`, `submittedAt`, and commit. Use `disposition=out_of_scope`. No `=N/A` values appear in any `current-code artifact` field.
8. All code, thread-mapping, and status artifacts, including every `path:line@sha` and every CI `head_sha`, derive from one single consistent live head SHA. Mixed-SHA evidence is not present.
9. CI rows name run_id, head_sha, source; conclusion occurrences include immediate `artifact:` when required by the parser.
   API-derived values in CI rows, variance rows, and header artifacts must be
   copied from the current tool output or command result, then rechecked before
   emit. Do not reconstruct SHAs, run IDs, review IDs, URLs, or
   conclusion/status values by hand from memory. If a value cannot be
   rechecked, omit the optional row or mark the exact field
   `Pending Verification`; do not emit malformed evidence.
10. Operator status, if present, cites exact PR body section names, exact README line ranges or field names, or exact tool/API results with parameters. Narrative claims such as "complete for reviewer scope" are not used.
11. Confidence artifact proves the actual inspection scope performed in the session, such as specific API fetches at a named `ref@sha` or command output. CI success alone does not justify `HIGH` when local validation was not executed. Static-only reviews with no session-run tests, build, or reproduction cap `Confidence` at `MEDIUM`, as does a `Pending Verification` rollout or runtime gap that bears on the change.
12. `Would flip verdict if` names the smallest concrete observable condition at the reviewed head, such as a specific workflow at a named `headSha` returning non-success, or a new thread on named logic with no mitigation at `path:line@sha`. For a verification or rollout gap it names both the clearing evidence and the escalation failure in one line. When a separate P2/P3 finding remains alongside an open P1 REH gate, clearing the REH gate can only flip BLOCKED to PASS_WITH_FINDINGS with the lower-severity finding still counted; fixing that finding is a separate condition. Tautological phrasing such as "if a defect exists" is not used.
13. No low-value nit is a formal finding or a residual-risk line. Cleanup, naming, redundancy, doc-drift, or ownership-ambiguity observations are formal only when the current head is already wrong or a reachable path fails today; speculative future risk is omitted. Review objects use `review_id=`, never `comment_id=<review id>`. Finding `Location:` is a bare artifact locator with no narrative or field-name prefix, and header doc/runbook artifacts reuse the most precise locator already in the packet.
14. Full-text trigger-word scan completed.
15. Central blocking execution or rollout evidence gaps that require a P1 REH gate are never counted or filed as formal P2 or P3 findings in the packet header; the P2/P3 findings count is 0 when the only open gaps are those tracked exclusively in Pending Verification + REH-n (with the P0/P1 line qualifying "0 code findings; 1 P1 REH gate").
16. The variance ledger section after any "Variance ledger: enumerated below" claim consists solely of individually numbered rows (one per fetched artifact) with no grouping, no "multiple ... objects", no "additional follow the same pattern", and no summary language. Any unenumerated subset of low-signal fetched artifacts is described exactly with count and IDs in the Pending Verification header field, and the variance header uses bounded wording instead of claiming full enumeration.
17. **Transport and Serialization Self-Check**:
    Before final emit, scan the packet string for inserted newlines, not for
    terminal display wrapping, which is not a violation:
    - reject if any required header line starts with whitespace
    - reject if `Packet ends.` is not exactly the final packet line
    - reject if any line ends with `-` followed by a continuation line beginning with a line number, SHA, URL tail, or `>`
    - reject if a `source=` value or a `current-code artifact=` value is broken across two physical lines
    - reject if any `current-code artifact=` line lacks `@<40-char-sha>` before the newline
    - prefer raw contiguous text for CLI output; use one fenced `text` block only when the channel needs it to preserve packet rows
    - never use a `markdown` fence for the packet
    - when `Review comments:` exists, reject raw unprefixed body or summary
      text, missing two-space `|` continuations, empty Summary/Body bytes,
      invalid UTF-8, non-canonical anchor JSON, incomplete or overlapping
      finding ordinals, or event/decoration disagreement with severity
18. Final logical packet line is exactly `Packet ends.` with nothing after it;
    no memory citation block, ordinary final-answer summary, validation footer,
    self-audit, or any other framework-required prose follows it.
19. Risk Evidence Handoff uses `REH-n:` named-field blocks, not Markdown tables. Each block includes `Severity:`, `Concern:`, `Question for author/parent:`, `Evidence needed:`, `Suggested evidence lane:`, `Do-not-run boundary:`, and `Verdict impact:` exactly once with no blank lines between those named fields.
20. For database-mutating runs, `Evidence needed:` specifies: `Staging capped execution logs for the reviewed mode at head_sha=H, run status, cap values, timeout config relevant to that mode, terminal completion/failure state, and absence of hang/error signals.`, and `Do-not-run boundary:` enforces the no-production boundary.
21. `Plain-language summary:` appears before `Selected reviewer lenses:` and `Packet ends.`, is top-level, and contains only one to three concise bullets or sentences restating packet-backed facts. It must not introduce new evidence, findings, verdicts, merge advice, or follow-up work not already represented in the packet, and it must not soften or contradict `Verdict:`, `Pending Verification:`, `Would flip verdict if:`, `Next owner:`, formal findings, residual risk, or REH fields.
22. `Selected reviewer lenses:` appears before `Packet ends.`, lists each loaded lens with its current-target trigger, concrete PR surface, and disposition, includes top-level `Not loaded:` reasons for skipped common lenses, and names migration/rollout contract surfaces when blast-radius review applies. `Scope basis` and `Coverage` account for the admitted inventory, proved impact cone, evidence-backed expansions, and explicitly unreviewed surfaces. `Plain-language summary:`, `Selected reviewer lenses:`, `Not loaded:`, and `Packet ends.` each start at column 1.
23. Before emit, scan the raw packet string for malformed REH blocks: reject Markdown tables, missing named fields, duplicated field labels inside one `REH-n:` block, or any field that is cut off mid-value.
24. The header `Variance ledger:` value is consistent with the row set and the `Pending Verification` omission item. `enumerated below` appears only when every fetched artifact has its own row; when a class is omitted, the header uses bounded wording naming enumerated vs omitted, and the exact omitted count and IDs are in `Pending Verification`.
25. Every local file artifact carries `:line` or `:start-end` (including migrations and stubs), and each cited range was re-verified at the reviewed head immediately before emit rather than recalled from an earlier read. Doc/runbook artifacts cite the exact command/example/table block proving the claim, not adjacent prose.
26. Packet content, workflow route, verdict rationale, prior-thread state, and
    validation claims are derived from current repo/GitHub artifacts, not
    memory, prior-session summaries, copied packets, or hidden conversation
    state. If memory was consulted accidentally, restart the packet evidence
    pass from current artifacts and omit memory-derived claims.
