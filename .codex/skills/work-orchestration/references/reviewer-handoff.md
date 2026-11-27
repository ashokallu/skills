<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (same-response minimal review comments) -->

# Reviewer Handoff

```text
Type: owning lane
Use when: `review-routing`/`delegation` or a specialist workflow has selected a separate
          reviewer session
Skip when: the current agent is directly reviewing a local target without a handoff, or
           the PR workflow already supplies a stricter packet
Owns: construction and delivery of a factual, neutral packet to a separately selected
      reviewer
Does not own: review routing, the verdict, fixes, or publication
Allowed side effects: packet delivery to the already authorized reviewer; secret-safe
                      local artifact only when the owning workflow authorizes that write
Inputs: review owner, stable target, objective/acceptance, changed boundary, validation,
        known gaps, and prior findings when applicable
Exit states: delivered, blocked, stale, rejected
Outputs: target-bound reviewer packet and parent acceptance checks
Re-enter when: target, finding lineage, validation, or review purpose changes
```

Do not load or use this reference merely because the user asks the current
agent to review working-directory changes, a local diff, branch, commit, or
named files. That path is current-agent owned through `reviewer`.

## Mission

Give a reviewer enough factual context to understand the claimed intent while
preserving independent judgment. Author intent aims inspection; it is not proof.
Current source, diff, generated artifacts, config, tests, runtime wiring, and
live metadata remain authoritative.

Use the shared
[`review-control-plane`](review-control-plane.md) vocabulary for assignment
depth, topology, scope acceptance or escalation, target-change classification,
and parent-only join categories. This lane remains the transport and
append-only-ledger owner. The companion does not take over delivery, session
provenance, packet acceptance, review judgment, or final serialization.

## Select The Intent Source

- **Open teammate PR:** use the live PR body as the author-provided narrative.
  Do not improve it silently. Mark thin, stale, or missing intent/non-goals/
  risk/validation `Pending Verification`.
- **Own pre-open branch:** use a compact factual packet derived from the user
  request, accepted objective, protected invariants, non-goals, changed files,
  and validation. Do not pass an unpublished PR-body draft to the unbiased
  reviewer.
- **Commit/branch/follow-up without PR body:** use only facts actually known;
  mark missing acceptance or non-goals when material.

When sources conflict, preserve the conflict. Do not choose the narrative most
favorable to the change.

Do not impose a retroactive objective lock on teammate/open PR review. Keep the
live PR body as stated intent and surface missing or conflicting intent as
`Pending Verification`. Objective locking governs the parent's own planned
implementation; it does not reconstruct another author's private planning
history.

## Own-Work Conformance Admission

For parent-authored pre-open branches, commits, staged/local diffs, and
follow-ups, require the exact final target-bound attestation from
[orchestration-conformance](orchestration-conformance.md). It must be the
version reconciled by `authoring-preflight` against the stable target, accepted
findings, and append-only scope-delta ledger. A pre-code-only, missing, stale,
contradictory, or unsupported attestation blocks delivery to a mandatory own-work
reviewer.

The reviewer verifies the attestation independently and may ask the parent for
the smallest decision-changing evidence. The reviewer must not fill the
attestation, request governing-source paths or hashes, infer a
safer objective, or convert missing authoring provenance into a new product
requirement.

## Session Provenance And Neutrality

Classify the reviewer session:

- **fresh:** new process/subagent/thread with no prior review context;
- **reused:** the same reviewer session continues its own prior review;
- **context-contaminated:** a nominally new reviewer inherited author findings,
  preferred focus, expected verdict, or prior conclusions.

For a fresh independent review, include only the factual target packet,
required instructions, current intent source, validation, and known gaps. Do
not call it “final,” “last,” “confirmation,” or “one more.” Do not disclose
preferred fixes, prior reviewer conclusions, author self-review findings, or
the verdict expected.

When the author ran the author self-review gate, freshness requires isolation across every reviewer-visible input, not only neutral prompt wording. Use a
verified new-session mechanism that inherits zero author turns, context files,
handoff artifacts, or tool/session state. A new identity with inherited author
context is `context-contaminated`, not fresh.

For a reused session, provide the new target plus that reviewer’s own prior
findings and ask it to verify the fix and inspect residual risk. Context from
other reviewers is supplied only for explicit conflict resolution.

