<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Analytics And Event Tracking Authoring

Use this lane when code adds, renames, moves, or removes product analytics
events, event properties, user/identity traits, tracking calls (Amplitude or
similar), consent-gated telemetry, funnel or experiment instrumentation, or
schema/docs that downstream dashboards and stakeholders treat as a tracking
plan.

## Mission

Analytics events are a data contract with people who cannot read the diff.
Renaming an event, changing a property type, or moving a firing point silently
breaks dashboards, funnels, experiment analysis, and stakeholder decisions
long after merge. Instrumentation must also never degrade the product: it is
best-effort by design, consent-aware, and free of sensitive payloads.

## Boundaries

Also load:

- `observability-and-operations` for operator-facing logs/metrics/alerts;
  product analytics answers "what did users do", not "is the system healthy" —
  do not merge the two pipelines' semantics;
- `security-and-trust-boundary` when events can carry PII, learner records,
  tokens, free-text user input, or identifiers joinable to sensitive data;
- `frontend-ui` or `backend-go` for the firing code path itself;
- `resilience-and-fallbacks` so tracking failures never block or break the
  user action being tracked;
- `feature-flags-rollout` when experiment exposure events gate analysis.

Do not add a new analytics vendor, SDK, or event pipeline for one feature when
the repo already has an owning integration.

## Authoring Sequence

1. Check the existing taxonomy before naming anything: event naming
   convention, property casing, identity/trait model, and where the tracking
   plan or event schema is documented. Match it; do not invent a parallel
   dialect.
2. Define each new/changed event as a contract: name, trigger condition,
   firing point (client, server, or both — pick one owner per event),
   properties with types and allowed values, identity attached, and the
   question a stakeholder answers with it.
3. Fire at the moment of truth. Track confirmed outcomes (server-acknowledged
   success) rather than optimistic clicks when the event will be read as a
   conversion; if both are needed, name them distinctly.
4. Keep tracking non-blocking and failure-tolerant: fire-and-forget or queued
   dispatch, no user-visible error, no thrown exception that can break the
   feature path, and no await that adds user-facing latency on hot paths.
5. Respect consent and privacy: honor the consent state before dispatch, keep
   PII, secrets, free-text user content, and sensitive learner data out of
   event properties, and prefer stable pseudonymous IDs over raw identifiers.
6. Treat renames and removals as breaking changes: search dashboards/tracking
   docs for consumers, keep the old event firing through a stated deprecation
   window or get owner sign-off, and update the tracking plan doc in the same
   slice.
7. Guard against volume and cardinality surprises: no per-keystroke or
   per-scroll-tick events without sampling, no unbounded property values
   (raw URLs with tokens, full payloads, timestamps as property names).
8. Update the tracking-plan documentation, typed event helpers, and any
   generated schema in the same change as the firing code.

## Prevention Probes

- Does a renamed event, moved firing point, or retyped property break an
  existing dashboard, funnel, alert, or experiment readout?
- Can the event fire twice (retry, re-render, optimistic + confirmed, client +
  server) and inflate counts without a dedupe decision?
- Can the event fail to fire on a real success path (early return, ad blocker,
  consent-denied, error before dispatch) in a way that stakeholders will read
  as a product regression?
- Do properties carry PII, tokens, emails, free-text input, or identifiers
  that violate consent or data policy?
- Is tracking gated on consent state everywhere the event can fire, including
  server-side paths?
- Can a tracking failure or slow analytics endpoint block, delay, or error the
  user action?
- Does the experiment exposure event fire exactly once per unit of analysis,
  before the treatment can affect behavior?
- Do typed helpers, tracking docs, and the actual payload agree after this
  change?

## Validation

Prefer unit tests on the typed event helper asserting name, properties, and
consent gating; an integration or E2E assertion that the event dispatch was
invoked on the success path (mock transport, not live vendor); a payload
snapshot for shape drift; and a manual or staged verification against the
analytics tool's live/debug stream when the change claims dashboard
continuity. Mark unverified downstream-dashboard impact `Pending Verification`
with the named consumers.

## Output

```text
Analytics/event authoring:
- events changed: <name, trigger, firing owner>
- contract: <properties/types/identity, tracking plan updated>
- downstream consumers: <dashboards/funnels checked or Pending Verification>
- privacy/consent: <PII exclusion and consent gating evidence>
- failure isolation: <non-blocking dispatch proof>
- proof: <tests/debug-stream evidence or Pending Verification>
```
