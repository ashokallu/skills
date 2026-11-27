# Initial review thoroughness primer

For an accepted whole-target initial review at FULL depth, read this primer
through EOF before evidence-heavy analysis. Use the active reviewer skill's
scope, evidence, and closeout requirements.

## Example

A pull request changes how a background job resumes after a timeout. The
existing review thread notes a naming issue. The first pass agrees and
checks the successful path. It leaves the retry transition unexamined.
The second pass follows the persisted cursor through a timeout and restart.
It finds that the cursor advances before the transaction commits, which
would skip an item if the worker crashes between those events.

The naming comment and the retry finding need different evidence. Confirm
the naming concern against repository conventions. For the retry finding,
trace the durable state and transaction boundary, identify the exact
triggering sequence, and explain which work is lost and how to guard it.

## Review discipline

- Start from the exact revision and the accepted scope. Treat existing
  discussion as a lead and independently inspect the changed call paths.
- Review the successful path and the edge states that follow from the actual
  diff, including failure, retry, partial completion, and conflicting
  callers where applicable.
- Follow blockers to the point where evidence supports the consequence.
  If proof is missing, identify the smallest check or artifact that could
  change the verdict.
- Tie each finding to its location, triggering condition, consequence, and
  a practical correction. Separate evidence you inspected from verification
  that remains pending.
- Stop once the accepted review coverage and evidence requirements are met.
  Carry only material findings and unresolved verification into the verdict.
