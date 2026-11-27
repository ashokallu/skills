<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-15 -->

# Workflow Calibration

Use this lane when the task is to see how multiple harnesses currently choose
repo workflows, compare that behavior against expected routing, and optionally
let weak lanes repair the durable instructions that should guide their future
runs.

This lane is a calibration and repair loop. It is not the normal execution path
for the underlying task being used as the prompt. For example, a Sentry issue
planning prompt can be a useful calibration input, but this lane does not make
Sentry planning a cross-harness requirement for future production-error work.

## Core Rule

The parent harness owns the experiment. Harness outputs are observations,
proposals, or patches, not proof. Keep the first pass read-only, pin the repo
state, and consolidate only generic instruction improvements that would help
future tasks beyond the calibration prompt.

Use the existing lanes instead of duplicating them:

- use `direct-collaboration.md` for wrapper commands, model/reasoning flags,
  fresh aliases, timeout handling, metadata checks, and failed-output triage;
- use `council-planning.md` for isolated worktrees, manifests, artifact
  contracts, consolidation rules, and cleanup discipline;
- use `prompt-templates.md` only when a reusable prompt block or failed prompt
  contract needs repair.

## Calibration Loop

1. Pin the baseline.
   - Record the branch, commit, changed instruction files, and harness set.
   - Decide whether the prompt tests routing, planning quality, wrapper
     availability, low-reasoning behavior, or instruction repair.
   - Keep the prompt natural. Do not tell the harness it is being graded unless
     the purpose is explicit self-repair.
2. Run the current-state smoke.
   - Use fresh sessions or aliases unless the user explicitly asks for session
     reuse.
   - Use the requested model and reasoning level, and record wrapper metadata
     rather than trusting the model's self-description.
   - From disposable worktrees, trust the exact worktree `.mise.toml` when
     present and pass absolute prompt, context, and output paths to wrappers.
   - Keep the first pass read-only. Do not create repair worktrees, edit
     files, fetch private remote state, or run live external workflows unless
     the prompt itself asks for that side effect.
3. Capture evidence.
   - Store outputs, wrapper diagnostics, command lines, cwd, branch, model,
     reasoning, session alias, and exit status under a repo-local `tmp/`
     folder.
   - Treat empty output, timeout, bad metadata, contaminated write scope, or a
     wrapper failure as a harness-run failure, not as a workflow-quality answer.
4. Score behavior against expected repo routing.
   - Check whether the harness selected the repo-owned skill or lane before a
     plugin or global skill when repo routing should own the workflow.
   - Check whether multi-step work included a todo or planning ledger with
     workflow-lane or specialist-skill mapping before execution.
   - Check whether the answer used current repo facts, named conditional steps
     as conditional, avoided cargo-cult "always do this" rules, and separated
     evidence gathering from implementation, validation, publication, and
     handoff.
   - Mark missing or unverified current facts as `Pending Verification`; do not
     reward plausible invention.
5. Decide whether self-repair is warranted.
   - Skip self-repair when gaps are wrapper failures, missing auth,
     unavailable models, unsupported reasoning knobs, or one-off prompt
     ambiguity.
   - Retry wrapper mechanics before blaming instructions: untrusted mise files,
     relative prompt paths from a child cwd, budget caps, turn limits, auth
     transport failures, and missing write-permission flags are run setup
     issues until retried correctly.
   - Use self-repair when a harness consistently misses a repo-owned route,
     forgets phase-boundary re-entry, ignores todo lane mapping, treats a
     plugin skill as the workflow owner, or needs instruction text to prevent a
     repeat failure.
6. Isolate repair work.
   - Create one repair worktree per repairing harness from the same pinned
     base.
   - If a harness cannot write inside its own repair worktree, try the
     harness-specific bypass or permission mode in that same worktree before
     any parent-branch fallback. For headless Codex repair/edit lanes, use
     `--dangerously-bypass-approvals-and-sandbox` only inside the disposable
     worktree with narrow allowed edits.
   - Give each harness only its own smoke output, the expected behavior, and
     the repo files it may edit.
   - Ask for generic instruction improvements in the harness's own words.
     Forbid prompt-specific cargo-cult rules and broad rewrites of unrelated
     guidance.
7. Consolidate in the parent branch.
   - Inspect each repair diff directly.
   - Keep portable improvements, preserve runtime adapters, and reject
     wholesale replacements that drop existing guardrails.
   - Reapply selected edits manually or with a narrow patch into the canonical
     branch and mirrors. Do not merge proposal branches just because a harness
     produced a plausible patch.
8. Validate and rerun only what proves the repair.
   - Run markdown and whitespace checks for changed instruction files.
   - Run targeted Waza evals when skill routing or trigger language changed.
   - Rerun the same smoke only when the changed instructions should materially
     affect the next answer; otherwise record the repair as instruction-only
     with `Pending Verification` for live behavior.
9. Clean up.
   - Remove disposable worktrees, scratch branches, stale output folders, and
     temporary artifacts unless the user asked to keep them.
   - Remove ignored Waza result folders created solely for calibration after
     recording pass/fail evidence, unless the user asked to retain artifacts.
   - Commit and push only after the parent branch contains the selected
     generic improvements and validation evidence.

## Expected Scoring Notes

Prefer compact scoring over long prose. A useful table usually includes:

| Harness | Route chosen | Todo lane mapping | Current evidence | Conditionality | Major gap | Self-repair |
| --- | --- | --- | --- | --- | --- | --- |
| `<name>` | pass/fail | pass/fail | pass/fail | pass/fail | `<gap>` | yes/no |

Treat `pass` as evidence-backed. If the answer is good but omitted proof that
it read the relevant repo-owned skill, mark the route `partial`, not `pass`.

## Repair Prompt Shape

For self-repair prompts, include:

- the pinned base branch and worktree path;
- the harness's own first-pass output;
- the expected durable behavior in generic terms;
- the files or skill trees it may edit;
- the validation commands it should run;
- a requirement to preserve existing guardrails and avoid incident-specific
  rules.

Do not ask a repairing harness to evaluate every mirror unless mirror work is
part of its scope. The parent owns final mirror consistency.

## Closeout

Close with:

- harnesses tested and model/reasoning metadata, or `Pending Verification`;
- artifacts captured under `tmp/`, if kept;
- scoring summary and which gaps were instruction-worthy;
- repair worktrees created, consolidated, and removed;
- instruction files changed and validation commands run;
- remaining live-behavior `Pending Verification`.
