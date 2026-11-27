<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-26 (conditional initial FULL primer entry guard) -->

# Reviewer Middle Phase

Load this mandatory phase only after reviewer bootstrap succeeds. It owns
stable-target confirmation, bounded inventory, lens selection, production
applicability, evidence routing, and residual analysis. It does not own verdict
law or packet serialization.

For a separately assigned review, enter only after the shared scope-control
message reached `REVIEW_SCOPE_ACCEPTED`, `ESCALATION_ACCEPTED`, or
`CORRECTED_AND_ACCEPTED`. A `SCOPE_DISPUTE_BLOCKED` result blocks analysis
under the disputed narrowing. Later target evidence may reopen scope control
with one evidence-backed escalation; it does not permit repeated negotiation
or parent-imposed narrowing.

For a separately assigned, newly admitted whole-target initial ordinary review
whose accepted depth is `FULL`, also confirm that the reviewing session
completed the private
initial-review primer through EOF at the current live content identity. Block
evidence-heavy analysis when that admission proof is absent, stale, or
unreadable; do not downgrade or silently skip it. This entry guard never applies to `LITE`, `STANDARD`, or focused re-review.
Primer content is not target evidence and cannot select a lens, expand the
cone, create a finding quota, or influence severity or verdict directly.

## Target And Inventory

1. Confirm the exact review target from current evidence.
   - PR: pinned worktree head SHA and base supplied by orchestration, rechecked
     locally before use.
   - Branch or commit: named base/head or commit SHA.
   - Staged or dirty: state which local state is included and preserve
     unrelated work.
   - Direct named-path: named files or symbols plus only the related context
     necessary for safety judgment.
2. Build the bounded inventory from that target. For diff-shaped work, use the
   local changed-file list. For direct review, do not invent a diff.
3. Close the depth-independent admission floor before verdict: identify the
   changed contract and immediate effects, detect mandatory floors, assess
   claimed proof, and give every admitted surface a lens, bounded micro-probe,
   or evidenced `not loaded` disposition.
4. Apply the accepted depth:
   - `LITE`: inspect the exact change, immediate contract and effect, one-hop
     callers or consumers, claimed proof, and every triggered lens or
     micro-probe.
   - `STANDARD`: add nearby callers and consumers, relevant tests, configs,
     docs and generated surfaces, and every triggered lens.
   - `FULL`: add cross-boundary states, compatibility, failure and recovery
     paths, rollout/rollback, operator evidence, and an independent residual
     pass.
5. If target or inventory changes, discard target-dependent conclusions,
   recompute lenses, and repeat this phase before verdict.

Target-dependent conclusions also expire when a material artifact, environment,
configuration, topology, workload, data shape, or evidence source changes.
Evidence names the immutable target or artifact, environment, observation time,
scope, and limitations when those facts affect the claim. Current-state and
recovery exercises prove only their observed scope, time, integrity checks, and
limitations.

For parser-facing PR verdicts, use current repo and authenticated evidence.
Memory, copied prior packets, hidden summaries, and prior-session conclusions
are not verdict evidence.

## Lens Selection Algorithm

1. Apply the common admission floor and mandatory context lenses from the
   matrix below.
2. Give every changed file, named path, or changed-boundary surface one
   disposition: selected lens, bounded micro-probe, or evidenced `not loaded`.
3. Add risk lenses when behavior crosses a domain even if paths do not reveal
   it.
4. Read each selected lens and turn its guidance into concrete target-specific
   probes.
5. Run independent source, caller, test, docs, CI, and operational reads in
   parallel only after target, read-only boundary, disjoint scopes, and join
   point are known. One reviewer owns the evidence join, dedupe, severity, and
   verdict.
6. Join candidates by root cause. A shared missing guard is one finding, not a
   frontend, backend, and test finding.
7. For `STANDARD` and `FULL`, run the compact dimension sweep: correctness,
   security/privacy,
   performance/scale, tests/verification, architecture/conventions,
   dependency/migration, DX/tooling, docs/operator truth, and value/direction.
   Load the narrowest missing lens only when a material candidate is
   uncovered. `LITE` uses the same dimensions as a bounded trigger probe,
   without loading another lens absent a material signal.
8. Freeze the selected set for the stable target. Reroute only when target,
   inventory, or material risk changes; do not repeatedly scan every reference.

