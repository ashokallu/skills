<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (canonical owner of the suspension-boundary serialization) -->

# Task Suspension Checkpoint

```text
Type: owning lane
Use when: a new request may pause a non-trivial unfinished objective, or observable
          context pressure threatens loss of current reasoning
Skip when: the new message is an in-scope follow-up, the old task is complete, or the
           user simply asks for status
Owns: classification of an interruption, preservation of resumable state, and safe
      return to the suspended objective
Does not own: reprioritization authority, cancellation, or the tangent itself
Allowed side effects: one secret-safe gitignored session-owned checkpoint for a
                      user-directed same-session tangent; proactive persistence only
                      when the active workflow already authorizes it
Inputs: active objective/target, mutation state, evidence, approvals, next action, new
        request, and available continuity transports
Exit states: follow-up, checkpointed, suspended, replaced, cancelled, blocked
Outputs: checkpoint location/content, tangent disposition, and exact resume point
Re-enter when: tangent ends, user changes priority, or resumed target/state changes
```

The goal is to preserve expensive reasoning and live evidence without making
every interruption a ceremony or blocking all work when a preferred session ID
or filesystem path is unavailable.

## Classify The New Request

- **Follow-up:** advances, validates, clarifies, reviews, or reports on the same
  primary outcome and next consumer.
- **Tangent:** creates a different deliverable or next consumer while the active
  objective remains valid.
- **Replacement/reprioritization:** the user changes the primary outcome or
  priority. Preserve or disposition the unfinished objective here, then route
  the replacement through `request-intake`; use `objective-lock` when its
  contract or authority must be locked. Use `scope-change-control` only when the
  original objective remains active and the new request modifies its scope.
- **Cancellation/undo:** route through `abort-and-unwind`.

Phrases such as “before we do this,” “while we wait,” “first handle,” and
“separately” normally indicate a tangent, not cancellation.

## Context-Rot Risk

Assess what would be expensive or unsafe to reconstruct:

- approved plan, critic/reviewer/council decision;
- exact next command, worktree, branch, PR, test matrix, or prepared mutation;
- live production/data/log/metric/query-plan evidence;
- run IDs, environment state, time-sensitive external operation, or monitoring
  obligation;
- multi-step reasoning not represented in a durable artifact.

Classify:

- **Low:** cheap to reconstruct; no live obligation or approved complex plan.
- **Medium:** non-trivial plan/evidence chain or prepared state exists.
- **High:** live operation, sensitive production evidence, approved high-impact
  plan, or several hours of reasoning would be lost or misapplied.

For medium/high risk, tell the user exactly what is being preserved and the
resume point. Push back only when switching now could create an unsafe loss of
state or abandon an active operation without an owner. The user controls
priority; do not require confirmation merely to enforce a preferred session
boundary.

## Checkpoint Side-Effect Boundary

A checkpoint is local workflow metadata under gitignored `tmp/`; it is not a
product, source, git, or remote-state edit. A user-directed same-session switch
to a tangent authorizes only the disclosed checkpoint write required by this
repo workflow. Tell the user before writing it.

An explicit user or higher-priority no-local-write boundary still wins. In that
case, do not write a checkpoint and do not start the tangent in the same
session. Report that safe suspension is blocked and recommend a separate
session or explicit permission for the workflow-metadata write.

Proactive context pressure without a user-directed tangent never creates write
authority. Persist only when local workflow writes are already inside the
active side-effect boundary. Otherwise use a proven runtime-internal non-repo
continuity mechanism, or finish the current stable milestone and report the
continuity risk.

When explaining the boundary to the user, serialize it:

```text
Suspension boundary:
- bare halt: abort-and-unwind; no checkpoint
- user-directed same-session tangent: disclosed gitignored workflow-metadata
  write; tangent blocked until checkpoint exists
- no-local-write exit: separate session | explicit write permission
- re-entry: separate session | explicit write permission
```

For a no-local-write case or a missing stable session identity, serialize both
blocked states explicitly so the user sees why the tangent cannot start here:

```text
- local checkpoint write: blocked
- same-session tangent: blocked
```

## Proactive Context-Pressure Checkpoint

Use the same checkpoint contract without a tangent when there is an observable
continuity risk, such as an approaching or announced compaction, a very long
session with substantial unpersisted state, or degraded recall of earlier
approvals, evidence, or decisions. Do not trigger this path from vague anxiety
alone; tie it to a concrete loss risk.

1. Finish or safely stop the current atomic action. Do not interrupt an in-flight
   write merely to checkpoint.
2. Choose the smallest checkpoint level that permits a cold resume.
3. Record the classification as `context-pressure`; record the tangent as
   `none: proactive context-pressure checkpoint`.
4. Use the storage and ownership rules below. Proactive context pressure without a user-directed tangent never creates write
   authority: use a proven runtime-internal continuity mechanism unless a
   secret-safe artifact is already permitted.
