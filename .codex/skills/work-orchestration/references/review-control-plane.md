<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (minimal same-response comments and single-event join) -->

# Review Control Plane

```text
Type: companion contract
Use when: a parent or owning workflow assigns, resumes, or joins an ordinary or
          database review
Skip when: the current agent directly reviews a local target without a separate
           assignment or join
Owns: shared review assignment vocabulary, depth/topology projection, scope-control
      transitions, pull-based progress vocabulary, semantic ownership boundaries,
      target-change classification terms, and parent-only join categories
Does not own: reviewer routing, packet transport, applicability, inspection, verdicts,
              round history, conflict resolution, or final packet serialization
Allowed side effects: none
Inputs: accepted review owner, exact target, decision scope, mandatory floors, changed
        boundary, evidence gaps, and accepted reviewer results when joining
Exit states: scope accepted | scope dispute blocked | join classified | invalid input
Outputs: separate scope-control message or lossless parent join classification
Re-enter when: target, mandatory floor, evidence, scope adequacy, reviewer result, or
               required-reviewer set changes
```

## Ownership Matrix

This companion defines vocabulary and transition law only. Existing owners
remain authoritative:

| Concern | Owner |
| --- | --- |
| Reviewer selection and specialist applicability | `review-routing` and `database-review-applicability` |
| Neutral assignment delivery, session provenance, required instructions, and append-only review-round ledger | `reviewer-handoff` |
| Scope adequacy, inventory expansion, lenses or lanes, evidence judgment, findings, exact review-comment wording, and verdict | The assigned ordinary or database reviewer |
| Sibling dispatch, one evidence correction, progress requests, waiting, mechanical packet/comment integrity checks, publication, readback, and join execution | The owning PR or direct workflow |
| Ordinary provenance-bound re-review lifecycle | `pr-workflow/references/re-review-worktree.md` |
| Database target-delta and environment-evidence invalidation | `database-reviewer` |
| Unresolved role disagreement | `conflict-resolution` |
| Final PR and database packet serialization | `docs/agents/pr-review-packet-format.md` and database `verdict-closeout.md` |

Do not copy transport, applicability, ledger, verdict, join execution, or
serialization procedure into this file. Consumers reference this vocabulary
and keep their existing authority.

## Review Assignment Vocabulary

The parent supplies factual assignment state:

```text
REVIEW_SCOPE_PROPOSAL:
- reviewer kind: ordinary | database
- exact target and base:
- decision scope:
- proposed depth: LITE | STANDARD | FULL
- topology: single | council
- proposal rationale:
- changed-boundary seeds:
- mandatory floors:
- validation already run:
- known evidence gaps:
- final output contract: canonical packet with conditional review comments | verdict-only canonical packet
```

Changed-boundary seeds orient admission. They are never an inspection
whitelist, a prescribed lens set, or a limit on reviewer expansion.

Every review still returns its complete mandatory verdict packet. The output
contract controls the conditional `Review comments:` section; comment-only
closeout is invalid.

For ordinary whole-target PR review, the proposed and selected output contract
defaults to `canonical packet with conditional review comments` for both the
ordinary reviewer and any required database sibling. When formal findings
exist, the same response carries the minimal reviewer-owned `Review comments:`
section. A clean response omits it. Use `verdict-only canonical packet` only for
an explicitly verdict-only or triage assignment. Preparing review comments does
not grant publication authority. A narrower PR
metadata, thread, or CI read does not dispatch either reviewer and therefore has
no reviewer output contract.

The reviewer emits this packet once to the parent. The parent validates and
accepts it once. When review comments are present, it retains the exact decoded
summary and inline body bytes. In all cases it uses a
bounded verdict/findings/state summary for normal user-facing closeout. It
forwards the exact canonical packet once only when the user explicitly requests
the packet itself. Commentary and later turns must not repeat the packet, lens
inventory, variance ledger, or review-comment literal bodies.

Ordinary and database sibling packets remain separate semantic verdict units.
When both contain review comments, the parent composes exactly one
GitHub review event from their mechanically accepted payloads. It must follow
the deterministic publication join in `## Lossless Parent Join`; separate
sibling review events are forbidden because the first event can create an
unresolved same-actor thread that blocks the second.

