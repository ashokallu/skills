<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-17 -->

# pr-comments-read-mcp

## Purpose

Use this skill for read-only PR comment triage through the GitHub MCP server
configured for this repo.

GitHub splits PR discussion into multiple surfaces. Pull all of them before
claiming a PR has no comments.

This skill keeps `-mcp` in its name because the MCP read surface is the durable
domain boundary: its job is to inspect PR comment data without creating a
worktree, editing files, or mutating GitHub state.

## USE FOR

- read-only PR comment, review summary, and inline thread inspection
- deciding whether unresolved review threads still matter
- summarizing comment surfaces without creating a worktree or editing files

## DO NOT USE FOR

- fixing valid review comments; use `references/comments-worktree.md`
- creating a worktree, preparing author replies, or resolving threads;
  use `references/comments-worktree.md`
- CI failures or check runs; use the PR CI skills
- GitHub CLI fallback unless MCP reads are auth-limited; use `github-workflow` `references/gh-auth-session.md`

## Required read batch

For a specific PR URL or number, use the active runtime's GitHub MCP read
operations to fetch these together:

The labels describe the project GitHub MCP data surfaces; map them to the
active runtime's equivalent callable surface.

1. PR issue comments
2. PR review summaries
3. inline review comments or review threads

## Review Thread Discovery (Default Behavior)

When the user states that a PR has review comments (without supplying any
specific thread links, `discussion_r` IDs, or `pullrequestreview-XXXX`
IDs), you **must** fully and independently discover the threads yourself.

Do not wait for the user to point at individual comments.

When the user provides a `pullrequestreview-<id>` URL, treat it as a review
summary pointer, not as the actionable inline thread itself. Fetch all review
threads and map each thread back to its originating
`comments.nodes[].pullRequestReview.databaseId` before summarizing what that
review still requires.

- Start with the required MCP read batch above. When the task needs complete
  thread inventory, unresolved-thread triage, author attribution, or a
  read-only ownership recommendation, continue with `github-workflow` `references/gh-auth-session.md` plus
  `gh api graphql` for `repository.pullRequest.reviewThreads` before
  summarizing or routing.
- If a PR prompt mentions Copilot comments, reviewer comments, unresolved
  threads, or review-comment actionability, do not stop at `gh pr view`
  review summaries or REST review comments. Use the GraphQL thread surface
  unless the active MCP already provides equivalent `isResolved` and
  `isOutdated` thread state.
- If GitHub MCP cannot return review-thread nodes with `isResolved` and
  `isOutdated`, use the authenticated GraphQL `reviewThreads` query as the
  fallback path. Do not substitute REST `/pulls/<pr-number>/comments` as the
  closure-state source: that endpoint returns inline comment content but not
  thread-level resolved/outdated state.
- Use a properly paginated GraphQL query on
  `repository.pullRequest.reviewThreads` to retrieve the complete set.
- For every thread, inspect the first comment to determine the originating
  `pullRequestReview` so you can clearly attribute threads to the exact
  review submission that created them, especially when automated reviewers
  submit multiple reviews on one PR.
- Always follow pagination until `hasNextPage` is false.
- Prioritize unresolved and non-outdated threads, especially those authored by
  automated reviewers or requested human reviewers.
- In review packets, all inline comments and review summaries must map to their
  exact locations at the single target head SHA. If the branch head changes
  while fetching, discard old thread data and restart mapping against the new
  head SHA.
- Only after you have a complete, attributed picture should you summarize
  findings, classify comments, and route to the appropriate action skill
  (e.g. `references/comments-worktree.md`) if fixes or replies are needed.

Direct links provided by the user are supplementary information only. The
default expectation is that you will locate and triage everything on your own.

## Interpretation rules

- `get_comments` covers issue-style PR discussion comments.
- `get_reviews` covers review summary entries.
- `get_review_comments` covers inline review threads and their thread state.
- REST `/pulls/<pr-number>/comments` covers inline comment records only; it
  does not prove whether a review thread is resolved, unresolved, active, or
  outdated.
- Do **not** report "no actionable comments" just because `get_comments` is empty.
- Separate these surfaces clearly in the answer.
- Prefer unresolved, non-outdated inline threads when identifying what still matters.
- If every inline thread is resolved, say that explicitly.

## Suggested output shape

Summarize in this order:

1. issue comments count
2. review summaries count and authors
3. inline thread count with resolved/outdated state
4. a short list of still-relevant threads, if any

## Read-only stop condition

If `get_comments` is empty but `get_review_comments` shows only resolved
threads, summarize the comment surfaces and stop instead of proposing code
changes.

Tooling note:

- Tool-call names are runtime-specific. Use the active runtime's visible
  GitHub MCP descriptor instead of assuming a hardcoded callable prefix.
- In Codex, `mcp__codex_apps__github` is a GitHub plugin connector exposed
  through MCP; that label is Codex-specific. Other harnesses must describe
  their own visible GitHub tool surface instead of importing Codex plugin
  terminology.
- If private PR review reads return `404` while authenticated `gh` can read the
  same repo resource, treat that as MCP auth/config drift and fall back to
  authenticated `gh` instead of GitHub HTML. Report the exact surface that
  returned `404`; do not say GitHub MCP is absent when a visible tool returned
  an auth-scope or capability error.
- Do not use an alternate GitHub plugin or connector as the fallback unless its
  installation scope has been revalidated against the target repo.
