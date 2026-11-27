<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-24 (critical shared mutation autonomy boundary) -->

# Execution Recovery And Tool Failures

```text
Type: decision gate
Use when: an attempted action fails or leaves uncertain partial state
Skip when: the failure is expected domain behavior already owned by diagnosis
Owns: classification and bounded recovery decision after command, tool, auth, sandbox,
      wrapper, partial-execution, or availability failure
Does not own: product diagnosis or repeated blind retries
Allowed side effects: read-only inspection; any retry returns to the owning execution
                      lane under an explicit changed-variable contract
Inputs: attempted action, exact target, output/error, possible side effects, authority,
        and prior attempts
Exit states: recovered, rerouted, partial state contained, blocked
Outputs: failure class, state impact, next safe attempt/owner, and stop condition
Re-enter when: recovery changes state or another attempt fails
```

Use this lane when commands fail, tools are unavailable, credentials are
missing, sidecars cannot start, validation is flaky, repo state is unexpectedly
dirty, a workflow was interrupted, or earlier steps completed only partially.

This lane prevents retry loops and false completion claims. It does not replace
`diagnose`, `validation`, `repository-editing`, `delegation`, or specialist
workflows; it decides how to recover and which owner should take over.

## Use For

- command failures with unclear cause
- missing tools, wrappers, MCPs, credentials, sidecar capacity, Docker, local
  services, or env files
- malformed, empty, stale, or missing subagent/Luna/reviewer output
- partial execution after a crash, timeout, interrupted workflow, or failed gate
- dirty worktree surprises, stale PR/branch state, or failed remote mutations
- the first failure and the decision whether one bounded changed-variable retry
  is safe

## Do Not Use For

- capability uncertainty before any attempt when the planned route depends on
  a named load-bearing capability that remains unresolved after current runtime
  inventory and repo configuration are checked; use `runtime-capability-check`
- user-initiated stop, cancel, undo, or reversal of agent work; use
  `abort-and-unwind` (this lane owns failure-initiated recovery)
- normal product debugging after the failure locus is known; use `diagnose`
- setup failures before product code runs; use `environment-tooling`
- work that has already produced two materially identical failures without new
  narrowing evidence; use `loop-control-and-escalation`
- final completion wording; use `completion-claim-gate`
- replacing required specialist gates with a weaker local check

## Failure Classification

Classify before retrying or changing code:

- **Command misuse:** wrong directory, wrong package, missing env, interactive
  prompt, pager, shell quoting issue, stale generated files, unsupported flag.
- **Environment-local:** missing dependency, Docker unavailable, local port in
  use, credential absent, service not running, local database state mismatch.
- **Tooling/platform:** API rate limit, MCP/tool outage, subagent/session cap,
  wrapper unavailable, CI provider issue.
- **Product failure:** code behavior, test expectation, build regression,
  runtime exception, contract mismatch.
- **Flake/timing:** nondeterministic test, network hiccup, queued CI,
  eventual consistency, transient container startup.
- **Permission/scope:** insufficient auth, wrong project/account, branch
  protection, missing approval, read/write boundary mismatch.
- **Stale state:** branch/head/PR/environment changed since evidence was
  gathered.

Do not edit product code for an environment-local, command-misuse, permission,
or stale-state failure until a product failure is proven or a safe hypothesis
requires a code change.

## Retry Policy

A retry is useful only when something changed. This gate authorizes or rejects
the retry; the owning execution lane performs it under the original or newly
authorized side-effect boundary:

- command corrected, directory fixed, env loaded, service started, dependency
  installed, or timeout adjusted according to repo guidance
- scope narrowed to a focused failing package/test/check
- external transient wait has a stop condition
- stale target refreshed
- delegated output defect is named in the retry prompt

Before authorizing the one bounded retry, record every field below. An empty
changed variable or falsifier rejects the retry; narration such as “try again”
or a different command spelling is not a material change.

```text
Retry decision record:
- failure class and exact locus:
- partial state and target freshness:
- changed variable:
- falsifier / why this change should distinguish the hypothesis:
- evidence invalidated by the failure or recovery:
- retained, cleaned, or quarantined artifacts:
- retry owner:
- stop condition:
- remaining retry budget: 1 | 0
```

The initial failed attempt may receive at most one retry with this complete
changed-variable record. If that retry produces a materially identical failure,
route to `loop-control-and-escalation` immediately with the two attempt records
and set the remaining retry budget to `0`. Further variants stay blocked until
new diagnosis or implementation evidence changes the hypothesis. Do not create
a persistent retry service, journal, or runtime dependency to track this state.

## Same-Envelope Recovery

When an approved critical-mutation autonomy envelope is active, recovery stays
on the same version only when its exact action class and capability row were
present before the approval hold. Read back the critical target and first
attempt's effect, require known safely reconcilable partial state, then permit
at most one changed-variable retry. The retry must preserve the exact
environment, principal, resources, action semantics, credentials, tools,
network/cost effects, ceilings, rollback boundary, and terminal proof already
confirmed. It must be idempotent under the observed state or use the
predeclared recovery action to reconcile that state.

Append recovery evidence without editing authority-bearing envelope fields.
Rerun every readiness, specialist, validation, monitoring, or proof gate
invalidated by the recovery before a completion claim.

A new critical target, resource, principal, action semantic, environment,
credential, tool, network/cost effect, ceiling, rollback burden, second
failure, or unknown partial external state is not recovery. Stop before action
and return to the parent for a new envelope version or `BLOCKED`
reconciliation. A derived count or summary correction is a presentation
erratum, not recovery, only when the authoritative enumerated set is unchanged
and unambiguous.

Ordinary Git hook, executable-mode, restaging, invocation, or in-scope content
recovery does not use this envelope path. Route it through
`worktree-readiness`, preserve hooks and the user's action-specific Git
authority, reread local/remote state as applicable, and rerun invalidated
validation or review. If that Git or CI action predictably triggers a critical
shared mutation, stop before it and use the critical-mutation envelope instead.

## Partial Execution Recovery

When prior work is partial:

1. Snapshot current state: route ledger, worktree status, branch/head, dirty
   files, commands run, external IDs touched, sidecars launched, blockers.
2. Separate completed evidence from unverified assumptions.
3. Identify the earliest unsafe or stale step.
4. Re-emit the Classification receipt for the next action only.
5. Continue with independent safe work or stop with `Pending Verification` if
   the missing gate owns completion.

Never claim a whole ordered workflow is done because later steps succeeded.
Every requested gate must have evidence or an explicit gap.

## Tool Unavailable

When a required tool, wrapper, MCP, subagent, or credential is unavailable:

- do not silently substitute a weaker path for a required gate
- use documented fallback only when the owning lane allows it
- report the exact blocker and what evidence remains missing
- continue on independent read-only or local work only if it cannot invalidate
  the blocked gate
- mark the blocked proof `Pending Verification` instead of claiming completion

For mandatory reviewer, critic, publication, production, or safety gates, a
missing tool is a blocker, not permission to skip.

## Output

```text
Recovery decision: RECOVERED | REROUTED | PARTIAL STATE CONTAINED | BLOCKED
- failure class and failure locus:
- target/state freshness:
- attempts and materially changed variables:
- retry decision record and remaining budget:
- partial-state or side-effect impact:
- containment/readback/cleanup status:
- evidence:
- retry allowed: yes | no
- changed variable, retry owner, and stop condition:
- safe continuation:
- next owner and re-entry condition:
- Pending Verification:
```
