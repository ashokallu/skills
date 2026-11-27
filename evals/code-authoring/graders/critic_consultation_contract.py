#!/usr/bin/env python3
"""Deterministic terminal-contact checks for critic-consultation behavior."""

from __future__ import annotations

import re
import sys


def case_section(output: str, case: str, next_case: str | None = None) -> str:
    heading = rf"(?im)^\s*(?:#+\s*)?(?:[*_]{{0,2}})case\s+{case}:.*$"
    start = re.search(heading, output)
    if not start:
        return ""
    end = re.search(
        rf"(?im)^\s*(?:#+\s*)?(?:[*_]{{0,2}})case\s+{next_case}:.*$",
        output[start.end():],
    ) if next_case else None
    stop = start.end() + end.start() if end else len(output)
    return output[start.end():stop]


def has_affirmative_action(
    text: str,
    actor: str,
    action: str,
    target: str,
) -> bool:
    for sentence in re.split(r"(?<=[.!?])\s+|\n+", text):
        match = re.search(
            rf"\b(?:{actor})\b(?P<before>.{{0,100}}?)\b(?:{action})\b(?P<after>.{{0,80}}?)\b(?:{target})\b",
            sentence,
            re.IGNORECASE,
        )
        if not match:
            continue
        before_action = match.group("before")
        if not re.search(
            r"\b(?:not|never|cannot|can't|mustn't|forbids?|prohibits?)\b",
            before_action,
            re.IGNORECASE,
        ):
            return True
    return False


def makes_contact_three_terminal(text: str) -> bool:
    for sentence in re.split(r"(?<=[.!?])\s+|\n+", text):
        match = re.search(
            r"(?:\bcontact\s*3\b(?P<after>.{0,80}?)\bterminal\b|"
            r"\bterminal\b(?P<before>.{0,80}?)\bcontact\s*3\b)",
            sentence,
            re.IGNORECASE,
        )
        if not match:
            continue
        bridge = match.group("after") or match.group("before") or ""
        if not re.search(r"\b(?:not|never|cannot|can't)\b", bridge, re.IGNORECASE):
            return True
    return False


def reenters_closed_lineage(text: str) -> bool:
    for sentence in re.split(r"(?<=[.!?])\s+|\n+", text):
        match = re.search(
            r"\bre-?enter(?:s|ed|ing)?\b.{0,80}\b(?:critic|critique)\b"
            r".{0,80}\b(?:same|existing|current)\s+lineage\b",
            sentence,
            re.IGNORECASE,
        )
        if not match:
            continue
        prefix = sentence[max(0, match.start() - 60):match.start()]
        if not re.search(
            r"\b(?:not|never|cannot|can't|mustn't|forbids?|prohibits?)\b",
            prefix,
            re.IGNORECASE,
        ):
            return True
    return False


def grade(output: str) -> list[str]:
    """Return terminal-contact contract failures found in candidate output."""
    failures: list[str] = []
    case_b = case_section(output, "B", "C")
    case_c = case_section(output, "C")

    if not makes_contact_three_terminal(case_b):
        failures.append("Case B does not make contact 3 terminal")
    if has_affirmative_action(
        case_b,
        r"contact\s*3|it|the\s+critic",
        r"requests?|asks?|seeks?|invites?|allows?|permits?",
        r"revisions?|revision\s+cycle",
    ):
        failures.append("Case B lets contact 3 request another revision")
    if reenters_closed_lineage(case_c):
        failures.append("Case C re-enters critic under the closed lineage")
    return failures


def main() -> int:
    failures = grade(sys.stdin.read())
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("all deterministic critic-contact requirements passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
