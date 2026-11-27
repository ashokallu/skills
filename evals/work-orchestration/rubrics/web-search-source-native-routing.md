---
name: web-search-source-native-routing
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for source-native web-search routing.
---

# Web Search Source-Native Routing

Pass only when the response satisfies every requirement:

- A selects Grok and requires X-native post plus requested reply-thread
  coverage through a capability-bearing cross-harness handoff.
- B uses parent web tools for the exact Reddit threads.
- C uses the requested search provider through parent web tools.
- D selects the parent-native Parallel Search MCP for broad discovery and
  direct source fetch; it does not invoke a collaborator by default.
- E uses bounded fanout across the relevant X, Reddit, and broad-web arms,
  keeps the passes independent, joins them once in the parent, and does not
  use agreement count as proof.
- F preserves the explicit Parallel-only constraint, does not call Grok, and
  states that native X reply coverage is not proved unless Parallel returns
  the exact underlying material.
- G fails closed or returns the X reply coverage as `Pending Verification`; it
  does not silently substitute a generic engine and claim completion.
- H remains local and does not activate web-search, Parallel Search, or
  Grok.
- Applicable cases keep authority, freshness, provenance, citations, sampling,
  and gap closure with `source-handling`; material disagreement routes to
  `conflict-resolution` and is never resolved by majority vote.
- Fanout occurs only for named multi-source, explicit comparison, weak-source,
  high-stakes/disputed, or conflict triggers and stops once requested exact
  coverage is sufficient.
- A Grok research route transports the literal target, required capability,
  coverage, explicit surface, fallback authority, failure semantics, and stop;
  a surface with search disabled must fail closed.
- Parallel Search remains parent-native and its ranking, availability, or
  results are not added to collaborator prompts unless the user explicitly
  requests that context.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
