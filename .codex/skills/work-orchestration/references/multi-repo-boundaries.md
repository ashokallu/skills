<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (new orchestration lane for multi-repo, shared-contract, and stacked-change boundaries) -->

# Multi-Repo Boundaries

```text
Type: decision gate
Use when: one outcome spans repositories, shared contracts, generated clients, or
          stacked changes
Skip when: all authoritative changes and proof stay inside one repository
Owns: source-of-truth, producer/consumer ordering, compatibility window, and
      per-repository ownership/publication boundaries
Does not own: implementation inside each repository
Allowed side effects: read-only mapping and sequencing
Inputs: objective, repositories, shared contracts/artifacts, owners, and release
        constraints
Exit states: bounded sequence, split, needs owner, blocked
Outputs: repo boundary map, dependency order, joins, and proof per repo
Re-enter when: repo set, source of truth, ownership, compatibility, or order changes
```

Use this lane when work spans more than one repository, service, package,
generated client, deployment repo, documentation repo, shared contract, or PR
stack. It keeps ownership, sequencing, validation, and publication explicit so
one repo's successful change is not mistaken for system completion.

## Use For

- sibling service changes, shared API contracts, generated clients, SDKs,
  schemas, protobuf/OpenAPI/GraphQL artifacts, SQL migrations plus app changes,
  or cross-package releases
- changes requiring coordinated PRs, stacked branches, version bumps, deploy
  order, feature flags, backwards compatibility, or rollout sequencing
- deciding which repo is source of truth and which repos only consume generated
  output
- broad initiatives where each repo needs separate validation and publication
  evidence

## Do Not Use For

- a broad single-repo initiative; use `work-slicing`
- implementation inside one repo after boundaries are known; use
  `code-authoring`
- branch mechanics or worktree creation; use `worktree-readiness`
- external-system mutation such as GitHub/Jira/Confluence writes; use the
  relevant specialist after sequencing is known

## Boundary Map

Before editing, create a compact map:

```text
Multi-repo boundary map:
- source of truth:
- repos/packages involved:
- owner route per repo:
- write authority per repo:
- contracts/generated artifacts:
- compatibility requirement:
- validation per repo:
- join artifact/consumer per repo:
- publication/deploy order:
- rollback or fallback:
- Pending Verification:
```

## Sequencing Rules

- Identify the source of truth before editing generated clients or copied
  contracts.
- Keep producer and consumer changes reviewable. Prefer backwards-compatible
  producer changes before consumer reliance when deploy order is uncertain.
- Do not batch unrelated repo changes in one claim. Each repo needs its own diff,
  validation, review, and publication evidence.
- Do not assume a branch, PR, CI run, generated artifact, or dependency version
  in one repo proves another repo is current.
- If a shared contract changes, include compatibility evidence: old client/new
  server, new client/old server, fallback behavior, flag state, or explicit
  one-way migration sequencing.
- If generated files are required in multiple repos, record generator command,
  source input, output path, and whether the output was regenerated or left
  `Pending Verification`.
- If a dependency or package version crosses repos, record pin, lockfile, release
  artifact, and consumer validation.
- Use separate PR/publication phases unless an existing workflow explicitly owns
  stacked PR creation.

## Common Pitfalls

- editing a generated client directly instead of the schema/source
- validating only the producer and claiming consumer safety
- opening a consumer PR before the producer contract is published or pinned
- losing rollback because both repos require simultaneous deployment
- mixing docs/deployment config changes into a code PR without owner approval
- using stale branch names or unverified CI from a different repo/head

## Output

```text
Gate: multi-repo-boundaries
Decision: BOUNDED SEQUENCE | SPLIT | NEEDS OWNER | BLOCKED
- next repo/phase:
- owner lane or specialist:
- side effects allowed:
- required compatibility proof:
- join or handshake proof:
- deferred repo phases:
- blocked by:
- re-entry condition:
- Pending Verification:
```
