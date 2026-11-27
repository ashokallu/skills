#!/usr/bin/env python3
"""Section-aware deterministic grader for database-reviewer behavior evals."""

from __future__ import annotations

import re
import sys


END_FIELDS = (
    "findings", "verified clean", "rejected candidates", "rejected material candidates",
    "pending verification", "central missing proof", "required before", "not reviewed",
    "author validation", "coverage map", "non-waivable hard stops", "phase and rollback",
    "plain-language summary", "selected lanes", "not selected", "next owner",
    "findings count", "strongest proof", "decision scope and readiness boundary",
    "decision outcome", "blocked decision", "review comments", "publication candidates",
)


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value.lower()).strip()


def field(text: str, name: str) -> str:
    """Extract one Markdown packet field without consuming later top-level fields."""
    pattern = re.compile(
        rf"(?ims)^(?:#+\s*)?(?:[-*]\s*)?(?:\*\*)?{re.escape(name)}\s*(?::\s*\*\*|\*\*\s*:|:)\s*(.*?)"
        rf"(?=^(?:#+\s*)?(?:[-*]\s*)?(?:\*\*)?(?:{'|'.join(re.escape(x) for x in END_FIELDS)}|"
        r"target|review mode|verdict|confidence|selected lanes|risk acceptance|evidence limitations|verdict invalidation)"
        r"\s*(?::\s*\*\*|\*\*\s*:|:)|\Z)"
    )
    match = pattern.search(text)
    return compact(match.group(1)) if match else ""


def raw_field(text: str, name: str) -> str:
    """Extract a packet field while preserving row and bullet boundaries."""
    pattern = re.compile(
        rf"(?ims)^(?:#+\s*)?(?:[-*]\s*)?(?:\*\*)?{re.escape(name)}\s*(?::\s*\*\*|\*\*\s*:|:)\s*(.*?)"
        rf"(?=^(?:#+\s*)?(?:[-*]\s*)?(?:\*\*)?(?:{'|'.join(re.escape(x) for x in END_FIELDS)}|"
        r"target|review mode|verdict|confidence|risk acceptance|evidence limitations|verdict invalidation)"
        r"\s*(?::\s*\*\*|\*\*\s*:|:)|\Z)"
    )
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def selected_lanes(text: str) -> str:
    lanes_raw = raw_field(text, "selected lanes") or raw_field(text, "selected lanes and exact triggers")
    if re.search(r"^(did not|not selected|excluded|none selected)\b", compact(lanes_raw)):
        return ""
    rows = [line.strip() for line in lanes_raw.splitlines() if line.strip().startswith("-")]
    lanes = compact(" ".join(row.split("|", 1)[0] for row in rows))
    return lanes


def finding_blocks(text: str) -> list[str]:
    return [
        match.group(0).strip()
        for match in re.finditer(
            r"(?ims)^Finding P[0-3]:.*?(?=^Finding P[0-3]:|^Review comments:|^Publication candidates:|^Plain-language summary:|^Selected lanes:|^Verified clean:|^Rejected candidates:|^Author validation and scope:|^Not reviewed:|\Z)",
            text,
        )
    ]


def block_field(block: str, name: str) -> str:
    return compact(raw_block_field(block, name))


def raw_block_field(block: str, name: str) -> str:
    match = re.search(
        rf"(?ims)^- {re.escape(name)}:\s*(.*?)(?=^- (?:Severity|Confidence|Category|Location|Problem|Impact|Evidence|Fix shape):|\Z)",
        block,
    )
    return match.group(1).strip() if match else ""


def obsolete_publication_candidate_failures(output: str) -> list[str]:
    if re.search(r"(?m)^Publication candidates:$", output):
        return ["obsolete publication candidate section"]
    return []


