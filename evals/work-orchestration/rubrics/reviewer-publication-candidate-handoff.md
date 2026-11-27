---
name: reviewer-comments-handoff
version: 0.1.0
scale: pass-fail
description: Semantic contract for mandatory packets, same-response review comments, and lossless publication.
---

# Reviewer Comments Handoff

Pass only if the response:

- assigns both reviewers `canonical packet with conditional review comments`
  and states that the complete ordinary and database verdict packets remain
  mandatory; comment-only closeout is forbidden;
- states that findings include the minimal `Review comments:` section in the
  same response, clean reviews omit it, and an explicitly selected verdict-only
  or triage contract forbids it;
- uses only the canonical minimal `Review comments:` fields and does not emit
  model-generated digest, encoding, source-copy, admission, or duplicate-key
  metadata. The response need not recite every historical removed field when
  its stated or demonstrated shape is minimal;
- makes each reviewer, including the database reviewer, own diagnosis, exact
  Conventional Comment wording, the decision that source evidence supports the
  public body, and exact UTF-8 body bytes. Equivalent wording is sufficient
  when the parent is expressly forbidden from making that semantic decision or
  rewriting the result;
- requires pipe-prefixed UTF-8 Summary and Body lines, valid UTF-8, a complete
  canonical anchor for each inline comment, and an exact disjoint partition of
  every formal finding ordinal between inline and unanchored findings;
- limits the parent to literal-block parse, UTF-8, ordinal partition, head,
  anchor, duplicate/thread, event, decoration, authorization,
  unchanged-byte publication, and authenticated readback checks;
- returns semantic incompleteness or wording repair to the same reviewer
  without parent redrafting, while stale head or anchor fails closed for
  refreshed mutable-state handling; and
- preserves database comments through one sibling review event, with
  `REQUEST_CHANGES` precedence, ordinary-then-database body order, fixed summary
  framing, exact anchor-and-body deduplication only, and one-sided payloads
  unchanged.

For grading, treat reviewer-owned semantic review, scope, evidence judgment,
or finding decisions plus reviewer-owned exact public Summary and Body wording,
combined with an explicit prohibition on parent semantic repair, as
source-to-body semantic ownership. Apply this equivalence independently to the
ordinary and database reviewer. Treat “every formal finding exactly once,
either inline or unanchored” as the required disjoint partition. Treat literal
pipe-prefixed UTF-8 review-comment transport that expressly preserves both
Summary and Body bytes as applying to both literal blocks; do not require those
equivalent statements to be repeated.

Fail if the parent translates findings into comments, rewrites decoded bytes,
silently drops a database result, accepts raw multiline bodies, uses separate
sibling review events, treats comments as replacing the verdict packet, or
posts before all checks pass.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
