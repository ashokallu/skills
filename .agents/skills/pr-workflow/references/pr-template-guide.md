<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (PR workflow publication ownership) -->

# PR Template Guide

Use this reviewer-facing shape when opening or updating a example-app PR:

```markdown
## Description

### What?

<Summarize the shipped behavior, files or subsystems touched, and explicit
out-of-scope items. Prefer bullets for multi-surface changes.>

Out of scope:

- <Behavior, rollout step, follow-up slice, environment action, or risk this PR
  deliberately does not own.>
- <Add more bullets for non-obvious exclusions.>

### Why?

<Explain the defect, rollout need, operational gap, or reviewer decision this
change addresses. Link the issue here when it explains the motivation. Do not
leave this implicit in the What section.>

## Reviewer guide

Review in this order to keep related concerns grouped:

1. **<Concern name>**
    - `<repo-relative/path>`
2. **<Concern name>**
    - `<repo-relative/path>`

The highest-value review points are <the safety, correctness, rollout,
operator, or UX questions reviewers should focus on>.

### Understanding guide

<Required for large, AI-authored, broad, generated, migration, operator-gated,
or multi-domain PRs. Explain what changed and why in reviewer-owned terms:
intent, changed contracts, evidence layers, fail-closed or fallback behavior,
intentional non-goals, data/runtime risk, and why the chosen shape is
maintainable. For small obvious PRs, write "Not needed - small contained
change.">

## Dependencies

<List prerequisite PRs, base-branch dependencies, deploy order, migration order,
or "None". Use PR links when applicable.>

## Risks and impact (What is the risk level of the changes and why?)

- [ ] Minimal
- [ ] Normal
- [ ] High

<Explain what can go wrong, blast radius, rollback/mitigation, and why the
selected risk box is appropriate.>

Rollback:

- <How to disable, avoid invoking, revert, or safely stop using the behavior.>
- <What operators should inspect before retrying if the change is a gate,
  migration, job, or runtime workflow.>

## Operator notes

<Include only when the PR changes infra, CI/release behavior, migrations, jobs,
rollout gates, Terraform, apply/destroy behavior, data backfills,
auth/permissions, or any workflow where an operator needs post-merge or
pre-apply instructions. Omit this section for ordinary app/backend/UI changes
when Risks, Rollback, and Verification already cover the reviewer need.>

- <What operators can safely do before and after merge.>
- <What must not be applied, invoked, enabled, retried, or treated as complete
  yet.>
- <Fallbacks, rollback, provider/UI-only checks, state files, run IDs, or gates
  that materially affect operation.>

## Verification

### Does this change the UI?

- [ ] Yes (if yes, provide screenshots/video)
- [ ] No

### How can the changes be tested and verified?

<List commands actually run and meaningful manual/runtime checks. If a relevant
check was not run, say `Pending Verification` and why.>

Pending Verification:

- <Important unrun check, rollout proof, external gate, or operator action and
  the evidence needed to clear it.>

Reviewer notes:

- <Optional non-blocking review context, known advisory, or invariant reviewers
  should keep in mind. Omit this subsection when there are no notes.>

---

**Link to Jira issue:**
<Markdown link, for example [DEMO-1234](https://jira.example.com/browse/DEMO-1234)>
```

Guidance:

- Before writing or editing any PR title or body, read the full relevant skill
  and this guide. This applies to updates on an already-open PR, not only the
  first publish. Do not draft PR text from memory, a chat summary, or a
  `.github` template alone.
- Do not use the root `pull_request_template.md` for our PRs. It is obsolete,
  lower quality than this guide, and must not be treated as an equivalent
  template source. If a GitHub workflow pre-populates it, replace it with this
  guide's structure before opening or updating the PR.
- Inspect the parent PR for stacked work and 1-2 recent similar PRs to match
  actual repo title style and tone.
