<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Frontend, React, Next.js, And UI Lens

Use this lens when the review touches frontend routes, components, requesters,
React behavior, Next.js behavior, browser helpers, E2E helpers, CSS, design
system contracts, or user-visible UI state.

This lens assumes React 19 and Next.js 16 are the intended stack only after repo
package files confirm that. If `package.json`, lockfiles, or repo docs disagree,
treat repo files as the source of truth.

## Review Order

1. Identify route, component, requester, Server Action, or UI state changed.
2. Map server/client boundary and data flow from source to rendered state.
3. Inspect reachable callers: links, forms, route params, feature flags, auth
   state, tenant/user state, requester consumers, keyboard/focus path, and
   locale/translation source when user-visible UI changes.
4. Check old/new compatibility for URLs, query params, response shapes, cache
   tags, redirects, and browser-visible error states.
5. Inspect tests and browser evidence with the tests lens when the change claims
   validation.
6. Emit only material, reachable, evidenced findings; keep visual-only gaps as
   requested browser artifacts unless static evidence proves breakage.

## React 19 / 19.2 Specific Probes

- Actions and form Actions:
  - Check that async submissions preserve pending, error, success, and reset
    semantics; uncontrolled forms reset on successful form Actions, so confirm
    that is intended when preserving inputs matters.
  - `useActionState` should return state that the component actually renders or
    handles; do not allow silent success/failure branches or swallowed server
    errors.
  - `useFormStatus` only reports the nearest parent form status. Flag buttons or
    design-system wrappers that read status outside the form they submit.
  - Multiple submit buttons with `formAction` need distinct pending/disabled and
    permission semantics when actions differ.
- Optimistic UI:
  - `useOptimistic` must reconcile with authoritative server state, failed
    actions, duplicate submissions, stale responses, and rollback/error display.
  - Optimistic mutations touching permissions, enrollment, progress, tenant
    data, or irreversible actions need fail-closed proof.
- Transitions and concurrency:
  - `startTransition` and async transitions should not hide required errors,
    leave controls enabled for duplicate writes, or make auth redirects appear
    successful before the server confirms.
  - Suspense fallbacks must not strand the user, mask permission failures, or
    cause layout shift that breaks primary tasks.
- `useEffectEvent`:
  - Use it for event-like logic fired from effects, not as a blanket way to
    silence dependencies.
  - Confirm the surrounding effect still declares true reactive dependencies and
    cleans up subscriptions, timers, observers, and connections.
- `<Activity>`:
  - Hidden mode preserves component state while unmounting effects and deferring
    updates. Check stale data, hidden form state, background auth state, focus,
    announcements, subscriptions, and memory cost.
  - Do not use it to hide privileged UI or data unless authorization and
    serialization boundaries are independently safe.
- React Server Components:
  - Server-only code, secrets, privileged fetches, cookies, headers, and private
    env vars must not cross into client bundles or serialized props.
  - Client Components receiving server data need stable serializable shapes and
    safe defaults for missing, stale, or partial data.
- React Compiler and hooks linting:
  - Do not accept manual memoization, dependency suppression, or hook reshaping
    that changes behavior just to satisfy compiler or lint output.
  - Stable callbacks still need correct closures, cleanup, and public behavior.

## Next.js 16 Specific Probes

- App Router and async request APIs:
  - `params`, `searchParams`, `cookies()`, `headers()`, and `draftMode()` access
    must follow the async contract for the actual Next version.
  - Metadata image route params and generated metadata paths need the same async
    handling and error/fallback behavior.
- Server/client boundaries:
  - `use client` files must not import server-only modules, database clients,
    secret-bearing config, privileged requesters, Node-only APIs, or code that
    expands bundle size through accidental server imports.
  - Server Components must not depend on browser-only APIs at import time.
  - Client bundles, browser logs, static props, serialized state, and hydrated
    error payloads must not leak cookies, tokens, internal errors, or private
    env values.