`decision scope` and `review depth` are different axes. Database decision scope
remains `planning`, `implementation`, `performance-assessment`,
`production-readiness`, `emergency-repair`, or `mixed`. It is not replaced by
the shared depth vocabulary.

### Depth

Depth changes work after a common admission and closure floor. It never changes
whether the admitted target must be accounted for.

Before applying a depth, the assigned reviewer must establish:

- the exact target and base;
- the complete admitted changed-surface and changed-boundary inventory;
- the changed contract and immediate effects;
- mandatory-floor triggers;
- validation or other proof claimed for the target; and
- one disposition for every admitted surface.

The shared companion owns these generic closure terms. The ordinary reviewer
owns concrete lens or micro-probe selection. The database reviewer owns concrete
lane selection and database-consequence disposition. The parent supplies seeds
and checks packet completeness; it does not prove trigger absence or prescribe
reviewer discovery.

Use the lightest depth that closes the admitted inventory:

- `LITE`: contained, reversible, one-boundary review with no mandatory
  high-risk trigger. Inspect the exact change, its contract and immediate
  effect, one-hop callers or consumers, claimed proof, and every triggered
  specialist probe. Do not add an otherwise untriggered broad residual pass.
- `STANDARD`: default substantive bounded review. Add nearby callers and
  consumers, relevant tests, config, documentation and generated surfaces, and
  every evidence-triggered specialist lens or lane.
- `FULL`: production blast radius, direct or indirect shared-database
  consequence, auth/security/privacy, migration or data-integrity work, public
  contracts, infrastructure or release behavior, cross-system ownership,
  central missing proof, or an unbounded or contested impact cone. Add
  cross-boundary states, compatibility, failure and recovery paths,
  rollout/rollback, operator evidence, and an independent residual pass.

All depths close every admitted surface and load every mandatory or
evidence-triggered specialist lens or lane. `LITE` and `STANDARD` remove
untriggered breadth, not required coverage. A bounded probe may discover
expansion evidence. "No trigger, no lens" means no broader load without that
evidence; it never means "do not look for a trigger."

Database `LITE` is valid only for a bounded direct or advisory target whose
admission inventory does not activate migration, Production execution, data
integrity, topology, recovery, or central-evidence gates.

Mandatory current rules are floors. In particular, direct or indirect
consequences to a shared database contract retain `cross-system` impact,
`FULL` review, independent database review, and affected-consumer
authoring/validation coverage.

An owning workflow may establish a named mandatory depth floor for a narrowly
defined request class. That accepted floor is assignment authority, not generic
reviewer preference, and cannot be demoted during scope admission. The
`pr-workflow` owner sets `senior_pr_owner_whole_target` to `FULL` for a
substantive whole-target verdict on a teammate or otherwise non-owned PR
supplied by URL or number. Its initial topology remains `single`; `FULL` does
not imply `council` or replace an independently applicable database review.

The named floor does not leak into PR summaries, metadata or CI reads,
existing-comment or thread handling without a new whole-target verdict,
triage, fixes, workflow explanations, or provenance-bounded targeted
re-reviews. A whole-target review that also publishes surviving findings still
qualifies. Generic deep or thorough wording outside the qualifying owning route
is not a mandatory-floor trigger.

### Impact Cone And Stop Proof

Begin with the changed contract, changed files or symbols, immediate effects,
one-hop callers or consumers, claimed proof, and direct documentation or
operator consequences. Expand only when current target evidence proves at
least one of:

- a reachable caller or consumer outside the current cone;
- a crossed runtime, data, auth, API, security, or operator boundary;
- a sibling implementation sharing the protected invariant or failure
  mechanism;
- one additional artifact that can materially change severity or verdict; or
- a mandatory safety floor.

Every expansion names the trigger, evidence, added boundary, and defect class
the old cone could miss. A depth change uses the existing scope-escalation
exchange. An expansion within an already sufficient depth is recorded in the
originating reviewer's existing coverage and selected-lens or selected-lane
audit. Do not create another packet field or negotiation loop.

Stop only when the stated intent or decision was assessed, every admitted
surface has a disposition, all reachable P0-P2 candidates inside the proved
cone are classified, claimed proof was assessed, no verdict-changing evidence
gap is hidden, and no expansion trigger remains active. Do not keep searching
for unrelated debt, another lens, or an architectural alternative after this
proof exists.

