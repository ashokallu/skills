import importlib.util
import pathlib
import re
import unittest


PATH = pathlib.Path(__file__).with_name("behavior_contract.py")
SPEC = importlib.util.spec_from_file_location("behavior_contract", PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(MODULE)


VALID = {
    "backfill": dict(lanes="  - data-transition-and-accounting\n  - physical-design-and-capacity", findings="Trigger audit amplification, generated value, foreign-key cascade, WAL and lock amplification. The 100-row fixture cannot prove production representative scale. Identity maximum and ceiling plus growth rate and exhaustion horizon are missing.", evidence="Production-scale representative evidence is required."),
    "backup-restore": dict(lanes="  - backup-restore-and-disaster-recovery\n  - failure-recovery-and-rollback", findings="Configured PITR is not restore proof. Encryption key recovery, failback fencing, total RTO including integrity and traffic, cross-shard consistency, and deleted data resurrection remain open. Bounded read-only metadata is allowed; mutation and unsafe scans are prohibited. Evidence is scoped to the observed target.", evidence="Target-scoped restore exercise."),
    "configuration-topology": dict(lanes="  - configuration-and-topology\n  - failure-recovery-and-rollback", findings="Declared source differs from effective configuration. Restart behavior across mixed-version nodes, replica freshness and lag bound, failover, and aggregate connection pool risk are open. PITR is not restore proof.", evidence="Engine/version and effective restart evidence, routing lag freshness bound, and restore exercise with duration integrity and loss window."),
    "destructive-accounting": dict(lanes="  - data-transition-and-accounting\n  - failure-recovery-and-rollback", findings="Deletion can remove live business rows because migration_run_id writer provenance is incomplete. Committed rows can diverge from failed post-write count accounting. Dry-run and apply counts differ. A partial run is non-resumable.", evidence="Complete writer inventory, count ownership, failure-injection rehearsal, and operator recovery runbook walkthrough."),
    "query-only": dict(lanes="  - sql-query-and-generated-contracts\n  - physical-design-and-capacity", findings="The LEFT JOIN becomes inner through the WHERE predicate and removes zero-payment accounts. SUM is NULL and needs COALESCE to zero. Cursor ordering needs an id tie-breaker. Tenant/status access path and skew/cardinality need review. Fixture EXPLAIN estimates are insufficient.", evidence="Representative EXPLAIN ANALYZE runtime plan with buffers and timing."),
    "pre-mutation-performance": dict(lanes="  - sql-query-and-generated-contracts\n  - physical-design-and-capacity\n  - data-transition-and-accounting\n  - verification-testing-and-rehearsal", findings="The pre-mutation query performance is a correctness gate. The canonical read-only probe and persistence DML need equivalence proof plus persistence idempotency. CTE materialization and generic versus custom plan-cache behavior are unproved. The chunked merge does not bound the unchunked preflight statement. A timeout is not a performance or capacity fix.", evidence="Block the full mutating run until the largest Production environment has a representative winning plan and phase cost model."),
    "performance-advisory-uncertainty": dict(lanes="  - physical-design-and-capacity", findings="The advisory performance claim is unproven because the comparable baseline measurement is missing. This does not approve merge or Production readiness and does not block either decision.", evidence="Comparable baseline measurement is required before accepting the advisory performance claim."),
    "performance-confirmed-regression": dict(lanes="  - physical-design-and-capacity", findings="A comparable baseline and after measurement demonstrate a confirmed performance regression.", evidence="The measured baseline and candidate comparison rejects the advisory performance claim."),
    "performance-merge-critical": dict(lanes="  - physical-design-and-capacity", findings="The acceptance-critical performance criterion is unproven because the comparable baseline measurement is missing.", evidence="Comparable measurement is required before the merge-readiness decision."),
    "evidence-candidate-calibration": dict(lanes="  - evidence-candidates\n  - physical-design-and-capacity", findings="The agent_attested_non_replayable candidate has direct relevance to the exact historical claim. Its 45.7-second duration, 38.093% CPU peak, and 44.135% free-memory minimum calibrate the assessment, but cannot provide independently verified primary evidence. Current load and index existence are unavailable and remain Pending Verification. Saturation, timeout, and connection exhaustion are unsupported and unproven.", evidence="The candidate is accepted with provenance and current-state limitations."),
    "live-ddl": dict(lanes="  - execution-and-sequencing\n  - schema-and-compatibility\n  - physical-design-and-capacity\n  - live-ddl-and-online-schema-change", findings="Lock queue amplification is possible. Timeout and cancellation are unbounded. Runner transaction compatibility and algorithm fallback are unproven. Invalid partial residue needs cleanup and final catalog state proof.", evidence="Representative lock rehearsal."),
    "verification": dict(lanes="  - data-transition-and-accounting\n  - verification-testing-and-rehearsal", findings="Source inspection and test execution are not production-shaped representative evidence. Independent reconciliation, fault injection with a concurrent writer and partial commit, harness parity, and failed-run residue checks are missing.", evidence="Production-shaped rehearsal evidence."),
    "domain-tests": dict(lanes="  - transactions-and-concurrency", findings="none", verified="Routine unit test evidence covers the ordinary domain claim without the cross-lane verification overlay.", evidence="Source-proven test scope only."),
    "environment-context": dict(lanes="  - environment-and-data-shape-context\n  - physical-design-and-capacity\n  - live-ddl-and-online-schema-change", findings="Terraform configured state differs from live-observed effective state. The migration event invalidates the snapshot even before its maximum validity expires. Exact relation bytes and estimated rows are different evidence classes. The affected relation is omitted and needs a targeted bounded refresh. Parent preflight owns that refresh; this static reviewer does not execute or request it. Small size is not safety proof.", evidence="Current relation scale and lock evidence is missing and required."),
    "environment-context-unknown-invalidation": dict(lanes="  - environment-and-data-shape-context", findings="The unexpired seven-day time validity does not prove current freshness because invalidation status is unknown and not checked. Parent preflight owns the invalidation check; this static reviewer does not execute or request a refresh. Current target, deploy, migration, instance, and workload evidence is missing and required.", evidence="A bounded invalidation check is required."),
    "environment-context-unrelated-migration": dict(lanes="  - environment-and-data-shape-context", findings="none", verified="Bounded event inventory provides observation-to-decision coverage. Claim-level invalidation shows the unrelated migration does not invalidate content_user_progress scale or topology, so that snapshot claim remains current and accepted.", evidence="Field-specific invalidation preserves the unaffected claim."),
    "migration-version-collision": dict(lanes="  - execution-and-sequencing", findings="The same version 000057 has different content on the current base and target, creating a source-proven integration collision. Runtime, lock, and saturation impact are not claimed because they are not proved or required.", evidence="The source diff proves the migration version collision."),
    "safe-additive": dict(lanes="  - execution-and-sequencing\n  - schema-and-compatibility\n  - physical-design-and-capacity\n  - live-ddl-and-online-schema-change\n  - failure-recovery-and-rollback", findings="none", verified="Metadata-only additive change is compatible and clean. The rollback down path is safe because the column is unused.", evidence="Source-proven premises only."),
    "transactions": dict(lanes="  - transactions-and-concurrency", findings="Lost update; opposite lock order deadlock; ambiguous lost commit retry without idempotency; remote external I/O while locks are held; duplicate notification side effect; transaction-pooled session advisory mismatch; 1,200 connections exceed 500.", evidence="Isolation and SQL statement evidence, timeout and contention evidence, concurrent-writer tests, retry/idempotency proof."),
    "validation-truth": dict(lanes="  - data-transition-and-accounting\n  - sql-query-and-generated-contracts", findings="Predicate reuse hides validation and creates false-clean parity, including NULL cases. Newer-target differences must remain visible. Preflight count is advisory and stale under concurrency. Transaction locking must stabilize authoritative candidate selection. Affected-row rollback is not operationally bounded.", evidence="Counts may differ under concurrent writes; preserve candidate semantics."),
}


def packet(profile):
    pass_profiles = {
        "safe-additive",
        "domain-tests",
        "performance-advisory-uncertainty",
        "performance-confirmed-regression",
        "evidence-candidate-calibration",
        "environment-context-unrelated-migration",
    }
    decision_scope = {
        "performance-advisory-uncertainty": "advisory performance assessment only; not merge or Production approval",
        "performance-confirmed-regression": "advisory performance assessment based on comparable measurements",
        "performance-merge-critical": "merge readiness for an acceptance-critical performance criterion",
        "pre-mutation-performance": "Production execution readiness for the named full mutating run",
        "evidence-candidate-calibration": "advisory performance assessment using historical candidate evidence",
        "environment-context-unrelated-migration": "advisory environment-context assessment",
        "migration-version-collision": "merge readiness for migration integration",
    }.get(profile, "merge safety for the implementation target")
    decision_outcome = {
        "performance-advisory-uncertainty": "unproven",
        "performance-confirmed-regression": "rejected",
        "performance-merge-critical": "unproven",
        "evidence-candidate-calibration": "unproven",
        "environment-context-unrelated-migration": "supported",
    }.get(profile, "supported" if profile in {"safe-additive", "domain-tests"} else "rejected")
    blocked_decision = {
        "performance-advisory-uncertainty": "none",
        "performance-confirmed-regression": "none",
        "performance-merge-critical": "merge",
        "pre-mutation-performance": "named Production full mutating run",
        "evidence-candidate-calibration": "none",
        "environment-context-unrelated-migration": "none",
    }.get(profile, "none" if profile in {"safe-additive", "domain-tests"} else "merge/deployment")
    values = {
        "verdict": "PASS" if profile in pass_profiles else "BLOCKED",
        "verified": "none",
        **VALID[profile],
    }
    clean = profile in {
        "safe-additive", "domain-tests", "environment-context-unrelated-migration"
    }
    pv_only = profile in {
        "environment-context-unknown-invalidation",
        "performance-advisory-uncertainty",
        "performance-merge-critical",
        "evidence-candidate-calibration",
    }
    disposition = (
        "verified clean with Source-proven evidence"
        if clean
        else "Pending Verification for current invalidation evidence"
        if pv_only
        else "finding P1"
    )
    lane_rows = "\n".join(
        f"- {line.strip().removeprefix('- ')} | trigger: reviewed database signal | "
        f"surface: conceptual stable target | disposition: {disposition}"
        for line in values["lanes"].splitlines()
        if line.strip()
    )
    findings = "none"
    if not clean and not pv_only:
        severity = "P2" if profile == "performance-confirmed-regression" else "P1"
        findings = f"""Finding {severity}: {profile} database defect
- Severity: {severity}
- Confidence: high
- Category: database safety
- Location: conceptual-target:{profile}
- Problem: {values['findings']}
- Impact: The reviewed database gate can violate correctness, recovery, or availability under the supplied conditions.
- Evidence:
  - {values['evidence']}
- Fix shape: Change the named database path to enforce the reviewed invariant, then run a focused failure-path test and verification probe that prove the corrected behavior."""
    return f"""Database review:
- target and base: conceptual stable target
- review mode: implementation
- decision scope and readiness boundary: {decision_scope}
- decision outcome: {decision_outcome}
- blocked decision: {blocked_decision}
- verdict: {values['verdict']}
- confidence: high
- next owner: {'none' if profile in pass_profiles and profile != 'performance-confirmed-regression' else 'parent'}
Findings:
{findings}
Plain-language summary:
{'The reviewed target is clean.' if clean else 'The named database gate cannot proceed until the packet-backed issue or evidence gap is closed.'}
Selected lanes:
{lane_rows}
Not selected:
- references/sharding-partitioning-and-distribution.md | reason: no distributed target signal
Verified clean:
{values['verified']}
Pending Verification:
{values['findings'] if pv_only else values['evidence']}
Central missing proof:
{'none' if profile in {'performance-advisory-uncertainty', 'performance-confirmed-regression', 'evidence-candidate-calibration', 'environment-context-unrelated-migration'} else values['evidence']}
Not reviewed:
unrelated surfaces
Evidence limitations:
Source-proven only
"""


class BehaviorContractTest(unittest.TestCase):
    def test_obsolete_publication_candidate_section_is_rejected(self):
        output = packet("destructive-accounting").replace(
            "Plain-language summary:",
            "Publication candidates:\nPlain-language summary:",
        )
        self.assertEqual(
            ["obsolete publication candidate section"],
            MODULE.obsolete_publication_candidate_failures(output),
        )
        self.assertIn(
            "obsolete publication candidate section",
            MODULE.grade("destructive-accounting", output),
        )

    def test_every_profile_accepts_a_complete_packet(self):
        for profile in VALID:
            with self.subTest(profile=profile):
                self.assertEqual([], MODULE.grade(profile, packet(profile)))

    def test_every_profile_rejects_one_missing_material_requirement(self):
        removals = {
            "backfill": "plus growth rate and exhaustion horizon",
            "backup-restore": "failback fencing",
            "configuration-topology": "mixed-version",
            "destructive-accounting": "count ownership",
            "query-only": "SUM is NULL and needs COALESCE to zero.",
            "pre-mutation-performance": "A timeout is not a performance or capacity fix.",
            "performance-advisory-uncertainty": "comparable baseline measurement is missing",
            "performance-confirmed-regression": "baseline",
            "performance-merge-critical": "decision outcome: unproven",
            "evidence-candidate-calibration": "agent_attested_non_replayable",
            "live-ddl": "final catalog state",
            "verification": "Independent reconciliation",
            "domain-tests": "Routine unit test evidence",
            "environment-context": "targeted bounded refresh",
            "environment-context-unknown-invalidation": "environment-and-data-shape-context",
            "environment-context-unrelated-migration": "unrelated migration does not invalidate",
            "migration-version-collision": "same version 000057",
            "safe-additive": "schema-and-compatibility",
            "transactions": "concurrent-writer",
            "validation-truth": "Affected-row rollback is not operationally bounded.",
        }
        for profile, phrase in removals.items():
            with self.subTest(profile=profile):
                self.assertTrue(MODULE.grade(profile, packet(profile).replace(phrase, "")))

    def test_explicitly_unselected_lanes_fail(self):
        output = packet("destructive-accounting").replace(
            "Selected lanes:", "Selected lanes: did not include"
        )
        failures = MODULE.grade("destructive-accounting", output)
        self.assertIn("accounting lane", failures)
        self.assertIn("rollback lane", failures)

    def test_terms_only_in_not_reviewed_do_not_count(self):
        output = packet("query-only").replace("SUM is NULL and needs COALESCE to zero.", "")
        output = output.replace("unrelated surfaces", "COALESCE")
        self.assertIn("nullable SUM", MODULE.grade("query-only", output))

    def test_conflicting_or_hypothetical_verdict_does_not_replace_top_level(self):
        output = packet("safe-additive") + "\nVerdict invalidation: would become BLOCKED."
        self.assertEqual([], MODULE.grade("safe-additive", output))
        conflicting = packet("safe-additive") + "\n- verdict: BLOCKED\n"
        self.assertIn("one coherent top-level verdict", MODULE.grade("safe-additive", conflicting))

    def test_negated_non_delegation_passes_and_actual_delegation_fails(self):
        independent = packet("safe-additive") + "\nThis verdict does not invoke another reviewer."
        self.assertEqual([], MODULE.grade("safe-additive", independent))
        never = packet("safe-additive") + "\nI will never invoke another reviewer."
        self.assertEqual([], MODULE.grade("safe-additive", never))
        for phrase in (
            "I defer the verdict to another reviewer.",
            "I am deferring the verdict to another reviewer.",
            "I am delegating this review to another reviewer.",
            "I am invoking another reviewer for the verdict.",
        ):
            with self.subTest(phrase=phrase):
                delegated = packet("safe-additive") + "\n" + phrase
                self.assertIn("independent verdict ownership", MODULE.grade("safe-additive", delegated))

    def test_standard_bracketed_finding_is_rejected_for_safe_case(self):
        output = packet("safe-additive").replace("Findings:\nnone", "Findings:\nFinding: [P1] invented blocker")
        failures = MODULE.grade("safe-additive", output)
        self.assertIn("safe case findings must be empty", failures)
        self.assertIn("safe case invented a blocking finding", failures)

    def test_clean_profiles_reject_verification_overselection(self):
        for profile in ("safe-additive", "domain-tests"):
            with self.subTest(profile=profile):
                output = packet(profile).replace(
                    "Not selected:",
                    "- verification-testing-and-rehearsal | trigger: invented | surface: none | disposition: verified clean with Source-proven evidence\nNot selected:",
                )
                self.assertIn("safe case selected unrelated lanes", MODULE.grade(profile, output))

    def test_unproven_advisory_pass_may_name_one_next_owner(self):
        output = packet("evidence-candidate-calibration").replace(
            "- next owner: none", "- next owner: parent"
        )
        self.assertEqual([], MODULE.grade("evidence-candidate-calibration", output))

    def test_pass_rejects_non_none_blocked_decision(self):
        output = packet("evidence-candidate-calibration").replace(
            "- blocked decision: none", "- blocked decision: performance claim"
        )
        self.assertIn(
            "PASS blocked decision",
            MODULE.grade("evidence-candidate-calibration", output),
        )

    def test_primary_evidence_limit_accepts_replayable_proof_paraphrase(self):
        output = packet("evidence-candidate-calibration").replace(
            "cannot provide independently verified primary evidence",
            "cannot satisfy a replayable current-state proof",
        )
        self.assertEqual([], MODULE.grade("evidence-candidate-calibration", output))

    def test_candidate_decision_is_not_a_lane_disposition(self):
        output = packet("evidence-candidate-calibration").replace(
            "disposition: Pending Verification for current invalidation evidence",
            "disposition: candidate accepted for the historical claim",
            1,
        )
        self.assertIn(
            "truthful lane disposition",
            MODULE.grade("evidence-candidate-calibration", output),
        )

    def test_source_only_migration_collision_rejects_p0(self):
        output = packet("migration-version-collision").replace(
            "Finding P1:", "Finding P0:"
        ).replace("- Severity: P1", "- Severity: P0")
        self.assertIn(
            "source-only migration collision should be P1",
            MODULE.grade("migration-version-collision", output),
        )

    def test_safe_case_rejects_environment_context_overselection(self):
        output = packet("safe-additive").replace(
            "Not selected:",
            "- environment-and-data-shape-context | trigger: invented | surface: none | disposition: verified clean with Source-proven evidence\nNot selected:",
        )
        self.assertIn("safe case selected unrelated lanes", MODULE.grade("safe-additive", output))

    def test_environment_profiles_require_parent_owned_static_preflight(self):
        for profile in ("environment-context", "environment-context-unknown-invalidation"):
            with self.subTest(profile=profile):
                output = packet(profile).replace(
                    "Parent preflight owns", "The reviewer owns"
                ).replace("- next owner: parent", "- next owner: reviewer").replace(
                    "this static reviewer does not execute or request", "the reviewer runs"
                )
                failures = MODULE.grade(profile, output)
                self.assertIn("parent-owned", " ".join(failures))
                self.assertIn("static reviewer", " ".join(failures))

    def test_keyword_stuffing_outside_evidence_sections_fails(self):
        output = packet("destructive-accounting").replace(
            "Deletion can remove live business rows", "No finding"
        )
        output += "\nAppendix copied prompt: deletion removes live business rows."
        self.assertIn("destructive business deletion", MODULE.grade("destructive-accounting", output))


if __name__ == "__main__":
    unittest.main()
