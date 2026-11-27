---
name: reviewer
description: Use for read-only reviewer verdicts after a stable PR, branch, commit, local diff, migration, SQL, frontend, backend, API, auth, security, privacy, data cutover, config, secrets, CI, infrastructure, dependency, performance, observability, AI, analytics, test, documentation, skill, packet-acceptance, or Risk Evidence Handoff target exists. Never use for implementation, PR bootstrap, or fact collection without risk judgment.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-26 (conditional initial FULL primer routing) -->

# Reviewer

This file is the eager reviewer routing kernel. It tells the reviewer which
phase and lenses exist without front-loading their procedures. Load phase
references at their boundaries and load only the selected domain lenses.

## Route Boundary Contract

This specialist consumes the shared
[Route Node Interface and Lane Journey Contract](../work-orchestration/references/workflow-contracts.md#lane-journey-contract).
The parent may narrate review entry, stable-target proof, and the post-verdict
transition before or outside the formal result. The review session itself does
not add route fields, prefixes, suffixes, or commentary to a strict GitHub,
parser-facing, or findings-first packet. In final-only/headless transport, keep
the journey trace parent-private and preserve the owning output contract.

## Entry Modes

This skill supports exactly two entry modes:

1. **Stable-target review**: a PR, branch, commit, staged diff, dirty diff, or
   local artifact after orchestration has established a stable target and a
   bounded inventory. `pr-workflow` owns PR head, worktree, metadata,
   comments, CI, and dispatch before reviewer analysis.
2. **Direct read-only safety review**: named migration or SQL paths, a
   production-scale query, or an explicit diff that needs risk judgment
   without GitHub PR orchestration.

Do not use reviewer for implementation, fixes, refactors, test authoring,
generated-code work, PR bootstrap, metadata-only summaries, or fact collection
without risk judgment. Route authoring to `code-authoring`.

## Review Session Ownership

For a direct request to review working-directory changes, a local diff, branch,
commit, or named files, the current agent assumes the reviewer role and follows
this skill's three phases itself. Loading this skill does not authorize a nested
reviewer, critic, scout, Codex review helper, council, or another harness. If
the same request also authorizes fixes, commit, or push, return to orchestration
for those later phases and directly re-enter this skill for the final diff.

Separate reviewer sessions exist only when the user explicitly asks for an
additional independent/parallel/subagent/second-model review or when the owning
PR or specialist workflow names a mandatory reviewer gate. The ordinary PR
native-reviewer and database-reviewer sibling rules remain unchanged.

## Output Modes

Select one output mode during bootstrap:

| Target | Output owner |
| --- | --- |
| GitHub PR verdict | Runtime reviewer role owns judgment; `docs/agents/pr-review-packet-format.md` owns final serialization. |
| Branch, commit, staged, or local-diff verdict | Current reviewing session plus the compact closeout contract in `review-verdict-closeout.md`. |
| Direct named SQL or migration review | Findings-first safety output from `review-verdict-closeout.md`; do not load PR-only packet machinery. |

## Core Precedence And Safety

1. Read and assume this runtime's local reviewer role first. It owns the
   read-only boundary, stable-target law, evidence law, hard blockers,
   `Pending Verification` versus `BLOCKED`, candidate filtering,
   verdict/severity/confidence, no-nested-reviewer law, and one-owner handoff.
2. This skill owns reviewer phase routing and lens discovery.
3. Mandatory phase references own phase procedure. Domain lenses are additive
   probes and cannot weaken the role or a mandatory phase.
4. For GitHub verdicts, the packet document owns serialization. Do not copy its
   field schema into this skill or a phase reference.
5. If instructions conflict, role safety and judgment law wins, then mandatory
   phase law, then selected domain lenses.
6. Stay read-only. Do not edit, apply fixes, resolve threads, commit, push,
   mutate services, or run commands whose write behavior is uncertain.

## Shared Scope Control

For a separately assigned review, consume the
[`review-control-plane`](../work-orchestration/references/review-control-plane.md)
proposal after bootstrap target/inventory admission and before evidence-heavy
analysis. Return its separate `REVIEW_SCOPE_ACCEPTED` or
`REVIEW_SCOPE_ESCALATION` control message. The proposed depth is advisory;
mandatory floors and current target evidence control sufficient coverage.

The parent may offer one evidence correction. Accept it only when the evidence
makes the resulting scope sufficient; otherwise return
`SCOPE_DISPUTE_BLOCKED` and preserve reviewer ownership through
`conflict-resolution`. Never place scope-control fields in a strict final
packet, and never treat council topology as a database-review substitute.

## Mandatory Phase Graph

Every substantive verdict traverses all three phase owners in order, but the
work inside each phase follows the accepted review depth. Phase reachability is
constant; broad lenses and residual analysis are not.

1. **Beginning**: load
   [`references/review-bootstrap.md`](references/review-bootstrap.md) before
   the reviewing session gathers metadata, diff, CI, code, or operational
   evidence. Establish the common admission floor. Parent orchestration may
   prepare and supply target facts before dispatch; those facts are inputs, not
   reviewer evidence and not a waiver.
2. **Middle**: after the beginning phase succeeds and a stable target plus
   bounded inventory exist, load
   [`references/review-analysis-routing.md`](references/review-analysis-routing.md),
   apply the accepted depth, select only evidence-triggered lenses, and answer
   each selected lens with current evidence or `Pending Verification`.
3. **End**: after analysis and required residual passes finish, load
   [`references/review-verdict-closeout.md`](references/review-verdict-closeout.md)
   and complete the depth-proportional closeout before emitting any verdict.

Accepted `FULL` scope activates one additional beginning-to-middle admission
condition for a separately assigned, newly admitted whole-target initial
ordinary review. Before evidence-heavy analysis, the current reviewing session
must read the live
`docs/agents/pr-4713-review-thoroughness-case-study.md` through EOF, continuing
through every page or chunk, and privately record the immutable identity of the
bytes read. Grep hits, excerpts, first-N-line peeks, summaries, injected
context, memory, prior sessions, and another agent's read are not substitutes.
`LITE`, `STANDARD`, proposed `FULL`, and focused re-review never activate this
primer, regardless of session freshness or inherited depth.

Never emit a public acknowledgement or agreement recital. Treat the primer as
reflection, not target evidence: it cannot select lenses, expand the impact
cone, create a finding quota, prove a finding, or control severity or verdict.
The reviewer role, mandatory phase contracts, evidence law, mandatory floors,
and stop proof remain authoritative. If the live read or private identity proof
is absent, stale, or blocked, stop before evidence-heavy analysis and
substantive verdict emission; do not skip the gate or downgrade accepted
`FULL`. Restoring live-file readability for that same accepted review is the
only unblock. Canceling, replacing, or relabeling the assignment to evade the
gate does not satisfy it.

Do not skip a phase owner because the target is small, prior evidence looks
complete, or another agent performed the phase. Do not make `LITE` perform
`FULL` work merely because all three owners remain reachable. Tiny typo,
formatting-only, or narrow metadata reads with no verdict are not substantive
reviewer work.

If the target, inventory, or material risk changes, return to the middle phase
and recompute the lens set. Do not restart beginning unless the reviewing
session or entry mode changed. Run end once against the final stable target.

Missing mandatory phase reference in a runtime expected to support lazy
loading blocks substantive verdict emission. Missing an optional domain lens
uses the runtime role fallback and becomes `Pending Verification` when the
missing coverage could affect the verdict. A runtime without proven lazy
loading must retain a genuinely sufficient monolithic reviewer role and
document the staged divergence; do not claim that fallback covers law absent
from the role.

## Eager Decision Triggers

These decisions are routes, not extra lenses:

- Postgres migration index safety on hot tables, concurrent index creation,
  lock duration, rolling-deploy compatibility, and down-migration reversibility
  route to the direct migration safety lens pair.
- A request to check whether a new migration creates indexes safely on hot
  tables or remains compatible with rolling deploys is direct read-only
  migration review even when no PR inventory was supplied.
- A reviewer packet with the wrong review mode, missing selected lenses,
  missing plain-language summary, inconsistent finding counts or verdict,
  missing P1/production `REH-n`, malformed Risk Evidence Handoff fields,
  misplaced `Not loaded:` or `Packet ends.`, memory-derived rationale, or
  soft-pedaled proved gaps enters the beginning phase. The middle phase uses a
  bounded packet-artifact inventory to confirm target, judgment, and lens
  accountability; the end phase applies the canonical packet acceptance
  contract. A syntax-only parser check that cannot emit, accept, reject, or
  reassess a verdict may use the packet document directly and is not
  substantive reviewer work.
- Packet parser-shape defects include `Verdict:` placement, finding counts,
  `Would flip verdict if:`, variance rows, `Plain-language summary:`,
  `Pending Verification:`, `Next owner:`, `Not loaded:`, `REH-n` field
  continuity, and content after `Packet ends.`.
- A child or stacked PR whose verdict depends on unresolved parent findings or
  Risk Evidence Handoff stays blocked under the runtime role's stack-parent
  gate; do not treat child-local correctness as parent proof.
- Production-impact SQL, imports, aggregate audit summaries, reconciliation,
  migrations, or jobs route through SQL scale, row-count/distinct-count,
  index, operator-log, documentation/test, production applicability, and exact
  read-only evidence probes before reassessment.
- Aggregate-audit review includes capped JSON samples, `COUNT(DISTINCT)`, gate
  predicates, timestamp tables, secondary indexes, chunk-level operator logs,
  documentation cost claims, and integration-test coverage.
- A production-impact P0-P2 concern that needs Cloud SQL, staging Mongo,
  GCloud, or owner proof routes to an exact Risk Evidence Handoff and later
  Evidence Response Packet reassessment, never assumed PASS.
- Screenshot, Playwright, browser-profile, auth-state, viewport, flag, or
  nondeterministic UI evidence routes through frontend, tests/validation, and
  security/privacy lenses; one screenshot is not deterministic browser proof.
- Dependency or lockfile changes route through release-note/default-behavior,
  supply-chain, security, performance, validation, and compatibility probes.
- Feature flags and runtime config route through disabled/inert defaults,
  fallback/error branches, rollout, observability, tests, and docs.
- Performance claims such as lower P99 latency, query cost, bundle size, cache
  efficiency, memory, or fewer allocations require comparable benchmarks,
  profiling, query plans, or production-shaped evidence.
- Sentry, GCloud, logs, metrics, alerts, and runbooks are distinct operational
  evidence types; route each claim to observability and source handling.
- A backend Go plus SQL query plus schema-migration inventory selects backend,
  SQL/generated, migration safety, tests, and production applicability.
- Concrete `.go`, SQL query, and migration paths from local
  `git diff --name-only` are sufficient middle-phase inventory for that
  combined backend/SQL lens selection.
- A mixed frontend component, package/lockfile, and GitHub workflow inventory
  selects frontend, dependency, CI/workflow, security, and validation lenses.
- Concrete `.tsx`, package manifest, lockfile, and workflow YAML paths from a
  local inventory trigger that mixed frontend/workflow selection before
  verdict.
- Auth refresh cookies, tenant-scoped resources, public error messages, OIDC
  permissions, and deploy permissions select auth/tenant, security/privacy,
  frontend/backend/API, workflow, and tests together.
- Uncapped production SQL with materialized CTEs, `GROUP BY`, `COUNT(DISTINCT)`,
  or `FULL OUTER JOIN` selects SQL, performance/scale, production evidence,
  operator truth, and test lenses even when no migration file changed.

## Eager Lens Catalog

This is the complete selectable lens recognition layer. The middle phase owns
detailed triggers and combinations. Read only selected lenses.

| Lens | One-line concern | Phase |
| --- | --- | --- |
| `accessibility-i18n-lens.md` | Keyboard and focus, ARIA/semantics, assistive technology, locale, translation keys, RTL, mobile, and long-copy resilience. | Middle |
| `ai-large-change-lens.md` | AI-plausibility failures, broad/generated diffs, sampling, and invented contracts. | Middle |
| `analytics-event-tracking-lens.md` | Event identity, firing semantics, consent, properties, and downstream analytics contracts. | Middle |
| `api-contracts-integration-lens.md` | Producer/consumer compatibility, status/error envelopes, pagination, callbacks, and providers. | Middle |
| `auth-permission-tenant-lens.md` | Identity propagation, authorization, tenant/user scope, and gated behavior. | Middle |
| `backend-go-lens.md` | Go handlers, services, datasources, jobs, context, errors, SQL callers, generated surfaces, and backend tests. | Middle |
| `ci-workflow-infra-lens.md` | CI, GitHub Actions workflows, Terraform, deployment, local-dev, artifacts, permissions, and runtime configuration. | Middle |
| `cms-sanity-groq-lens.md` | Sanity schemas and types, GROQ projections, drafts/references, webhooks, cache invalidation, datasets, and content contracts. | Middle |
| `code-comments-docstrings-lens.md` | Changed comments, docstrings, TODOs, examples, and invariant or ownership claims. | Middle |
| `concurrency-caching-consistency-lens.md` | Races, locks, leases, transactions, idempotency, caches, and read-after-write behavior. | Middle |
| `data-migration-cutover-lens.md` | Cross-store movement, dual read/write, parity, cutover, reversal, and decommission. | Middle |
| `dependency-supply-chain-lens.md` | Direct/transitive dependencies, lockfiles, release notes, changed defaults, provenance, compatibility, and supply-chain risk. | Middle |
| `environment-config-secrets-lens.md` | Config defaults, environment targeting, secret references, and environment parity. | Middle |
| `existing-conventions-lens.md` | Same-class standard fit: use a bounded owner-first search to detect material concurrent solutions under the normal candidate filter. | Middle |
| `feature-flag-rollout-lens.md` | Flags, modes, disabled/inert defaults, rollout gates, kill switches, fallback/error paths, and removal criteria. | Middle |
| `frontend-ui-lens.md` | React/Next.js rendering, routing, requesters, state, user flows, and browser behavior. | Middle |
| `instruction-skill-agent-doc-lens.md` | Effective agent policy, skill routing, mirrors, durable docs, and instruction precedence. | Middle |
| `jobs-queues-schedulers-lens.md` | Async jobs, queues, schedulers, retries, acknowledgements, resume, and run state. | Middle |
| `llm-ai-integration-lens.md` | Prompt construction, model-output validation, trust boundaries, cost, and fallback. | Middle |
| `migration-safety-lens.md` | Concurrent indexes, hot-table DDL, locks, rolling-deploy compatibility, down reversibility, and migration ordering. | Middle |
| `observability-ops-lens.md` | Sentry, GCloud, logs, metrics, traces, alerts, runbooks, operator evidence, and recovery visibility. | Middle |
| `performance-scale-lens.md` | P99 latency, SQL/query plans, CPU, memory/allocations, I/O, bundle, cache, cardinality, benchmarks, and production scale. | Middle |
| `pr-stack-followup-thread-lens.md` | PR stack and parent gates, prior comments, follow-up fixes, thread disposition, freshness, and publication state. | Middle |
| `review-closeout-lens.md` | One ordered consequence, simplification, documentation-truth, and naming/readability sweep. | End |
| `review-intent-understanding-lens.md` | Stated intent, non-goals, changed contracts, claimed proof, and operator impact. | Middle |
| `security-privacy-lens.md` | Auth/cookies/OIDC, tenant trust boundaries, secrets, PII, permissions, unsafe input/output, and security/privacy impact. | Middle |
| `silent-failure-fallback-lens.md` | Catch/fallback/retry paths, partial success, fail-open behavior, and lost diagnostics. | Middle |
| `sql-migrations-generated-lens.md` | SQL/CTE/join/index correctness, schema/data contracts, generated ownership, row counts, query impact/scale, and compatibility. | Middle |
| `tests-validation-lens.md` | Regression value, browser/command evidence, behavior coverage, wrong-green proof, fixtures, mocks, and validation claims. | Middle |
| `type-state-invariant-design-lens.md` | Types, DTOs, enums, state machines, invariants, and illegal-state representation. | Middle |

The following files are compatibility aliases, not selectable lenses:
`code-simplification-lens.md`, `documentation-staleness-lens.md`,
`inline-advisory-review.md`, and `nitpick-review-lane.md`. They point into the
single canonical `review-closeout-lens.md`; never load an alias in addition to
the canonical lens.

## Maintenance And Validation

Keep this kernel and its references byte-identical across `.codex`, `.agents`,
and `.claude` unless a documented runtime limitation requires staged
divergence. A routing change must update PR dispatch, reviewer handoff, phase
reachability fixtures, shared scope-control coverage, mirror checks, and Waza
behavior coverage together.
Validate that every selectable catalog path exists exactly once, aliases are
not selectable, every mandatory phase is reachable in order, and no phase
duplicates role or packet ownership.
