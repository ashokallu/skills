<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Accessibility And Internationalization Lens

## Mission

Review changed user-facing UI for keyboard, focus, semantic markup, accessible
names, form/error states, responsive behavior, translation keys, locale-aware
formatting, interpolation, pluralization, RTL/long-copy behavior, and user copy
that affects comprehension.

## Ownership And Boundaries

This lens refines `frontend-ui-lens`; it does not require full-site
certification for every small diff. Use it when the changed target can affect a
real user task or when UI evidence is part of the verdict. Defer proof quality
to `tests-validation-lens` and copy/doc truth to the canonical closeout
`documentation_truth` category when the text is operator/reviewer guidance rather than UI copy.

## Evidence And Dedupe

A finding needs a changed UI path, affected user state, and evidence that the
interaction, copy, locale, or layout can fail. Deduplicate a missing accessible
name, translation key, or focus bug across repeated instances when they share
the same component/root cause.

## Review Probes

- Can the changed flow be reached, operated, and dismissed using keyboard only?
- Does focus move predictably after navigation, modal open/close, validation
  failure, async success/failure, optimistic rollback, or route transition?
- Do buttons, links, inputs, icons, menus, tabs, dialogs, toasts, and loading
  states have visible labels or accessible names not based only on color,
  position, placeholder, or title?
- Are form errors associated with controls and summarized when needed?
- Do loading, empty, permission-denied, disabled, and error states communicate
  state without relying only on color, animation, or visual proximity?
- Are user-facing strings routed through i18n with complete keys, safe
  interpolation, plural/ordinal handling, and locale-aware date/number/duration
  formatting?
- Can long translations, RTL, zoom/larger text, mobile viewports, or dynamic
  data overlap, truncate critical information, or hide controls?
- Do tests use roles, labels, or user-visible selectors where possible instead
  of brittle CSS structure?

## Triage

Promote issues that block task completion, hide critical state, make controls
unreachable/unnamed, break locale content, or create materially misleading copy.
Keep minor wording preferences, non-critical visual polish, or unproven edge
cases as advisory only.

## Output Discipline

If clean, the selected-lens audit can state the changed task and which keyboard,
label, locale, or layout paths were inspected. If browser/assistive-tech/RTL
proof is unavailable and central to release confidence, mark the exact evidence
`Pending Verification`.
