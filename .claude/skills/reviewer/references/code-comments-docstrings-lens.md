<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-17 -->

# Code Comments And Docstrings Lens

Use this lens when the diff adds, removes, or changes inline code comments,
docstrings, TODOs, or examples embedded near code that describe invariants,
side effects, retries, error handling, performance, security, rollout,
generated-source ownership, or operator behavior.

The goal is not to reward more comments. The goal is to prevent comments from
becoming a false contract that future maintainers, reviewers, operators, or
agents will trust over the code.

## Review Order

1. Identify the code path, symbol, option, branch, or generated artifact the
   comment claims to describe.
2. Compare the claim against current source, callers, tests, generated output,
   config, and runtime behavior when cheaply inspectable.
3. Classify the comment as accurate, incomplete but harmless, misleading,
   stale, redundant, or missing where the code relies on non-obvious context.
4. Emit a finding only when the comment can steer a future change, review,
   rollout, incident response, security decision, or operator action the wrong
   way.

## High-Risk Comment Claims

Treat these comment changes as review surfaces, not prose polish:

- comments that describe why a guard, fallback, retry, timeout, lock, cache,
  feature flag, or validation exists
- option, config, and feature-flag comments that must distinguish between
  "sets prerequisite data", "pins a run/config value", and "enables behavior".
  A run ID or config value is not an enable flag unless the code treats it as
  one.
- comments that claim a path is safe, bounded, idempotent, temporary,
  generated, unreachable, test-only, staging-only, or production-ready
- TODOs that imply follow-up work already has an owner, ticket, guardrail, or
  safe deadline when the repo does not prove it
- docstrings or examples that describe accepted inputs, rejected inputs,
  auth/tenant behavior, response shape, pagination, ordering, errors, or
  side effects
- comments around generated files or source-of-truth pairs that can cause
  future agents to edit the wrong surface
- comments that explain an invariant but the implementation does not enforce it

## Comment Rot And Removal

Flag changed comments when:

- the comment contradicts the branch condition, default value, caller contract,
  generated type, SQL shape, config key, or test behavior at the reviewed head
- the comment uses the wrong domain noun for the current code path, such as a
  container, version alias, source row, mirror, aggregate, or report term that
  no longer matches the branch being classified
- the comment hides a required error path, partial failure, fallback, or
  mutation side effect
- the code changed but the comment still names the old runtime, flag, command,
  route, table, field, or operational behavior
- the comment was removed from code whose safety depends on non-obvious
  ordering, locking, transaction, retry, compatibility, or generated-source
  constraints

Do not ask for comments that merely restate obvious code. Prefer removal over
rewrite when the comment adds no durable context and increases drift risk.

## Output Discipline

- Formal findings require a concrete false or missing contract and a realistic
  future defect path.
- Advisory comments are appropriate when a line-local comment can prevent a
  likely misunderstanding but does not affect current shipped behavior.
- Drop grammar, spelling, and style-only comments unless they materially change
  the runtime claim.
