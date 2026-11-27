<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-10 -->

# Review Closeout Lens

Use this canonical lens after a stable review target, bounded target inventory,
selected domain lenses, and reviewable target units exist. Target units are
changed hunks for diff-shaped reviews or named files/symbols plus necessary
context for direct named-path reviews. It owns the ordered closeout behavior
formerly implemented separately by `inline-advisory-review.md`,
`code-simplification-lens.md`, `documentation-staleness-lens.md`, and
`nitpick-review-lane.md`.

Those four files are compatibility aliases. They preserve legacy routes and category names, but this file is authoritative and alias bodies must not diverge.

## Mission

Read each target unit and its necessary context once, collect candidates into
one ledger, then classify them in this exact order:

1. `consequence_advisory`
2. `simplification`
3. `documentation_truth`
4. `naming_readability`

The order is precedence, not four independent reviews. A stronger category claims a candidate before a weaker category can emit it. The reviewer still owns severity, finding eligibility, evidence law, and the final verdict.

## Ownership And Boundaries

This lens owns closeout candidate collection, category precedence, dedupe,
advisory budgeting, and clean closeout proof. It does not own:

- stable-target setup, PR metadata, worktrees, comments, CI, or publication;
- domain review that should already have run through selected lenses;
- verdict, severity, confidence, `Pending Verification`, or `BLOCKED` law;
- packet field names, ordering, transport, or parser acceptance;
- broad architecture redesign, behavior-changing refactors, or implementation;
- formatter, linter, compiler, type-checker, or generated-file diagnostics.

When a candidate belongs to a stronger domain lens, route it there and keep only its dedupe disposition in this closeout ledger. Do not weaken a material correctness, security, privacy, data, auth, migration, API, fallback, test, or operator issue into an advisory category.

## Shared Stable-Target Input

Before collecting candidates, record one shared input block:

```text
Review closeout input:
- target: <dirty|staged|branch|PR|commit|named path plus base/head when known>
- target inventory: <changed-file artifact or bounded named files/symbols>
- stated intent: <scope, non-goals, changed contracts>
- selected domain lenses: <names and concrete surfaces>
- prior artifacts: <thread/review IDs already fetched or N/A>
- evidence boundary: <static-only, commands run, and Pending Verification>
```

If the target, base, head, inventory, or stated behavior changes, discard the
closeout ledger and restart from the new stable target. Do not patch candidates
from two targets into one verdict.

## Review Depth

Run the same category precedence at every depth, but keep collection inside the
proved impact cone:

- `LITE`: collect exact target units plus immediate context once. Inspect
  changed prose and direct documentation consequences; do not navigate broadly
  for simplification, naming, or documentation candidates without a material
  trigger.
- `STANDARD`: add nearby trusted prose, local convention, tests, and consumers
  relevant to the admitted inventory.
- `FULL`: include cross-boundary operator and documentation truth,
  compatibility, recovery, and residual surfaces established by analysis.

Depth never suppresses a proved candidate or a target unit admitted by the
middle phase. It controls untriggered navigation beyond those units.

## One Target-Unit Collection Pass

Walk each target unit once with enough nearby source, callers, consumers, tests,
generated artifacts, comments, and operator output to understand the reviewed
contract. For a direct named-path review without a diff, treat each named path
and the bounded related context needed for safety judgment as target units; do
not invent a diff or changed-file inventory. Collect candidates before assigning
categories.

For each candidate, capture:

```text
candidate_key=<path:symbol-or-hunk|contract>
location=<current-target path:line or exact artifact>
reviewed_contract=<behavior or reader contract>
reachable_consequence=<current effect or none proved>
local_precedent=<helper, convention, test, doc, or N/A>
stronger_route=<lens/category or none>
proposed_category=<one ordered marker>
disposition=<formal|advisory|internal|drop|routed>
```

Use one `candidate_key` for one root cause. When several lines, files, tests, docs, or lenses expose the same cause, join them under that key and keep the strongest evidence. Do not emit frontend, backend, test, documentation, and nitpick copies of one defect.

## Ordered Category Pass

### `consequence_advisory`

