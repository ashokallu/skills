<!-- markdownlint-disable MD012 MD013 MD060 -->
<!-- Last verified: 2026-07-31 (workflow-run CI read boundary) -->

# GitHub Auth Session Reference

Use this reference when the task needs `gh` against
`example-org/example-app` and the built-in GitHub tools are not
enough.

## USE FOR

- authenticated `gh api`, `gh pr`, or `gh run` fallback work
- GitHub MCP reads that return `404`, auth-limited data, or missing fields
- Actions job URLs that require log or artifact inspection through `gh`
- GitHub Actions check-run or status-rollup APIs that return token permission
  errors, where `gh run list`, `gh run watch`, or job-log fallback may still
  work

## DO NOT USE FOR

- normal PR metadata, comments, reviews, files, or checks when MCP tools work
- generic git push mechanics; use the workflow or worktree skill first
- reading `.envrc` by sourcing it directly

## Default Rule

Use GitHub MCP / GitHub PR tools first for normal PR, issue, review-comment, and status-check work.

Use the bundled `.codex/skills/github-workflow/scripts/gh-auth-session.sh`
helper when:

- a required GitHub operation is not exposed by the current tool surface
- a GitHub connector endpoint returns `404`, auth-limited data, or missing fields
- the task specifically needs `gh api`, `gh pr`, or another authenticated CLI flow

Do not `source .envrc` just to get GitHub auth. Use the helper script instead.
When working inside example-app, the repo-local mirror at
`scripts/dev/gh-auth-session.sh` may also be used if present.

For old or `origin/main`-based feature worktrees, the repo-local helper or
`.envrc` may be missing even though the root `local-dev-reference` checkout has a
working helper and token context. In that case, run GitHub reads or mutations
from the root checkout with `scripts/dev/gh-auth-session.sh`, but pass explicit
`--repo`, `--head`, `--base`, branch, PR, or run identifiers so the operation
targets the feature branch rather than the root branch.

## MCP 404 Triage

For private repo reads, a GitHub MCP `404 Not Found` is often an auth-surface
problem, not evidence that the repo, workflow, run, branch, or file is missing.
Report this as a failure of the exact visible surface. In Codex,
`mcp__codex_apps__github` is a GitHub plugin connector exposed through MCP;
that label is Codex-specific and should not be copied into other harnesses
unless their tool descriptor says the same thing. Do not say GitHub MCP is
absent when a visible GitHub tool exists but returned `404`, omitted fields, or
lacked the needed operation.
Before concluding a resource is absent:

1. Verify the same endpoint with `references/gh-auth-session.md`, for example:

   ```bash
   .codex/skills/github-workflow/scripts/gh-auth-session.sh gh api \
     repos/example-org/example-app/actions/workflows
   ```

2. Check whether the MCP host process actually inherited the token env it
   expects. Restart the host after env changes.
3. If GitHub MCP and `references/gh-auth-session.md` disagree, treat it as an auth-scope
   mismatch first. Compare which token variable and process environment the
   active runtime sees before changing repo workflow guidance.

## Helper

Bundled path: `.codex/skills/github-workflow/scripts/gh-auth-session.sh`

Repo-local mirror: `scripts/dev/gh-auth-session.sh`

This helper:

- reads only `GH_TOKEN`, `GITHUB_PAT_TOKEN`, and `COPILOT_GITHUB_TOKEN` from
  the active environment or `.envrc`
- does not execute the rest of any env file
- injects `GH_TOKEN` and `GITHUB_TOKEN` only for the wrapped command

Token lookup order:

1. `GH_TOKEN`
2. `GITHUB_PAT_TOKEN`
3. `COPILOT_GITHUB_TOKEN`

## Commands

