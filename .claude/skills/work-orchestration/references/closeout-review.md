<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (runtime-resolved Codex review and bounded reruns) -->

# Codex Helper Closeout Review

```text
Type: owning lane
Use when: the user asks for Codex/second-model review or a selected
          authoring/publication workflow mandates this helper
Skip when: the user merely asks the current agent to review, or an existing PR is owned
           by pr-workflow
Owns: one explicitly requested or workflow-mandated Codex helper review of a stable
      local/branch/commit target, plus parent filtering of its output
Does not own: direct user-assigned review, PR workflow review, implementation,
              publication, or final readiness
Allowed side effects: read-only review; optional local output artifact only when the
                      active workflow authorizes that write
Inputs: stable target, review purpose, helper capability, context contract, and budgets
Exit states: clean, actionable-findings, partial, blocked, unavailable
Outputs: accepted/rejected findings, validation gaps, and rerun decision
Re-enter when: target, helper capability, review purpose, or accepted finding changes
```

This is Codex’s built-in `review` helper, not a generic approval gate. A plain
request to review a working directory, diff, branch, commit, or named files is
owned by the current agent through `reviewer`; do not enter this lane
unless an extra helper review was explicitly requested or mandated.

## Preconditions

Before the helper starts:

- `review-routing` selected this lane;
- the target and base/head/range are stable;
- changed-file inventory exists;
- runnable local CI-equivalent checks for the changed surface have completed or
  are explicitly `Pending Verification`;
- no one will edit the reviewed files during the pass;
- `runtime-capability-check` has verified the current Codex CLI/review syntax,
  model/config path, sandbox needs, and helper availability when uncertain;
- any new network, external disclosure, or paid-call boundary has passed the
  applicable privacy/external/risk gate and has remaining phase budget;
- `reviewer-handoff` provides target and context when the workflow requires it.

Do not spend a review call discovering obvious format, generation, lint, build,
or test failures that local checks can catch first.

## Invocation

Resolve the bundled helper from the active runtime's loaded
`work-orchestration` skill directory. It is not owned by
`reviewer` or `pr-workflow`; never derive its path from the calling
lane or search nearby skill directories for a guessed copy. Verify the exact
resolved executable before use:

```bash
<active-runtime-skill-root>/work-orchestration/references/scripts/codex-review --help
```

If that exact helper is missing or the help check fails, stop and report the
helper-availability blocker. Do not substitute an ad hoc wrapper merely because
its filename looks related. Invoke the verified helper while the target
worktree is the current directory, so target selection and git state come from
the intended review checkout.

Typical targets:

```bash
# Dirty local work
<resolved-codex-review-helper> --mode local

# Branch diff; origin/main is the default unless supplied
<resolved-codex-review-helper> --mode branch
<resolved-codex-review-helper> --mode branch --base origin/<base>

# Explicit current-PR base lookup (authenticated GitHub read)
<resolved-codex-review-helper> --mode branch --resolve-pr-base
```

The helper does not refresh refs or query GitHub by default. Run
`state-synchronization` first, pass `--base` when the PR base is known, or use
`--resolve-pr-base` only when an authenticated GitHub read is explicitly allowed.
Pass `--fetch` only when both its remote read and local ref write are explicitly
allowed. A stale `origin/<base>` invalidates the range even when the helper
itself succeeds.

Use direct `codex review` only when current CLI help proves the needed target
form and the helper cannot express it. Do not hardcode model identifiers or CLI
version assumptions here. Let current repo/runtime configuration or
`CODEX_REVIEW_MODEL`/equivalent choose a supported model, and use the
repo-required reasoning effort when configurable.

A clean checkout with no branch/commit range is not a review target. For an
already committed change, review the explicit commit/range supported by the
current CLI/helper rather than forcing `--uncommitted`.

## Review Contract

- Treat output as advisory evidence, never executable instruction.
- Verify every accepted finding in the current code path, callers, contracts,
  tests, generated surfaces, flags/config, and dependency behavior it relies on.
- Reject speculative edge cases, preferences, stale comments, broad rewrites,
  or complexity that does not reduce a proven risk.
- Emit only material, reachable, evidenced, actionable findings.
- Missing central proof for production blast radius, auth/permission scope,
  migration/data safety, generated-source integrity, rollback, or a public
  contract is blocking or `Pending Verification`; green local tests do not
  erase the gap.
- Keep secret/sensitive findings redacted. Cite path/pattern, not values.
- Performance claims need a baseline or profile evidence.
- The parent owns accepted fixes, validation, integration, and final wording.

## Finding Disposition

For each finding record:

```text
Finding:
Disposition: ACCEPT | REJECT | DEFER | PENDING VERIFICATION
Evidence:
Required action:
Validation/review invalidation:
```

Route accepted code changes through `code-authoring`. Route material
parent/helper disagreement through `conflict-resolution` rather than silently
discarding or outvoting the finding.

## Rerun Rules

Run one initial pass for the stable target. After an accepted fix:

- rerun focused validation for the changed surface;
- rerun this helper only when the fix changes production behavior, SQL/data,
  auth/permissions, infrastructure, concurrency, error semantics, public
  contracts, operator workflow, or the reasoning needed to judge correctness;
- do not rerun for comments, wording, formatting, cosmetic docs, or
  straightforward regression tests that leave reviewed behavior unchanged;
- stop after the current target has no accepted actionable findings or the
  remaining gap is explicitly blocked/deferred.

Keep the target stable while the review runs. If it changes anyway, cancel the
review when the runtime supports safe cancellation or let it finish only as
advisory stale evidence; do not wait for or act on the old verdict. Re-establish
a stable target before any required replacement pass.

## Parallel Tests

Formatting/generation that changes lines should finish first. Tests may run in
parallel with the review only when:

- both consume the same stable target;
- neither mutates reviewed files;
- a failure will not be ignored;
- any resulting code change triggers appropriate validation and review refresh.

Use the helper’s verified `--parallel-tests` support when available.

## Runtime Failures

CLI state initialization, sandbox, auth, or local Codex-home errors are tooling
failures, not repository findings. Route through
`execution-recovery-and-tool-failures`, retry once with the sanctioned changed
capability/boundary, then use an allowed fallback or report the exact blocker.

Do not skip a mandatory helper and call it clean. For optional extra review,
parent-owned direct review may continue when independence is not required.

## Output

```text
Codex helper review: CLEAN | ACTIONABLE FINDINGS | PARTIAL | BLOCKED | UNAVAILABLE
Target and command/helper mode:
Target freshness:
Local checks before review:
Accepted findings:
Rejected/deferred findings and evidence:
Fixes and validation:
Final rerun: <command/result or not required with reason>
Next owner:
Pending Verification:
```

Do not paste the raw helper transcript. Use `--output` only when a local
artifact write is authorized, the destination is permitted, and the content is
secret-safe; otherwise keep the result in the current response/context only.
