#!/usr/bin/env python3
"""Structured grader for reviewer convention-lens behavior evals."""

from __future__ import annotations

import re
import sys


FIELDS = (
    "convention disposition",
    "standard state",
    "search scope",
    "finding owner",
    "pending verification",
    "reason",
)

PROFILES = {
    "authoritative-precedent": {
        "convention disposition": "FINDING",
        "standard state": "AUTHORITATIVE",
        "search scope": "OWNER_BOUNDED",
        "finding owner": "CONVENTIONS",
        "pending verification": "NO",
        "reason": r"(?=.*(?:second helper|another helper|dual path|behavior divergence))(?=.*(?:authoritative|established|documented))",
    },
    "conflicting-precedents": {
        "convention disposition": "NO_FINDING",
        "standard state": "CONFLICTING",
        "search scope": "INPUT_SUFFICIENT",
        "finding owner": "NONE",
        "pending verification": "NO",
        "reason": r"(?=.*(?:conflict|coexist|two current))(?=.*(?:no documented owner|no authoritative|without an authoritative|ambiguity|evidence.boundary))(?=.*(?:no.finding|rather than.{0,100}finding|non.material|no material|not material|not.{0,100}finding))",
    },
    "justified-divergence": {
        "convention disposition": "NO_FINDING",
        "standard state": ("JUSTIFIED", "AUTHORITATIVE"),
        "search scope": ("OWNER_BOUNDED", "INPUT_SUFFICIENT"),
        "finding owner": "NONE",
        "pending verification": "NO",
        "reason": r"(?=.*(?:replacement|migrat|shared helper))(?=.*(?:no dual|single|no mixed|alignment|documented))",
    },
    "no-standard": {
        "convention disposition": "NO_FINDING",
        "standard state": "NONE",
        "search scope": "OWNER_BOUNDED",
        "finding owner": "NONE",
        "pending verification": "NO",
        "reason": r"(?=.*no.{0,100}(?:standard|helper|sibling))(?=.*(?:not material|non.material|immaterial|no material effect|no defect|no finding))",
    },
    "pure-nit": {
        "convention disposition": "NO_FINDING",
        "standard state": "NIT",
        "search scope": "INPUT_SUFFICIENT",
        "finding owner": "NONE",
        "pending verification": "NO",
        "reason": r"(?=.*(?:not material|non.material|not actionable|pure nit|stylistic nit|naming nit|taste.only))(?=.*(?:no.{0,100}(?:impact|effect|finding)|unchanged|does not survive|remains only))",
    },
    "stronger-lens-dedupe": {
        "convention disposition": "FINDING",
        "standard state": "AUTHORITATIVE",
        "search scope": ("OWNER_BOUNDED", "INPUT_SUFFICIENT"),
        "finding owner": "SECURITY_PRIVACY",
        "pending verification": "NO",
        "reason": r"(?=.*(?:sensitive|privacy|tenant data))(?=.*(?:security|stronger|primary))(?=.*(?:redact|single|one|dedup))",
    },
}


def parse_fields(output: str) -> tuple[dict[str, str], list[str]]:
    parsed: dict[str, str] = {}
    failures: list[str] = []
    for name in FIELDS:
        matches = re.findall(
            rf"(?im)(?:^|[\r\n.!?])\s*(?:[-*]\s*)?(?:\*\*)?{re.escape(name)}(?:\*\*)?\s*:\s*([^\r\n]+?)\s*$",
            output,
        )
        if len(matches) != 1:
            failures.append(f"exactly one {name} field")
        else:
            parsed[name] = re.sub(r"[*`]", "", matches[0]).strip()
    return parsed, failures


