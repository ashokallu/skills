<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (minimal same-response review-comment closeout) -->

# Database Reviewer Verdict Closeout

Load this reference exactly once after database judgment is stable. It owns
final packet serialization and the handoff to the parent or author. It does not
change severity, evidence, or verdict law from the skill.

## Entry gate

Do not serialize the verdict until:

- target, base, review mode, and decision boundary are stable;
- shared depth work completed outside the packet;
- every admitted database surface has a selected-lane, `Not selected`, or
  `Not reviewed` disposition;
- the impact cone and every evidence-backed expansion are closed;
- every selected lane returned one disposition;
- required residual database surfaces are accounted for;
- retained findings are deduplicated by root cause; and
- central missing proof is separated from confirmed defects.

If the target, inventory, selected lanes, or material evidence changes during
closeout, return to analysis and load this reference again only after judgment
stabilizes on the new target.

Any shared `REVIEW_SCOPE_*`, `ESCALATION_ACCEPTED`, `SCOPE_EVIDENCE_CORRECTION`,
`CORRECTED_AND_ACCEPTED`, or `SCOPE_DISPUTE_BLOCKED` message is separate
assignment control. It must not appear as a field, prefix, suffix, or section
in this packet. The packet's `review mode` remains database decision scope.
`REVIEW_PROGRESS:` is separate pull-based control too and must never appear in
this packet.

## Actionable finding core

Only a retained, current-target defect receives a finding block. Central
missing proof by itself belongs under `Pending Verification` and `central
missing proof`; it must not create a finding or a speculative fix.

Use this shape for every retained finding:

```text
Finding P0: <short unique title>
- Severity: P0
- Confidence: high | medium | low
- Category: <database consequence class>
- Location: <precise file, symbol, SQL statement, plan step, or evidence artifact>
- Target relevance: <introduced | worsened | activated | newly depended on, with causal link>
- Decision affected: <active objective, acceptance criterion, database invariant, or safety boundary>
- Problem: <violated invariant and the reachable defect>
- Impact: <concrete data, availability, security, recovery, capacity, or operator consequence>
- Evidence:
  - <distinct proof for one claim component>
- Fix shape: <exact change surface, correction direction, and focused post-fix proof>
```

The same structure applies to P1-P3. Keep `Problem` and `Impact` concrete enough
that the author understands both the defect and why it matters without another
investigation session. Use one to three evidence bullets normally; every bullet
must prove a distinct claim component. Do not split unrelated root causes into
one finding merely to stay within that bound.

Keep `Fix shape` to one or two sentences. Name the exact schema, SQL, runner,
caller, transaction, rollout control, recovery path, documentation, or test
surface to change; state the required behavioral direction; and name the
focused proof that should pass afterward. Do not write patch code, prescribe a
full implementation plan, invent an API, or redesign beyond the evidence. When
more than one safe implementation could satisfy the invariant, state the
required outcome and proof instead of choosing an unsupported design.

## Selected-lane audit

The final packet must expose every selected lane. Use one compact row per lane:

```text
- <lane path> | trigger: <concrete signal> | surface: <artifact or behavior inspected> | disposition: <finding ID | verified clean with evidence class | Pending Verification with exact gap | not applicable with reason>
```

All four row components are mandatory. `Not applicable` is valid when a lane
was correctly selected from an initial signal but current evidence proves its
concern absent. Do not rewrite that result as verified clean. List only skipped
lanes that a reasonable reader might expect from the target signals, each with
a short `- <lane path> | reason: <why>` row. List at most three. When more
omissions need one explanation, collapse them into a single bounded scope
reason instead of enumerating the unselected catalog.

Reject closeout when an admitted database surface lacks a disposition, a
mandatory or evidence-triggered lane was suppressed, or a selected broad lane
cannot name current target evidence for its trigger. Shared depth and
scope-control state stay outside the strict packet; use the existing selected,
not-selected, and not-reviewed carriers without adding fields.

Keep a candidate's `accepted`, `limited`, `rejected`, or `irrelevant` decision
inside the evidence-candidate lane's row, but do not use that decision as the
row-level disposition. The row-level disposition must still begin with
`finding P0` through `finding P3`, `verified clean`, `Pending Verification`, or
`not applicable`. For example, use `verified clean: candidate accepted for the
named historical claim with Agent-attested non-replayable provenance`, or
`Pending Verification: candidate limited to historical calibration; current
load remains unknown`.

