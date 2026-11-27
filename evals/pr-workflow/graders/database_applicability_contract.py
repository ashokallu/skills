#!/usr/bin/env python3
"""Deterministic grader for the parent-owned database applicability gate."""

from __future__ import annotations

import re
import sys


def has(text: str, pattern: str) -> bool:
    return bool(re.search(pattern, text, re.IGNORECASE | re.DOTALL))


def grade(profile: str, output: str) -> list[str]:
    failures: list[str] = []
    prohibitions: dict[str, str] = {}
    positive_live_access = (
        r"\bno\s+(?:objection|problem|restriction|bar)\b.{0,120}"
        r"\b(?:live|staging|production|database|monitoring)\b"
        r"|\bno\s+reason\s+not\s+to\b.{0,80}"
        r"\b(?:allow|permit|authorize|access|read|query|inspect|refresh|collect)\b"
        r".{0,80}\b(?:live|staging|production|database|monitoring)\b"
        r"|\b(?:may|can|should)\s+(?:still\s+)?"
        r"(?:access|read|query|inspect|refresh|collect|use)\b.{0,100}"
        r"\b(?:live|staging|production|database|monitoring)\b"
        r"|(?:^|[.!?]\s+)(?!no\b)"
        r"(?:live|staging|production|database|monitoring)\b.{0,100}"
        r"\b(?:it\s+)?(?:is|are)\s+(?!not\b)(?:allowed|permitted|authorized)\b"
    )
    if profile == "classification":
        requirements = {
            "direct database change is required": r"(?=.*\brequired\b)(?=.*(?:sql|migration|index))(?=.*direct.{0,120}database(?: consequence|-behavior| behavior))",
            "indirect database consequence is required": r"(?=.*\brequired\b)(?=.*(?:indirect|without (?:touching|edit(?:ed|ing)) (?:`?\.sql|sql)|n\+1|database (?:consequence|interaction shape)))",
            "negative trace supports not required": r"(?:not required).{0,240}(?:negative trace|unchanged|no database consequence)",
            "ambiguity fails closed": r"(?=.*pending verification)(?=.*fails?[- ]closed)",
            "environment scope is independent": r"(?=.*(?:environment evidence|live environment|environment materiality))(?=.*(?:separat|independent|only after applicability|applicability is established))",
            "classification grants no live access": r"(?=.*(?:does not|no|never).{0,80}(?:authorize|grant).{0,80}live)(?=.*(?:fresh|classif).{0,120}(?:validation|production.readiness))",
        }
        prohibitions = {
            "classification positively authorizes live access": positive_live_access,
        }
    elif profile == "blocking":
        requirements = {
            "ordinary reviewer starts independently": r"ordinary reviewer.{0,220}(?:immediate|does not wait|independent)",
            "required database review is non-waivable": r"(?:non.?waiv|cannot waive|does not waive).{0,220}(?:database|sibling)|database.{0,220}(?:non.?waiv|cannot waive|does not waive)",
            "first push is blocked": r"(?:block|blocked).{0,40}first push|first push(?:\s+(?:is|remains))?\s+blocked",
            "PR creation is blocked": r"pr creation.{0,180}block|block.{0,180}pr creation",
            "approval is blocked": r"approval.{0,180}block|block.{0,180}approval",
            "overall handoff is blocked": r"(?:overall|review).{0,100}handoff.{0,180}block|block.{0,180}(?:overall|review).{0,100}handoff",
            "parent combines independent verdicts": r"parent.{0,220}(?:combine|synthesi).{0,180}(?:ordinary|database)",
        }
    elif profile == "static_boundary":
        requirements = {
            "ordinary review is static": r"ordinary (?:pr )?review.{0,220}static",
            "both reviewers dispatch without preflight": r"(?=.*ordinary reviewer.{0,220}(?:immediate|dispatch|start))(?=.*database reviewer.{0,220}(?:immediate|dispatch|start))(?=.*(?:no|without).{0,80}(?:environment )?preflight)",
            "live evidence is forbidden": r"(?=.*(?:no|must not|forbid).{0,100}(?:live|staging|production|database|monitoring))",
            "missing proof is pending verification": r"(?=.*missing.{0,240}pending\s+verification)",
            "no readiness upgrade": r"(?=.*(?:does not|must not|cannot).{0,100}(?:prove|upgrade|grant|claim).{0,80}(?:ready|readiness|safe))",
            "separate phase reclassifies": r"(?=.*(?:separate|new).{0,120}(?:validation|production.readiness).{0,160}(?:fresh|reclassif))",
            "review authority does not carry": r"(?=.*(?:authority|permission).{0,120}(?:does not|must not|cannot|never).{0,80}(?:carry|transfer|persist))",
            "mandatory Git setup remains authorized": (
                r"(?:\b(?:authorized|required|allowed|permitted)\b"
                r"[^.!?]{0,160}\bfetch(?:ing)?\b"
                r"[^.!?]{0,160}\bworktree\b"
                r"[^.!?]{0,160}\brebase\b"
                r"|\bfetch(?:ing)?\b"
                r"[^.!?]{0,160}\bworktree\b"
                r"[^.!?]{0,160}\brebase\b"
                r"[^.!?]{0,160}\b(?:authorized|required|allowed|permitted)\b)"
            ),
            "helper evidence files are forbidden": r"(?=.*(?:do not|must not|cannot|forbid).{0,120}(?:helper|evidence).{0,80}(?:file|artifact|temporary|storage))",
        }
        prohibitions = {
            "live evidence is positively authorized": positive_live_access,
            "reviewers wait for environment preflight": (
                r"\b(?:dispatch|start)\b.{0,100}\b(?:after|following|once)\b"
                r".{0,60}\b(?:environment\s+)?preflight\b"
                r"|\b(?:environment\s+)?preflight\b.{0,80}\b(?:before|then)\b"
                r".{0,80}\b(?:dispatch|start)\b"
            ),
            "missing evidence positively upgrades readiness": (
                r"\bmissing\b.{0,200}\b(?:may|can|does|will)\s+(?!not\b)"
                r"(?:still\s+)?(?:prove|upgrade|grant|claim|establish)\b"
                r".{0,100}\b(?:ready|readiness|safe)\b"
                r"|\bmissing\b.{0,180}\b(?:is|remains)\s+(?!not\b)"
                r"(?:enough|sufficient)\b.{0,80}\b(?:ready|readiness|safe)\b"
            ),
            "review authority positively carries forward": (
                r"\b(?:authority|permission)\b.{0,120}"
                r"\b(?:carries|transfers|persists)\b"
            ),
            "mandatory Git setup is called unauthorized": (
                r"\b(?:fetch|worktree|rebase)\b.{0,120}"
                r"\b(?:unauthorized|forbidden|violation)\b"
            ),
            "mandatory Git setup is made optional": (
                r"\b(?:fetch|worktree|rebase)\b.{0,120}"
                r"\b(?:optional|unnecessary|not required|may skip|can skip)\b"
                r"|\b(?:may skip|can skip)\b.{0,120}"
                r"\b(?:fetch|worktree|rebase)\b"
            ),
            "temporary evidence persistence is allowed": (
                r"\b(?:may|can|should|is allowed to)\b.{0,80}"
                r"\b(?:write|create|persist|store)\b.{0,100}"
                r"\b(?:helper|evidence)\b.{0,80}\b(?:file|artifact)\b"
            ),
        }
    else:
        return ["unknown profile"]
    for name, pattern in requirements.items():
        if not has(output, pattern):
            failures.append(name)
    for name, pattern in prohibitions.items():
        if has(output, pattern):
            failures.append(name)
    return failures