A context-contaminated pass is advisory and does not satisfy a required fresh
independent gate unless the owning workflow or user explicitly accepts that
limitation.

## Required Packet

```text
Reviewer handoff:
- target type: PR | pre-open branch | local/staged diff | commit | follow-up
- exact target: PR + live head/base | base...head | commit SHA | explicit files
- target freshness: as-of time and source
- review intent source: live PR body | factual intent packet | user request |
  Pending Verification
- stated outcome and acceptance:
- orchestration conformance: teammate-PR exemption | <final attestation ID, status, and exact target identity>
- objective lock: not required | <id@version> | teammate-PR exemption
- protected invariants:
- in-scope / non-goals:
- changed contracts: API/data/flags/generated/workflow/runtime/operator
- risk and operator impact:
- current changed-file inventory:
- validation already run:
- known gaps / Pending Verification:
- allowed evidence sources: <phase-specific exact list>
- forbidden evidence sources and execution: <phase-specific exact list>
- required reviewer instructions: <mandatory phase and role paths>
- reviewer phase contract: load `review-bootstrap.md` before evidence, `review-analysis-routing.md` after stable target/inventory, and `review-verdict-closeout.md` before verdict
- final output contract: canonical packet with conditional review comments | verdict-only canonical packet
- session provenance: fresh | reused | context-contaminated
- reviewer context isolation: <zero-history mechanism and excluded author-context channels | reused: provenance-bound context | context-contaminated>
- review scope proposal: <separate REVIEW_SCOPE_PROPOSAL artifact using review-control-plane | not separate>
- reviewer ask: understand intent, inspect surrounding source, then return
  findings-first verdict with evidence
```

The packet must not contain parent verdict labels, desired conclusion, broad
preferred focus, implementation advocacy, or private chain-of-thought.

Every output contract retains the reviewer's complete mandatory verdict packet.
Default whole-target PR review uses `canonical packet with conditional review
comments`: when formal findings exist, the same response adds the minimal
`Review comments:` section; a clean review omits it. Use `verdict-only canonical
packet` only for an explicitly verdict-only or triage assignment. The reviewer
owns finding-to-comment semantics, summary semantics, the selected event, and
exact literal bytes. The parent owns only the one-time mechanical acceptance,
mutable GitHub-state, publication, and readback checks in
`review-control-plane.md`.

For ordinary PR review, set the allowed evidence sources to local Git and file
inspection, checked-in artifacts according to their provenance, GitHub PR
metadata, reviews, threads, and head-pinned CI metadata. Set the forbidden
sources to live runtimes, Staging, Production, Cloud SQL, Mongo, logging,
monitoring, Sentry, browsers, and all other environment state, even read-only.
Also forbid tests, builds, migrations, smoke checks, collectors, reproduction,
and other validation execution. Both reviewers inherit this ceiling. Generic
reviewer evidence lanes cannot widen it. Missing current proof remains
claim-specific `Pending Verification`; a live read requires a separately
user-requested phase and fresh classification.

The scope proposal is assignment control, not a final verdict-packet field.
Deliver the reviewer's `REVIEW_SCOPE_ACCEPTED` or
`REVIEW_SCOPE_ESCALATION` response separately. Record one
`SCOPE_EVIDENCE_CORRECTION` at most. If the reviewer still rejects the
narrowing, preserve `SCOPE_DISPUTE_BLOCKED`, route the exact claim through
`conflict-resolution`, and keep evidence-heavy analysis under that narrowing
blocked.

## Mandatory Reviewer Instructions

Always include the mandatory bootstrap, analysis-routing, and verdict-closeout
paths. The mandatory phase order is `review-bootstrap.md`, then
`review-analysis-routing.md`, then `review-verdict-closeout.md`. Missing a
mandatory phase blocks substantive verdict emission.

If a required path or contract cannot be supplied, block the mandatory review
or mark the exact limitation under the owning workflow. Do not fabricate or
paraphrase required agreement text from memory.

## Database Reviewer Addendum

When `database-review-applicability` returns `required`, attach its immutable
packet. For ordinary PR review, attach checked-in evidence and exact gaps
without refreshing live state:

