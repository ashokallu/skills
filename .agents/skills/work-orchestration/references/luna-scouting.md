<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-10-07 (Model substitution to GPT-6-Luna; lane contract preserved, wrapper smoke verified) -->

# Luna Scouting

```text
Type: owning lane
Use when: an approved child contract names Luna
Skip when: no approved child contract names Luna or the unit requires mutation/judgment
Owns: invocation, scope, evidence shape, and failure handling after `delegation` has
      selected Luna for a bounded read-only task
Does not own: the spawn decision, final judgment, implementation, readiness, external
              mutation, or production/data safety decisions
Allowed side effects: read-only target access; disposable local output only when the
                      child contract authorizes the exact path, retention, and cleanup;
                      no target mutation
Inputs: Delegation ID and complete child contract
Exit states: complete, partial, timed-out, unavailable, rejected
Outputs: cited scout/monitor evidence for parent verification
Re-enter when: target, scope, boundary, capability, or parent need changes
```

Luna is optional unless the user or a selected workflow explicitly names it.
Availability, quota, parent token pressure, or mechanical eligibility is not a
reason to call it. `delegation` must first establish a concrete net-positive
child contract.

Luna is a headless Codex process, not an in-process child tied to the caller's
harness. Codex, Claude, AGY, and other local harnesses may invoke the same repo
wrapper and consume its saved result. The calling parent still owns delegation,
scope, join, and verification.

Do not hardcode a model name, context size, CLI version, or wrapper behavior in
this durable lane. Use `runtime-capability-check` and current repo configuration
to verify the available Luna-backed role, model, sandbox, network access,
wrapper flags, output location, timeout support, and quota.

## Good Uses

- code path, symbol, caller, import, or nearby test mapping;
- route, config, workflow, docs, TODO, or stale-comment inventory;
- validation-command discovery from current manifests/workflows;
- bounded PR/body/doc consistency checks;
- read-only CI/check/review-state inventory for a supplied PR/head;
- a long read-only watch with explicit target, timeout, stop states, and join;
- several independent mechanical searches with non-overlapping scopes.

Luna is most valuable when it replaces mechanical parent reading. It must own
a surface the parent is not simultaneously redoing.

## Do Not Use For

- final code review, merge/readiness verdict, architecture, product, or safety
  decisions;
- implementation or repository edits;
- auth, permissions, secrets, private user payloads, migrations, production
  config, data mutation, or destructive work;
- live GitHub, cloud, ticket, PR, workflow, reviewer, or thread mutation;
- broad whole-repo/whole-PR/multi-domain tasks that exceed the verified context
  or cannot return a small evidence shape;
- duplicate inspection of a small diff the parent must read hunk-by-hunk anyway;
- root-cause conclusions without parent verification.

A user-requested experiment with Luna still requires an explicit side-effect
boundary and must not be mistaken for production-ready work.

## Non-Duplication Rule

Before invocation, name:

- the exact surface Luna owns;
- different parent work that continues in parallel, or why the parent waits;
- the join consumer;
- the condition under which the parent may take over.

The parent may inspect the same surface only after Luna fails, times out,
returns stale/uncited/incomplete evidence, or yields ownership because parent
judgment is required. Verification of cited anchors is not duplication.

## Scope Design

Keep each call to one coherent bounded unit:

- one directory/package/route family;
- one PR head and one evidence class;
- one document set or config family;
- one validation-discovery question;
- one monitored operation.

Prefer targeted reads and small evidence packets over file dumps or long logs.
Split independent domains into separate calls only when delegation economics
remain positive and capacity is reserved for mandatory gates.

`--scope`-style wrapper declarations are prompt/evidence boundaries, not a
confidentiality guarantee, unless the runtime proves filesystem enforcement.
Read-only sandboxes may still expose host-readable files. Do not send sensitive
work to Luna merely because edits are blocked.

## Invocation Discovery

For repo Luna work, a Codex caller may prefer a task-appropriate native
Luna-backed role when its configuration proves the required boundary. A caller without that in-process role uses
the repo wrapper as the normal cross-harness path. Do not assume a generic
model override has the same sandbox or result contract.

Resolve the invocation path in this order:

1. reusable matching Luna session whose target and scope remain current;
2. configured native Luna-backed read-only role;
3. repo wrapper documented by current repo instructions;
4. parent-owned fallback for optional work;
5. `BLOCKED`/`Pending Verification` when Luna is mandatory and no sanctioned
   path works.

