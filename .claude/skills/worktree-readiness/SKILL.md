---
name: worktree-readiness
description: Use when creating, preparing, checking readiness, committing, rewriting history, or pushing from a example-app git worktree. Do not use it to choose PR CI commands or application validation coverage.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-27 (single-commit new-PR readiness) -->

# worktree-readiness

## Route Boundary Contract

This specialist consumes the shared
[Route Node Interface and Lane Journey Contract](../work-orchestration/references/workflow-contracts.md#lane-journey-contract).
Before a worktree or git mutation, the parent names the exact checkout/branch,
authorized git side effect, readiness or terminal git proof, and next owner.
After the proof is observed, narrate the transition before authoring, review,
or publication continues. Internal readiness checks remain implementation
detail, not separate user-visible lanes.

## Ownership

This skill owns git worktree mechanics for example-app:

- where worktrees live
- how they are named
- readiness checks before code edits
- branch-local frontend dependency setup
- Husky setup before git write paths
- push/auth boundaries from a worktree
- keeping instruction and skill edits out of feature/PR worktrees

It does **not** own PR metadata reads, review-comment policy, CI command
selection, or PR body content. Use the domain skill for those concerns after
this worktree setup is complete.

## USE FOR

- creating a repo-local `tmp/worktrees/<slug>` checkout
- preparing branch-local dependencies and Husky in a worktree
- validating worktree status, branch slug, and push/auth readiness

## DO NOT USE FOR

- choosing PR-triggered CI commands or deciding validation coverage; use the
  `pr-workflow` local-ci lane
- reading or fixing PR review comments; use the `pr-workflow` comments
  lanes
- transplanting completed work and opening a PR; use the
  `pr-workflow` publication lane

## Worktree Rules

- Treat `local-dev-reference` and every branch cut from it as non-PR
  integration/instruction branches. For commit, cherry-pick, and direct-push
  requests on those branches, use this skill's git readiness and push boundary
  only. Never enter PR publication, Jira, PR-template, review-thread, or remote reviewer
  gates, and never open a PR from those branches.
- This skill is intentionally self-contained for git branch, worktree, commit,
  and push safety. Agents running from `main` may not have the latest
  `AGENTS.md`, `CLAUDE.md`, or `repo.md`; do not rely on those files for the
  rules below.
- Worktree readiness is a hard pre-authoring gate, not a cleanup step. For any
  non-root worktree where code, tests, generated files, docs, config, commits,
  pushes, PR publication, or reviewer gates may happen, prove readiness before
  the first code edit. Do not treat an existing checkout as ready because the
  files are present.
- The minimum readiness proof before authoring is: worktree path and branch
  match the intended target, `git status --short --branch` is understood,
  `core.hooksPath` points at the repo hook path, the Husky helper exists when
  hooks are configured, required branch-local dependencies are installed, and
  repo-local or CI-aligned tools needed for validation resolve to the intended
  version from the worktree.
- If a hook, linter, Go environment, Node environment, or dependency setup
  problem appears after code edits started, stop the authoring path. Do not
  keep editing, request review, push, or open a PR from that state. Repair
  readiness first, rerun any validation or reviewer gate that could have been
  affected, and record the ordering violation separately from product-code
  findings.
- Create repo worktrees only under `tmp/worktrees/<slug>`.
- Never delete or broadly clean the repository root `tmp/` directory during
  worktree cleanup. Root `tmp/` holds local-only roadmaps, request briefs,
  archives, and the worktrees themselves. Cleanup must target only the named
  worktree-local artifact path, for example
  `tmp/worktrees/<slug>/tmp/`, and only after verifying that path is inside the
  intended worktree.
- Before deleting Clawpatch or other tool artifacts from a worktree, distinguish
  generated state from tracked repo config. Remove untracked generated state
  such as `tmp/worktrees/<slug>/tmp/clawpatch-*`; do not remove tracked config
  such as `tmp/worktrees/<slug>/.clawpatch/config.json`.
- Never switch the root checkout to a feature, fix, PR, or reproduction branch
  for code changes. Only edit code in the root checkout when the current branch
  is intentionally the current branch; otherwise create or reuse a repo-local
  worktree and make branch changes there.
- First-time worktree creation is local setup only. Do not push the new branch,
  run `git push -u`, or set an upstream remote branch as part of creating or
  preparing the worktree unless the user explicitly asks to push, publish, or
  open a PR for that branch.
- For maintaining or pushing an open PR branch, use the normalized PR head
  branch name as the worktree slug and as the local branch name. The local
  branch should track `origin/<head-branch>` because the remote branch already
  exists; this does not grant permission to push new work.
- For PR-scoped problem investigation, do not search the root checkout unless
  it is already proven to be the live PR head. First fetch the PR head, check
  whether that exact head is contained in `origin/local-dev-reference`, then
  create or reuse the PR-head worktree if it is not contained. Search and read
  files from the PR-head worktree before drawing conclusions about what the PR
  contains.
- Before creating any PR-related worktree, inventory existing worktrees with
  `git worktree list --porcelain` and reuse a clean matching checkout when
  possible. Match by live PR head branch first, then by canonical PR review
  path `tmp/worktrees/pr-<number>`, then by current head SHA when the worktree
  is detached. Do not create a second worktree only because another harness
  chose a different path.
- For read-only PR reviews, the canonical worktree path is
  `tmp/worktrees/pr-<number>`. If that path or another clean worktree already
  points at the same PR head, reuse it. Do not create purpose-suffixed review
  worktrees such as `pr-<number>-cloudsql-storage-review`; those quickly waste
  disk and make freshness ambiguous.
- When multiple agents are asked to work on the same PR or branch in parallel,
  create one canonical worktree for the real PR head branch and separate
  scratch worktrees for each agent. Scratch worktrees must use scratch branches
  based on the same PR head or base, for example `<head-branch-slug>-agy` and
  `<head-branch-slug>-copilot`; integrate only selected commits, patches, or
  diffs back into the canonical worktree before pushing.
- Reserve PR-number slugs such as `pr-123-ci-fix` or `pr-123-comments-fix` for
  short-lived CI or review-comment reproduction work, not ongoing PR
  publication.
- For a branch without a PR, use the branch name with `/` replaced by `-`.
- Prefer PR merge refs for CI or review-comment reproduction unless the task
  specifically requires head-only behavior.
- For stacked PRs, keep every worktree branch named after its real PR head and
  preserve the live base chain. A child PR branch must be based on its immediate
  parent branch, not on `main`, unless the PR base is intentionally changing.
- When refreshing a stacked PR chain after `main` changes, update the root of
  the stack first, then walk down the chain one branch at a time:

    ```bash
    git fetch origin main <root-branch> <child-branch> <grandchild-branch>
    git -C tmp/worktrees/<root-branch> rebase origin/main
    git -C tmp/worktrees/<child-branch> rebase <root-branch>
    git -C tmp/worktrees/<grandchild-branch> rebase <child-branch>
    ```

    For the E2E stabilization stack, the order is smoke, then regression based on
    smoke, then visual regression based on regression.

- If a change is added to the root branch after child PRs already exist, rebase
  every child branch onto the updated local parent before running or dispatching
  CI from the child. Otherwise the child workflow run will use the old remote
  child SHA and miss the parent change.
- Before force-pushing a rebased or stacked PR, verify the intended scope with
  `git diff --name-only origin/<base-branch>...HEAD` and check the live PR file
  list after push.
- Before any commit-history rewrite on an open PR branch, inspect and record
  the current topology with `git log --oneline <base>..HEAD` and the live PR
  commit list. Decide which commits must remain separate and which adjacent
  commits are in the rewrite range before running the rewrite command.
- Before applying a routed PR-workflow amend rule, check whether a
  provenance-bound scoped re-review is planned or active. If it is, preserve
  the reviewed `H0` and create a new ancestral finding-directed fix commit or
  exact range. Do not rewrite that boundary until the scoped result is
  terminal. A provider-specific convenience rule is not rewrite authorization
  when it would destroy required review provenance.
- Preserve feature/fix boundaries by default. A request to squash review-fix,
  bot-fix, or "top N" commits is not permission to squash lower feature
  commits. Use a range-specific rewrite and verify the resulting commit list
  before force-pushing.
- For history-only rewrites, verify tree equivalence against the old head:
  `git diff --quiet <old-head>..HEAD`. If this fails, inspect the diff and run
  normal code validation because the operation was not history-only.
- A new PR publication branch must contain exactly one commit relative to its
  intended base at first push and PR creation. Pre-open reviewer fixes may use
  separate local commits while review provenance is active, but after all
  required pre-open reviews are terminal, record the reviewed head, squash the
  full branch range, prove tree equivalence, and require
  `git rev-list --count <base>..HEAD` to print `1`. For stacked PRs, use the
  intended parent branch as `<base>`. Do not push or create the PR when the
  count differs.
- After rebasing child branches, expect non-fast-forward remote updates. Use
  `git fetch` immediately before `git push --force-with-lease`, push from root
  to leaf, and verify remote refs match local tips before asking for CI reruns.
- After every push or force-push to an open PR branch, run the post-push PR
  body gate before final handoff. PR title/body freshness is part of PR
  publication closeout, even when the user only asked to commit, push, amend,
  squash, rebase, or force-push.
- Treat the root checkout and disposable worktree as separate surfaces.
- Treat unrelated local branch state as separate from the PR publication branch.
- Keep `AGENTS.md`, `.github/copilot-instructions.md`,
  `.github/instructions/**`, runtime skill directories, and other agent
  guidance edits out of PR worktrees unless the user explicitly asks for an
  instruction-only PR.
- When the user asks for instruction self-repair, skill hardening, or workflow
  guidance updates, treat that as instruction-maintenance work on the repo's
  instruction branch or current instruction checkout. Do not make those edits
  inside an unrelated feature, stack, review, or PR worktree just because that
  worktree was active when the lesson was learned.
- Keep Waza eval files and Waza runs out of PR worktrees unless the PR is explicitly about them. If a skill was
  evaluated there, transplant only the relevant skill, agent, doc, or config
  changes to a PR branch; do not include Waza eval files in unrelated PR
  branches.
- Treat the current checkout as shared. Before editing or staging, inspect
  `git status --short --branch` and preserve unrelated user or generated work.
- Before any commit, inspect `git diff --stat` and the relevant hunks for every
  dirty path. Classify each path as intentional task work, intentional
  generated output, user-owned/unrelated work, or incidental tool/editor churn.
  Stage only intentional task work and required generated output. Do not commit
  incidental Markdown table alignment, formatter-only wrapping, local metadata
  artifacts, or unrelated dirty files just because the user said "commit and
  push".
- If the only dirty changes are incidental churn or files you cannot explain,
  stop before staging. Revert only changes you created and can prove are
  unwanted; otherwise report the dirty paths and ask how to handle them.
- Stage explicit paths when practical. Avoid `git add .` and `git add -A` in
  mixed worktrees.
- Before committing, inspect recent commits or repo docs for the enforced commit
  message format. Do not invent a format when it is not verified.
- A plain commit request means a new commit. Do not use `git commit --amend`,
  interactive rebase, `reset`, or force-push to satisfy a plain commit or push
  request. Those are history-rewrite operations and require explicit current
  user authorization or a selected PR workflow rewrite gate.
- Do not infer amend from the existence of a previous local commit, a failed
  commit attempt, or a general "do the required" follow-up. Use amend only when
  the latest user request or the selected PR workflow explicitly authorizes a
  rewrite for the current target.
- If the user challenges whether an amend, rebase, reset, or force-push
  happened, inspect `git reflog -5 --date=iso`, `git log --oneline -5`, and
  branch status before answering. Never deny a rewrite from memory.
- When a normal commit fails because of hooks, validation, or commit-message
  format, correct the blocker and rerun `git commit` as a new commit. Do not
  convert the retry into `git commit --amend`.
- Ordinary commit, push, branch-update, and hook-recovery work does not use an
  autonomy acceptance packet. The user's current Git request plus this owning
  workflow supplies action-specific authority; target, history risk, hooks,
  validation, and readback remain mandatory.
- On the first failed commit or push attempt, read back worktree, index,
  branch/upstream, and remote state as applicable. Correct the proved blocker
  inside the existing task scope, preserve hooks, stage only intentional paths,
  rerun every invalidated validation or review gate, and retry once with a
  materially changed variable. An in-scope content correction or formatter
  fix is ordinary authoring, not an autonomy-envelope expansion. A new target,
  branch, remote, credential, history-rewrite class, unrelated path, or second
  failure routes through scope/recovery control instead of creating repeated
  approval packets.
- If a Git push or CI dispatch predictably deploys, migrates, changes traffic,
  or runs a shared-state job, stop before that action and route the critical
  shared mutation through the autonomy acceptance contract. The surface label
  `push` or `retry` never exempts its normal critical effect.
- Before reporting a commit or push result, verify local and remote shape with
  `git status --short --branch`, `git log -1 --oneline --decorate`, and the
  relevant ref comparison such as `git rev-parse HEAD @{u}` when an upstream
  exists. If history rewriting was authorized, also inspect
  `git reflog -3 --date=iso` and report the rewrite explicitly.
- Never force-push, rewrite remote history, bypass hooks, bypass signing, or
  skip validation unless the user explicitly asks and the target is
  unambiguous.

## Create A Worktree

First run the reuse gate for PR work:

```bash
git worktree list --porcelain
```

Reuse an existing worktree when it is clean and any of these are true:

- its branch is the live PR head branch;
- its path is `tmp/worktrees/pr-<number>` for a read-only PR review;
- it is detached at the current PR head SHA.

If a matching worktree exists but is dirty, stop and report the path as
contaminated instead of creating a duplicate for read-only review. Create a
new scratch worktree only for explicitly requested write work where the dirty
state cannot be safely reused.

For maintaining an open PR head branch:

```bash
git fetch origin <head-branch> --prune
git worktree add -B <head-branch> tmp/worktrees/<head-branch-slug> \
  origin/<head-branch>
```

For parallel agents on the same PR, keep the real PR branch in one canonical
worktree and create per-agent scratch branches:

```bash
git fetch origin <head-branch> --prune
git worktree add -B <head-branch> tmp/worktrees/<head-branch-slug> \
  origin/<head-branch>
git worktree add -B <head-branch-slug>-agy tmp/worktrees/<head-branch-slug>-agy \
  origin/<head-branch>
git worktree add -B <head-branch-slug>-copilot tmp/worktrees/<head-branch-slug>-copilot \
  origin/<head-branch>
```

For short-lived PR reproduction work:

```bash
git fetch origin \
  pull/<number>/head:refs/remotes/origin/pr-<number>-head \
  pull/<number>/merge:refs/remotes/origin/pr-<number>-merge

git worktree add -B <branch-name> tmp/worktrees/<worktree-slug> \
  refs/remotes/origin/pr-<number>-merge
```

For a new PR publication branch:

```bash
git fetch origin main --prune
git worktree add -B <branch-name> tmp/worktrees/<branch-slug> origin/main
```

## Readiness Checklist

Run this immediately after every `git worktree add` and before reading,
editing, linting, testing, committing, pushing, or replying from the worktree.

For implementation, PR publication, or review-comment work, readiness proof is
part of the phase contract. Before the first code edit, validation command, git
write, PR-body write, or reviewer request from a worktree, record or report the
exact readiness evidence that matters for the task: worktree path and branch,
clean/dirty state, Husky helper and `core.hooksPath`, backend linter path and
version when `backend/` may be touched, and any known setup fallback. Do not
treat later successful validation as retroactive proof that the worktree was
ready at the start.

This checklist is not optional setup documentation. It is the mandatory first
response to worktree-local runtime failures. If Husky, mise, Go, Node, linter,
wrapper, hook, or dependency setup behaves unexpectedly, stop and apply the
`AGENTS.md` Runtime Failure Triage path before retrying commands. Do not run a
sequence of alternate shell commands from memory, do not switch to the root
checkout for convenience, and do not treat a setup failure as product evidence
until this readiness checklist has been checked against the exact worktree.

If you discover only after a failed hook, wrong linter, missing binary, or
misrouted install that readiness was skipped, run the `AGENTS.md` Violation
Correction Workflow. Name the skipped readiness gate, repair the worktree setup
before retrying the real command, and update this skill only when the missed
decision point is not already covered here.

Treat the repo-owned readiness helper as the day-zero worktree prerequisite,
not optional setup documentation. Immediately after creating or selecting a
repo-local worktree, run:

```bash
scripts/dev/prepare-worktree-readiness.sh <repo-root>/tmp/worktrees/<slug>
```

The helper is the first-line path because it refuses ambiguous worktree paths,
bootstraps Husky in the target worktree, reads the target branch's backend
linter pin from that worktree, installs `golangci-lint` into that worktree's
`backend/bin`, and keeps the Go cache in that worktree. Do not run `mise -C`
or a root-checkout install task as the normal readiness path; `mise` can climb
to a parent checkout and mutate the wrong `backend/bin` when the target branch
does not contain `.mise.toml`.

A worktree is not ready until the helper has completed and the target worktree
has `.husky/_/husky.sh`, `core.hooksPath` equal to `.husky`, a branch-pinned
`backend/bin/golangci-lint` when `backend/` exists, and no tracked dirty files.

If the worktree contains `.mise.toml`, run `mise trust <worktree>/.mise.toml`
or otherwise resolve the trust prompt for that exact path before invoking
wrappers, validation, package commands, or git hooks. Treat a mise trust
failure as local setup, not product failure.

If the readiness helper fails, diagnose from the target worktree only:

```bash
git -C <repo-root>/tmp/worktrees/<slug> rev-parse --show-toplevel
git -C <repo-root>/tmp/worktrees/<slug> rev-parse --abbrev-ref --symbolic-full-name @{u}
git -C <repo-root>/tmp/worktrees/<slug> config --get core.hooksPath
test -f <repo-root>/tmp/worktrees/<slug>/.husky/_/husky.sh
rg -n "version: v[0-9.]+" <repo-root>/tmp/worktrees/<slug>/.github/workflows/backend-validate.yml
rg -n "golangci-lint@" <repo-root>/tmp/worktrees/<slug>/backend/tools.go
cd <repo-root>/tmp/worktrees/<slug>/backend
go env GOBIN GOPATH GOENV
<repo-root>/tmp/worktrees/<slug>/backend/bin/golangci-lint --version
```

The reported linter version must match the version pinned in that target
worktree's `.github/workflows/backend-validate.yml` or explicit tool pin. For
PR or worktree validation, the exact target worktree or PR head SHA is the
source of truth. Do not use the root checkout, `local-dev-reference`, a
user-global `golangci-lint`, or memory as CI-parity proof for another branch.
Stale v1 binaries cannot read the repo's v2 configuration, and newer binaries
from a different branch can also be wrong. The pre-commit hook prefers
`backend/bin/golangci-lint`, so fixing this setup once per worktree keeps
commits aligned with that branch's CI.

If manual repair is required, install the pinned version into the
worktree-local `backend/bin` with absolute `GOBIN` and `GOPATH` values, then
verify the worktree binary. For `golangci-lint` v2, the Go install module path
must include `/v2`, even if an older branch's `backend/tools.go` still shows
the pre-v2 module path:

```bash
GOBIN=<repo-root>/tmp/worktrees/<slug>/backend/bin \
GOPATH=<repo-root>/tmp/worktrees/<slug>/backend/.gopath \
  go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@vX.Y.Z
ln -sf golangci-lint <repo-root>/tmp/worktrees/<slug>/backend/bin/golangci-lint-v2
<repo-root>/tmp/worktrees/<slug>/backend/bin/golangci-lint --version
```

Replace `vX.Y.Z` with the version read from the current branch's workflow or
tool pin. Do not guess the old non-v2 module path for a v2 version.

Scope toolchain mutations to the active worktree first. Do not copy a linter
binary into the root checkout, a global tool directory, or multiple unrelated
worktrees until you have proven each target branch pins that same version and
the task explicitly requires that broader surface.

After installing, verify the binary from the worktree path, not from `$PATH`:

```bash
test -x <repo-root>/tmp/worktrees/<slug>/backend/bin/golangci-lint
<repo-root>/tmp/worktrees/<slug>/backend/bin/golangci-lint --version
```

If the install task reports success but the binary is missing, treat that as a
local environment misroute. Inspect `pwd`, `git -C <worktree> rev-parse
--show-toplevel`, `go env GOBIN GOPATH GOENV`, and any inherited `GOBIN` before
running another install command. Do not use a root-checkout binary as worktree
readiness proof unless you explicitly state it is a fallback and separately
repair or report the worktree-local setup gap.

```bash
git -C <repo-root>/tmp/worktrees/<slug> status --short --branch
```

If GitHub CLI fallback, PR edits, thread mutation, or push may be needed,
validate auth from the root checkout. Resolve `<gh-auth-session-helper>`
through the `github-workflow` auth lane skill:

```bash
<gh-auth-session-helper> summary
<gh-auth-session-helper> gh api user --jq .login
```

Do not run a Husky-only repair as readiness proof. The readiness helper owns
Husky plus branch-pinned backend linter setup together. Use manual Husky
commands only while diagnosing a helper failure, and rerun
`scripts/dev/prepare-worktree-readiness.sh <repo-root>/tmp/worktrees/<slug>`
before treating the worktree as ready.

If the worktree may touch `app/`, install branch-local frontend dependencies:

```bash
frontend_modules=<repo-root>/tmp/worktrees/<slug>/app/node_modules
if test -L "$frontend_modules"; then
  echo "error: refuse shared app/node_modules symlink: $frontend_modules" >&2
  exit 1
fi
if test -e "$frontend_modules"; then
  find "$frontend_modules" -depth -delete || {
    echo "error: could not remove worktree-local dependencies: $frontend_modules" >&2
    exit 1
  }
fi
yarn --cwd <repo-root>/tmp/worktrees/<slug>/app install --frozen-lockfile --non-interactive
git -C <repo-root>/tmp/worktrees/<slug> diff --exit-code -- app/yarn.lock
```

Do not symlink `app/node_modules` from another checkout. That can mix branch
dependency graphs and create false ESLint, Prettier, Jest, or Husky failures.
If the frozen install changes `app/yarn.lock`, stop and diagnose manifest/lock
drift instead of treating the worktree as ready.

Before frontend validation, reject a shared `.next` symlink and remove only a
non-writable worktree-local build cache:

```bash
frontend_next=<repo-root>/tmp/worktrees/<slug>/app/.next
if test -L "$frontend_next"; then
  echo "error: refuse shared app/.next symlink: $frontend_next" >&2
  exit 1
fi
if test -e "$frontend_next"; then
  nonwritable_next_path=$(find "$frontend_next" ! -writable -print -quit) || {
    echo "error: could not inspect build cache ownership: $frontend_next" >&2
    exit 1
  }
  if test -n "$nonwritable_next_path"; then
    find "$frontend_next" -depth -delete || {
      echo "error: could not remove non-writable build cache: $frontend_next" >&2
      exit 1
    }
  fi
fi
```

Do not change ownership recursively or delete broader app/repository paths to
repair a generated-cache permission failure.

If `.husky/_/husky.sh` is missing, rerun the readiness helper and then rerun
the real git command.
Do not default to `--no-verify`, `HUSKY=0`, or `core.hooksPath=/dev/null`
unless the user explicitly authorizes a hook bypass after you report the gap.
If you had to bypass hooks once because Husky was missing, stop and repair the
worktree before any further git write path instead of normalizing the bypass.

Some older PR branches still carry a pre-commit hook that sources `nvm.sh`
directly. If a commit fails with `nvm is not compatible with the npm config
"prefix"` because the shell is currently using mise's Node/npm, rerun the
commit with NVM's Node 18 binary first on `PATH` instead of bypassing hooks:

```bash
PATH="$HOME/.nvm/versions/node/v18.20.8/bin:$PATH" git -C <worktree-path> commit
```

This preserves the hook while avoiding mise's global npm prefix. The root
checkout hook uses `mise exec` and should not need this workaround.

If a worktree commit fails with `N/A: version "N/A -> N/A" is not yet
installed`, treat it as the same class of local Node/Husky setup failure, not a
product failure. First try the worktree readiness repair path or the NVM Node
18 `PATH` workaround above. Use `--no-verify` only when the user authorized
the git write, the hook failure is clearly local setup noise, and the
equivalent validation commands for the changed surface have already passed;
state that bypass reason in the handoff.

When a hook was recently narrowed, verify what it actually narrows before
claiming the branch should commit cleanly. For example, `golangci-lint
--new-from-rev=HEAD` scopes Go lint to lines/files new since the current commit;
it does not ignore newly added files in a large aggregate commit, and it does
not affect separate hooks such as `detect-secrets`, `hadolint`, or Prettier.

## Post-Push PR Body Gate

When pushing to an existing PR branch, do not close the task until you have
checked whether the PR title/body is stale.

After every push or force-push to an open PR branch:

1. Re-read the live PR title/body.
2. Compare it against the pushed diff, commit count, validation results, CI
   state, stack/base status, and any changed operator behavior.
3. If the PR body has drifted, update it in the same pass.
4. If no PR body update is needed, say explicitly in the final response that the
   PR body was checked and is still accurate.

Use `github-workflow` for the authenticated PR read or update. This gate
applies even when the user only asked to commit, push, amend, squash, rebase,
or force-push. PR description freshness is part of PR publication closeout, not
an optional follow-up.

If an aggregate migration or local-only commit still needs `--no-verify`, separate
the failure classes: pre-existing unrelated lint, new-code lint, secret-scan
false positives, Dockerfile policy, and formatter churn.

## Push Boundary

Push from a worktree only when the user asks.
Creating a worktree, installing dependencies, running readiness checks, or
committing locally does not imply permission to publish the branch or set its
upstream.

A clear current push request does not require an autonomy acceptance packet.
Use the branch/topology/auth/readback checks below and proceed through the
owning publication or integration workflow. Force-push and history rewrite
still require exact current authorization, lease protection, and remote
readback. A push whose predictable normal effect mutates a critical shared
runtime/data/config/security surface is the separate critical-mutation case
described above.

Before pushing:

- when instruction or skill files are present, confirm the destination is
  `local-dev-reference`, a verified non-PR branch cut from it, or an explicitly
  requested main-based instruction-only PR branch. Instruction files are
  expected on the non-PR integration path; do not require an instruction-only
  PR classification there
- inspect branch topology with `git status --short --branch` and the remote
  ahead/behind relationship before selecting the push mode. Use a normal push
  for fast-forward publication. Use `--force-with-lease` only for intentional
  history rewrites such as rebase, squash, or amend, and name that reason in
  the handoff.
- for a new PR branch, prove the publication lane's final single-commit gate
  after pre-open reviews: recorded reviewed head, tree-equivalent squash, and
  exactly one commit over the intended base. This is distinct from maintenance
  of an already-open PR, where active review provenance may require separate
  finding-directed commits.
- If `git push` refuses because the configured upstream branch does not match
  the current branch, stop and inspect the current branch name and upstream.
  For `local-dev-reference` or its verified non-PR descendants, confirm the
  intended same-name remote integration branch and push explicitly to that
  branch. For an actual open-PR branch, also confirm the live PR head before an
  explicit push. Never follow a CLI hint that targets the base branch.
- confirm the worktree branch is the real PR head branch for PR maintenance or
  publication, not a short-lived `pr-<number>-...` reproduction branch
- for stacked PRs, confirm the live PR base branch and compare the diff against
  that base before pushing
- rerun the relevant domain validation
- ensure `.husky/_/husky.sh` exists
- ensure `git config --get core.hooksPath` still reports `.husky`
- use `github-workflow` auth lane from the root checkout when the shell lacks GitHub auth
- never print token values

Prefer root-shell execution with `git -C <worktree-path>` so auth and path
context are explicit.

### Explicitly Amending Local Commits on Existing PR Worktrees

Use this section only when the user explicitly asks to amend, squash, rewrite,
or force-push an existing PR worktree commit, or when a routed PR workflow
requires that exact rewrite. Local commits existing on a branch are not enough
to choose amend by default.

- Inspect first: `git log --oneline -5`, `git status --short --branch`.
- Make edits in the worktree as normal.
- Amend the latest local commit (`git commit --amend`). Use `--no-verify` only
  if Husky fails due to local environment noise (e.g. nvm/mise prefix); repair
  Husky when practical instead of normalizing the bypass.
- After amending, re-run the verification commands appropriate to the PR or
  worktree. When the PR involves workflows or configuration, this commonly
  includes the project's YAML parse, `actionlint`, and `git diff --check`
  commands (or whatever checks the PR itself recommends).
- Prefer `git push --force-with-lease` even when the user explicitly says
  "force push".
- When the task includes adding "agent handholding", "gotchas", or "footguns
  for future agents/reviewers", treat those documentation changes as first-class
  work and ensure they are included in the amended commit before pushing.

## Recovery Boundaries

If a worktree operation is interrupted, first inspect state without changing it:

```bash
git -C <worktree-path> status --short --branch
git -C <worktree-path> worktree list
ps -ef | grep '[g]it' || true
```

Use normal git recovery commands such as `git -C <worktree-path> rebase --abort`,
`merge --abort`, `cherry-pick --abort`, or `git worktree prune -v` when the
state clearly matches the command. Do not remove `.git/worktrees/**`, `.lock`
files, or worktree directories by hand unless the user explicitly approves that
destructive cleanup and you have verified no git process is still using them.

## Handoff Checklist

Before handoff:

- `git status --short --branch`
- for PR work, the live PR head branch, base branch, and local worktree slug
- `git diff --check`
- remove generated files, coverage files, copied `.env` files, and helper
  artifacts unless they are intended changes
- report local-vs-CI toolchain mismatches explicitly
