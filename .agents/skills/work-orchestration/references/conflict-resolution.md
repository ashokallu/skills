<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (user instruction versus user-asserted fact) -->

# Conflict Resolution

```text
Type: decision gate
Use when: authoritative sources or accountable roles materially disagree
Skip when: one source is merely stale, non-authoritative, or compatible after refresh
Owns: resolution of a material disagreement about instructions, evidence, target,
      ownership, severity, or verdict consequence
Does not own: implementation, majority voting, or repeated reviewer shopping
Allowed side effects: read-only evidence refresh and one bounded peer challenge
Inputs: exact conflicting claims, source authority/freshness, affected decision, and
        accountable roles
Exit states: resolved, provisional, needs owner, blocked
Outputs: governing source, decision boundary, next owner, and reopen condition
Re-enter when: new authoritative evidence or owner decision arrives
```

Use this lane when user intent, repo instructions, current source, docs,
reviewer output, CI, tool results, external sources, prior handoffs, or subagent
summaries disagree in a way that changes the next route, side-effect boundary,
or completion claim.

This lane resolves the conflict enough to choose the next safe owner. It does
not replace source lookup, validation, review, or implementation.

For parent, critic, reviewer, or specialist disagreement, this lane owns only
the challenge transport, round termination, and provisional side-effect
boundary. It does not take over the critic's plan verdict, the ordinary
reviewer's code verdict, the database reviewer's named database decision, the
intent owner's objective, or the parent's integration and write ownership.

## Use For

- current user request conflicts with previous messages, prior plans, handoffs,
  docs, or loaded lane instructions
- the user asserts a fact about current code, state, or history that current
  evidence contradicts
- current code contradicts docs, README examples, ADRs, runbooks, PR body text,
  generated artifacts, comments, or tests
- CI, local validation, reviewer comments, Copilot, Luna, or another subagent
  gives contradictory status
- external sources disagree about versions, APIs, dates, current facts, or
  operational state
- route ownership is unclear because two skills claim adjacent parts of the
  same workflow
- a completion claim would depend on choosing between stale and current proof
- a parent and critic, reviewer, or specialist materially disagree about a
  premise, relevance disposition, severity, decision scope, or evidence-backed
  verdict consequence

## Do Not Use For

- ordinary source lookup with no conflicting evidence; use `source-handling`
- route conflicts where the only question is immediate owner precedence; use
  the `work-orchestration` route precedence ladder, specialist routing table, and
  narrowest owning lane instead of inventing a separate conflict lane
- code review verdicts; use `reviewer` after a stable target exists
- ordinary finding acceptance with no material disagreement; verify and apply
  the finding through authoring and review-response workflows
- hiding uncertainty by choosing the convenient source

## Authority Order

Use the highest applicable authority, then verify the target is the same:

1. System/developer/runtime safety constraints and current repo `AGENTS.md`.
2. The latest explicit user instruction for this thread.
3. Current live state for the exact target: branch, PR head, CI run,
   environment, issue, page version, release, or source file.
4. Owning specialist lane or skill for the current phase.
5. Repo source of truth: source code, generated inputs, manifests, CI config,
   schema, tests, package locks, or deployment config.
6. Current official external source or authenticated API output.
7. Older docs, examples, comments, handoffs, summaries, screenshots, snippets,
   secondary sources, and memory.

A lower source can still be useful as a lead, but it cannot override a higher
source without direct evidence and an explicit rationale.

## User Instruction Versus User-Asserted Fact

The authority order above ranks *instructions*. It does not make a user's factual
claim outrank current evidence. Separate the two before resolving:

- **A user instruction** — what to do, what the objective is, what is acceptable,
  what is out of scope — is high authority. The user owns intent, priorities, and
  tradeoffs.
- **A user-asserted fact** — "that function is already gone," "CI passed," "the
  flag is off in Staging," "I already pushed that" — is evidence at the same level
  as any other secondary report. Current live state for the exact target outranks
  it.

When a user-asserted fact is material and current evidence contradicts it, do not
quietly proceed on the user's premise. Verify with the smallest read that can
settle it and name the exact target inspected.