For `LITE`, do not open an optional lens merely to learn whether its trigger
exists. Use this phase's matrix and inline micro-probes first, then open the
lens only after current target evidence satisfies its trigger. Understanding a
private rename's stated intent belongs to the common admission floor; it does
not by itself select `review-intent-understanding-lens.md`. Likewise, a bounded
conventions micro-probe does not select or open
`existing-conventions-lens.md` unless it finds a competing pattern, material
candidate, unclear ownership, or a second implementation path.

Every selected lens must produce evidence, a rejected candidate with reason,
or `Pending Verification`. Do not emit checklist output merely because a lens
was loaded.

Begin the impact cone with the changed contract, changed files or symbols,
immediate effects, one-hop callers or consumers, claimed proof, and direct
documentation or operator consequences. Expand only for current evidence of a
reachable external caller or consumer, a crossed runtime/data/auth/API/security
or operator boundary, a sibling sharing the protected invariant or failure
mechanism, one artifact that can materially change severity or verdict, or a
mandatory floor. Record the trigger, evidence, added boundary, and defect class
the old cone could miss. A bounded probe may discover this evidence; absence of
evidence forbids broader expansion, not the probe.

## Mandatory Context Matrix

| Trigger | Mandatory lenses |
| --- | --- |
| Every substantive verdict | `review-closeout-lens.md`, executed once during the end phase after residual analysis. |
| Every GitHub PR or PR-bound verdict | `review-intent-understanding-lens.md`. Current head, body, thread inventory, checks, and strict packet truth remain PR-workflow evidence independent of lens selection. |
| Stack lineage, follow-up lineage, fetched prior threads/comments, contested prior finding, or a proved publication-state defect | `pr-stack-followup-thread-lens.md`. |
| Broad, generated, refactor, mechanical, multi-domain, placeholder-heavy, or suspiciously fluent target | `ai-large-change-lens.md` and `existing-conventions-lens.md`. |
| Follow-up patch, bug fix, or contested prior finding | `pr-stack-followup-thread-lens.md` and `tests-validation-lens.md`. |
| Instruction, skill, agent, prompt, durable doc, ADR, or runbook | `instruction-skill-agent-doc-lens.md`. |
| Changed comments, docstrings, TODOs, examples, or invariant prose | `code-comments-docstrings-lens.md`. |
| New or changed types, DTOs, enums, state machines, or generated shapes | `type-state-invariant-design-lens.md`. |
| Catch, retry, fallback, optional effect, partial success, mock, or default-on-failure | `silent-failure-fallback-lens.md` and `tests-validation-lens.md`. |
| Auth, permission, tenant, privacy, secret, trust boundary, or supply chain | Matching domain lens plus `security-privacy-lens.md` and `tests-validation-lens.md`. |
| Direct migration or migration-central review | `sql-migrations-generated-lens.md` and `migration-safety-lens.md`. |
| Cross-store movement, backfill, parity, cutover, or decommission | `data-migration-cutover-lens.md` plus SQL, job, flag, consistency, observability, and test lenses as applicable. |
| Production blast-radius surface | Every lens required to trace code to production effect, operator proof, rollback, and detection. |

Do not load AI/large-change or existing-conventions for tiny docs-only targets
without behavior, operator, runtime, validation, architecture, naming, or
ownership claims. For a `LITE` or bounded `STANDARD` implementation target,
perform a micro-probe in the nearest authoritative owner for competing ways to
handle the same job. Load `existing-conventions-lens.md` only when the probe
finds competing patterns, a material convention candidate, unclear ownership,
or evidence that the change creates a second path. Broad, generated, refactor,
mechanical, multi-domain, placeholder-heavy, or suspiciously fluent targets
load the full conventions and AI lenses. A small target loads the AI lens only
when current evidence suggests an invented API/path/command, impossible
validation, lost behavior, overclaiming prose, or a generic abstraction that
bypasses the repository owner.

## Detailed Routing

Use the eager catalog for recognition, then apply these combinations:

- Frontend routes, React/Next.js components, hooks, contexts, requesters,
  styling, browser state, or E2E helpers: `frontend-ui-lens.md`; add API,
  accessibility/i18n, performance, security, and tests when those contracts
  move.
- Go controllers, services, datasources, REST handlers, config, queues,
  caches, jobs, SQL callers, or backend tests: `backend-go-lens.md`; add SQL,
  API, concurrency, jobs, resilience, observability, security, and tests for
  the changed effect path.