```text
Database environment scope:
Static evidence ceiling:
Checked-in evidence artifact and digest:
Observed at / valid until:
Schema/collector validation:
Invalidation checks:
Omitted relations or inaccessible fields:
Claim-specific state: usable historical evidence | expired | invalidated | Pending Verification
```

The ordinary reviewer should remain autonomous and should not receive a desired
conclusion from the database sibling. The parent joins both verdicts.

The database sibling receives the same `final output contract` as the ordinary
sibling for this dispatch. When it has findings, its minimal pipe-prefixed
review-comment section rides on that first dispatch. The parent must not translate a database
finding into new prose. If both siblings have review comments, the
parent follows `review-control-plane.md` and submits their mechanically accepted
union through one review event, never one event per sibling.

## Progress Requests

Successful ordinary or database reviewer dispatch activates the internal
`REVIEW_ACTIVE` lifecycle state from `review-control-plane.md`. It creates no
extra packet or progress emission. Waiting and review control become the
parent's critical path until that state reaches its governed terminal
transition.

If a reviewer remains active long enough that coordination state is useful,
request the pull-based `REVIEW_PROGRESS:` control response from
`review-control-plane.md` before asking about closeout. Do not ask the reviewer
to finish merely because it is still running. Do not request periodic updates,
repeat an unchanged request, turn its optional time band into a deadline, or
perform the reviewer's semantic work in parallel.

The parent may continue only bounded, non-overlapping orchestration work:
target and PR freshness, thread and CI inventory, database applicability,
required evidence preparation, authorization state, and join/readback
preparation. Each action is bounded by purpose and effect to that output; none
permits partial, supporting, spot-check, or relabeled semantic review. When no
such action is needed, the parent waits. An incidental semantic concern goes
factually to the active reviewer or scope-control path. A semantic contradiction
or deficient review comment goes back to the same reviewer with exact evidence.

## Dispatch And Resume Economy

Resuming a reviewer replays accumulated context and can repeat expensive work.
Set the complete final output contract in the first dispatch. Default
whole-target PR review, including a required database sibling, requests the
canonical packet with conditional same-response review comments. Clean reviews
carry no comment section. Do not request digest triples, base64 bodies, or a
second comment-only turn. Narrow metadata, thread, or CI reads do not dispatch a reviewer.

Resume is for semantic repair of content the reviewer already returned, a
provenance-bound scoped re-review, or a pull-based `REVIEW_PROGRESS:` response.
A finding-bearing packet missing valid review comments receives one consolidated
packet repair in the same session. Do not request a body-only response or start
a fresh reviewer. Report an actual economy
violation in one concise closeout line and include measured avoidable
invocations, tool calls, tokens, or elapsed time only when available. Never
estimate a cost or emit a new violation packet.

The parent owns one timestamped, head-bound dispatch snapshot containing PR
identity, title/body/author, base and head refs/SHAs, existing reviews,
comments, threads and resolution state, and head-pinned CI/check metadata. Pass
that same immutable snapshot to the ordinary reviewer and required database
sibling. A reviewer reuses it and fetches remote evidence only when a mandatory
field is absent, provenance or head binding is invalid, current evidence proves
a head/state mismatch, or one specifically named artifact is required for
packet completeness. The reviewer must name that trigger. The parent alone
refreshes live head, thread, duplicate, and CI state for final join or the
pre-write guard and performs post-write readback.

The reviewer emits one packet to the parent. The parent accepts it once and
must not paste it into commentary or repeat it in later turns. It reports a
bounded verdict, findings, current state, and gaps by default. Forward the exact
packet once only when the user explicitly asks for the packet itself.

## Append-Only Review-Round Ledger

The parent owns one ledger for each requested outcome lineage. Keep its
`action_item_id` stable until the user explicitly changes the outcome. Keep the
objective reference separate from the subordinate production mechanism scope;
changing either never resets or removes review history.

