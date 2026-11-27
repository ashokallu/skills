---
name: review-submission-readback
version: 0.1.0
scale: pass-fail
description: Byte-preserving coherent review publication and authenticated readback.
---

# Review Submission Readback

Pass only if the response rechecks the live head, unresolved threads, anchors,
and duplicate state; reuses the once-accepted pipe-prefixed literal Summary and
Body bytes without repeating immutable checks; publishes both exact decoded
bodies unchanged in one coherent `REQUEST_CHANGES` review, ordinary body first
and database body second, with fixed application/database Summary framing; and rereads
the stored review object plus inline comment or thread surfaces through
authenticated GitHub APIs. Readback must verify event, reviewed commit, count,
paths and lines, complete byte-identical bodies, labels, and absence of
duplicates or truncation. An explicit check of exact canonical anchors satisfies
the paths-and-lines requirement because those fields are part of the canonical
anchor. Label verification means comparing each stored Conventional Comments
label and decoration with its exact accepted Body value; it does not require
reciting every allowed label. Exact anchor-and-body duplicates are retained
once; same-anchor comments with different Body bytes are both retained.

Fail if the parent rereads code to rewrite either body, uses separate review
events, drops a non-duplicate accepted comment, invents digest fields, trusts rendered
HTML or the mutation response alone, or skips
authenticated readback.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
