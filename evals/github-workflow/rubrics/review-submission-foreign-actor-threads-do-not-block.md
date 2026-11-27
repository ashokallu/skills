---
name: review-submission-foreign-actor-threads-do-not-block
version: 0.1.0
scale: pass-fail
description: Semantic contract that other actors open threads do not block a first review from this posting login.
---

# Review Submission Foreign-Actor Threads Do Not Block

Pass only if the response:

- does not stop solely because unresolved threads authored by `u-pr[bot]`
  exist;
- treats the same-actor unresolved-thread guard as clear for posting GitHub
  actor `alice`; and
- determines ownership from the root review comment, so `alice` replying to a
  foreign-root thread and a missing reply-author login do not make it blocking;
- names create-review or submit-review of the already accepted comment payload as the
  next GitHub mutation, without inventing a new comment body.

Fail if the response reports `new-review authorization: no` solely because any
unresolved thread exists, treats `u-pr[bot]` threads as blocking for `alice`,
or refuses to post the accepted comments for that reason. Do not fail the
payload for later acceptance or publication-capability checks that the prompt
already states are satisfied.

Evaluate each requirement only against the supplied comment output. Waza
attests skill invocation and canonical skill-path identity separately.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
