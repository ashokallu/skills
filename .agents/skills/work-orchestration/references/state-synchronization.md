<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-25 (settled user-premise ownership) -->

# State Synchronization

```text
Type: decision gate
Use when: prior local or remote evidence may no longer describe the target
Skip when: the target is immutable or current evidence remains fresh for the next action
Owns: refresh of the minimum mutable state needed for the next action or claim
Does not own: merge, rebase, reset, commit, push, PR mutation, deployment, or product
              diagnosis
Allowed side effects: read-only by default; bounded fetch is an explicit
                      remote-read/local-ref-write exception requiring repo policy and
                      current permission
Inputs: next action/claim, target identity, prior evidence, and freshness risk
Exit states: current, stale, conflicting, blocked, concurrent
Outputs: refreshed target identity, discarded stale proof, and one next owner
Re-enter when: the target changes again or a freshness deadline expires
```

The gate answers one question: **is the evidence current enough for the next
side effect or claim?**

## Use For

- continuation after a pause, handoff, context recovery, rebase, force-push,
  failed push, CI rerun, reviewer update, release, or user correction;
- before a target-sensitive commit, push, PR mutation, thread action, release
  validation, status/readiness claim, or handoff;
- delegated/reviewer evidence tied to an older branch, head SHA, environment,
  run, or document version;
- validation that may have run in another checkout, module, env, or commit;
- versioned external resources such as PRs, CI runs, Jira issues, Confluence
  pages, releases, deployments, cloud resources, and data snapshots.

Skip when the exact target was just inspected and no mutation or passage of time
could make the evidence stale.

## Refresh The Minimum Surface

| Surface | Minimum current proof |
| --- | --- |
| Local repo | working directory, branch/detached state, status, relevant diff |
| Branch/commit | base, head SHA, upstream/ref relationship, latest commit |
| PR | number, base, live head SHA, changed files, relevant metadata, current-head checks/threads |
| Validation | command, working directory, exact checkout/head, env, result |
| External doc/ticket | resource ID, version/status, project/space/board, last update |
| Release/deploy | environment, release/commit, live revision/image, traffic/readiness, flags |
| Data/cloud | project, environment, principal, resource/query scope, read/write boundary |
| Generated artifact | source inputs, generator version/command, generated diff freshness |

Do not refresh unrelated surfaces “for completeness.”

## Read-Only Default

State synchronization does not silently repair state.

- Inspect `origin/main`, a release tag, remote refs, or live metadata directly
  when that proves the fact.
- A fetch may be used only as an explicit bounded refresh when current
  instructions permit both the remote read and local ref write and it cannot
  overwrite local work. Do not describe fetch as a purely read-only operation.
- Merging into `local-dev-reference`, rebasing, resetting, committing a sync,
  pushing, editing PR metadata, or changing an external resource is a separate
  `worktree-readiness`, publication, or specialist phase with explicit
  authorization.
- Never mutate a checkout merely to make a status answer look current.

When a merged PR or deployed release is reported, distinguish:

1. PR merged;
2. commit included in a published release;
3. release or manual deploy present in the target environment;
4. behavior verified live.

Inspect only as far as the user’s next requested action or claim requires. Do
not automatically expand a merge status check into release/deployment
investigation. When live behavior proof is required, hand off to
`release-regression-validation`.

## Settled User Premises

When a user-asserted current-state fact is material, refresh the smallest exact
target that can settle it. First check whether an apparent contradiction is
actually a branch, head, worktree, environment, tenant, or time mismatch.

If current exact-target evidence conclusively settles the fact and the
correction leaves the objective, target, scope, authority, and requested
outcome unchanged:

- proceed on the verified fact;
- inform the user of the correction and the exact target inspected;
- do not ask the user to choose which fact is current; and
- return to the current owning lane without activating conflict or scope
  control.

If evidence remains inconclusive, hand off to `conflict-resolution`. If the
correction changes intent, target, scope, authority, or outcome, hand off to
`request-intake` or `scope-change-control`; never absorb the delta silently.

## Staleness Rules

Evidence becomes stale when its identity or assumptions change. Examples:

- CI is green for an old head SHA;
- review threads were read before the last push;
- a branch was rebased after validation;
- a PR body or file inventory predates the current diff;
- a document/ticket version changed before mutation;
- a release plan predates a deploy, rollback, or traffic change;
- generated output predates source/generator changes;
- external issue grouping, tags, or representative events changed.

Discard stale proof. Refresh, rerun, or mark the exact gap `Pending
Verification`; do not weaken the wording while reusing the old evidence.

## Concurrent Or Conflicting State

If refresh reveals another active writer or unexplained changes, do not clean,
reset, overwrite, or adopt them silently. Classify:

- plausible concurrent actor → `parallel-work-coordination`;
- stale continuation or wrong target → `context-recovery` or dispatcher;
- material disagreement between authoritative surfaces →
  `conflict-resolution`;
- failed refresh/tool/auth path → `execution-recovery-and-tool-failures`.

## Output

```text
Gate: state-synchronization
Decision: CURRENT | STALE | CONCURRENT | CONFLICTING | BLOCKED
Surface and target:
Refreshed evidence:
Stale evidence discarded:
Mutation performed: none <or explicitly authorized harmless fetch>
Next owner:
Recheck trigger:
Pending Verification:
```
