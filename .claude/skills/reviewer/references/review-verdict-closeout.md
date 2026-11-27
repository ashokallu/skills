<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (same-response review comments and canonical conventions) -->

# Reviewer End Phase

Load this mandatory phase after analysis and residual passes complete against a
stable target. It owns final candidate collapse, soft-pedal prevention,
selected-lens accountability, next-consumer proof, and output-mode closeout.
The runtime reviewer role owns verdict judgment. The packet document owns
GitHub packet serialization.

## Entry Gate

Do not begin closeout until the middle-phase result confirms:

- stable target and bounded inventory;
- selected depth and complete admitted-surface dispositions;
- initial impact cone, every evidence-backed expansion, and cone closure;
- every selected lens read and applied;
- target-specific probes answered or marked `Pending Verification`;
- production applicability completed when triggered;
- required prior-comment and independent residual passes completed; and
- unresolved central proof represented as `BLOCKED` and Risk Evidence Handoff.

If target, inventory, or material risk changes during closeout, return to the
middle phase. Do not patch the lens list inside final output.

## Materiality And Candidate Collapse

A concern is material when it can affect correctness, data, security,
deployability, operator truth, public API or UX contract, test validity, or the
verdict. Style preference, pure formatting, or taste without contract impact is
non-material. Calling an item a nit or optional does not demote a proved
material consequence.

Apply the reviewer role's candidate filter and severity law. Every surviving
finding must be reachable, actionable, evidenced against the current target,
and deduplicated by root cause. Missing proof is not automatically a finding:
use `Pending Verification` when non-central and `BLOCKED` plus Risk Evidence
Handoff when central.

## Canonical Closeout Lens

Run `review-closeout-lens.md` exactly once after required residual review. It
owns one depth-proportional target-unit collection followed by these ordered
categories:

1. `consequence_advisory`
2. `simplification`
3. `documentation_truth`
4. `naming_readability`

Use one root-cause join and the lens's shared advisory budget. Do not load or
run compatibility aliases in addition to the canonical lens. The canonical
lens is a candidate sweep; this phase remains the controller for verdict
closeout. `LITE` keeps collection to exact target units, immediate context,
changed prose, and direct consequences. `STANDARD` adds nearby trusted
surfaces. `FULL` includes the cross-boundary and residual surfaces established
by analysis. A lower depth never suppresses a proved candidate.

## Soft-Pedal Gate

Before verdict, inspect coverage, residual risk, `Pending Verification`,
variance notes, handoff prose, and summaries for a proved gap that was not
classified.

- Proved material gaps must be formal findings at the role-defined severity or
  a Risk Evidence Handoff when central external proof controls the verdict.
- Proved non-blocking contract or documentation gaps may use permitted
  non-counting advisory context only when the packet contract explicitly
  allows it.
- Pure naming/readability nits remain non-counting under the canonical closeout
  lens.
- Unfetched or unexecuted evidence may remain `Pending Verification`; fetched
  proof of a gap may not.

Reject a packet or compact verdict that hides a proved gap only in coverage,
residual risk, or vague `Pending Verification` prose.

## Selected-Lens Audit

Account for every selected lens and the common lenses intentionally not loaded.
Each selected row must name its trigger, concrete target surface, and evidence
or disposition. Each skipped common lens needs a short reason. Reject a broad
lens or impact-cone expansion that lacks current target evidence, and reject a
missing lens whose trigger or mandatory floor is present. This audit is
parent-facing review evidence, not permission to invent fields in
parser-sensitive packet sections.

For production blast-radius review, include migration/SQL coverage stating
whether Postgres migration files changed and which schema, rollout, or operator
contract was inspected, even when the target is documentation-heavy.

## Next-Consumer Pass

Before accepting an unblock or readiness claim, name:

- artifact or state produced by the reviewed change;
- exact command, workflow, runtime, operator, downstream system, reviewer, or
  human decision that consumes it;
- that consumer's acceptance rules;
- current evidence that those rules pass;
- missing acceptance proof; and
- next likely blocker.

If the consumer would still reject the artifact or state, do not call the path
unblocked. Raise a finding, Risk Evidence Handoff, or `Pending Verification`
according to centrality.

## Decision Scope

State the exact decision scope assessed by the verdict. Source, plan, or
implementation review does not imply deploy, execution, or later-stage
readiness unless that evidence and consumer were also reviewed. Reviewer
judgment informs readiness; it does not itself authorize merge, deploy,
production execution, or an external override.

Owner risk acceptance or an external override is disposition metadata. It does
not rewrite inspected evidence, erase a confirmed finding, or convert the
reviewer's verdict to `PASS`.

## Actionable Finding Handoff

Only a retained current-target defect receives a finding. Central missing proof
alone remains `Pending Verification` or a Risk Evidence Handoff and must not
create a speculative fix.

