---
name: code-authoring
description: Implement or refactor code, tests, scripts, or configuration within an agreed scope.
---

# Code Authoring

1. Read the relevant repository instructions and trace the normal entry point through its callers and dependencies.
2. Identify the behavior that existing callers and older data rely on. Review failure, retry, and concurrent execution where the change touches shared state.
3. Reuse established interfaces and generators. If generated output needs to change, edit its source and regenerate it using the project workflow.
4. Run focused checks that exercise the changed behavior through its normal entry point. Add regression coverage when existing checks miss a concrete failure mode.
5. Review the diff for unrelated changes and report the checks run, their results, and any gaps.
