---
name: github-workflow
description: Use when example-app work needs authenticated GitHub primitives including GitHub MCP smoke tests, missing-field PR reads requested as a primitive, PR title or body mutation after publish-lane content preparation, thread replies or resolution, GitHub Actions job logs or artifacts, or gh CLI and API fallback through the repo auth helper.
---

<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-02 (same-actor unresolved-thread guard) -->

# GitHub Workflow

Use this skill as the Claude Code entry point for example-app GitHub
primitives. It keeps GitHub routing visible while lazy-loading the heavier read,
mutation, and auth references only after the task shape is known.

## First Reads

`CLAUDE.md` (which imports `AGENTS.md`) is loaded by default in this runtime, so
do not re-read it. Before repo-facing GitHub work, read `repo.md`, then this
skill, if you have not already. Those are live file reads; pasted context,
memory, or previous sessions do not replace them.

Then choose the smallest lane that matches the user's ask. Do not load every
reference file by default.

If the prompt starts from a PR URL/number or asks to summarize/review a pull
request, use `pr-workflow` first unless the user explicitly asks for a
GitHub primitive such as MCP smoke, `gh api`, PR metadata mutation, thread
mutation IDs, or Actions job logs.

## Route The Ask

| User ask | Reference to load | Operational boundary |
| --- | --- | --- |
| Read GitHub PR metadata, changed files, comments, reviews, statuses, check runs, or smoke-test the GitHub MCP read surface outside a PR-workflow ask | `references/pr-read.md` | Read-only authenticated GitHub state. Do not mutate GitHub or create a checkout. |
| Update PR title/body after publish-lane content preparation, request review, reply to or resolve review threads, mutate PR comments, or coordinate authenticated PR operations | `references/pr-operations.md` | Authenticated GitHub write operation. Fetch the required IDs and current PR state before writing. |
| GitHub MCP/tooling is auth-limited, missing fields, or a task needs `gh api`, `gh pr`, `gh run`, Actions logs, artifacts, or helper-backed auth | `references/gh-auth-session.md` | Use the bundled helper or repo-local mirror without sourcing `.envrc`; never expose tokens. |
| PR review, PR URL/number read-only summary, CI read/fix, review-comment worktree fixes, local PR gate selection, or bug-fix PR proof starts from a PR URL/number | `pr-workflow` | Defer to the PR workflow umbrella; it owns PR-shaped routing, worktrees, freshness, review packets, CI reproduction, and comment-fix sequencing. |

## Shared GitHub Rules

- Parse owner, repo, and resource ID before GitHub calls. Default to
  `example-org/example-app` only when the prompt omits owner/repo.
- Prefer the repo-configured GitHub MCP or active runtime GitHub tools for
  supported reads and writes.
- Name the active GitHub surface precisely when a tool fails. In Codex,
  `mcp__codex_apps__github` is a GitHub plugin connector exposed through MCP;
  that label is Codex-specific. Other harnesses must use their visible tool
  descriptor instead of importing Codex plugin terminology.
- A visible GitHub tool returning `404`, omitting fields, or lacking an
  operation is an auth-scope or capability result for that surface, not proof
  that GitHub MCP is absent. Fall back through the `gh` auth lane and say which
  surface failed.
- Plan GitHub reads before executing them. For PR-shaped tasks, collect the
  needed metadata, comments, review threads, changed files, branch heads, and
  check runs in one consolidated read pass where practical.
- When a GitHub MCP/tool call returns permission errors, omits required fields,
  or is unavailable in the harness, fall back directly to the `gh` auth lane or
  local git/file reads instead of retrying the same blocked call.
- If plain `gh` returns `401`, `Bad credentials`, or an auth-scope error,
  switch immediately to the repo helper through the `gh` auth lane. Do not keep
  retrying the stale token, and do not paste or print token values while
  diagnosing.
- For example-app Actions CI, never use `gh pr checks` or GraphQL
  `statusCheckRollup`, including as quicker confirmation, secondary,
  corroborating, or fallback evidence. Use branch workflow runs and exact
  head-SHA readback. If a GitHub GraphQL query is malformed, retry once only
  after naming and correcting a concrete query or variable defect. Never resend
  a materially identical query; repeated non-narrowing failure routes to loop
  control.
- Before creating or submitting a new PR review, identify the
  posting GitHub actor as this session's authenticated login from the GitHub
  surface that will mutate. Normalize `foo` and `foo[bot]` as one actor by ASCII
  case-folding and stripping one trailing `[bot]` suffix. If that login is
  unknown, fail closed: make no create-review or submit-review mutation and
  report `Pending Verification` for the missing posting login. Inspect
  unresolved review comments and threads. Treat the root review comment (the
  non-reply comment that opened the thread) as the thread owner. Only an
  unresolved and unaddressed thread whose normalized root-author login matches
  the posting actor blocks the new review mutation. If that root-author login
  is missing, fail closed because the thread cannot be proved foreign and
  report `Pending Verification` for the missing root-author login.
  Reply-author identities never transfer thread ownership: a foreign-root
  thread remains non-blocking even when the posting actor replied or a reply
  author login is missing, and a same-actor-root thread remains blocking
  regardless of reply authors. Other actors' unresolved threads do not block a
  first review from this posting actor. A request to add, post,
  or submit remaining or unique findings authorizes content only;
  it never waives this guard. Continue on the existing thread surface or
  report the exact blocker. State the authorization split explicitly:
  `Content authorization: yes; new-review authorization: no.` Content
  authorization is approval for later publication, not authority to publish
  immediately. Hold the unique finding until the guard clears; do
  not attach it to an unrelated existing thread. Use existing threads only
  for their own existing concerns. Do not collapse that distinction into a
  generic "do not post yet."
- Do not use rendered GitHub HTML as the source of truth for PR state,
  comments, checks, titles, bodies, branches, or thread state.
- PR title/body content is governed by the `pr-workflow` publication
  lane and PR template guide. Use this skill to execute the
  authenticated GitHub mutation only after the reviewer-facing content has been
  prepared through that lane.
- Use `references/gh-auth-session.md` only when the active GitHub surface lacks
  the needed field/operation, returns auth-limited data, or the task explicitly
  needs `gh`.
- If a high-level GitHub command such as `gh pr view --json` lacks a field
  needed for PR truth, escalate to `gh api graphql` through the auth lane before
  reporting a tooling limitation. For PR review threads, GraphQL
  `repository.pullRequest.reviewThreads` is the authoritative fallback for
  resolved and outdated state.
- Use `scripts/dev/gh-auth-session.sh` when the repo-local mirror is available;
  otherwise use `.claude/skills/github-workflow/scripts/gh-auth-session.sh`.
- Never print tokens, cookies, auth headers, or raw secret-bearing shell output.
- Keep reviewer-facing GitHub text free of local paths, worktree names, agent
  internals, and unverified claims.

## Replaced Skill Names

This skill consolidates the retired first-class Claude GitHub primitive aliases:

- `github-pr-read-mcp`
- `github-pull-request-tools`
- `gh-auth-session`

These names are retired aliases, not paths to open. Do not try to read
`.claude/skills/<old-name>/SKILL.md`; load this skill plus the matching
`references/*.md` lane instead.

## Closeout

Name the GitHub lane used, source of truth, commands or tools used, GitHub
write state, and any `Pending Verification` surfaces. If no GitHub mutation
happened, say so plainly.
