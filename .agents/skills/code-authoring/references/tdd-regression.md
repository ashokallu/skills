<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# TDD And Regression Authoring

Use this lane when behavior is known and needs a focused failing check,
regression harness, or test-first loop.

## Mission

Convert a known behavior or a fixed bug into a deterministic check that fails
for the right reason before the fix exists and keeps failing if the behavior
ever regresses.

## Boundaries

This lane owns the test-first loop and regression capture. Load
`test-quality` for broader suite design, fixture strategy, and mock
discipline; `debugging-and-repro` when the behavior is not yet understood
enough to write the failing check; and the owning domain lane (frontend,
backend, SQL, jobs) for where the seam lives.

Do not write the fix first and back-fill a test that was never seen failing;
a test that has never failed proves nothing about regression protection.

## Process

1. Identify the public behavior and narrowest meaningful seam.
2. Name the behavior in repo language.
3. Write one failing test or executable check. Verify it fails for the expected
   reason when feasible — read the failure message; a compile error or setup
   error is not the expected failure.
4. Implement only enough production code to pass that check.
5. Run the check again and keep the evidence (command and output).
6. Refactor only while green.
7. Repeat only when the next test adds real confidence.

For bug regressions specifically: reproduce the bug through the test before
fixing, reference the bug or PR in the test name or comment, and assert the
observable symptom, not the internal mechanism that happened to cause it this
time.

## Test Quality Bar

- The test would fail if shipped behavior regressed.
- The test uses production code through a stable interface.
- The test avoids copied production logic in assertions or mocks.
- The test name describes behavior, not implementation.
- The test is deterministic: no real time, network, ordering, or shared-state
  dependence without explicit control.
- The validation command is cheap enough to rerun, or paired with a narrower
  local check.

## Prevention Probes

- Would this test still pass if the fix were reverted? If unsure, revert
  locally and check.
- Does the assertion accept a superset of correct behavior (snapshot too
  broad, truthiness instead of value, count instead of content)?
- Does the mock encode the same wrong assumption the bug had?
- Can the test flake under CI parallelism, timezone, or locale differences?

## Output Discipline

Record the failing-run evidence, the passing-run evidence, and the exact
command. Use `Pending Verification` for behavior not proven by the test or
command, including "fails-on-revert" when it was not feasible to check.
