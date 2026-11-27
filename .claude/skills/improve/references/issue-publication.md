<!-- markdownlint-disable MD013 MD060 -->

# Improve Issue Publication

Use only when the user explicitly includes `--issues` with an Improve
planning variant. The selected audit or planning reference creates the advisory
artifact first.

Issue creation is an external GitHub write. Before publishing:

1. Resolve the selected `plan_root` and verify the issue body against the
   current plan.
2. Re-enter `work-orchestration` for the external-write boundary and
   use `github-workflow` for authenticated mutation mechanics.
3. Check repository visibility.
4. If the repository is public and the plan contains a security vulnerability,
   credential location, personal data, private operational detail, or other
   sensitive evidence, stop for explicit confirmation before publication.
5. Search for an existing issue representing the same plan and avoid
   duplicates.
6. Redact secrets and machine-local paths; use repository-relative evidence.
7. Create the issue, record its URL in the advisor-owned index, and read back
   the rendered issue.

The `--issues` flag authorizes only issue creation for the selected plans. It
does not authorize labels, milestones, assignees, source edits, commits, pushes,
PRs, releases, or production actions unless separately requested and routed.

If GitHub auth or visibility cannot be verified, leave publication
`Pending Verification` and preserve the local plan without inventing a URL.