When current exact-target evidence settles the fact and the corrected fact does
not change the user's objective, target, scope, or authority, there is no
remaining conflict for this lane to decide. Consume the
`state-synchronization` result, follow the verified fact, and tell the user.
Do not ask the user to choose between current evidence and a stale premise.
Ask for an owner decision only when the evidence remains inconclusive or the
correction materially changes intent, scope, authority, or the requested
outcome.

Use this compact discrepancy record when the correction changes the route or a
material claim:

```text
Premise check:
- user-asserted fact: <exact claim>
- current evidence: <command/file/state and what it shows>
- target match: <same target, or the mismatch that explains the difference>
- effect on the request: <what changes if the evidence is right>
- decision needed: <none, proceeding on evidence | owner decision required>
```

Many such conflicts are a target mismatch rather than an error: a different
branch, head, worktree, environment, tenant, or point in time. Check that before
treating the user as mistaken, and say which target you inspected.

Only the user can change intent in response to the correction. A corrected
premise never silently expands scope: if the evidence means the request needs
different or additional work, route that through `request-intake` or
`scope-change-control` rather than absorbing it.

When the user maintains the claim after seeing exact-target evidence, preserve
the verified fact. The user may change intent, scope, priority, or acceptable
risk within their authority, but cannot turn contradicted current state into
proof. If their response requests a materially different action, route it
through `request-intake` or `scope-change-control`. When safety, mutation, or a
completion claim still depends on unresolved evidence, preserve the stricter
provisional boundary and ask for the exact owner decision. Do not repeat the
same evidence at the user.

## Role-Bounded Decision Authority

Agents have equal standing to challenge a claim, but authority follows the
decision rather than agent rank:

| Decision | Governing owner or evidence |
| --- | --- |
| Current code, CI, database, environment, or external behavior | Current exact-target evidence |
| Objective, acceptance criteria, or non-goals | User or named intent owner |
| Pre-implementation plan verdict | Critic within the approved critic scope |
| Implemented-code verdict | Ordinary reviewer within the reviewed target |
| Named database decision | Database reviewer within its submitted evidence and decision scope |
| Integration, writes, sequencing, and publication | Parent within the approved objective and side-effect boundary |
| Repo policy or safety constraint | Highest applicable instruction or authorized human owner |

The parent cannot silently replace a specialist verdict with its own. A
specialist cannot turn its verdict into write authority, objective amendment,
or a decision outside its named scope. Consensus, agent count, confidence
language, seniority, and repetition are not evidence.

## Peer Challenge Trigger

A finding or recommendation becomes a peer conflict only when another owner
materially disputes its premise, target relevance, severity, evidence class,
decision scope, or required consequence. Do not activate this protocol for
wording preferences, already-dispositioned unrelated observations, or a
finding the parent accepts after direct verification.

Keep the reviewed plan or diff stable while the challenge is open. For owned
work, reuse the active objective-lock relevance disposition. For teammate PR
review, use the current live intent and head; do not manufacture a retroactive
objective lock.

Start one append-only disagreement row with a stable ID:

```text
Peer challenge:
- disagreement ID: <stable ID>
- active objective: <lock ID/version or teammate PR intent/head>
- decision affected: <plan | code verdict | database decision | integration | completion>
- challenged claim: <exact claim and emitting owner>
- counterclaim: <exact disagreement>
- target/freshness: <immutable target and observation boundary>
- evidence: <artifacts for both claims, with gaps marked Pending Verification>
- objective relevance: <direct | protective | contract-changing | unrelated>
- role boundary: <who owns the verdict, intent, evidence collection, and writes>
- smallest settling evidence: <artifact or owner decision that can change the result>
- provisional side-effect boundary: <continue read-only | reversible action | fail-closed hold>
```

When the challenge crosses sessions, tools, or organizations, dispatch it through
[delegation.md](delegation.md) after
[runtime-capability-check.md](runtime-capability-check.md) and the applicable
privacy, cost, and side-effect boundaries are satisfied. A same-thread role
exchange does not require inventing a child worker.

The challenged owner answers once:

```text
Peer response:
- disagreement ID: <same ID>
- disposition: <accept | modify | stand | Pending Verification | escalate>
- governing evidence: <artifact or exact missing proof>
- objective relevance: <verified disposition and causal link>
- decision impact: <what changes or remains blocked>
- next owner: <one owner>
```

