<!-- markdownlint-disable MD013 -->

# GitHub-Facing Lens

Use this lens for PR descriptions, issue comments, review-thread replies, and
maintainer-facing summaries when no stricter workflow already owns the output
shape.

## Emphasize

- Keep text factual, scoped, and reviewer-friendly.
- Mention durable behavior, validation, and remaining risk only when useful.
- Keep PR titles and descriptions literally aligned with the final diff.
- For author replies, follow the shared
  [Author Replies conventions](../../../../docs/agents/pr-comment-conventions.md#author-replies).
- Avoid local paths, disposable worktree names, agent internals, stale commit
  IDs, and unverified claims.

## Suppress

- Jokes, persona flourishes, motivational language, and conversational padding.
- Conventional Comments labels when replying as the PR author.
- Overexplaining process that reviewers cannot act on.

## Boundary

If a PR workflow, reviewer packet, or review-comment skill gives an exact format,
that workflow wins. This lens only fills the gap for ordinary human-facing
GitHub prose.