- Cache Components and caching APIs:
  - If `cacheComponents`, `use cache`, `cacheTag`, `cacheLife`, `revalidateTag`,
    `updateTag`, `refresh`, or `router.refresh()` changes, verify expected
    consistency: stale-while-revalidate versus read-your-writes semantics.
  - `revalidateTag()` single-argument usage is suspect on Next.js 16; verify the
    chosen cache profile or `updateTag()` alternative matches the user flow.
  - Server Actions using `updateTag()` or `refresh()` must update the exact data
    that the current page reads, not just a nearby tag or unrelated shell.
  - Cached results must include tenant/user/permission inputs in their key or be
    proven public and safe to share.
- `proxy.ts` and `middleware.ts`:
  - `proxy.ts` is the preferred network-boundary file in Next.js 16; check auth,
    redirects, matchers, header/cookie handling, and loop prevention.
  - If `middleware.ts` remains, verify intentional runtime need and migration
    plan; do not treat deprecated naming as a blocker unless it hides behavior.
- Turbopack default and build config:
  - Build/runtime behavior can differ when custom webpack assumptions, loaders,
    module aliases, PostCSS, or dynamic imports are changed. Ask for the exact
    build evidence when the diff touches those seams.
  - `next lint` removal means lint proof must come from the configured lint tool,
    not `next build` by assumption.
- `next/image` and asset changes:
  - Check `remotePatterns`, `localPatterns`, query-string restrictions,
    redirect limits, quality allowlists, cache TTL changes, alt text, sizing,
    priority/preload, and private-network image sources.
  - When a layout breakpoint, column count, container width, or image card shape
    changes, re-check `next/image` `sizes`, aspect ratio, and priority/preload
    hints. Old size hints can survive a visually correct diff and still produce
    wrong production image selection.
- Runtime config and env:
  - `serverRuntimeConfig` and `publicRuntimeConfig` are removed in Next.js 16;
    changed config should use env conventions without leaking private env vars.
  - Import-time env parsing in shared modules can break builds, static render,
    tests, or client bundles.
- Version-matched docs:
  - If local Next docs are present, prefer them for changed APIs. Do not infer
    Next 16 behavior from memory when a repo-local doc can be inspected.

## Requesters, Data Shapes, And Cross-Stack Contracts

- Use existing LearnRequester, LearnContext, ProgressContext, component
  hierarchy, Tailwind/SCSS tokens, translation patterns, route helpers, and repo
  request wrappers instead of parallel paths.
- Compare frontend request/response types to backend handlers, generated
  requesters, API docs, fixtures, and tests when any shape changes.
- Check null/undefined drift, unsafe casts, optional array/object fields, missing
  discriminants, schema migrations, and partially loaded state.
- Raw string query construction, manual URL concatenation, and unencoded params
  are reviewable when user input, locale, tenant, pagination, or filters are in
  the path.
- Redirect/callback contracts need old/new compatibility for login, logout,
  auth refresh, return URL, locale, and feature-flagged routes.
- Missing, malformed, stale, or partially loaded feature flags and permissions
  must fail closed for protected data or actions.

## UI State, Accessibility, And Responsive Correctness

Treat accessibility and responsive behavior as correctness when the diff changes
user interaction, navigation, layout, forms, content hierarchy, or disclosure of
state. When those concerns are central to the verdict, also load
`accessibility-i18n-lens` so keyboard, focus, accessible names, translation,
locale, RTL, and long-copy probes are explicit in the selected-lens audit.

- Check keyboard reachability, focus order, focus trapping/restore, skip paths,
  disabled states, aria labels/descriptions, live regions, and semantic roles.
- Avoid ARIA that contradicts native semantics or hides actionable elements from
  assistive tech.
- ARIA references such as `aria-labelledby` and `aria-describedby` must point to
  rendered IDs in every branch. If the ID is optional, the ARIA attribute should
  usually be optional too.
