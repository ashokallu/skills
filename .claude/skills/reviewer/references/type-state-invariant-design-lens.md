<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-28 -->

# Type, State, And Invariant Design Lens

Use this lens when the diff adds or changes types, interfaces, DTOs, generated
contracts, enums, state machines, discriminated unions, Go structs or
interfaces, request/response shapes, feature-flag state, persistence models, or
domain helpers that encode or should preserve domain state.

The goal is not to rate type beauty. The goal is to check whether the changed
types express and enforce the domain invariants that shipped code relies on.

## Review Order

1. Name the invariant the type or state shape is supposed to preserve.
2. Identify where values are constructed, decoded, mutated, serialized, stored,
   and consumed.
3. Check whether invalid combinations can be represented and reach production
   behavior.
4. Check whether enforcement happens at the boundary that actually receives
   untrusted, generated, persisted, or cross-service data.
5. Verify tests or validation cover the construction and mutation paths that
   matter, not only happy-path assignment.

## Invariant Probes

Ask these for every meaningful new or changed type/state shape:

- Which fields must move together, and can the type represent one without the
  other?
- Which counters, buckets, statuses, or terminal metadata must agree with
  durable rows and operator filters? A new enum or bucket should update every
  summary, gate, report, and unresolved/error count that humans compare.
- Which states are mutually exclusive, terminal, ordered, or mode-specific?
- Which persisted states are possible after reruns, replacement runs, partial
  failures, or multiple operator invocations? If the CLI or config accepts only
  one run ID, verify the database cannot contain multiple relevant runs for the
  same logical entity unless the code supports all of them.
- Which flags, limits, config fields, and helper functions are mode-specific?
  Parse, validate, and reject them in the same mode boundary so invalid input
  does not report a less useful error before the mode gate runs.
- Which optional field is actually required after construction, decoding, or a
  feature-flag branch?
- Which string, number, enum, timestamp, or ID has a smaller domain than its
  primitive type suggests?
- Which semantic ID, count, or selector can appear in more than one physical
  form? Normalize once at the boundary, deduplicate the normalized set, and use
  that same representation for query filters, grouping, missing-item checks,
  logs, and operator summaries.
- Which numeric cap or limit is adjusted before use? Check overflow and target
  type bounds before adding sentinel values or narrowing to generated SQL,
  protocol, or API types.
- Which validated value changes representation before storage or comparison?
  Check units, rounding, truncation, precision loss, timezone conversion,
  serialization, nullable wrapping, and generated type narrowing. The invariant
  must hold after conversion, not only at the CLI/config/API boundary.
- Which generated or external value can bypass constructor checks?
- Which database, cache, queue, API, or browser boundary can persist an old
  shape after the code changes?
- Does a nil, zero, empty, unknown, default, or fallback value mean "absent",
  "invalid", "not loaded", "no permission", or "safe default"?
- When classifications, buckets, or repair classes share a table, do they have
  the same lifecycle across insert, update, delete, restore, validate,
  reconcile, read, and cleanup? If not, require classification-specific guards
  and tests.

## Common Failure Patterns

Flag material issues when current evidence shows:

- permissive types allow impossible states that later code treats as impossible
- validation lives only in UI, comments, tests, or constructors while decoded,
  generated, persisted, or API values bypass it
- broad `any`, string maps, optional bags, or generic wrappers erase a domain
  constraint that nearby code had enforced
- defaulting missing payload fields to zero, empty string, or false can make
  malformed evidence look valid instead of preserving "unknown" or
  "unresolved" state
- a union, enum, interface, or Go type adds a variant without updating
  exhaustive consumers, generated mocks, serializers, or rejection-path tests
- old and new data shapes can coexist during deploy, migration, cache, or
  rollback, but consumers assume only the new shape
- duplicate constants or string literals encode the same domain value without a
  canonical alias, inviting drift between helpers, generated code, and tests
- duplicated coordination constants such as advisory-lock namespaces, feature
  flags, mode strings, run statuses, or sentinel query keys appear in packages
  that must interoperate. These need one canonical owner or an explicit
  generated source so drift cannot break coordination.
- mode-specific validation, helper names, or error messages live under another
  mode's validation path, making the supported flag set hard to audit
- a mode silently accepts flags that belong to another mode, making operator
  intent unverifiable or causing a required safety pin to be ignored
- raw ordering, grouping, or map keys use a physical representation while the
  decoded value uses a normalized representation, causing duplicate, missing,
  or non-contiguous logical records
- normalized inputs can introduce duplicates, but later loops, missing checks,
  logs, or summaries still iterate the original or non-deduped list
- counters or log fields use the same key for pre-normalized and normalized
  values, so operator-visible evidence can disagree across the same run
- sentinel arithmetic such as `max + 1` happens before overflow and generated
  type bounds are checked
- positive, valid-looking input becomes invalid after conversion, such as a
  sub-second duration truncated to zero before hitting a database
  `CHECK (> 0)` constraint
- non-UI helpers import types from UI component modules, tying domain shape to a
  presentation layer and making reuse or generated contracts harder to reason
  about
- tests narrow valid data shapes with casts instead of constructing fixtures
  through the same public type boundary production uses
- helper names imply enforcement while the function only transforms or logs

## Output Discipline

- Do not emit taste findings about type names, purity, or abstraction style.
- Do emit findings when the type shape lets reachable code violate auth,
  tenant scope, data integrity, rollout compatibility, user-visible behavior,
  or operator truth.
- Use residual risk or Risk Evidence Handoff when enforcement depends on live
  data shape, generated artifacts, or external contracts reviewer cannot inspect
  read-only.