- `.codex/skills/github-workflow/scripts/gh-auth-session.sh summary`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh auth status`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh api user`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh pr view <pr-number> --repo example-org/example-app`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh api repos/example-org/example-app/issues/comments/<comment-id> -X DELETE`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh api repos/example-org/example-app/actions/runs/<run-id>/jobs`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh api repos/example-org/example-app/actions/runs/<run-id>/artifacts`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh run list --repo example-org/example-app --branch <head-branch> --limit 10`
- `.codex/skills/github-workflow/scripts/gh-auth-session.sh gh run watch <run-id> --repo example-org/example-app --exit-status`
- `GH_PAGER=cat PAGER=cat LESS=FRX .codex/skills/github-workflow/scripts/gh-auth-session.sh gh run view <run-id> --repo example-org/example-app --job <job-id> --log-failed > tmp/gha-job-<job-id>.log`
- `GH_PAGER=cat PAGER=cat LESS=FRX .codex/skills/github-workflow/scripts/gh-auth-session.sh gh run download <run-id> --repo example-org/example-app -n smoke-test-results-json -D tmp/gha-run-<run-id>-smoke`

Use `shell` only for interactive shell sessions or when multiple `gh` commands
need the token in the same process. It is disabled by default because it prints
raw token exports:

```bash
eval "$(GH_AUTH_SESSION_ALLOW_SHELL=1 .codex/skills/github-workflow/scripts/gh-auth-session.sh shell)"
gh api user
gh pr view 123
```

For non-interactive scripting or single commands, wrap each `gh` invocation
directly:
`.codex/skills/github-workflow/scripts/gh-auth-session.sh gh api user`.

## Non-interactive output discipline

Treat `gh` as pager-prone and terminal-interactive unless you deliberately make
it non-interactive.

- Prefer `gh api --jq`, `--json`, or explicit field selection for structured
  reads.
- Set `GH_PAGER=cat PAGER=cat LESS=FRX` for commands that might page, switch to
  an alternate screen, or wait for terminal input.
- Prefer redirecting long logs, JSON, and job output to a file under `tmp/`
  and reading that file afterward instead of streaming everything live into the
  terminal.
- Avoid `gh` flows that open a browser, editor, or full-screen viewer during
  unattended review work.

If the first `gh` attempt lands in a pager, stop and rerun in non-interactive
mode instead of trying to recover from the pager session mid-workflow.

## Safety

- Never print raw token values into chat, issue comments, or logs unless the user explicitly asks for the token itself.
- Prefer `summary` when you need to verify auth wiring.
- Prefer the `gh` wrapper for scripts; use `shell` only in a deliberate
  interactive session because it prints token-bearing exports to stdout.
- Keep reviewer-facing GitHub text free of local paths, worktree names, and repo-internal execution details.
- If the helper cannot find a token in the environment or `.envrc`,
  report that fact directly instead of falling back to unauthenticated `gh`.
- In a fresh worktree flow, validate this helper from the root checkout before
  code edits when the task may need `gh` fallback, GitHub mutation, thread
  resolution, PR creation/editing, or push access.
- When validating auth in a restricted shell, prefer an actual API read such as
  `gh api user` or `gh repo view <repo>` over `gh auth status` alone. A live
  API call proves token + network + host access together.
- If GitHub MCP reads work but local `git` or `gh` push still fails, treat that
  as an auth-surface split rather than proof that GitHub itself is unavailable.
- If the helper cannot find a token from a feature worktree, retry from the
  root checkout before declaring GitHub auth unavailable. This is especially
  common when opening or editing a PR for a branch cut from an older
  `origin/main` where `scripts/dev/gh-auth-session.sh` or `.envrc` is absent.

## GitHub Actions job URL workflow

When the user gives a GitHub Actions job URL such as:

```text
https://github.com/example-org/example-app/actions/runs/<run-id>/job/<job-id>
```

prefer this sequence:

1. Parse `run-id` and `job-id` from the URL.
2. Save job metadata first so you can see the failed step name and which later
   steps were skipped:

    ```bash
    .codex/skills/github-workflow/scripts/gh-auth-session.sh gh api \
      repos/example-org/example-app/actions/runs/<run-id>/jobs \
      > tmp/gha-run-<run-id>-jobs.json
    ```

3. Disable paging for `gh run view` so the terminal does not jump into an
   alternate buffer, then save the failed-step log to `tmp/`:

    ```bash
    GH_PAGER=cat PAGER=cat LESS=FRX \
    .codex/skills/github-workflow/scripts/gh-auth-session.sh gh run view <run-id> \
      --repo example-org/example-app \
      --job <job-id> \
      --log-failed \
      > tmp/gha-job-<job-id>.log
    ```

4. For smoke, visual, or other artifact-heavy workflows, list and download the
   smallest JSON artifacts before pulling multi-megabyte HTML reports:

    ```bash
    .codex/skills/github-workflow/scripts/gh-auth-session.sh gh api \
      repos/example-org/example-app/actions/runs/<run-id>/artifacts \
      > tmp/gha-run-<run-id>-artifacts.json

    GH_PAGER=cat PAGER=cat LESS=FRX \
    .codex/skills/github-workflow/scripts/gh-auth-session.sh gh run download <run-id> \
      --repo example-org/example-app \
      -n smoke-test-results-json \
      -D tmp/gha-run-<run-id>-smoke
    ```

5. Read the jobs JSON before the raw log. The jobs API tells you which step
   actually failed; the log tells you the failing wrapper step; the downloaded
   Playwright JSON artifact often tells you the exact failing spec/assertion.

6. For artifact-producing workflows that feed PR evidence, inspect the
   downloaded summary or JSON artifact before updating the PR body or reporting
   the workflow as product validation. A successful runner can still produce a
   placeholder, skipped, stale, or non-probing artifact.

7. If a downloaded artifact only contains a `cliArgs.note` plus `suites: []`,
   treat it as a workflow-generated placeholder rather than real test output.
   That usually means the artifact path was preserved even though the relevant
   Playwright step never produced results.

## PR Branch Workflow Run Reads

When the task starts from a example-app PR and needs GitHub Actions CI
state, use the branch workflow surface as the primary read path. Start with the
PR head branch and head SHA, then list workflow runs for that branch:

```bash
.codex/skills/github-workflow/scripts/gh-auth-session.sh gh pr view <pr-number> \
  --repo example-org/example-app \
  --json headRefName,headRefOid

