#!/usr/bin/env python3
"""Deterministic grader for same-response reviewer comment economy."""

from __future__ import annotations

import re
import sys


def has(text: str, pattern: str) -> bool:
    return bool(re.search(pattern, text, re.IGNORECASE | re.DOTALL))


def grade(profile: str, output: str) -> list[str]:
    output = re.sub(r"\s+", " ", output)
    failures: list[str] = []
    common_prohibitions = {
        "comments authorize publication": r"(?:prepar|return|include).{0,100}(?:comment|bod).{0,120}(?<!never )(?<!not )(?<!no )(?:authorizes|grants|permits)(?!\s+(?:neither|no|not)).{0,80}(?:publication|publish|github|mutation)",
    }

    if profile in {"reviewer", "database"}:
        reviewer_name = "database reviewer" if profile == "database" else "ordinary reviewer"
        requirements = {
            "correct reviewer context": r"\bdatabase(?: reviewer| review|[- ]verdict)\b" if profile == "database" else r"\b(?:ordinary )?reviewer\b",
            "complete verdict remains mandatory": r"(?:complete|full|canonical).{0,120}(?:packet|verdict)",
            "clean review omits comments": r"(?:clean review|clean.{0,40}(?:zero|no) (?:formal )?findings?|(?:zero|no) (?:formal )?findings?).{0,160}(?:omit|without|no).{0,100}(?:review comments|comment section|that section)|omit.{0,100}(?:clean review|clean.{0,40}(?:zero|no) (?:formal )?findings?|(?:zero|no) (?:formal )?findings?)|(?:zero|no) (?:formal )?findings?.{0,140}(?:review comments|comment section).{0,80}omit",
            "verdict-only is explicit": r"verdict[- ]only.{0,180}(?:explicit|triage)",
            "minimal comment fields": r"review event.{0,160}unanchored findings.{0,160}summary.{0,220}(?:finding|comment).{0,160}anchor json.{0,160}body",
            "finding ordinals form exact partition": r"(?:partition|disjoint).{0,180}(?:finding|ordinal)|(?:finding|ordinal).{0,180}(?:partition|disjoint)|(?:finding|ordinal).{0,160}exactly once.{0,120}(?:inline|unanchored)|exactly once.{0,120}(?:inline|unanchored).{0,160}(?:finding|ordinal)",
            "p0 or p1 requests changes": r"(?:p0|p1).{0,120}request_changes|request_changes.{0,120}(?:p0|p1)",
            "p2 or p3 comments": r"(?:p2|p3)(?:[- ]only)?.{0,120}(?:selects?|uses?|event).{0,80}\bcomment\b|\bcomment\b.{0,120}(?:p2|p3)(?:[- ]only)?",
            "reviewer owns exact wording": rf"{reviewer_name}.{{0,180}}(?:owns|authors).{{0,180}}(?:exact|body|summary|wording)|reviewer.{{0,180}}(?:owns|authors).{{0,180}}(?:exact|body|summary|wording)|(?:public )?wording.{{0,180}}(?:owned|authored).{{0,100}}{reviewer_name}|(?:public )?wording.{{0,180}}(?:owned|authored).{{0,100}}reviewer|reviewer[- ]owned exact.{{0,120}}(?:text|bytes|body|summary)",
            "no model digest ceremony": r"(?:no (?:model or )?reviewer (?:emits|produces|calculates)|reviewer (?:does.{0,8}not|must not|never).{0,8}(?:emit|produce|calculate)|reviewer emits neither|does.{0,8}not.{0,8}(?:emit|produce|calculate)).{0,180}(?:sha-?256|base64|byte[- ]count)|(?:returns|uses).{0,100}(?:text|utf-8).{0,30}not.{0,180}(?:sha-?256|base64|byte[- ]count)",
            "no second comment-only turn": r"(?:\bno\b|does not|must not|never).{0,30}(?:second|later|follow[- ]up).{0,100}(?:comment[- ]only|comment bod|summary bod)|(?:second|later|follow[- ]up).{0,100}(?:comment[- ]only|comment bod|summary bod).{0,30}(?:not|required nor valid|invalid|forbidden)|(?:comment[- ]only|comment bod|summary bod).{0,100}(?:not.{0,40}(?:later|follow[- ]up)|invalid)",
            "preparation grants no publication authority": r"(?:prepar|return|include).{0,180}(?:does.{0,8}not|doesn't|never|not).{0,80}(?:authorization|authorize|grant|permit).{0,80}(?:publish|github|mutation)",
        }
        prohibitions = common_prohibitions
    elif profile == "dispatch":
        requirements = {
            "conditional contract is default": r"(?=.*(?:first[- ]dispatch|first response))(?=.*(?:complete canonical|canonical packet))(?=.*(?:conditional review comments|review comments.{0,120}(?:only when|if).{0,100}(?:formal )?findings))",
            "findings carry comments in same response": r"(?=.*(?:formal )?findings?)(?=.*(?:review comments|comment bod))(?:(?=.*(?:same.{0,20}(?:response|turn|packet)|same-response))|(?=.*(?:deferred comment bod|comment-only output).{0,120}forbidden))",
            "clean review omits comments": r"(?:clean review|(?:zero|no) (?:formal )?findings?).{0,120}omit|omit.{0,120}(?:clean review|(?:zero|no) (?:formal )?findings?)|(?:review comments|comment section).{0,100}omit.{0,100}clean",
            "verdict-only is explicit": r"verdict[- ]only.{0,180}(?:explicit|triage)",
            "database sibling uses same contract": r"database (?:reviewer|sibling).{0,220}(?:same|matching).{0,140}(?:contract|conditional review comments)|both reviewers.{0,220}(?:same|conditional review comments)|both.{0,160}ordinary reviewer.{0,180}database reviewer.{0,180}(?:complete canonical|conditional review comments)",
            "preparation grants no publication authority": r"(?:prepar|return|include).{0,160}(?:does.{0,8}not|doesn't|never|not).{0,80}(?:authorization|authorize|grant|permit).{0,80}(?:publication|publish|github|mutation)|(?:prepar|return|include).{0,160}(?:comment|bod).{0,100}authorizes neither.{0,80}(?:publication|publish|github|mutation)",
            "parent owns one snapshot": r"parent.{0,100}(?:one|single).{0,100}(?:timestamped|head[- ]bound).{0,100}snapshot|parent.{0,100}(?:one|single).{0,100}snapshot.{0,220}(?:timestamp|head[- ](?:bound|pinned))",
            "reviewers reuse the snapshot": r"(?:both |two )?reviewers?.{0,140}(?:receive|reuse|share).{0,140}(?:same|identical|exact|one|single|parent-owned).{0,140}snapshot|(?:same|identical|exact|one|single|parent-owned).{0,100}snapshot.{0,100}(?:both |two )?reviewers?|parent.{0,100}(?:passes|supplies).{0,100}(?:same|identical|exact).{0,80}snapshot.{0,80}(?:both |two )?reviewers?",
            "remote refresh needs a named trigger": r"(?:fetch|refresh).{0,160}(?:only|unless).{0,160}(?:missing|absent|mismatch|invalid|packet completeness)",
            "parent defaults to bounded closeout": r"parent.{0,160}bounded.{0,120}(?:verdict|finding|state)",
            "exact packet only on explicit request": r"(?:exact\s+)?(?:canonical\s+)?packets?.{0,180}(?:only|unless|when).{0,120}(?:explicit|asks|request)|(?:does.{0,8}not|doesn't|never).{0,100}(?:paste|repeat|show).{0,100}(?:canonical\s+)?packets?(?:.{0,120}(?:unless|until).{0,100}(?:asks|request))?",
            "no model digest ceremony": r"no (?:model or )?reviewer (?:emits|produces|calculates).{0,160}(?:sha-?256|digest|base64|byte[- ]count)|no model[- ]emitted.{0,120}(?:sha-?256|digest|base64|byte[- ]count)|(?:reviewers?|model).{0,80}(?:do not|does not|must not|never|no).{0,50}(?:emit|produce|calculate).{0,160}(?:sha-?256|digest|base64|byte[- ]count)|(?:base64|byte[- ]counts?|sha-?256|digest).{0,120}(?:not reviewer[- ]emitted|not.{0,40}reviewer.{0,40}fields?)",
            "no second comment-only turn": r"(?:no|does not|must not|never).{0,100}(?:second|later|follow[- ]up).{0,100}(?:comment[- ]only|comment bod|summary bod)|(?:no|does not|must not|never).{0,100}(?:comment[- ]only|comment bod|summary bod).{0,100}(?:second|later|follow[- ]up)|comment[- ]only.{0,100}(?:forbidden|invalid|not permitted)|comment bod.{0,100}later.{0,100}(?:forbidden|invalid|not permitted)",
        }
        prohibitions = common_prohibitions
    elif profile == "publication":
        requirements = {
            "accepted bytes reused unchanged": r"(?=.*(?:already passed|already accepted|packet acceptance|acceptance.{0,30}already complete|accepted packet|accepted.{0,30}summary|accepted.{0,30}body))(?=.*(?:unchanged|unaltered|exact|not.{0,30}(?:alter|rewrite)))(?=.*summary)(?=.*body)",
            "pre-write checks are mutable only": r"(?:before|pre[- ]write|publication).{0,120}(?:only|mutable).{0,160}(?:head|anchor|thread|duplicate|authorization|capability)|remaining.{0,80}mutable[- ]state checks|(?:after|once|following).{0,40}(?:packet |mechanical )?acceptance.{0,120}(?:do not|not|without).{0,80}(?:revalidate|repeat|reconstruct).{0,180}before publication.{0,180}(?:head|anchor|thread|duplicate|authorization|capability)|(?:acceptance|mechanical acceptance).{0,80}(?:complete|already).{0,160}(?:do not|not).{0,80}(?:revalidate|repeat|reconstruct).{0,180}before publication.{0,180}(?:head|anchor|thread|duplicate|authorization|capability)",
            "publication preserves exact event and bodies": r"(?=.*preserv)(?=.*request_changes)(?=.*summary)(?=.*(?:inline )?body)(?=.*(?:exact|byte-for-byte|unchanged))",
            "alternate sanctioned primitive": r"(?:another|alternate).{0,120}(?:sanctioned|authenticated|github).{0,100}(?:primitive|surface)",
            "incompatible surfaces fail closed": r"(?:fail closed|pending verification|no (?:review )?mutation).{0,180}(?:no compatible|incompatible|cannot|none)|(?:no compatible|incompatible|cannot|none).{0,180}(?:fail closed|pending verification|no (?:review )?mutation)",
            "no event downgrade": r"(?:forbid|forbidden|never|must not|do.{0,8}not|not (?:permissible|allowed)|not.{0,8}to).{0,160}(?:downgrade|change|changing).{0,80}(?:request_changes|event|comment)|not.{0,240}downgraded.{0,40}(?:request_changes|event|comment)|(?:downgrade|downgraded|changing|change).{0,120}(?:request_changes|event|comment).{0,200}(?:forbid|forbidden)",
            "no model digest ceremony": r"(?:digest triples?|sha-?256|base64|byte[- ]counts?).{0,120}(?:must not|do not|never|not|forbid|forbidden|diagnostic)|(?:must not|do not|never|not|forbid|forbidden).{0,160}(?:invent|emit|calculate|produce)?.{0,80}(?:digest triples?|sha-?256|base64|byte[- ]counts?)",
        }
        prohibitions = common_prohibitions | {
            "same identity waives transport": r"same[- ]identity.{0,120}(?:skip|waive|bypass).{0,100}(?:transport|literal|parse)",
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
    dispatch = """
    Ordinary whole-target review defaults on the first dispatch to a canonical
    packet with conditional review comments. Formal findings carry their review
    comments in the same response; a clean review omits the review comments
    section. Verdict-only is reserved for an explicit verdict-only or triage
    request. The database sibling uses the same conditional review comments
    contract. Returning comment bodies does not authorize GitHub publication.
    The parent owns one timestamped head-bound snapshot. Both reviewers reuse
    the snapshot and may refresh only for a missing field, invalid provenance,
    head mismatch, or packet completeness. The parent normally shows a bounded
    verdict and findings, and forwards the exact canonical packet only when the
    user explicitly requests it. No model or reviewer emits SHA-256, base64, or
    byte-count fields and no second comment-only turn is requested.
    """
    publication = """
    Reviewer-to-parent cross-session transport uses pipe-prefixed literals.
    Already accepted Summary and Body bytes are reused unchanged. Immutable
    checks are not repeated; before publication check only mutable head,
    anchor, thread, duplicate, authorization, and capability.
    Preserve the exact REQUEST_CHANGES event plus summary and inline body bytes.
    Ordinary and database payloads use one review event. REQUEST_CHANGES takes
    precedence if either selected it. The fixed summary framing is Application
    review followed by Database review. Keep an exact anchor-and-body duplicate
    once. Try another repo-sanctioned authenticated GitHub primitive. If no
    compatible surface exists, fail closed with Pending Verification and no
    mutation. Never downgrade the
    event and never invent a summary. Returned comments do not authorize GitHub
    publication, and no model or reviewer emits SHA-256, base64, or byte counts.
    """
    reviewer = """
    The complete ordinary reviewer verdict packet remains mandatory. Formal
    findings include Review comments in the same response; a clean review
    omits the Review comments section, and verdict-only is limited to an
    explicit verdict-only or triage request. The minimal fields are Review
    event, Unanchored findings, Summary, then each Comment with Finding,
    Anchor JSON, and Body. Inline and unanchored ordinals are disjoint and
    their union is 1..N for every formal finding. P0/P1 selects
    REQUEST_CHANGES, while a P2/P3-only review selects COMMENT. The ordinary reviewer owns
    the exact body and summary wording. No model or reviewer emits SHA-256,
    base64, or byte-count fields, and there is no second comment-only turn.
    Returning comments does not authorize GitHub publication.
    """
    database = reviewer.replace("ordinary reviewer", "database reviewer")
    failures: list[str] = []
    if grade("dispatch", dispatch):
        failures.append("valid dispatch contract rejected")
    if grade("dispatch", dispatch.replace("first dispatch", "first response")):
        failures.append("valid first-response dispatch phrasing rejected")
    exact_snapshot = dispatch.replace(
        "Both reviewers reuse the snapshot",
        "The parent passes that exact snapshot to both reviewers",
    )
    if grade("dispatch", exact_snapshot):
        failures.append("valid exact-snapshot dispatch phrasing rejected")
    if grade("publication", publication):
        failures.append("valid publication contract rejected")
    publication_mutable = publication.replace(
        "Immutable checks are not repeated; before publication check only mutable head,",
        "After acceptance, remaining mutable-state checks cover head,"
    ).replace(
        "Never downgrade the event",
        "The parent must not revalidate accepted semantics. Never downgrade the event"
    )
    if grade("publication", publication_mutable):
        failures.append("valid remaining-mutable-check wording rejected")
    publication_after_acceptance = publication.replace(
        "Already accepted Summary and Body bytes are reused unchanged. Immutable\n"
        "    checks are not repeated; before publication check only mutable head,",
        "After packet acceptance, do not revalidate or reconstruct the Summary and\n"
        "    Body bytes. Before publication verify the live head,",
    )
    if grade("publication", publication_after_acceptance):
        failures.append("valid after-acceptance publication wording rejected")
    if grade("reviewer", reviewer):
        failures.append("valid reviewer contract rejected")
    if grade("database", database):
        failures.append("valid database contract rejected")
    if not grade("database", database.replace("database reviewer", "ordinary reviewer")):
        failures.append("wrong database reviewer context accepted")
    database_review_context = database.replace(
        "database reviewer verdict packet",
        "database-verdict packet",
    ).replace(
        "The database reviewer owns",
        "The reviewer owns",
    )
    if grade("database", database_review_context):
        failures.append("valid database-review context rejected")
    markdown_clean = reviewer.replace(
        "a clean review omits the Review comments section",
        "with zero formal findings, `Review comments:` would be omitted"
    )
    if grade("reviewer", markdown_clean):
        failures.append("valid markdown clean-review phrasing rejected")
    markdown_transport = reviewer.replace(
        "Formal findings include Review comments in the same response",
        "Formal findings and Review comments are returned in the same complete packet"
    ).replace(
        "No model or reviewer emits SHA-256, base64, or byte-count fields",
        "It does **not** emit SHA-256, base64, or byte-count fields"
    )
    if grade("reviewer", markdown_transport):
        failures.append("valid markdown transport phrasing rejected")
    later_turn_reversed = reviewer.replace(
        "there is no second comment-only turn",
        "a comment-only response is not a required later turn and is invalid",
    )
    if grade("reviewer", later_turn_reversed):
        failures.append("valid reversed later-turn prohibition rejected")
    if not grade("dispatch", dispatch.replace("does not authorize", "authorizes")):
        failures.append("publication-authority violation accepted")
    authorize_neither = dispatch.replace(
        "Returning comment bodies does not authorize GitHub publication",
        "Returning comment bodies authorizes neither publication nor GitHub mutation"
    )
    if grade("dispatch", authorize_neither):
        failures.append("valid negative publication-authority wording rejected")
    never_authorizes = database.replace(
        "Returning comments does not authorize GitHub publication",
        "Returning comments never authorizes GitHub publication"
    )
    if grade("database", never_authorizes):
        failures.append("valid never-authorizes wording rejected")
    if not grade("dispatch", dispatch.replace("same response", "later comment-only response")):
        failures.append("second-turn comment contract accepted")
    if not grade("dispatch", dispatch.replace("No model or reviewer emits SHA-256", "The reviewer must emit SHA-256")):
        failures.append("model digest ceremony accepted")
    if not grade("publication", re.sub(r"\bNever downgrade", "Downgrade", publication)):
        failures.append("event downgrade accepted")
    not_permissible = publication.replace("Never downgrade", "It is not permissible to downgrade")
    if grade("publication", not_permissible):
        failures.append("valid not-permissible event wording rejected")
    if not grade(
        "reviewer",
        reviewer.replace("there is no second comment-only turn", "a second comment-only turn follows")
    ):
        failures.append("reviewer second-turn contract accepted")
    if not grade("database", database.replace("No model or reviewer emits SHA-256", "The reviewer must emit SHA-256")):
        failures.append("database digest ceremony accepted")
    return failures


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        failures = self_test()
    elif len(sys.argv) == 2:
        failures = grade(sys.argv[1], sys.stdin.read())
    else:
        print("usage: review_dispatch_economy_contract.py <reviewer|database|dispatch|publication> | --self-test")
        return 2
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("review dispatch economy contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