def packet_contract_failures(output: str) -> list[str]:
    failures: list[str] = []
    lanes_raw = raw_field(output, "selected lanes")
    lane_rows = [line.strip() for line in lanes_raw.splitlines() if line.strip().startswith("-")]
    if not lane_rows:
        failures.append("selected-lane audit rows")
    for row in lane_rows:
        parts = [part.strip() for part in row.split("|")]
        if len(parts) != 4 or not parts[0].lstrip("- ").strip():
            failures.append("lane row shape")
            continue
        required = ("trigger:", "surface:", "disposition:")
        if any(not parts[index].lower().startswith(prefix) or not parts[index][len(prefix):].strip()
               for index, prefix in enumerate(required, start=1)):
            failures.append("lane row trigger/surface/disposition")
            continue
        disposition = re.sub(r"[`*_]", "", parts[3].split(":", 1)[1]).strip()
        if not re.search(r"^(finding\s+p[0-3]|verified clean\b|pending verification\b|not applicable\b)", disposition, re.I):
            failures.append("truthful lane disposition")

    skipped_raw = raw_field(output, "not selected")
    skipped_rows = [line.strip() for line in skipped_raw.splitlines() if line.strip().startswith("-")]
    if len(skipped_rows) > 3:
        failures.append("skipped lane budget")
    for row in skipped_rows:
        if "reason:" not in row.lower() or not row.lower().split("reason:", 1)[1].strip():
            failures.append("skipped lane reason")

    if not field(output, "plain-language summary"):
        failures.append("plain-language summary")
    decision_scope = field(output, "decision scope and readiness boundary")
    decision_outcome = field(output, "decision outcome")
    blocked_decision = re.sub(r"[`*_]", "", field(output, "blocked decision")).strip()
    if not decision_scope:
        failures.append("decision scope and readiness boundary")
    if decision_outcome not in {"supported", "rejected", "unproven", "not applicable"}:
        failures.append("decision outcome")
    if not blocked_decision:
        failures.append("blocked decision")
    next_owner = re.sub(r"[`*_]", "", field(output, "next owner")).strip()
    if not next_owner or "," in next_owner or re.search(r"\band\b", next_owner):
        failures.append("exactly one next owner")

    blocks = finding_blocks(output)
    for block in blocks:
        for name in ("Severity", "Confidence", "Category", "Location", "Problem", "Impact", "Evidence", "Fix shape"):
            if not block_field(block, name):
                failures.append(f"finding {name}")
        evidence = raw_block_field(block, "Evidence")
        bullet_count = len(re.findall(r"(?m)^\s*-\s+", evidence))
        if bullet_count < 1 or bullet_count > 3:
            failures.append("finding evidence bullet bound")
        fix_shape = block_field(block, "Fix shape")
        if fix_shape:
            if len(fix_shape) < 45 or re.fullmatch(r"(?:fix|address|resolve|update|make)\b.{0,35}", fix_shape, re.I):
                failures.append("specific Fix shape")
            if not re.search(r"(test|verify|assert|validation|check|probe|proof|plan|explain|metric|rehears)", fix_shape, re.I):
                failures.append("post-fix proof")

    verdict = top_verdict(output)
    if verdict == "blocked" and blocked_decision in {"", "none"}:
        failures.append("BLOCKED exact decision")
    if verdict == "pass" and blocked_decision not in {"", "none"}:
        failures.append("PASS blocked decision")
    pending = field(output, "pending verification")
    central = field(output, "central missing proof")
    has_open_decision = (
        field(output, "decision outcome") == "unproven"
        or pending not in {"", "none", "n/a", "not applicable"}
        or central not in {"", "none", "n/a", "not applicable"}
    )
    if verdict == "pass" and not blocks and not has_open_decision and next_owner and next_owner != "none":
        failures.append("clean PASS next owner")
    if verdict == "blocked" and next_owner == "none":
        failures.append("BLOCKED next owner")
    if blocks and next_owner == "none":
        failures.append("finding next owner")
    return list(dict.fromkeys(failures))


def top_verdict(text: str) -> str:
    patterns = (
        r"(?im)^\s*[-*]?\s*(?:\*\*)?top-level verdict(?: and authorization boundary)?\s*(?::\s*\*\*|\*\*\s*:|:)\s*(?:\n\s*[-*]\s*)?`?\*{0,2}(pass|blocked|needs_input)",
        r"(?im)^\s*[-*]?\s*(?:\*\*)?verdict\s*(?::\s*\*\*|\*\*\s*:|:)\s*(?:\n\s*[-*]\s*)?`?\*{0,2}(pass|blocked|needs_input)",
    )
    verdicts = []
    for pattern in patterns:
        verdicts.extend(match.lower() for match in re.findall(pattern, text))
    unique = set(verdicts)
    return unique.pop() if len(unique) == 1 else ""


def evidence_sections(text: str) -> str:
    names = (
        "findings", "pending verification", "central missing proof",
        "required before merge", "required before deploy/execute", "verified clean",
    )
    supporting = tuple(
        re.sub(r"[`*]", "", value)
        for value in (
            field(text, "plain-language summary"),
            field(text, "selected lanes"),
            field(text, "next owner"),
            field(text, "author validation and scope"),
            field(text, "decision scope and readiness boundary"),
            field(text, "decision outcome"),
            field(text, "blocked decision"),
        )
    )
    return " ".join(finding_blocks(text) + [field(text, name) for name in names] + list(supporting))


def matches(value: str, pattern: str) -> bool:
    return bool(re.search(pattern, value, re.I | re.S))


def groups(*items: tuple[str, str, str]) -> list[tuple[str, str, str]]:
    return list(items)


