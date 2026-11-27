---
name: code-review
description: Review a stable diff, commit, or pull request for correctness and regression risk.
---

# Code Review

1. Identify the base and head. Inspect the diff and the surrounding code needed to understand affected callers.
2. Trace modified behavior through normal, failure, and retry paths. Check authorization, data consistency, compatibility, and test coverage where the diff affects them.
3. For each actionable finding, give the affected location, triggering condition, consequence, and a suggested correction. Distinguish confirmed defects from unresolved questions.
4. Report findings in severity order and state what you verified. Keep the reviewed code read-only unless the user asks for fixes.