- SQL, migrations, sqlc, schema, seeds, generated models, persisted JSON,
  cache/event schemas, or data fixtures: `sql-migrations-generated-lens.md`;
  add `migration-safety-lens.md` for DDL/lock/rolling compatibility and
  `data-migration-cutover-lens.md` for cross-store ownership movement.
- Review stacked or assembled changes cumulatively when their combined state or
  execution order controls safety; an isolated clean diff is not assembled-state
  proof.
- Sanity schema, GROQ, webhook, CMS cache, dataset, or content contract:
  `cms-sanity-groq-lens.md`; add environment, API, security, tests, and
  observability as the path requires.
- GitHub Actions, Terraform, deployment, IAM, runtime config, Docker/local-dev,
  release, or operator workflow: `ci-workflow-infra-lens.md`; add environment,
  security, observability, dependencies, and tests.
- Public/internal API, requester, callback, webhook, provider, pagination, or
  status/error contract: `api-contracts-integration-lens.md` plus producer and
  consumer lenses; add security for public or sensitive boundaries.
- Flag, mode, environment toggle, experiment, datasource switch, kill switch,
  or deploy gate: `feature-flag-rollout-lens.md` plus affected domain, tests,
  docs, observability, and config lenses.
- Cache, lock, lease, transaction, idempotency, dedupe, stale state, or
  concurrent mutation: `concurrency-caching-consistency-lens.md` plus the
  persistence/job/fallback/performance/security lenses required by the path.
- Job, queue, scheduler, worker, batch script, ack/nack, retry, resume, or run
  state: `jobs-queues-schedulers-lens.md` plus production/data, fallback,
  observability, workflow/config, and tests.
- LLM prompt, model call, streaming output, parsing, retrieval, or generated
  content: `llm-ai-integration-lens.md` plus API, fallback, security, tests,
  and performance/cost where claimed.
- Config key, default, `.env*` declaration, dataset/project target, connection
  string, or secret reference: `environment-config-secrets-lens.md` plus CI,
  security, and documentation truth.
- Analytics event, property, firing point, identity, consent, or experiment
  exposure: `analytics-event-tracking-lens.md` plus firing-path, privacy, and
  tests.
- Dependency, lockfile, package manager, action, image, or tool version:
  `dependency-supply-chain-lens.md` plus CI, security, tests, and runtime
  compatibility.

Version claims must be verified from current package files, lockfiles,
`go.mod`, `go.work`, toolchain pins, or CI. For Next.js, use version-matched
local docs when present; do not claim they were read without inspection.

## Behavior-Contract Map

For changed conditional behavior, privately map:

- meaningful states or inputs;
- prerequisites and gates;
- branch precedence;
- output or side effect per branch;
- error, retry, cancellation, and fallback behavior;
- observability and operator-visible state;
- docs/comments/help text; and
- proof for each meaningful branch.

Use missing, unreachable, contradictory, or wrong-green rows as candidate
findings. Do not review one branch in isolation from modes that share state or
side effects.

## Production Applicability Map

Trigger production analysis for mutation-capable jobs, apply/repair/import/
reconcile paths, production-sized SQL, migrations, cross-store consistency,
caches, queues, external effects, CMS mutations, Cloud Run, Terraform, secrets,
IAM, deploy workflows, auth, permissions, PII, learner records, or public APIs.

For each applicable category, record:

- changed trigger or surface;
- proof question;
- applicable `yes` or `no`, with source evidence;
- answered artifact or `Pending Verification`;
- central `yes` or `no`, with reason; and
- verdict impact.

Probe the smallest evidence needed for worst-case data shape and query plan;
bounds, chunks, timeouts, retries, idempotency and resume; transaction outcome
and rollback; dry-run/apply equivalence; environment parity; permissions and
secret targeting; operator run state; observability; and recovery.

Every applicable central unknown must remain `Pending Verification` and block
only the exact decision whose safety depends on it, with a Risk Evidence
Handoff under the reviewer role. A non-central unknown may remain
`Pending Verification` without blocking an unrelated decision. Do not call
production behavior safe, rare, unlikely, or mitigated without current metrics,
source impossibility proof, an explicit contract, or documented owner
acceptance.

## Prior Comments And Residual Pass

