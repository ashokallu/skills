<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-27 (secret-safe approval identity and auth evidence) -->

# External System Boundaries

```text
Type: decision gate
Use when: an external read/write could affect the route or claim and its boundary is
          unclear
Skip when: the phase is entirely local and no external state is needed
Owns: target, identity, operation, permission, pagination/scope, and readback contract
      for an external system
Does not own: the domain workflow or mutation content
Allowed side effects: bounded read-only preflight
Inputs: external system, exact resource, intended operation, identity, authority, data
        class, and expected result
Exit states: bounded, ask, blocked, reroute
Outputs: external operation contract and owning specialist
Re-enter when: target, principal, operation, scope, auth, or expected result changes
```

Use this lane when the next action touches a system outside the local repo:
APIs, MCPs, plugins, SaaS tools, cloud resources, dashboards, monitoring,
connectors, browser-authenticated apps, data services, or any remote state whose
read/write target must be proven before acting.

This lane does not replace specialist workflows. It defines the boundary so the
orchestrator can safely hand the action to GitHub, Jira, Confluence, data,
browser, incident, source-handling, or code-authoring owners.

## Use For

- choosing whether an external tool is evidence, an execution surface, or the
  workflow owner
- verifying target environment, account, project, tenant, org, repo, resource,
  URL, ID, filter, or time window before an external action
- external reads that require pagination, filtering, redaction, or freshness
  proof before broad claims
- external writes that need readback, idempotency, rollback, and audit evidence
- plugin/MCP results that may be stale, partial, unauthorized, or scoped to the
  wrong identity

## Do Not Use For

- normal web research and citations; use `source-handling`
- GitHub/Jira/Confluence mechanics after the boundary is clear; use the
  matching specialist
- read-only live data access as the main task; use `readonly-data-access`
- production mutation decisions; use `risk-and-side-effects` plus incident or
  release workflows
- code implementation after the external contract is understood; use
  `code-authoring`

## Boundary Preflight

Before using an external system for a decision or mutation, establish:

1. **Owner route:** repo lane or specialist that owns the workflow.
2. **Target:** exact org/project/account/tenant/env/resource/URL/ID/filter.
3. **Principal:** authenticated identity or credential source, without printing
   secrets.
4. **Operation:** read, list, search, export, create, update, delete, comment,
   transition, deploy, rollback, run job, or mutate config.
5. **Scope:** whether results must be exhaustive or sampled; pagination and time
   window rules.
6. **Sensitivity:** secrets, tokens, cookies, PII, customer data, request bodies,
   billing data, permission changes, or public communication.
7. **Idempotency:** whether retrying can duplicate work, send notifications,
   rerun jobs, or create duplicate artifacts.
8. **Readback:** exact post-action check that proves the intended state changed.
9. **Rollback:** revert/edit/delete/disable path, or why rollback is unavailable.

If target, principal, or operation remains uncertain after bounded discovery,
return `ASK`/`BLOCKED` through `request-intake`; do not use the risk gate to guess
the resource or identity. Once the boundary is known and a write is proposed,
`risk-and-side-effects` decides authorization before the specialist acts.

When a task autonomy envelope is active, return the verified environment,
principal, exact resource set, operation, and sensitivity as independent facts
to the parent dispatcher. Being in Production does not itself make a read
sensitive, and being outside Production does not make sensitive data public.
A new principal, resource, environment, write/execute class, or sensitivity
level is an envelope expansion and must stop before the action. This gate supplies
boundary evidence; it does not authorize the action or own envelope versioning.

Also classify, per action, whether the target is a critical shared
service/data surface and whether the operation's direct or predictable
normal-workflow effect mutates that surface. Critical shared targets include
shared managed infrastructure, Staging or Production runtime or persisted
data, database state, deployed artifacts or traffic, shared config or flags,
secrets or IAM, queues, jobs, and equivalent service/data/security control
planes. Return `direct`, `predictable`, or `none` plus the causal effect to the
parent.

Routine Git hosting, review/issue/document collaboration, and test-only CI
actions return `none` when their normal outcome does not mutate a critical
shared target. They retain proportional authority, target, rollback, and
readback rules but do not activate an autonomy packet. A push, workflow
dispatch, or retry whose normal success deploys, migrates, changes traffic, or
runs a shared-state job returns `predictable` and cannot escape the critical
mutation latch because its immediate surface looks routine. This gate still
does not own confirmation or authorize execution.

## Read Discipline

- Treat external reads as current evidence only for the target, filters, identity,
  and retrieval time used.
- Do not claim "all", "none", "top", "latest", "current", or "resolved" unless
  pagination, filters, stale windows, and resource identity support that claim.
- Prefer official APIs, authenticated tools, and versioned exports over rendered
  pages or snippets when they disagree.
- Summarize sensitive payloads. Do not paste raw secrets, bearer tokens, cookies,
  request bodies, or unnecessary personal data.
- When a plugin result conflicts with repo state or official API output, route
  through `conflict-resolution`.

## Write Discipline

External writes require the owning route plus the risk gate. Before writing,
state the mutation class and expected readback. After writing, read the target
back before claiming completion.

For a qualifying critical mutation, do not write after boundary preflight.
Populate the envelope's target, principal, resource, operation,
auth/permission, and authorized-proof facts, then stop at its confirmation
latch. For a non-qualifying remote write, proceed through the owning specialist
and risk boundary without constructing an autonomy packet, then perform the
declared readback.

Do not silently substitute a manual/browser/UI write for an API write, or an API
write for a browser/UI write, when the workflow requires one surface. If a
fallback is necessary, mark the difference and validate the final remote state.

## Output

```text
External boundary:
- owner route:
- target:
- principal/credential boundary:
- auth/permission state: authorized | unauthorized | partial | unknown | not-required
- operation:
- scope/pagination:
- sensitivity/redaction:
- idempotency/retry risk:
- readback proof:
- rollback:
- decision: PROCEED | REROUTE | ASK | BLOCKED
- allowed boundary:
- allowed operations:
- prohibited operations:
- next owner:
- reopen condition:
- Pending Verification:
```

When a task autonomy envelope is active, return exact target, principal,
auth/permission state, and externally allowed and prohibited operations as
separate secret-safe facts. Confirm credential presence or identity without
printing credential values.
