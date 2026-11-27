<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-26 (conditional initial FULL primer admission) -->

# Reviewer Beginning Phase

Load this mandatory phase in the reviewing session before that session gathers
PR metadata, diff, CI, code, or operational evidence. Parent orchestration may
prepare a stable head, worktree, bounded inventory, intent summary, comments,
and validation claims before dispatch. Treat those as routing inputs, not
reviewer evidence and not a waiver of this phase.

## Mission

Establish the reviewing session, output mode, common admission floor, and
read-only boundary before evidence can narrow reviewer attention.

## Substantive Review

A review is substantive when it includes a verdict or risk judgment about code
behavior, tests, config, migration, auth, API, data, runtime behavior, CI,
publication readiness, or a ready/green/pass claim. Tiny typo, pure formatting,
or metadata-only reads without risk judgment do not enter this phase.

Soft labels such as "quick", "light", or "sanity check" do not make a
substantive review non-substantive.

## Bootstrap Sequence

1. Read and assume the runtime's local reviewer role.
2. Confirm one entry mode and one output mode from the eager kernel.
3. For parent-authored own work, load the current
   [orchestration conformance contract](../../work-orchestration/references/orchestration-conformance.md),
   spot-check only the current decision owners that can change the verdict, and
   record the parent attestation as unverified routing input. For a teammate/open
   PR, record the exemption instead; do not reconstruct planning history.
4. Record the parent-supplied target identity and inventory as unverified
   routing inputs. Do not inspect or rely on them as evidence yet.
5. Record the proposed or directly selected depth and the common admission
   inputs: exact target/base, changed-surface seeds, changed contract,
   immediate effects, mandatory-floor candidates, and claimed proof. The
   reviewer independently verifies and closes them during analysis.
6. Determine the task-time direction or necessity contracts triggered by the
   supplied target and risk shape.
7. Reconfirm the role's read-only and no-nested-reviewer boundaries.
8. Emit the bootstrap result. Only then may this reviewing session begin
   evidence collection and enter the middle phase.

## Conditional FULL Initial-Review Primer

For a separately assigned review, the private primer at
`docs/agents/pr-4713-review-thoroughness-case-study.md` activates only for a
newly admitted whole-target initial ordinary review after scope control reaches
an accepted `FULL` terminal state: `REVIEW_SCOPE_ACCEPTED`,
`ESCALATION_ACCEPTED`, or `CORRECTED_AND_ACCEPTED`.

A proposed `FULL` depth does not activate the primer. Neither does `LITE`,
`STANDARD`, or focused re-review, regardless of session freshness or inherited
depth.

When activated, the reviewing session must read the live file through EOF
before evidence-heavy middle-phase analysis. Continue through every page or
chunk until EOF. Search or grep hits, excerpts, first-N-line peeks, summaries,
injected context, memory, prior sessions, and another agent's read do not count.
Record the immutable content identity of the bytes read privately. The same
continuing initial `FULL` review may reuse that completed read only while the
content identity remains unchanged. A fresh whole-target initial `FULL`
reviewer or changed identity reads it again.

Do not emit an acknowledgement or agreement recital. The primer is reflection,
not target evidence: it cannot select lenses, expand the impact cone, create a
finding quota, prove a finding, or override native reviewer doctrine and stop
proof. If the live primer cannot be read through EOF, block evidence-heavy analysis and substantive verdict emission.
Do not skip it or downgrade the accepted depth. Restoring live-file readability
for that same accepted review is the only unblock. Canceling, replacing, or
relabeling the assignment to evade the gate does not satisfy it.

## Task-Time Direction And Necessity Contracts

For high-risk review where a PR, operation, rollout, migration, data repair, or
production-affecting plan is claimed to be unblocked, verify the whole current
problem rather than only the local diff. Require current evidence, no-code or
existing-path alternatives, the smallest durable slice, the next consumer's
acceptance rules, and the next predictable blocker. High-risk review includes
auth or authorization, production data, migrations, rollout/release gates,
infrastructure, security-sensitive behavior, or a change that may cause another
production-affecting operation, data repair, rollback, or owner decision.