PROFILES = {
    "backfill": groups(
        ("lane", "accounting lane", r"data-transition-and-accounting"),
        ("lane", "capacity lane", r"(physical-design-and-capacity|capacity-maintenance-and-storage)"),
        ("evidence", "audit trigger", r"trigger.{0,120}audit|audit.{0,120}trigger"),
        ("evidence", "generated value", r"generated.{0,80}(value|column)"),
        ("evidence", "foreign-key cascade", r"foreign.key|cascade"),
        ("evidence", "WAL amplification", r"wal"),
        ("evidence", "lock amplification", r"lock"),
        ("evidence", "fixture rejected as scale proof", r"100.row.{0,180}(not|cannot|insufficient|unrepresentative)"),
        ("evidence", "identity exhaustion", r"(identity|sequence).{0,140}(ceiling|exhaust|headroom)"),
        ("evidence", "maximum and ceiling", r"(maximum|max).{0,100}ceiling|ceiling.{0,100}(maximum|max)"),
        ("evidence", "growth and exhaustion horizon", r"growth.{0,120}(horizon|exhaust)|exhaust.{0,120}(growth|horizon)"),
        ("evidence", "production-scale evidence", r"(production|representative).{0,80}(scale|rehears|evidence)"),
    ),
    "backup-restore": groups(
        ("lane", "backup lane", r"backup-restore-and-disaster-recovery"),
        ("lane", "recovery/topology/security/sharding companion", r"(failure-recovery|configuration-and-topology|security-tenancy|sharding-partitioning)"),
        ("evidence", "PITR not restore proof", r"pitr.{0,160}(not|does not|insufficient).{0,100}(proof|exercise|restore)"),
        ("evidence", "key recovery", r"(key|encryption).{0,100}recover"),
        ("evidence", "failback fencing", r"failback.{0,100}fenc"),
        ("evidence", "total RTO", r"rto.{0,160}(integrity|traffic)"),
        ("evidence", "cross-shard consistency", r"(cross.shard|all shard|multi.shard).{0,120}(consisten|restore|recover)"),
        ("evidence", "deletion resurrection", r"(deleted|deletion).{0,120}(reappear|resurrect|restore)"),
        ("evidence", "bounded read-only evidence", r"bounded.{0,80}read.only"),
        ("evidence", "mutation/unsafe scan prohibited", r"(prohibit|must not|without).{0,100}(mutat|unsafe scan)|unsafe scan.{0,80}(prohibit|must not)"),
        ("evidence", "target-scoped recovery evidence", r"(scope|scoped).{0,120}(target|shard|observed)"),
    ),
    "configuration-topology": groups(
        ("lane", "configuration lane", r"configuration-and-topology"),
        ("lane", "recovery lane", r"failure-recovery-and-rollback"),
        ("evidence", "declared versus effective", r"(declared|source).{0,120}effective|effective.{0,120}(declared|source)"),
        ("evidence", "restart and mixed version", r"restart.{0,140}mixed.version|mixed.version.{0,140}restart"),
        ("evidence", "replica freshness", r"replica.{0,120}(fresh|lag|bound)"),
        ("evidence", "failover", r"failover"),
        ("evidence", "aggregate pool risk", r"(aggregate|fleet|total).{0,100}(pool|connection)|pool.{0,100}(aggregate|fleet|total)"),
        ("evidence", "PITR not restore proof", r"pitr.{0,160}(not|does not|insufficient).{0,100}(proof|exercise|restore)"),
        ("evidence", "engine/version and effective-value scope", r"(engine|version).{0,160}(effective|restart)|effective.{0,160}(engine|version)"),
        ("evidence", "routing/lag bound", r"(routing|replica).{0,120}(lag|freshness).{0,120}bound|bound.{0,120}(lag|freshness)"),
        ("evidence", "restore exercise detail", r"restore.{0,120}(exercise|drill).{0,200}(duration|integrity|loss|recovery point)"),
    ),
    "destructive-accounting": groups(
        ("lane", "accounting lane", r"data-transition-and-accounting"),
        ("lane", "rollback lane", r"failure-recovery-and-rollback"),
        ("evidence", "destructive business deletion", r"delet.{0,160}(business|live|valid).{0,120}(row|data)"),
        ("evidence", "writer provenance", r"(writer|provenance).{0,180}migration_run_id|migration_run_id.{0,180}(writer|provenance)"),
        ("evidence", "committed effects versus failed accounting", r"commit.{0,200}(count|account)|count.{0,200}commit"),
        ("evidence", "dry-run/apply ambiguity", r"dry.run.{0,180}apply|apply.{0,180}dry.run"),
        ("evidence", "non-resumable identity", r"non.resum|cannot.{0,60}resume|partial run"),
        ("evidence", "writer inventory evidence", r"(complete|exact).{0,100}writer.{0,80}inventor|writer.{0,100}inventor"),
        ("evidence", "count ownership evidence", r"(owner|ownership|authoritative).{0,120}(count|account|inserted_count)|(count|account).{0,120}(owner|ownership|authoritative)"),
        ("evidence", "failure rehearsal", r"(failure|fail).{0,100}(rehears|simulat|inject|test)"),
        ("evidence", "operator recovery evidence", r"(operator|runbook|walkthrough).{0,120}(recover|partial|resume)"),
    ),
    "query-only": groups(
        ("lane", "SQL lane", r"sql-query-and-generated-contracts"),
        ("lane", "physical lane", r"physical-design-and-capacity"),
        ("evidence", "LEFT JOIN semantics", r"left join.{0,200}(where|zero|remove|exclude|inner)"),
        ("evidence", "nullable SUM", r"(sum|coalesce).{0,140}(null|zero)|null.{0,140}(sum|coalesce)"),
        ("evidence", "unique ordering", r"(tie.break|unique.{0,50}order|order.{0,100}id|cursor)"),
        ("evidence", "tenant/status access paths", r"(index|access path).{0,200}(status|tenant)|(status|tenant).{0,200}(index|access path)"),
        ("evidence", "skew/cardinality", r"(skew|cardinal)"),
        ("evidence", "fixture EXPLAIN limited", r"explain.{0,200}(estimate|fixture|not|insufficient)"),
        ("evidence", "representative actual runtime proof", r"(actual|runtime|buffer|timing).{0,160}(plan|evidence|representative)|representative.{0,160}(actual|runtime|plan)"),
    ),
    "pre-mutation-performance": groups(
        ("lane", "SQL lane", r"sql-query-and-generated-contracts"),
        ("lane", "capacity lane", r"physical-design-and-capacity"),
        ("lane", "transition lane", r"data-transition-and-accounting"),
        ("lane", "rehearsal lane", r"verification-testing-and-rehearsal"),
        ("evidence", "pre-mutation performance is correctness", r"pre.mutation.{0,160}(performance|runtime|plan).{0,120}(correct|block|required)"),
        ("evidence", "canonical read-only probe", r"canonical.{0,120}read.only|read.only.{0,120}canonical"),
        ("evidence", "read-only and persistence equivalence", r"read.only.{0,160}(persist|dml).{0,160}(equival|same|shared)|equival.{0,160}read.only.{0,160}(persist|dml)"),
        ("evidence", "persistence idempotency", r"persist.{0,160}idempot|idempot.{0,160}persist"),
        ("evidence", "CTE materialization", r"cte.{0,160}(materialized|materialization)|not materialized|materialized cte"),
        ("evidence", "generic and custom plan behavior", r"generic.{0,120}custom.{0,120}plan|custom.{0,120}generic.{0,120}plan|plan.cache"),
        ("evidence", "largest environment", r"largest.{0,120}(environment|data shape|relation)|production.{0,120}(largest|representative)"),
        ("evidence", "phase cost model", r"phase.{0,100}cost|cost model"),
        ("evidence", "unchunked gate", r"unchunked.{0,120}(gate|statement|preflight)|chunked.{0,120}(does not|cannot).{0,100}unchunked"),
        ("evidence", "timeout is not performance proof", r"timeout.{0,160}(not|does not|cannot).{0,120}(performance|capacity|proof|fix)"),
        ("evidence", "block before full mutation", r"block.{0,160}(full|mutating|mutation).{0,160}(run|job)|full.{0,160}(run|job).{0,160}block"),
        ("evidence", "Production operation named", r"production.{0,120}(?:operation|run)"),
    ),
    "performance-advisory-uncertainty": groups(
        ("lane", "capacity lane", r"physical-design-and-capacity"),
        ("evidence", "advisory decision scope", r"performance.assessment|advisory"),
        ("evidence", "claim unproven", r"(?:claim|performance).{0,120}unproven|decision outcome.{0,80}unproven"),
        ("evidence", "comparable measurement gap", r"(?:baseline|comparable|measurement).{0,160}(?:missing|required|pending verification)"),
        ("evidence", "no merge or Production approval", r"(?:not|does not|cannot).{0,120}(?:merge|production).{0,80}(?:approval|ready|readiness)|blocked decision.{0,40}none"),
    ),
    "performance-confirmed-regression": groups(
        ("lane", "capacity lane", r"physical-design-and-capacity"),
        ("evidence", "comparable baseline and after", r"baseline.{0,160}(?:after|candidate)|(?:after|candidate).{0,160}baseline"),
        ("evidence", "confirmed regression", r"(?:confirmed|measured|demonstrated).{0,120}regression|regression.{0,120}(?:confirmed|measured|demonstrated)"),
        ("evidence", "advisory decision rejected", r"(?:advisory|performance).{0,180}rejected|\brejected\b"),
    ),
    "performance-merge-critical": groups(
        ("lane", "capacity lane", r"physical-design-and-capacity"),
        ("evidence", "merge decision scope", r"merge.{0,80}(?:readiness|acceptance|blocked)|blocked decision.{0,80}merge"),
        ("evidence", "acceptance-critical performance", r"performance.{0,120}(?:acceptance|criterion|critical)|(?:acceptance|criterion).{0,120}performance"),
        ("evidence", "missing comparison remains proof gap", r"(?:baseline|comparable|measurement).{0,160}(?:missing|required|pending verification)"),
    ),
    "evidence-candidate-calibration": groups(
        ("lane", "candidate evidence lane", r"evidence-candidates"),
        ("lane", "capacity lane", r"physical-design-and-capacity"),
        ("evidence", "agent attested provenance", r"agent.attested.non.replayable"),
        ("evidence", "direct relevance separated", r"direct.{0,140}(?:relevance|claim)|relevance.{0,140}direct"),
        ("evidence", "historical runtime calibration", r"45\.7|38\.093|44\.135"),
        ("evidence", "unsupported impact stays unproven", r"(?:saturat|timeout|exhaust).{0,220}(?:unproven|pending verification|not proved|unsupported)"),
        ("evidence", "current-state limitation", r"current.{0,120}(?:load|exist).{0,160}(?:unknown|unavailable|pending verification)"),
        (
            "evidence",
            "primary evidence limitation",
            r"(?:not|cannot).{0,140}(?:(?:primary|independently).{0,120}(?:evidence|verified|replay)|replayable.{0,100}(?:proof|evidence))",
        ),
    ),
    "live-ddl": groups(
        ("lane", "execution lane", r"execution-and-sequencing"),
        ("lane", "schema lane", r"schema-and-compatibility"),
        ("lane", "physical lane", r"physical-design-and-capacity"),
        ("lane", "live DDL lane", r"live-ddl-and-online-schema-change"),
        ("evidence", "lock queue amplification", r"lock.{0,100}(queue|amplif)|queue.{0,100}lock"),
        ("evidence", "bounded timeout and cancellation", r"(?=.*timeout)(?=.*cancel)"),
        ("evidence", "runner transaction compatibility", r"runner.{0,160}transaction|transaction.{0,160}runner"),
        ("evidence", "fallback classification", r"fallback|algorithm"),
        ("evidence", "partial residue and cleanup", r"(?=.*(?:partial|invalid|residue))(?=.*cleanup)"),
        ("evidence", "final catalog state", r"(?:final|catalog).{0,100}(?:catalog|state)"),
    ),
    "verification": groups(
        ("lane", "domain lane", r"(data-transition-and-accounting|transactions-and-concurrency|failure-recovery-and-rollback)"),
        ("lane", "verification lane", r"verification-testing-and-rehearsal"),
        ("evidence", "source versus execution distinction", r"source.{0,120}(execution|test)|(?:execution|test).{0,120}source"),
        ("evidence", "production-shaped limitation", r"production.shaped|representative"),
        ("evidence", "independent reconciliation", r"independent.{0,100}reconcil"),
        ("evidence", "fault injection", r"fault.inject|failure.inject"),
        ("evidence", "concurrent writer", r"concurrent.writer"),
        ("evidence", "partial or ambiguous commit", r"(?:partial|ambiguous).{0,80}commit"),
        ("evidence", "harness parity", r"harness.{0,100}(parity|match|differ)"),
        ("evidence", "failed-run residue", r"failed.run.{0,100}(residue|evidence)|residue.{0,100}failed"),
    ),
    "domain-tests": groups(
        ("lane", "transactions lane", r"transactions-and-concurrency"),
        ("verified", "ordinary domain-test assessment", r"(?:routine|ordinary|unit).{0,120}(?:test|evidence)|(?:test|evidence).{0,120}(?:routine|ordinary|unit)"),
    ),
    "environment-context": groups(
        ("lane", "environment context lane", r"environment-and-data-shape-context"),
        ("lane", "physical lane", r"physical-design-and-capacity"),
        ("lane", "live DDL lane", r"live-ddl-and-online-schema-change"),
        ("evidence", "declared versus observed state", r"terraform.{0,140}(declared|configured).{0,140}(observed|effective)|(?:observed|effective).{0,140}terraform"),
        ("evidence", "event invalidation", r"(?:migration|deploy).{0,140}invalid|invalid.{0,140}(?:migration|deploy)"),
        ("evidence", "time expiry", r"expir|valid.until|maximum validity"),
        ("evidence", "exact bytes versus estimated rows", r"exact.{0,120}byte.{0,160}estimat.{0,80}row|estimat.{0,80}row.{0,160}exact.{0,120}byte"),
        ("evidence", "omitted relation refresh", r"omitt.{0,140}(?:targeted|bounded).{0,80}refresh|(?:targeted|bounded).{0,80}refresh.{0,140}omitt"),
        ("evidence", "parent-owned refresh", r"parent.{0,140}(?:preflight|refresh)|(?:preflight|refresh).{0,140}parent"),
        ("evidence", "static reviewer does not refresh", r"(?:static reviewer|reviewer).{0,140}(?:never|does not|cannot|must not).{0,100}(?:refresh|execute|run)|(?:never|does not|cannot|must not).{0,100}(?:refresh|execute|run).{0,140}reviewer"),
        ("evidence", "small is not safety proof", r"small.{0,120}(?:not|does not|cannot|insufficient).{0,100}(?:safe|safety|proof)"),
        ("evidence", "missing current evidence", r"current.{0,100}(?:missing|required)|missing.{0,100}current"),
    ),
    "environment-context-unknown-invalidation": groups(
        ("lane", "environment context lane", r"environment-and-data-shape-context"),
        ("evidence", "time validity is insufficient", r"(?:seven.day|time.valid|valid.until|unexpired).{0,180}(?:not|insufficient|does not|unknown|unusable|blocked).{0,100}(?:fresh|current|proof|invalidat)|cannot.{0,180}seven.day"),
        ("evidence", "unknown invalidation state", r"invalidat.{0,120}(?:unknown|unavailable|not checked)|(?:unknown|unavailable).{0,120}invalidat"),
        ("evidence", "current target comparison", r"current.{0,100}(?:target|deploy|migration|instance|workload)"),
        ("evidence", "parent-owned invalidation preflight", r"parent.{0,140}(?:preflight|invalidat|evidence preparer)|(?:preflight|invalidat).{0,140}parent"),
        ("evidence", "static reviewer does not refresh", r"(?:static reviewer|reviewer|review).{0,140}(?:never|does not|did not|cannot|must not).{0,100}(?:refresh|execute|run)|(?:never|does not|did not|cannot|must not).{0,100}(?:refresh|execute|run).{0,140}(?:reviewer|review)|no refresh.{0,100}(?:performed|run|executed)"),
        ("evidence", "missing current evidence", r"pending verification|current.{0,100}(?:missing|required)"),
    ),
    "environment-context-unrelated-migration": groups(
        ("lane", "environment context lane", r"environment-and-data-shape-context"),
        ("evidence", "claim-level invalidation", r"claim.level|dependent field|field.specific"),
        ("evidence", "unrelated migration does not invalidate", r"unrelated.{0,160}(?:does not|cannot|not).{0,100}invalid"),
        ("evidence", "bounded invalidator coverage", r"bounded.{0,120}(?:event|invalidat).{0,120}(?:coverage|inventory)|observation.to.decision"),
        ("verified", "snapshot claim remains usable", r"content_user_progress.{0,160}(?:usable|current|accepted)|(?:usable|current|accepted).{0,160}content_user_progress"),
    ),
    "migration-version-collision": groups(
        ("lane", "execution lane", r"execution-and-sequencing"),
        ("evidence", "same version differing content", r"same.version.{0,120}(?:different|differing).{0,80}content|000057.{0,160}(?:collision|differ)"),
        ("evidence", "source-proven integration defect", r"source.proven.{0,160}(?:integration|collision)|(?:integration|collision).{0,160}source.proven"),
        ("evidence", "runtime impact not invented", r"(?:runtime|saturat|lock).{0,160}(?:not proved|not claimed|unproven|not required)"),
    ),
    "safe-additive": groups(
        ("lane", "execution lane", r"execution-and-sequencing"),
        ("lane", "schema lane", r"schema-and-compatibility"),
        ("lane", "physical lane", r"physical-design-and-capacity"),
        ("lane", "live DDL lane", r"live-ddl-and-online-schema-change"),
        ("lane", "recovery lane", r"failure-recovery-and-rollback"),
        ("verified", "metadata-only/additive clean proof", r"metadata.only|additive"),
        ("verified", "rollback clean proof", r"(rollback|down).{0,160}(clean|safe|unused|bounded)"),
    ),
    "transactions": groups(
        ("lane", "transactions lane", r"transactions-and-concurrency"),
        ("evidence", "lost update", r"lost.update"),
        ("evidence", "lock-order deadlock", r"(lock.order|opposite order).{0,140}deadlock|deadlock.{0,140}(lock.order|opposite order)"),
        ("evidence", "ambiguous commit retry", r"(lost|ambiguous).{0,100}commit.{0,140}(retry|idempot)"),
        ("evidence", "external I/O under lock", r"(remote|external).{0,140}(lock|transaction)"),
        ("evidence", "repeated external side effect", r"(duplicate|repeated|double).{0,120}(notification|side effect|external)"),
        ("evidence", "pooling/advisory mismatch", r"(transaction.pool|pooled).{0,180}(advisory|session)"),
        ("evidence", "fleet capacity", r"(1200|1,200).{0,120}500|500.{0,120}(1200|1,200)"),
        ("evidence", "isolation and statement evidence", r"(?=.*isolation)(?=.*(statement|sql))"),
        ("evidence", "timeout and contention evidence", r"(?=.*timeout)(?=.*contention)"),
        ("evidence", "concurrent-writer evidence", r"concurrent.writer"),
        ("evidence", "retry/idempotency evidence", r"retry.{0,120}idempot|idempot.{0,120}retry"),
    ),
    "validation-truth": groups(
        ("lane", "data-transition lane", r"data-transition-and-accounting"),
        ("lane", "SQL or concurrency lane", r"sql-query-and-generated-contracts|transactions-and-concurrency"),
        ("evidence", "false-clean validation", r"(false.clean|false pass|hide|exclude).{0,180}(validat|parity)"),
        ("evidence", "NULL cases", r"null"),
        ("evidence", "newer target visible", r"(newer.target|target.{0,20}newer).{0,200}(visible|difference|report|surface)"),
        ("evidence", "preflight advisory", r"preflight.{0,140}(advisory|not authoritative|stale|race)"),
        ("evidence", "authoritative stabilized selection", r"(authoritative|transaction|lock|immutable|versioned).{0,200}(selection|candidate|bound|stabili)"),
        ("evidence", "counts may differ under concurrency", r"count.{0,180}(differ|change|stale).{0,120}concurr|concurr.{0,180}count"),
        ("evidence", "affected rows not an operational bound", r"affected.row.{0,200}(not|does not|insufficient).{0,120}(bound|limit|safety)|not operationally bounded"),
    ),
}


