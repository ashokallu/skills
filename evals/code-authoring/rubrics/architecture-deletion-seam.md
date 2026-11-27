---
name: architecture-deletion-seam
version: 0.1.0
scale: pass-fail
description: Checks the deletion test and evidence required for production seams.
---

# Architecture Deletion And Seam Evidence

Pass only if the response:

- treats A's vanished complexity as evidence that the wrapper is shallow and
  should be removed, inlined, or otherwise not deepened without another need;
- treats B's responsibility reappearing across callers as evidence that the
  module earns locality and leverage;
- rejects C's test fake alone as proof of a public production seam because no
  current production variation exists;
- allows a private or internal test seam when it improves module-owned tests
  without expanding the caller contract; and
- does not impose a fixed adapter count as the deciding rule.

Fail if it retains every wrapper, rejects every interface, treats a mock as
sufficient production variation, invents hypothetical future consumers, or
confuses an internal test seam with a public production contract.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