```text
Review-round ledger:
- action_item_id: <stable requested-outcome lineage>
- current_objective_ref: <lock-id@v<objective-version> | teammate-pr:<current-intent-ref>>
- current_mechanism_scope: <objective-key>/mechanisms@v<version> | not applicable
- broad_round_count_overall: <append-only count across objective and mechanism revisions>
- broad_rounds: <round, objective ref, mechanism scope, target, participants, result>
- targeted_followups: <boundary lineage ID and contract, objective ref, mechanism scope, target, fix delta, result, same-boundary failed count, recovery artifact>
- objective_or_mechanism_resets: <from/to refs, reason, keep/defer/remove ledger, author self-audit evidence, validation evidence>
- last_target: <exact target>
- next_dispatch_classification: <validation/readback | targeted | broad> + <justification>
```

For owned work, `current_objective_ref` is the objective key and
`current_mechanism_scope` is its exact subordinate key when Production-Ready
Scope activated. For teammate PR review, do not manufacture either authoring
key: use the current live PR intent/head as `teammate-pr:<current-intent-ref>`
and mark mechanism scope `not applicable` unless the PR itself supplies that
artifact. Review task-time necessity analysis remains authoritative.

The ordinary reviewer and conditionally required database reviewer dispatched
in parallel against one target count as one broad round. Any full cumulative
target or multi-domain independent residual review is broad regardless of
model or harness count. A targeted follow-up covers one materially changed
correctness boundary and its fix delta without another full residual sweep.

A target change invalidates exact-target conclusions, not the entire review
strategy. Classify the delta:

- wording, formatting, comments, or semantically unchanged generated output:
  validation and direct readback only
- one changed correctness boundary in runtime behavior, schema/data, auth or
  privacy, transactions or concurrency, public contracts, production config or
  deploy behavior, or operator decisions: targeted follow-up
- multi-domain or global invalidation: broad follow-up when the ledger explains
  why targeted review is insufficient

### Targeted follow-up circuit breaker

Identify a correctness-boundary lineage by its stable invariant or side-effect
edge and owning surface, not by a finding label, filename, objective version,
or mechanism version. Renaming, moving, splitting, or merging descriptions of
the same failure mechanism retains the original lineage and append-only
history. When two lineages cannot be distinguished safely, classify the impact
as broad instead of manufacturing a new identifier.

Increment `same-boundary failed count` only when a material outcome remains,
regresses, or introduces the same failure mechanism inside the proved impact
cone. Validation or tool failure, reviewer unavailability, `Pending
Verification`, and unrelated or outside-cone findings do not increment it. A
resolved result appends a disposition but never erases history. An unrelated
finding opens its own lineage and selects broad review when it expands the
impact cone or invalidates multiple domains.

After the second same-boundary failure, set the next state to
`AUTHORING_RESET_REQUIRED` and stop reviewer redispatch. Do not automatically
request either targeted or broad review. The parent must first record a
recovery artifact containing the rebuilt failure model, bounded sibling-code-
path search inside the impact cone, focused proof, complete accepted-finding
batch, and explicit next classification.

After recovery, one still-bounded boundary with adequate proof may receive
another targeted follow-up against the same lineage and non-resetting count.
An expanded cone or multiple invalidated domains selects the existing broad
path. If proof remains unavailable or the safety model remains incomplete,
record `Pending Verification` and block or escalate to the owner; do not
redispatch. Any later same-boundary failure increments the same count and
returns immediately to `AUTHORING_RESET_REQUIRED`.

Before the third broad round overall, produce a keep/defer/remove mechanism
ledger, record any `objective_or_mechanism_resets` entry, rerun author
self-audit and validation, and justify why another broad round remains
necessary. Each kept mechanism must directly satisfy an existing acceptance
criterion, be required by a mandatory current contract, or be `protective`
with a named invariant and current causal evidence. The ledger and rerun proof
are the circuit breaker. Do not use a new objective or mechanism version to
evade the append-only review history.

### Scoped re-review provenance addendum

When `pr-workflow` selects its scoped re-review lane, reused provenance
must bind the exact reviewer thread or tool-session identifier, prior target
`H0`, new target `H1`, successful ancestry artifact, immutable prior result plus
digest or artifact ID, stable IDs for that reviewer's own findings, exact fix
commit or range, parent resolution explanation, and validation artifacts. A
nickname, role, model, session alias, or similarly named process is not enough.

