<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-29 -->

# TypeScript Contracts

Use this lane for focused TypeScript contract work in example-app:
component props, hook returns, context values, request/response shapes, env
declarations, state models, translation keys, utility contracts, and
producer/consumer data-shape tightening.

## Mission

Treat TypeScript as runtime contract work. Map both sides of the boundary,
identify type drift or unsafe assumptions, implement the smallest coherent
fix, and verify under project strictness.

Follow this sequence:

1. Identify the exact type boundary: props, hook return, context value,
   requester response, page props, env variable, translation key, utility
   input/output, or serialized SSR/client data.
2. Read both sides of the contract before editing: producer and consumer,
   caller and callee, page props and component props, requester and use site,
   env declaration and runtime access.
3. Prefer compiler-guided fixes that match runtime truth. Do not silence errors
   with assertions, defaults, broad unions, or suppressions unless the invariant
   is proved and documented.
4. Validate the changed path, one relevant failure/empty/unknown-data path, and
   one integration boundary for downstream type breakage.

## Type Design Rules

- Model real states, not implementation convenience. Use discriminated unions
  for multi-state UI/data flows and handle variants exhaustively.
- Use `interface` for object shapes and component props; use `type` for unions,
  intersections, mapped types, and literal unions.
- Prefer explicit `[ComponentName]Props` interfaces for components and
  descriptive names for context shapes.
- Use generics only when they preserve caller information or remove real
  duplication. Do not use `any` as a substitute for a generic.
- `any` is prohibited for props and function signatures. Use `unknown` plus a
  type guard for genuinely unknown data.
- Avoid optional parameters or optional object fields when the value is
  required by the runtime contract.
- Use assertions only at true boundary points where required data has already
  been checked. After narrowing, trust the type instead of adding impossible
  defensive branches.
- Prefer `satisfies`, const assertions, type predicates, and
  `Record<Enum, T>` maps when they make contracts clearer without increasing
  complexity.
- Keep unions narrow. Do not widen to `string`, `object`, `unknown`, or
  nullable shapes just to make a compiler error disappear.
- Keep serialized contracts explicit and stable across SSR props, requester
  JSON, context values, and browser/runtime boundaries.

## React And App Contracts

- Use arrow function components only. Do not introduce class components.
- Library components use named exports. Next.js page components use default
  exports and should follow local page typing patterns.
- Custom hooks need explicit return types. General hooks live in
  `app/hooks/useCamelCase.ts`; feature/context hooks stay near the feature.
- Do not call `useContext` directly in leaf components. Consume contexts
  through wrapper hooks with explicit return types.
- Effects that register listeners, subscriptions, or timers must clean up. Do
  not access `window` or `document` at module top level.
- Use semantic data IDs as list keys. Do not use array index when items can
  reorder.
- Do not duplicate backend business rules, enums, flags, or validation in
  frontend types. Consume API data or existing shared frontend constants/types.
- Do not edit generated files such as `app/sanity.types.ts`.

## Validation

- Run commands from `app/` unless using `yarn --cwd app`.
- Type-check uses `yarn type-check`; do not substitute `tsc`.
- Targeted lane first: `yarn type-check` plus focused tests for touched
  components, requesters, pages, or utilities where relevant.
- Standard lane before done when feasible: `yarn lint`, `yarn type-check`, and
  `yarn test`.
- Translation changes require the repo translation parity test.
- If runtime behavior changed, route browser/runtime proof through the
  frontend or browser lanes instead of claiming type-check proves UI behavior.

## Output

```text
TypeScript contracts:
- boundary: <producer/consumer or prop/request/state/env contract>
- type-risk removed: <unsafe assumption fixed>
- validation: <commands or Pending Verification>
- residual unsafe edge: <none or exact gap>
```
