<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Frontend UI Authoring

Use this lane for focused example-app frontend changes under `app/`:
Next.js pages, React components, hooks, contexts, requesters, middleware,
styling, browser-visible behavior, frontend tests, and frontend CI failures.

## Mission

Own frontend behavior end to end. Map the route, component, state, requester,
styling, and runtime boundary before editing; then make the smallest durable
change and verify user-visible behavior.

Follow this sequence:

1. Identify the boundary: page route, component tree, context or state owner,
   requester/API path, styling token, middleware, env, or instrumentation.
2. Read relevant page, component, hook, requester, test, style, and translation
   files before editing.
3. Add or adjust the narrowest user-behavior test first when feasible. If the
   failing signal cannot be demonstrated, mark `Pending Verification` with
   exact follow-up commands.
4. Implement the minimum change using existing shared components, constants,
   helpers, requesters, route constants, translations, and types.
5. Validate the changed success path, a relevant failure/loading/error path,
   and an integration boundary such as SSR hydration, client navigation,
   requester auth, translations, accessibility/focus, or responsive layout.
6. For UI bug fixes, keep before/after browser evidence or an explicit
   `Pending Verification` path with exact repro steps.

## Frontend Contracts

- Pages Router is primary. New user-facing pages belong under `app/pages/` with
  `getServerSideProps` and a default page export unless the surrounding feature
  already uses another local pattern.
- App Router under `app/app/` is limited. Do not add page routes, layouts,
  Server Actions, route handlers, or PPR/cache patterns without explicit
  architecture direction.
- SSR pages that need normal app context must call `getLearnPageProps`, spread
  its props, and include needed translation namespaces.
- Preserve `_app.tsx` provider order:
  `LearnContext` -> `ProgressContextProvider` -> `LoginContext`.
- `LearnContext` is immutable SSR-seeded state. Do not put mutable UI state or
  sensitive auth material there.
- Preserve middleware auth and locale behavior. Do not implement custom JWT
  refresh, cookie parsing, or login redirects in pages or components.
- All backend calls go through typed requesters in `app/api/`, primarily
  `LearnRequester`, `LearnLegacyRequester`, or `CMSRequester`.
- Do not call raw `fetch` or bypass centralized auth, ETag, timeout, and
  response normalization from pages or components.
- Requester consumers must check `hasError`, `ok`, or status before consuming
  JSON and must represent loading, error, and empty states in user-visible
  surfaces.

## UI, Styling, And Runtime

- Follow Atomic Design placement and import direction. Components are
  PascalCase; hooks are `useCamelCase.ts`; utilities and constants are
  camelCase.
- Named exports are the default for non-page components and utilities. Default
  exports are for Next.js pages and existing local exceptions.
- Props use explicit `[ComponentName]Props` interfaces. Use `type` for unions
  and intersections. Do not use `any`.
- Prefer discriminated unions for multi-state UI and handle variants
  exhaustively. Do not make required values optional.
- Use project Tailwind tokens and canonical color names from
  `app/tailwind.config.js`. Use `clsx()` for conditional class merging.
- Use SCSS modules only when Tailwind cannot express the behavior. Do not add
  component-specific rules to `app/styles/globals.scss`.
- User-facing strings need i18n keys across locales. Do not hardcode English
  copy in JSX.
- UI must remain scannable, accessible, keyboard reachable, and responsive.
  Load `accessibility-and-i18n` when the change touches forms, focus, ARIA,
  semantic markup, visible copy, translations, locale formatting, RTL, or
  long-content layout. Verify text does not overflow or overlap on normal
  mobile and desktop viewports when layout is affected.
- For visible UI fixes, document browser coverage. Chrome proof is the minimum;
  Safari, Firefox, Edge, or mobile proof is required when the change touches
  layout, forms, dates, scrolling, focus, media, or browser-specific APIs.
- Prefer stable selectors in tests and browser checks: role, label, text, or
  `data-testid` over CSS structure. Avoid fixed sleeps; wait for deterministic
  text, selector, response, or load state.
- Do not use CSS `!important`, hardcoded pixels, or arbitrary colors to mask a
  symptom unless the local design system already requires that exact pattern
  and the rationale is documented.
- Preserve Sentry, logging, Next.js config, env declarations, and Docker
  runtime contracts unless the task explicitly targets them.

## Validation

- Do not run `yarn dev` locally; this repo uses the Docker `nextjs` service for
  local runtime work.
- Run commands from `app/` unless using `yarn --cwd app`.
- Targeted lane first: changed component, requester, or page tests plus
  `yarn type-check` when types changed.
- Standard lane before done when feasible: `yarn lint`, `yarn type-check`, and
  `yarn test`.
- Deep lane when risk justifies it: Docker-based build, browser smoke,
  accessibility keyboard/focus check, axe/accessibility scan when available,
  screenshots, RTL/long-copy check, or deterministic Playwright replay.
- Type-check uses `yarn type-check`; do not substitute plain `tsc`.
- Keep screenshots, traces, and auth state under ignored local paths such as
  `tmp/`. Never commit browser evidence artifacts or saved session state.

## Output

```text
Frontend UI authoring:
- boundary: <route/component/requester/state/style>
- user-visible proof: <test, browser check, screenshot, or Pending Verification>
- validation: <commands or Pending Verification>
- residual risk: <none or exact gap>
```
