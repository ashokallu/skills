<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (actionable, secret-safe, non-mutating handoffs) -->

# Agent Handoffs

```text
Type: owning lane
Use when: scoped work is complete/blocked and another owner must act, or the user asks
          for a fresh-thread handoff
Skip when: the current owner can complete the next phase in the same context
Owns: transfer of a bounded task/result to the next project owner and creation of an
      end-of-thread continuity packet
Does not own: selecting delegation initially, implementation, hidden cleanup,
              git/publication mutation, or external-harness invocation
Allowed side effects: read-only packet creation; durable artifact writes only when
                      already authorized by the active workflow
Inputs: current phase/result, target, evidence, side effects, approvals, blockers, and
        named next owner
Exit states: actionable, blocked, complete, transferred
Outputs: one next owner and a compact evidence-bearing packet
Re-enter when: next owner rejects it, target changes, or missing evidence is supplied
```

Do not invent agents. Use the current configured roster; verify it through
`runtime-capability-check` when availability matters.

## Project Roster

| Agent | Use when |
| --- | --- |
| `code-mapper` | read-only navigation, dependency/symbol/caller mapping |
| `ui-debugger` | browser reproduction and console/network/DOM evidence |
| `critic` | independent pre-implementation challenge of a plan/proposal |
| `database-reviewer` | SQL/schema/migration/query/data-access review |
| `devops` | Terraform/IAM/GCP/Cloud Run/monitoring review |
| `security-auditor` | auth, authorization, secrets, permissions, injection, exposure |
| `tester` | verification plan, regression risk, flaky-test and CI/local check selection |
| `reviewer` | final stable-target correctness/regression/security/workflow verdict |

Name the owning specialist directly when the receiving workflow accepts that
route. Use `parent` when no configured roster agent or specialist fits, user
judgment is required, or the parent must re-enter the dispatcher before the
next owner can be selected safely.

## Handoff Rules

- Return `ACTIONABLE` only when the current scope is complete enough for the
  next owner to act.
- Choose one next owner. Mention secondary gates only as dependencies.
- Do not implement work outside the current role or spawn nested agents unless
  the parent explicitly authorized nesting.
- Include exact target/freshness, side-effect boundary, evidence, acceptance,
  and `Pending Verification`.
- On failure, include what was attempted, exact blocker, evidence, and the
  smallest safe next step. “Needs investigation” is not actionable.
- Do not paste whole files, large logs, raw payloads, or long research dumps.
  Use compact summaries and stable secret-safe artifact pointers.
- Validate structured artifact pointers: schema, task scope, allowed path,
  freshness/expiry, and checksum/byte count when available. Do not infer a
  pointer from prose.
- Strict specialist packets override this generic format.

For documentation work, include intent, audience, doc type, in/out scope, file
targets, outline, verified sources, decisions/invariants, and gaps. Do not turn
the handoff into the full draft unless the current owner owns authoring.

## ACTIONABLE Packet

```markdown
Status: ACTIONABLE | BLOCKED | COMPLETE
Next owner: <one roster agent, parent, or named specialist>

## Objective
<one or two sentences>

## Scope And Target
- Exact target/freshness:
- In scope:
- Out of scope:

## Route And Side Effects
- Owning lane/specialist:
- Allowed side effects:
- Risk/approvals:

## Evidence And Current State
- Work completed:
- Files/resources/branch/PR/run IDs:
- Validation/readback:
- Active operations:
- Assumptions and Pending Verification:

## Acceptance And Next Action
- Acceptance criteria:
- Exact next action:
- Stop/re-entry condition:
```

## End-Of-Thread Handoff

When the user says the thread is ending or asks for cleanup before a new thread,
create a paste-ready continuity packet without making them ask twice.

Before writing it:

1. Refresh only the state the next owner will rely on.
2. Update an existing durable runbook/skill/roadmap only when the user already
   authorized instruction/document edits or the active instruction-maintenance
   workflow requires them. Do **not** silently merge, commit, push, or mutate
   `local-dev-reference` as part of handoff creation.
3. Keep feature-branch code changes separate from instruction cleanup unless
   explicitly requested.
4. Use a concise local `tmp/requests/` brief only when filesystem writes are
   allowed and it materially improves cold resume. A raw request transcript is
   backup evidence, not the default brief.
5. Reconcile active waits/external operations. Park or transfer each with target,
   latest state, next check, and owner.
6. Run instruction/mirror/eval checks only for guidance files actually edited
   under the owning workflow.

The final handoff should contain:

- original outcome and why it matters;
- what changed or was decided;
- current branch/worktree/PR/resource IDs;
- side-effect boundary and approvals still valid;
- validation, review, CI, and external-state evidence;
- blockers, stale assumptions, active operations, and `Pending Verification`;
- exact next steps in priority order;
- durable files/skills/runbooks to read first.

Do not claim that background monitoring or future work continues unless a
verified owner accepted it.

## External Harnesses

For Claude Code, AGY, Copilot CLI, or other cross-harness work, use
`cross-harness-workflow` and its current collaboration wrapper. The
project `ACTIONABLE` packet is not a substitute for session/secret-safe
cross-harness transport. Never invent an external agent or paste credentials
into a handoff.

## Output

```text
Handoff outcome: ACTIONABLE | BLOCKED | COMPLETE | TRANSFERRED
Next owner:
Target and freshness:
Packet/artifact:
Active operations transferred or parked:
Pending Verification:
```