### Topology And External Projection

Internal state uses:

```text
depth: LITE | STANDARD | FULL
topology: single | council
```

For the strict ordinary PR packet:

- `topology: single` projects `Review mode` from the selected depth;
- `topology: council` projects `Review mode: COUNCIL`; and
- the underlying council depth remains in parent assignment state and cannot
  fall below a mandatory floor.

The database final packet is unchanged. Its existing `review mode` continues
to mean database decision scope. Shared depth and topology remain outside that
packet.

`COUNCIL` is topology, not database review, and never replaces an independently
required database-reviewer sibling. Council selection remains subject to its
existing cross-harness authority; scope escalation cannot silently authorize a
paid or separately controlled council.

## Separate Scope-Control Message

Scope control occurs after target and inventory admission and before
evidence-heavy analysis. It is a separate control message, never a field,
prefix, suffix, or section in either strict final verdict packet.

Receipt planning uses the shared depth law, mandatory floors, specialist
matrix, and current target evidence already admitted. It must not open optional
ordinary lenses or perform optional database-lane work merely to discover what
might be relevant. Optional specialist procedure loads only after its trigger
is evidenced and the scope exchange reaches an accepted terminal state.

The reviewer returns exactly one initial response:

```text
REVIEW_SCOPE_ACCEPTED:
- exact target:
- selected depth and topology:
- mandatory floors applied:
- bounded initial impact cone:
- expansion triggers:
```

or:

```text
REVIEW_SCOPE_ESCALATION:
- exact target:
- proposed and requested depth:
- concrete target evidence:
- newly reachable risk boundary:
- impact-cone and lens/lane expansion:
- defect class the proposed scope could miss:
- closure proof:
```

Emit one control response for each transition. Never concatenate alternative
versions, repeat the complete exchange, or append another response after the
terminal state.
Use evidence-resolution language between peer owners. Do not frame the exchange
as one role defeating, beating, or winning against the other.

An escalation must be caused by the current target, a mandatory floor, or
evidence discovered during review. File count, reviewer preference, generic
thoroughness, elapsed time, token pressure, and an unrelated concern are not
evidence.

### One-Challenge Closure

When a mandatory floor or current target evidence proves the expansion, the
parent records:

```text
ESCALATION_ACCEPTED:
- exact target:
- accepted depth and topology:
- governing floor or evidence:
- parent join/re-entry point:
```

The parent cannot veto proved safety coverage for speed or cost.

Otherwise the parent may send exactly one:

```text
SCOPE_EVIDENCE_CORRECTION:
- exact target:
- disputed claim:
- counter-evidence:
- governing contract:
- requested reassessment:
```

This is evidence, not an instruction to narrow. The same reviewer owns the
terminal response:

```text
CORRECTED_AND_ACCEPTED:
- exact target:
- accepted correction:
- sufficient depth and topology:
- bounded impact cone and closure:
```

or:

```text
SCOPE_DISPUTE_BLOCKED:
- exact target:
- unresolved scope claim:
- reviewer evidence:
- parent counter-evidence:
- decision blocked:
- conflict-resolution handoff:
```

Do not repeat negotiation, shop for a reviewer, or silently override scope.
`SCOPE_DISPUTE_BLOCKED` prevents evidence-heavy analysis or verdict under the
disputed narrowing and routes the exact claim through `conflict-resolution`.

After acceptance, depth is monotonic for the stable target: it may remain or
increase only when newly discovered target evidence reaches another defect
class. Once depth is `FULL`, widen the impact cone or selected lenses inside
that depth without opening another depth negotiation. Reopen topology or
authority separately only when their own governing trigger changes.

This local read-only exchange needs no human approval while it remains inside
the accepted objective and authority. Re-enter objective, scope, autonomy, or
owner control when an expansion changes accepted behavior, external access,
mutation authority, or separately governed paid/council execution.

Scope control for one sibling never serializes another. Ordinary review may
continue while database evidence is prepared, and each required reviewer
negotiates only its own scope.

## Reviewer-Active Semantic Ownership

Successful dispatch of an ordinary or database reviewer activates the internal
`REVIEW_ACTIVE` lifecycle state for that reviewer and exact target. This is a
control-plane state, not a mandatory emitted packet, progress event, heartbeat,
or user-visible ceremony. While any required reviewer remains active, the
parent's critical-path work is waiting and review control; it does not need to
invent another work item to remain productive.

