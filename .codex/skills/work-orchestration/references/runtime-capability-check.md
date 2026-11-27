<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-27 (runtime and network readiness ownership) -->

# Runtime Capability Check

```text
Type: decision gate
Use when: a planned route depends on a named capability and the inline inventory/config
          check cannot prove whether that capability exists with the required boundary
Skip when: current runtime inventory/config or same-session evidence already proves it
Owns: disposition of a load-bearing runtime capability that remains uncertain after the
      current runtime inventory and repo configuration are checked
Does not own: delegation economics, domain judgment, implementation, or final claims;
              tool-failure recovery, environment setup, external identity/auth, or
              monitoring execution
Allowed side effects: bounded read-only capability discovery; no paid call, external
                      disclosure, credential use, smoke execution, or target mutation
                      unless separately authorized
Inputs: required capability, action boundary, current runtime evidence, and fallback
        need
Exit states: verified, fallback selected, blocked, not needed
Outputs: capability snapshot, sanctioned fallback, and next owner
Re-enter when: runtime/config/network/capability evidence changes
```

Use this gate only for a load-bearing uncertainty that survives the cheap inline
check. Model names, CLI versions, wrapper flags, agent rosters, quotas, network
access, sandbox behavior, and background-resume support can change; verify them
at use time instead of treating documentation memory as current fact.

## Trigger

Before activating this gate, inspect the runtime-provided inventory and current
repo configuration inline. Activate it only when the proposed route still
depends on an unresolved capability such as:

- a named specialist skill or project agent;
- a native reviewer, critic, database, security, infrastructure, scout, or
  writer role;
- a specific model/tier or context limit;
- a repo wrapper or helper script;
- presence of a configured GitHub, browser, cloud, database, Jira, Confluence,
  or other integration path before any external identity, authorization,
  target, or readback question arises;
- filesystem write, network, subprocess, worktree, or sandbox permissions;
- structured artifact transport;
- concurrency slots, quotas, paid-agent budget, or rate limits;
- autonomous monitoring, wake/resume, or long-running process support.

Do not activate this gate for:

- an attempted command, tool, wrapper, auth, sandbox, or worker action that
  already failed; use `execution-recovery-and-tool-failures`;
- missing packages, services, environment setup, or local toolchain state; use
  `environment-tooling`;
- external account, principal, credential, target, permission, or readback
  uncertainty; use `external-system-boundaries`;
- the decision whether another worker is worth its context, cost, supervision,
  and join overhead; use `delegation`;
- wait ownership, polling, wake/resume, or terminal observation mechanics after
  monitoring is selected; use `waiting-and-monitoring`; or
- a capability already proved by current inventory, repo config, or successful
  exercise in the same stable session and permission surface.

## Verification Order

Use the cheapest authoritative source:

1. runtime-provided tool or role inventory;
2. current repo instructions/configuration;
3. `--help`, version, or read-only capability query that requires no credential
   use, paid call, external disclosure, or mutation;
4. explicit user/operator confirmation when the needed capability cannot be
   established read-only and the owner controls it.

Do not infer availability from a stale doc, previous session, model name, or
wrapper path alone.

For an active task autonomy envelope, return monitoring capability separately
from authorization. `READY FOR AUTOPILOT` requires proof that the selected
runtime can observe and report every required terminal state. Unsupported or
unknown required wake/resume capability cannot be papered over with a detached
process, sleeping shell, or optimistic promise; select `READY WITH CHECKPOINTS`,
`APPROVAL REQUIRED`, or `BLOCKED` according to the safe foreground work that
remains. A newly required monitoring mode is an upward envelope delta.

The parent derives capability work from the planned action graph, not from an
inventory of installed tools. For every load-bearing action ID assigned to this
gate, return a current capability evidence row with availability, source and
freshness, allowed/prohibited boundary, fallback or blocker, and action role.
Do not claim completeness for external identity, credentials, permission,
sensitive proof, or monitoring execution; their owning gates must populate
those parts of the same row. A smoke or metadata read remains forbidden here
unless its external/privacy authority was separately established. Any planned
action without a complete current row blocks `READY FOR AUTOPILOT`.

## Capability Snapshot

Record only fields relevant to the proposed route:

```text
Capability:
Source of truth:
Availability: yes | no | partial | unknown
Allowed operations:
Prohibited operations:
Runtime/network/sandbox state:
Concurrency, quota, or paid-call state:
Async resume support: yes | no | unknown
Freshness:
Required fallback:
Pending Verification:
```

External principal, credential, and permission state remain owned by
`external-system-boundaries`. This snapshot owns only the runtime integration,
network reachability, and sandbox capability needed to exercise that external
boundary.

Never expose secrets, bearer tokens, cookies, private config, or full process
command lines while checking capability.

## Fallback Rules

A fallback is valid only when it preserves:

- the same or narrower side-effect boundary;
- required independence and role separation;
- evidence quality needed by the next consumer;
- privacy and secret handling;
- target identity and freshness;
- the user’s explicit tool or worker requirement.

Preferred fallback order:

1. another configured path for the same role and boundary;
2. parent-owned read-only work when independence is not mandatory;
3. a narrower partial result with `Pending Verification`;
4. `BLOCKED` for specialist-only writes, mandatory independent verdicts,
   production operations, or unsupported external mutations.

Do not silently replace a mandatory reviewer, security, database, release, or
production gate with generic parent judgment. Do not retry multiple wrappers or
models after the first failure unless the next path changes a material variable
and the work still has net benefit.

## Output

```text
Capability decision: VERIFIED | FALLBACK | BLOCKED | NOT NEEDED
Capability:
Verified operations and boundary:
Evidence:
Fallback or blocker:
Next owner:
Recheck trigger:
Pending Verification:
```