- Decorative icons inside links, stats, and controls should be hidden from
  assistive tech unless they add information not present in text. Do not add
  redundant or non-localized `aria-label` text to decorative icons.
- Hover-only affordances need keyboard equivalents, usually focus-visible or
  focus-within behavior on the same interactive target.
- Check loading, error, empty, partial, disabled, offline, permission-denied,
  stale-data, retry, long-copy, missing-translation, and invalid-locale states.
- Check filter/pagination/sort transitions, selection persistence, destructive
  confirmation, duplicate submit prevention, and back/forward navigation.
- Check text overflow, mobile layout, responsive breakpoints, skeleton size,
  modal/dialog scroll, sticky headers, and content overlap.
- Flex and grid truncation need the full chain of constraints. Verify the
  shrinking child has `min-w-0` or equivalent, the text uses the repo's truncate
  pattern, and surrounding cards retain width constraints after layout changes.
- Shared design-system default class changes have broad blast radius. Prefer
  caller overrides for local layout needs unless the diff proves all existing
  unset callers should inherit the new default.
- Use repo design tokens for colors, spacing, and typography when a token exists.
  Arbitrary values are reviewable when they bypass a nearby design-system
  convention without reason.
- Missing translations and hard-coded English are defects when surrounding UI is
  localized. Technical raw errors shown to users are defects unless explicitly
  intended and safe.
- Translation helpers reused across routes need the namespace loaded on every
  server-rendered route that can call them. A helper that works on one page can
  still fail when imported into a page with a narrower namespace set.
- Page titles and metadata should preserve the repo's default branding, separator
  convention, and explicit override pattern across empty, custom, and fallback
  states.
- Visual diffs need browser or screenshot evidence. Static review may request a
  route/state/browser artifact but must not claim visual proof it did not see.

## E2E, Browser Helpers, And Playwright-Specific Footguns

- Login and navigation helpers must fail when setup, clicks, navigation, or
  assertions fail. Do not accept helpers that swallow errors and report success.
- Prefer stable role/name/test-id selectors that reflect user behavior. Empty,
  broad, hidden, nth-child, or brittle CMS-text selectors can make wrong-green
  tests.
- Browser state setup must match auth, tenant, locale, flags, and data needed by
  the route. Seeded cookies or local storage are not proof of a real login path.
- Avoid duplicated cookie/login/menu orchestration unless there is a documented
  reason; divergent helpers hide auth regressions.
- A screenshot proves only the observed route, account, viewport, flags,
  browser, data, and commit.

## Frontend Performance, Observability, And Privacy

- Watch for new large client imports, server modules pulled into client bundles,
  duplicate providers, unbounded renders, unstable dependencies, waterfall
  requests, and cache invalidation that forces full-page reloads.
- Observer, resize, scroll, and measurement effects should not set state on
  every callback when the computed value is unchanged. Check dependency arrays
  for teardown/resubscribe churn caused by broad values such as `children`.
- Browser logging, terminal-forwarded browser errors, and analytics events must
  not include tokens, cookies, raw PII, internal stack traces, or learner data
  beyond the repo's redaction policy.
- User-visible outages need observable signals: safe logs, metrics, events, or
  error boundaries that let operators distinguish auth, network, backend, and
  frontend failures.
- Performance claims require bundle, Web Vitals, profiler, build, or route-level
  evidence when the claim affects verdict.

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- secret, cookie, private env, privileged fetch, or server-only module leaks to
  the client or browser logs
- protected route/action fails open on missing auth, permission, tenant, flag, or
  stale state
- Next.js 16 async API, cache, proxy, image, or removed-config change breaks a
  reachable route or deploy
- optimistic/action/form path can double-submit, silently drop errors, or show
  durable success after server failure
- response-shape drift strands users on loading/error states or sends invalid
  backend requests
- UI change blocks keyboard/mobile users on a primary path
- test/browser evidence cannot exercise the claimed user-visible behavior