def grade(profile: str, output: str) -> list[str]:
    lanes = selected_lanes(output)
    blocks = finding_blocks(output)
    findings = " ".join(blocks) if blocks else field(output, "findings")
    verified = field(output, "verified clean")
    evidence = evidence_sections(output)
    verdict = top_verdict(output)
    failures: list[str] = []

    if "database review" not in output.lower():
        failures.append("database review packet")
    if not verdict:
        failures.append("one coherent top-level verdict")
    pass_profiles = {
        "safe-additive", "domain-tests", "performance-advisory-uncertainty",
        "performance-confirmed-regression", "evidence-candidate-calibration",
        "environment-context-unrelated-migration",
    }
    expected = "pass" if profile in pass_profiles else "blocked"
    if verdict and verdict != expected:
        failures.append(f"{expected} verdict")
    if not re.search(r"(?im)^\s*[-*]?\s*(?:\*\*)?confidence", output):
        failures.append("confidence")
    if not re.search(r"(pending verification|source-proven|runtime-proven|evidence limitations)", output, re.I):
        failures.append("evidence-class honesty")
    ownership_text = re.sub(
        r"(?:\b(?:do|does|will|must|should|can)\s+(?:not|never)\s+|\bwithout\s+)"
        r"(?:defer(?:ring)?|delegat(?:e|ing)|ask(?:ing)?|invok(?:e|ing)).{0,80}reviewer",
        "",
        output,
        flags=re.I | re.S,
    )
    if re.search(
        r"(defer(?:ring)?|delegat(?:e|ing)|ask(?:ing)?|invok(?:e|ing)).{0,80}"
        r"(another|other).{0,40}reviewer",
        ownership_text,
        re.I | re.S,
    ):
        failures.append("independent verdict ownership")

    failures.extend(packet_contract_failures(output))
    failures.extend(obsolete_publication_candidate_failures(output))

    scopes = {"lane": lanes, "evidence": evidence, "verified": verified}
    for scope, name, pattern in PROFILES[profile]:
        if not matches(scopes[scope], pattern):
            failures.append(name)

    if profile in {"safe-additive", "domain-tests"}:
        if findings and not re.search(r"^(none|\[\]|no material findings)", findings):
            failures.append("safe case findings must be empty")
        if re.search(r"\bfinding\s*[:#-]?\s*\[?p[012]\]?\b|\bseverity\s*[:#-]?\s*\[?p[012]\]?\b", findings, re.I):
            failures.append("safe case invented a blocking finding")
        unrelated = r"(data-transition|sharding|replication|security-tenancy|backup-restore|verification-testing-and-rehearsal|environment-and-data-shape-context)"
        if profile == "safe-additive":
            unrelated += r"|transactions-and-concurrency"
        if re.search(unrelated, lanes):
            failures.append("safe case selected unrelated lanes")
        invented = r"(large table|backfill|wal|replication|privacy|operator blocker|index blocker)"
        if re.search(invented, findings):
            failures.append("safe case invented an unrelated blocker")

    if profile == "destructive-accounting" and not finding_blocks(output):
        failures.append("confirmed defect requires actionable finding")
    if profile == "environment-context-unknown-invalidation" and finding_blocks(output):
        failures.append("central missing proof must not fabricate a finding")
    if profile in {"evidence-candidate-calibration", "environment-context-unrelated-migration"} and finding_blocks(output):
        failures.append("historical or unaffected evidence must not fabricate a finding")
    if profile in {"performance-advisory-uncertainty", "performance-merge-critical"} and finding_blocks(output):
        failures.append("performance evidence gap must not fabricate a finding")
    if profile == "performance-confirmed-regression":
        if not finding_blocks(output):
            failures.append("confirmed regression requires actionable finding")
        elif not any(block_field(block, "Severity") == "p2" for block in finding_blocks(output)):
            failures.append("bounded confirmed regression should be P2")
    if profile == "migration-version-collision":
        if not finding_blocks(output):
            failures.append("confirmed migration collision requires actionable finding")
        elif not any(block_field(block, "Severity") == "p1" for block in finding_blocks(output)):
            failures.append("source-only migration collision should be P1")

    return list(dict.fromkeys(failures))


