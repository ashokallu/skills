<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Engineering Judgment

Use this lane when the main risk is overengineering, speculative abstractions,
weak invariants, structured-data churn, or avoidable LLM coding mistakes.

## Mission

Keep the change as small as the requirement, as reversible as the uncertainty,
and free of the failure patterns that agents produce fluently: invented APIs,
speculative flexibility, validation that cannot fail, and confident claims
without evidence.

## Rules

- Surface meaningful assumptions before coding. If a safe default exists, state
  it and proceed.
- Prefer the minimum code that solves the requested behavior. No speculative
  flexibility, no single-use abstraction, no optionality for required data.
- Touch only what the task requires. Clean up only artifacts introduced by the
  current change.
- Challenge plans that make the least-reversible decision before proving the
  central premise.
- Ask which acceptance criterion could pass while the real user, operator, or
  data outcome still fails. Fix that gap before implementation.
- Security and performance claims require proof. Security needs a reachable
  path and calibrated impact. Performance needs a baseline, hot path, and
  before/after or query-plan evidence.
- Prefer strengthening an invariant over adding a defensive check for a state
  that should be impossible; if the impossible state is reachable, that is
  the bug to fix.
- When two designs are close, choose the one that is easier to delete.

## LLM Coding Footguns

Actively check the change for these agent-typical failures before calling it
done:

- APIs, options, flags, file paths, commands, or config keys that were
  plausible rather than verified against the repo or the pinned dependency
  version.
- Error handling added around code that cannot throw, or validation that
  accepts every input it claims to validate.
- Behavior silently dropped during a refactor because it looked like
  boilerplate (cleanup calls, cache invalidation, early returns, logging).
- Comments and docs that overclaim ("fully tested", "backwards compatible")
  beyond what the diff and validation actually prove.
- Generic abstractions imported from training priors that bypass the repo's
  existing pattern for the same problem.
- Duplicated logic created because the existing owner of the behavior was not
  searched for before writing a new one.

## Pre-Code Critique

For non-trivial changes, quickly identify:

- the least reversible decision
- maximum blast radius across users, data, production, policy, workflow, and
  future precedent
- load-bearing claims that must be verified before code
- the smaller reversible slice, if one preserves most value

If a central premise is `Pending Verification` for safety, correctness,
privacy, data integrity, production readiness, or user decision making, block
or revise the plan before coding.

## Output Discipline

When this lane changes the plan, record what was cut, deferred, or simplified
and why. When it approves the plan, record the least-reversible decision and
the evidence that its premise held. Do not present intuition-level risk
rankings as measured fact.
