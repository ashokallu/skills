---
name: work-orchestration
description: Coordinate repository work with dependent steps, concurrent ownership, or external side effects.
---

# Work Orchestration

1. State the deliverable, the current evidence, and the next decision or action needed to advance the work.
2. Identify who owns each affected file or external operation. Give concurrent work disjoint ownership where practical.
3. Carry forward the exact revision or artifact reviewed. Recheck live state before acting on an earlier observation that may have changed.
4. Keep read-only investigation separate from writes in the execution sequence. Before an external mutation, verify the target and that the user's authorization covers it.
5. Close the task against the requested outcome. Record verification results and any remaining blocker with its evidence.
