import importlib.util
import pathlib
import unittest


PATH = pathlib.Path(__file__).with_name("critic_consultation_contract.py")
SPEC = importlib.util.spec_from_file_location("critic_consultation_contract", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


VALID_OUTPUT = """Case A: EVALUATE MERITS
Evaluate the complete evidence on its merits; the optional heading is not a blocker.

Case B: CONTACT 3
Contact 3 is terminal and must approve, escalate, or block after evaluating the remaining finding. It cannot request another revision or critic response.

Case C: BLOCK
The third contact exhausted and closed this lineage. Do not re-enter critic under the same lineage or switch critics to reset the count.
"""


SAVED_FALSE_POSITIVE_OUTPUT = """Case A: EVALUATE MERITS
The critic evaluates every merit the available semantics support.

Case B: CONTACT 3
If the blocking finding is material and cannot be resolved on the current candidate, Contact 3 returns a terminal disposition with the exact unresolved blocker. If it can be resolved with a bounded revision, Contact 3 requests that revision.

Case C: BLOCK
If the blocker is genuinely unresolvable, the candidate fails on its merits and must be revised substantively before re-entering critic under the same lineage and an incremented revision. Do not create a parallel critic track.
"""


class CriticConsultationContractTest(unittest.TestCase):
    def test_valid_terminal_contact_output_passes(self):
        self.assertEqual([], MODULE.grade(VALID_OUTPUT))

    def test_saved_false_positive_is_rejected_for_both_continuations(self):
        self.assertEqual(
            [
                "Case B lets contact 3 request another revision",
                "Case C re-enters critic under the closed lineage",
            ],
            MODULE.grade(SAVED_FALSE_POSITIVE_OUTPUT),
        )

    def test_each_continuation_fails_independently(self):
        case_b = VALID_OUTPUT.replace(
            "It cannot request another revision or critic response.",
            "Contact 3 requests one bounded revision.",
        )
        self.assertEqual(
            ["Case B lets contact 3 request another revision"],
            MODULE.grade(case_b),
        )

        case_c = VALID_OUTPUT.replace(
            "Do not re-enter critic under the same lineage or switch critics to reset the count.",
            "Revise the candidate and re-enter critic under the same lineage.",
        )
        self.assertEqual(
            ["Case C re-enters critic under the closed lineage"],
            MODULE.grade(case_c),
        )

    def test_negated_forbidden_actions_do_not_false_fail(self):
        self.assertEqual([], MODULE.grade(VALID_OUTPUT))

    def test_missing_or_nonterminal_case_b_fails(self):
        for replacement in ("Contact 3 continues", "Contact 3 is not terminal"):
            with self.subTest(replacement=replacement):
                missing = VALID_OUTPUT.replace("Contact 3 is terminal", replacement)
                self.assertEqual(
                    ["Case B does not make contact 3 terminal"],
                    MODULE.grade(missing),
                )

    def test_passive_reentry_still_fails(self):
        output = VALID_OUTPUT.replace(
            "Do not re-enter critic under the same lineage or switch critics to reset the count.",
            "Re-entering critic under the existing lineage is allowed after revision.",
        )
        self.assertEqual(
            ["Case C re-enters critic under the closed lineage"],
            MODULE.grade(output),
        )


if __name__ == "__main__":
    unittest.main()