- Keep PR titles short and conventional, such as `fix(workflows): ...` or
  `feat(docker): ...`.
- Make the title match the current shipped stage. Do not use a title that
  implies full ownership, rollout, migration, cleanup, or cutover when the PR
  only prepares the contract, adds a gate, enables one environment, or leaves a
  later cutover under `Pending Verification`.
- Do not include dependency noise in the title, such as `(depends on #4518)`;
  put stacking and dependency details in `## Dependencies`.
- Keep `What?` descriptive, but put the motivation in `Why?`; reviewers should
  not need to infer the reason from changed files.
- Put explicit `Out of scope:` bullets under `What?` for any likely reviewer
  assumption the PR does not own, such as rollout execution, materialization,
  UI activation, migration apply, validation gate changes, or follow-up slices.
  Omit the subsection only for tiny PRs with no meaningful exclusions.
- Keep `Why?` durable and current-state. It should explain the final defect,
  rollout need, operational gap, or reviewer decision addressed by the diff,
  not the chronology of debugging attempts, local workflow repairs, earlier bad
  assumptions, or transient CI investigations.
- `Why?` must let a reviewer understand the decision without asking the author
  to translate the diff. For any non-trivial PR, answer these questions in
  prose, not as vague labels: what concrete failure or missing capability
  opened the PR, which current code/config contract caused or failed to prevent
  it, what user/operator/system impact follows if it is left alone, and why the
  chosen ownership boundary or fix shape is the right one. If those answers are
  not known, write `Pending Verification` with the evidence needed instead of a
  generic motivation paragraph.
- Do not make `Why?` merely repeat `What?`. A sentence like "fixes drift",
  "updates config", "adds a gate", or "supports migration" is insufficient
  unless it also explains the failure mode, impact, and reasoning that make the
  change necessary.
- Include root-cause or incident detail in `Why?` only when that detail is the
  actual behavior the PR fixes and helps reviewers judge the final patch. Put
  run IDs, measurements, and proof in `Verification` or the `Understanding
  guide`; omit process history that does not change reviewer judgment.
- If the PR was opened because of a concrete operational artifact, include
  that artifact in `Why?`: Terraform run, release, incident, alert, log query,
  database query, support report, failed CI run, or reviewer finding. Name the
  exact dangerous plan/action that must not proceed, the relevant counts or
  before/after values, and the cascade that makes it risky. If the artifact is
  private or not linkable, cite the safe public/private reference available to
  reviewers and summarize the evidence without leaking secrets.
- For infra, Terraform, migration, release, or production-data PRs, `Why?`
  must say whether the current triggering operation should be discarded,
  retried, blocked, or allowed after merge. Mirror that same boundary in
  `Operator notes` and list the post-merge proof required before apply,
  deployment, job execution, or production action.
- When the PR changes classifications, severities, statuses, exceptions,
  config contract shape, or operator gates, define each value that matters and
  state the runtime behavior it causes. Reviewers should be able to tell which
  states block, which states are evidence-only, why that split is intentional,
  and what data or prior rollout evidence supports it.
- When the PR is motivated by analysis, rollout evidence, production or
  Staging behavior, performance, resource usage, data volume, or operational
  risk, include the strongest real numbers available in the PR body. Prefer
  concrete counts, rates, durations, sizes, p95 or max values, run IDs, release
  versions, and before/after measurements over qualitative phrases like
  "large", "healthy", "slow", or "low impact". If exact values are unavailable,
  say `Pending Verification` and name the missing measurement rather than
  weakening the evidence.
- For follow-up PRs, stacked PRs, and repair PRs, link the source or parent PR
  that introduced the behavior being changed in `Why?` or `Dependencies`.
  Mention the relationship even when the base branch is already obvious from
  GitHub metadata, because reviewers often read PR bodies outside the stack
  view.
- Add a `Reviewer guide` immediately after `Why?` for non-trivial PRs. Group
  files by review concern rather than dumping the full changed-file list.
