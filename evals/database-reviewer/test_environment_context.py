import copy
import importlib.util
import pathlib
import subprocess
import tempfile
import unittest

import yaml


PATH = pathlib.Path(__file__).with_name("validate_environment_context.py")
SPEC = importlib.util.spec_from_file_location("validate_environment_context", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)

ROOT = pathlib.Path(__file__).parents[2]
SNAPSHOT = ROOT / ".codex/skills/database-reviewer/evidence/staging-cloudsql.yaml"
PRODUCTION = ROOT / ".codex/skills/database-reviewer/evidence/production-cloudsql.yaml"


class EnvironmentContextTest(unittest.TestCase):
    def setUp(self):
        self.data = yaml.safe_load(SNAPSHOT.read_text())

    def validate_mutation(self, mutation):
        data = copy.deepcopy(self.data)
        mutation(data)
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            evidence = root / "evidence"
            evidence.mkdir()
            collector = SNAPSHOT.parent / self.data["collector"]["path"]
            (evidence / collector.name).write_text(collector.read_text())
            non_sql = SNAPSHOT.parent / self.data["non_sql_collector"]["path"]
            (evidence / non_sql.name).write_text(non_sql.read_text())
            target = evidence / SNAPSHOT.name
            target.write_text(yaml.safe_dump(data, sort_keys=False))
            with self.assertRaises(MODULE.ValidationError):
                MODULE.validate_snapshot(target, ROOT, allow_fixture=True)

    def validate_production_mutation(self, mutation):
        data = yaml.safe_load(PRODUCTION.read_text())
        mutation(data)
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            evidence = root / "evidence"
            evidence.mkdir()
            for key in ("collector", "non_sql_collector"):
                source = PRODUCTION.parent / data[key]["path"]
                (evidence / source.name).write_text(source.read_text())
            target = evidence / PRODUCTION.name
            target.write_text(yaml.safe_dump(data, sort_keys=False))
            with self.assertRaises(MODULE.ValidationError):
                MODULE.validate_snapshot(target, ROOT, allow_fixture=True)

    def validate_production_success(self, mutation):
        data = yaml.safe_load(PRODUCTION.read_text())
        mutation(data)
        with tempfile.TemporaryDirectory() as directory:
            evidence = pathlib.Path(directory) / "evidence"
            evidence.mkdir()
            for key in ("collector", "non_sql_collector"):
                source = PRODUCTION.parent / data[key]["path"]
                (evidence / source.name).write_text(source.read_text())
            target = evidence / PRODUCTION.name
            target.write_text(yaml.safe_dump(data, sort_keys=False))
            MODULE.validate_snapshot(target, ROOT, allow_fixture=True)

    def test_staging_fixture_is_valid(self):
        MODULE.validate_snapshot(SNAPSHOT, allow_fixture=True)

    def test_production_fixture_is_valid(self):
        MODULE.validate_snapshot(PRODUCTION, allow_fixture=True)

    def test_fixture_requires_explicit_mode(self):
        with self.assertRaisesRegex(MODULE.ValidationError, "explicit fixture"):
            MODULE.validate_snapshot(PRODUCTION)

    def test_production_requires_replica_sql_proof(self):
        self.validate_production_mutation(
            lambda data: data["live_observed"]["database"]["is_replica"].update(value=False)
        )

    def test_production_requires_access_preflight_result(self):
        self.validate_production_mutation(
            lambda data: data["live_observed"].pop("access_preflight")
        )

    def test_production_requires_all_non_sql_query_ids(self):
        self.validate_production_mutation(
            lambda data: data["non_sql_collector"].update(query_ids=[])
        )

    def test_production_rejects_failed_vpn_preflight(self):
        self.validate_production_mutation(
            lambda data: data["live_observed"]["access_preflight"]["vpn_smoke_passed"].update(
                value=False
            )
        )

    def test_production_accepts_reasoned_unavailable_row_estimate(self):
        self.validate_production_success(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(value=None, classification="unavailable", reason="pg_class.reltuples is negative")
        )

    def test_production_sql_sections_require_read_only_timeout(self):
        sections = ("database", "settings", "relation_summary", "largest_physical_relations")
        for section in sections:
            with self.subTest(section=section, invariant="read_only"):
                self.validate_production_mutation(
                    lambda data, section=section: data["live_observed"][section]["provenance"].update(
                        transaction_mode="read_write"
                    )
                )
            with self.subTest(section=section, invariant="timeout"):
                self.validate_production_mutation(
                    lambda data, section=section: data["live_observed"][section]["provenance"].update(
                        statement_timeout_ms=0
                    )
                )

    def test_unknown_environment_is_rejected(self):
        self.validate_mutation(lambda data: data.update(environment="prod"))

    def test_cross_environment_collector_is_rejected(self):
        self.validate_mutation(
            lambda data: data["collector"].update(id="production-cloudsql-context-v1")
        )

    def test_missing_non_sql_query_id_is_rejected(self):
        self.validate_mutation(lambda data: data["non_sql_collector"].update(query_ids=[]))

    def test_exact_counts_bound_cannot_be_enabled(self):
        self.validate_mutation(lambda data: data["collection_bounds"].update(exact_counts_run=True))

    def test_explain_analyze_bound_cannot_be_enabled(self):
        self.validate_mutation(lambda data: data["collection_bounds"].update(explain_analyze_run=True))

    def test_row_samples_bound_cannot_be_enabled(self):
        self.validate_mutation(lambda data: data["collection_bounds"].update(row_samples_read=True))

    def test_payload_bound_cannot_be_enabled(self):
        self.validate_mutation(lambda data: data["collection_bounds"].update(payloads_read=True))

    def test_negative_row_estimate_is_rejected(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(value=-1)
        )

    def test_boolean_row_estimate_is_rejected(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(value=True)
        )

    def test_fractional_row_estimate_is_rejected(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(value=1.5)
        )

    def test_null_estimate_cannot_be_labeled_estimated(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(value=None)
        )

    def test_non_null_estimate_cannot_be_labeled_unavailable(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["largest_physical_relations"]["rows"][0][
                "estimated_live_rows"
            ].update(classification="unavailable", reason="missing statistics")
        )

    def test_missing_provenance_is_rejected(self):
        self.validate_mutation(lambda data: data["live_observed"]["database"].pop("provenance"))

    def test_inaccurate_declared_source_anchor_is_rejected(self):
        revision = subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True
        ).strip()
        with self.assertRaisesRegex(MODULE.ValidationError, "does not contain value"):
            MODULE.validate_source_anchor(ROOT, revision, "README.md:1", "synthetic-absent-value")

    def test_unresolvable_declared_source_commit_is_rejected(self):
        with self.assertRaisesRegex(MODULE.ValidationError, "source is unavailable"):
            MODULE.validate_source_anchor(ROOT, "0" * 40, "README.md:1", "example")

    def test_invalid_timestamp_order_is_rejected(self):
        self.validate_mutation(lambda data: data.update(valid_until=data["observed_at"]))

    def test_unknown_classification_is_rejected(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["database"]["database_bytes"].update(
                classification="precise"
            )
        )

    def test_unavailable_value_requires_reason(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["instance_metadata"]["replica"]["sql_recovery_state"].pop(
                "reason"
            )
        )

    def test_collector_hash_mismatch_is_rejected(self):
        self.validate_mutation(lambda data: data["collector"].update(sha256="0" * 64))

    def test_relation_count_mismatch_is_rejected(self):
        self.validate_mutation(
            lambda data: data["live_observed"]["relation_summary"]["omitted_relation_count"].update(
                value=0
            )
        )


if __name__ == "__main__":
    unittest.main()