When the target adds durable persistence, retained observability with new
thresholds or ongoing operator ownership, or durable lifecycle machinery,
identify the requested outcome, required mechanisms, speculative mechanisms,
and keep, defer, remove, or finding disposition. Challenge necessity before
making an oversized design internally safer. Keep a mechanism only when it
directly satisfies an existing acceptance criterion, is required by a
mandatory current contract, or is `protective`: it maps to a named protected
invariant and current evidence proves the change makes the prevented failure
reachable. An unsupported mechanism is a scope finding or plan-reset candidate.

Do not run the scope check for typo, formatting, wording-only documentation,
semantically unchanged generated output, an ordinary rollback note using an
existing release path, a short runbook update documenting existing controls,
or routine CI repair with unchanged behavior and permissions.

Apply the
[native forward-analysis contract](../../work-orchestration/references/forward-analysis.md)
to the broader unblock claim. The reviewer independently tests the claim and
does not treat a parent result as proof. It does not require a narrative read,
acknowledgement, or second parent analysis.

When a target records or implements a requested plan, policy, proposal, or
phase boundary, review its decision provenance before local mechanics. Keep
artifact-fidelity obligation, phase and packaging authority, execution
authorization, owner-approved behavioral policy, verified facts, advisory
input, and `Pending Verification` distinct. A fact, dependency, critic finding,
or reviewer recommendation can challenge the contract; it cannot silently
reverse accepted behavior, absorb the next phase, or manufacture approval.

When a target records or changes source authority, fallback/error/availability
semantics, runtime dependencies or latency, synchronization, auth or data
ownership, flags, phase sequence, acceptance criteria, protected invariants, or
non-goals, activate `review-intent-understanding-lens.md` for objective
conformance. Bootstrap owns only this activation; that lens owns live-intent
comparison, four-way relevance classification, and the teammate-PR
no-retroactive-lock boundary.

For a missing-behavior claim derived from a runtime symptom, require the
intended contract, implemented capability across affected paths, effective
configuration and lineage, and observed behavior before accepting code as the
fix. Disabled capability is not missing code. Classify missing evidence
honestly instead of turning it into a speculative finding.

The reviewer handoff carries only the task-time necessity decision and its
evidence.

## Parent Inputs Versus Reviewer Evidence

PR orchestration may safely establish and supply these facts before reviewer
bootstrap:

- repository and PR identity;
- base and head refs or SHAs;
- canonical worktree path and readiness state;
- bounded changed-file inventory;
- live PR body, comments, reviews, thread inventory, and check inventory;
- requested output mode and claimed validation.

The reviewer must recheck any supplied fact it uses for a finding, verdict,
freshness claim, validation claim, or packet field against current local or
authenticated evidence after bootstrap. Parent preparation avoids circular
setup; it does not become proof by delegation.

## Stop Conditions

Do not enter analysis when:

- the runtime reviewer role cannot be read;
- entry or output mode is ambiguous;
- the read-only boundary cannot be maintained.

Missing this mandatory phase blocks substantive verdict emission in a runtime
expected to support lazy loading.

## Bootstrap Result

Keep a compact private or parent-facing result:

```text
Reviewer bootstrap:
- role loaded: <runtime role path>
- entry mode: <stable-target | direct-safety>
- output mode: <github-packet | compact-verdict | direct-safety>
- proposed or selected depth: <LITE | STANDARD | FULL>
- common admission inputs: <target/base, surface seeds, changed contract, mandatory-floor candidates, claimed proof>
- production-ready scope disposition: <not activated | requested outcome, required mechanisms, speculative mechanisms, disposition>
- parent inputs accepted for routing only: <target and inventory identifiers>
- scope-control next step: <not separate | emit REVIEW_SCOPE_ACCEPTED | emit REVIEW_SCOPE_ESCALATION>
- FULL initial-review primer: <not activated | waiting for accepted FULL | read through EOF at content identity | same-session unchanged-identity reuse | blocked>
- reviewer evidence collection allowed: yes | no, because <reason>
```

When the review is separately assigned, this bootstrap result admits the
separate scope-control exchange from
`work-orchestration/references/review-control-plane.md`. The reviewer may
use the exact target, bounded inventory, mandatory floors, and cheap trigger
evidence to accept or escalate. Do not begin evidence-heavy analysis until the
exchange reaches an accepted terminal state. The exchange is never part of the
strict final verdict packet.

When a caller asks for the receipt plus prospective review work, derive that
work from the phase owners, mandatory matrix, and admitted evidence. Do not
open optional domain lenses during receipt planning merely to describe work
that might become relevant later.