During `REVIEW_ACTIVE`, the parent may only:

- wait silently;
- request one justified pull-based `REVIEW_PROGRESS:` response at a safe
  boundary;
- maintain target and PR freshness, thread and CI inventory, database-review
  applicability and required evidence preparation, authorization state,
  scope-control dialogue, mechanical packet integrity, and join, publication,
  or readback mechanics.

Each allowed action is bounded by both purpose and effect to its named
control-plane output. It must not inspect changed code, callers, consumers, or
tests for verdict semantics, whether described as a whole review, partial
review, supporting analysis, spot check, database-applicability check,
thread/CI work, packet-integrity check, or another label. An incidental
semantic concern is sent factually to the active reviewer or scope-control path;
the parent does not investigate it. When no allowed control-plane action is
needed, the parent waits.

Database-review applicability is the one allowed action that must read changed
files, so its boundary is stated explicitly rather than left to judgment. The
parent may read changed paths, import and caller edges, dependency and config
diffs, and migration or query file presence, for the sole purpose of producing
the applicability disposition and its evidenced negative or positive trace. The
parent may not judge whether any of that code is correct, efficient, safe, or
well designed, and may not retain a finding from it. If the applicability read
surfaces a suspected defect, state it factually to the active reviewer and stop;
do not develop it. Reading for routing is permitted, reading for verdict is not,
and the disposition packet is the only artifact this read may produce.

An exception trigger permits consideration of leaving `REVIEW_ACTIVE`; it does
not authorize semantic takeover by itself. Before the parent or another owner
begins semantic work, the original reviewer must have terminal and stop proof,
or an explicit terminal blocked or malformed disposition, and the owning
workflow must authorize the replacement transition. Malformed transport
receives mechanical repair, semantic ambiguity or incomplete wording returns
to the same reviewer, and a target change creates a fresh target and reviewer
binding. A mandatory ordinary or database reviewer remains mandatory. Parent
analysis cannot satisfy or waive either mandatory reviewer, and no replacement
semantic work overlaps a healthy or merely still-running reviewer.

## Reviewer Packet Acceptance Lifecycle

A terminal reviewer return enters the internal exact-target lifecycle
`RETURNED -> VALIDATING -> ACCEPTED | REJECTED`. This section is the sole
owner of those states and the repair schemas below. It does not create a
user-visible packet, approval, heartbeat, or semantic review.

At `VALIDATING`, the parent runs
`scripts/dev/validate-review-packet.rb` against the exact returned bytes and
the target, review mode, and review-comments policy fixed in the dispatch
(`required_if_findings` for the default; `forbidden` for explicit verdict-only
or triage review). The packet cannot declare or
weaken those trusted inputs. The canonical packet shape and rule-ID inventory
remain solely owned by `docs/agents/pr-review-packet-format.md`.
For an accepted finding-bearing packet, the validator's version 3 JSON
`review_comments_payload` is the retained, already-decoded source of review
event, summary, anchor, and inline-body bytes. Rejected and clean packets return
no review-comments payload. The parent must not parse those literal blocks
a second time.

The parent records one private result:

```text
PACKET_ACCEPTANCE_RESULT:
- exact target:
- expected review mode:
- expected output contract:
- source sha256:
- canonical packet sha256:
- transport: raw | fenced | invalid
- rule results: <RPPA rule IDs and pass/fail>
- decision: ACCEPTED | REJECTED
- repair attempt: 0 | 1
```

Only `ACCEPTED` permits sibling join, bounded user closeout, publication, or
a packet-compliance claim. A result is not accepted because the parent can
recognize the intended verdict, because the reviewer later claims compliance,
or because a prose summary appears accurate.

The first `REJECTED` result keeps the same reviewer and exact target active.
Send one consolidated mechanical request:

```text
REVIEW_PACKET_REPAIR:
- exact target:
- expected review mode:
- expected output contract:
- rejected source sha256:
- rejected canonical packet sha256:
- failed rule IDs:
- observed defects:
- expected mechanical shape:
- required correction: return one complete corrected canonical packet
- repair attempt: 1 of 1
```

