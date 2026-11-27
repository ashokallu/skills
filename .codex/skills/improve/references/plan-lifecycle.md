<!-- markdownlint-disable MD013 MD060 -->

# Improve Plan Lifecycle

Use for explicit `improve reconcile`.

Resolve one `plan_root` and read its index plus referenced plans. Only the
advisor or orchestrating parent updates lifecycle state.

For each plan:

- `DONE`: spot-check current done criteria and record the verified revision;
- `BLOCKED`: inspect the blocker, then refresh the same plan only when the
  approach remains valid; otherwise supersede or reject it with evidence;
- stale `IN PROGRESS`: inspect the named worktree or handoff evidence and
  report the missing owner or state before changing status;
- `TODO`: run the drift check, re-verify that the finding still exists, and
  refresh current-state evidence and planned-at SHA when needed;
- obsolete or independently fixed work: mark `REJECTED` with the proof.

Do not delete completed plans; they are decision records. Do not treat a status
label or executor summary as proof. Re-open the cited code, validation result,
review verdict, or current git state needed for each transition.

Reconciliation is advisory plan maintenance. It does not authorize source
edits, worktree cleanup, commit, push, issue mutation, or publication. If a
plan becomes executable, return it through
[execution-handoff.md](execution-handoff.md) only after an explicit execute
request.