## Handoff economy

- Present findings before clean evidence, lane detail, and secondary context.
- Deduplicate by root cause and cite the narrowest useful location.
- Do not repeat `Problem`, `Impact`, or evidence prose in the plain-language
  summary, `Pending Verification`, or lane rows.
- The plain-language summary is one to three sentences stating the verdict
  consequence, the first required author action, or the evidence boundary. It
  introduces no new claim.
- Name exactly one next owner. Use `none` only for a settled clean `PASS` with
  no actionable finding, central proof gap, or owner decision.
- Keep rejected candidates only when their rejection materially explains the
  verdict or prevents a likely duplicate review cycle.

## Review comments

For default whole-target PR database review, emit `Review comments:` in the
same response whenever formal findings exist. A clean review omits it. An
explicit verdict-only or triage contract forbids it. The complete `Database
review` packet remains mandatory; comment-only closeout is invalid.

Use the exact minimal section, pipe-prefixed UTF-8 literal rules, canonical
anchor JSON, ordinal partition, event selection, and severity-decoration rules
from `docs/agents/pr-review-packet-format.md`. Do not reproduce a second schema
here. Every formal finding ordinal appears exactly once as an inline Comment or
under `Unanchored findings`; the sets are disjoint and no anchor is fabricated.
Any P0/P1 selects `REQUEST_CHANGES`, including an unanchored finding. A P2/P3-
only set selects `COMMENT`. Inline advisories are outside this default contract.

The reviewer owns the exact Conventional Comment bodies, selected review
event, and Summary. Reject raw unprefixed body or summary text, invalid UTF-8,
inconsistent events or decorations, non-canonical anchors, or incomplete or
overlapping finding coverage. The parent may parse the literal blocks once and
publish the accepted decoded bytes unchanged, but semantic ambiguity or wording
repair returns to this same reviewer.

## Packet shape

```text
Database review:
- target and base:
- review mode:
- decision scope and readiness boundary:
- decision outcome: <supported | rejected | unproven | not applicable>
- blocked decision: <none | performance claim | merge/deployment | exact Production operation>
- verdict:
- confidence:
- strongest proof:
- findings count:
- Pending Verification:
- central missing proof:
- next owner:

Findings:
<structured finding blocks, or none>

Review comments:
<minimal review-comment section when required by the output contract; otherwise omit>

Plain-language summary:
<one to three non-duplicative sentences>

Selected lanes:
<one complete audit row for every selected lane>

Not selected:
<only plausibly relevant skipped lanes with reasons, or none>

Verified clean:
<important probes and evidence classes>

Rejected candidates:
<materially explanatory rejections, or none>

Author validation and scope:
<provided proof and its exact limits>

Not reviewed:
<bounded omissions and later stages not assessed>
```

For a clean target, write `Findings: none` and make the verified-clean section
carry the proof. For a central-evidence-only block, write `Findings: none`,
state the exact missing artifact, route it to one owner, and omit any Fix shape.

## Final acceptance

Before returning the packet, confirm:

- finding counts, severity, verdict, and confidence agree;
- every `PASS` uses `blocked decision: none`, including an advisory `unproven`
  decision outcome;
- every `BLOCKED` verdict names the exact blocked decision, while advisory
  performance uncertainty is `unproven` rather than a fabricated finding;
- every relevant supplied evidence candidate has an `accepted`, `limited`,
  `rejected`, or `irrelevant` disposition naming the affected claim and reason;
- every formal finding satisfies target relevance, reachable causal chain,
  violated invariant, and evidence-backed impact admission;
- every retained finding contains the complete actionable core;
- under the conditional contract, every formal finding ordinal maps exactly
  once to an inline Comment or `Unanchored findings`, with no overlap, missing
  ordinal, fabricated anchor, or inline advisory;
- every selected lane has trigger, surface, and truthful disposition;
- every admitted database surface is closed and every cone expansion cites
  current target evidence;
- no central proof gap was disguised as a finding;
- every finding states target relevance and the decision it can change;
- the next owner can act without rediscovering the issue; and
- the packet contains no duplicate explanation or speculative implementation.
