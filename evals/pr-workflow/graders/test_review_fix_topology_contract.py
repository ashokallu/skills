"""Unit tests for review-fix commit topology."""

from __future__ import annotations

import unittest

from review_fix_topology_contract import (
    decide_topology,
    rewrite_outcome,
    scoped_review_eligible,
)


class ReviewFixTopologyContractTest(unittest.TestCase):
    def test_internal_and_human_feedback_preserve_fix_commit(self) -> None:
        for source in ("human", "mixed", "internal"):
            with self.subTest(source=source):
                self.assertEqual(decide_topology(source), "new_commit")

    def test_copilot_amend_is_narrow_exception(self) -> None:
        self.assertEqual(decide_topology("copilot"), "amend_permitted")
        for condition in (
            {"human_baseline_changed": True},
            {"scoped_review_required": True},
            {"immutable_target_required": True},
            {"classification_certain": False},
        ):
            with self.subTest(condition=condition):
                self.assertEqual(
                    decide_topology("copilot", **condition), "new_commit"
                )

    def test_scoped_review_requires_clean_ancestral_range(self) -> None:
        self.assertTrue(
            scoped_review_eligible(
                ancestral=True, rewritten=False, finding_mapped=True
            )
        )
        self.assertFalse(
            scoped_review_eligible(
                ancestral=False, rewritten=False, finding_mapped=True
            )
        )
        self.assertFalse(
            scoped_review_eligible(
                ancestral=True, rewritten=True, finding_mapped=True
            )
        )
        self.assertFalse(
            scoped_review_eligible(
                ancestral=True, rewritten=False, finding_mapped=False
            )
        )

    def test_rewrite_invalidates_sha_bound_review(self) -> None:
        self.assertEqual(
            rewrite_outcome("scoped_pending", explicit=True), "reject"
        )
        self.assertEqual(
            rewrite_outcome("scoped_resolved", explicit=True),
            "stabilize_then_neutral_full",
        )
        self.assertEqual(
            rewrite_outcome("neutral_complete", explicit=True),
            "invalidate_then_fresh_neutral_full",
        )


if __name__ == "__main__":
    unittest.main()
