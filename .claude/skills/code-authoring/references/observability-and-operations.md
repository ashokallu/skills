<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Observability And Operations Authoring

Use this lane when changed behavior affects logs, metrics, traces, Sentry,
alerts, dashboards, runbooks, deploy/rollback checks, operator evidence,
incident triage, or any path where future humans must detect, diagnose, or
recover from runtime behavior.

## Mission

Author operational truth, not noise. The changed path should leave enough safe,
structured evidence for an operator to know what happened, what did not happen,
which run or request is affected, and what action is safe next.

## Boundaries

Load `docs-and-operator-truth` for prose/runbook/CLI help alignment,
`resilience-and-fallbacks` for failure paths, `production-data-safety` for
apply/dry-run/bulk jobs, `security-and-trust-boundary` for sensitive data, and
`ci-workflow-authoring` for deploy/check automation. This lane does not create
new observability platforms or alert policies without owner direction.

## Authoring Sequence

1. Identify the operational question the change creates: success, failure,
   partial success, skipped work, retry, rollback, deploy readiness, or user
   impact.
2. Choose the signal owner: structured log, metric, trace/span, Sentry event,
   run-state row, CLI summary, dashboard, alert, or runbook step.
   Classify each signal before coding as one of:
   - strict correctness or operator truth that may fail the primary operation;
   - best-effort diagnostic telemetry that must not abort primary work.
   Do not let a diagnostic signal drift into a strict dependency by returning
   its error through the primary mutation path.
3. Add the smallest signal that answers the question with safe labels and a
   stable correlation key such as request ID, run ID, tenant-safe ID, job ID,
   release, or feature flag.
   Every log for a chunk, progress update, uncertain commit, terminal failure,
   or terminal success must carry the same stable correlation key as the
   durable run/progress rows it is meant to explain.
   Components must emit through their injected or scoped logger rather than a
   package-global logger so caller-selected suppression, handlers, formatting,
   and correlation attributes remain effective. Normalize nil loggers at the
   composition boundary instead of bypassing the injected contract.
4. Separate user-facing messages from operator detail. Keep user errors generic
   and localization-safe; put technical detail in logs/metrics/tests/runbooks.
5. Bound cardinality and volume. Do not emit per-user, per-row, raw payload,
   stack dump, or secret-bearing labels into high-volume metrics or logs.
6. Ensure success logs and warnings are gated on the condition that actually
   occurred. Never log that blockers were resolved, data was mirrored, or a
   safety check ran when the path was skipped or best-effort failed.
7. Update runbooks, PR text, CLI help, and validation notes when operators must
   act on the new signal.
8. Make each stop threshold operational: absolute value, rate of change,
   sustained window, alert owner, false-positive behavior, and maximum harm
   through detection and completed stopping.
9. Author runbooks with exact artifact and target selectors, executing
   principal, units, defaults, confirmation behavior, safe copy/paste,
   non-production defaults, interruption/re-entry, postconditions, recovery,
   validation, and post-run watch.
10. Test the kill path: no new work starts, in-flight work reaches a safe
    boundary, durable state leaves `running`, locks and resources release,
    cleanup is cancellation-independent and bounded, and restart does not
    silently resume.

## Prevention Probes

- Can an operator distinguish complete success, no-op success, partial success,
  skipped work, retryable failure, permanent failure, and unknown commit state?
- Does every long-running or mutation-capable job expose durable run state,
  progress, terminal status, error reason, and recovery/resume guidance?
- If a progress or terminal-status write is operational truth rather than
  primary correctness, is its context choice deliberate? A canceled caller
  context should not make non-critical telemetry roll back primary work, while
  a detached context still needs a narrow timeout and explicit error handling.
- If progress telemetry is diagnostic-only, can a telemetry write failure,
  zero-row marker update, pool blip, row-status mismatch, or log/metric failure
  abort the real operation? If yes, either make that fail-closed coupling
  explicit in docs/tests or convert the signal to bounded best-effort logging.
- Is there an operator-visible in-flight signal before the first expensive
  statement starts, and does it identify the current chunk or statement if that
  statement stalls?
- Are recorded durations measuring the expensive operation itself, or do they
  accidentally include the setup/progress-marker write that precedes it?
- Do progress rows distinguish operational progress from correctness evidence?
  A progress row can prove liveness or failure location, but it must not become
  reconcile, validate, or cutover truth unless the data contract explicitly says
  so.
- Are logs/metrics/traces safe from secrets, tokens, cookies, raw PII, learner
  records, large payloads, and unbounded labels?
- Do alerts or dashboards use signals that the changed code actually emits at
  the right severity and environment?
- Does a fallback, fail-open path, or sampled/capped run emit a loud enough
  warning that operators will not mistake partial coverage for full proof?
- Are test fixtures or local logs proving the signal shape, not just the
  existence of a logging call?

## Validation

Proof may include focused unit tests over run summaries, log fields, metric
labels, Sentry configuration, CLI output, dashboard config, or runbook command
readback. For live observability claims, mark the exact dashboard, alert,
release, environment, or event evidence `Pending Verification` unless it was
actually checked.

## Output

```text
Observability/ops authoring:
- operator question: <what future human must know>
- signal: <log/metric/trace/run-state/runbook/alert>
- sensitive/cardinality check: <result>
- proof: <test/config/readback or Pending Verification>
```