Evaluate this category first. Keep a candidate only when it is current-target grounded, reachable, actionable without redesigning the PR, and tied to a real consequence such as:

- avoidable production-scale work after a nominal limit, page, chunk, sample,
  filter, or cap;
- redundant derived work, query shape, cache, retry, fallback, wrapper, index,
  allocation, serialization, or network call;
- stale downstream predicates, cleanup, reporting, metrics, tests, or operator
  evidence after a state or category moved;
- logs, counters, run summaries, docs, or dashboards that confuse attempts,
  sampled evidence, partial work, or fallback with durable success;
- a wrong-green test that asserts existence but not the tenant, user, state,
  timestamp, source row, aggregate, generated field, or failure path;
- a stale or opaque identifier that conceals the current value role, units,
  source, destination, lifecycle, or domain/storage boundary and creates a
  reachable risk of applying the old contract in a future edit;
- an unexplained boundary or sentinel literal in a test when a local
  intent-bearing constant is needed to reveal the contract under test;
- documentation that claims a bound protects more work or risk than the
  implementation actually bounds.

Route material defects through the reviewer finding contract. Keep a
non-blocking advisory only when it is line-local, proved, cheaper to fix now,
and worth the shared advisory budget. Drop speculative alternatives and broad
architecture wishes. For naming candidates, state the old implication, the
actual contract, and the reachable consequence. Drop equally clear naming
preferences and ordinary fixture literals as taste. Do not demand renames of
intentionally stable public, compatibility, historical, or generated names
unless the owning contract also changes.

### `simplification`

Evaluate unresolved candidates second. A simplification must preserve the exact behavior established by current source, callers, tests, and stable contracts. Prefer local helpers, standard library behavior, installed dependencies, direct branches, narrower state, and established project patterns over new machinery.

Look for repeated guards or branches, unnecessary wrappers or adapters, broad
variable scope, delayed initialization, mixed abstraction levels, deep
nesting, duplicated literals, unreachable props or modes, and helpers whose
names or shape are harder to verify than the code they wrap.

Check unsafe over-simplification with equal force. Route or reject a compact
rewrite when it removes or hides:

- distinct states, errors, tenants, permissions, retries, or side effects;
- guard clauses, validation, cancellation, cleanup, rollback, or idempotency;
- transaction ownership, lock boundaries, cache invalidation, or generated
  source-of-truth movement;
- useful logs, metrics, operator evidence, debug visibility, or failure detail;
- type or state boundaries, test clarity, public compatibility, or a
  non-obvious invariant that must remain explicit.

Fewer lines are not evidence of simpler ownership. Do not request a rewrite
unless the reviewer can explain why behavior remains identical, or identify
the exact missing proof that prevents the suggestion.

### `documentation_truth`

Evaluate documentation after changed behavior, callers and callees, config or runtime wiring, tests, and operator impact are understood. Early doc reads may inventory affected prose, but findings come from this final consistency pass.

First reconcile changed-line comments, docstrings, TODOs, examples, generated
help, logs, and changed docs collected with the hunks. Then navigate beyond
changed lines to the nearest trusted prose surfaces:

- file, package, module, and project READMEs;
- runbooks, operator guides, ADRs, migration docs, and reviewer guides;
- flag descriptions, accepted values, persisted terms, CLI help, and examples;
- PR title/body claims about scope, readiness, dependencies, validation, and
  operator action.

For GitHub PR bodies, also check portability and final-state hygiene: reject
absolute or machine-specific paths, local tool or repair commands, disposable
worktree or auth-state breadcrumbs, internal agent/reviewer/Copilot/council/
Luna process labels, review-fix chronology, routine copied CI inventories,
stale pending-CI or head-SHA claims, obsolete file/dependency lists, and raw
commit IDs that do not help reviewers judge the final source.

Check activation gates, defaults, modes, flags, environment targeting, source
of truth, timeout and rollback semantics, cap meaning, generated ownership,
commands, error and log labels, and old/new compatibility. Documentation
should also let a future reader navigate from the changed symbol to its owning
module, package, workflow, or runbook without inventing missing architecture.