The challenger then records one reassessment:

```text
Peer reassessment:
- disagreement ID: <same ID>
- terminal state: <withdrawn | resolved as modified | stands | escalated>
- governing evidence: <artifact or owner decision>
- final provisional boundary: <allowed action or exact hold>
- next route: <owning lane>
```

This is not hidden reasoning or a meeting transcript. Record only the claims,
evidence, disposition, and decision needed by the next owner.

## Packet And Reassessment Boundaries

Use the generic peer-challenge packet for plan, finding, relevance, severity,
and verdict-consequence disagreements. When a reviewer emitted a canonical
`REH-n` Risk Evidence Handoff, keep using the existing `Evidence Response
Packet For Reassessment` for that operational evidence. Do not duplicate its
fields or wrap it inside a peer-challenge packet; reference the matching
`REH-n` row as the disagreement evidence instead.

A response never edits the original verdict. The original critic, reviewer, or
database reviewer reassesses its own decision against the returned evidence.
The parent records whether it accepts, disputes, or escalates the result for
integration, but it does not relabel a standing specialist verdict as rejected
or passed.

## Termination And Reopen Rules

One challenge, one response, and one reassessment is the normal maximum. After
that, resolve through the governing evidence or escalate to the named decision
owner. Do not repeat the same argument, spawn more agents to outvote a verdict,
or conclusion-shape a fresh reviewer prompt.

Reopen the same disagreement only for:

- new evidence that can change the disputed claim;
- a changed immutable target;
- an explicitly amended objective or non-goal; or
- a newly discovered safety boundary with a reachable causal chain.

Renaming the concern, changing agent identity, restating the same evidence, or
wanting a different verdict does not reset the round.

When high-risk conflict remains unresolved, preserve the stricter provisional
side-effect boundary and fail closed on the exact affected decision. This is a
temporary safety hold, not an automatically adopted final verdict. When
low-risk conflict remains unresolved, take the safest reversible action and
mark the exact claim `Pending Verification`.

## Anti-Gaming Rules

- The burden of proof follows the claim and claimed impact.
- Severity cannot increase without stronger reachability or impact evidence.
- A specialist cannot block a decision outside its named scope.
- A parent cannot silently discard a material specialist finding; challenge it
  with evidence or retain it in the final synthesis.
- A specialist that stands must name the governing evidence and the smallest
  evidence that could change its decision.
- A changed mind after better evidence is successful review, not lost authority.
- No majority vote, agent shopping, status language, or repeated assertion can
  replace current evidence or the correct owner decision.

## Conflict Procedure

1. Name the conflicting claims and the targets they describe.
2. Check whether the conflict is real or target-mismatched: different branch,
   head SHA, environment, tenant, version, time, or scope.
3. Refresh the smallest current source that can settle the next action.
4. If settled, update the route ledger with the governing source and proceed
   through the owning lane.
5. If unresolved and low risk, proceed with the safest reversible assumption and
   mark `Pending Verification`.
6. If unresolved and high risk, remote-writing, production-affecting,
   destructive, auth/data/security-sensitive, or policy-changing, stop and ask a
   targeted question or require owner approval.

For an agent-to-agent dispute, execute the peer challenge after step 3 and use
its terminal state as the input to steps 4 through 6.

## Conditional Worked Example

For a multi-lane task whose collaboration or disagreement path remains
unclear, a repository may provide optional mentorship material at
`docs/agents/collaborative-lane-workflow-example.md`. Consult it only when that
path exists in the current checkout. Its absence is not a blocker. The example
is not workflow law or completion proof and creates no mandatory read,
acknowledgement, narration, lane, agent, packet, or per-run artifact.
Fast-exit, single-lane, and conflict-free work must not load or replay it merely
because it may exist elsewhere.

If the bounded pass cannot produce new evidence or identify a governing owner,
and another pass would not change the target, source, owner, or hypothesis,
route through `loop-control-and-escalation` instead of repeating the challenge
or shopping for another verdict.

## Output

```text
Conflict decision:
- conflict:
- governing evidence:
- target/freshness checked:
- decision:
- next route:
- side-effect boundary:
- Pending Verification:
```
