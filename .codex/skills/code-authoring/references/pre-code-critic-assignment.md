<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-12 (bounded merits-first critic consultation) -->

# Pre-Code Critic Assignment

```text
Type: owning lane
Use when: a proposed implementation needs independent value or implementation-readiness
          challenge before meaningful edits
Skip when: the change is truly low risk and contained, or the exact unchanged plan already
           has a terminal critic disposition
Owns: critic brief readiness, contact accounting, finding disposition, and terminal join
Does not own: objective authority, user plan acceptance, implementation, final review, or Git
Allowed side effects: one read-only critic consultation lineage with at most three contacts
Inputs: clear objective, candidate revision, current evidence, scope/non-goals, risks,
        validation proof, authority boundary, and conformance attestation
Exit states: approved | escalation required | blocked | contact budget exhausted
Outputs: one terminal critic disposition bound to the candidate revision
Re-enter when: the objective, core decision, or risk boundary changes
```

Use this lane after idea challenge and lane selection, and before meaningful
edits, when a plan needs an independent challenge. It may answer both “should we
do this?” and “is this candidate ready to become an accepted plan?” in one
consultation.

The candidate is not an owner-accepted implementation plan yet. When
[plan acceptance](../../work-orchestration/references/plan-acceptance.md)
independently activates, it runs after terminal critic convergence. Do not ask
an owner to approve a design the critic is expected to change.

## Busy-Professor Contract

Treat each critic contact like a visit to a busy professor. The parent arrives
with complete decision-ready work after doing cheap relevant discovery. The
critic spends the scarce contact on decision quality, not header policing. The
analogy explains the operating constraint; it is not evidence or authority.

A consultation lineage permits at most three substantive parent-to-critic
contacts:

1. Contact 1 supplies the complete brief and should be capable of terminal
   approval.
2. Contact 2 is allowed only after the parent disposes every material finding
   from contact 1 and returns a materially revised candidate or new evidence.
3. Contact 3 is allowed only for focused reconciliation of the remaining
   decision-changing gaps and is terminal: approve, escalate, or block.

Three contacts are a ceiling, never a target. A successfully delivered prompt
that asks for substantive critic judgment consumes one contact. A transport
failure before delivery and a judgment-free readback do not. Renaming the
lineage, reformatting the same candidate, switching critics, or changing an
implementation detail cannot reset the counter. If a critic session must be
replaced after a tool failure, carry the same lineage, ordinal, candidate, and
prior dispositions.

A new lineage is valid only when the objective, core decision, or risk boundary
changes. Preserve the prior lineage and why it closed so a reset cannot hide
non-convergence.

## Readiness Before Contact 1

Before the first contact:

1. Read the PR 4685 lane-discipline case study and make its required agreement.
2. Resolve cheap current repo or environment evidence that can change the
   design.
3. Select the implementation lanes and convert them into concrete probes.
4. Complete the decision-focused
   [orchestration conformance attestation](../../work-orchestration/references/orchestration-conformance.md).
5. Prepare one concise brief with no governing-source path/hash inventory,
   all-gates recital, duplicated forward-analysis packet, or user-approved plan
   fiction.
6. Bind the brief to one candidate revision and one consultation lineage.

When a Work Item Profile is active, ask the critic to challenge the work item
classification and advisory review forecast only where they can change the
decision. They are planning inputs, never proof or a gate waiver.

When forward analysis was triggered, carry its decision-changing conclusions
and record ID/version in the brief. Do not reproduce an unchanged full record
when objective, evidence, alternatives, consumers, and claim boundary are
already available in the brief.

## Critic Consultation Brief

```text
Critic consultation brief:
- consultation: <lineage ID; candidate revision; contact ordinal>
- objective lock: <not required | lock-id@version>
- objective and outcome: <what must become true>
- target and non-goals: <affected boundary and explicit exclusions>
- current evidence: <only decision-bearing facts and pointers>
- candidate design: <mechanism and ordered decisions>
- alternatives: <credible options, dispositions, reopen evidence>
- risks, rollback, and detection: <failure modes and response>
- validation and next-consumer proof: <what proves the change and who accepts it next>
- unresolved decision-changing questions: <items or none>
- authority and side-effect ceiling: <applicable authority states and current exact boundary>
- prior material dispositions: <none on contact 1; disposition map later>
- requested verdict: <should-do and implementation-readiness decision>
```