.codex/skills/github-workflow/scripts/gh-auth-session.sh gh run list \
  --repo example-org/example-app \
  --branch <head-branch> \
  --limit 10

.codex/skills/github-workflow/scripts/gh-auth-session.sh gh run watch <run-id> \
  --repo example-org/example-app \
  --exit-status
```

This avoids the known token restrictions on `gh pr checks`, GraphQL
`statusCheckRollup`, and REST check-run reads in this repo. Never call
`gh pr checks` or request `statusCheckRollup`; they are not fallback reads.
REST check-run reads remain optional secondary evidence only when branch
workflow runs are insufficient, and a permission failure closes that path. If
`gh run watch` says annotations are forbidden, keep watching; use the job status
and final run result as evidence, then fetch failed job logs only if the run
fails.

This helper still uses GitHub authentication. It does not grant Okta-backed
access to Terraform Cloud or SAST provider detail pages, private Terraform
Cloud module registry operations, remote state, plan, or apply. For failed
Terraform/SAST provider checks, report provider details as `Pending
Verification` and ask the user for copied logs, screenshots, exported
artifacts, or, for Terraform state evidence, stop the state-dependent work until
the user supplies a manually downloaded local state file path. Staging state
downloads are available to the user at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-test/states`;
Staging state downloads are at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-stg/states`;
Production state downloads are at
`https://app.terraform.io/app/example-org/workspaces/example-terraform-services-prd/states`.

`gh run list` rows are not head-pinned: the listing omits the commit SHA, and a
branch can carry older runs from earlier pushes. Before citing a workflow run as
CI evidence for a specific reviewed head, read `actions/runs/<run-id>` with the
helper (add `--jq '.head_sha'`) and cite only runs whose `head_sha` matches the
reviewed head. This is what lets a single-head review packet trust each CI row.

## Typical Flow

1. Try GitHub MCP tools first.
2. If a needed write or read path is unavailable, run the helper with `gh`.
3. Validate the helper-backed auth path with `gh api user` before touching
   worktree code that will later require a push or mutation-heavy command.
4. Use `gh api` for exact REST or GraphQL calls.
5. After `gh pr create`, `gh pr edit`, reviewer requests, comments, or branch
   force-pushes, read back the live PR or ref metadata and verify title, body,
   base/head, head SHA, or requested-reviewer state before reporting success.
6. Report outcomes without exposing secrets.