def self_test() -> list[str]:
    actionable = """Database review:
- target and base: v2 against v1
- review mode: implementation
- decision scope and readiness boundary: merge safety for the implementation target
- decision outcome: rejected
- blocked decision: merge/deployment
- verdict: BLOCKED
- confidence: high
- next owner: parent
Findings:
Finding P1: partial commit accounting
- Severity: P1
- Confidence: high
- Category: data integrity
- Location: migration/runner.go:42
- Problem: The runner records zero after a later count fails even though an earlier batch committed.
- Impact: Operators can undercount durable writes and choose an unsafe recovery scope.
- Evidence:
  - runner.go:42 overwrites the committed count on the error path.
  - query.sql:18 proves committed rows remain tagged by run ID.
- Fix shape: Change the terminal-run accounting path to preserve committed batch totals after a later failure, then add a focused failure-path test that asserts the persisted count equals tagged rows.
Plain-language summary:
The author must correct failed-run accounting before this target can proceed.
Selected lanes:
- references/data-transition-and-accounting.md | trigger: partial batch commit | surface: terminal run accounting | disposition: finding P1
- references/failure-recovery-and-rollback.md | trigger: recovery depends on recorded count | surface: tagged-row recovery path | disposition: verified clean with Source-proven evidence
- references/transactions-and-concurrency.md | trigger: initial transaction signal | surface: single-writer runner | disposition: not applicable because no concurrent writer exists
Not selected:
- references/sharding-partitioning-and-distribution.md | reason: no distributed relation or partial-fleet rollout
Verified clean:
- Tagged rows remain recoverable by run ID.
Rejected candidates:
none
Author validation and scope:
Source inspection only.
Not reviewed:
Production execution.
"""
    failures: list[str] = []
    if packet_contract_failures(actionable):
        failures.append("valid actionable packet rejected")

    missing_fix = re.sub(r"(?m)^- Fix shape:.*$", "", actionable)
    if "finding Fix shape" not in packet_contract_failures(missing_fix):
        failures.append("missing Fix shape accepted")

    generic_fix = re.sub(r"(?m)^- Fix shape:.*$", "- Fix shape: Fix it.", actionable)
    if "specific Fix shape" not in packet_contract_failures(generic_fix):
        failures.append("generic Fix shape accepted")

    wrong_owner = actionable.replace("- next owner: parent", "- next owner: none")
    if "finding next owner" not in packet_contract_failures(wrong_owner):
        failures.append("incorrect finding owner accepted")

    pv_only = """Database review:
- target and base: production snapshot
- review mode: production-readiness
- decision scope and readiness boundary: Production DDL readiness
- decision outcome: unproven
- blocked decision: exact Production DDL operation
- verdict: BLOCKED
- confidence: low
- next owner: parent
Findings:
none
Plain-language summary:
Current environment evidence is required before the readiness decision.
Selected lanes:
- references/environment-and-data-shape-context.md | trigger: scale-dependent DDL | surface: expired production snapshot | disposition: Pending Verification for current relation bytes
Not selected:
none
Verified clean:
none
Rejected candidates:
none
Author validation and scope:
Stale snapshot only.
Not reviewed:
Current Production state.
"""
    if packet_contract_failures(pv_only) or finding_blocks(pv_only):
        failures.append("valid central-PV-only packet rejected")

    clean = """Database review:
- target and base: v2 against v1
- review mode: implementation
- decision scope and readiness boundary: bounded implementation correctness
- decision outcome: supported
- blocked decision: none
- verdict: PASS
- confidence: high
- next owner: none
Findings:
none
Plain-language summary:
The bounded additive change is clean for the reviewed decision scope.
Selected lanes:
- references/schema-and-compatibility.md | trigger: nullable column addition | surface: additive schema change | disposition: verified clean with Source-proven evidence
Not selected:
- references/data-transition-and-accounting.md | reason: no backfill or existing-row mutation
Verified clean:
- Metadata-only addition and compatible rollback.
Rejected candidates:
none
Author validation and scope:
Source and focused test evidence.
Not reviewed:
Production execution.
"""
    if packet_contract_failures(clean) or finding_blocks(clean):
        failures.append("valid clean packet rejected")

    missing_lane_part = actionable.replace(" | surface: terminal run accounting", "")
    if "lane row shape" not in packet_contract_failures(missing_lane_part):
        failures.append("incomplete lane row accepted")

    missing_skip_reason = actionable.replace(" | reason: no distributed relation or partial-fleet rollout", "")
    if "skipped lane reason" not in packet_contract_failures(missing_skip_reason):
        failures.append("unexplained skipped lane accepted")
    excessive_skips = actionable.replace(
        "Not selected:\n",
        "Not selected:\n"
        "- references/a.md | reason: absent a signal\n"
        "- references/b.md | reason: absent b signal\n"
        "- references/c.md | reason: absent c signal\n",
    )
    if "skipped lane budget" not in packet_contract_failures(excessive_skips):
        failures.append("excessive skipped-lane list accepted")
    return failures


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        failures = self_test()
        if failures:
            print("failed self-tests: " + "; ".join(failures))
            return 1
        print("database reviewer packet contract self-tests passed")
        return 0
    if len(sys.argv) != 2 or sys.argv[1] not in PROFILES:
        print("usage: behavior_contract.py <profile> | --self-test")
        return 2
    failures = grade(sys.argv[1], sys.stdin.read())
    if failures:
        print("failed requirements: " + "; ".join(failures))
        return 1
    print("all deterministic contract requirements passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
