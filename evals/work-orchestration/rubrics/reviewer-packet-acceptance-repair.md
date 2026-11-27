---
name: reviewer-packet-acceptance-repair
version: 0.1.0
scale: pass-fail
description: Parent-side reviewer packet admission and bounded repair semantics.
---

# Reviewer Packet Acceptance Repair

Pass only if the response:

- keeps the same reviewer and exact target in `REVIEW_ACTIVE`, and either states
  `RETURNED -> VALIDATING -> REJECTED` or unambiguously describes validating the
  exact returned bytes and rejecting that same response; it must not accept the
  reviewer's self-attestation or unseen prior response;
- names the parent-trusted exact target, `FULL` mode, and `canonical packet
  with conditional review comments` contract as validator inputs that packet
  content cannot weaken;
- records a parent-private `PACKET_ACCEPTANCE_RESULT` bound to source and
  canonical packet identities, transport, validator-produced failed rule IDs,
  trusted inputs, and `REJECTED` decision. The response must not invent exact
  `RPPA-*` identifiers when the scenario does not supply validator output;
- sends one consolidated `REVIEW_PACKET_REPAIR` to the same reviewer, naming
  failed rule IDs and observed defects and requesting one complete corrected
  canonical packet rather than fragments or a fresh semantic review;
- forbids the parent from reviewing code, reconstructing findings or packet
  sections, rewriting verdict/comment semantics, or starting an overlapping
  reviewer;
- blocks sibling join, bounded closeout, publication, and packet-compliance
  claims until the complete corrected packet is revalidated and accepted; and
- states that a second mechanically malformed full response stops at the
  existing terminal-malformed or replacement decision rather than looping,
  relaxing checks, or asking the user for routine read-only approval.

Fail if the response accepts prose, trusts reviewer self-certification, lets
the packet choose its own expected mode/output contract, repairs semantics in
the parent, asks for another whole-target review, omits the one-repair bound,
or allows any blocked downstream action before `ACCEPTED`.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
