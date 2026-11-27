<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (linked side-effect and multi-repo boundaries) -->

# Repository Editing

```text
Type: companion contract
Use when: an owning code, document, or instruction lane is preparing repository writes
Skip when: work is read-only or the specialist has a stricter editing contract
Owns: surgical edit discipline, preservation of unrelated work, generated-file
      boundaries, and edit-time hygiene
Does not own: solution design, code-authoring judgment, validation, git, or publication
Allowed side effects: none by itself; the owning lane supplies the authorized write
                      boundary
Inputs: accepted objective, exact target, file scope, repo instructions, and proof plan
Exit states: edit contract ready | blocked
Outputs: edit constraints consumed by the owning lane
Re-enter when: edit scope, generated ownership, or concurrent state changes
```

Use this lane for local file edits, generated files, package changes,
repository `tmp/` handling, command timeouts, and branch/worktree-safe editing
behavior. Use `risk-and-side-effects` before high-risk git, remote, production,
secret, auth, data, deploy, or destructive actions. Use `environment-tooling`
when setup or toolchain behavior is the blocker before product code runs.
When the edit phase creates or adopts a temporary resource, consume
[resource-lifecycle.md](resource-lifecycle.md) for the shared lifecycle record
and invariants; this companion retains the repository-specific mechanics.

## Editing Rules

- Before edits that cross side-effect levels, confirm the allowed boundary with
  [risk-and-side-effects.md](risk-and-side-effects.md). Local
  file edits do not imply permission for git writes, remote writes, production
  actions, or destructive cleanup.
- For changes spanning sibling repos, generated clients, shared contracts, or
  deployment/docs repositories, load
  [multi-repo-boundaries.md](multi-repo-boundaries.md) before editing so each
  repo has explicit write ownership, validation, and publication boundaries.
- Treat the current worktree as shared. Before editing, check for existing
  changes in files you will touch; preserve unrelated user or generated work.
  If the branch, PR, or dirty state may have changed since the current plan,
  route through [state-synchronization.md](state-synchronization.md) before writing.
- Resolve write and cleanup paths before acting. A symlink, hardlink, mount, or
  generated path must not redirect an edit or deletion outside the authorized
  repository/worktree root. Preserve file mode and executable-bit changes unless
  the accepted task intentionally changes them.
- Follow `repo.md` for local-dev branch boundaries. Follow the relevant GitHub
  skills for PR publication, PR comments, CI, worktree readiness,
  authenticated GitHub fallback, and reviewer-facing GitHub text.
- Prefer editing existing files. Add a new file only when the requested
  behavior, repo structure, or ownership boundary genuinely needs one.
- Use structured patch/edit tools for manual edits. Generated output,
  formatter output, and broad mechanical rewrites may use the appropriate repo
  command.
- Treat generated docs, lockfiles, schemas, clients, and other derived files as
  outputs. Edit the source of truth first, then regenerate the derived files
  through the repo's normal command when the repo expects both.
- Do not hand-edit build artifacts such as `dist/`, `build/`, `target/`,
  generated clients, vendored bundles, or generated schema output unless repo
  evidence says they are source files.
- Use repo-local `tmp/` for non-trivial disposable scripts so logic is
  inspectable and rerunnable. Use `/tmp` only for non-repo artifacts.
- Never delete, empty, or broadly clean the repository root `tmp/` directory.
  It contains durable local-only roadmaps, request briefs, archives, and
  worktrees. When asked to clean worktree artifacts, target only explicit
  worktree-local paths such as `<repo-root>/tmp/worktrees/<slug>/tmp/` or
  untracked generated tool state inside that specific worktree. Verify the
  target with `git status` or `git check-ignore` before deletion, and do not
  remove tracked config such as `.clawpatch/config.json`.
- When an owning workflow authorizes disposable experiment, repair, council,
  or smoke-test worktrees, route their creation and removal through
  `worktree-readiness`. Use
  `<repo-root>/tmp/worktrees/<descriptive-slug>` as the preferred location, and
  record which worktrees and scratch branches the current run created. This
  companion contract does not create, switch, or remove them itself.
- For multi-harness, council, repair, or smoke experiments, the owning
  `worktree-readiness` phase should create one isolated worktree per
  harness or agent from the same pinned base commit. Treat those worktrees as
  proposal surfaces: inspect their diffs, copy or reapply only the selected
  durable changes into the parent branch, and do not merge every branch
  wholesale.
