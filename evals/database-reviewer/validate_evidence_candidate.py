#!/usr/bin/env python3
"""Validate optional database operation evidence candidate records."""

from __future__ import annotations

import datetime as dt
import pathlib
import re
import sys
from typing import Any

import yaml


RELEVANCE_CLASSES = {"direct", "comparable", "contextual"}
PROVENANCE_CLASSES = {"agent_attested_non_replayable"}


class ValidationError(ValueError):
    """Candidate violates the historical-evidence contract."""


def require(mapping: dict[str, Any], key: str, context: str) -> Any:
    if key not in mapping:
        raise ValidationError(f"missing {context}.{key}")
    return mapping[key]


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


def validate_candidate(path: pathlib.Path) -> None:
    data = yaml.safe_load(path.read_text())
    if not isinstance(data, dict):
        raise ValidationError("candidate root must be a mapping")

    for key in (
        "schema_version", "record_kind", "record_id", "record_version",
        "environment", "engine", "observed_at", "completed_at", "provenance",
        "operation", "claim_groups", "relevance", "limitations", "supersedes",
    ):
        require(data, key, "root")

    if data["schema_version"] != 1:
        raise ValidationError("unsupported schema_version")
    if data["record_kind"] != "database_operation_evidence_candidate":
        raise ValidationError("unexpected record_kind")
    if not re.fullmatch(r"[a-z0-9-]+", str(data["record_id"])):
        raise ValidationError("record_id must be a stable lowercase slug")
    version = data["record_version"]
    if type(version) is not int or version < 1:
        raise ValidationError("record_version must be a positive integer")

    observed = parse_time(data["observed_at"], "observed_at")
    completed = parse_time(data["completed_at"], "completed_at")
    if completed < observed:
        raise ValidationError("completed_at precedes observed_at")

    provenance = data["provenance"]
    classification = require(provenance, "classification", "provenance")
    if classification not in PROVENANCE_CLASSES:
        raise ValidationError("unsupported provenance classification")
    if provenance.get("independently_replayable") is not False:
        raise ValidationError("agent-attested evidence must be non-replayable")
    if provenance.get("portable_source_artifact_retained") is not False:
        raise ValidationError("candidate overstates retained primary evidence")
    for key in ("basis", "limitation"):
        if not str(require(provenance, key, "provenance")).strip():
            raise ValidationError(f"provenance.{key} must be non-empty")

    claim_groups = data["claim_groups"]
    if not isinstance(claim_groups, dict) or not claim_groups:
        raise ValidationError("claim_groups must be non-empty")
    for name, group in claim_groups.items():
        if group.get("provenance_class") != classification:
            raise ValidationError(f"claim group provenance mismatch: {name}")

    relevance = data["relevance"]
    if not isinstance(relevance, dict) or not relevance:
        raise ValidationError("relevance must be non-empty")
    if not set(relevance) <= RELEVANCE_CLASSES:
        raise ValidationError("unknown relevance classification")
    for name, claims in relevance.items():
        if not isinstance(claims, list) or not claims or not all(str(x).strip() for x in claims):
            raise ValidationError(f"relevance.{name} must contain claims")

    limitations = data["limitations"]
    if not isinstance(limitations, list) or len(limitations) < 3:
        raise ValidationError("candidate must state currentness and repeatability limits")

    if version > 1:
        correction = require(data, "correction", "root")
        for key in ("corrected_at", "reason"):
            if not str(require(correction, key, "correction")).strip():
                raise ValidationError(f"correction.{key} must be non-empty")
        parse_time(correction["corrected_at"], "correction.corrected_at")
        prior = correction.get("prior_git_commit")
        if prior is not None and not re.fullmatch(r"[0-9a-f]{7,40}", str(prior)):
            raise ValidationError("correction.prior_git_commit is invalid")


def main() -> int:
    paths = [pathlib.Path(arg) for arg in sys.argv[1:]]
    if not paths:
        paths = [
            pathlib.Path(
                ".codex/skills/database-reviewer/evidence/"
                "production-content-user-progress-created-at-index-20260716.yaml"
            )
        ]
    try:
        for path in paths:
            validate_candidate(path)
    except (OSError, ValidationError, yaml.YAMLError) as error:
        print(f"evidence candidate validation failed: {error}", file=sys.stderr)
        return 1
    print(f"evidence candidate validation passed: {len(paths)} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
