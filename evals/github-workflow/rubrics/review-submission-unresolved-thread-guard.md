---
name: review-submission-unresolved-thread-guard
version: 0.2.0
scale: pass-fail
description: Semantic contract for blocking a new review while the posting actor still has unresolved threads.
---

# Review Submission Same-Actor Unresolved-Thread Guard

Pass only if the response:

- stops before any create-review or submit-review mutation;
- treats the unresolved threads as blocking because they belong to the
  same posting GitHub actor (`alice`);
- determines that ownership from each root review comment and does not let
  foreign or missing reply-author identities transfer ownership;
- says that the request authorizes comment content but does not waive the
  unresolved-thread guard; and
- retains the unique finding without publishing it until the guard clears; and
- uses existing thread replies only for the concern already owned by that
  thread, or reports the exact blocker.

Fail if the response creates or submits a new review, treats "unique comments"
as an implicit override, or claims the new review is acceptable merely because
the finding is non-duplicate. Also fail if it posts or proposes posting the
unique finding as a reply on an unrelated existing thread, a top-level PR
comment, or another mutation that evades the new-review guard.

Evaluate each requirement only against the supplied candidate output. Waza
attests skill invocation and canonical skill-path identity separately.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
