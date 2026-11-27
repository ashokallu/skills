#!/usr/bin/env python3
"""Validate database-reviewer environment-context snapshot semantics."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import pathlib
import re
import subprocess
import sys
from typing import Any

import yaml


CLASSIFICATIONS = {"configured", "observed", "exact", "estimated", "unavailable"}
ENVIRONMENT_CONTRACTS = {
    "staging": {
        "project": "example-app-staging",
        "collector_id": "staging-cloudsql-context-v1",
        "collector_path": "staging-cloudsql-collector.sql",
        "non_sql_query_ids": {
            "cloudsql_instance_metadata_v1", "cloudsql_disk_used_v1"
        },
    },
    "production": {
        "project": "example-app-prod",
        "collector_id": "production-cloudsql-context-v1",
        "collector_path": "production-cloudsql-collector.sql",
        "non_sql_query_ids": {
            "cloudsql_instance_metadata_v1", "cloudsql_disk_used_v1",
            "production_access_preflight_v1",
        },
    },
}
QUERY_ID_PATTERN = re.compile(r"^-- query_id: ([a-z0-9_]+)$", re.MULTILINE)
SOURCE_PATTERN = re.compile(r"^(.+):(\d+)(?:-(\d+))?$")


class ValidationError(ValueError):
    """Snapshot violates its evidence contract."""


def parse_time(value: Any, field: str) -> dt.datetime:
    if not isinstance(value, str):
        raise ValidationError(f"{field} must be a quoted RFC3339 timestamp")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValidationError(f"{field} is not RFC3339") from error
    if parsed.tzinfo is None:
        raise ValidationError(f"{field} must include a timezone")
    return parsed


def require(mapping: dict[str, Any], key: str, context: str) -> Any:
    if key not in mapping:
        raise ValidationError(f"missing {context}.{key}")
    return mapping[key]


def validate_source_anchor(
    repo_root: pathlib.Path, source_commit: str, source: str, value: Any
) -> None:
    match = SOURCE_PATTERN.fullmatch(source)
    if not match:
        raise ValidationError(f"invalid declared source anchor: {source}")
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ValidationError("declared source commit must be a full SHA")
    source_path = match.group(1)
    try:
        source_text = subprocess.check_output(
            ["git", "-C", str(repo_root), "show", f"{source_commit}:{source_path}"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError as error:
        raise ValidationError(
            f"declared source is unavailable at commit: {source_commit}:{source_path}"
        ) from error
    lines = source_text.splitlines()
    start = int(match.group(2))
    end = int(match.group(3) or start)
    if start < 1 or end < start or end > len(lines):
        raise ValidationError(f"declared source anchor is out of range: {source}")
    excerpt = "\n".join(lines[start - 1:end]).lower()
    expected = str(value).lower()
    if expected not in excerpt:
        raise ValidationError(f"declared source anchor does not contain value: {source}")


def validate_classifications(value: Any, path: str = "root") -> None:
    if isinstance(value, dict):
        if "classification" in value:
            classification = value["classification"]
            if classification not in CLASSIFICATIONS:
                raise ValidationError(f"unknown classification at {path}: {classification}")
            if "value" not in value and "fields" not in value:
                raise ValidationError(f"classified field lacks value at {path}")
            if classification == "unavailable" and "fields" not in value:
                if value["value"] is not None or not value.get("reason"):
                    raise ValidationError(f"unavailable field lacks null value/reason at {path}")
            elif "fields" not in value and value["value"] is None:
                raise ValidationError(f"available field has null value at {path}")
        for key, child in value.items():
            validate_classifications(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            validate_classifications(child, f"{path}[{index}]")


def validate_snapshot(
    snapshot_path: pathlib.Path,
    repo_root: pathlib.Path | None = None,
    *,
    allow_fixture: bool = False,
) -> None:
    data = yaml.safe_load(snapshot_path.read_text())
    if not isinstance(data, dict):
        raise ValidationError("snapshot root must be a mapping")
    is_fixture = data.get("status") == "illustrative_fixture"
    if is_fixture and not allow_fixture:
        raise ValidationError("illustrative fixture requires explicit fixture validation")
    repo_root = repo_root or next(
        (parent for parent in snapshot_path.resolve().parents if (parent / ".git").exists()), None
    )
    if repo_root is None and not is_fixture:
        raise ValidationError("snapshot is not inside a git worktree")

    for key in (
        "schema_version", "snapshot_id", "environment", "project",
        "observed_at", "valid_until", "maximum_validity_days", "collector",
        "non_sql_collector", "declared_source_commit", "declared_topology",
        "live_observed", "invalidators", "invalidation_check", "limitations",
        "failed_probes",
    ):
        require(data, key, "root")

    observed_at = parse_time(data["observed_at"], "observed_at")
    valid_until = parse_time(data["valid_until"], "valid_until")
    if valid_until <= observed_at:
        raise ValidationError("valid_until must be after observed_at")
    maximum = dt.timedelta(days=int(data["maximum_validity_days"]))
    if valid_until - observed_at > maximum:
        raise ValidationError("valid_until exceeds maximum_validity_days")

    collector = data["collector"]
    environment = data["environment"]
    contract = ENVIRONMENT_CONTRACTS.get(environment)
    if contract is None:
        raise ValidationError(f"unknown environment: {environment}")
    if data["project"] != contract["project"]:
        raise ValidationError("environment and project do not match")
    if collector.get("id") != contract["collector_id"]:
        raise ValidationError("environment and collector id do not match")
    if collector.get("path") != contract["collector_path"]:
        raise ValidationError("environment and collector path do not match")
    collector_path = snapshot_path.parent / require(collector, "path", "collector")
    collector_text = collector_path.read_text()
    actual_hash = hashlib.sha256(collector_text.encode()).hexdigest()
    if require(collector, "sha256", "collector") != actual_hash:
        raise ValidationError("collector sha256 does not match tracked definition")
    declared_ids = set(require(collector, "query_ids", "collector"))
    defined_ids = set(QUERY_ID_PATTERN.findall(collector_text))
    if declared_ids != defined_ids:
        raise ValidationError("collector query_ids do not match tracked definitions")

    non_sql = data["non_sql_collector"]
    non_sql_path = snapshot_path.parent / require(non_sql, "path", "non_sql_collector")
    non_sql_text = non_sql_path.read_text()
    non_sql_hash = hashlib.sha256(non_sql_text.encode()).hexdigest()
    if require(non_sql, "sha256", "non_sql_collector") != non_sql_hash:
        raise ValidationError("non-SQL collector sha256 does not match tracked definition")
    non_sql_data = yaml.safe_load(non_sql_text)
    if non_sql.get("id") != non_sql_data.get("collector_id"):
        raise ValidationError("non-SQL collector id does not match tracked definition")
    non_sql_ids = set(non_sql.get("query_ids", []))
    if non_sql_ids != contract["non_sql_query_ids"]:
        raise ValidationError("environment requires a different non-SQL query-id set")
    if not non_sql_ids <= set(non_sql_data.get("queries", {})):
        raise ValidationError("non-SQL query_ids do not match tracked definitions")

    bounds = data["collection_bounds"]
    for field in ("exact_counts_run", "explain_analyze_run", "row_samples_read", "payloads_read"):
        if bounds.get(field) is not False:
            raise ValidationError(f"unsafe collection bound enabled: {field}")

    declared = data["declared_topology"]
    source_commit = declared.get("source_commit")
    if declared.get("classification") != "configured" or not source_commit:
        raise ValidationError("declared topology lacks configured classification/provenance")
    if source_commit != data["declared_source_commit"]:
        raise ValidationError("declared source commit fields disagree")
    for name, field in require(declared, "fields", "declared_topology").items():
        if (
            "value" not in field
            or field.get("classification") != "configured"
            or not field.get("source")
        ):
            raise ValidationError(f"declared field lacks configured value/source: {name}")
        if is_fixture:
            if not SOURCE_PATTERN.fullmatch(field["source"]) or not re.fullmatch(r"[0-9a-f]{40}", source_commit):
                raise ValidationError(f"invalid fixture source anchor: {name}")
        else:
            validate_source_anchor(repo_root, source_commit, field["source"], field["value"])

    live = data["live_observed"]
    for section in ("instance_metadata", "monitoring", "database", "settings", "relation_summary"):
        if not require(live, section, "live_observed").get("provenance"):
            raise ValidationError(f"live section lacks observation provenance: {section}")
    largest = require(live, "largest_physical_relations", "live_observed")
    if not largest.get("provenance"):
        raise ValidationError("largest relations lack observation provenance")

    summary = live["relation_summary"]
    rows = require(largest, "rows", "largest_physical_relations")
    listed = summary["listed_relation_count"]["value"]
    omitted = summary["omitted_relation_count"]["value"]
    total = summary["physical_relation_count"]["value"]
    aggregate_components = sum(
        summary[field]["value"]
        for field in (
            "heap_total_bytes", "index_total_bytes", "toast_total_bytes",
            "auxiliary_total_bytes",
        )
    )
    if aggregate_components != summary["user_relation_total_bytes"]["value"]:
        raise ValidationError("aggregate relation byte components do not sum")
    limit = data["collection_bounds"]["relation_limit"]
    if listed != len(rows) or listed > limit or listed + omitted != total:
        raise ValidationError("relation listing/count/limit invariants do not match")
    for index, row in enumerate(rows):
        for field in (
            "total_bytes", "heap_bytes", "index_bytes", "toast_bytes", "auxiliary_bytes"
        ):
            if row[field].get("classification") != "exact":
                raise ValidationError(f"relation byte field is not exact at row {index}")
        components = sum(
            row[field]["value"]
            for field in ("heap_bytes", "index_bytes", "toast_bytes", "auxiliary_bytes")
        )
        if components != row["total_bytes"]["value"]:
            raise ValidationError(f"relation byte components do not sum at row {index}")
        estimate = row["estimated_live_rows"]
        if estimate.get("classification") == "estimated":
            if type(estimate.get("value")) is not int or estimate["value"] < 0:
                raise ValidationError(f"row estimate is invalid at row {index}")
        elif estimate.get("classification") == "unavailable":
            if estimate.get("value") is not None or not estimate.get("reason"):
                raise ValidationError(f"unavailable row estimate lacks reason at row {index}")
        else:
            raise ValidationError(f"row cardinality is unlabeled at row {index}")
        if row["statistics_at"].get("classification") not in {"observed", "unavailable"}:
            raise ValidationError(f"statistics timestamp is unlabeled at row {index}")

    if environment == "production":
        if data["collection_bounds"].get("source") != "confirmed_read_replica":
            raise ValidationError("Production collection source is not the confirmed replica")
        if bounds.get("transaction_mode") != "read_only":
            raise ValidationError("Production collection bound is not read-only")
        if bounds.get("statement_timeout_ms") != 10000:
            raise ValidationError("Production collection timeout is not 10000 ms")
        preflight = live.get("access_preflight", {})
        if preflight.get("provenance", {}).get("query_id") != "production_access_preflight_v1":
            raise ValidationError("Production access preflight provenance is missing")
        vpn = preflight.get("vpn_smoke_passed", {})
        if vpn.get("value") is not True or vpn.get("classification") != "observed":
            raise ValidationError("Production VPN preflight did not pass")
        if live["database"]["is_replica"] != {"value": True, "classification": "observed"}:
            raise ValidationError("Production database identity lacks replica SQL proof")
        recovery = live["instance_metadata"]["replica"]["sql_recovery_state"]
        if recovery.get("value") is not True or recovery.get("classification") != "observed":
            raise ValidationError("Production replica recovery state is not observed true")
        for section in ("database", "settings", "relation_summary", "largest_physical_relations"):
            provenance = live[section]["provenance"]
            if provenance.get("transaction_mode") != "read_only":
                raise ValidationError(f"Production live section is not read-only: {section}")
            if provenance.get("statement_timeout_ms") != 10000:
                raise ValidationError(f"Production live section lacks timeout: {section}")
        if any(row["statistics_at"].get("classification") != "unavailable" for row in rows):
            raise ValidationError("Production replica rows misstate primary statistics timestamps")

    validate_classifications(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", action="store_true", help="validate the structure of illustrative snapshots")
    parser.add_argument("paths", nargs="*", type=pathlib.Path)
    args = parser.parse_args()
    paths = args.paths
    if not paths:
        paths = [pathlib.Path(".codex/skills/database-reviewer/evidence/staging-cloudsql.yaml")]
    try:
        for path in paths:
            validate_snapshot(path, allow_fixture=args.fixture)
    except (OSError, KeyError, TypeError, ValidationError, yaml.YAMLError) as error:
        print(f"environment context invalid: {error}", file=sys.stderr)
        return 1
    label = "fixture structure" if args.fixture else "environment context"
    print(f"{label} valid: {len(paths)} snapshot(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
