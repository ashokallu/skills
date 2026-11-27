---
name: github-workflow
description: Read GitHub repository state or carry out an explicitly requested GitHub update.
---

# GitHub Workflow

1. Resolve the repository and object from the user's request or the checkout remote. Check the current branch and revision for branch-dependent work.
2. Use the configured GitHub client and its existing authentication. Verify the active identity when it matters for a write.
3. Inspect the current object before updating it. Use the narrowest operation that makes the requested change.
4. After an authorized write, read the object back and report its URL and resulting state. If a request failed after submission, check whether it took effect before retrying.
