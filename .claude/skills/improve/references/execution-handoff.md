<!-- markdownlint-disable MD013 MD060 -->

# Improve Execution Handoff

Use only for explicit `improve execute <plan>`. This variant validates and
hands off an accepted specification; it does not create a second implementation
workflow.

## Preconditions

1. Resolve `plan_root` under the Improve Plan Root contract and confirm the
   plan is inside it.
2. Read the plan completely and verify dependency status in
   `<plan_root>/README.md`.
3. Run the plan's drift check and re-open its load-bearing current-state
   evidence.
4. Stop for reconciliation when the plan is stale, ambiguous, missing a
   dependency, or cannot prove its verification commands.
5. Confirm the user's execution request and allowed side effects. Selection of
   `execute` does not authorize commit, push, PR publication, GitHub writes,
   or production mutation.

## Return To Repo-Native Execution

Re-enter `work-orchestration` with the accepted plan as the execution
contract. The normal owners remain mandatory:

- `delegation` decides capacity, work packets, parent critical path, and joins;
- `worktree-readiness` owns isolated worktree and git mechanics;
- `code-authoring` owns implementation and its selected domain lanes;
- the orchestration `validation` lane owns verification selection and proof;
- `reviewer` owns the stable-diff formal verdict; and
- commit, push, publication, GitHub, and production actions require their normal
  routes and explicit authorization.

Do not name a runtime-specific agent type, model, message primitive, or
worktree-isolation syntax here. The active orchestration runtime selects those
mechanics.

## Advisor Acceptance

After implementation validation and formal review, the advisor may assess plan
conformance:

1. verify every changed hunk maps to a plan step;
2. confirm no product file outside plan scope changed without an approved plan
   revision;
3. re-run or inspect the evidence for every done criterion;
4. inspect new tests rather than trusting their pass status;
5. classify deviations as accepted, revision required, or blocked.

Advisor acceptance supplements normal authoring and review gates; it never
replaces them.

Only the advisor or orchestrating parent updates the plan index after verified
evidence. Executors return changed paths, validation results, STOP conditions,
and deviations. Their product-code scope excludes `<plan_root>/README.md`.

A completed execution handoff ends with the current worktree/branch, changed
files, validation evidence, reviewer verdict, plan-conformance decision, index
status, and any still-unauthorized publication step.