The parent must create and preserve the ancestral finding-directed fix commit
or exact range before this handoff. Do not amend or rewrite the reviewed target
to manufacture a compact delta. If ancestry or an exclusively mapped fix range
cannot be proved, do not reuse the reviewer; dispatch a fresh full review.

The reused reviewer retains only its own finding context and resets its
conclusion. Its output must follow the non-packet `Re-review result:` contract
from `pr-workflow/references/re-review-worktree.md` and must state
`Whole-PR signoff: not granted`. Missing or ambiguous provenance, a
non-ancestral target, unrelated edits, or an unbounded impact cone selects a
fresh full review instead. A fresh neutral reviewer never receives this
addendum or any prior-finding summary.

## Tool Delivery

- **Native reviewer:** pass the full packet in the prompt or a validated
  secret-safe artifact the runtime can read.
- **Codex helper:** use a supported context channel when verified. When custom
  context is unsupported, run the exact-target helper and use a native/manual
  follow-up for intent-specific judgment; mark the limitation.
- **External tool/harness:** use its supported context transport. Validate
  artifact pointers, scope, expiry, and sensitivity before delivery.

Do not assume a path is readable across worktrees/harnesses. Do not put secrets,
cookies, tokens, private payloads, or machine-local auth state into the packet.

Packet return is not packet acceptance. Apply the exact-target
`RETURNED -> VALIDATING -> ACCEPTED | REJECTED` lifecycle and private result
or repair schemas from
`work-orchestration/references/review-control-plane.md`. Run the shared
validator named by `docs/agents/pr-review-packet-format.md` with the trusted
target, review mode, and review-comments policy from this handoff:
`verdict-only canonical packet` maps to `--review-comments forbidden`;
`canonical packet with conditional review comments` maps to
`--review-comments required_if_findings`. Do not accept a reviewer's prose
compliance claim, reconstruct its packet, or join, close out, or publish a
`REJECTED` result.

## Parent Acceptance Checks

Before dispatch:

- exact target/base/head and changed-file inventory are current;
- packet is neutral and conclusion-free;
- mandatory instructions are complete;
- side-effect boundary is read-only;
- database/specialist applicability is attached when required;
- fresh-session isolation is real when independence is mandatory.

After return:

- transition the exact returned bytes through `RETURNED -> VALIDATING` and
  run the canonical shared validator against the target, mode, and output
  contract fixed before dispatch; only its `ACCEPTED` result proves
  mechanical packet compliance;
- verify that any separate scope-control exchange reached an accepted terminal
  state and never entered the final verdict packet;
- reject a result when an admitted surface lacks a disposition, a mandatory or
  evidence-triggered lens/lane is omitted, or a broad lens or impact-cone
  expansion lacks current target evidence;
- reject stale, malformed, uncited, contaminated, or out-of-scope output;
- under the conditional contract, verify literal-block parse, UTF-8, the exact
  inline/unanchored finding partition, canonical anchors, selected event, and
  severity decorations without re-diagnosing the target; skip this comment
  gate for `verdict-only canonical packet` dispatches;
- reject any comment-only closeout, raw multiline comment transport, semantic
  parent rewrite, or missing review-comment section for a finding-bearing
  conditional packet;
- preserve disagreements and use `conflict-resolution` when material;
- route fixes and invalidate only the review surfaces actually changed.

When the parent materially disputes a finding, use the bounded peer challenge
in `conflict-resolution` with the same reviewer session when available. Supply
the challenged claim, counterclaim, current target, and evidence rather than a
desired verdict. The reviewer reassesses its own result; the parent does not
rewrite or silently discard it.

Building a packet is not a review. When a mandatory reviewer is selected and
available, the parent must dispatch it and wait for an acceptable result before
the dependent approval/publication/claim.

An ordinary-review lane may use only its documented skip reason. This skip never applies to a
`required` database-reviewer sibling. If either returned packet is rejected,
request the corrected reviewer pass and keep the overall handoff blocked.

## Output

```text
Reviewer handoff: DELIVERED | BLOCKED | STALE | REJECTED
Reviewer role/session provenance:
Exact target:
Intent source:
Packet location or transport:
Required instruction gate:
Specialist addenda:
Scope-control result:
Expected return contract:
Parent acceptance result:
Parent join category:
Next owner / join consumer:
Reopen condition:
Pending Verification:
```