For every retained finding in any output mode, provide severity, confidence,
category, precise location, `Target relevance`, `Decision affected`,
`Problem`, `Impact`, one to three distinct `Evidence` bullets normally,
and `Fix shape`. Target relevance must state how the reviewed target
introduces, worsens, activates, or newly depends on the condition and connect
it to stated intent or a protected invariant. Unrelated candidates are not
findings. Keep `Fix shape` to one or two sentences naming the exact change
surface, correction direction, and focused post-fix proof. It must let the
author start without rediscovering the issue, but it must not contain patch
code, a full implementation plan, an invented API, or an unsupported redesign.
When several safe implementations satisfy the invariant, state the required
outcome and proof instead of choosing one speculatively.

Do not repeat the finding's Problem, Impact, or evidence in summary, coverage,
or lane-accountability prose. A clean verdict or central-proof-only block must
not fabricate a finding or Fix shape.

## Output Modes

### GitHub PR verdict

1. Use the runtime role for candidate filtering, severity, confidence, verdict,
   hard blockers, and Risk Evidence Handoff judgment.
2. Keep shared scope-control messages outside the packet. Do not add
   `REVIEW_SCOPE_*`, `ESCALATION_ACCEPTED`, `SCOPE_EVIDENCE_CORRECTION`,
   `CORRECTED_AND_ACCEPTED`, or `SCOPE_DISPUTE_BLOCKED` fields or prose.
3. Read `docs/agents/pr-review-packet-format.md` after judgment is stable and
   immediately before emission.
4. When the assignment's output contract includes conditional review comments,
   which is the default for whole-target PR review, also read
   `docs/agents/pr-comment-conventions.md` before drafting any candidate body or
   review-summary body. It is mandatory at this phase and is not conditional on
   any evidence-triggered lens, so it applies to a PR with no prior review
   threads. The parent does not supply comment conventions, and the mechanical
   subset is enforced as `RPPA-011`.
5. Run that document's complete Pre-Emit Checklist and trigger-word audit.
6. Emit only its canonical packet shape. Do not prepend or append prose,
   agreements, memory citations, source footers, or private routing notes.
7. Reject an invalid packet as a reviewer-output defect. Correct it in the same
   reviewing session when the target is unchanged; otherwise restart the
   affected analysis slice.

Evidence Response Packets for reassessment use the canonical field set in the
packet document. Do not reproduce that schema here. Match evidence to the
original review target and Risk Evidence Handoff identifier. If the target
changed, restart the affected analysis rather than laundering new evidence
into an old verdict.

For a material parent disagreement that is not a canonical `REH-n` evidence
response, use the bounded peer challenge from `conflict-resolution`. Keep the
target stable, answer once with accept, modify, stand, Pending Verification, or
escalate, and name the governing evidence plus the smallest evidence that could
change the decision. The reviewer retains its verdict; the parent retains
integration and write ownership.

### Branch, commit, staged, or local-diff verdict

Emit a compact integrity contract containing:

- stable target and base/head when known;
- selected lenses and concrete surfaces;
- evidence inspected and checks actually run;
- findings or clean-proof rationale;
- confidence and verdict under role law;
- reviewed decision scope and later stages not assessed;
- unresolved central proof and `Pending Verification`;
- next-consumer result; and
- one next owner.

Omit only inapplicable GitHub metadata, thread, CI, and packet-serialization
fields.

### Direct named SQL or migration safety review

Emit findings first, then:

- named stable files, symbols, or query target;
- selected SQL and migration safety lenses;
- source and operational evidence inspected;
- production applicability map;
- exact `Pending Verification` or Risk Evidence Handoff artifacts; and
- verdict impact and next owner.

Do not require PR metadata, PR publication preparation, thread state, CI rows,
or parser-facing PR packet serialization.

## Final Acceptance

Before emitting any verdict, confirm:

- all three mandatory phases completed in this reviewing session;
- target remained stable after final middle-phase computation;
- the accepted depth performed its required work without collapsing to another
  depth;
- every admitted surface has a disposition and every expansion has current
  target evidence;
- the canonical closeout lens ran once;
- findings, counts, verdict, confidence, and unresolved proof agree;
- every P0/P1 and production-impact P2 has local proof or exact Risk Evidence
  Handoff under role law;
- no proved material concern was soft-pedaled;
- next-consumer acceptance was checked;
- one next owner is named; and
- output follows the selected mode's canonical owner.

Missing this mandatory phase blocks substantive verdict emission in a runtime
expected to support lazy loading.

## Closeout Result

For non-packet modes, or parent-facing notes before packet serialization, keep:

```text
Reviewer verdict closeout:
- beginning phase: complete
- middle phase: complete at <stable target>
- selected depth and closure: <depth, admitted surfaces, cone closure>
- canonical closeout lens: complete once
- selected-lens audit: complete
- soft-pedal gate: passed | failed, because <reason>
- next consumer: <consumer and acceptance result>
- output mode: <github-packet | compact-verdict | direct-safety>
- verdict emission allowed: yes | no, because <reason>
```
