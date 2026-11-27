<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# Debugging And Reproduction

Use this lane when a code change is a bug fix, a runtime symptom is reported,
or implementation needs a proven root cause before editing.

This lane preserves the useful workflow from the Copilot debugging and UI
debugging agents. It does not preserve Copilot handoff fields, browser-skill
allowlists, or persona text.

## Mission

Turn a symptom into evidence, a root cause, a minimal fix, and regression
proof. Do not code from vibes.

Follow this sequence:

1. Reproduce the bug or document why reproduction is safely unnecessary.
2. Capture the smallest evidence bundle: steps, actual result, expected
   result, logs, screenshot, DOM state, request/response, or failing test.
3. Form two or three ranked hypotheses and test the most likely one first.
4. Fix the root cause, not the most visible symptom.
5. Add or update a regression check that would fail for the original defect.
6. Remove temporary debug artifacts before handoff.

## Reproduction Gate

Reproduction is required before hypothesis or fix unless all of these are true:

- the defect is statically obvious from current source;
- runtime state is not needed to prove the failure;
- the fix is mechanical and low risk;
- a regression test or focused check can still prove the behavior; and
- the code-change todo records why reproduction was skipped.

After three failed reproduction attempts, stop the loop. Record what was tried,
why each attempt failed, and the smallest missing input or environment proof.
Do not keep changing code to make an unproven symptom disappear.

## UI And Browser Evidence

For browser-visible bugs, capture before/after evidence when feasible:

- route or URL, viewport, browser/device, and auth/data setup;
- screenshot, DOM snapshot, console errors, network failure, or trace path;
- deterministic waits based on selectors, text, response, or load state, not
  blind sleeps;
- responsive and keyboard behavior when layout or interaction changed; and
- browser coverage status, including what remains `Pending Verification`.

Keep browser auth state, cookies, raw tokens, and screenshots with sensitive
data out of committed files and chat output.

## Debug Artifact Cleanup

Before handoff, search changed files for temporary diagnostics when relevant:

```bash
rg -n 'console\.log|fmt\.Println|print\(|pprint\(|var_dump' <changed-files>
```

Remove:

- debug prints, commented-out probes, temporary test data, and local scripts;
- debug flags or environment variables not part of the real behavior;
- verbose logging that exposes sensitive data or creates noisy operations; and
- test-only bypasses that weaken auth, validation, or error handling.

## Root-Cause Discipline

- A fix is not done until the regression check proves the failure mode.
- If the test expectation is correct and production code fails it, treat the
  failure as product evidence, not as text to rewrite until green.
- If the bug involves unauthorized access, data loss, PII, secrets, or
  production impact, load the security or production-data lane before editing.
- If the bug crosses frontend and backend, name the boundary that owns the
  root cause before changing both sides.

## Output

```text
Debugging and repro:
- reproduction: <reproduced | static-defect skip | Pending Verification>
- root cause: <file/symbol and why>
- regression proof: <test/check or Pending Verification>
- cleanup check: <command or not needed>
```
