<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Value And Release Readiness

Use this lane near the end of implementation when a change affects
user-facing behavior, operator-facing behavior, release safety, or value
delivery. It is an authoring-phase check, not a final UAT or release verdict.

This lane preserves useful UAT and release-verification patterns from the
Copilot agents. It does not import their approval authority or final go/no-go
packet format.

## Mission

Make sure the code being handed off can plausibly deliver the promised value
and can be rolled back or verified without guesswork.

Follow this sequence:

1. Restate the value or outcome the implementation is supposed to deliver.
2. Name the current authoring stage and the evidence that later merge, deploy,
   execution, and recovery decisions must still acquire. Do not let local
   implementation proof imply a later-stage readiness verdict.
3. Translate each important acceptance criterion into Given/When/Then shape.
4. Confirm at least one runtime or integration proof path exists for the core
   value, or mark the exact proof `Pending Verification`.
5. Check for drift: unrequested behavior, skipped requirements, weakened error
   states, or tests that miss the actual user/operator flow.
6. Record release risk, rollback path, and conditions before handoff.

## Value Delivery Checks

- Tests passing is not the same as value delivered. A test must exercise the
  real user, API, data, or operator flow it claims to prove.
- For frontend changes, prefer browser-visible evidence, E2E, screenshot,
  accessibility/keyboard checks, or a documented manual path when automation is
  not feasible.
- For backend changes, prefer API/integration evidence, error-path checks,
  performance or query proof when relevant, and clear API contract assertions.
- For cross-stack changes, trace the value through both sides: backend returns
  the right data and frontend renders or handles it correctly.
- If runtime proof is blocked, do not imply approval. State the exact
  `Pending Verification` path, including config readback, flag state, dashboard,
  runbook, provider sandbox, browser, or production-shape evidence when those
  are the real release gate.

## Release Readiness Checks

Before handoff or PR publication for production-facing work, name:

- release scope and changed user/operator surfaces;
- risk level and why;
- commands or artifacts checked;
- gaps that could block ship confidence;
- rollback or revert path, including data recovery, flag disablement, job pause,
  cache invalidation, or provider rollback when relevant; and
- conditions for safe release when the change cannot be fully proven locally.

## Drift And Scope Control

- Do not add new features while fixing value delivery gaps.
- Do not let tests validate a different outcome than the stated acceptance
  criterion.
- Do not hide partial delivery behind a green check. Name missing runtime,
  data, browser, staging, or operator proof.
- If value cannot be expressed as a user, API, data, or operator outcome,
  revisit the implementation plan before expanding code.

## Output

```text
Value and release readiness:
- value under test: <user/API/operator outcome>
- proof path: <runtime/integration/manual/e2e evidence or Pending Verification>
- drift check: <none | scope creep | missing requirement>
- rollback: <revert, flag, data recovery, or Pending Verification>
```