5. Prefer completing the current stable milestone before starting a new
   discovery-heavy phase when recall is degrading.
6. When a durable artifact is created or refreshed, tell the user its exact path
   and the resume point. Do not imply a fresh session is mandatory when the
   current one remains sound.

This path preserves state **before** loss. Use `context-recovery` to reconstruct
state after compaction, a crash, or a stale/incomplete handoff has already
occurred.

## Checkpoint Levels

Choose the smallest level that permits a cold resume.

### Level 1 — Compact

Use for low-risk work:

```markdown
# <Objective>
Status: suspended | active-checkpointed
Last updated: <timestamp>

## Outcome And State
- Goal:
- Completed:
- Current target:
- Exact next action:
- Proof needed:
- Do not repeat or substitute:
- Refresh before resume:
- Pending Verification:

## Interruption
- Tangent/request: <none for a proactive context-pressure checkpoint>
- Resume trigger:
```

### Level 2 — Standard

Use for medium risk. Add:

- governing request and accepted plan;
- files/symbols/branches/PRs/resources;
- important evidence and artifact pointers;
- decisions/rejected alternatives;
- validation already run;
- blockers, assumptions, and active side effects;
- next owning lane and first reads/commands.

### Level 3 — Operational

Use for high risk or live external obligations. Add:

- environment, principal, resource/run IDs, timestamps, and latest observed
  state;
- every active operation, terminal method, next check, timeout, and owner;
- rollback/containment state;
- sensitivity/redaction boundary;
- evidence → inference → conclusion chain;
- known footguns and do-not-repeat decisions;
- approvals that remain valid and their exact scope.

Do not paste secrets, cookies, tokens, private payloads, huge logs, or full files.
Use stable artifact pointers with purpose, relevant section/symbol, freshness,
and required revalidation.

## Storage And Ownership

Use one active checkpoint file per agent session. The current runtime's stable,
non-secret session or thread identifier is the only valid lookup key. A
user-directed same-session tangent uses the narrow workflow-metadata authority
above; proactive context pressure must already have write authority.

Preferred path:

```text
tmp/task-checkpoints/<stable-session-id>.md
```

If the runtime does not expose a stable session identifier, stop before a
same-session tangent and report that a safe checkpoint cannot be owned. A
separate session remains available for the tangent.

Do not scan for the “newest” checkpoint and assume ownership. A resumed agent
must be given the exact path or packet. Do not use shared `current.md`/`latest.md`
files when concurrent sessions can collide.

Checkpoint failure blocks the same-session tangent. A response-only packet is
not a substitute for the session-owned cold-resume artifact. Proactive
context-pressure continuity may remain response-only because that path creates
no write authority.

When using a writable artifact, update the session's one active checkpoint file
rather than creating a second objective-named or “latest” copy. The file may
replace its suspended-objective content only after the prior objective is
marked `complete`, `abandoned`, or `transferred`. Remove it only when cleanup is
separately authorized and the artifact is proven to be owned by the current
workflow; otherwise leave the exact path in the handoff.

## Mandatory Content

Every checkpoint, regardless of level, must allow a fresh owner to answer:

1. What outcome is still owed and why?
2. What is already complete?
3. What exact target/state is current?
4. What evidence supports the current conclusion?
5. What side effects or operations remain active?
6. What is the next action and what proof must it produce?
7. What must not be repeated or substituted?
8. What must be refreshed before resuming?

When a decisive user instruction is short and safe, quote it accurately. For
large requests, summarize and point to a durable brief rather than copying raw
conversation history.

## Active Operations

A tangent does not silently suspend monitoring or ownership. For each
non-terminal operation, choose one before switching:

- keep a verified watcher and join path;
- perform the next bounded check and park with an exact re-entry condition;
- transfer to an accepted owner;
- cancel/contain through the owning workflow.

Do not claim background monitoring continues unless `runtime-capability-check`
verified it.

## Resume Gate

Before resuming:

1. read the checkpoint through EOF;
2. verify target/branch/PR/resource identity;
3. refresh drift-prone local and remote state;
4. check whether user intent, scope, approvals, or instructions changed;
5. reconcile active operations and `Pending Verification`;
6. restate the exact next action and proof;
7. re-enter the dispatcher for the resumed phase.

Do not resume by blindly executing the saved command. The checkpoint records
intent and evidence; current state remains authoritative.

## Cold-Resume Test

The checkpoint is sufficient when a fresh agent can continue without guessing
at the primary outcome, target, permission boundary, next action, or live
obligation. It does not need to reproduce every thought or transcript detail.

## Output

```text
Suspension decision: FOLLOW-UP | CHECKPOINTED | SUSPENDED | REPLACED |
                     CANCELLED | BLOCKED
Active objective:
Tangent/context classification:
Context-rot risk and checkpoint level:
Checkpoint path or transport:
Active operations disposition:
Exact resume point:
User-visible caveat / Pending Verification:
```