- For large, AI-authored, broad, generated, migration, operator-gated, or
  multi-domain PRs, add a `### Understanding guide` under `## Reviewer guide`.
  Tests passing is not a substitute for reviewer understanding. The guide must
  make the human reviewer able to explain:
  - intent: why the change exists and which user, operator, rollout, or
    maintenance outcome it serves
  - changed contracts: public API, data shape, generated surface, workflow,
    runtime mode, permission boundary, or operator evidence that changed
  - evidence and safety gates: what proof is required, which conditions fail
    closed, which fallbacks are intentional, and which state must match before
    a risky action proceeds
  - intentional non-goals: behavior, files, flows, risks, or follow-up work this
    PR deliberately does not own
  - data/runtime risk: production data, migration, cache, job, auth, deploy,
    rollback, performance, or observability consequences reviewers must reason
    about
  - maintainability: why this implementation shape should be understandable and
    supportable after merge, including source-of-truth and generated-artifact
    pairing when relevant
- If a broad or AI-authored PR cannot provide that understanding from current
  evidence, write `Pending Verification` in the `Understanding guide` and name
  the missing owner, artifact, or measurement. Do not replace missing
  understanding with only test commands, CI status, or a changed-file list.
- Follow this structure exactly instead of replacing it with a freeform body.
- Call out intentional exclusions so reviewers know which follow-up PR owns
  omitted behavior.
- Keep dependencies concrete: name stacked PRs, schema prerequisites, rollout
  order, and whether the PR can land independently.
- In risk sections for migration, apply, release, infrastructure, feature-flag,
  or operator-gated changes, include a short `Rollback:` subsection with the
  exact safe path: disable, do not invoke, revert, inspect failed run state, or
  retry only with fresh evidence. Do not leave rollback implicit in prose.
- For large-blast-radius infrastructure, release, Terraform, migration, auth,
  or production-data PRs, explicitly name what can go wrong, who or what is
  blocked if the gate fails, the rollout order, stop conditions, and any
  temporary mode split. If the PR intentionally avoids blocking unrelated team
  work through a feature or environment gate, say that plainly and list the
  residual risk while the gate is disabled elsewhere.
- Add `## Operator notes` when the PR changes infra, CI/release behavior,
  migrations, jobs, rollout gates, Terraform, apply/destroy behavior, data
  backfills, auth/permissions, or another workflow where a human operator needs
  post-merge, pre-apply, retry, fallback, or "do not run this yet" guidance.
  Use the pattern from PRs such as #4490 and #4684: exact safe actions,
  intentional non-actions, fallback/rollback path, provider or UI-only evidence
  boundaries, state or run evidence required, and gates that must pass before
  the next operation. Omit the section for ordinary changes where Risks,
  Rollback, and Verification already answer the operator question.
- Verification should distinguish local commands actually run,
  runtime/operator evidence, and important unrun checks. Use
  `Pending Verification` for important unrun checks.
- Local validation is not a substitute for external proof. When the PR's core
  safety claim depends on Terraform Cloud, provider state, staging or
  production runtime behavior, database metadata, deployed revisions, release
  workflow state, or another external system, put that exact artifact under
  `Pending Verification` until it has been inspected. Do not let a passing
  local command or green GitHub check imply that external proof exists.
- Put important unrun checks under a visible `Pending Verification:` subsection
  inside `Verification`, not buried in prose. Each bullet should name the
  missing action and the evidence that would clear it.
- Use `Reviewer notes:` only for non-blocking advisories or invariants that
  help reviewers judge the diff. Do not use it for process labels, internal
  reviewer verdicts, routine CI inventories, or unresolved blocking work.
- Do not add a routine `GitHub CI` section, green-check inventory, or copied
  check-run list to the PR body. The GitHub UI owns normal current-head CI
  status. Mention CI in the PR body only when the check is not visible in the
  standard UI, an external required gate needs explanation, or a queued/failed
  gate is a material reviewer decision; then keep the wording current and
  remove it once it becomes stale.