def grade(profile: str, output: str) -> list[str]:
    expected = PROFILES[profile]
    fields, failures = parse_fields(output)
    for name in FIELDS[:-1]:
        allowed = expected[name] if isinstance(expected[name], tuple) else (expected[name],)
        if name in fields and fields[name].upper() not in allowed:
            failures.append(f"{name} must be one of {', '.join(allowed)}")
    if "reason" in fields and not re.search(expected["reason"], fields["reason"], re.I | re.S):
        failures.append("reason must support the disposition")

    reason = fields.get("reason", "").lower()
    if expected["convention disposition"] == "FINDING" and re.search(r"\bno[_ -]?finding\b|\bno (?:formal )?finding\b", reason):
        failures.append("reason contradicts FINDING disposition")
    if expected["convention disposition"] == "NO_FINDING" and re.search(r"\b(?:emit|retain|report|raise|is) (?:a )?(?:p[012] )?(?:formal )?finding\b|\bblock(?:ed)?\b", reason):
        failures.append("reason contradicts NO_FINDING disposition")
    return list(dict.fromkeys(failures))


def valid_packet(profile: str) -> str:
    expected = PROFILES[profile]
    reasons = {
        "authoritative-precedent": "The documented authoritative owner makes the second helper a material dual path.",
        "conflicting-precedents": "The conflict has no authoritative winner and is not material.",
        "justified-divergence": "The documented replacement migrates callers and leaves no dual path.",
        "no-standard": "No clear standard exists and the choice is not material, so there is no finding.",
        "pure-nit": "This pure nit is not material and does not survive the candidate filter.",
        "stronger-lens-dedupe": "Sensitive tenant data creates one stronger privacy finding; convention evidence is deduplicated.",
    }
    values = {
        name: value[0] if isinstance(value, tuple) else value
        for name, value in expected.items()
    }
    values["reason"] = reasons[profile]
    return "\n".join(f"{name.title()}: {values[name]}" for name in FIELDS)


def self_test() -> list[str]:
    failures: list[str] = []
    alternatives = {
        "convention disposition": {"FINDING": "NO_FINDING", "NO_FINDING": "FINDING"},
        "standard state": {"AUTHORITATIVE": "NONE", "CONFLICTING": "AUTHORITATIVE", "JUSTIFIED": "CONFLICTING", "NONE": "AUTHORITATIVE", "NIT": "AUTHORITATIVE"},
        "search scope": {"OWNER_BOUNDED": "REPOSITORY_WIDE", "INPUT_SUFFICIENT": "REPOSITORY_WIDE"},
        "finding owner": {"CONVENTIONS": "NONE", "NONE": "CONVENTIONS", "SECURITY_PRIVACY": "CONVENTIONS"},
        "pending verification": {"NO": "YES"},
    }
    inverted_reasons = {
        "authoritative-precedent": "No finding exists because mandatory selection is sufficient.",
        "conflicting-precedents": "Emit a P2 finding merely because the patterns conflict.",
        "justified-divergence": "Block the change and retain a formal finding.",
        "no-standard": "Emit a P2 finding because no standard exists.",
        "pure-nit": "Block the change and report a formal naming finding.",
        "stronger-lens-dedupe": "Emit separate security and convention findings.",
    }
    for profile in PROFILES:
        packet = valid_packet(profile)
        if grade(profile, packet):
            failures.append(f"valid packet rejected: {profile}")
        for field, mapping in alternatives.items():
            configured = PROFILES[profile][field]
            expected = configured[0] if isinstance(configured, tuple) else configured
            mutated = re.sub(
                rf"(?im)^({re.escape(field.title())}:\s*){re.escape(expected)}$",
                rf"\g<1>{mapping[expected]}",
                packet,
            )
            if not grade(profile, mutated):
                failures.append(f"inverted {field} accepted: {profile}")
        mutated = re.sub(r"(?im)^Reason:.*$", f"Reason: {inverted_reasons[profile]}", packet)
        if not grade(profile, mutated):
            failures.append(f"inverted reason accepted: {profile}")
    return failures


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        failures = self_test()
    elif len(sys.argv) == 2 and sys.argv[1] in PROFILES:
        failures = grade(sys.argv[1], sys.stdin.read())
    else:
        print("usage: existing_conventions_contract.py <profile|--self-test>")
        return 2
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("all deterministic contract requirements passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