This brief is a semantic contract, not a format trap. A missing or mislabeled
optional heading is non-blocking when the needed meaning is available elsewhere.
Missing objective, authority, safety, ownership, rollback, or verification
evidence remains substantive regardless of formatting.

Do not send a governing-source path or hash inventory. The attestation names
the decision owners consulted and one evidence pointer per triggered decision.
The critic may spot-check only current sources that can change its verdict.

## Finding Disposition And Follow-Up

For every material critic finding, record exactly one disposition:

- `resolved`: the candidate or evidence changed and the root issue is closed;
- `rejected with current evidence`: cite the evidence and preserve the critic's
  ability to stand or modify its finding;
- `routed to accountable owner`: the advice is contract-changing or requires
  owner authority; implementation remains frozen where it depends on that choice;
- `still blocking`: the evidence or safe design remains unavailable.

Do not silently discard, blindly incorporate, cosmetically reword, or relabel a
finding. The next contact carries the complete disposition map and only changed
design/evidence. An unchanged resubmission still consumes the contact and must
not receive a fresh full review.

The critic batches every decision-changing evidence request into its current
response and evaluates all independent merits possible from the available
semantics. A must-fix item includes evidence, consequence, and owner/action.
Correctable presentation defects do not pre-empt merits.

## Risk Overlay

Critic is required before edits for:

- production data, migrations, auth, permissions, secrets, privacy, security,
  infrastructure, deployment, IAM, or external integrations;
- generated contracts, public APIs, cross-service contracts, or feature-flagged
  rollout paths;
- broad refactors, architecture or ownership-boundary changes, module rewrites,
  or large mixed-surface changes; and
- workflow, skill, agent, reviewer, critic, default-gate, publication, or
  durable instruction changes that affect many future agents or reviews.

Critic is optional for a contained medium-risk change with one owner, no
production/auth/data/infra/public-contract boundary, and focused validation.
It may be skipped with a visible rationale for true low-risk typo, formatting,
or local reversible work that changes no durable behavior or default.

Use evidence-backed confidence:

- `HIGH`: target contract, affected consumers, current evidence, risks, and
  validation proof are known;
- `MEDIUM`: one non-central surface remains `Pending Verification`;
- `LOW`: ownership, behavior, risk, or proof is unclear enough that editing
  would move discovery into review.

## Ordering And Admission

Use this order:

1. Clear intent and objective authority.
2. Idea challenge and forward analysis when triggered.
3. Decision-ready candidate design and conformance attestation.
4. Bounded critic consultation to terminal disposition.
5. Exact plan acceptance when independently triggered.
6. Meaningful edits under the critic-approved candidate and owner-accepted plan.

Critic approval is implementation-readiness advice. It is not user acceptance,
execution authority, or permission for Git or external side effects. A material
post-critic change to target, mechanism, ownership, safety boundary,
rollback/detection, or verification proof invalidates the disposition. Ordinary
implementation detail inside those reviewed boundaries does not.

Once critic is invoked, silence is not approval. Do not edit, publish, or run a
mutating operation while its verdict is pending. Read-only evidence collection
is allowed only when it cannot change the candidate without a new contact.

## Acting On The Verdict

- `APPROVED FOR IMPLEMENTATION`: bind the disposition to the exact candidate
  revision, then run any triggered plan acceptance before editing.
- `REVISION REQUIRED`: dispose every material finding and use the next contact
  only when the candidate or evidence materially changed.
- `ESCALATION REQUIRED`: route the exact owner decision. Do not treat owner
  input as critic approval when it changes the core design; open a new visible
  lineage when required.
- `BLOCKED`: stop the dependent work.
- Contact 3 with any unresolved blocker terminates in escalation or blocking.
  There is no fourth consultation, critic shopping, or same-plan restart.

Do not ask critic to implement, review the finished diff, or follow the whole
task. Use the owning reviewer after a stable target exists.

## Skip Note

When skipping critic for a non-trivial-looking task, leave one sentence:

```text
Pre-code critic: skipped, because <risk, containment, and focused proof>.
```
