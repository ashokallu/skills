<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-04 (title aligned to mirrors; retired-alias H1 removed) -->

# GitHub PR Read Reference

## Purpose

Use the GitHub MCP server configured for this repo as the source of truth for
read-only PR triage in the active runtime.

Do **not** start from GitHub HTML when the user already gave a PR URL or number.

This skill keeps `-mcp` in its name because the MCP read surface is the durable
domain boundary: its job is to retrieve PR state through the repo-configured
GitHub MCP, then hand off to narrower workflow skills when action is needed.

## When to use

Apply this skill when the task asks for any of these on a PR:

- metadata
- changed files or patch excerpts
- comments or reviews
- statuses or check runs
- smoke-testing GitHub MCP access

## Tool mapping

Prefer the repo-configured GitHub MCP read operations exposed by the active
runtime. Tool-call names are runtime-specific; choose the callable operation
from the visible tool descriptor instead of assuming a hardcoded prefix.
The method labels in the read patterns below describe the project GitHub MCP
API shape; map them to the active runtime's equivalent callable surface.
In Codex, `mcp__codex_apps__github` is a GitHub plugin connector exposed
through MCP; that label is Codex-specific. Other harnesses must describe their
own visible GitHub tool surface and must not generalize Codex plugin wording.

- PR metadata
- changed files
- PR issue comments
- review summaries
- inline review threads and resolved/outdated state
- commit status contexts
- Checks API jobs
- pull request list or search operations for discovery
- repo file contents for repo-level smoke tests

`Pending Verification`:

- active/open PR context helpers may be runtime-specific; when unavailable,
  parse owner, repo, and PR number explicitly from the user-provided URL or
  branch context

## Non-negotiable rules

- Parse owner, repo, and PR number from the URL immediately.
- Treat GitHub MCP data as authoritative over GitHub webpage fetches.
- For comment tasks, fetch `get_comments`, `get_reviews`, and `get_review_comments` together.
- Do **not** infer "no comments" from `get_comments: []`.
- For thread mutation planning, start with `get_review_comments` for thread
  state and context, but do not assume it exposes mutation IDs. If the
  `PRRT_...` thread node ID or numeric root review comment ID is missing, use
  `github-workflow` `references/gh-auth-session.md` with GitHub API/GraphQL to fetch only those fields before
  using write tools.
- For CI tasks, do not start with `get_status`/`get_check_runs`. Those map to
  the GraphQL `statusCheckRollup`/REST check-runs surfaces that can return
  `403`/`Resource not accessible by personal access token` for this repo's
  token. Use `pr-workflow` `references/ci-read.md` as the canonical CI
  read owner. Treat `get_status`/`get_check_runs` as optional secondary reads
  only after that lane's head-pinned workflow-run path is attempted or marked
  `Pending Verification`.
- If `get_check_runs` returns `403`, report it as a token-permission problem, not a missing PR.

## Read patterns

### What changed in this PR?

1. `get`
2. `get_files`
3. optionally `get_status`

### What comments are on this PR?

1. `get_comments`
2. `get_reviews`
3. `get_review_comments`
4. separate issue comments, review summaries, and inline threads in the output

### Is this PR green?

1. `pr-workflow` `references/ci-read.md` head-pinned workflow-run
   list/watch path
2. `get_status`/`get_check_runs` only as an optional secondary read
3. report live failing contexts or say explicitly that checks are passing

### Is the GitHub MCP server alive?

1. `list_pull_requests`
2. `get_file_contents` on a known file from `main`

## Practical fallback

If the repo-configured GitHub MCP returns `404` for a private PR resource that
authenticated `gh` can read, treat that as MCP auth/config drift and fall back
to `gh` instead of GitHub HTML. Report the exact surface that returned `404`;
do not say GitHub MCP is absent when a visible tool returned an auth-scope or
capability error. Do not use an alternate GitHub plugin or connector as the
fallback unless its installation scope has been revalidated against the target
repo.
