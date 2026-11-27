import copy
import importlib.util
import pathlib
import tempfile
import unittest

import yaml


PATH = pathlib.Path(__file__).with_name("validate_evidence_candidate.py")
SPEC = importlib.util.spec_from_file_location("validate_evidence_candidate", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)

ROOT = pathlib.Path(__file__).parents[2]
CANDIDATE = (
    ROOT
    / ".codex/skills/database-reviewer/evidence/"
    / "production-content-user-progress-created-at-index-20260716.yaml"
)


class EvidenceCandidateTest(unittest.TestCase):
    def setUp(self):
        self.data = yaml.safe_load(CANDIDATE.read_text())

    def validate_mutation(self, mutation):
        data = copy.deepcopy(self.data)
        mutation(data)
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / CANDIDATE.name
            target.write_text(yaml.safe_dump(data, sort_keys=False))
            with self.assertRaises(MODULE.ValidationError):
                MODULE.validate_candidate(target)

    def test_current_candidate_is_valid(self):
        MODULE.validate_candidate(CANDIDATE)

    def test_rejects_owner_attestation_claim(self):
        self.validate_mutation(
            lambda data: data["provenance"].update(classification="owner_attested")
        )

    def test_rejects_replayable_agent_attestation(self):
        self.validate_mutation(
            lambda data: data["provenance"].update(independently_replayable=True)
        )

    def test_rejects_claim_group_provenance_mismatch(self):
        self.validate_mutation(
            lambda data: data["claim_groups"]["execution_terminal"].update(
                provenance_class="runtime_proven"
            )
        )

    def test_rejects_unknown_relevance_class(self):
        self.validate_mutation(
            lambda data: data["relevance"].update(authoritative=["all future operations"])
        )

    def test_corrected_record_requires_correction_metadata(self):
        self.validate_mutation(lambda data: data.update(record_version=2))

    def test_corrected_record_accepts_reasoned_metadata(self):
        data = copy.deepcopy(self.data)
        data["record_version"] = 2
        data["correction"] = {
            "corrected_at": "2026-07-17T00:00:00Z",
            "reason": "Corrected a transcription error.",
            "prior_git_commit": "1691b830d",
        }
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / CANDIDATE.name
            target.write_text(yaml.safe_dump(data, sort_keys=False))
            MODULE.validate_candidate(target)


if __name__ == "__main__":
    unittest.main()