Do not ask the reviewer to repeat semantic inspection, widen the output
contract, or return fragments. Do not let the parent reconstruct findings,
verdict logic, evidence, comment wording, or missing packet sections. The
complete corrected packet re-enters `RETURNED -> VALIDATING` from scratch
with a new byte identity. If it remains mechanically invalid, stop through the
existing terminal-malformed or replacement decision. Never relax validation,
loop, start an overlapping reviewer, or join the rejected result.

## Pull-Based Review Progress

`REVIEW_PROGRESS:` is a separate control response for an ordinary or database
review. It is not a verdict, scope transition, packet section, keepalive, or
closeout request. The parent may request it after extended silence or when a
material coordination decision depends on reviewer state. The reviewer returns
it only at a safe boundary where reporting will not interrupt an indivisible
inspection or evidence comparison:

```text
REVIEW_PROGRESS:
- exact target:
- phase:
- completed surfaces:
- remaining surfaces:
- active candidates:
- blockers:
- scope changes:
- next milestone:
- advisory time band: <5m | 5-15m | >15m | unknown | omitted
```

Progress is pull-only. The reviewer never emits autonomous periodic updates,
repeats an unchanged progress response, or inserts progress fields inside a
strict ordinary or database verdict packet. The optional time band is advisory
response metadata only. It never creates a deadline, polling cadence, retry
rule, escalation trigger, or permission to request early closeout.

The parent requests progress before asking whether a reviewer can close. A
reviewer closes only when its admission, closure, and stop-proof rules are
satisfied. Elapsed time, token use, parent anxiety, or a request for a quick
answer cannot substitute for that proof.

## Semantic Ownership And Parent Integrity Floor

The reviewer is the semantic owner. It understands the target, decides
findings and advisories, and, when the output contract requires them, returns exact publication-ready
comment bytes. The `REVIEW_ACTIVE` state above therefore excludes parent
semantic review of any size or label. The parent does not reread code, callers,
consumers, or tests to rediscover defects; alter severity or confidence; choose
a different fix; rewrite comment bodies; or invent missing review feedback.

The parent remains the orchestration and publication controller. It performs
only non-semantic integrity work:

- verify exact target, packet shape, and accepted scope-control terminal state;
- verify that inline and unanchored finding ordinals are disjoint and together
  cover every formal finding exactly once;
- verify literal-block parse, UTF-8, canonical anchor JSON, selected event,
  severity decoration, and exact Summary and Body bytes once at packet
  acceptance;
- retain the accepted decoded bytes and repeat only mutable current-head,
  anchor, duplicate/thread, authorization, and capability checks before
  publication;
- preserve independently required database-sibling and lossless join state; and
- publish accepted bytes unchanged, then perform authenticated readback.

Reviewer-to-parent transport always crosses a session boundary and therefore
always uses the packet's pipe-prefixed literal transport. Authenticated identity
does not waive that boundary. A successful packet acceptance is the sole
immutable-byte verification for the current packet and exact target. Do not
re-parse the same accepted Summary or Body literal blocks again before
publication. A body, summary, event, target, or anchor change invalidates
acceptance and returns to the same reviewer; mutable GitHub-state changes return
to the owning freshness or publication gate.

Malformed transport, a missing mapping, or stale mutable state returns to the
owning workflow for mechanical repair or a fresh target. Semantic ambiguity,
an incomplete finding, or a comment that needs different wording returns to the
same reviewer. The parent neither repairs the semantics nor silently drops a
comment. A materially contradictory packet, changed target, explicit user
request for independent review, or terminal blocked or malformed reviewer may
start the replacement-transition decision above; none permits overlapping
semantic work or waives a mandatory reviewer.

## Target-Change Classification

Use the shared terms:

- `readback`: wording, formatting, comments, or semantically unchanged output;
- `targeted`: one materially changed correctness boundary with a bounded
  impact cone;
- `broad`: multiple domains, an unbounded cone, ownership redesign, or global
  invalidation; and
- `blocked`: missing provenance, unresolved scope dispute, or insufficient
  evidence for safe classification.

Record prior and current immutable targets, provenance or ancestry when
applicable, changed boundary, cone seeds and closure, invalidated evidence,
validation, and classification reason.

These terms do not replace the ordinary re-review lifecycle or the database
reviewer's static target-delta and environment-invalidation rules. A compact
follow-up result never becomes whole-target signoff.