Keep a documentation candidate only when current evidence proves stale or
missing contract prose could mislead review, implementation, QA, rollout,
operations, incident response, or future code navigation. Drop grammar,
polish, and requests for more explanation when current prose is accurate and
sufficient.

### `naming_readability`

Evaluate remaining candidates last. This category owns only non-linter naming, terminology, local convention, readability, and small maintainability issues not already claimed by a stronger route.

Compare changed names, units, state words, ownership terms, abbreviations,
magic values, helper scope, test names, local style, and nearby patterns. Keep
only candidates grounded in an exact changed line or adjacent contract,
supported by repo precedent, actionable with a small edit, and likely to save
future reading, testing, review, or maintenance time.

Pure nits are non-counting. They must not change the verdict, become formal P3
findings, or appear as residual risk unless they independently satisfy the
reviewer core's material, reachable, actionable, current-defect standard.
Do not manufacture a nit to prove this category ran.

## Stronger-Route Precedence And Dedupe Join

Use this precedence when categories overlap:

```text
domain correctness or safety lens
> consequence_advisory
> simplification
> documentation_truth
> naming_readability
```

At the join point, group candidates by `candidate_key`, merge their artifacts, and emit exactly one disposition. A candidate routed to a stronger lens stays `routed`; weaker categories must not restate it. When two candidates share symptoms but not a cause, keep separate keys and explain the distinct contract each one breaks.

## Shared Advisory Budget

All four categories share one advisory budget. For an ordinary PR review, emit
at most five combined advisory or nitpick comments, ordered by consequence and
future maintenance value. If `consequence_advisory` consumes the budget, keep
only a simplification, documentation, or naming item whose distinct value is
greater than the weakest surviving advisory.

For an explicitly requested standalone nitpick pass, the existing ten-comment
cap may apply. Formal material findings are not advisory-budget items, but
duplicate symptoms still collapse under one root-cause key.

## Packet And Output Discipline

Do not create a `Review closeout`, `Advisories`, `Simplification`, `Docs`, or
`Nitpicks` packet field. Parser-facing output uses only the canonical finding,
variance, residual-risk, `Pending Verification`, plain-language summary, and
selected-lens sections permitted by the packet contract.

Material defects use the normal finding contract. Pure nits remain
non-counting advisory context only when the output shape permits it. Internal
and dropped candidates stay out of user-facing output. GitHub-facing comments
require the owning PR workflow and exact current lines.

## Clean Closeout Proof

Before a clean verdict, produce compact internal or parent-facing proof:

```text
Review closeout proof:
- target unchanged: yes/no, artifact=<target evidence>
- target units collected once: <count or bounded scope>
- category order: consequence_advisory -> simplification -> documentation_truth -> naming_readability
- dedupe join: <candidate count before -> root-cause count after>
- routed/formal/advisory/internal/drop: <counts>
- shared advisory budget: <used>/<cap>
- documentation final consistency/navigation: <surfaces inspected>
- unsafe over-simplification check: <result or routed candidate keys>
- Pending Verification: <gaps or N/A>
```

A clean result means no material finding or advisory candidate survived the
ordered pass. It does not prove unreviewed domains, unchanged architecture, or
unexecuted validation are safe. Keep those limits in coverage or `Pending
Verification` under the reviewer core.

## Category Audit Output

When selected-lens reporting needs category detail, use this compact shape
without adding packet fields:

```text
Review closeout category audit:
- consequence_advisory: <covered surface; disposition count>
- simplification: <covered surface; disposition count>
- documentation_truth: <changed prose plus final navigation surfaces; disposition count>
- naming_readability: <changed-line convention surface; disposition count>
- dedupe_key_join: <root-cause keys emitted or none>
```

## Compatibility Aliases

The four legacy filenames remain thin aliases for old prompts, evals, and links. Active callers load this canonical file once. Each alias points to its exact category heading and carries only a trigger and ownership summary.

Do not add behavior to an alias. Change this file and the behavior fixtures together. Remove an alias only after every route, eval, doc, and mirror reference has moved. On disagreement, this canonical file and the reviewer core win.