def self_test() -> list[str]:
    classification = """
    A direct SQL or migration change proves a direct database consequence and is
    required. An indirect runtime query-load
    consequence is also required. A wording-only change is not required only
    after a negative trace proves the persistence path is unchanged and has no
    database consequence. Ambiguity is Pending Verification and fails closed by
    blocking the phase. Environment materiality is a separate independent
    decision and may be neither for a source-only change.
    Classification does not authorize live access. A fresh classification is
    required for a separately requested validation or production-readiness
    phase.
    """
    blocking = """
    The ordinary reviewer starts immediately and remains independent. Required
    database sibling review is non-waivable. If unavailable, block first push,
    block PR creation, block approval, and block the overall review handoff.
    The parent combines the ordinary and database verdicts.
    """
    static_boundary = """
    Ordinary PR review is static. Dispatch the ordinary reviewer immediately
    and start the database reviewer immediately from checked-in evidence and
    explicit gaps, without environment preflight. No live Production,
    database, or monitoring access is allowed. Missing current proof is Pending
    Verification and does not prove or upgrade readiness. A separate validation
    or production-readiness phase requires fresh classification, and review
    authority does not carry into it. Fetching explicit refs, creating the
    canonical worktree, and performing the required local rebase are authorized
    review setup. Do not create or persist a helper evidence file in temporary
    storage.
    """
    failures: list[str] = []
    if grade("classification", classification):
        failures.append("valid classification rejected")
    if grade("blocking", blocking):
        failures.append("valid blocking contract rejected")
    if grade("static_boundary", static_boundary):
        failures.append("valid static boundary rejected")
    if not grade("classification", classification.replace("Pending Verification", "not required").replace("fails closed", "is allowed")):
        failures.append("ambiguous fail-closed omission accepted")
    if not grade("blocking", blocking.replace("block first push", "allow first push")):
        failures.append("first-push escape accepted")
    if not grade("static_boundary", static_boundary.replace("without environment preflight", "after environment preflight")):
        failures.append("environment preflight escape accepted")
    if not grade("static_boundary", static_boundary.replace("does not carry", "carries")):
        failures.append("authority carryover accepted")
    if not grade(
        "classification",
        classification
        + "\nThere is no reason not to authorize live access from classification.",
    ):
        failures.append("classification live-access contradiction accepted")
    if not grade(
        "static_boundary",
        static_boundary
        + "\nNo objection exists to live Production database access; it is permitted.",
    ):
        failures.append("live-access contradiction accepted")
    if not grade(
        "static_boundary",
        static_boundary + "\nMissing current proof can still prove readiness.",
    ):
        failures.append("readiness-upgrade contradiction accepted")
    if not grade(
        "static_boundary",
        static_boundary
        + "\nFetching refs and rebasing the review worktree are unauthorized violations.",
    ):
        failures.append("mandatory setup misclassification accepted")
    if not grade(
        "static_boundary",
        static_boundary.replace("authorized", "described"),
    ):
        failures.append("unclassified mandatory setup accepted")
    if not grade(
        "static_boundary",
        static_boundary + "\nThe local rebase is optional.",
    ):
        failures.append("optional mandatory setup accepted")
    if not grade(
        "static_boundary",
        static_boundary + "\nThe review may write a helper evidence file locally.",
    ):
        failures.append("temporary evidence persistence accepted")
    return failures


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        failures = self_test()
    elif len(sys.argv) == 2:
        failures = grade(sys.argv[1], sys.stdin.read())
    else:
        print("usage: database_applicability_contract.py <classification|blocking|static_boundary> | --self-test")
        return 2
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("database applicability contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
