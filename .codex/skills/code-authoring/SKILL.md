---
name: code-authoring
description: Use for example-app code authoring, refactoring, tests, workflow/config/script/dependency changes, backend codegen, SQL/migrations, cross-store data migration/cutover, APIs/integrations, auth/permissions, Sanity CMS, environment config/secrets, LLM/AI integration, analytics/event tracking, observability, resilience, rollout flags, production data safety, security, and code readiness.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-08-04 (accepted-plan conformance intake and handoff) -->

# Code Authoring

Use this skill when the next phase writes or changes code, tests, generated
artifacts, workflows, configs, dependencies, scripts, or implementation-facing
documentation. It owns code authoring quality before a stable target leaves the
implementation phase.

`work-orchestration` owns the phase route. This skill owns how code is
written once the route is code authoring.

## Entry Contract

### Route Boundary Contract

This specialist consumes the shared
[Route Node Interface and Lane Journey Contract](../work-orchestration/references/workflow-contracts.md#lane-journey-contract).
Before the first target-specific authoring action, the parent names why code
authoring owns the phase, the accepted inputs and side-effect boundary, the
candidate evidence that ends authoring, and the expected validation or review
consumer. At authoring exit, the parent narrates that evidence before the next
lane acts. Internal authoring lanes remain private implementation machinery and
do not each emit a second journey trace.

### Operational "substantive" definition (law)

A task is **substantive** when it includes any of: PR review, code behavior,
tests, config, migration, auth, API, data, runtime behavior, CI, publication
readiness, or a ready/green/pass claim. Tiny typo or pure formatting may skip
case-study gates only when the task has no PR, readiness, or verdict claim.
Soft words such as "quick", "light", or "sanity check" do not make substantive
work non-substantive.

Before using this skill for substantive work, read
[docs/agents/pr-4685-lane-discipline-case-study.md](../../../docs/agents/pr-4685-lane-discipline-case-study.md)
and state the required agreement from that document to the user. This is a
hard gate: naming lanes is not applying lanes. Tiny typo, formatting-only,
quick lookup, and straightforward explanation tasks do not require the case
study unless the work turns into substantive authoring, substantive review, or
a high-risk recommendation (see operational definition above). Do not start
code edits until the relevant lanes are read at their active work item, mapped
to concrete probes, and answered with evidence or marked `Pending Verification`.

Before substantive work that may be published, handed off as PR-ready, or
reviewed as a PR-bound branch, also read
[docs/agents/pr-4706-publication-gate-case-study.md](../../../docs/agents/pr-4706-publication-gate-case-study.md)
and state its required agreement to the user. Opening a PR is not handoff:
authoring self-audit, native reviewer subagent, Codex review helper, PR
template, review-thread handling, and current-head CI/readback gates remain
required when the publication workflow owns them.

After all triggered mandatory agreement responses are complete, and before
this authoring session performs its first target-specific evidence action, load
[references/case-study-transfer-preflight.md](references/case-study-transfer-preflight.md)
and complete its bounded transfer preflight. This is active recall, not another
agreement recital: freeze at most three task-specific commitments that name the
observable decision, probe, or stop condition each lesson will change. Do not
inspect the target diff, code, PR metadata, CI, logs, tests, browser state, or
data until the preflight is complete. Instruction and bootstrap reads,
worktree/readiness setup, exact mandatory agreement responses, and
parent-supplied routing inputs remain allowed under that reference's evidence
boundary.

Publication workflow ownership is concrete: the first push, force-push, PR
creation, PR title/body mutation, "ready for review" claim, "PR-ready" handoff,
or request to publish/open/update a PR enters the publication boundary. Before
that boundary, pure local WIP may stay in authoring/validation with publication
gates deferred. Once that boundary is crossed or claimed, publication-owned
reviewer/critic, template, thread, CI/readback, and metadata gates are required;
do not skip them by saying "not publication yet."

For new PR work, separate finding-directed commits are allowed only as
temporary local review provenance. Do not squash while a required pre-open
review or scoped re-review is active. Once every required pre-open review is
terminal and accepted findings are resolved, the authoring handoff must name
the reviewed head and route to publication's mandatory tree-equivalent squash.
PR creation remains blocked until the publication branch contains exactly one
commit over its intended base.

For high-risk work where a PR, operation, rollout, migration, data repair, or
production-affecting plan may be recommended, run forward analysis before
authoring. Define the whole current problem, inspect current evidence, check
no-code, existing-path, config, data, operator-sequence, canary, documentation,
and policy alternatives, and name the next consumer's acceptance rules plus the
next predictable blocker. If code is still needed, explain why those paths are
insufficient and why the proposed change is the smallest durable slice. Narrow
the claim or mark missing material evidence `Pending Verification`.

Consume the recorded
[native forward-analysis contract](../work-orchestration/references/forward-analysis.md)
when an earlier decision gate produced one. Do not recompute it because
authoring started. Require its ID, version, and exact record. A same-session
reference is sufficient only while this consumer can dereference the exact
current record and verify its ID/version; an opaque audit summary is not
transport. Optional digest provenance is never a prerequisite. If no earlier gate
owned the decision, complete it before editing. High-risk work includes
auth/authz, production data, migrations, rollout/release gates, infrastructure,
security-sensitive behavior, or any change that may cause another PR,
operation, data repair, rollback, or production-affecting decision.

Also read
[docs/agents/agent-violation-examples.md](../../../docs/agents/agent-violation-examples.md)
before substantive code-authoring work. Scan its index, read every complete
example that matches the task, and correct matching workflow before editing,
validating, publishing, or requesting review. Read the whole document through
EOF only for violation correction, instruction audits, or when the matching
scope cannot be narrowed.

When code-change intake lacks a current orchestration-conformance attestation,
stop before implementation merits and ask the parent only for that attestation,
including its objective-lock and forward-analysis dispositions. Do not expand
the response into a replacement workflow checklist or reconstruct those gate
results inside authoring.

Before editing, emit or keep parent-facing notes with this compact audit:

```text
Entry Contract TODO:
- orchestration conformance: pending | complete <attestation-id>, next action=<critic evaluation | plan acceptance | meaningful edits | no>
- objective lock: not required with evidence | already locked <lock-id>@v<version> | locked <lock-id>@v<version> | pending owner/evidence
- plan acceptance: not triggered | accepted <plan-id>@v<version> content=<identity>, approval=<evidence>, critic=<disposition> | blocked
- plan conformance: not triggered | initialized, steps=<stable IDs>, preservation/deletion=<obligations>
- objective conformance: not activated | complete, fields=<applicable authority fields>, mechanisms=<direct/protective/contract-changing/unrelated dispositions>, blocked=<none or item>
- pr-4685 lane discipline: pending | complete, agreement=<required agreement stated>
- pr-4706 publication gate: not triggered | pending | complete, agreement=<required agreement stated>
- case-study transfer preflight: not triggered | pending | complete, commitments=<C1-C3 or reason not triggered>
- forward analysis: not triggered | pending | complete, record=<ID/version>, transport=<exact record | verified same-session reference>
- violation examples: pending | complete, audit=<negative-pattern result>
Selected code lanes:
- <lane>: <concrete changed surface and why this lane owns the next action>
Code-change todo:
- <item>: lanes=<lane[, lane]>; load timing=just before edit; rationale=<what to look for>
Skipped adjacent lanes:
- <lane>: <why it is intentionally not loaded now>
Pre-code critic:
- required | optional | skipped, because <risk overlay and confidence rationale>
Final-shape preflight:
- needed: yes/no, because <changed risk surface>
```

For tiny single-line fixes, the audit may be one sentence. For non-trivial or
multi-step work, keep the audit as a routing ledger and update it at phase
boundaries.

For substantive code-authoring work, add the Entry Contract items to the
TODO/routing ledger before editing. Mark each item complete only after the
required agreement or audit result is visible, not merely because the file was
opened. Mark `case-study transfer preflight` as `not triggered` only when no
mandatory agreement case study was triggered. Keep `forward analysis` as `not
triggered` unless high-risk triggers apply. Keep `pr-4706 publication gate` as
`not triggered` only when the work will not be published, handed off as
PR-ready, or reviewed as a PR-bound branch. If the task changes shape, reopen
or reread the relevant contract item and update the ledger before continuing.

Use eager lane selection with lazy lane loading. Plan the code-change todo
items up front and map each item to the code lane or lanes it will need. Do not
read every selected lane immediately. Read a selected lane just before starting
the item it governs, then keep that rationale active while editing. If the item
changes shape, update the lane mapping before editing further.

### Lane fanout and load cap (law)

Cross-domain reminders name lanes to consider, not a license to front-load the
whole skill. For each active code item, name all triggered lanes in the todo,
but read only the always-loaded core plus at most two active item-specific
lanes immediately before editing. Add a third active lane only when the item
cannot be made safe without it, and record why. Keep remaining selected lanes
as deferred checks or closeout probes. Mandatory closeout lanes still run at
the closeout boundary.

## Non-Negotiable Authoring Shape

1. Treat this skill as the code-authoring boot contract. There is no separate
   code-authoring agent role file. Complete the mandatory case-study gates for
   `pr-4685-lane-discipline` and, for PR-bound work,
   `pr-4706-publication-gate`, then complete the Case-study Transfer Preflight
   before target-specific evidence. Apply the task-time forward-analysis
   contract for high-risk work before substantive authoring.
2. Select lanes from the current task, changed surface, and planned code-change
   items, not from memory or stale summaries.
3. Map each non-trivial code item to the specific lane or lanes that own the
   next edit before editing starts.
4. Read selected lanes just in time for the active item. Do not preload every
   likely lane into context.
5. Inspect implementation context before changing files: callers, consumers,
   nearby tests, generated outputs, docs, configs, and public contracts.
6. For non-trivial or risky work, classify the pre-code critic gate before
   editing. If required, run the bounded consultation to a terminal disposition,
   then complete any independently triggered exact plan acceptance; if skipped,
   record the skip rationale.
7. Keep edits requirement-backed, behavior-preserving, or root-cause-backed.
   Do not add speculative abstractions, broad rewrites, or cleanup unrelated to
   the active item.
8. During editing, run tight inner-loop checks coupled to the change, such as a
   focused red/green test, parser check, or generator verification. Route
   post-implementation command selection, broader check execution, environment
   feasibility, and final validation reporting to the orchestration validation
   lane with this skill's proof requirements.
9. Before handoff or PR publication, run the mandatory closeout lanes and report
   what they covered.
10. If a selected lane conflicts with the core authoring contract, this
    `SKILL.md` wins.
11. If a needed lane is missing or cannot be read, continue with the closest
    loaded core lane and mark the missing lane coverage `Pending Verification`
    when it could affect implementation quality.

## Do Not Use For

- final read-only verdicts after a stable target and changed-file inventory
  exist; use `reviewer` for stable-target review or final
  parser-facing verdict requests
- validation-only command selection, build or test reporting, and check
  strategy after code is already written
- PR orchestration, review worktree setup, PR comments, PR CI, or GitHub
  metadata collection before code authoring begins; use `pr-workflow`
- validation strategy as the main task after code is already written; use the
  validation lane in `work-orchestration`
- generic programming advice outside example-app repo work

## Always-Loaded Authoring Core

For non-trivial code changes, always load these lanes before the first
meaningful edit:

- `references/change-intake.md`: side-effect boundary, lane selection, and the
  visible code-lane audit.
- `references/authoring-core.md`: target contract, context discipline, central
  failure, validation truth, production posture, and runtime truth.
- `references/implementation.md`: surgical editing discipline, behavior
  preservation, generated-output movement, and implementation pattern choices.
- `references/existing-conventions.md`: same-class local precedent, naming,
  ownership, test shape, validation pattern, and evidence-backed divergence.
- `references/engineering-judgment.md`: anti-overengineering pressure,
  speculative-abstraction checks, and LLM coding footguns.

These lanes are the durable authoring role core. Other lanes are additive
domain prompts: they refine what to inspect, how to implement safely, and what
proof matters for a specific risk surface. They must not weaken the core
authoring contract, validation obligation, or handoff checklist.

## Core Flow

1. Complete the Entry Contract case-study gate first: for substantive work read
   `docs/agents/pr-4685-lane-discipline-case-study.md`; for PR-bound work also
   read `docs/agents/pr-4706-publication-gate-case-study.md`, and state their
   required agreements. Then complete
   [references/case-study-transfer-preflight.md](references/case-study-transfer-preflight.md)
   before target-specific evidence. For high-risk work, complete the task-time
   forward-analysis audit without requiring a narrative read or acknowledgement.
   Then load
   [references/change-intake.md](references/change-intake.md) for every
   non-fast-exit code task.
2. For every non-trivial code task, load
   [references/authoring-core.md](references/authoring-core.md),
   [references/implementation.md](references/implementation.md),
   [references/existing-conventions.md](references/existing-conventions.md), and
   [references/engineering-judgment.md](references/engineering-judgment.md)
   before the first meaningful edit.
3. Prepare or update the code-change todo. Each code item must name the selected
   lane or lanes, the just-in-time read point, and the rationale for what the
   agent should look for while editing.
4. Select only the lanes needed for the next active code item. Do not load
   every lane.
5. For non-trivial or risky work, load
   [references/pre-code-critic-assignment.md](references/pre-code-critic-assignment.md)
   and classify whether critic is required, optional, or skipped with
   rationale. Preserve lazy lane loading: name lanes already read separately
   from lanes selected but scheduled just in time.
6. If critic is required or useful, run the bounded consultation and wait for a
   terminal disposition before editing. Revise the candidate if critic returns a central gap,
   `LOW` confidence, `REVISION REQUIRED`, `ESCALATION REQUIRED`, or `BLOCKED`.
   One critic consultation may also satisfy `idea-challenge` only when its brief and
   verdict explicitly answer both the should-do and implementation-readiness
   questions, name selected implementation lanes, and the plan is materially
   unchanged.
7. Just before starting a code item, read the selected lane files for that item.
8. Write the smallest behavior-preserving or requirement-backed change.
9. Before the next code item, record the completed item's delta: changed
   surface, newly triggered risk or lane, selected proof, and whether the next
   item may proceed. Do not repeat the full assembled-target contract when the
   target and risk map are unchanged.
10. Before validation, publication, review, GitHub mutation, or handoff, run the
    full code authoring handoff contract once against the assembled stable
    target. Rerun it only when the diff, base/head, or risk map changes.
11. Pass the proof contract to the orchestration validation lane for broader
    command selection, execution, environment classification, and reporting.
12. Before handoff or PR publication, run the mandatory closeout lanes named in
    "Mandatory Closeout Lanes" below — `simplification`, `docs-and-operator-truth`,
    then [references/authoring-preflight.md](references/authoring-preflight.md), in
    that order — plus any risk lanes the change triggers.
13. When the assembled target is an agent-authored substantive change that will
    enter an independently dispatched reviewer gate, run
    [references/author-self-review.md](references/author-self-review.md) after
    closeout and before dispatch. It records only the reviewer-lens delta from
    the completed authoring handoff; it is not a verdict or a second handoff
    packet. Apply its explicit exclusions for teammate review, parent-owned
    direct review, eligible local micro-edits, and finding-directed re-review.
14. If reviewer, Copilot, CI, or human feedback finds a non-trivial issue,
    classify the missed issue class before handoff. If selected lanes already
    covered it, record it as lane-application failure and rerun the lanes
    against the current diff. If lane guidance was not concrete enough, add or
    schedule a generic update to the owning authoring and reviewer lanes before
    treating the workflow as closed.

## Code Authoring Delta And Handoff Contract

After each substantive code-authoring item, record a compact delta check before
starting the next code item: changed surface, new risk or lane, selected proof,
and `next item allowed: yes/no`. If the diff or risk map changed, read the newly
triggered lane before continuing.

Before routing the assembled target to validation, review, PR publication,
GitHub mutation, or handoff, complete the full contract below once. Rerun it
only when the diff, base/head, or risk map changes:

- Treat the completed item as a stable authoring target: name the item, current
  diff scope, changed files or symbols, and base/head when the work is PR or
  branch-shaped. Do not rely on the original plan when the diff proves a
  different surface changed.
- Revisit every lane selected for the item, including the always-loaded core
  lanes and any risk/file-routed lanes added during implementation.
- Check the actual diff against those lane instructions, not the original plan.
  If the diff changed the risk surface, update the lane map, read the newly
  relevant lane, and rerun this contract.
- Convert each selected lane into concrete completed probes: context inspected,
  invariant preserved, failure mode handled, test or validation selected, docs
  updated, and remaining proof marked `Pending Verification`.
- When config/flags, SQL result shaping, transactions, cleanup, retries, or
  durable side effects changed, complete the trigger-scoped Changed Boundary
  Proof from `authoring-preflight`. A lane name is not proof; record applicable
  states and evidence, and block reviewer handoff while a row is unanswered.
- Record a compact coverage ledger: surfaces reviewed, surfaces intentionally
  sampled, surfaces not inspected, and why any uninspected surface is still safe
  to leave as `Pending Verification`.
- Record variance from the original route: lanes added, lanes skipped, approach
  changes, validation changes, and the evidence that the final lane set still
  covers the code-to-runtime effect.
- If any selected lane's instructions were not followed, stop. Do not advance
  to the next item. Redo the implementation, add the missing proof, or narrow
  the claim until the lane is satisfied.
- If review/council feedback would likely be needed to discover whether the
  selected lanes were honored, treat that as an authoring failure and do the
  self-audit before asking for review.
- Do not ask an external reviewer, council, sidecar, Codex review helper, or
  Copilot pass to catch lane violations the author can detect locally. Before
  any reviewer gate, rerun this handoff contract against the actual diff and
  fix missing context, validation, docs/operator truth, or lane coverage first.
  If a reviewer later flags an issue that a selected code-authoring lane would
  have caught, treat that as failed authoring discipline. Stop the review loop,
  reread the missed lane, update the lane map if needed, and rerun this
  contract before requesting another review.
- Treat accepted or actionable findings from the Codex review helper, native
  reviewer subagent, Copilot, council, or human reviewers as authoring-lane
  feedback before final handoff. For each finding, decide whether an existing
  selected lane already covered it and was missed, whether the owning lane is
  missing or too weak, or whether it is a one-off project decision. If the lane
  is missing or weak, classify whether the gap is generic and recurring or a
  one-off project decision. Existing-lane misses rerun the lane and this
  contract; one-off decisions are recorded without instruction edits. Generic
  recurring gaps become a durable follow-up or enter violation correction only
  when the current task authorizes instruction writes and publication. Never
  block product readiness on an unrelated instruction commit or push.
- Classify every post-review fix, before or after PR creation, before spending
  expensive reviewer gates again. Simple, bounded fixes such as documentation wording, typo corrections,
  local comment/help text updates, trivial guard reordering, or an obvious
  early return may skip native reviewer and Codex review reruns after focused
  validation and finding or thread readback. Straightforward test expansion
  requested by a reviewer may use the same skip when it only locks
  already-reviewed behavior and does not change production code, test strategy,
  fixtures that define product semantics, or the reasoning contract. Do not use
  this as a blanket skip: rerun the
  needed reviewer gate when the fix changes behavior, SQL, auth, data, infra,
  concurrency, error handling, public contracts, test strategy, operator
  workflow, or when the review comment asks for design judgment instead of a
  mechanical edit.
- Scan the index in
  [docs/agents/agent-violation-examples.md](../../../docs/agents/agent-violation-examples.md)
  before handoff, PR publication, or any reviewer gate and read every matching
  complete example. Read through EOF only for violation correction,
  instruction audits, or when matching scope cannot be narrowed. If an example
  resembles the current work, stop, correct the workflow or artifact, rerun the
  relevant validation or evidence gate, and record the correction.
- Reject the handoff packet as invalid if it omits the selected lanes, coverage
  ledger, variance ledger, validation or proof selection,
  `Pending Verification`, or an explicit `next action allowed` decision.
  Invalid means the authoring phase is not done yet.

Use this checklist shape once for the assembled non-trivial stable target:

```text
Code authoring handoff contract:
- item completed: <item>
- stable target: <changed files/symbols and base/head when relevant>
- orchestration conformance: <final target-bound attestation ID and reconciliation result>
- accepted-plan conformance: <not triggered | plan/version + stable target + result + exceptions>
- selected lanes revisited: <lanes>
- diff matched lane instructions: yes/no, evidence=<files, symbols, probes>
- changed-boundary proof: <not triggered or applicable config/SQL/transaction/cleanup rows with evidence>
- coverage ledger: <reviewed, sampled, uninspected with reason>
- variance ledger: <none or route/lane/approach/proof changes>
- missing lane coverage corrected before next action: yes/no/not needed
- validation or proof selected: <command, artifact, or Pending Verification>
- docs/operator truth updated or not needed: <evidence>
- reviewer findings backpropagated to authoring lanes: <not needed/already covered and discipline corrected/lane patched with path>
- post-open reviewer rerun decision: <not applicable/skipped as simple bounded fix with evidence/rerun required because risk changed>
- Agent violation examples audit: <passed/corrected/Pending Verification with reason>
- next action allowed: yes/no, because <reason>
```

## Reference Lane Shape

When revising a code-authoring reference lane, keep it compact: mission,
boundaries, authoring sequence, prevention probes, validation, output
discipline, and only material edge cases. Do not add lane-local personas,
GitHub posting workflows, slash-command mechanics, memory caches, branch
mechanics, or final verdict law. Those belong to orchestration, PR workflow,
git readiness, or the read-only assessment gate.

## Lane Selection Algorithm

1. Confirm the target and changed-surface inventory from current local
   evidence.
2. Add the always-loaded authoring core for non-trivial code changes.
3. Add file-routed lanes from every changed surface in the lane map.
4. Add risk-routed lanes for auth, production data, SQL/data contracts,
   cross-store migration/cutover, generated contracts, public APIs, external
   integrations, LLM/AI calls, environment config/secrets, caches,
   concurrency, jobs, feature flags, CI workflows, observability,
   analytics/event tracking, docs/operator truth, accessibility/i18n,
   performance, test quality, instruction docs, or release readiness.
5. For broad, generated, AI-assisted, or mixed work, select more lanes up front
   but still load them just in time per code item.
6. Record selected lanes, skipped adjacent lanes, and rationale in the audit.
7. If the target or approach changes, recompute lanes before editing further.

## Lane Map

| Ask shape or risk surface                                                                                                                                                                                       | Lane                                                                                               |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Code task intake, lane selection, side-effect boundary, or visible code-lane audit                                                                                                                              | [references/change-intake.md](references/change-intake.md)                                         |
| Beginning non-trivial code work, target contract, context discipline, central failure, validation truth, production posture, or runtime truth before editing                                                    | [references/authoring-core.md](references/authoring-core.md)                                       |
| Non-trivial or risky implementation plan needs a bounded critic consultation, confidence rating, or skip rationale before editing                                                                               | [references/pre-code-critic-assignment.md](references/pre-code-critic-assignment.md)               |
| Unfamiliar symbols, broad impact, cross-stack changes, external/current/library facts, issue-derived implementation, or source-truth gaps before editing                                                        | [references/impact-and-source-map.md](references/impact-and-source-map.md)                         |
| Code edits, refactors, scripts, tests, workflows, config, dependencies, generated outputs, or implementation pattern choices                                                                                    | [references/implementation.md](references/implementation.md)                                       |
| Same-class local precedent, naming/ownership/test/validation fit, existing architecture pattern, or evidence-backed divergence from repo convention                                                             | [references/existing-conventions.md](references/existing-conventions.md)                           |
| Bug fixes, runtime symptoms, root-cause work, reproduction evidence, debug artifact cleanup, or regression proof                                                                                                | [references/debugging-and-repro.md](references/debugging-and-repro.md)                             |
| Go backend services, controllers, datasources, REST handlers, backend tests, context/error/logging behavior, or backend generated-code-aware edits                                                              | [references/backend-go.md](references/backend-go.md)                                               |
| Next.js, React, frontend routing, components, hooks, contexts, requesters, styling, browser-visible behavior, or frontend tests                                                                                 | [references/frontend-ui.md](references/frontend-ui.md)                                             |
| Keyboard/focus behavior, ARIA, semantic markup, forms, user copy, translation keys, locale-aware formatting, RTL/long-copy layout, or accessible browser proof                                                  | [references/accessibility-and-i18n.md](references/accessibility-and-i18n.md)                       |
| TypeScript props, hooks, contexts, request/response shapes, env declarations, state models, translation keys, or producer/consumer contracts                                                                    | [references/typescript-contracts.md](references/typescript-contracts.md)                           |
| Public/internal API contracts, REST handlers, requesters, Server Actions, webhooks, external providers, callbacks, status/error envelopes, pagination, or old/new client compatibility                          | [references/api-contracts-and-integrations.md](references/api-contracts-and-integrations.md)       |
| Overengineering, speculative abstractions, weak invariants, structured-data churn, or LLM coding footguns                                                                                                       | [references/engineering-judgment.md](references/engineering-judgment.md)                           |
| Behavior is known and needs a focused failing check, regression harness, or test-first loop                                                                                                                     | [references/tdd-regression.md](references/tdd-regression.md)                                       |
| Backend SQL, sqlc, mockery, generated Go code, domain mocks, or Postgres schema migrations must change together                                                                                                 | [references/backend-codegen.md](references/backend-codegen.md)                                     |
| SQL queries, schema migrations, generated data contracts, seed/fixture data, cache/event schemas, old/new deploy compatibility, or persistence contract movement                                                | [references/sql-migrations-and-data-contracts.md](references/sql-migrations-and-data-contracts.md) |
| Sanity CMS fetches, webhooks, GROQ, caches, Mongo-to-Sanity ID mapping, CMS-backed endpoints, or Sanity dataset mutation safety                                                                                 | [references/sanity-schema.md](references/sanity-schema.md)                                         |
| Cross-store data migration, source-of-truth moves, Mongo-to-Postgres domains, dual-read/dual-write, backfill parity, datasource cutover, reverse cutover, or legacy store decommission                          | [references/data-migration-and-cutover.md](references/data-migration-and-cutover.md)               |
| Runtime LLM/AI calls, prompt templates, model output parsing/validation, streaming handlers, token/cost budgets, AI-generated content rendering, retrieval pipelines, or prompt-injection trust boundaries      | [references/llm-and-ai-integration.md](references/llm-and-ai-integration.md)                       |
| Environment variables, `.env*` files, config keys/defaults/types, dataset/project targeting, connection strings, secret references, or local/CI/staging/production config parity                                | [references/environment-config-and-secrets.md](references/environment-config-and-secrets.md)       |
| Product analytics events, event properties, tracking calls, identity traits, consent-gated telemetry, experiment exposure events, or tracking-plan contract movement                                            | [references/analytics-and-event-tracking.md](references/analytics-and-event-tracking.md)           |
| Broad request, initiative, or large change needs reviewable vertical slices before code                                                                                                                         | [references/plan-to-slices.md](references/plan-to-slices.md)                                       |
| Architecture assessment, refactor boundary, ownership critique, locality, or seam design before implementation                                                                                                  | [references/architecture.md](references/architecture.md)                                           |
| ADR research packet or architecture decision evidence gathering before ADR authoring                                                                                                                            | [references/adr-research.md](references/adr-research.md)                                           |
| Behavior-preserving simplification, large-file pressure, unnecessary abstraction, or clarity/maintainability cleanup                                                                                            | [references/simplification.md](references/simplification.md)                                       |
| Duplicate logic, repeated guards, abstraction pressure, or drift-prone copy-paste                                                                                                                               | [references/duplication-and-abstraction.md](references/duplication-and-abstraction.md)             |
| Dependency upgrades, package manager changes, lockfiles, transitive risk, release notes, or dependency security scans                                                                                           | [references/dependencies-and-upgrades.md](references/dependencies-and-upgrades.md)                 |
| Developer tooling, repo scripts, mise tasks, local Docker compose, lint/format fixes, or validation command ergonomics                                                                                          | [references/dx-tooling.md](references/dx-tooling.md)                                               |
| GitHub Actions workflow YAML, CI path filters, matrices, caches, artifacts, permissions, runner settings, or CI runtime/cost optimization                                                                       | [references/ci-workflow-authoring.md](references/ci-workflow-authoring.md)                         |
| Feature flags, modes, environment toggles, staged rollout, experiments, kill switches, datasource switches, deployment gates, or conditional runtime behavior                                                   | [references/feature-flags-rollout.md](references/feature-flags-rollout.md)                         |
| Jobs, queues, schedulers, workers, Cloud Run jobs, cron, async processors, queue ack/nack, retries, resume, batch scripts, or run-state contracts                                                               | [references/jobs-queues-and-schedulers.md](references/jobs-queues-and-schedulers.md)               |
| Caches, invalidation, locks, leases, transactions, optimistic updates, race windows, idempotency keys, dedupe, read-after-write behavior, or stale-state consistency                                            | [references/concurrency-caching-consistency.md](references/concurrency-caching-consistency.md)     |
| SQL, migrations, imports, backfills, dry-run/apply jobs, bulk writes, generated queries, production-scale data, or operator safety gates                                                                        | [references/production-data-safety.md](references/production-data-safety.md)                       |
| Retries, timeouts, cancellation, partial failure, fallback values, best-effort paths, fail-open/fail-closed choices, broad catch blocks, or silent failure risk                                                 | [references/resilience-and-fallbacks.md](references/resilience-and-fallbacks.md)                   |
| Logs, metrics, traces, Sentry, alerts, dashboards, runbooks, deploy/rollback checks, operator evidence, or incident triage behavior                                                                             | [references/observability-and-operations.md](references/observability-and-operations.md)           |
| Performance, scale, query cost, memory, network or I/O fanout, bundle/runtime cost, or efficiency claims                                                                                                        | [references/efficiency-and-scale.md](references/efficiency-and-scale.md)                           |
| Auth, permissions, tenant scope, identity propagation, service accounts, admin/operator modes, gated UI, or protected resource access                                                                           | [references/auth-permissions-identity.md](references/auth-permissions-identity.md)                 |
| Secrets, sensitive logs, workflow permissions, suspicious network/file/system access, dependency trust, supply-chain risk, or broader trust-boundary changes                                                    | [references/security-and-trust-boundary.md](references/security-and-trust-boundary.md)             |
| Tests, fixtures, mocks, integration coverage, regression value, or brittle/private-helper tests                                                                                                                 | [references/test-quality.md](references/test-quality.md)                                           |
| Final-pass documentation truth after behavior is understood; comments, README, runbooks, PR text, CLI help, flags, logs, or operator-facing docs must match runtime behavior and help readers navigate the code | [references/docs-and-operator-truth.md](references/docs-and-operator-truth.md)                     |
| At most three repository-quality or code-health tasks feeding the current implementation workflow; durable backlogs, roadmaps, and cold-executor plans route to `improve`                                       | [references/quality-scout.md](references/quality-scout.md)                                         |
| Skills, agent role files, prompts, durable reviewer/authoring instructions, TOML role definitions, packet docs, mirrored runtime docs, or agent-policy examples                                                 | [references/instruction-skill-agent-authoring.md](references/instruction-skill-agent-authoring.md) |
| User-facing value delivery, release risk, runtime proof path, drift check, rollback path, or pre-handoff ship confidence                                                                                        | [references/value-and-release-readiness.md](references/value-and-release-readiness.md)             |
| Final-shape readiness, changed-file inventory, preventive domain probes, and token-bounded handoff preparation                                                                                                  | [references/authoring-preflight.md](references/authoring-preflight.md)                             |
| Author-owned reviewer-lens delta before independent dispatch; conditional database readiness and fresh-context isolation                                                                                        | [references/author-self-review.md](references/author-self-review.md)                               |

Cross-domain routing reminders:

- A public API change normally selects API contracts plus the producing and
  consuming implementation lanes, generated/type lanes, tests, and docs truth.
- Auth-sensitive behavior normally selects auth/permissions plus security,
  data/query, API/frontend/backend, tests, and logging/docs lanes as relevant.
- Conditional behavior normally selects feature-flags/rollout, tests,
  docs/operator truth, observability, and any domain lane affected by either
  branch.
- Async or production-affecting work normally selects jobs/queues,
  production-data safety, resilience, concurrency/cache, observability, tests,
  and CI/workflow/runtime config lanes.
- Instruction-document changes normally select instruction authoring plus docs
  truth and existing conventions; do not treat prose-only edits as harmless when
  future agents or operators will follow them as policy.
- Cross-store migration or datasource-cutover work normally selects data
  migration/cutover plus SQL/data contracts, production-data safety,
  feature-flags/rollout, jobs/queues, concurrency/cache, observability, and
  tests lanes; do not treat a backfill script as an ordinary job.
- Runtime AI-calling code normally selects LLM/AI integration plus API
  contracts, resilience, security/trust-boundary, and test-quality lanes; a
  prompt-template edit is a behavior change, not a docs change.
- Any new, renamed, or re-defaulted config key normally selects environment
  config/secrets plus CI workflow, security, and docs/operator truth lanes;
  check that no non-production environment can reach a production target
  through the default.
- Analytics event changes normally select analytics/event tracking plus the
  firing-path domain lane, security (PII in payloads), and docs lanes;
  renames are breaking changes for dashboard consumers who cannot see the
  diff.

## Mandatory Closeout Lanes

Before PR publication, "ready for review" or PR-ready handoff, remote push, or
handoff for any code change, run:

- `simplification`
- `docs-and-operator-truth`
- `authoring-preflight`

Treat these as authoring closeout lanes, not optional polish. Run
simplification first, then docs/operator truth, then authoring-preflight so
structure, runtime prose, and handoff proof are checked before the code leaves
the implementation phase. Use docs/operator truth as a final consistency pass
after the changed logic, callers/callees, config or runtime wiring, tests, and
operator path are understood, not as an early documentation-writing pass.

For a local-only micro-edit with no PR, push, ready claim, handoff, behavior,
config, migration, auth, API, data, CI, documentation-contract, or validation
claim, these closeout lanes may be skipped with a recorded reason. The moment
the work is handed off as ready, pushed, published, or reviewed as a PR-bound
branch, the closeout lanes are mandatory.

Add risk lanes whenever changed behavior triggers them. A small file count does
not make data, auth, production, migration, generated-contract, public API, CI,
or documentation-contract changes low risk.

After these closeout lanes, run `author-self-review` once when its admission
contract applies and before the first independently dispatched reviewer. A
material fix found there invalidates the affected authoring handoff or preflight
rows: rerun those rows first, then recompute the self-review delta. Do not use
this gate to delay or replace an independent reviewer.

## Gate Boundary

Keep code authoring independent from final read-only verdict gates. This skill
may reuse durable prevention patterns, but it must phrase them as
implementation guidance, validation obligations, and final-shape checks. Do not
pull verdict law, severity mapping, packet format, thread handling, or
gate-specific procedure into code authoring.

## Closeout

When this skill shaped the work, report:

- selected code lanes and skipped adjacent lanes
- changed files or surfaces
- validation commands and results
- remaining `Pending Verification`
- whether authoring-preflight ran and which preventive probes it covered
- whether author self-review was required, its delta disposition, and whether
  independent reviewer context isolation was proved
