---
name: pre-publication-single-commit
version: 0.1.0
scale: pass-fail
description: Semantic acceptance contract for new-PR commit normalization.
---

# Pre-Publication Single Commit

Pass only if the response requires recording the reviewed pre-squash head,
squashing the complete branch range over `origin/main` to exactly one commit
before first push and PR creation, proving tree equivalence between the
reviewed head and squashed head, verifying
`git rev-list --count origin/main..HEAD` equals `1`, rerunning commit-message
or history-sensitive checks, then pushing and reading back the new PR commit
list as exactly one commit.

The response must say that reviewer redispatch is not required solely for a
tree-equivalent squash after every pre-open review is terminal. Fail if it
opens the PR with four commits, squashes while review is active, omits
tree-equivalence proof, or treats the SHA change alone as a reason for another
review.

Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
`set_waza_grade_fail` once and name the missing or contradicted requirement.
