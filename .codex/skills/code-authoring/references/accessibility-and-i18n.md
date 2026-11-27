<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Accessibility And Internationalization Authoring

Use this lane for user-facing UI, forms, navigation, modals, loading/error
states, copy, translations, locale routing, date/number/currency formatting,
right-to-left behavior, keyboard/focus behavior, ARIA, semantic markup, and
browser evidence where accessibility or localization can regress.

## Mission

Make the changed UI usable and understandable across keyboard, assistive
technology, viewport, locale, and content-length variations. Do not treat visual
appearance in one browser and one language as sufficient proof.

## Boundaries

Load this with `frontend-ui` for UI behavior and `typescript-contracts` when
translation keys or state models move. Load `api-contracts-and-integrations`
when locale-sensitive data comes from APIs, and `docs-and-operator-truth` when
copy/help text changes operator or reviewer behavior.

This lane does not require perfect WCAG certification for every small UI edit;
it requires targeted proof for the accessibility and localization risk the diff
actually changes.

## Authoring Sequence

1. Identify the user task, interactive elements, visible copy, dynamic states,
   locale/source of strings, and viewport/content-length risks.
2. Use semantic HTML and existing accessible components before adding ARIA. ARIA
   must supplement semantics, not repair avoidable non-semantic markup.
3. Preserve keyboard order, focus management, visible focus, escape/close
   behavior, and screen-reader names for buttons, links, forms, menus, modals,
   tabs, toasts, and error summaries.
4. Route user-facing strings through existing i18n patterns. Keep placeholders,
   pluralization, interpolation, punctuation, and locale fallbacks explicit.
5. Use locale-aware formatting for dates, times, numbers, durations,
   currencies, and relative labels. Avoid hardcoded English grammar in code.
6. Check responsive and long-content behavior for labels, error messages,
   translated strings, and dynamic data.
7. Add or adjust tests/selectors using roles, labels, text, or stable test IDs
   that reflect real user interaction.

## Prevention Probes

- Can the changed UI be reached, operated, dismissed, and understood with only
  keyboard input?
- Does focus move to the right place after navigation, modal open/close,
  validation failure, async success/failure, or optimistic update rollback?
- Are controls named by visible labels or accessible names rather than icons,
  placeholders, color, position, or title-only hints?
- Do loading, empty, error, disabled, and permission-denied states communicate
  state without relying only on color or motion?
- Are translation keys present across locales, with safe interpolation and
  correct plural/ordinal behavior?
- Do long translations, RTL direction, small viewports, zoom, and larger text
  avoid overlap, truncation of critical information, or unreachable controls?

## Validation

Choose proof proportional to the changed risk:

- unit/component tests asserting roles, names, labels, validation, and state;
- Playwright/browser checks for keyboard path, focus, form errors, and mobile;
- axe/accessibility scan when available for changed page/component;
- visual/browser evidence for layout, wrapping, RTL, or responsive changes;
- locale snapshot or translation-key check when copy moves.

If browser, mobile, RTL, or assistive-tech evidence cannot be gathered, mark the
specific path and command/check as `Pending Verification`.

## Output

```text
Accessibility/i18n authoring:
- user task/UI states: <task and states>
- a11y/locale risks: <keyboard/focus/labels/copy/formatting/etc.>
- proof: <test/browser/scan or Pending Verification>
```
