<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (new orchestration lane for claim-to-evidence mapping and proof quality) -->

# Evidence And Verification Ledger

```text
Type: companion contract
Use when: high-risk, disputed, external, review, release, or broad completion claims
Skip when: one current observation proves the narrow claim
Owns: mapping each material claim to current evidence and exact gaps
Does not own: collecting all evidence, routing, or the final domain verdict
Allowed side effects: none; evidence collection remains with the active owner
Inputs: candidate claims, exact target, evidence, acceptance, and limitations
Exit states: proved | sampled | stale | conflicting | Pending Verification
Outputs: claim ledger with proved, sampled, stale, conflicting, and pending states
Re-enter when: target, evidence, claim wording, or acceptance changes
```

Use this lane when the work depends on proof quality: conflicting sources,
uncertain current state, generated summaries, subagent output, external tool
results, broad claims, or any final answer where the agent might overstate what
was verified.

This lane complements `source-handling`, `validation`, and
`completion-claim-gate`. Source handling decides how to gather evidence;
validation decides what command or runtime proof to run; completion claim gate
checks final wording. This lane keeps the claim-to-evidence map during the work.

## Use For

- strong claims such as all, complete, green, ready, fixed, safe, no issues,
  production-ready, backwards-compatible, review-clean, current, or verified
- deciding whether evidence is direct proof, derived proof, a lead, an
  assumption, stale, or `Pending Verification`
- parent verification of Luna, subagent, reviewer, critic, external tool, or
  copied-summary output
- conflicts between current code, docs, CI, review comments, source results,
  screenshots, PR state, or external systems
- final responses where unverified gaps must be separated from completed work

## Do Not Use For

- choosing commands; use `validation`
- gathering external/current facts; use `source-handling`
- final completion wording after all proof exists; use `completion-claim-gate`
- replacing a specialist verdict, incident packet, or PR workflow output

## Evidence Levels

Use the strongest applicable level for each material claim:

1. **Direct proof:** current source file, command output, runtime check, live
   remote state, or official/version-matched source directly supports the claim.
2. **Derived proof:** direct proof plus a small inference, such as tracing a
   caller or matching repo-pinned dependency behavior.
3. **Corroborated lead:** multiple weaker sources agree, but no direct proof is
   available.
4. **Single lead:** snippet, old doc, comment, screenshot, subagent summary, or
   secondary source suggests the claim.
5. **Assumption:** needed to proceed but not verified.
6. **Pending Verification:** required proof is absent, blocked, stale, or out of
   scope.

Only direct or derived proof can support strong completion language. Leads and
assumptions must be worded as such.

## Claim Ledger

For non-trivial work, maintain a lightweight ledger:

```text
Evidence ledger:
- claim: <what will be reported or acted on>
  level: <direct|derived|corroborated lead|single lead|assumption|Pending Verification>
  evidence: <file/command/source/state>
  freshness: <current|stale risk|unknown>
  gap: <none or missing proof>
```

Use this especially for:

- current PR, CI, reviewer-thread, branch, release, deploy, or live-system state
- auth, tenant, data, migration, dependency, security, or performance claims
- documentation or PR metadata that describes validation, risk, or rollout
- subagent/Luna/reviewer output that the parent did not verify
- sampled searches where the answer might be mistaken for exhaustive coverage

## Conflict Handling

When evidence conflicts:

1. Prefer current live state over stale cached state.
2. Prefer repo source, manifests, generated inputs, and tests over old docs.
3. Prefer official/version-pinned external sources over tutorials or snippets.
4. Prefer authenticated API/tool output over rendered HTML for GitHub and other
   external systems.
5. Keep both facts if they describe different targets, branches, heads,
   environments, tenants, or versions.
6. Mark unresolved conflict `Pending Verification`; do not choose the convenient
   claim.

## Delegated Evidence

Subagent, Luna, reviewer, critic, and tool outputs are useful evidence, not
parent absolution. Before acting on delegated output, check:

- Does it cite exact files, commands, IDs, versions, lines, or sources?
- Does the target match the current branch, PR head, environment, or user ask?
- Is the output current enough for the next side effect?
- Did the delegate stay inside its read/write boundary?
- Is the claim judgment-heavy enough that the parent or specialist must verify
  it before write, publish, or completion?

If delegated evidence is missing citations, stale, target-mismatched, or out of
scope, retry once with the defect named or treat it as `Pending Verification`
according to risk.

## Wording Discipline

Use precise verbs:

- **Inspected** means files or sources were read.
- **Changed** means the diff exists locally.
- **Validated** means the named command or runtime check passed on the relevant
  checkout/environment.
- **Pushed** means the remote ref was verified after push.
- **Published** means reviewer-facing PR metadata or external content was
  verified after mutation.
- **Ready** means all required gates for that workflow passed, or the claim is
  narrowed so any missing gates are explicit.

Do not use stronger wording than the evidence supports.

## Output

```text
Evidence summary:
- confirmed:
- inferred:
- leads/assumptions:
- Pending Verification:
- not checked:
```