Use one alternate path only when it changes a material failure variable and the
child contract still has net benefit. Do not probe multiple models/wrappers to
justify optional delegation.

When the repo wrapper exists, verify its current help before relying on flags.
The commonly expected shape is:

```bash
scripts/dev/agent-call-luna.sh \
  --title "<short-task-slug>" \
  --prompt "<bounded read-only task>"
```

Optional modes such as minimal-context, GitHub read-only, or cloud monitoring
must be verified from current wrapper help/config. A saved call artifact may be
the authoritative output when stdout is quiet; inspect the current invocation’s
artifact identity before declaring failure.

## Minimal-Context Mode

Use only for non-sensitive local mechanical scouting when the parent already
owns routing and the wrapper supports declared scopes.

Require:

- repo-relative existing scopes;
- read-only task;
- no secrets/auth/private data;
- no GitHub/cloud/network mode;
- post-call inspection for out-of-scope reads when event logs exist.

An observed out-of-scope read invalidates the result for trust-sensitive use.
Post-hoc event inspection can detect some violations; it cannot undo the read.

## GitHub Read-Only Mode

When live GitHub reads are required, use only a verified read-only mode. Allowed
examples may include PR metadata, check runs, workflow runs, and review-state
inventory. Forbid:

- comments, reviews, reviewer requests, metadata edits;
- reruns/cancellations, merges, thread resolution;
- pushes or repo edits.

Supply PR number, branch, exact live head SHA, required checks when known, and
terminal states. The parent owns live readiness wording and all mutations.

## Monitoring Mode

A Luna watcher needs:

```text
Operation and target ID:
Exact head/revision/as-of marker:
Expected states:
Unexpected states:
Read-only evidence sources:
Poll cadence and timeout:
Terminal stop conditions:
Parent join action:
```

Use `waiting-and-monitoring` and verify that the runtime can return the result.
Do not monitor the same surface in parallel. Luna observes; it does not request
reviews, rerun CI, resolve comments, approve release, decide GO/NO-GO, abort
operations, or claim readiness.

For CI/review monitoring, stop when:

- all required current-target checks/review state are terminal;
- a required failure appears;
- the target/head changes;
- evidence access fails;
- the timeout expires.

## Cloud Monitoring Mode

Use only a current repo-documented read-only wrapper mode and a bounded operator
prompt. The parent retains GO/NO-GO, mutation, cleanup, data safety, and final
health judgment.

Prefer fresh per-call credentials and secret-safe summaries. Do not print bearer
tokens, DSNs, cookies, or raw credential-bearing output. Route data-access
mechanics through `readonly-data-access`.

Repo-specific query-shape notes are hints, not authority. Verify them against
current runbooks/API schema before use. In particular, Cloud SQL Monitoring
resource labels, region labels, and REST paths are easy to mis-shape; a no-data
result after a guessed label/filter is a query failure until one calm
instruction-backed correction confirms otherwise. Do not let a scout thrash
through speculative probes or reinterpret wrapper mistakes as service-health
evidence.

## Prompt Contract

```text
Objective:
<one scout or monitoring outcome>

Target and freshness:
<paths/PR/head/run/revision/as-of marker>

Scope:
<small files, symbols, commands, docs, or evidence packet>

Stop condition:
<exact evidence, terminal state, timeout, or blocker>

Constraints:
- Read-only. Do not edit or mutate local/remote state.
- Do not broaden beyond scope.
- Do not inspect sensitive material.
- Cite file:line, command/result, URL/ID, or artifact evidence.
- Mark unsearched or unproven scope Pending Verification.

Return:
- Target identity and freshness.
- Findings/observations with evidence.
- Scope not covered.
- Suggested next owner when action is needed.
- Pending Verification.
```

For candidate-work discovery, require ranked bounded tasks with evidence,
expected owner, and proof surface; the parent chooses what is worth doing.

## Result Acceptance

The parent verifies:

- invocation/target identity;
- scope compliance and sensitive-data boundary;
- cited anchors and current target;
- whether the output answers the contracted question;
- whether any claim exceeds the evidence.

Discard invented commands, malformed links, uncited confident claims,
scratchpad leakage, out-of-scope evidence, and stale-head results. Use the valid
remainder only when it remains independently useful.

## Output

```text
Luna outcome: COMPLETE | PARTIAL | TIMED OUT | UNAVAILABLE | REJECTED
Delegation ID and target:
Invocation path/capability verified:
Evidence artifact:
Accepted findings:
Rejected/stale/out-of-scope portions:
Parent verification:
Next owner:
Pending Verification:
```