## Lossless Parent Join

The owning workflow first applies its existing packet-acceptance rules.
Missing, stale, target-mismatched, malformed, internally inconsistent, or
contaminated required output contributes `INPUT`; the parent does not invent a
reviewer verdict.

When review comments are present, packet acceptance also requires the
semantic-ownership integrity floor above. Their presence means publication-
ready, but does not grant permission to publish without the owning GitHub
workflow's current-head, anchor, same-actor, authorization, and readback gates.

Map each accepted result to one candidate:

- `CLEAN`: pass-form verdict; no P0-P3 finding, central missing proof,
  non-central `Pending Verification`, residual risk, required action, or owner
  decision.
- `CAVEATS`: pass-form verdict; no formal finding, central missing proof, or
  required action, but explicit non-blocking residual risk or non-central
  `Pending Verification` remains.
- `ACTION`: non-blocking verdict with a P2/P3 finding or explicit required
  action/owner decision, and no P0/P1 or central missing proof.
- `DEFECT`: accepted ordinary `FAIL` with a proved intent failure, or an
  accepted ordinary/database blocking verdict with a retained P0/P1. Preserve
  any simultaneous central proof gap.
- `EVIDENCE`: ordinary or database `BLOCKED` because central missing proof
  controls the named decision, with no verdict-inconsistent P0/P1.
- `INPUT`: database `NEEDS_INPUT`, rejected/missing required output, or any
  verdict/finding/count/blocked-decision combination that violates the
  originating packet contract.

Ordinary `PASS_WITH_FINDINGS` with no formal finding, only non-blocking
residual risk, no central gap, and no required next action maps to `CAVEATS`.
Database `PASS` with a P2/P3 or non-none action owner maps to `ACTION`;
database `PASS` with only non-central uncertainty and no action maps to
`CAVEATS`.

Join all required candidates in this order:

1. any `INPUT` -> `JOIN_NEEDS_INPUT`;
2. otherwise any `DEFECT` -> `JOIN_BLOCKED_DEFECT`;
3. otherwise any `EVIDENCE` -> `JOIN_BLOCKED_EVIDENCE`;
4. otherwise any `ACTION` -> `JOIN_ACTION_REQUIRED`;
5. otherwise any `CAVEATS` -> `JOIN_READY_WITH_CAVEATS`;
6. otherwise -> `JOIN_READY_CLEAN`.

The join retains every original verdict, finding, confidence, target,
residual-risk item, `Pending Verification`, and next owner. A higher-precedence
category does not suppress lower-precedence sibling state. Serialize that
retained state separately for every required sibling: name the reviewer kind,
its original verdict, retained findings or central evidence gap, confidence,
target, `Pending Verification`, and next owner when present. A generic plural
summary such as "original verdicts" is not lossless proof because it does not
make each sibling's verdict and gap independently recoverable. A
`JOIN_NEEDS_INPUT` result may retain independently valid sibling findings as
provisional work while the missing or invalid required result is repaired.

When both accepted sibling packets contain review comments, publish their union
in one GitHub review event only. Select `REQUEST_CHANGES` when either sibling
selected it; otherwise select `COMMENT`. Preserve every body byte for byte and
preserve sibling order: ordinary comments, then database comments. Retain an
exact duplicate anchor-and-body pair once. Retain non-identical bodies,
including bodies on the same anchor, without parent semantic rewriting. A
one-sided ordinary-only or database-only payload is used unchanged.

The combined review-summary bytes are exactly:

```text
## Application review

<ordinary reviewer-summary bytes>
## Database review

<database reviewer-summary bytes>
```

The two headings and their separating newlines are parent-owned fixed framing;
each reviewer-summary remains an exact byte substring. Missing or invalid
summary bytes block publication. Unanchored findings remain represented in
their reviewer-owned summary substring. This composition changes neither sibling
verdict nor the lossless join category.

Material contradiction about the same premise, target fact, severity
consequence, or safety boundary is not normalized by majority or role
hierarchy. Emit `JOIN_NEEDS_INPUT`, retain both results, and route the exact
dispute through `conflict-resolution`. An unresolved scope dispute does the
same.

No join category authorizes merge, publication, deployment, Production
execution, or mutation. The owning workflow applies the next gate.
