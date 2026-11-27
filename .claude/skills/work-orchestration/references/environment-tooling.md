<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (new orchestration lane for environment, toolchain, and bootstrap blockers) -->

# Environment Tooling

```text
Type: owning lane
Use when: environment or command infrastructure fails before the target runs
Skip when: the product ran and exposed domain behavior
Owns: setup/bootstrap/toolchain/container/wrapper failures that occur before product
      behavior can be evaluated
Does not own: product-code fixes unless evidence proves the product is at fault
Allowed side effects: bounded local tooling repair within current authorization
Inputs: intended command, error, repo instructions, environment state, and write ceiling
Exit states: repaired, workaround selected, blocked, product issue confirmed
Outputs: failure classification, repair evidence, and next owner
Re-enter when: repair changes tool/runtime boundary or product behavior becomes
               reachable
```

Use this lane when setup, bootstrap, package manager, version manager, Docker,
Testcontainers, env files, local services, generated commands, CI-equivalent
commands, or wrappers fail before product behavior can be evaluated.

The lane separates environment-local blockers from product failures so agents do
not patch product code for broken setup.

## Use For

- missing or wrong toolchain, package manager, shell activation, `mise`, Docker,
  browser binaries, local service, database, cache, queue, env file, credential,
  or generated-code prerequisite
- commands that fail before reaching product code
- choosing whether a failure is command misuse, environment-local, auth/config,
  dependency, tool outage, flaky/timing, stale state, or product failure
- documenting setup blockers and choosing a next-best deterministic validation

## Do Not Use For

- product failures after setup is confirmed; use `diagnose`
- normal validation strategy; use `validation`
- dependency or tool implementation changes; use `code-authoring`
- production environment changes; use `incident-command` and risk/permission
  gates

## Classification

| Class | Signal | Next action |
| --- | --- | --- |
| Command misuse | wrong directory/module/flag, pager, interactive prompt, quoting | correct command from repo docs and rerun once |
| Toolchain | wrong/missing binary, runtime, shim, package manager, version | inspect manifests, active binary, and wrapper |
| Dependency install | missing modules, lock mismatch, package-manager mismatch | use repo package manager; do not hand-edit locks |
| Local service | Docker, DB, cache, queue, sibling service unavailable | verify safe startup and mutation risk |
| Auth/config | missing env/token/project/principal | stop or use next-best read-only check; never print secrets |
| Generated state | source input/output mismatch or generator unavailable | identify source-of-truth input and generator command |
| Flaky/timing | intermittent after setup succeeds | rerun narrowly once, collect signal, route to diagnose if persistent |
| Product failure | reaches product code and fails consistently | route to `diagnose` or implementation owner |

## Rules

- Read repo command docs, package manifests, task runners, CI workflows, and
  local `AGENTS.md` before inventing setup commands.
- Verify working directory, branch, module root, env source, tool versions, and
  generated-code state before broad commands.
- Prefer repo-owned pinned commands. Do not install global tools, mutate shell
  startup files, change user-level config, or edit product code as workaround
  unless the user explicitly asks for setup repair.
- Treat package lifecycle hooks, fetched installers, container images, browser
  downloads, and bootstrap scripts as code execution with network and machine
  effects. Prefer pinned repo-owned artifacts; inspect the command/source and
  expected writes before running it.
- Do not use `curl | sh`, `wget | bash`, unverified binary downloads, or an
  unpinned remote image as a generic repair. A repo-approved runbook may permit
  one only with source/version integrity, exact destination, cleanup, and current
  authorization.
- Treat trust of repo-local tool configuration such as `.mise.toml` as a
  security and machine-state mutation. Inspect the exact file and repository
  policy, then trust it only under an authorized boundary; otherwise use an
  already-installed direct binary or report the blocker.
- For Docker/Testcontainers/integration tests, verify whether the command
  mutates local databases or containers before running it.
- Confirm secret presence without printing values.
- If setup cannot be repaired safely, run the next-best deterministic check and
  mark the exact setup gap `Pending Verification`.

## Output

```text
Environment/tooling outcome: REPAIRED | WORKAROUND SELECTED | BLOCKED | PRODUCT ISSUE CONFIRMED
- command/check:
- blocker class:
- evidence:
- safe correction:
- lifecycle/network/machine side effects:
- processes/artifacts started and cleanup:
- reached product code: yes/no
- next route and owner:
- re-entry condition:
- Pending Verification:
```
