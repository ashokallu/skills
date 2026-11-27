---
name: pull-request-workflow
description: Prepare, inspect, review, or verify a pull request and its checks.
---

# Pull Request Workflow

1. Resolve the repository, PR number, base branch, and head commit. Inspect the diff at that head.
2. For a draft, summarize the change, motivation, and verification. Keep the description aligned with what the diff actually does.
3. For check triage, confirm the run belongs to the inspected head. Identify the failing job and first relevant failure before proposing a fix.
4. For review, anchor findings to changed lines when possible and recheck the head if it moves.
5. Publish or update the PR only when authorized. Verify the resulting PR URL and head afterward.