- Cleanup is a separate authorized action. After selected changes are
  consolidated, remove only disposable worktrees and scratch branches proven
  to be created and owned by the current run. Use `git worktree remove <path>`
  through `worktree-readiness`; use `--force` only when the user or the
  selected workflow explicitly authorized deletion of uncommitted disposable
  artifacts and the exact path has been verified. If cleanup is not authorized
  or ownership is uncertain, hand off the exact paths instead of deleting
  them. Verify authorized cleanup with `git worktree list --porcelain` and a
  filesystem glob for the exact prefix.
- Keep harness outputs, scorecards, prompts, run logs, and smoke artifacts
  under repo-local `tmp/<task-slug>/...`; do not stage those artifacts unless
  the user explicitly asks for a tracked artifact.
- Fresh worktrees can fail before the task starts when repo-local tool config
  has not been trusted by the host environment. Treat trust as a security and
  machine-state boundary, not as automatic setup. Inspect the exact
  `.mise.toml` and repository policy first; trust that exact file only when the
  user or owning workflow has authorized repo-local tool-config trust. Do not
  broaden trust, inherit trust from another path, or change tool versions
  without evidence and authorization. When trust is unavailable, prefer
  already-installed direct binaries or report the blocker instead of silently
  mutating host trust state.
- Put timeouts on scripts and long-running commands. Choose the timeout from
  the expected duration and failure mode; if it expires, investigate before
  simply raising it.
- Prefer non-interactive commands for scaffolding, installs, tests, and
  formatters. Use explicit target directories and no-watch/CI/yes flags where
  supported.
- When an authorized agent-workflow or instruction edit is being made, follow
  the repository policy that normally keeps it on `local-dev-reference`, unless
  the user explicitly requests an instruction-only PR. This companion does not
  switch branches, merge, commit, or push as a side effect; route all branch and
  worktree mechanics through the current runtime's
  `worktree-readiness` skill.
- Treat git writes as scoped operations, not cleanup opportunities. When the
  user asks for a commit, create a new commit with `git commit`; do not amend,
  squash, rebase, reset, or force-push unless the user explicitly asks for that
  history operation in the current request or the selected PR workflow requires
  it and its rewrite gate has been followed.
- If the user request implies both local edits and publication, keep those as
  separate phases. Finish the local authoring/validation route first, then
  re-enter orchestration for commit, push, or PR publication.
- If a commit attempt fails because of hooks, message format, or validation,
  retry only the same intended operation after fixing the blocker. A failed
  normal commit does not grant permission to use `git commit --amend`.
- After any git write, verify the operation with `git status --short --branch`,
  `git log -1 --oneline --decorate`, and when history shape matters,
  `git reflog -3 --date=iso` before reporting what happened.
- Use the repo's package manager for dependency additions, removals, and
  upgrades. Edit package files directly only for config or metadata the package
  manager cannot express.
- Never hand-edit lockfiles. Let the correct package manager regenerate
  `app/yarn.lock`, `backend/go.sum`, and `e2e/pd/package-lock.json`, then
  review the resulting diff for unexpected transitive churn.
- Before adding a task, script, tool, or dependency, inspect existing task
  runners, package manifests, scripts, and CI workflows. Reuse or extend an
  existing pattern unless a new surface has a clear benefit and migration path.
- Dependency changes need source evidence before the edit when risk is more
  than a patch bump: current manifest or lockfile state, official changelog or
  release notes, security/advisory signal when relevant, and an explicit
  behavior-change check for defaults, errors, performance, telemetry, or
  deprecations.
- Prefer small dependency increments. Do not batch unrelated major upgrades,
  introduce a new package manager for an existing scope, or remove a dependency
  without checking import and usage sites first.
- For tooling or developer-workflow changes, preserve backward compatibility
  for existing commands when feasible. If a command must change, include a
  migration note and validate the new command path, dry-run/config output, or
  affected task suite.
- For Docker compose or dev-server changes, validate config before runtime
  smoke where possible, document any new port or environment variable exposure,
  and stop services started only for verification.

## Output

```text
Repository edit contract:
- owning lane and target:
- authorized write boundary:
- files/symbols owned:
- pre-existing or concurrent work to preserve:
- source-of-truth and generated outputs:
- package/tooling command and expected side effects:
- temporary artifacts, ownership, and cleanup boundary:
- validation owner and proof:
- re-entry trigger:
- Pending Verification:
```

The owning lane consumes this contract; this companion does not perform the
edit, validation, git operation, cleanup, or publication itself.
