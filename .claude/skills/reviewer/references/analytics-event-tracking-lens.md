<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Analytics And Event Tracking Lens

## Mission

Review product analytics changes: event names, properties, identity traits,
tracking calls (Amplitude or similar), firing points, consent gating,
experiment exposure events, and tracking-plan documents that dashboards,
funnels, and stakeholders depend on.

## Ownership And Boundaries

This lens owns the analytics data contract and instrumentation safety. Defer
operator-facing logs/metrics/alerts to `observability-ops-lens` — product
analytics answers "what did users do", not "is the system healthy". Defer PII
and consent-violation severity to `security-privacy-lens`, the firing code
path to `frontend-ui-lens`/`backend-go-lens`, blocked-user-action failure
semantics to `silent-failure-fallback-lens`, and typed-helper proof quality to
`tests-validation-lens`.

Do not emit taste findings about event naming when the change follows the
repo's existing taxonomy; the contract with downstream consumers is what
matters.

## Evidence And Dedupe

A finding needs the event, its firing point, and the reachable defect: broken
downstream consumer, double/missed fire, blocked user action, or a sensitive
payload. Group one event's problems across client/server firing points,
helpers, and docs as one finding. Evidence includes typed event helpers,
dispatch code, consent checks, the tracking-plan doc, payload fixtures, and
PR-body claims about dashboard continuity.

## Review Probes

- Does a renamed event, retyped property, or moved firing point break an
  existing dashboard, funnel, alert, or experiment readout — and was any
  downstream consumer checked or a deprecation window kept?
- Can the event fire twice for one user action (retry, re-render, optimistic
  plus confirmed, client plus server) without a dedupe decision, or fail to
  fire on a real success path (early return, consent-denied, error before
  dispatch)?
- Is the event tracked at the moment of truth — server-acknowledged success —
  or does an optimistic click get read downstream as a conversion?
- Do properties carry PII, tokens, emails, free-text user input, raw URLs
  with credentials, or learner data beyond policy?
- Is dispatch gated on consent state everywhere the event can fire, including
  server-side paths?
- Can a tracking failure or slow analytics endpoint block, delay, or error
  the user action being tracked?
- Does the experiment exposure event fire exactly once per unit of analysis
  and before treatment can affect behavior?
- Do typed helpers, the tracking-plan doc, and the actual payload still agree
  after this change?
- Can property cardinality or event volume (per-keystroke, per-tick, raw IDs
  as names) blow up downstream cost or make analysis unusable?

## Triage

Promote: silently broken downstream consumers, double-counted or dropped
conversions on decision-driving events, sensitive data in payloads, consent
bypass, and tracking that can block or break the user path. Keep naming
preferences, minor property additions, and speculative volume concerns
advisory unless the current diff makes them reachable.

## Output Discipline

For findings, name the event, firing point, defect sequence, and the smallest
contract-preserving fix (dedupe key, deprecation alias, consent gate, payload
scrub). Downstream dashboard impact the reviewer cannot verify read-only goes
to `Pending Verification` with the named consumer, or Risk Evidence Handoff
when it controls the verdict. If clean, the selected-lens audit can state
which events, firing points, and consent/PII surfaces were inspected.