- For backend PRs, include the workflow-pinned local backend linter command in
  local validation when it was run. Do not collapse backend proof into
  "go tests passed" when the PR will trigger `Backend - Validate`; reviewers
  need to see lint, generated-code, build, and test coverage separately or see
  each missing gate under `Pending Verification`.
- After a squash, amend, rebase, or force-push, previous workflow runs are
  historical unless tied to the new head SHA or an explicitly proven
  tree-equivalent rewrite. Refresh CI wording and head references before
  updating the body or signing off.
- After a review-comment fix or Copilot-thread fix changes code, refresh the
  PR body's verification and reviewer guide from the new diff before handoff.
  A body that names old checks, omits the fix validation, or still says CI is
  pending after it has completed is stale reviewer evidence.
- After a metadata-only PR body edit, re-read the live body and current-head
  CI again before handoff. Metadata edits can trigger lightweight checks, and a
  body edit can itself introduce stale reviewer evidence.
- Keep the body in sync with the diff. Derive the `What?` and `Reviewer guide`
  file list and the `Verification` scope from the current changed-file set, and
  re-check them after any push that changes the commit range so no stale file
  list or validation claim survives.
- When different checks cover different file types, say which check ran on which
  surface instead of implying one command covered the whole change.
- Strict portable-command gate: PR bodies must contain commands another
  reviewer can run on a normal checkout. Use repo-relative paths and standard
  project commands only. Never put absolute machine paths, local tool install
  paths, shim bypasses, shell-specific setup, or one-agent environment
  workarounds in the PR body.
- Validation notes must describe the behavior or surface validated, not the
  internal review event that caused the command to run. Do not write phrases
  such as "after the reviewer fix", "after the Copilot fix", or "focused
  validation after the timeout fix". Say which command or scenario was
  validated and why it matters to the final diff.
- Never mention a local working branch, local filesystem paths, disposable
  worktree names, gitignored files, or `tmp/` artifacts in PR bodies.
- Never mention local worktree/tooling repair details in PR bodies, including
  Husky bootstrap or repair, nvm/mise prefix workarounds, branch-local setup
  issues, fresh-worktree setup failures, or local fixes such as replacing a
  shimmed command with an absolute binary path.
- Never mention internal agent review tools, subagent names, local review
  passes, Copilot/council/Luna process labels, or their verdicts in PR
  bodies. If a reviewer-facing decision matters, describe the resulting source
  behavior, risk, dependency, or validation evidence instead.
- Before publishing or updating the body, scan the draft for local and process
  leakage. Remove or rewrite matches for `/home/`, `/Users/`, `.local/share`,
  `mise/installs`, `tmp/worktrees`, absolute binary paths, local branch names,
  `Copilot`, `council`, `Luna`, transient "focused validation after ..."
  wording, stale `GitHub CI` sections, stale head SHA claims, and raw commit
  IDs unless the user explicitly asked the PR body to discuss a commit.
- Render Jira references as Markdown links every time they appear in the PR
  body, including inline motivation text and the footer. Use
  `[DEMO-1234](https://jira.example.com/browse/DEMO-1234)`, not plain
  `DEMO-1234` and not a bare Jira URL.
- Keep the footer label exactly `**Link to Jira issue:**` when the linked
  tracker is Jira. Do not rename it to `Github issue`, `GitHub issue`, or a
  generic issue label for Jira-backed work.
- Before drafting a new PR body, verify the intended Jira key. If no key is
  known, pause PR publication and ask whether the user has a Jira issue or wants
  one created for the PR. Do not treat a later PR-body Jira link as equivalent
  to a branch that already contains the Jira key.
- Do not use em dashes in PR titles, PR bodies, issue comments, or review
  replies. Use regular hyphens or rephrase.
