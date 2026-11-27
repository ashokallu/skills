"""Deterministic contract for review-fix commit topology."""

from __future__ import annotations

import sys


NEW_COMMIT_SOURCES = {"human", "mixed", "internal"}


def decide_topology(
    source: str,
    *,
    human_baseline_changed: bool = False,
    scoped_review_required: bool = False,
    immutable_target_required: bool = False,
    classification_certain: bool = True,
) -> str:
    """Return the only allowed topology for a review-fix batch."""
    if not classification_certain:
        return "new_commit"
    if source in NEW_COMMIT_SOURCES:
        return "new_commit"
    if source != "copilot":
        return "new_commit"
    if human_baseline_changed or scoped_review_required or immutable_target_required:
        return "new_commit"
    return "amend_permitted"


def scoped_review_eligible(
    *,
    ancestral: bool,
    rewritten: bool,
    finding_mapped: bool,
) -> bool:
    """Return whether an exact finding-directed delta can use scoped review."""
    return ancestral and not rewritten and finding_mapped


def rewrite_outcome(phase: str, *, explicit: bool) -> str:
    """Return the review consequence of a requested history rewrite."""
    if phase in {"finding_accepted", "scoped_pending"}:
        return "reject"
    if not explicit:
        return "reject"
    if phase == "scoped_resolved":
        return "stabilize_then_neutral_full"
    if phase == "neutral_complete":
        return "invalidate_then_fresh_neutral_full"
    return "reject"


def self_test() -> list[str]:
    failures: list[str] = []
    topology_cases = [
        ("human", {}, "new_commit"),
        ("mixed", {}, "new_commit"),
        ("internal", {}, "new_commit"),
        ("copilot", {}, "amend_permitted"),
        ("copilot", {"human_baseline_changed": True}, "new_commit"),
        ("copilot", {"scoped_review_required": True}, "new_commit"),
        ("copilot", {"immutable_target_required": True}, "new_commit"),
        ("copilot", {"classification_certain": False}, "new_commit"),
    ]
    for source, kwargs, expected in topology_cases:
        actual = decide_topology(source, **kwargs)
        if actual != expected:
            failures.append(f"{source} {kwargs}: expected {expected}, got {actual}")

    if not scoped_review_eligible(
        ancestral=True, rewritten=False, finding_mapped=True
    ):
        failures.append("valid ancestral finding range rejected")
    for kwargs in (
        {"ancestral": False, "rewritten": False, "finding_mapped": True},
        {"ancestral": True, "rewritten": True, "finding_mapped": True},
        {"ancestral": True, "rewritten": False, "finding_mapped": False},
    ):
        if scoped_review_eligible(**kwargs):
            failures.append(f"invalid scoped review accepted: {kwargs}")

    rewrite_cases = [
        ("finding_accepted", True, "reject"),
        ("scoped_pending", True, "reject"),
        ("scoped_resolved", False, "reject"),
        ("scoped_resolved", True, "stabilize_then_neutral_full"),
        ("neutral_complete", True, "invalidate_then_fresh_neutral_full"),
    ]
    for phase, explicit, expected in rewrite_cases:
        actual = rewrite_outcome(phase, explicit=explicit)
        if actual != expected:
            failures.append(
                f"{phase} explicit={explicit}: expected {expected}, got {actual}"
            )
    return failures


def main() -> int:
    if sys.argv[1:] != ["--self-test"]:
        print("usage: review_fix_topology_contract.py --self-test")
        return 2
    failures = self_test()
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("review-fix topology contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