When prior review comments exist, challenge both open and closed dispositions
against current code before independent analysis. Confirmation is input, not
the review.

Run an Independent Residual Pass for `FULL` or `COUNCIL` review, production
blast radius, fetched prior threads, migration/data/auth/public API surfaces,
or any case where prior review could anchor attention. `LITE` and `STANDARD`
omit an otherwise untriggered residual pass after the admitted inventory is
closed. Probe unmentioned callers, negative branches, old/new compatibility,
partial failure, wrong-green tests, operator truth, and next-consumer
acceptance. Record what was independently probed and what remains uninspected.

When the diff changes config or flags, SQL result shaping, transactions,
cleanup, retries, or durable side effects, the residual pass must independently
reconstruct the applicable changed-boundary rows before consulting an author's
matrix, prior reviewer findings, or review summaries:

- config presence versus value: omitted, explicit zero, negative, positive,
  repeated, and conflicting-mode input;
- SQL logical key versus physical multiplicity: zero, one, duplicate, stale,
  and malformed source rows, with exact aggregate/output cardinality;
- transaction lifecycle: every begin, commit, rollback, close, and
  uncertain-commit branch under active, canceled, and expired parent contexts;
- detached cleanup: fresh bounded context, pooled-resource release, durable
  bookkeeping, and false-terminal-state behavior.

This is not a second review round and must not echo the author's answers. Build
it from the stable diff and surrounding contracts, record the probes and
evidence, then compare with prior material only after the independent pass.
Missing an applicable row is incomplete residual analysis, not an empty proof.

## Read-Only Evidence Lanes

Evidence lanes are not reviewer lenses. They are subordinate to the
phase-specific allowed and forbidden evidence ceiling in `reviewer-handoff`;
this catalog never grants authority. For ordinary PR review, use only local
source and Git inspection, checked-in artifacts within their provenance,
GitHub PR metadata, reviews, threads, and head-pinned CI metadata. Do not run
commands that execute validation and do not access live runtime, environment,
database, logging, monitoring, Sentry, or browser state. Record unavailable
current proof as claim-specific `Pending Verification`. A separately
user-requested validation or production-readiness phase must classify again
before selecting any live evidence lane below.

When the owning phase permits them, use evidence lanes only when they improve proof:

- local source/caller map;
- focused local command that is installed, foreground, bounded, and
  non-mutating;
- current-head GitHub checks and artifacts;
- `readonly-data-access` for bounded database metadata, plans, and
  read-only queries;
- staging Mongo read-only evidence;
- existing GCloud logs, monitoring, errors, and job metadata;
- existing Sentry issue, event, replay, or profile evidence;
- Cloud Run, Cloud SQL, IAM, VPC, region, timeout, retry, and secret-name-only
  metadata; or
- owner decision for product, rollout, legal, data, security, or infra policy.

Every lane needs a do-not-run boundary. Never request or perform writes,
migrations, unbounded production scans, secret inspection, or broad service
experiments. When evidence cannot be gathered read-only, create the exact Risk
Evidence Handoff required by the runtime role.

## Middle-Phase Completion

Before entering verdict closeout, record:

```text
Reviewer analysis routing:
- stable target: <base/head, commit, local state, or named paths>
- selected depth: <LITE | STANDARD | FULL>
- bounded inventory: <files or symbols>
- admitted-surface closure: <every surface and selected lens, micro-probe, or evidenced not-loaded disposition>
- impact cone: <initial boundary, evidence-backed expansions, and closure>
- selected lenses: <lens and concrete surface>
- not loaded: <common lens and reason>
- behavior-contract map: <completed | not triggered | Pending Verification>
- production applicability: <completed | not triggered | BLOCKED>
- prior-comment pass: <completed | not triggered>
- independent residual pass: <completed | not triggered>
- FULL initial-review primer: <not activated | completed at content identity | same-session unchanged-identity reuse | blocked>
- stop proof: <all admitted surfaces disposed, P0-P2 candidates classified, claims assessed, no hidden verdict-changing gap or active expansion>
- changed-boundary reconstruction: <not triggered or independently completed applicable rows>
- unresolved central proof: <none | REH identifiers>
- target changed during analysis: no | yes, middle phase recomputed
- end phase allowed: yes | no, because <reason>
```

Missing this mandatory phase blocks substantive verdict emission in a runtime
expected to support lazy loading.
