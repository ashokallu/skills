#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

runtime_scope="all"
if [[ $# -gt 0 ]]; then
  if [[ $# -ne 2 || "$1" != "--runtime" || "$2" != "codex" ]]; then
    echo "usage: $0 [--runtime codex]" >&2
    exit 2
  fi
  runtime_scope="codex"
fi

if [[ "$runtime_scope" == "codex" ]]; then
  contract_runtimes=(.codex)
else
  contract_runtimes=(.codex .agents .claude)
fi

require_text() {
  local file="$1"
  local text="$2"
  local scenario="$3"

  if ! rg -q -F -- "$text" "$file"; then
    echo "workflow contract failed [$scenario]: missing '$text' in $file" >&2
    exit 1
  fi
}

require_section_text() {
  local file="$1"
  local start="$2"
  local end="$3"
  local expected="$4"
  local scenario="$5"

  python3 - "$file" "$start" "$end" "$expected" "$scenario" <<'PY'
from pathlib import Path
import re
import sys

file, start, end, expected, scenario = sys.argv[1:]

def heading(line):
    return re.sub(r"^#{1,6}\s+", "", line.rstrip()).strip()

lines = Path(file).read_text(encoding="utf-8").replace("\r\n", "\n").splitlines()
starts = [index for index, line in enumerate(lines) if heading(line) == start]
if len(starts) != 1:
    print(
        f"workflow contract failed [{scenario}]: expected one '{start}' "
        f"section in {file}, found {len(starts)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

ends = [
    index for index, line in enumerate(lines)
    if index > starts[0] and heading(line) == end
]
if len(ends) != 1:
    print(
        f"workflow contract failed [{scenario}]: expected one '{end}' "
        f"section after '{start}' in {file}, found {len(ends)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

section = re.sub(r"\s+", " ", "\n".join(lines[starts[0] + 1:ends[0]])).strip()
normalized_expected = re.sub(r"\s+", " ", expected).strip()
if normalized_expected not in section:
    print(
        f"workflow contract failed [{scenario}]: missing '{expected}' "
        f"inside '{start}' in {file}",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
}

require_file() {
  local file="$1"
  local scenario="$2"

  if [[ ! -f "$file" ]]; then
    echo "workflow contract failed [$scenario]: missing file $file" >&2
    exit 1
  fi
}

forbid_file() {
  local file="$1"
  local scenario="$2"

  if [[ -e "$file" ]]; then
    echo "workflow contract failed [$scenario]: obsolete file still exists: $file" >&2
    exit 1
  fi
}

require_occurrence_count() {
  local expected_count="$1"
  local text="$2"
  local scenario="$3"
  shift 3

  python3 - "$expected_count" "$text" "$scenario" "$@" <<'PY'
from pathlib import Path
import sys

expected, text, scenario, *files = sys.argv[1:]
actual = sum(Path(path).read_text(encoding="utf-8").count(text) for path in files)
if actual != int(expected):
    print(
        f"workflow contract failed [{scenario}]: expected {expected} occurrence(s) "
        f"of {text!r}, found {actual} across {', '.join(files)}",
        file=sys.stderr,
    )
    raise SystemExit(1)
PY
}

require_same() {
  local first="$1"
  local second="$2"
  local scenario="$3"

  if [[ "$runtime_scope" == "codex" ]]; then
    return
  fi

  if ! cmp -s "$first" "$second"; then
    echo "workflow contract failed [$scenario]: $first and $second differ" >&2
    exit 1
  fi
}

require_portable_contract_same() {
  local start="$1"
  local end="$2"
  local scenario="$3"
  shift 3

  if [[ "$runtime_scope" == "codex" ]]; then
    return
  fi

  python3 - "$start" "$end" "$scenario" "$@" <<'PY'
from pathlib import Path
import re
import sys

start, end, scenario, *files = sys.argv[1:]

def heading(line):
    return re.sub(r"^#{1,6}\s+", "", line.rstrip()).strip()

def extract(path):
    lines = Path(path).read_text(encoding="utf-8").replace("\r\n", "\n").splitlines()
    starts = [index for index, line in enumerate(lines) if heading(line) == start]
    ends = [index for index, line in enumerate(lines) if heading(line) == end]
    if len(starts) != 1:
        raise ValueError(f"{path}: expected one '{start}' block start, found {len(starts)}")
    following_ends = [index for index in ends if index > starts[0]]
    if len(following_ends) != 1:
        raise ValueError(
            f"{path}: expected one '{end}' block end after '{start}', "
            f"found {len(following_ends)}"
        )
    body = [re.sub(r"^#{1,6}\s+", "", line.rstrip()) for line in lines[starts[0] + 1:following_ends[0]]]
    while body and not body[0]:
        body.pop(0)
    while body and not body[-1]:
        body.pop()
    return "\n".join(body)

try:
    extracted = [(path, extract(path)) for path in files]
except (OSError, ValueError) as error:
    print(f"workflow contract failed [{scenario}]: {error}", file=sys.stderr)
    raise SystemExit(1)

expected_path, expected = extracted[0]
for path, actual in extracted[1:]:
    if actual != expected:
        print(
            f"workflow contract failed [{scenario}]: normalized portable block "
            f"differs between {expected_path} and {path}",
            file=sys.stderr,
        )
        raise SystemExit(1)
PY
}

forbid_text() {
  local file="$1"
  local text="$2"
  local scenario="$3"

  if rg -q -F -- "$text" "$file"; then
    echo "workflow contract failed [$scenario]: forbidden '$text' in $file" >&2
    exit 1
  fi
}

require_peer_challenge_schema() {
  local file="$1"
  local scenario="$2"
  local actual expected

  actual="$(
    awk '
      $0 == "Peer challenge:" { active = 1; next }
      active && $0 == "```" { exit }
      active && /^- [^:]+:/ {
        field = $0
        sub(/:.*/, ":", field)
        print field
      }
    ' "$file"
  )"
  expected=$'- disagreement ID:\n- active objective:\n- decision affected:\n- challenged claim:\n- counterclaim:\n- target/freshness:\n- evidence:\n- objective relevance:\n- role boundary:\n- smallest settling evidence:\n- provisional side-effect boundary:'

  if [[ "$actual" != "$expected" ]]; then
    echo "workflow contract failed [$scenario]: Peer challenge schema drift in $file" >&2
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

require_route_node_inventory() {
  local orchestration="$1"
  local contracts="$2"
  local scenario="$3"

  python3 - "$orchestration" "$contracts" "$scenario" <<'PY'
from pathlib import Path
import re
import sys

orchestration_path = Path(sys.argv[1])
contracts_path = Path(sys.argv[2])
scenario = sys.argv[3]

def fail(message):
    print(f"workflow contract failed [{scenario}]: {message}", file=sys.stderr)
    raise SystemExit(1)

orchestration = orchestration_path.read_text(encoding="utf-8")
contracts = contracts_path.read_text(encoding="utf-8")

# Preservation: the compressed Codex dispatcher makes its three typed route
# tables authoritative instead of duplicating them in workflow-contracts. Keep
# the legacy inventory validation for runtimes that still use the older shape.
if "## Orchestration Reference Map" in orchestration:
    try:
        route_map = orchestration.split("## Orchestration Reference Map", 1)[1].split(
            "## Specialist Skill Routing", 1
        )[0]
    except IndexError:
        fail(f"cannot isolate Orchestration Reference Map in {orchestration_path}")

    section_types = {
        "Decision gates": "decision gate",
        "Owning lanes": "owning lane",
        "Companion contracts": "companion contract",
    }
    seen = set()
    for section, expected_type in section_types.items():
        try:
            body = route_map.split(f"### {section}", 1)[1]
        except IndexError:
            fail(f"missing {section!r} route section in {orchestration_path}")
        following = [
            body.find(f"### {other}")
            for other in section_types
            if other != section and body.find(f"### {other}") >= 0
        ]
        if following:
            body = body[:min(following)]
        for node in re.findall(r"references/([a-z0-9-]+)\.md", body):
            if node in seen:
                fail(f"duplicate route-map entry for {node}")
            seen.add(node)
            reference = orchestration_path.parent / "references" / f"{node}.md"
            if not reference.is_file():
                fail(f"route-map reference does not exist: {reference}")
            match = re.search(r"^Type:\s*(.+?)\s*$", reference.read_text(encoding="utf-8"), re.MULTILINE)
            if not match:
                fail(f"route-map reference has no Type contract: {reference}")
            if match.group(1) != expected_type:
                fail(
                    f"route-map type drift for {node}: section expects "
                    f"{expected_type!r}, file declares {match.group(1)!r}"
                )
    if not seen:
        fail(f"no typed route-map entries found in {orchestration_path}")
    raise SystemExit(0)

try:
    lane_map = orchestration.split("## Orchestration Lane Map", 1)[1].split(
        "## Codex optional worker boundary", 1
    )[0]
except IndexError:
    fail(f"cannot isolate Orchestration Lane Map in {orchestration_path}")

expected_nodes = set(re.findall(r"references/([a-z0-9-]+)\.md", lane_map))
expected_nodes.update({"forward-analysis", "completion-claim-gate"})

try:
    inventory = contracts.split("## Typed Route Adoption Inventory", 1)[1].split(
        "Specialist skills are route boundaries", 1
    )[0]
except IndexError:
    fail(f"cannot isolate Typed Route Adoption Inventory in {contracts_path}")

rows = {}
allowed_types = {
    "owning lane",
    "pre-route gate",
    "specialist boundary",
    "internal companion/lens",
    "output guide",
}
for line in inventory.splitlines():
    if not line.startswith("| `"):
        continue
    cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
    if len(cells) != 5:
        fail(f"inventory row must have five populated columns: {line}")
    node = cells[0].strip("`")
    node_type = cells[1]
    if node in rows:
        fail(f"duplicate inventory row for {node}")
    if node_type not in allowed_types:
        fail(f"unsupported node type {node_type!r} for {node}")
    if any(not cell for cell in cells[2:]):
        fail(f"entry, owned result, and next/visibility columns are required for {node}")
    rows[node] = node_type

missing = sorted(expected_nodes - rows.keys())
extra = sorted(rows.keys() - expected_nodes)
if missing or extra:
    fail(f"typed inventory drift; missing={missing}, extra={extra}")

pre_route_gates = {
    "completion-claim-gate",
    "conflict-resolution",
    "context-recovery",
    "database-review-applicability",
    "delegation",
    "evidence-and-verification-ledger",
    "execution-recovery-and-tool-failures",
    "external-system-boundaries",
    "forward-analysis",
    "idea-challenge",
    "multi-repo-boundaries",
    "objective-lock",
    "parallel-work-coordination",
    "privacy-and-secrets-boundary",
    "request-intake",
    "review-routing",
    "reviewer-handoff",
    "risk-and-side-effects",
    "runtime-capability-check",
    "scope-change-control",
    "loop-control-and-escalation",
    "state-synchronization",
    "task-suspension-checkpoint",
    "work-slicing",
}
output_guides = {"workflow-contracts"}
expected_types = {
    node: (
        "pre-route gate"
        if node in pre_route_gates
        else "output guide"
        if node in output_guides
        else "owning lane"
    )
    for node in expected_nodes
}
wrong_types = {
    node: {"expected": expected_types[node], "actual": rows[node]}
    for node in expected_nodes
    if rows[node] != expected_types[node]
}
if wrong_types:
    fail(f"typed inventory classification drift: {wrong_types}")

specialist_block = contracts.split(
    "Specialist skills are route boundaries", 1
)[1].split("The critic is not a new route-node serializer", 1)[0]
specialists = {
    match for match in re.findall(r"^\| `([^`]+)` \|", specialist_block, re.MULTILINE)
}
expected_specialists = {
    "work-orchestration",
    "code-authoring",
    "pr-workflow",
    "reviewer",
    "database-reviewer",
    "skill-quality-evals",
    "worktree-readiness",
}
if specialists != expected_specialists:
    fail(
        "specialist adoption drift; "
        f"missing={sorted(expected_specialists - specialists)}, "
        f"extra={sorted(specialists - expected_specialists)}"
    )
PY
}

require_universal_reference_interface() {
  local references_dir="$1"
  local workflow_contracts="$2"
  local instruction_maintenance="$3"
  local preservation_ledger="$4"
  local scenario="$5"
  local canonical_references_dir="$6"

  python3 - \
    "$references_dir" \
    "$workflow_contracts" \
    "$instruction_maintenance" \
    "$preservation_ledger" \
    "$scenario" \
    "$canonical_references_dir" <<'PY'
from pathlib import Path
import re
import sys

references_dir = Path(sys.argv[1])
workflow_contracts = Path(sys.argv[2])
instruction_maintenance = Path(sys.argv[3])
preservation_ledger = Path(sys.argv[4])
scenario = sys.argv[5]
canonical_references_dir = Path(sys.argv[6])

expected_fields = [
    "Type",
    "Use when",
    "Skip when",
    "Owns",
    "Does not own",
    "Allowed side effects",
    "Inputs",
    "Exit states",
    "Outputs",
    "Re-enter when",
]
legacy_fields = {
    "Activated by",
    "Enter when",
    "Required inputs",
    "Emits",
    "Reopen when",
    "Reopen only when",
    "Re-enter dispatcher when",
}
allowed_types = {"decision gate", "owning lane", "companion contract"}


def fail(message):
    print(f"workflow contract failed [{scenario}]: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_leading_interface(text, label):
    match = re.search(r"```text\n(.*?)\n```", text, re.DOTALL)
    if not match:
        raise ValueError(f"{label}: missing leading text interface")

    prefix_without_comments = re.sub(
        r"<!--.*?-->",
        "",
        text[:match.start()],
        flags=re.DOTALL,
    )
    prefix_lines = [
        line.strip()
        for line in prefix_without_comments.splitlines()
        if line.strip()
    ]
    if len(prefix_lines) != 1 or not re.fullmatch(r"# [^#].*", prefix_lines[0]):
        raise ValueError(
            f"{label}: interface must immediately follow one H1 title"
        )

    names = []
    values = {}
    active_name = None
    for line in match.group(1).splitlines():
        field = re.match(r"^([A-Z][A-Za-z -]+):\s*(.*)$", line)
        if field:
            active_name = field.group(1)
            if active_name in values:
                raise ValueError(
                    f"{label}: duplicate leading field {active_name!r}"
                )
            names.append(active_name)
            values[active_name] = field.group(2).strip()
            continue
        if active_name is None or not line.startswith(" "):
            raise ValueError(f"{label}: malformed leading interface line {line!r}")
        values[active_name] = f"{values[active_name]} {line.strip()}".strip()

    present_legacy = sorted(set(names) & legacy_fields)
    if present_legacy:
        raise ValueError(
            f"{label}: legacy leading fields remain: {present_legacy}"
        )
    if names != expected_fields:
        raise ValueError(
            f"{label}: expected ordered fields {expected_fields}, found {names}"
        )
    empty = [name for name in expected_fields if not values[name]]
    if empty:
        raise ValueError(f"{label}: empty leading fields: {empty}")
    if values["Type"] not in allowed_types:
        raise ValueError(
            f"{label}: unsupported Type value {values['Type']!r}"
        )
    return values


references = sorted(references_dir.glob("*.md"))
if not references:
    fail(f"no canonical references found in {references_dir}")

parsed_references = {}
for reference in references:
    try:
        parsed_references[reference.name] = parse_leading_interface(
            reference.read_text(encoding="utf-8"),
            str(reference),
        )
    except (OSError, ValueError) as error:
        fail(error)

# Interface values are portable even when a runtime keeps an intentional
# body-level divergence. Compare this narrow boundary without requiring byte
# parity for every complete reference.
canonical_references = sorted(canonical_references_dir.glob("*.md"))
if {path.name for path in canonical_references} != set(parsed_references):
    fail(
        f"{references_dir} and {canonical_references_dir} have different "
        "reference inventories"
    )
for reference in canonical_references:
    try:
        canonical_values = parse_leading_interface(
            reference.read_text(encoding="utf-8"),
            str(reference),
        )
    except (OSError, ValueError) as error:
        fail(error)
    if parsed_references[reference.name] != canonical_values:
        fail(
            f"{references_dir / reference.name} interface differs from "
            f"{reference}"
        )

# These focused negative fixtures prove that the structural parser rejects the
# failure classes this contract names. They do not claim semantic preservation.
valid_fixture = "\n".join(
    [
        "# Fixture",
        "",
        "```text",
        "Type: owning lane",
        "Use when: active",
        "Skip when: inactive",
        "Owns: one action",
        "Does not own: adjacent action",
        "Allowed side effects: none",
        "Inputs: current target",
        "Exit states: complete | blocked",
        "Outputs: evidence",
        "Re-enter when: target changes",
        "```",
    ]
)
invalid_fixtures = {
    "missing-field": valid_fixture.replace("Skip when: inactive\n", ""),
    "duplicate-field": valid_fixture.replace(
        "Use when: active\n",
        "Use when: active\nUse when: duplicate\n",
    ),
    "legacy-field": valid_fixture.replace(
        "Use when: active",
        "Enter when: active",
    ),
    "wrong-order": valid_fixture.replace(
        "Inputs: current target\nExit states: complete | blocked",
        "Exit states: complete | blocked\nInputs: current target",
    ),
    "not-leading": valid_fixture.replace(
        "# Fixture\n\n",
        "# Fixture\n\nIntroductory prose.\n\n",
    ),
}
for fixture_name, fixture in invalid_fixtures.items():
    try:
        parse_leading_interface(fixture, fixture_name)
    except ValueError:
        continue
    fail(f"negative interface fixture unexpectedly passed: {fixture_name}")

workflow_text = workflow_contracts.read_text(encoding="utf-8")
if workflow_text.count("## Universal Reference Interface") != 1:
    fail(
        f"{workflow_contracts} must contain exactly one "
        "Universal Reference Interface owner heading"
    )
if "This file is the sole canonical owner of the interface." not in workflow_text:
    fail(f"{workflow_contracts} does not declare sole interface ownership")

for reference in references:
    if reference == workflow_contracts:
        continue
    if "## Universal Reference Interface" in reference.read_text(encoding="utf-8"):
        fail(f"duplicate Universal Reference Interface owner in {reference}")

maintenance_text = instruction_maintenance.read_text(encoding="utf-8")
if (
    "[Universal Reference Interface]"
    "(workflow-contracts.md#universal-reference-interface)"
    not in maintenance_text
):
    fail(
        f"{instruction_maintenance} does not consume the canonical "
        "Universal Reference Interface"
    )
maintenance_blocks = re.findall(
    r"```text\n(.*?)\n```",
    maintenance_text,
    re.DOTALL,
)
for index, block in enumerate(maintenance_blocks[1:], start=2):
    block_fields = {
        match.group(1)
        for match in re.finditer(
            r"^([A-Z][A-Za-z -]+):",
            block,
            re.MULTILINE,
        )
    }
    if set(expected_fields).issubset(block_fields):
        fail(
            f"{instruction_maintenance} duplicates the universal interface "
            f"in text block {index}"
        )

ledger_text = preservation_ledger.read_text(encoding="utf-8")
correlation_rows = re.findall(
    r"Instruction preservation row "
    r"`lane-correlation-([a-z0-9-]+)`:",
    ledger_text,
)
if (
    len(correlation_rows) != 47
    or len(set(correlation_rows)) != 47
    or "critical-mutation-control" not in correlation_rows
):
    fail(
        "the historical staged-to-Codex snapshot must retain 47 unique "
        "lane-correlation rows, including critical-mutation-control"
    )
PY
}

for objective_lock in \
  .codex/skills/work-orchestration/references/objective-lock.md \
  .agents/skills/work-orchestration/references/objective-lock.md \
  .claude/skills/work-orchestration/references/objective-lock.md; do
  require_file "$objective_lock" "objective-lock-reference"
done
require_same \
  .codex/skills/work-orchestration/references/objective-lock.md \
  .agents/skills/work-orchestration/references/objective-lock.md \
  "objective-lock-codex-agents-parity"
require_same \
  .codex/skills/work-orchestration/references/objective-lock.md \
  .claude/skills/work-orchestration/references/objective-lock.md \
  "objective-lock-codex-claude-parity"
require_same \
  .codex/skills/work-orchestration/references/forward-analysis.md \
  .agents/skills/work-orchestration/references/forward-analysis.md \
  "forward-analysis-codex-agents-parity"
require_same \
  .codex/skills/work-orchestration/references/forward-analysis.md \
  .claude/skills/work-orchestration/references/forward-analysis.md \
  "forward-analysis-codex-claude-parity"
require_same \
  .codex/skills/work-orchestration/references/planning-philosophy.md \
  .agents/skills/work-orchestration/references/planning-philosophy.md \
  "planning-philosophy-codex-agents-parity"
require_same \
  .codex/skills/work-orchestration/references/planning-philosophy.md \
  .claude/skills/work-orchestration/references/planning-philosophy.md \
  "planning-philosophy-codex-claude-parity"

require_before() {
  local file="$1"
  local first="$2"
  local second="$3"
  local scenario="$4"
  local first_line second_line

  first_line=$(rg -n -m1 -F -- "$first" "$file" | cut -d: -f1)
  second_line=$(rg -n -m1 -F -- "$second" "$file" | cut -d: -f1)
  if [[ -z "$first_line" || -z "$second_line" || "$first_line" -ge "$second_line" ]]; then
    echo "workflow contract failed [$scenario]: '$first' must precede '$second' in $file" >&2
    exit 1
  fi
}

require_text AGENTS.md \
  "When the user asks the current agent to review working-directory changes" \
  "root-direct-local-review-ownership"
require_text AGENTS.md \
  "Reserve autonomy acceptance packets when a planned action either targets a" \
  "root-critical-shared-mutation-confirmation-latch"
require_text repo.md \
  'The current agent owns the direct verdict; `review` alone does not request another worker.' \
  "repo-direct-local-review-ownership"
require_text repo.md \
  "## Runtime Identity Bootstrap" \
  "repo-runtime-bootstrap-index"
require_text repo.md \
  'AGENTS.md` -> `GEMINI.md` -> `repo.md` -> `.agents/skills/work-orchestration/SKILL.md' \
  "repo-agy-bootstrap-order"
require_text repo.md \
  "## Review And Publication Ownership" \
  "repo-review-owner-index"
forbid_text repo.md \
  "## Review Closeout" \
  "repo-does-not-own-pr-closeout-procedure"
require_text repo.md \
  "Google Cloud resource MCP authentication recovery is owned by" \
  "repo-cloudsql-recovery-owner-pointer"
forbid_text repo.md \
  "First mint a fresh token and do a read-only direct API" \
  "repo-does-not-own-cloudsql-token-procedure"
require_text repo.md \
  "Route Terraform plan/state/apply advice through" \
  "repo-terraform-owner-pointer"
require_file docs/agents/instruction-preservation-ledger.md \
  "instruction-preservation-ledger"
for preservation_row in \
  root-bootstrap-order \
  agy-grok-defensive-kernel \
  terraform-apply-authority \
  terraform-auth-and-state-boundary \
  terraform-attribute-evidence \
  direct-local-review-ownership \
  pr-review-gates \
  pr-review-packet-closeout \
  pr-thread-ownership \
  pr-commit-topology-and-correction \
  pr-current-head-closeout \
  pr-metadata-truth \
  pr-review-rerun-economy \
  workflow-violation-correction \
  orchestration-phase-readiness-preservation-repair \
  universal-interface-conformance-trigger-repair \
  universal-interface-database-applicability-trigger-repair \
  universal-interface-terraform-advice-trigger-repair \
  universal-interface-exact-block-repair \
  reviewer-thoroughness-recovery-anchor-d78b1cdca \
  reviewer-full-initial-thoroughness-primer \
  google-mcp-token-recovery; do
  require_text docs/agents/instruction-preservation-ledger.md \
    "Instruction preservation row \`$preservation_row\`:" \
    "instruction-preservation-row-$preservation_row"
done
require_text GEMINI.md \
  "## Bootstrap Completeness Verification Gate (Non-Negotiable)" \
  "agy-defensive-bootstrap-kernel-retained"
require_text GEMINI.md \
  "## One-Shot PR Review Closeout (Grok, Grok Build, Antigravity, Gemini)" \
  "agy-defensive-review-kernel-retained"
require_text GEMINI.md \
  "This native-reviewer gate is scoped to ordinary GitHub PR review" \
  "runtime-pr-only-native-reviewer-boundary"
require_file \
  "scripts/dev/check-codex-review-helper.sh" \
  "codex-review-helper-contract"
require_text \
  ".codex/skills/work-orchestration/references/scripts/codex-review" \
  'sandbox_mode="read-only"' \
  "codex-review-read-only"
require_text \
  ".codex/skills/work-orchestration/references/scripts/codex-review" \
  "required canonical review context is unreadable" \
  "codex-review-canonical-context-fail-closed"

for obsolete_path in \
  "work-orchestration/references/publish-pr.md" \
  "work-orchestration/references/pr-template-guide.md"; do
  stale_files="$(rg --hidden -l -F \
    --glob '!.git/**' \
    --glob '!tmp/**' \
    --glob '!scripts/dev/check-agent-workflow-contracts.sh' \
    -- "$obsolete_path" . || true)"
  if [[ -n "$stale_files" ]]; then
    echo "workflow contract failed [obsolete-publication-reference]: $obsolete_path remains in:" >&2
    echo "$stale_files" >&2
    exit 1
  fi
done

reviewer_recovery_anchor="d78b1cdca7e4709fa25c26a29aa59388eebc45d6" # pragma: allowlist secret

for runtime in "${contract_runtimes[@]}"; do
  orchestration="$runtime/skills/work-orchestration/SKILL.md"
  delegation="$runtime/skills/work-orchestration/references/delegation.md"
  approved_plan_execution="$runtime/skills/work-orchestration/references/approved-plan-execution.md"
  plan_acceptance="$runtime/skills/work-orchestration/references/plan-acceptance.md"
  plan_conformance="$runtime/skills/work-orchestration/references/plan-conformance.md"
  rejected_critical_mutation="$runtime/skills/work-orchestration/references/critical-mutation-control.md"
  resource_lifecycle="$runtime/skills/work-orchestration/references/resource-lifecycle.md"
  repository_editing="$runtime/skills/work-orchestration/references/repository-editing.md"
  abort_unwind="$runtime/skills/work-orchestration/references/abort-and-unwind.md"
  request_intake="$runtime/skills/work-orchestration/references/request-intake.md"
  objective_lock="$runtime/skills/work-orchestration/references/objective-lock.md"
  idea_challenge="$runtime/skills/work-orchestration/references/idea-challenge.md"
  forward_analysis="$runtime/skills/work-orchestration/references/forward-analysis.md"
  planning_philosophy="$runtime/skills/work-orchestration/references/planning-philosophy.md"
  workflow_synthesis="$runtime/skills/work-orchestration/references/workflow-synthesis-example.md"
  workflow_contracts="$runtime/skills/work-orchestration/references/workflow-contracts.md"
  autonomy_envelope="$runtime/skills/work-orchestration/references/autonomy-envelope.md"
  external_system="$runtime/skills/work-orchestration/references/external-system-boundaries.md"
  session_bootstrap="$runtime/skills/work-orchestration/references/session-bootstrap.md"
  runtime_capability="$runtime/skills/work-orchestration/references/runtime-capability-check.md"
  orchestration_conformance="$runtime/skills/work-orchestration/references/orchestration-conformance.md"
  scope_change="$runtime/skills/work-orchestration/references/scope-change-control.md"
  execution_recovery="$runtime/skills/work-orchestration/references/execution-recovery-and-tool-failures.md"
  loop_control="$runtime/skills/work-orchestration/references/loop-control-and-escalation.md"
  risk_side_effects="$runtime/skills/work-orchestration/references/risk-and-side-effects.md"
  completion_claim="$runtime/skills/work-orchestration/references/completion-claim-gate.md"
  review_routing="$runtime/skills/work-orchestration/references/review-routing.md"
  conflict_resolution="$runtime/skills/work-orchestration/references/conflict-resolution.md"
  state_synchronization="$runtime/skills/work-orchestration/references/state-synchronization.md"
  database_applicability="$runtime/skills/work-orchestration/references/database-review-applicability.md"
  closeout_review="$runtime/skills/work-orchestration/references/closeout-review.md"
  reviewer_handoff="$runtime/skills/work-orchestration/references/reviewer-handoff.md"
  review_control="$runtime/skills/work-orchestration/references/review-control-plane.md"
  pr_workflow="$runtime/skills/pr-workflow/SKILL.md"
  review_worktree="$runtime/skills/pr-workflow/references/review-worktree.md"
  pr_operations="$runtime/skills/github-workflow/references/pr-operations.md"
  re_review="$runtime/skills/pr-workflow/references/re-review-worktree.md"
  luna_scouting="$runtime/skills/work-orchestration/references/luna-scouting.md"
  waiting="$runtime/skills/work-orchestration/references/waiting-and-monitoring.md"
  suspension="$runtime/skills/work-orchestration/references/task-suspension-checkpoint.md"
  incident="$runtime/skills/work-orchestration/references/incident-command.md"
  zoom_out="$runtime/skills/work-orchestration/references/zoom-out.md"
  work_slicing="$runtime/skills/work-orchestration/references/work-slicing.md"
  reviewer="$runtime/skills/reviewer/SKILL.md"
  reviewer_bootstrap="$runtime/skills/reviewer/references/review-bootstrap.md"
  reviewer_intent="$runtime/skills/reviewer/references/review-intent-understanding-lens.md"
  reviewer_analysis="$runtime/skills/reviewer/references/review-analysis-routing.md"
  reviewer_closeout="$runtime/skills/reviewer/references/review-verdict-closeout.md"
  authoring="$runtime/skills/code-authoring/SKILL.md"
  authoring_core="$runtime/skills/code-authoring/references/authoring-core.md"
  instruction_maintenance="$runtime/skills/work-orchestration/references/instruction-maintenance.md"
  cloudsql_readonly="$runtime/skills/readonly-data-access/references/cloudsql-readonly.md"
  release_terraform_plan="$runtime/skills/work-orchestration/references/release-terraform-plan-analysis.md"
  orchestration_evaluation_cases="$runtime/skills/work-orchestration/references/orchestration-evaluation-cases.md"
  change_intake="$runtime/skills/code-authoring/references/change-intake.md"
  pre_code_critic="$runtime/skills/code-authoring/references/pre-code-critic-assignment.md"
  instruction_authoring="$runtime/skills/code-authoring/references/instruction-skill-agent-authoring.md"
  impact_source_map="$runtime/skills/code-authoring/references/impact-and-source-map.md"
  docs_operator_truth="$runtime/skills/code-authoring/references/docs-and-operator-truth.md"
  case_study_transfer="$runtime/skills/code-authoring/references/case-study-transfer-preflight.md"
  worktree_readiness="$runtime/skills/worktree-readiness/SKILL.md"
  publish_pr="$runtime/skills/pr-workflow/references/publish-pr.md"
  pr_template_guide="$runtime/skills/pr-workflow/references/pr-template-guide.md"
  obsolete_publish_pr="$runtime/skills/work-orchestration/references/publish-pr.md"
  obsolete_pr_template_guide="$runtime/skills/work-orchestration/references/pr-template-guide.md"
  improve="$runtime/skills/improve/SKILL.md"
  improve_audit="$runtime/skills/improve/references/audit-workflow.md"
  improve_planning="$runtime/skills/improve/references/planning-workflow.md"
  improve_execute="$runtime/skills/improve/references/execution-handoff.md"
  improve_lifecycle="$runtime/skills/improve/references/plan-lifecycle.md"
  improve_issues="$runtime/skills/improve/references/issue-publication.md"
  improve_template="$runtime/skills/improve/references/plan-template.md"

  require_text "$request_intake" \
    "Exact agent authority or permission bound to one displayed artifact/version" \
    "request-intake-typed-approval-transport"
  require_text "$request_intake" \
    "never open a second channel" \
    "request-intake-post-presentation-fail-closed"
  require_text "$request_intake" \
    'Root-only `request_user_decision` with `mode=approval`, an empty caller-options list' \
    "request-intake-approval-mode-and-options"
  require_text "$request_intake" \
    'positively absent before presentation' \
    "request-intake-positive-absence-only-fallback"
  require_text "$request_intake" \
    'The transport matrix above is authoritative' \
    "request-intake-transport-matrix-authoritative"
  forbid_text "$request_intake" \
    'when available; otherwise it asks one blocking plain-text question' \
    "request-intake-no-generic-approval-fallback"
  require_text "$execution_recovery" \
    "Retry decision record:" \
    "execution-recovery-complete-retry-record"
  for retry_field in \
    "failure class and exact locus:" \
    "partial state and target freshness:" \
    "changed variable:" \
    "falsifier / why this change should distinguish the hypothesis:" \
    "evidence invalidated by the failure or recovery:" \
    "retained, cleaned, or quarantined artifacts:" \
    "retry owner:" \
    "stop condition:"; do
    require_text "$execution_recovery" \
      "$retry_field" \
      "execution-recovery-retry-field"
  done
  require_text "$execution_recovery" \
    "remaining retry budget: 1 | 0" \
    "execution-recovery-bounded-retry-budget"
  require_text "$loop_control" \
    "initial failure followed by one changed-variable retry" \
    "loop-control-two-attempt-circuit-breaker"
  require_text "$orchestration_evaluation_cases" \
    "Retry record incomplete" \
    "orchestration-eval-retry-record-nonactivation"
  require_text "$orchestration_evaluation_cases" \
    "Changed-variable retry reproduces failure" \
    "orchestration-eval-retry-circuit-breaker"

  require_file "$publish_pr" "pr-workflow-publish-owner"
  require_file "$pr_template_guide" "pr-workflow-template-owner"
  forbid_file "$obsolete_publish_pr" "orchestration-publish-owner-retired"
  forbid_file "$obsolete_pr_template_guide" "orchestration-template-owner-retired"
  require_text "$publish_pr" \
    "The Codex review helper is owned by \`work-orchestration\`" \
    "codex-review-helper-owner-explicit"
  require_text "$publish_pr" \
    "never search for a guessed copy under either" \
    "codex-review-helper-no-nearby-skill-guess"
  require_text "$closeout_review" \
    "<active-runtime-skill-root>/work-orchestration/references/scripts/codex-review --help" \
    "codex-review-helper-resolved-from-owner"
  require_text "$closeout_review" \
    "Invoke the verified helper while the target" \
    "codex-review-helper-target-cwd"
  forbid_text "$publish_pr" \
    "this lane's \`references/scripts/codex-review" \
    "codex-review-helper-no-pr-lane-relative-path"
  forbid_text "$publish_pr" \
    "case study" \
    "publish-pr-no-case-study-lookup"
  forbid_text "$publish_pr" \
    "case-study" \
    "publish-pr-no-case-study-path"
  require_text "$publish_pr" \
    "Opening a PR is not handoff" \
    "publish-pr-native-handoff-doctrine"
  require_text "$publish_pr" \
    "small diffs do not bypass authoring" \
    "publish-pr-native-small-diff-doctrine"
  require_text "$instruction_maintenance" \
    "## Instruction Ownership And Compaction Gate" \
    "instruction-compaction-canonical-owner"
  require_text "$instruction_maintenance" \
    "Instruction preservation row <stable-id>:" \
    "instruction-row-level-preservation-ledger"
  require_text "$instruction_maintenance" \
    "reachable without following a pointer back to the source" \
    "instruction-relocation-non-circular-owner"
  require_text "$instruction_maintenance" \
    "Single-owner checks may allow an explicitly named minimal fail-closed summary" \
    "instruction-single-owner-fallback-boundary"
  require_text "$instruction_maintenance" \
    "AGY/Grok defensive kernel text stays monolithic" \
    "agy-grok-defensive-kernel-preserved"
  require_universal_reference_interface \
    "$runtime/skills/work-orchestration/references" \
    "$workflow_contracts" \
    "$instruction_maintenance" \
    "docs/agents/instruction-preservation-ledger.md" \
    "universal-reference-interface-structural-contract" \
    ".codex/skills/work-orchestration/references"
  require_text "$workflow_contracts" \
    "Every routable reference must use this exact leading block:" \
    "universal-interface-exact-block-contract"
  require_text "$workflow_contracts" \
    "Runtime-specific behavior may diverge in a" \
    "universal-interface-body-divergence-boundary"
  forbid_text "$workflow_contracts" \
    "A reference may use prose instead of this exact block" \
    "universal-interface-no-prose-variance"
  require_text "$orchestration_conformance" \
    "Use when: parent-authored substantive work is about to enter a pre-code critic," \
    "orchestration-conformance-semantic-trigger"
  require_text "$orchestration_conformance" \
    "Skip when: reviewing a teammate or external open PR from current public artifacts" \
    "orchestration-conformance-semantic-skip"
  forbid_text "$orchestration_conformance" \
    "orchestration history is irrelevant to the verdict" \
    "orchestration-conformance-no-history-relevance-bypass"
  require_text "$database_applicability" \
    "Use when: authored PR-bound work or ordinary PR review has a stable target, base," \
    "database-applicability-semantic-trigger"
  require_text "$database_applicability" \
    "Skip when: no authored PR-bound or ordinary PR-review decision point exists" \
    "database-applicability-semantic-skip"
  forbid_text "$database_applicability" \
    "Skip when: the changed surface has no database contract or data-access consequence" \
    "database-applicability-no-disposition-as-bypass"
  require_text "$release_terraform_plan" \
    "Skip when: only execution of apply, approval, unlock, cancellation, discard," \
    "terraform-advice-semantic-skip"
  require_text "$release_terraform_plan" \
    "deployment, or rollback is requested, with no read-only analysis or advice" \
    "terraform-advice-preserved-when-apply-mentioned"
  forbid_text "$release_terraform_plan" \
    "Skip when: apply, approval, unlock, cancellation, discard, deployment, or rollback is" \
    "terraform-advice-no-action-word-bypass"
  require_text "$orchestration_evaluation_cases" \
    "Straightforward parent-authored work reaches meaningful editing" \
    "orchestration-conformance-obvious-own-work-case"
  require_text "$orchestration_evaluation_cases" \
    "Ordinary PR review appears database-free" \
    "database-applicability-negative-trace-case"
  require_text "$orchestration_evaluation_cases" \
    "including “should I apply?”" \
    "terraform-advice-apply-question-case"
  require_text "$cloudsql_readonly" \
    "## Registered Google Cloud MCP Token Recovery" \
    "cloudsql-token-recovery-canonical-owner"
  require_text "$cloudsql_readonly" \
    "fresh-token smoke succeeds while the registered MCP still returns" \
    "cloudsql-token-recovery-diagnostic-split"
  require_text "$cloudsql_readonly" \
    "The new process boundary is required" \
    "cloudsql-token-recovery-process-boundary"
  require_text "$cloudsql_readonly" \
    "env -u GOOGLE_MCP_ACCESS_TOKEN" \
    "cloudsql-token-recovery-secret-safe-smoke"
  require_text "$cloudsql_readonly" \
    "SELECT 1" \
    "cloudsql-token-recovery-bounded-query"
  forbid_text "$cloudsql_readonly" \
    'follow `repo.md` Google Cloud MCP token-refresh' \
    "cloudsql-token-recovery-no-circular-repo-owner"
  require_text "$release_terraform_plan" \
    "Terraform state file for the same environment" \
    "terraform-plan-state-canonical-owner"
  require_text "$release_terraform_plan" \
    'A summary such as `0 to destroy` is never enough' \
    "terraform-plan-attribute-evidence-owner"
  require_text "$release_terraform_plan" \
    "si-terraform-services-prd/states" \
    "terraform-plan-environment-state-owner"
  require_text "$pr_workflow" \
    "Native Reviewer Dispatch Gate for ordinary PR review" \
    "pr-review-native-gate-canonical-owner"
  require_text "$pr_workflow" \
    "PR body freshness is part of the same gate as code freshness" \
    "pr-body-freshness-canonical-owner"
  require_text "$pr_workflow" \
    "current-head CI" \
    "pr-current-head-closeout-canonical-owner"
  require_text "$orchestration_evaluation_cases" \
    "Instruction-only bootstrap before classification" \
    "instruction-bootstrap-evaluation-case"
  require_text "$orchestration_evaluation_cases" \
    "Instruction compaction or relocation" \
    "instruction-compaction-evaluation-case"
  require_file "$approved_plan_execution" \
    "approved-plan-execution-canonical-owner"
  require_file "$plan_acceptance" \
    "plan-acceptance-canonical-owner"
  require_file "$plan_conformance" \
    "plan-conformance-canonical-owner"
  require_text "$orchestration" \
    "decision-ready candidate through the bounded critic consultation" \
    "plan-acceptance-route-precedence"
  require_text "$plan_acceptance" \
    "Apparent clarity and agent confidence do not waive activation" \
    "plan-acceptance-confident-bypass-blocked"
  require_text "$plan_acceptance" \
    "Missing tool capability never implies" \
    "plan-acceptance-question-capability-fallback"
  require_text "$plan_acceptance" \
    "A critic-required material revision updates the candidate revision before plan" \
    "plan-acceptance-critic-revision-versioning"
  require_text "$plan_acceptance" \
    "Plan approval never grants commit, push, publication, deployment" \
    "plan-acceptance-action-authority-boundary"
  require_text "$plan_conformance" \
    "Every approved step maps to implementation evidence" \
    "plan-conformance-step-to-evidence"
  require_text "$plan_conformance" \
    "Every changed file, meaningful hunk, and mechanism maps to an approved step" \
    "plan-conformance-surface-to-step"
  require_text "$plan_conformance" \
    "File presence, changed-file inventory, or phrase presence" \
    "plan-conformance-same-file-semantic-preservation"
  require_text "$plan_conformance" \
    "input to review, never proof" \
    "plan-conformance-reviewer-independence"
  require_text "$request_intake" \
    "looks clear and the agent is confident" \
    "intent-alignment-confident-request-activation"
  require_text "$request_intake" \
    "Ordinary localized reversible work does not activate" \
    "intent-alignment-ordinary-task-nonactivation"
  require_text "$objective_lock" \
    "require one explicit intent-contract approval" \
    "intent-alignment-objective-single-owner"
  require_text "$scope_change" \
    "Plan-changing → re-plan" \
    "plan-change-scope-route"
  require_text "$orchestration" \
    "Current accepted plan with an unchanged objective and target, unless a" \
    "approved-plan-execution-positive-route"
  require_text "$orchestration" \
    "specialist already owns the complete execution workflow" \
    "approved-plan-execution-specialist-precedence"
  require_text "$orchestration" \
    "[approved-plan-execution](references/approved-plan-execution.md)" \
    "approved-plan-execution-owning-lane-route"
  require_text "$approved_plan_execution" \
    "Owns: plan admission, step-to-phase sequencing, progress tracking, delta detection," \
    "approved-plan-execution-canonical-owner"
  require_text "$approved_plan_execution" \
    "Plan acceptance by itself is not execution authority" \
    "approved-plan-action-specific-authority"
  require_text "$approved_plan_execution" \
    "exact plan body and content identity match" \
    "approved-plan-content-identity-admission"
  require_text "$approved_plan_execution" \
    "semantic preservation and deletion obligations inside touched files" \
    "approved-plan-execution-semantic-obligations"
  require_text "$delegation" \
    "[Approved Plan Execution](approved-plan-execution.md) owns plan admission" \
    "delegation-approved-plan-boundary-link"
  require_occurrence_count 1 \
    "Owns: plan admission, step-to-phase sequencing, progress tracking, delta detection," \
    "approved-plan-execution-single-owner" \
    "$approved_plan_execution" \
    "$delegation" \
    "$orchestration"
  require_text "$orchestration_evaluation_cases" \
    "| Current accepted plan | Visible current approval, unchanged objective/target, and no specialist owns the complete execution workflow | \`approved-plan-execution\` |" \
    "approved-plan-execution-positive-case"
  require_text "$orchestration_evaluation_cases" \
    "| Specialist-owned accepted plan | Visible current approval and one specialist owns the complete execution workflow | Owning specialist |" \
    "approved-plan-execution-specialist-owner-negative-case"
  require_text "$orchestration_evaluation_cases" \
    "| Proposed plan only | Plan is agent-authored or otherwise not visibly accepted | \`idea-challenge\` or owner decision |" \
    "approved-plan-execution-unaccepted-negative-case"
  require_text "$orchestration_evaluation_cases" \
    "| Stale accepted-plan target |" \
    "approved-plan-execution-stale-target-case"
  require_text "$orchestration_evaluation_cases" \
    "| Accepted plan changes materially |" \
    "approved-plan-execution-material-delta-case"
  require_text "$orchestration_evaluation_cases" \
    "| Plan execution discovers optional cleanup |" \
    "approved-plan-execution-optional-cleanup-case"
  require_text "$orchestration_evaluation_cases" \
    "| Plan execution discovers an omitted required consumer |" \
    "approved-plan-execution-required-consumer-case"
  forbid_file "$rejected_critical_mutation" \
    "standalone-critical-mutation-owner-rejected"
  forbid_text "$orchestration" \
    "critical-mutation-control.md" \
    "standalone-critical-mutation-route-rejected"
  require_file "$resource_lifecycle" \
    "resource-lifecycle-companion-present"
  require_text "$orchestration" \
    "[resource-lifecycle](references/resource-lifecycle.md)" \
    "resource-lifecycle-dispatcher-link"
  require_text "$repository_editing" \
    "[resource-lifecycle.md](resource-lifecycle.md)" \
    "resource-lifecycle-repository-editing-link"
  require_text "$resource_lifecycle" \
    "Type: companion contract" \
    "resource-lifecycle-companion-type"
  require_occurrence_count 1 \
    "Owns: the shared lifecycle record shape and cross-resource invariants for ownership, retention, cleanup, and residual-state reporting" \
    "resource-lifecycle-single-owner" \
    "$resource_lifecycle" \
    "$orchestration" \
    "$repository_editing"
  require_text "$resource_lifecycle" \
    "| Temporary resource created |" \
    "resource-lifecycle-created-case"
  require_text "$resource_lifecycle" \
    "| No temporary resource created |" \
    "resource-lifecycle-not-activated-case"
  require_text "$resource_lifecycle" \
    "| Cleanup ownership uncertain |" \
    "resource-lifecycle-uncertain-owner-case"
  require_text "$resource_lifecycle" \
    "| Cleanup remains incomplete |" \
    "resource-lifecycle-residual-state-case"
  require_text "$orchestration" \
    "## Next-Action Index" \
    "next-action-index-visible"
  require_text "$orchestration" \
    "This index is navigation only; the detailed" \
    "next-action-index-non-authoritative"
  require_occurrence_count 1 \
    "## Deterministic Route Precedence" \
    "deterministic-route-precedence-single-owner" \
    "$orchestration"
  # Preservation: both dispatcher shapes keep publication as a distinct phase;
  # runtime-specific typography around the pr-workflow owner is not the contract.
  require_text "$orchestration" \
    "Publication is a separate phase" \
    "orchestration-publication-specialist-dispatch"
  require_text "$pr_workflow" \
    "references/publish-pr.md\` lane" \
    "pr-workflow-publication-owner"
  require_text "$orchestration" \
    "Work Item Profile: not activated\` unless" \
    "work-item-profile-dispatch-activation"
  require_text "$orchestration" \
    "Work Item Profile activation is conditional; task classification is universal" \
    "work-item-profile-does-not-waive-classification"
  require_text "$orchestration" \
    "Classification receipt:" \
    "classification-receipt-schema"
  require_text "$orchestration" \
    "A route label, compact substitute, or plan without every field is not enough" \
    "classification-receipt-before-action"
  forbid_text "$orchestration" \
    "Tier 2" \
    "classification-no-compact-non-fast-exit-tier"
  require_text "$orchestration" \
    "Every non-fast-exit task uses the complete receipt" \
    "classification-complete-non-fast-exit-receipt"
  require_text "$orchestration" \
    "Classification: fast-exit; investigation; read-only; no repository or external mutation" \
    "fast-exit-proportional-classification"
  require_text "$session_bootstrap" \
    "This is a **read sequence**, not an authority-precedence rule." \
    "bootstrap-read-order-not-authority-precedence"
  require_text "$session_bootstrap" \
    "most-specific-applicable instruction rule" \
    "bootstrap-most-specific-applicable-precedence"
  require_text "$session_bootstrap" \
    "A new user message, ordinary follow-up turn, or" \
    "bootstrap-follow-up-turn-not-new-session"
  require_text "$session_bootstrap" \
    "When either cannot be proved, treat the work as a new session" \
    "bootstrap-unproved-continuity-fails-closed"
  require_text "$session_bootstrap" \
    "A higher-priority platform or runtime contract may still require" \
    "bootstrap-higher-priority-fresh-read-floor"
  require_text "$session_bootstrap" \
    "Instruction reuse: reused=" \
    "bootstrap-conditional-reuse-row"
  require_text "$conflict_resolution" \
    "there is no" \
    "conflict-resolution-settled-premise-exit"
  require_text "$conflict_resolution" \
    "\`state-synchronization\` result" \
    "conflict-resolution-state-synchronization-handoff"
  require_text "$conflict_resolution" \
    "Ask for an owner decision only when the evidence remains inconclusive" \
    "conflict-resolution-material-premise-question-boundary"
  require_text "$state_synchronization" \
    "proceed on the verified fact" \
    "state-synchronization-verified-fact-guidance"
  require_text "$state_synchronization" \
    "If evidence remains inconclusive, hand off to \`conflict-resolution\`" \
    "state-synchronization-material-premise-handoff"
  require_text "$orchestration" \
    "owning execution lane, specialist, or operational runbook" \
    "imperative-action-execution-owner-handoff"
  require_text "$orchestration" \
    "returned disposition is incomplete unless it explicitly" \
    "settled-premise-eager-fallback"
  require_text "$orchestration" \
    "When activated, load" \
    "work-item-profile-canonical-load"
  require_text "$orchestration" \
    "A profile or forecast never authorizes publication" \
    "work-item-profile-forecast-boundary"
  require_text "$workflow_contracts" \
    "use the exact canonical enum token" \
    "work-item-profile-canonical-token-serialization"
  # Preservation: the compressed companion promotes this canonical contract by
  # one heading level without changing its owner or anchor.
  require_text "$workflow_contracts" \
    "## Work Item Profile" \
    "work-item-profile-canonical-owner"
  require_text "$workflow_contracts" \
    "not a second task definition, calendar" \
    "work-item-profile-no-time-estimate"
  require_text "$workflow_contracts" \
    "Forecasts are advisory" \
    "work-item-profile-advisory-forecast"
  require_text "$work_slicing" \
    "initiative container\` cannot" \
    "work-item-profile-initiative-slicing"
  require_text "$impact_source_map" \
    "Do not reclassify from file count or diff size" \
    "work-item-profile-impact-reconciliation"
  require_text "$pre_code_critic" \
    "classification and advisory review forecast only where" \
    "work-item-profile-critic-transport"
  require_text "$review_routing" \
    "advisory forecast, not a verdict or waiver" \
    "work-item-profile-review-authority"
  quality_scout="$runtime/skills/code-authoring/references/quality-scout.md"
  authoring_preflight="$runtime/skills/code-authoring/references/authoring-preflight.md"
  database_reviewer="$runtime/skills/database-reviewer/SKILL.md"
  database_closeout="$runtime/skills/database-reviewer/references/verdict-closeout.md"
  author_self_review="$runtime/skills/code-authoring/references/author-self-review.md"
  skill_quality="$runtime/skills/skill-quality-evals/SKILL.md"
  real_model_behavior_eval="$runtime/skills/skill-quality-evals/references/real-model-behavior-evaluation.md"

  require_file "$orchestration_conformance" \
    "orchestration-conformance-canonical-owner"
  require_text "$orchestration_conformance" \
    "This is admission control, not a new gate or a source-provenance ceremony" \
    "orchestration-conformance-decision-attestation"
  require_text "$orchestration_conformance" \
    "serialize governing-source paths, file digests, source hashes" \
    "orchestration-conformance-no-source-inventory"
  require_text "$orchestration_conformance" \
    "Source freshness and attestation reuse are separate" \
    "orchestration-conformance-separate-reuse"
  require_text "$orchestration_conformance" \
    "Before the first attestation in a parent session" \
    "orchestration-conformance-parent-fresh-read"
  require_text "$orchestration_conformance" \
    "Do not require this attestation for review of a teammate or existing open PR" \
    "orchestration-conformance-teammate-pr-exemption"
  require_text "$orchestration" \
    "references/orchestration-conformance.md" \
    "orchestration-conformance-dispatch"
  require_text "$orchestration" \
    "Reuse an unchanged same-session attestation" \
    "orchestration-conformance-native-reuse"
  require_text "$orchestration" \
    "reread that decision owner" \
    "orchestration-conformance-native-changed-source-proof"
  require_text "$orchestration" \
    "rerun an unrelated unchanged gate" \
    "orchestration-conformance-native-no-unrelated-rerun"
  require_text "$real_model_behavior_eval" \
    "plain descendant directory inherits the parent repository" \
    "real-model-behavior-eval-isolation-parent-repo-footgun"
  require_text "$real_model_behavior_eval" \
    "changed source path with its isolated counterpart" \
    "real-model-behavior-eval-isolation-digest-proof"
  require_text "$real_model_behavior_eval" \
    "scripts/dev/agent-collab-vpn-smoke.sh" \
    "real-model-behavior-eval-vpn-script"
  require_text "$real_model_behavior_eval" \
    "smoke selects the Waza/Copilot lane" \
    "real-model-behavior-eval-vpn-route"
  require_text "$real_model_behavior_eval" \
    "failed smoke selects the Pi OpenAI Codex lane" \
    "real-model-behavior-eval-no-vpn-route"
  require_text "$real_model_behavior_eval" \
    'A CLI override such as `--model mock`' \
    "real-model-behavior-eval-mock-override-warning"
  require_text "$real_model_behavior_eval" \
    'never write `executor: pi`' \
    "real-model-behavior-eval-no-invalid-waza-executor"
  require_text "$real_model_behavior_eval" \
    '`openai-codex/gpt-5.6-luna` at low thinking' \
    "real-model-behavior-eval-pi-model"
  require_text "$real_model_behavior_eval" \
    '`Pi OpenAI Codex behavior evidence`' \
    "real-model-behavior-eval-evidence-boundary"
  require_text "$real_model_behavior_eval" \
    '`tmp/litellm-supported-model-slugs.md` is a dated LiteLLM' \
    "real-model-behavior-eval-historical-model-list"
  require_text "$real_model_behavior_eval" \
    'Inline `config.prompt` graders are unsupported' \
    "real-model-behavior-eval-inline-prompt-rejection"
  require_text "$real_model_behavior_eval" \
    '`candidate_visible_inputs` inventory contains every one needed' \
    "real-model-behavior-eval-linked-input-preflight"
  require_text "$authoring" \
    "orchestration conformance:" \
    "orchestration-conformance-authoring-entry"
  require_text "$authoring" \
    "ask the parent only for that attestation" \
    "orchestration-conformance-authoring-smallest-request"
  require_text "$change_intake" \
    "orchestration conformance attestation" \
    "orchestration-conformance-change-intake"
  require_text "$change_intake" \
    "do not replace that evidence request" \
    "orchestration-conformance-change-intake-no-checklist"
  require_text "$pre_code_critic" \
    "orchestration conformance attestation" \
    "orchestration-conformance-pre-code-critic"
  require_text "$authoring_preflight" \
    "## Final Orchestration Conformance Reconciliation" \
    "orchestration-conformance-final-target-reconciliation"
  require_text "$change_intake" \
    "## Accepted-Plan Conformance Intake" \
    "plan-conformance-authoring-intake"
  require_text "$authoring_preflight" \
    "## Accepted-Plan Conformance Proof" \
    "plan-conformance-authoring-preflight"
  require_text "$reviewer_intent" \
    "## Accepted-Plan Conformance" \
    "plan-conformance-reviewer-intent"
  require_text "$reviewer_intent" \
    "Do not accept the parent or authoring ledger as proof" \
    "plan-conformance-reviewer-independent-diff"
  require_text "$reviewer_handoff" \
    "## Own-Work Conformance Admission" \
    "orchestration-conformance-reviewer-handoff"
  require_text "$reviewer_bootstrap" \
    "orchestration-conformance.md" \
    "orchestration-conformance-review-bootstrap"
  require_text "$reviewer_intent" \
    "final target-bound" \
    "orchestration-conformance-review-intent"
  for conformance_consumer in \
    "$orchestration" \
    "$authoring" \
    "$change_intake" \
    "$pre_code_critic" \
    "$authoring_preflight" \
    "$reviewer_handoff" \
    "$reviewer_bootstrap" \
    "$reviewer_intent"; do
    forbid_text "$conformance_consumer" \
      "Orchestration conformance receipt:" \
      "orchestration-conformance-no-duplicate-schema"
    forbid_text "$conformance_consumer" \
      "ordered repo-relative paths and immutable current-byte content identities" \
      "orchestration-conformance-no-governing-source-inventory"
    forbid_text "$conformance_consumer" \
      "governing-source content identities for the consuming session" \
      "orchestration-conformance-no-consumer-source-hash-ledger"
  done

  require_route_node_inventory \
    "$orchestration" \
    "$workflow_contracts" \
    "typed-route-adoption-inventory"
  for boundary in \
    "$orchestration" \
    "$authoring" \
    "$pr_workflow" \
    "$reviewer" \
    "$database_reviewer" \
    "$skill_quality" \
    "$worktree_readiness"; do
    require_text "$boundary" \
      "Lane Journey Contract" \
      "specialist-route-node-adoption"
  done
  require_text "$workflow_contracts" \
    "The parent is the sole user-visible journey narrator" \
    "single-journey-serializer"
  require_text "$workflow_contracts" \
    "before the new phase's first action" \
    "phase-transition-before-action"
  require_text "$workflow_contracts" \
    "join result before any dependent parent action" \
    "delegation-join-before-dependent-action"
  require_text "$workflow_contracts" \
    "Fast-exit remains classified" \
    "fast-exit-classification-boundary"
  require_text "$workflow_contracts" \
    "A route label without the receipt's work type" \
    "route-label-does-not-satisfy-classification"
  require_text "$workflow_contracts" \
    "route fields to a stricter parser-facing packet" \
    "strict-packet-journey-isolation"

  require_file "$database_applicability" "database-applicability-reference"
  require_text "$database_applicability" \
    '`required`: current evidence proves a direct database surface or an indirect' \
    "database-applicability-direct-indirect"
  require_text "$database_applicability" \
    '`Pending Verification`: the parent cannot yet prove either state' \
    "database-applicability-tristate"
  require_text "$database_applicability" \
    '`not required` needs an evidenced negative trace' \
    "database-applicability-negative-trace"
  require_text "$database_applicability" \
    "reviewer unavailability, runtime limits" \
    "database-applicability-non-waivable"
  require_text "$database_applicability" \
    "first push or force-push" \
    "database-applicability-author-block"
  require_text "$database_applicability" \
    "overall PR review synthesis or handoff" \
    "database-applicability-review-block"
  require_text "$database_applicability" \
    "this classification must not delay or shape that verdict" \
    "database-applicability-ordinary-review-independence"
  require_text "$database_applicability" \
    "This classification identifies proof needs; it does not authorize live access." \
    "database-applicability-no-live-authority"
  require_text "$database_applicability" \
    "dispatch \`database-reviewer\` without" \
    "database-applicability-static-dispatch"
  require_text "$database_applicability" \
    "Authority from ordinary review never carries into that" \
    "database-applicability-no-authority-carryover"

  for improve_ref in \
    "$improve_audit" \
    "$improve_planning" \
    "$improve_execute" \
    "$improve_lifecycle" \
    "$improve_issues" \
    "$improve_template"; do
    require_file "$improve_ref" "improve-reference-integrity"
  done

  require_text "$improve" "## Variant Router" "improve-eager-variant-router"
  require_text "$improve" \
    "Load only the selected" \
    "improve-lazy-reference-loading"
  require_text "$improve" \
    "durable ranked improvement backlog" \
    "improve-advisory-product-boundary"
  require_text "$improve" \
    "at most three actionable code-health tasks" \
    "improve-quality-scout-boundary"
  require_text "$quality_scout" \
    "at most three actionable repository-quality" \
    "quality-scout-current-work-boundary"
  require_text "$quality_scout" \
    "durable ranked backlog" \
    "quality-scout-improve-handoff"
  require_text "$authoring_preflight" \
    "## Changed Boundary Proof" \
    "authoring-changed-boundary-proof"
  require_text "$conflict_resolution" \
    "the challenge transport, round termination, and provisional side-effect" \
    "peer-challenge-role-ownership"
  require_text "$conflict_resolution" \
    "Peer challenge:" \
    "peer-challenge-packet"
  require_text "$conflict_resolution" \
    "Peer reassessment:" \
    "peer-reassessment-packet"
  require_text "$conflict_resolution" \
    "One challenge, one response, and one reassessment" \
    "peer-challenge-bounded-loop"
  require_text "$conflict_resolution" \
    "REH-n" \
    "peer-challenge-reh-boundary"
  require_text "$review_routing" \
    "provisional side-effect boundary while" \
    "peer-challenge-provisional-boundary"
  forbid_text "$review_routing" \
    "use the stricter verdict" \
    "peer-challenge-no-automatic-verdict"
  require_text "$delegation" \
    "Do not silently discard a material critic, reviewer, or specialist claim" \
    "peer-challenge-parent-accountability"
  require_text "$reviewer_handoff" \
    "When the parent materially disputes a finding" \
    "peer-challenge-reviewer-handoff"
  require_text "$authoring_preflight" \
    "Disputed-finding proof" \
    "peer-challenge-authoring-preflight"
  require_text "$database_reviewer" \
    "The database reviewer retains its verdict" \
    "peer-challenge-database-independence"
  require_text "$database_reviewer" \
    "not refresh an environment or run a database query" \
    "peer-challenge-database-static"
  require_text "$database_closeout" \
    "- Target relevance:" \
    "database-finding-target-relevance"
  require_text "$database_closeout" \
    "- Decision affected:" \
    "database-finding-decision-affected"
  if rg -q -F -- "## Deterministic Route Precedence" "$orchestration"; then
    # The compressed dispatcher makes numbered route precedence authoritative;
    # link placement in later explanatory sections is incidental. Apply this
    # contract to every runtime mirror after the dispatcher is synchronized.
    require_before "$orchestration" \
      "4. **Unclear initial intent" \
      "8. **Material objective" \
      "objective-lock-after-request-intake"
    require_before "$orchestration" \
      "8. **Material objective" \
      "9. **Unapproved proposed direction" \
      "objective-lock-before-idea-challenge"
    require_text "$orchestration" \
      "User-requested action ordering does not reorder applicable pre-route gates." \
      "pre-route-ordering-cannot-bypass-gates"
    require_text "$objective_lock" \
      "blocks idea challenge, critic approval, and authoring until objective-lock resolves it" \
      "unresolved-objective-blocks-solution-work"
    require_text "$objective_lock" \
      "sequencing language alone does not activate" \
      "verified-objective-skips-duplicate-lock"
    require_text "$objective_lock" \
      "response is **lock-only**" \
      "objective-lock-first-response-boundary"
    require_text "$objective_lock" \
      "must not rank, recommend, pressure-test, or characterize" \
      "objective-lock-does-not-invent-policy"
    require_text "$objective_lock" \
      'Every material row must be resolved before `idea-challenge` may begin.' \
      "objective-lock-blocks-challenge-until-resolution"
    require_text "$objective_lock" \
      "Objective-lock first response:" \
      "objective-lock-native-first-response-schema"
    require_text "$objective_lock" \
      "- availability tradeoff: <locked | pending owner | pending evidence>" \
      "objective-lock-native-availability-row"
    require_text "$objective_lock" \
      "- blocked until resolved: idea-challenge, critic, authoring" \
      "objective-lock-native-blocked-row"
    require_text "$objective_lock" \
      "Neutral enumeration" \
      "objective-lock-native-neutral-options"
    require_text "$objective_lock" \
      "Emit the schema below." \
      "objective-lock-schema-required-response"
    require_text "$objective_lock" \
      "exact role unresolved;" \
      "objective-lock-vague-participant-role"
    require_text "$objective_lock" \
      "with no parentheses, examples, alternatives, or inferred roles added." \
      "objective-lock-no-participant-role-expansion"
    forbid_text "$objective_lock" \
      "Options may be enumerated neutrally" \
      "objective-lock-no-option-enumeration"
    require_text "$objective_lock" \
      'First classify relevance as `direct`, `protective`, `contract-changing`, or `unrelated`.' \
      "objective-lock-native-relevance-kernel"
    require_text "$objective_lock" \
      'classify it as speculative or `unrelated` and `defer` or `remove` it with no version bump' \
      "objective-lock-native-mechanism-disposition"
    require_text "$objective_lock" \
      "the causal-evidence field" \
      "objective-lock-native-protective-causal-field"
    require_text "$objective_lock" \
      "the failure is reachable is insufficient" \
      "objective-lock-native-protective-causal-specificity"
    require_text "$objective_lock" \
      'Idea challenge creates `<objective_key>/mechanisms@v1`' \
      "objective-lock-native-version-transition"
    require_text "$objective_lock" \
      "pair and its review history" \
      "objective-lock-native-append-only-history"
    require_text "$objective_lock" \
      "It never waives an independently triggered critic, reviewer or database-reviewer, validation, or publication gate." \
      "objective-lock-native-independent-gates"
    require_text "$objective_lock" \
      "It never waives an independently triggered critic, reviewer or database-reviewer, validation, or publication gate." \
      "objective-lock-native-independent-gate-list"
    require_text "$objective_lock" \
      "When reporting the next route, name those gate classes" \
      "objective-lock-native-independent-gate-output"
    require_text "$objective_lock" \
      "Do not promote optional machinery into an objective change" \
      "objective-lock-native-no-speculative-objective"
    require_text "$objective_lock" \
      "state these five fields explicitly" \
      "objective-lock-native-mechanism-output"
    require_text "$objective_lock" \
      'has disposition `freeze`' \
      "objective-lock-native-freeze-disposition"
    require_text "$objective_lock" \
      "never edits the current ledger" \
      "objective-lock-native-kept-mechanism-version"
    require_text "$objective_lock" \
      'for example `mechanisms@v1` to `mechanisms@v2`' \
      "objective-lock-native-mechanism-increment"
  else
    require_before "$orchestration" \
      "references/request-intake.md" \
      "references/objective-lock.md" \
      "objective-lock-after-request-intake"
    require_before "$orchestration" \
      "references/objective-lock.md" \
      "references/idea-challenge.md" \
      "objective-lock-before-idea-challenge"
  fi
  require_text "$objective_lock" \
    "Preservation authoring decision:" \
    "decision-provenance-output-schema"
  require_text "$objective_lock" \
    "- exact policy conflict:" \
    "decision-provenance-exact-conflict"
  require_text "$objective_lock" \
    "- discoverable facts: <verified evidence | Pending Verification + bounded check>" \
    "decision-provenance-discoverable-facts"
  require_text "$objective_lock" \
    "- residual owner decision: <only behavioral policy evidence cannot select>" \
    "decision-provenance-residual-owner-decision"
    require_text "$objective_lock" \
      "The response ends after the schema or one bounded restatement" \
      "objective-lock-bounded-response-closeout"
  require_text "$objective_lock" \
    "serialize every row; do not replace the schema with" \
    "decision-provenance-every-row-required"
  require_text "$autonomy_envelope" \
    "The envelope is a ceiling, never action authority." \
    "autonomy-readiness-authority-distinction"
  require_text "$objective_lock" \
    "Reused objective lock transition:" \
    "objective-lock-reuse-transition-schema"
  require_text "$objective_lock" \
    "- independently triggered gates preserved: critic; reviewer; database reviewer;" \
    "objective-lock-reuse-preserved-gates"
  require_text "$orchestration" \
    'is explicitly `objective-changing`: hand it one-way to' \
    "scope-delta-objective-changing-one-way"
  require_text "$orchestration" \
    "Current route node:" \
    "lane-journey-current-node-schema"
  require_text "$orchestration" \
    "- expected next owner: <one owner or conditional transition>" \
    "lane-journey-current-node-next-owner"
  require_text "$workflow_contracts" \
    "Kind: defect | feature | maintenance | investigation | operation" \
    "work-item-profile-canonical-kind"
  require_text "$workflow_contracts" \
    "Impact scope: contained | component | service | cross-system | production-wide" \
    "work-item-profile-canonical-impact"
  require_text "$workflow_contracts" \
    "Forecasts do not authorize" \
    "work-item-profile-forecast-boundary"
  require_text "$workflow_contracts" \
    'impact requires at least a `FULL` review forecast' \
    "work-item-profile-production-wide-review"
  require_text "$workflow_contracts" \
    'initiative container`' \
    "work-item-profile-initiative-slicing"
  require_text "$workflow_contracts" \
    "When a material axis changes" \
    "work-item-profile-material-delta"
  require_text "$workflow_contracts" \
    "emit only" \
    "work-item-profile-delta-only"
  require_text "$workflow_contracts" \
    'tokens, values, `=`, or old-to-new pairs' \
    "work-item-profile-unchanged-axis-no-values"
  require_text "$workflow_contracts" \
    "- unchanged axes rechecked, names only and values omitted: <axis name, axis name>" \
    "work-item-profile-unchanged-axis-check"
  require_text "$workflow_contracts" \
    "- validation route change: <proof widened to affected consumers>" \
    "work-item-profile-validation-route-delta"
  require_text "$workflow_contracts" \
    "- database-specialist route change: <required owner or evidenced negative trace>" \
    "work-item-profile-database-specialist-route-delta"
  require_text "$workflow_contracts" \
    "consequences to a shared database" \
    "work-item-profile-shared-database-consequence"
  require_text "$autonomy_envelope" \
    "permitted action = phase authorization intersect active autonomy envelope" \
    "autonomy-authority-intersection"
  require_text "$autonomy_envelope" \
    "acceptance packet required =" \
    "autonomy-action-local-critical-predicate"
  require_text "$autonomy_envelope" \
    "AND critical mutation effect in {direct, predictable}" \
    "autonomy-critical-target-effect-conjunction"
  require_text "$autonomy_envelope" \
    "Classify each action independently." \
    "autonomy-action-local-classification"
  require_text "$autonomy_envelope" \
    "Routine remote collaboration" \
    "autonomy-no-routine-remote-packet"
  require_text "$autonomy_envelope" \
    "A qualifying mutation without" \
    "autonomy-critical-mutation-lifecycle"
  require_text "$autonomy_envelope" \
    "Compare these axes independently" \
    "autonomy-independent-axis-comparison"
  require_text "$autonomy_envelope" \
    "A narrowing may" \
    "autonomy-narrowing-retains-authority"
  require_text "$autonomy_envelope" \
    'themselves justify `READY FOR AUTOPILOT`' \
    "autonomy-no-rollback-not-ready-by-itself"
  require_text "$autonomy_envelope" \
    "execution authority; the post-readiness confirmation" \
    "autonomy-initial-shared-mutation-not-execution-authority"
  require_text "$autonomy_envelope" \
    'rollback is `BLOCKED`.' \
    "autonomy-unknown-rollback-blocked"
  require_text "$autonomy_envelope" \
    'an unbounded ceiling cannot be `READY FOR AUTOPILOT`' \
    "autonomy-unbounded-ceiling-not-ready"
  require_text "$autonomy_envelope" \
    "Independent axis comparison: environment; principal/resource sets; sensitivity;" \
    "autonomy-expansion-axis-output"
  require_text "$autonomy_envelope" \
    "Critical-mutation lifecycle: PRELIMINARY -> APPROVAL REQUIRED -> terminal execution state" \
    "autonomy-critical-lifecycle-output"
  require_text "$autonomy_envelope" \
    "Capability/action evidence map:" \
    "autonomy-capability-action-map"
  require_text "$autonomy_envelope" \
    "Blast radius: <descriptive affected users/data/services/stakeholders and hard scope ceilings>" \
    "autonomy-blast-radius-field"
  require_text "$autonomy_envelope" \
    "Unresolved readiness: <none or exact blocker IDs>" \
    "autonomy-unresolved-readiness-field"
  require_text "$autonomy_envelope" \
    "Risk and blast radius: <exact Risk and Blast radius projection>" \
    "autonomy-card-risk-blast-projection"
  require_text "$autonomy_envelope" \
    "Readiness/access evidence: <exact preflights, action-evidence rows, monitoring, and prerequisites projection>" \
    "autonomy-card-readiness-projection"
  require_text "$autonomy_envelope" \
    "action-id=<owning-gate>|<purpose-rationale>|<capability-integration>|<principal>|" \
    "autonomy-purpose-bearing-evidence-row"
  require_text "$autonomy_envelope" \
    "no unrelated row is allowed" \
    "autonomy-no-unrelated-tool-row"
  require_text "$autonomy_envelope" \
    'Enter `APPROVAL REQUIRED` only when' \
    "autonomy-complete-readiness-before-hold"
  require_text "$autonomy_envelope" \
    'never ask the user to approve an incomplete readiness claim.' \
    "autonomy-no-opaque-readiness-claim"
  require_text "$autonomy_envelope" \
    "Predeclared bounded recovery:" \
    "autonomy-predeclared-recovery-field"
  require_text "$autonomy_envelope" \
    "Shared-environment effect: <none | direct | predictable>" \
    "autonomy-shared-effect-classification"
  require_text "$autonomy_envelope" \
    "A runbook that describes mechanics does not" \
    "autonomy-runbook-not-standing-authority"
  require_text "$autonomy_envelope" \
    "Preserved gates: risk; external boundary; specialist/runbook; prerequisites;" \
    "autonomy-expansion-gate-output"
  require_text "$autonomy_envelope" \
    "Irreversible readiness: explicit classification + current owner terms + all" \
    "autonomy-irreversible-readiness-output"
  require_text "$autonomy_envelope" \
    "Autonomy acceptance card <stable-id>@v<positive-integer>:" \
    "autonomy-lossless-acceptance-card"
  require_text "$autonomy_envelope" \
    "Justification and safer alternative: <accepted-plan/forward-analysis projection>" \
    "autonomy-card-justification-alternative"
  require_text "$autonomy_envelope" \
    "Credible failures and harm signals: <risk-gate projection>" \
    "autonomy-card-failure-harm"
  require_text "$autonomy_envelope" \
    "Irretrievable state and compensation limits: <none or exact no-rollback projection>" \
    "autonomy-card-irretrievable-compensation"
  require_text "$autonomy_envelope" \
    "No-rollback terms: <none | owner-approved; irretrievable=<exact state>;" \
    "autonomy-explicit-no-rollback-terms"
  require_text "$autonomy_envelope" \
    "bounded restoration state != verified" \
    "autonomy-irreversible-activation-branch"
  require_text "$autonomy_envelope" \
    '`Activation` has deterministic precedence.' \
    "autonomy-deterministic-activation-precedence"
  require_text "$autonomy_envelope" \
    'Both `irretrievable` and `compensation` values must be explicit and non-empty.' \
    "autonomy-explicit-no-rollback-values"
  require_text "$autonomy_envelope" \
    "Tool availability alone is not that" \
    "autonomy-approval-capability-not-availability"
  require_text "$autonomy_envelope" \
    "The interactive approval budget is one hold for each stable qualifying" \
    "autonomy-one-approval-budget"
  require_text "$autonomy_envelope" \
    "labels, and prose summaries are presentation only." \
    "autonomy-derived-summary-erratum"
  require_text "$autonomy_envelope" \
    "known and safely reconcilable" \
    "autonomy-bounded-critical-recovery"
  require_text "$autonomy_envelope" \
    "only one changed-variable retry is attempted" \
    "autonomy-bounded-retry"
  require_text "$risk_side_effects" \
    "Blast radius: <descriptive affected users/data/services/stakeholders and hard scope ceilings>" \
    "risk-gate-blast-radius-output"
  require_text "$external_system" \
    "auth/permission state: authorized | unauthorized | partial | unknown | not-required" \
    "external-boundary-auth-state-output"
  require_text "$external_system" \
    "- allowed operations:" \
    "external-boundary-allowed-operations-output"
  require_text "$external_system" \
    "- prohibited operations:" \
    "external-boundary-prohibited-operations-output"
  require_text "$runtime_capability" \
    "Runtime/network/sandbox state:" \
    "runtime-capability-network-state-output"
  require_text "$scope_change" \
    "Predeclared bounded recovery is an in-scope detail" \
    "autonomy-scope-absorbs-bounded-recovery"
  require_text "$execution_recovery" \
    "## Same-Envelope Recovery" \
    "autonomy-recovery-owner"
  require_text "$risk_side_effects" \
    "One interactive approval is the budget for" \
    "autonomy-risk-one-approval-budget"
  require_text "$completion_claim" \
    "repeated approval holds are a workflow defect" \
    "autonomy-completion-rejects-approval-churn"
  require_text "$orchestration" \
    "minimal fail-closed fallback for when that companion cannot load" \
    "orchestration-schema-fallback-kernel"
  require_text "$orchestration" \
    "The envelope is a ceiling, never action authority" \
    "orchestration-autonomy-fallback-authority"
  require_section_text "$orchestration" \
    "Task autonomy envelope" \
    "Orchestration conformance" \
    "permitted action = phase authorization intersect active autonomy envelope" \
    "orchestration-autonomy-fallback-authority-proposition"
  require_section_text "$orchestration" \
    "Task autonomy envelope" \
    "Orchestration conformance" \
    'After `APPROVAL REQUIRED`, only confirmation or verified-standing-authority evidence, latch status, and the resulting `State` may change on the same version' \
    "orchestration-autonomy-fallback-post-hold-allowlist"
  require_text "$orchestration" \
    'The complete readiness vocabulary is `PRELIMINARY`, `APPROVAL REQUIRED`' \
    "orchestration-autonomy-fallback-lifecycle-states"
  require_text "$orchestration" \
    '`READY FOR AUTOPILOT`, `READY WITH CHECKPOINTS`, and `BLOCKED`' \
    "orchestration-autonomy-fallback-terminal-states"
  require_text "$orchestration" \
    'A qualifying version starts `PRELIMINARY` and must pass through' \
    "orchestration-autonomy-confirmation-fallback"
  require_text "$orchestration" \
    "Ordinary commits, pushes and branch updates" \
    "orchestration-no-routine-git-packet"
  require_text "$orchestration" \
    "normal success deploys, migrates, changes traffic" \
    "orchestration-critical-effect-precedence"
  forbid_text "$orchestration" \
    "Autonomy envelope <stable-id>@v<positive-integer>:" \
    "orchestration-no-canonical-autonomy-packet"
  forbid_text "$orchestration" \
    "Work item profile <stable-id>@vN+1 delta:" \
    "orchestration-no-canonical-profile-delta"
  require_text "$conflict_resolution" \
    "One challenge, one response, and one reassessment" \
    "peer-challenge-native-bounded-loop"
  require_text "$conflict_resolution" \
    "No majority vote, agent shopping" \
    "peer-challenge-native-no-voting"
  require_text "$objective_lock" \
    "status: locked | pending owner | pending evidence" \
    "objective-lock-status"
  require_text "$objective_lock" \
    "contract-changing" \
    "objective-lock-four-way-disposition"
  require_text "$objective_lock" \
    "Do not create a retroactive objective lock" \
    "objective-lock-teammate-review-exemption"
  require_text "$objective_lock" \
    "Do not reopen for:" \
    "objective-lock-non-reopen-rules"
  require_text "$objective_lock" \
    "current -> transition -> target, only when phased" \
    "objective-lock-conditional-transition"
  require_text "$objective_lock" \
    "Existing critic and reviewer selection rules remain authoritative" \
    "objective-lock-preserves-existing-gates"
  require_text "$objective_lock" \
    "## Production-Ready Mechanism Scope" \
    "objective-lock-mechanism-scope-owner"
  require_section_text "$objective_lock" \
    "Production-Ready Mechanism Scope" \
    "Relevance Disposition" \
    "current evidence proves the change" \
    "production-ready-scope-objective-protective-path"
  require_text "$objective_lock" \
    "mechanism_scope_key=<objective_key>/mechanisms@v<positive-integer>" \
    "objective-lock-two-version-identity"
  require_text "$objective_lock" \
    'start its mechanism ledger at `v1`' \
    "objective-lock-version-transition"
  require_text "$objective_lock" \
    "## Decision Provenance And Scope Delta" \
    "decision-provenance-objective-owner"
  require_text "$objective_lock" \
    "Artifact-fidelity obligation" \
    "decision-provenance-authority-taxonomy"
  require_text "$objective_lock" \
    "finding a dependency does not authorize a new" \
    "decision-provenance-dependency-boundary"
  require_text "$instruction_maintenance" \
    "semantic fidelity check" \
    "requested-artifact-instruction-maintenance"
  require_text "$instruction_maintenance" \
    "$reviewer_recovery_anchor" \
    "reviewer-recovery-anchor-sha"
  require_text "$instruction_maintenance" \
    "Do not use an unscoped repository-wide" \
    "reviewer-recovery-anchor-bounded-comparison"
  require_text "$instruction_maintenance" \
    "Do not reset, revert, cherry-pick, or copy the anchor wholesale" \
    "reviewer-recovery-anchor-no-wholesale-rollback"
  require_text "$instruction_maintenance" \
    "Restoring fixed background-document or case-study reads requires an" \
    "reviewer-recovery-anchor-owner-only-background-reads"
  require_text "$instruction_maintenance" \
    "user instruction to restore those reads supplies that decision" \
    "reviewer-recovery-anchor-explicit-restoration-authority"
  require_text "$instruction_authoring" \
    "## Requested Artifact Fidelity" \
    "requested-artifact-author-time-owner"
  require_text "$instruction_authoring" \
    "do not make a polished substitute durable" \
    "requested-artifact-no-policy-substitute"
  require_text "$impact_source_map" \
    "## Capability, Configuration, And Observation Gate" \
    "missing-behavior-four-layer-gate"
  require_text "$impact_source_map" \
    "Disabled or incompletely configured capability is not missing code" \
    "missing-behavior-disabled-capability"
  require_text "$docs_operator_truth" \
    "semantically substituted requested artifact" \
    "requested-artifact-documentation-defect"
  require_text "$authoring_preflight" \
    "Requested plan and policy artifacts need semantic acceptance proof" \
    "requested-artifact-final-proof"
  require_text "$pre_code_critic" \
    "applicable authority states" \
    "decision-provenance-critic-transport"
  require_text "$request_intake" \
    "The objective produced here is provisional" \
    "request-intake-objective-handoff"
  require_text "$idea_challenge" \
    "## Objective-Lock Prerequisite" \
    "idea-challenge-objective-lock-consumer"
  require_file "$forward_analysis" \
    "forward-analysis-native-reference"
  require_file "$planning_philosophy" \
    "planning-philosophy-native-reference"
  require_text "$planning_philosophy" \
    "Type: companion contract" \
    "planning-philosophy-companion-owner"
  require_text "$planning_philosophy" \
    "When forward analysis is active, it consumes this companion once" \
    "planning-philosophy-single-consumption"
  require_text "$planning_philosophy" \
    "Inactive use adds no" \
    "planning-philosophy-silent-bypass"
  require_text "$planning_philosophy" \
    "Test one mechanism suggested by the live decision's structure" \
    "planning-philosophy-one-mechanism-default"
  require_text "$planning_philosophy" \
    "Use a second mechanism only when current evidence shows" \
    "planning-philosophy-causal-coupling-exception"
  require_text "$planning_philosophy" \
    "Find the structure before the principle" \
    "planning-philosophy-structure-before-principle"
  require_text "$planning_philosophy" \
    "A transfer's usable authority is the weakest link" \
    "planning-philosophy-weakest-link-authority"
  require_text "$planning_philosophy" \
    "which substrate could falsify the claim" \
    "planning-philosophy-substrate-boundary"
  require_text "$planning_philosophy" \
    "Run the deletion test" \
    "planning-philosophy-deletion-test"
  require_text "$planning_philosophy" \
    "A planned test is not itself a falsifier" \
    "planning-philosophy-observable-falsifier"
  require_text "$planning_philosophy" \
    "External research is conditional" \
    "planning-philosophy-no-forced-research"
  require_text "$planning_philosophy" \
    'Do not add a `Philosophy`, `Lenses`,' \
    "planning-philosophy-existing-output-only"
  require_text "$planning_philosophy" \
    "If no decision changed, do not claim" \
    "planning-philosophy-no-invented-influence"
  require_text "$planning_philosophy" \
    '`Planning philosophy influence:`' \
    "planning-philosophy-stable-influence-prefix"
  require_text "$planning_philosophy" \
    "When a forward-analysis record owns the output" \
    "planning-philosophy-influence-inside-record"
  require_text "$planning_philosophy" \
    "final record field the final bytes" \
    "planning-philosophy-record-is-terminal"
  require_text "$planning_philosophy" \
    "satisfy both output obligations" \
    "planning-philosophy-influence-and-terminal-record-paired"
  require_text "$planning_philosophy" \
    "## Epistemic Weight" \
    "planning-philosophy-epistemic-weight"
  require_text "$planning_philosophy" \
    "Do not traverse the router as a checklist" \
    "planning-philosophy-router-not-checklist"
  require_text "$planning_philosophy" \
    "Before assuming code is the answer" \
    "planning-philosophy-no-code-alternatives"
  require_text "$planning_philosophy" \
    "who pays when the choice fails" \
    "planning-philosophy-shifted-cost-payer"
  require_text "$planning_philosophy" \
    "capacity, variability, feedback, delay, thresholds, and saturation" \
    "planning-philosophy-feedback-saturation-family"
  require_text "$planning_philosophy" \
    "evidence that it reduces that failure relative to a simpler existing control" \
    "planning-philosophy-redundancy-comparative-admission"
  require_text "$planning_philosophy" \
    "proxy alignment, missing populations, incentives, and externalities" \
    "planning-philosophy-adaptive-incentive-family"
  require_text "$planning_philosophy" \
    "information loss, option value, carrying cost, and expiry" \
    "planning-philosophy-irreversibility-option-family"
  require_text "$planning_philosophy" \
    "serial fraction, information locality, decision rights" \
    "planning-philosophy-decomposition-ownership-family"
  require_text "$planning_philosophy" \
    "each actor's signal, action, timescale, bound, shared resource or state" \
    "planning-philosophy-multi-actor-inventory"
  require_text "$planning_philosophy" \
    "one owner for the combined decision" \
    "planning-philosophy-multi-actor-owner"
  require_text "$planning_philosophy" \
    "no oscillation or load amplification and measurably faster recovery" \
    "planning-philosophy-multi-actor-falsifier"
  require_text "$planning_philosophy" \
    "request calls for ordinary engineering language" \
    "planning-philosophy-ordinary-output-shape"
  require_text "$planning_philosophy" \
    "Authority, blast radius, accountability, containment, readback, and recovery" \
    "planning-philosophy-authority-family"
  require_text "$planning_philosophy" \
    "structural repair versus symptomatic containment" \
    "planning-philosophy-structural-fix-versus-containment"
  require_text "$planning_philosophy" \
    "open-loop versus closed-loop action" \
    "planning-philosophy-open-versus-closed-loop"
  require_text "$planning_philosophy" \
    "observed exit from the degraded state" \
    "planning-philosophy-degraded-state-exit"
  require_text "$planning_philosophy" \
    "Missing population" \
    "planning-philosophy-missing-population"
  require_text "$planning_philosophy" \
    "Common cause" \
    "planning-philosophy-common-cause"
  require_text "$planning_philosophy" \
    "Do not invent universal numeric thresholds" \
    "planning-philosophy-threshold-local-evidence"
  require_text "$planning_philosophy" \
    'decision to `objective-lock` and the accountable owner' \
    "planning-philosophy-owner-return"
  require_text "$planning_philosophy" \
    "## Worked Transfers" \
    "planning-philosophy-worked-transfers"
  require_text "$planning_philosophy" \
    "Example names are editorial and replaceable" \
    "planning-philosophy-replaceable-examples"
  require_occurrence_count 4 \
    "### Worked transfer:" \
    "planning-philosophy-four-worked-transfers" \
    "$planning_philosophy"
  for planning_transfer_field in \
    "**Starting decision.**" \
    "**Mechanism.**" \
    "**Rival.**" \
    "**Decision delta.**" \
    "**Reversal evidence.**"; do
    require_occurrence_count 4 \
      "$planning_transfer_field" \
      "planning-philosophy-worked-transfer-field" \
      "$planning_philosophy"
  done
  for planning_card_index in {1..8}; do
    forbid_text "$planning_philosophy" \
      "### W${planning_card_index}:" \
      "planning-philosophy-no-lettered-card-catalogue"
  done
  forbid_text "$planning_philosophy" \
    "## Principles In Tension" \
    "planning-philosophy-no-tension-table-retrieval-surface"
  planning_philosophy_lines="$(wc -l < "$planning_philosophy")"
  planning_philosophy_words="$(wc -w < "$planning_philosophy")"
  if (( planning_philosophy_lines > 320 || planning_philosophy_words > 3000 )); then
    echo "workflow contract failed [planning-philosophy-editorial-budget]: $planning_philosophy has ${planning_philosophy_lines} lines and ${planning_philosophy_words} words" >&2
    exit 1
  fi
  forbid_text "$planning_philosophy" \
    "docs/programming-idioms" \
    "planning-philosophy-no-doc-runtime-dependency"
  forbid_text "$planning_philosophy" \
    "tmp/programming-idioms" \
    "planning-philosophy-no-tmp-runtime-dependency"
  require_text docs/agents/instruction-preservation-ledger.md \
    'Instruction preservation row `planning-philosophy-two-to-four-selection-retirement`:' \
    "planning-philosophy-selection-preservation-row"
  require_text docs/agents/instruction-preservation-ledger.md \
    'Instruction preservation row `planning-philosophy-stop-rules`:' \
    "planning-philosophy-stop-preservation-row"
  require_text "$idea_challenge" \
    "[planning-philosophy.md](planning-philosophy.md) once" \
    "planning-philosophy-idea-consumer"
  require_text "$forward_analysis" \
    "[planning-philosophy.md](planning-philosophy.md) once inside this analysis" \
    "planning-philosophy-forward-consumer"
  require_text "$orchestration" \
    "[planning-philosophy](references/planning-philosophy.md)" \
    "planning-philosophy-kernel-route"
  require_text "$orchestration" \
    "bypass it without a read or skip receipt" \
    "planning-philosophy-kernel-bypass"
  require_text "$orchestration" \
    'include the `Planning philosophy influence:` sentence inside this field' \
    "planning-philosophy-kernel-record-placement"
  require_text "$forward_analysis" \
    "never append it after the record" \
    "planning-philosophy-forward-record-placement"
  require_text "$forward_analysis" \
    "This is a decision contract, not a new lane, acknowledgement, raw-reasoning" \
    "forward-analysis-no-new-ceremony"
  require_text "$forward_analysis" \
    "Never request or include hidden" \
    "forward-analysis-no-raw-reasoning"
  require_text "$forward_analysis" \
    "## Decision Contract" \
    "forward-analysis-decision-contract"
  require_text "$forward_analysis" \
    "## Stop Rules" \
    "forward-analysis-stop-rules"
  require_text "$forward_analysis" \
    "next two or three known material consumers" \
    "forward-analysis-bounded-consumers"
  require_text "$forward_analysis" \
    'not an "evidence PR" or gap-closing PR' \
    "forward-analysis-evidence-before-pr"
  require_text "$orchestration" \
    "The eager kernel is mandatory even when the runtime cannot load the linked" \
    "forward-analysis-eager-kernel"
  require_text "$orchestration" \
    "Forward-analysis decision record:" \
    "forward-analysis-output-schema"
  require_text "$orchestration" \
    "An unblock or readiness claim about an unchanged owner-approved behavioral" \
    "forward-analysis-readiness-is-not-objective-change"
  require_text "$orchestration" \
    "do not activate objective-lock solely because the team proposes" \
    "forward-analysis-readiness-does-not-overactivate-objective-lock"
  require_text "$orchestration" \
    "- Next consumers: <two or three consumer -> acceptance, proof, blocker rows>" \
    "forward-analysis-next-consumers-output"
  require_text "$forward_analysis" \
    "bounded read-only evidence can" \
    "forward-analysis-read-only-next-action"
  require_text "$orchestration" \
    "gap-closing PR as" \
    "forward-analysis-no-evidence-pr"
  require_text "$forward_analysis" \
    "they do not approve the parent workflow's broader unblock claim" \
    "forward-analysis-database-boundary"
  require_text "$forward_analysis" \
    "## One-Pass Transport" \
    "forward-analysis-one-pass-transport"
  require_text "$forward_analysis" \
    "<action-item-id>/forward-analysis@v<positive-integer>" \
    "forward-analysis-record-version"
  require_text "$forward_analysis" \
    "Content provenance is optional" \
    "forward-analysis-optional-content-provenance"
  require_text "$forward_analysis" \
    'sha256:<64-hex-characters>' \
    "forward-analysis-valid-optional-digest"
  require_text "$forward_analysis" \
    "Omit the provenance row entirely" \
    "forward-analysis-omit-unavailable-digest"
  require_text "$forward_analysis" \
    "A present digest is non-authoritative provenance only" \
    "forward-analysis-digest-non-authoritative"
  require_text "$forward_analysis" \
    'Never emit `pending`, `Pending' \
    "forward-analysis-no-placeholder-digest"
  forbid_text "$forward_analysis" \
    "Content identity:" \
    "forward-analysis-no-required-identity-row"
  forbid_text "$orchestration" \
    "Record and content identity:" \
    "forward-analysis-kernel-no-required-identity"
  require_text "$forward_analysis" \
    "Cross-session worker transport includes the exact complete record" \
    "forward-analysis-exact-worker-transport"
  require_text "$forward_analysis" \
    "same-session consumer may use a reference only when it can currently" \
    "forward-analysis-verified-same-session-reference"
  require_text "$forward_analysis" \
    "show the complete record to the" \
    "forward-analysis-one-visible-record"
  require_text "$forward_analysis" \
    "header appears exactly once" \
    "forward-analysis-single-physical-serialization"
  require_text "$forward_analysis" \
    "Choose one serialization owner before drafting user-visible decision content" \
    "forward-analysis-single-serialization-owner"
  require_text "$forward_analysis" \
    "new-session worker assignment" \
    "forward-analysis-handoff-owns-user-visible-record"
  require_text "$forward_analysis" \
    "it must not draft decision-record fields" \
    "forward-analysis-no-preliminary-record-draft"
  require_text "$forward_analysis" \
    "Do not emit a standalone idea-challenge packet" \
    "forward-analysis-no-competing-output-envelope"
  require_text "$forward_analysis" \
    "Challenge these conclusions; do not treat the parent result as proof" \
    "forward-analysis-downstream-non-proof"
  require_text "$forward_analysis" \
    "- Strongest counterargument and challenge targets:" \
    "forward-analysis-challenge-target"
  require_text "$forward_analysis" \
    "- Invalidation and reopen conditions:" \
    "forward-analysis-invalidation"
  require_text "$idea_challenge" \
    "## Forward-Analysis Decision" \
    "forward-analysis-earliest-owner"
  require_text "$idea_challenge" \
    "Record that result once" \
    "forward-analysis-idea-one-pass"
  require_text "$idea_challenge" \
    "A cross-session critic brief carries the" \
    "forward-analysis-idea-compact-critic-transport"
  require_text "$idea_challenge" \
    "Do not attach a second full forward-analysis" \
    "forward-analysis-idea-no-second-packet"
  require_text "$orchestration" \
    "carries its ID/version and decision-changing conclusions" \
    "forward-analysis-kernel-compact-critic-transport"
  require_text "$orchestration_conformance" \
    "forward analysis: <not triggered with evidence | record ID/version | blocked>" \
    "forward-analysis-conformance-decision-reference"
  forbid_text "$orchestration_conformance" \
    "content identity=<digest>" \
    "forward-analysis-conformance-no-digest-prerequisite"
  require_text "$workflow_synthesis" \
    "existing [forward-analysis result](forward-analysis.md)" \
    "forward-analysis-workflow-synthesis-consumer"
  require_text "$pre_code_critic" \
    "When forward analysis was triggered, carry its decision-changing conclusions" \
    "forward-analysis-critic-transport"
  forbid_text "$pre_code_critic" \
    "ID/version/content identity" \
    "forward-analysis-critic-no-digest-prerequisite"
  require_text "$pre_code_critic" \
    "Do not reproduce an unchanged full record" \
    "forward-analysis-no-second-critic-ceremony"
  require_text "$change_intake" \
    "decision-changing conclusions needed for the candidate" \
    "forward-analysis-authoring-semantic-input"
  forbid_text "$change_intake" \
    "identity=<digest>" \
    "forward-analysis-authoring-no-digest-prerequisite"
  forbid_text "$change_intake" \
    "complete, audit=<current-problem evidence, alternatives, next-consumer acceptance, smallest slice>" \
    "forward-analysis-retired-audit-summary"
  require_text "$workflow_contracts" \
    "Objective-lock status:" \
    "workflow-contract-objective-lock"
  require_text "$reviewer_handoff" \
    "Do not impose a retroactive objective lock" \
    "reviewer-handoff-teammate-exemption"
  require_text "$change_intake" \
    "objective lock: not required" \
    "authoring-intake-objective-lock"
  require_text "$change_intake" \
    "## Objective Conformance Intake" \
    "objective-conformance-intake-owner"
  require_text "$change_intake" \
    "sole pre-edit owner" \
    "objective-conformance-single-author-owner"
  require_text "$change_intake" \
    "Classify each proposed mechanism using the active objective lock" \
    "objective-conformance-intake-disposition"
  require_text "$authoring_core" \
    "## Objective Conformance Consumption" \
    "objective-conformance-author-consumer"
  require_text "$authoring_core" \
    "Implement only mechanisms classified" \
    "objective-conformance-author-bounded-mechanisms"
  require_text "$pre_code_critic" \
    "objective lock: <not required | lock-id@version>" \
    "pre-code-critic-objective-lock"
  require_text "$authoring_preflight" \
    "## Objective-Lock Conformance Proof" \
    "authoring-objective-lock-conformance"
  require_text "$idea_challenge" \
    "## Production-Ready Scope Challenge" \
    "production-ready-scope-idea-activation"
  require_text "$idea_challenge" \
    "require an active objective key" \
    "production-ready-scope-objective-prerequisite"
  require_section_text "$idea_challenge" \
    "Production-Ready Scope Challenge" \
    "Critic Escalation" \
    "named protected invariant" \
    "production-ready-scope-idea-protective-path"
  require_section_text "$idea_challenge" \
    "Production-Ready Scope Challenge" \
    "Critic Escalation" \
    "current evidence proves the change" \
    "production-ready-scope-idea-causal-evidence"
  require_text "$authoring_core" \
    "## Production-Ready Scope Lock" \
    "production-ready-scope-author-lock"
  require_text "$authoring_core" \
    "deferred lifecycle mechanisms" \
    "production-ready-scope-author-decision"
  require_text "$authoring_core" \
    "<objective_key>/mechanisms@v<version>" \
    "production-ready-scope-author-subordinate-key"
  require_text "$authoring_preflight" \
    "## Production-Ready Scope-Growth Proof" \
    "production-ready-scope-growth-proof"
  require_section_text "$authoring_preflight" \
    "Production-Ready Scope-Growth Proof" \
    "Objective-Lock Conformance Proof" \
    "current evidence proves the change" \
    "production-ready-scope-growth-protective-path"
  require_text "$authoring_preflight" \
    'mechanism revision and return to `objective-lock`' \
    "production-ready-scope-objective-reopen"
  require_text "$reviewer_bootstrap" \
    "## Task-Time Direction And Necessity Contracts" \
    "production-ready-scope-review-bootstrap"
  require_text "$reviewer_bootstrap" \
    "speculative mechanisms" \
    "production-ready-scope-review-agreement"
  require_text "$reviewer_bootstrap" \
    "../../work-orchestration/references/forward-analysis.md" \
    "forward-analysis-reviewer-native-reference"
  require_section_text "$reviewer_bootstrap" \
    "Task-Time Direction And Necessity Contracts" \
    "Parent Inputs Versus Reviewer Evidence" \
    "current evidence proves the change" \
    "production-ready-scope-reviewer-protective-path"
  require_text "$reviewer_bootstrap" \
    "artifact-fidelity obligation" \
    "decision-provenance-review-bootstrap"
  require_text "$reviewer_bootstrap" \
    "Disabled capability is not missing code" \
    "missing-behavior-review-bootstrap"
  require_text "$reviewer_bootstrap" \
    'activate `review-intent-understanding-lens.md` for objective' \
    "objective-conformance-reviewer-activation"
  require_text "$reviewer_intent" \
    "## Objective Conformance" \
    "objective-conformance-review-intent-owner"
  require_text "$reviewer_intent" \
    "Do not manufacture a retroactive objective lock" \
    "objective-conformance-teammate-pr-boundary"
  require_text "$authoring" \
    "next consumer's acceptance rules" \
    "forward-analysis-authoring-contract"
  require_text "$authoring" \
    "../work-orchestration/references/forward-analysis.md" \
    "forward-analysis-authoring-native-reference"
  require_file "$case_study_transfer" \
    "case-study-transfer-preflight-reference"
  require_text "$authoring" \
    "references/case-study-transfer-preflight.md" \
    "case-study-transfer-preflight-routing"
  require_text "$authoring" \
    "case-study transfer preflight: not triggered | pending | complete" \
    "case-study-transfer-entry-audit"
  require_text "$change_intake" \
    "case-study transfer preflight: not triggered | pending | complete" \
    "case-study-transfer-intake-audit"
  require_text "$case_study_transfer" \
    "this authoring session performs its first target-specific evidence action" \
    "case-study-transfer-evidence-boundary"
  require_text "$case_study_transfer" \
    "Maximum three commitments total" \
    "case-study-transfer-bounded-recall"
  require_text "$case_study_transfer" \
    "Freeze each initial row before target evidence" \
    "case-study-transfer-immutable-beginning"
  require_text "$case_study_transfer" \
    "No new commitment IDs are allowed" \
    "case-study-transfer-prospective-closeout"
  require_text "$case_study_transfer" \
    "prepend or append the transfer trace to a" \
    "case-study-transfer-packet-boundary"
  require_text "$case_study_transfer" \
    "Optional narrative case studies" \
    "case-study-transfer-optional-narrative-boundary"
  if rg -qi -- 'mantra|chant|religious|religion' "$case_study_transfer"; then
    echo "workflow contract failed [case-study-transfer-neutral-language]: religious metaphor leaked into $case_study_transfer" >&2
    exit 1
  fi
  require_section_text "$authoring_core" \
    "Production-Ready Scope Lock" \
    "Context Discipline" \
    "current evidence proves the change" \
    "production-ready-scope-author-protective-path"
  require_text "$database_reviewer" \
    "## Production-Ready Scope Necessity Gate" \
    "production-ready-scope-database-necessity"
  require_text "$database_reviewer" \
    "task-specific necessity decision is the gate" \
    "production-ready-scope-database-decision"
  require_section_text "$database_reviewer" \
    "Production-Ready Scope Necessity Gate" \
    "Parent-supplied environment evidence" \
    "current evidence" \
    "production-ready-scope-database-protective-path"
  require_text "$review_worktree" \
    "production-ready scope contracts are not added to this" \
    "forward-analysis-review-packet-exclusion"
  forbid_text "$review_worktree" \
    "optional production-ready scope narrative" \
    "production-ready-scope-no-pr-narrative-dependency"
  require_text "$reviewer_handoff" \
    "mandatory instructions are complete" \
    "reviewer-handoff-mandatory-instruction-closure"
  require_section_text "$reviewer_handoff" \
    "Targeted follow-up circuit breaker" \
    "Scoped re-review provenance addendum" \
    "named invariant and current causal evidence" \
    "production-ready-scope-review-circuit-protective-path"
  forbid_text "$authoring_preflight" \
    "Consult the production-ready scope case study" \
    "production-ready-scope-no-preflight-narrative-dependency"
  forbid_text "$authoring_preflight" \
    "approve unsupported mechanisms only inside" \
    "production-ready-scope-no-unmapped-scope-approval"
  forbid_text "$reviewer_handoff" \
    "production-ready scope case study is optional incident context" \
    "production-ready-scope-no-handoff-narrative-dependency"
  require_text "$database_reviewer" \
    "return that classification to the parent" \
    "database-review-target-change-classification"
  forbid_text "$database_reviewer" \
    "approve the parent workflow's broader unblock claim" \
    "forward-analysis-database-non-consumer"
  forbid_text "$database_reviewer" \
    "discard target-dependent conclusions and review the new target" \
    "database-review-no-unconditional-rereview"
  require_text "$authoring_preflight" \
    "explicitly zero" \
    "authoring-config-presence-boundary"
  require_text "$authoring_preflight" \
    "multiple physical source rows" \
    "authoring-sql-cardinality-boundary"
  require_text "$authoring_preflight" \
    "fresh narrow" \
    "authoring-cleanup-context-boundary"
  require_file "$author_self_review" "author-self-review-reference"
  require_text "$authoring" \
    "references/author-self-review.md" \
    "author-self-review-routing"
  require_text "$author_self_review" \
    "records only what changed" \
    "author-self-review-delta-only"
  require_text "$author_self_review" \
    "review of a teammate's PR" \
    "author-self-review-exclusions"
  require_text "$author_self_review" \
    "user-assigned direct review of a local diff" \
    "author-self-review-direct-review-exclusion"
  require_text "$author_self_review" \
    "local-only micro-edit" \
    "author-self-review-micro-edit-exclusion"
  require_text "$author_self_review" \
    "When excluded, record only" \
    "author-self-review-compact-exclusion"
  require_text "$author_self_review" \
    "finding-directed post-review re-review" \
    "author-self-review-exclusions"
  require_text "$author_self_review" \
    "strengthened Review-fix proof" \
    "author-self-review-review-fix-owner"
  require_text "$authoring_preflight" \
    "bounded impact cone through sibling code paths" \
    "review-fix-bounded-impact-cone"
  require_text "$authoring_preflight" \
    "meaningful stable seam exists" \
    "review-fix-proportional-test-proof"
  require_text "$authoring_preflight" \
    "finding has a disposition and proof record" \
    "review-fix-complete-batch"
  require_text "$authoring_preflight" \
    "green while the defect exists" \
    "changed-boundary-wrong-green-counterexample"
  require_text "$authoring_preflight" \
    "complete disposition ledger for every material self-check candidate" \
    "self-check-complete-disposition-ledger"
  require_text "$authoring_preflight" \
    "overflow count" \
    "self-check-overflow-visible"
  require_text "$author_self_review" \
    "Do not enter reviewer bootstrap" \
    "author-self-review-not-verdict"
  require_text "$author_self_review" \
    "affected authoring handoff or preflight rows" \
    "author-self-review-fix-recompute"
  require_text "$author_self_review" \
    "Carry its complete tri-state packet into this delta" \
    "author-self-review-conditional-database"
  require_text "$author_self_review" \
    "replace the independent database-reviewer sibling" \
    "author-self-review-preserves-database-gate"
  require_text "$author_self_review" \
    "it never delays the ordinary reviewer" \
    "author-self-review-ordinary-review-independence"
  require_text "$publish_pr" \
    "database applicability packet before the first" \
    "publish-pr-database-applicability-gate"
  require_text "$reviewer_handoff" \
    "This skip never applies to a" \
    "review-handoff-database-non-waiver"
  require_file "$review_control" \
    "review-control-plane-canonical-owner"
  require_text "$review_control" \
    "This companion defines vocabulary and transition law only" \
    "review-control-plane-owner-boundary"
  require_text "$review_control" \
    "## Reviewer-Active Semantic Ownership" \
    "review-control-plane-active-ownership"
  require_text "$review_control" \
    "bounded by both purpose and effect" \
    "review-control-plane-allowlist-containment"
  require_text "$review_control" \
    "whether described as a whole review, partial" \
    "review-control-plane-no-relabeled-semantic-work"
  require_text "$review_control" \
    "the parent waits" \
    "review-control-plane-wait-is-work"
  require_text "$review_control" \
    "analysis cannot satisfy or waive either mandatory reviewer" \
    "review-control-plane-mandatory-reviewer-nonwaiver"
  require_text "$delegation" \
    "## Native reviewer control-plane override" \
    "delegation-native-reviewer-override"
  require_text "$delegation" \
    "generic spot checks, caller or contract verification" \
    "delegation-no-review-takeover"
  require_text "$reviewer_handoff" \
    "Successful ordinary or database reviewer dispatch activates the internal" \
    "review-handoff-active-lifecycle"
  require_text "$reviewer_handoff" \
    "partial, supporting, spot-check, or relabeled semantic review" \
    "review-handoff-no-relabeled-semantic-work"
  require_text "$orchestration" \
    "Successful dispatch makes reviewer waiting and" \
    "orchestration-reviewer-wait-critical-path"
  require_text "$orchestration" \
    "whole, partial, supporting, spot-check, or" \
    "orchestration-no-relabeled-semantic-work"
  require_text "$review_worktree" \
    "Successful native-reviewer dispatch activates the internal" \
    "pr-review-active-lifecycle"
  require_text "$review_worktree" \
    "Parent analysis never" \
    "pr-review-mandatory-reviewer-nonwaiver"
  require_text "$review_control" \
    "Scope control occurs after target and inventory admission" \
    "review-control-plane-separate-message"
  require_text "$review_control" \
    "The same reviewer owns the" \
    "review-control-plane-reviewer-owned-dispute"
  require_text "$review_control" \
    "After acceptance, depth is monotonic" \
    "review-control-plane-monotonic-depth"
  require_text "$review_control" \
    "\`senior_pr_owner_whole_target\` to \`FULL\`" \
    "review-control-plane-senior-owner-full-floor"
  require_text "$review_control" \
    "initial topology remains \`single\`" \
    "review-control-plane-senior-owner-single-topology"
  require_text "$review_control" \
    "Generic deep or thorough wording outside the qualifying owning" \
    "review-control-plane-generic-thoroughness-nontrigger"
  require_text "$review_control" \
    "Emit one control response for each transition" \
    "review-control-plane-single-response"
  require_text "$review_control" \
    "Use evidence-resolution language between peer owners" \
    "review-control-plane-peer-language"
  require_text "$review_control" \
    "\`topology: council\` projects \`Review mode: COUNCIL\`" \
    "review-control-plane-depth-topology-projection"
  require_text "$review_control" \
    "JOIN_READY_WITH_CAVEATS" \
    "review-control-plane-lossless-caveat"
  require_text "$review_control" \
    "any \`INPUT\` -> \`JOIN_NEEDS_INPUT\`" \
    "review-control-plane-lossless-join"
  require_text "$review_control" \
    "retained state separately for every required sibling" \
    "review-control-plane-per-sibling-join-serialization"
  require_text "$review_control" \
    "make each sibling's verdict and gap independently recoverable" \
    "review-control-plane-no-generic-plural-preservation"
  require_text "$review_control" \
    "No join category authorizes merge" \
    "review-control-plane-no-action-authority"
  require_text "$orchestration" \
    "mean the broader review automatically proceeds" \
    "review-control-plane-dispute-stops-analysis"
  require_text "$reviewer_handoff" \
    "review scope proposal:" \
    "review-handoff-scope-control-transport"
  require_text "$reviewer_handoff" \
    "The scope proposal is assignment control, not a final verdict-packet field" \
    "review-handoff-scope-control-separation"
  require_text "$review_worktree" \
    "compute the lossless parent-only" \
    "pr-review-control-plane-join"
  require_text "$pr_workflow" \
    "senior_pr_owner_whole_target\` mandatory floor at \`FULL\` depth and \`single\`" \
    "pr-workflow-senior-owner-full-floor"
  require_text "$pr_workflow" \
    "It does not activate for a PR summary" \
    "pr-workflow-senior-owner-floor-exclusions"
  require_text "$review_worktree" \
    "mandatory floors: senior_pr_owner_whole_target" \
    "pr-review-worktree-senior-owner-floor-transport"
  require_text "$review_worktree" \
    "Do not normalize a material" \
    "pr-review-control-plane-conflict-route"
  forbid_text "$review_worktree" \
    "use the stricter verdict" \
    "pr-review-control-plane-no-stricter-normalization"
  require_text "$re_review" \
    "Use the shared \`readback\`, \`targeted\`, \`broad\`, and \`blocked\` vocabulary" \
    "re-review-control-plane-classification"
  require_text "$reviewer" \
    "## Shared Scope Control" \
    "ordinary-reviewer-scope-control"
  require_text "$database_reviewer" \
    "## Shared Scope Control" \
    "database-reviewer-scope-control"
  require_text "$database_closeout" \
    "must not appear as a field, prefix, suffix, or section" \
    "database-packet-scope-control-separation"
  require_text "$review_routing" \
    "database review applicability:" \
    "review-routing-database-applicability"
  require_text "$author_self_review" \
    "zero-history isolation" \
    "author-self-review-zero-history"
  require_text "$author_self_review" \
    'fork_turns="none"' \
    "author-self-review-codex-zero-history-control"
  require_text "$author_self_review" \
    "attached or generated context files and handoff artifacts" \
    "author-self-review-all-context-isolation"
  require_text "$author_self_review" \
    "context-contaminated" \
    "author-self-review-contamination-fail-closed"
  require_text "$reviewer_handoff" \
    "freshness requires isolation across every reviewer-visible input" \
    "fresh-reviewer-all-context-isolation"
  require_text "$reviewer_handoff" \
    "reviewer context isolation:" \
    "fresh-reviewer-isolation-packet"
  require_text "$reviewer_handoff" \
    "reused: provenance-bound context" \
    "reused-reviewer-isolation-packet"
  require_text "$reviewer_analysis" \
    "reconstruct the applicable changed-boundary rows" \
    "reviewer-independent-changed-boundary-reconstruction"
  require_text "$reviewer_analysis" \
    "logical key versus physical multiplicity" \
    "reviewer-sql-cardinality-boundary"
  require_text "$reviewer_analysis" \
    "active, canceled, and expired parent contexts" \
    "reviewer-cleanup-context-boundary"
  require_text "$publish_pr" \
    "Copilot and other paid or slow AI reviewers are optional external escape" \
    "copilot-optional-escape-audit"
  require_text "$improve" \
    "canonical durable \`plan_root\` is" \
    "improve-durable-plan-root"
  require_text "$improve" \
    "\`advisor-plans/\`" \
    "improve-durable-plan-root"
  require_text "$improve" \
    "local-only, non-durable" \
    "improve-local-scratch-explicit"
  require_text "$improve_audit" \
    "Do not promise fixed worker counts" \
    "improve-capacity-aware-delegation"
  require_text "$improve_execute" \
    "Re-enter \`work-orchestration\`" \
    "improve-repo-native-execution"
  require_text "$improve_execute" \
    "\`code-authoring\` owns implementation" \
    "improve-repo-native-execution"
  require_text "$improve_execute" \
    "\`worktree-readiness\` owns isolated worktree" \
    "improve-repo-native-execution"
  require_text "$improve_execute" \
    "\`reviewer\` owns the stable-diff formal verdict" \
    "improve-repo-native-execution"
  require_text "$improve" \
    "Only the advisor or orchestrating parent updates the plan index" \
    "improve-parent-index-owner"
  require_text "$improve_template" \
    "Do not update the plan index" \
    "improve-executor-index-exclusion"
  require_text "$improve_issues" \
    "use \`github-workflow\`" \
    "improve-issue-publication-boundary"

  require_text "$orchestration" \
    "one bounded local repo lookup" \
    "bounded-fresh-local-fast-exit"
  require_text "$orchestration" \
    "Every non-fast-exit task uses the complete receipt" \
    "observable-work-ownership"
  require_text "$orchestration" \
    "Work ownership: <parent-only: reason|delegation pending|mixed: see Dispatch>" \
    "observable-work-ownership"
  require_text "$orchestration" \
    'begins as `delegation pending` only while a required gate' \
    "ownership-pending-before-discovery"
  require_text "$orchestration" \
    '`parent-only: <reason>` or `mixed: see Dispatch` before a spawn' \
    "ownership-pending-before-discovery"
  require_text "$orchestration" \
    "consider decomposition before" \
    "ownership-pending-before-discovery"
  require_text "$orchestration" \
    "possible work units or a parent-owned integration or join" \
    "early-delegation-agents-trigger"
  require_text "$delegation" \
    "possible work units or a parent-owned integration/join" \
    "delegation-lane-agents-trigger"
  require_text "$orchestration" \
    "Specialist routing alone does not change work ownership." \
    "ownership-separate-from-routing"
  require_text "$orchestration" \
    'phase starts `parent-only: narrower specialist excludes delegation`' \
    "specialist-exclusion-ownership"
  require_text "$orchestration" \
    'no Dispatch packet' \
    "specialist-exclusion-ownership"
  require_text "$orchestration" \
    "owns each subordinate contract" \
    "dispatch-single-detail-owner"
  require_text "$orchestration" \
    "authoritative ordering for applicable pre-route gates" \
    "planning-preflight-single-precedence-owner"
  forbid_text "$orchestration" \
    "Dispatch Order At A Glance" \
    "no-duplicate-dispatch-order-authority"
  require_text "$orchestration" \
    "Urgency is a prioritization input, not authorization or a gate waiver" \
    "urgency-does-not-waive-gates"
  require_text "$orchestration" \
    "A proactive context-pressure checkpoint never creates filesystem-write" \
    "context-pressure-no-write-authority"
  require_text "$orchestration" \
    "specialist-less grounded repo explanation" \
    "specialist-less-explanation-routing"
  require_text "$orchestration" \
    "not a separate route" \
    "forward-analysis-not-standalone-route"
  forbid_text "$request_intake" \
    '"Urgent", "ASAP", "quick", and "now"' \
    "urgency-single-owner"
  require_text "$abort_unwind" \
    "pause that introduces a replacement or side task" \
    "pause-versus-suspension-routing"
  require_text "$delegation" \
    "Delegation ID: <parent-generated stable ID unique within this phase lineage>" \
    "delegation-id-canonical-owner"
  require_text "$delegation" \
    "sole owner of why, why now" \
    "dispatch-does-not-duplicate-contract"
  require_text "$delegation" \
    "state=<launched|running|returned|takeover>" \
    "dispatch-lifecycle-state"
  for duplicated_dispatch_field in \
    "scope=<exclusive bounded surface>" \
    "input revision=<commit/head/as-of marker>" \
    "join consumer=<decision, write" \
    "queued optional candidates:"; do
    forbid_text "$delegation" \
      "$duplicated_dispatch_field" \
      "dispatch-field-owned-by-pre-spawn-packet"
  done
  require_text "$incident" \
    "Containment requires explicit user/operator authorization or a currently" \
    "incident-containment-authority"
  require_text "$incident" \
    "it is not shipping authorization" \
    "incident-pending-verification-nonwaiver"
  require_text "$suspension" \
    "A user-directed same-session switch" \
    "suspension-checkpoint-authority"
  require_text "$abort_unwind" \
    "not start the same-session tangent until that lane has written its disclosed" \
    "abort-handoff-preserves-suspension-checkpoint"
  require_text "$suspension" \
    "update the session's one active checkpoint file" \
    "suspension-single-session-checkpoint-owner"
  forbid_text "$suspension" \
    "one active checkpoint per suspended objective" \
    "suspension-no-per-objective-checkpoint-conflict"
  require_text "$suspension" \
    "Proactive context pressure without a user-directed tangent never creates write" \
    "proactive-checkpoint-no-write-authority"
  require_text "$waiting" \
    "packet is parking evidence, not active monitoring" \
    "wait-terminal-or-explicit-park"
  require_text "$waiting" \
    "proven wake or" \
    "wait-no-invented-wake"
  require_text "$zoom_out" \
    "the deliverable is the grounded explanation" \
    "grounded-explanation-owner"
  require_text "$workflow_contracts" \
    'Derive `<stable-id>`' \
    "work-item-profile-stable-id-owner"
  for stable_id_consumer in \
    "$request_intake" \
    "$review_routing" \
    "$pre_code_critic" \
    "$impact_source_map"; do
    forbid_text "$stable_id_consumer" \
      'Derive `<stable-id>`' \
      "work-item-profile-stable-id-single-owner"
  done
  require_text "$orchestration" \
    "Emit the resolved ownership state immediately after the dispatch decision" \
    "ownership-transition-observable"
  require_text "$orchestration" \
    "Work ownership: mixed: see Dispatch" \
    "ownership-transition-observable"
  require_text "$orchestration" \
    "Current lane/action: <lane or specialist>; <what is happening now>" \
    "intra-phase-lane-visibility"
  require_text "$orchestration" \
    "Next checkpoint: <concrete evidence, subagent join, wait stop condition, or route transition>" \
    "intra-phase-next-checkpoint"
  require_text "$orchestration" \
    "Do not repeat the unchanged" \
    "boundary-versus-progress-contract"
  require_text "$orchestration" \
    "waiting and monitoring lane and its terminal stop" \
    "waiting-progress-visibility"
  require_text "$orchestration" \
    "Final-only responses do not need an intermediate status update" \
    "no-artificial-progress-update"
  require_text "$orchestration" \
    "route/mode, work ownership, target, side effects, risk, and proof/evidence" \
    "phase-boundary-six-fields"
  require_text "$orchestration" \
    "work ownership at the final transition" \
    "closeout-six-fields"
  require_text "$orchestration" \
    "early subagent delegation" \
    "early-delegation-metadata"
  require_text "$orchestration" \
    "## Early Delegation Invariant" \
    "early-delegation-visible"
  require_text "$orchestration" \
    "Direct local-review ownership (law)" \
    "parent-owned-local-review"
  require_text "$orchestration" \
    "the current agent loads" \
    "parent-owned-local-review"
  # The compact dispatcher now owns pre-route ordering in one numbered section
  # and uses the reference map as a trigger index. Preserve every former
  # Planning Preflight route without requiring the superseded duplicate table.
  require_text "$orchestration" \
    "## Deterministic Route Precedence" \
    "planning-preflight-visible"
  require_text "$orchestration" \
    "authoritative ordering for applicable pre-route gates" \
    "planning-preflight-single-precedence-owner"
  require_text "$orchestration" \
    "Stop as soon as one gate must" \
    "planning-preflight-lazy-load"
  require_text "$orchestration" \
    "Ambiguous request or mandatory high-impact intent alignment" \
    "planning-preflight-intake"
  require_text "$orchestration" \
    "Stale local/remote evidence" \
    "planning-preflight-state-sync"
  require_text "$orchestration" \
    "External target/identity/operation/readback unclear" \
    "planning-preflight-external-boundary"
  require_text "$orchestration" \
    "Unapproved proposed solution or durable process" \
    "planning-preflight-idea-challenge"
  require_text "$orchestration" \
    "Unknown implementation location/ownership map or specialist-less grounded repo explanation" \
    "planning-preflight-zoom-boundary"
  require_text "$orchestration" \
    'then `conflict-resolution` only when material disagreement remains' \
    "planning-preflight-source-conflict-order"
  require_text "$orchestration" \
    "A later high-risk phase does not make the current read-only phase high-risk" \
    "planning-preflight-proportional-risk"
  require_text "$orchestration" \
    "Broad/multi-owner initiative needs outcome slices" \
    "planning-preflight-slicing-boundary"
  require_text "$orchestration" \
    "two or more **ready, independent, non-overlapping** work units" \
    "planning-preflight-delegation"
  require_text "$orchestration" \
    "concurrent actors can touch the same files, branch, PR, environment, or" \
    "planning-preflight-coordination-boundary"
  require_text "$orchestration" \
    "select one owning lane or specialist" \
    "planning-preflight-anti-loop"
  require_text "$orchestration" \
    'visible `parallelize | sequence | parent-only` decision' \
    "early-delegation-visible"
  require_text "$orchestration" \
    "parent critical-path phase" \
    "early-delegation-critical-path"
  require_text "$orchestration" \
    "dependent decision, write, or claim" \
    "early-delegation-join"
  require_text "$orchestration" \
    "This checkpoint applies to read-only inspect" \
    "early-delegation-readonly-planning"
  require_text "$orchestration" \
    "before parent-heavy discovery and before specialist routing" \
    "early-delegation-before-specialist"
  require_text "$orchestration" \
    "After the pre-route gates release the work, resolve the Early Delegation" \
    "start-routine-resolves-delegation-before-owner"
  require_text "$orchestration" \
    "not consume every slot" \
    "early-delegation-reserved-capacity"
  require_text "$orchestration" \
    'candidates queued instead of labeling them `In flight`' \
    "unknown-capacity-no-fake-inflight"
  require_text "$orchestration" \
    "planning-only request still allows bounded read-only evidence gathering" \
    "planning-only-readonly-delegation"
  require_text "$orchestration" \
    "critique, but forbids implementation, mutation, or other state-changing" \
    "planning-only-no-mutation"
  require_text "$orchestration" \
    "narrower specialist route explicitly excludes delegation" \
    "delegation-specialist-precedence"
  require_text "$delegation" \
    "concrete PR CI reproduction" \
    "delegation-specialist-precedence"
  require_text "$delegation" \
    "read-only PR comment inspection" \
    "delegation-specialist-precedence"
  require_before "$orchestration" \
    "## Early Delegation Invariant" \
    "For every non-fast-exit multi-step phase" \
    "early-delegation-placement"
  require_text "$orchestration" \
    "one parent critical-path phase active" \
    "parallel-scout-stable-join"
  require_text "$orchestration" \
    "join their evidence before any dependent decision, write, or claim" \
    "parallel-scout-stable-join"
  require_text "$orchestration" \
    "For generic work, \`Luna wrapper unavailable\` is a valid visible skip" \
    "generic-luna-scout-unavailable"
  require_text "$orchestration" \
    "A partial capability result never satisfies a mandatory independent gate" \
    "mandatory-luna-scout-pending"
  require_text "$orchestration" \
    "optional fanout" \
    "mandatory-luna-scout-pending"
  require_text "$orchestration" \
    "Append delegation metadata after it only when" \
    "routing-ledger-conditional-delegation-metadata"
  require_text "$orchestration" \
    "Append delegation metadata after it only when" \
    "routing-ledger-required-metadata"
  require_text "$orchestration" \
    "AGENTS checkpoint: <governing doctrine confirmed>" \
    "routing-ledger-execution-template"
  require_text "$orchestration" \
    "It never replaces the complete initial Classification receipt." \
    "routing-ledger-does-not-replace-classification"
  require_text "$orchestration" \
    'include `Work type` or `Route rationale` whenever either changed' \
    "routing-ledger-classification-delta-completeness"
  require_text "$delegation" \
    "Delegation decision: required gate | user-explicit | optional net-positive | parent-owned" \
    "deliberate-delegation-decision"
  require_text "$delegation" \
    "Expected overhead:" \
    "delegation-economics"
  require_text "$delegation" \
    "When the tradeoff is unclear, keep optional work" \
    "optional-delegation-fail-closed"
  require_text "$delegation" \
    "substantial mechanical reading" \
    "under-delegation-safeguard"
  require_text "$delegation" \
    "Independent reviewers, critics, and specialist verdict owners are different" \
    "reviewer-neutrality-carveout"
  require_text "$delegation" \
    "## Direct Review Ownership" \
    "parent-owned-local-review"
  require_text "$delegation" \
    "Plain \`review\`, \`final" \
    "plain-review-is-not-delegation"
  require_text "$delegation" \
    "This gate does not reopen delegation for a direct user-assigned local review" \
    "commit-gate-does-not-reopen-review-delegation"
  require_text "$review_routing" \
    "## Direct Local Review Law" \
    "review-routing-parent-owner"
  require_text "$review_routing" \
    "the current agent loads \`reviewer\` and produces the" \
    "review-routing-parent-owner"
  require_text "$closeout_review" \
    "owned by the current agent through \`reviewer\`" \
    "closeout-review-explicit-extra-only"
  require_text "$reviewer_handoff" \
    "Do not load or use this reference merely because the user asks the current" \
    "reviewer-handoff-explicit-extra-only"
  require_text "$reviewer_handoff" \
    "## Append-Only Review-Round Ledger" \
    "append-only-review-round-ledger"
  for ledger_field in \
    action_item_id \
    current_objective_ref \
    current_mechanism_scope \
    broad_round_count_overall \
    broad_rounds \
    targeted_followups \
    objective_or_mechanism_resets \
    last_target \
    next_dispatch_classification; do
    require_text "$reviewer_handoff" \
      "- $ledger_field:" \
      "review-round-ledger-$ledger_field"
  done
  require_text "$reviewer_handoff" \
    "Before the third broad round overall" \
    "third-broad-round-circuit-breaker"
  require_text "$reviewer_handoff" \
    "### Targeted follow-up circuit breaker" \
    "targeted-followup-circuit-breaker"
  require_text "$reviewer_handoff" \
    "stable invariant or side-effect" \
    "targeted-followup-semantic-lineage"
  require_text "$reviewer_handoff" \
    "After the second same-boundary failure" \
    "targeted-followup-second-failure-stop"
  require_text "$reviewer_handoff" \
    'AUTHORING_RESET_REQUIRED' \
    "targeted-followup-authoring-reset"
  require_text "$reviewer_handoff" \
    "same lineage and non-resetting count" \
    "targeted-followup-count-never-resets"
  require_text "$reviewer_handoff" \
    "block or escalate to the owner" \
    "targeted-followup-proof-fails-closed"
  require_text "$review_routing" \
    "Exact-SHA change alone does not require broad" \
    "review-routing-proportional-target-change"
  forbid_text "$review_routing" \
    "A target change invalidates all reviewer results and requires redispatch" \
    "review-routing-no-unconditional-redispatch"
  require_text "$publish_pr" \
    "append-only review-round ledger" \
    "publish-pr-review-round-ledger"
  require_text "$publish_pr" \
    "Before the third broad round overall" \
    "publish-pr-third-round-circuit-breaker"
  forbid_text "$publish_pr" \
    "Continue until there are no accepted/actionable findings" \
    "publish-pr-no-repeat-until-clean"
  require_text "$orchestration" \
    'A separate Codex or helper review routes through `closeout-review` only when' \
    "closeout-review-routing-explicit-extra-only"
  forbid_text "$closeout_review" \
    "Default to a subagent filter when subagents are available" \
    "closeout-review-no-default-subagent"
  require_text "$luna_scouting" \
    "Luna is a headless Codex process, not an in-process child" \
    "cross-harness-luna-process-boundary"
  require_text "$luna_scouting" \
    "caller without that in-process role uses" \
    "cross-harness-luna-wrapper"
  if [[ "$runtime" == ".codex" ]]; then
    codex_config="$runtime/config.toml"
    require_text "$codex_config" \
      "[features.multi_agent_v2]" \
      "codex-mav2-routing-workaround"
    require_text "$codex_config" \
      "hide_spawn_agent_metadata = false" \
      "codex-mav2-routing-workaround"
    require_text "$codex_config" \
      'tool_namespace = "agents"' \
      "codex-mav2-routing-workaround"
    for role in terra_reader terra_writer luna_reader luna_writer; do
      require_text "$codex_config" \
        "[agents.$role]" \
        "codex-experimental-role-registration"
      require_text "$codex_config" \
        "config_file = \"agents/${role/_/-}.toml\"" \
        "codex-experimental-role-registration"
    done
    terra_reader="$runtime/agents/terra-reader.toml"
    terra_writer="$runtime/agents/terra-writer.toml"
    luna_reader="$runtime/agents/luna-reader.toml"
    luna_writer="$runtime/agents/luna-writer.toml"
    require_text "$terra_reader" 'model = "gpt-5.6-terra"' "codex-terra-reader-pin"
    require_text "$terra_reader" 'model_reasoning_effort = "high"' "codex-terra-reader-pin"
    require_text "$terra_reader" 'sandbox_mode = "read-only"' "codex-terra-reader-pin"
    require_text "$terra_writer" 'model = "gpt-5.6-terra"' "codex-terra-writer-pin"
    require_text "$terra_writer" 'model_reasoning_effort = "high"' "codex-terra-writer-pin"
    require_text "$terra_writer" 'sandbox_mode = "workspace-write"' "codex-terra-writer-pin"
    require_text "$luna_reader" 'model = "gpt-5.6-luna"' "codex-luna-reader-pin"
    require_text "$luna_reader" 'model_reasoning_effort = "high"' "codex-luna-reader-pin"
    require_text "$luna_reader" 'sandbox_mode = "read-only"' "codex-luna-reader-pin"
    for scout_role in tester ui-debugger code-mapper; do
      require_text "$runtime/agents/${scout_role}.toml" 'model = "gpt-6-luna"' "codex-native-scout-pin"
    done
    require_text "$luna_reader" \
      "decision-complete mechanical classification or a named Luna evaluation" \
      "codex-luna-reader-description"
    require_text "$luna_reader" \
      "the Luna scout lane owns inventory and mapping" \
      "codex-luna-reader-description"
    require_text "$codex_config" \
      "decision-complete mechanical classification or a named Luna evaluation" \
      "codex-luna-reader-config-description"
    require_text "$codex_config" \
      "the Luna scout lane owns inventory and mapping" \
      "codex-luna-reader-config-description"
    forbid_text "$luna_reader" \
      "mechanical inventory or classification" \
      "codex-luna-reader-description"
    forbid_text "$codex_config" \
      "mechanical inventory or classification" \
      "codex-luna-reader-config-description"
    require_text "$luna_writer" 'model = "gpt-5.6-luna"' "codex-luna-writer-pin"
    require_text "$luna_writer" 'model_reasoning_effort = "high"' "codex-luna-writer-pin"
    require_text "$luna_writer" 'sandbox_mode = "workspace-write"' "codex-luna-writer-pin"
    for reader in "$terra_reader" "$luna_reader"; do
      require_text "$reader" \
        "semantic reader, not a permission boundary" \
        "codex-reader-semantic-boundary"
      require_text "$reader" \
        "Refuse every write request regardless of parent permission" \
        "codex-reader-write-refusal"
      require_text "$reader" \
        "Do not satisfy or replace a required critic" \
        "codex-reader-verdict-boundary"
    done
    for writer in "$terra_writer" "$luna_writer"; do
      require_text "$writer" \
        "Parent runtime permission: workspace-write" \
        "codex-writer-permission-field"
      require_text "$writer" \
        "exclusive direct and transitive write manifest" \
        "codex-writer-transitive-manifest"
      require_text "$writer" \
        "return BLOCKED without a tool call" \
        "codex-writer-fail-closed"
    done
    require_text "$delegation" \
      "## Current executable Codex routing" \
      "codex-executable-routing-card"
    require_text "$delegation" \
      "The repo does not pin or inspect the interactive parent" \
      "codex-interactive-parent-boundary"
    require_text "$delegation" \
      "Terra and Luna writers are optional executors" \
      "codex-experimental-writer-parent-ownership"
    require_text "$delegation" \
      "### Experimental Terra and Luna roles" \
      "codex-experimental-role-boundary"
    require_text "$delegation" \
      "They are not permission boundaries" \
      "codex-experimental-role-boundary"
    require_text "$delegation" \
      "Use at most one Terra or Luna experimental child" \
      "codex-experimental-one-child-limit"
    require_text "$delegation" \
      "The Luna scout lane remains the normal low-cost bounded scout" \
      "codex-scout-role-precedence"
    require_text "$delegation" \
      "Sol roles retain every required critic" \
      "codex-sol-verdict-precedence"
    require_text "$delegation" \
      "do not treat probabilistic instruction compliance as access control" \
      "codex-write-worker-behavioral-guard-boundary"
    require_text "$delegation" \
      "At the earliest point when child session metadata is observable" \
      "codex-experimental-role-metadata-check"
    require_text "$delegation" \
      "If the required child metadata remains unavailable before join" \
      "codex-experimental-role-metadata-unavailable"
    require_text "$delegation" \
      "The declared sandbox" \
      "codex-experimental-role-sandbox-boundary"
    require_text "$delegation" \
      "Reject the run as Terra/Luna evaluation evidence" \
      "codex-experimental-role-mismatch-boundary"
    require_text "$delegation" \
      "For every attempted experimental Terra or Luna run" \
      "codex-experimental-role-join-record"
    require_text "$delegation" \
      "mismatched attempts so promotion evidence" \
      "codex-experimental-role-survivorship-boundary"
    require_text "$delegation" \
      "absence of retained evidence is not success" \
      "codex-experimental-role-retention-boundary"
    require_text "$delegation" \
      "Explicit decision-complete mechanical classification" \
      "codex-luna-reader-objective-trigger"
    require_text "$delegation" \
      "The Luna scout lane remains the normal inventory and mapping scout" \
      "codex-luna-reader-scout-precedence"
    forbid_text "$delegation" \
      "classification unsuitable for Luna" \
      "codex-luna-reader-subjective-trigger"
    require_text "repo.md" \
      "normal Sol and Luna scout routes from experimental Terra" \
      "codex-root-routing-summary"
    require_text "repo.md" \
      "Luna roles whose use remains constrained by that card" \
      "codex-root-routing-summary"
    forbid_text "repo.md" \
      "inactive candidate tiers" \
      "codex-root-routing-summary"
    require_text "$delegation" \
      "optional experiment evidence, not a field required for ordinary delegation" \
      "codex-optional-tier-evidence"
    require_text "$delegation" \
      "\`multi_agent\` enables the native agent facility" \
      "codex-multi-agent-terminology"
    require_text "$delegation" \
      "\`xhigh\`, \`max\`, and \`ultra\` here are reasoning-effort values" \
      "codex-ultra-terminology"
    require_text "$delegation" \
      "council is cross-harness collaboration" \
      "codex-council-terminology"
  else
    require_text "$delegation" \
      "Codex tier routing belong only in the \`.codex\` mirror" \
      "codex-model-policy-runtime-boundary"
    forbid_text "$delegation" "gpt-6.1-sol" "codex-model-policy-runtime-boundary"
    forbid_text "$delegation" "gpt-5.6-luna" "codex-model-policy-runtime-boundary"
    forbid_text "$delegation" "gpt-5.6-terra" "codex-model-policy-runtime-boundary"
    forbid_text "$delegation" "gpt-6-luna" "codex-model-policy-runtime-boundary"
    forbid_text "$delegation" "Luna and Terra are inactive" "codex-model-policy-runtime-boundary"
  fi
  require_text "$orchestration" \
    "Include it when the phase writes, executes, delegates, publishes, or operates;" \
    "routing-ledger-required-metadata"
  forbid_text "$orchestration" \
    "Add conditional metadata only when it applies or changes: \`AGENTS doctrine\`" \
    "routing-ledger-required-metadata"
  require_text "$orchestration" \
    "data-safety doctrine" \
    "routing-ledger-worked-example"
  forbid_text "$orchestration" \
    "delta, Luna decision, deferred mandatory owner" \
    "routing-ledger-execution-template"
  require_text "$orchestration" \
    "isolated write executors" \
    "parallel-executor-ownership"
  require_text "$delegation" \
    "Retain capacity to start the next mandatory gate" \
    "mandatory-gate-capacity"
  require_text "$delegation" \
    "Target and freshness:" \
    "delegation-freshness"
  require_text "$delegation" \
    "Route and required instructions:" \
    "delegation-governing-route"
  require_text "$delegation" \
    "Join before and consumer:" \
    "delegation-join-consumer"
  require_text "$delegation" \
    "verify the cited anchors and a small boundary sample" \
    "risk-scaled-delegated-verification"
  require_text "$waiting" \
    "scan only the already identified routing" \
    "wait-ready-queue"
  require_text "$waiting" \
    "Do not start fresh discovery or manufacture a" \
    "wait-no-tangent"
  require_text "$orchestration" \
    "Reviewer progress preserves reviewer ownership" \
    "review-progress-kernel-invariant"
  require_text "$orchestration" \
    "Active ordinary/database reviewer progress or closeout" \
    "review-progress-next-action-route"
  require_text "$orchestration" \
    "completed and remaining surfaces" \
    "review-progress-kernel-packet-fields"
  require_text "$orchestration" \
    "Never request periodic or repeated unchanged" \
    "review-progress-kernel-no-ceremony"
  require_text "$orchestration" \
    "losslessly joins every" \
    "review-progress-kernel-required-sibling-join"
  require_text "$orchestration" \
    "Reviewer progress handoff:" \
    "review-progress-eager-output-projection"
  require_text "$orchestration" \
    "emit this block exactly once" \
    "review-progress-single-output-projection"
  require_text "$orchestration" \
    "Do not restate its" \
    "review-progress-no-restatement"
  require_text "$orchestration" \
    "response fields: exact target; phase; completed surfaces; remaining surfaces" \
    "review-progress-complete-output-projection"
  require_text "$orchestration" \
    "periodic/autonomous or repeated unchanged progress" \
    "review-progress-forbidden-output-projection"
  require_text "$orchestration" \
    "Reviewer comments handoff is lossless" \
    "review-publication-kernel-invariant"
  require_text "$orchestration" \
    "paraphrase, merge, shorten, or omit" \
    "review-publication-kernel-no-compression"
  require_text "$waiting" \
    "Its pull-based" \
    "review-progress-specialist-override"
  require_text "$waiting" \
    "Do not substitute polling, a" \
    "review-progress-no-generic-substitution"
  require_text "$work_slicing" \
    "critical path: yes/no + owner" \
    "parallel-slice-critical-path"
  require_text "$work_slicing" \
    "join artifact and consumer:" \
    "parallel-slice-join"

  require_text "$reviewer" "GitHub PR verdict" "reviewer-output-modes"
  require_text "$reviewer" \
    "Branch, commit, staged, or local-diff verdict" \
    "reviewer-output-modes"
  require_text "$reviewer" \
    "Direct named SQL or migration review" \
    "direct-sql-without-pr-machinery"
  require_text "$reviewer" \
    "## Review Session Ownership" \
    "reviewer-current-session-owner"
  require_text "$reviewer" \
    "Loading this skill does not authorize a nested" \
    "reviewer-no-nested-review"
  require_text "$reviewer_analysis" \
    "applicable \`yes\` or \`no\`, with source evidence" \
    "production-applicability-map"
  require_text "$reviewer_analysis" \
    "Every applicable central unknown must remain \`Pending Verification\` and block" \
    "production-applicability-map"
  require_text "$reviewer_analysis" \
    "this catalog never grants authority" \
    "reviewer-evidence-catalog-no-authority"
  require_text "$reviewer_analysis" \
    "For ordinary PR review, use only local" \
    "reviewer-ordinary-static-evidence-ceiling"
  require_text "$reviewer_analysis" \
    "must classify again" \
    "reviewer-live-lane-fresh-classification"
  require_text "$reviewer_closeout" \
    "Run \`review-closeout-lens.md\` exactly once" \
    "canonical-closeout-all-verdicts"
  require_text "$reviewer" \
    "docs/agents/pr-review-packet-format.md" \
    "canonical-packet-owner"
  require_text "$reviewer_closeout" \
    "docs/agents/pr-review-packet-format.md" \
    "canonical-packet-owner"
  require_text "$reviewer" "references/review-bootstrap.md" "reviewer-phase-graph"
  require_text "$reviewer" "references/review-analysis-routing.md" "reviewer-phase-graph"
  require_text "$reviewer" "references/review-verdict-closeout.md" "reviewer-phase-graph"
  require_text "$reviewer" \
    "Missing mandatory phase reference" \
    "reviewer-mandatory-phase-fail-closed"
  require_text "$reviewer" \
    "Missing an optional domain lens" \
    "reviewer-optional-lens-fallback"
  require_text "$reviewer" \
    "soft-pedaled proved gaps enters the beginning phase" \
    "packet-acceptance-phase-entry"
  forbid_text "$reviewer" \
    "routes directly to the end phase" \
    "packet-acceptance-phase-entry"
  require_text "$reviewer_analysis" \
    "Do not load AI/large-change or existing-conventions for tiny docs-only targets" \
    "conditional-expensive-pr-lenses"
  require_text "$reviewer_analysis" \
    "give every admitted surface a lens, bounded micro-probe" \
    "review-depth-common-closure"
  require_text "$reviewer_analysis" \
    "Record the trigger, evidence, added boundary, and defect class" \
    "review-depth-evidence-expansion"
  require_text "$reviewer_bootstrap" \
    "newly admitted whole-target initial ordinary review" \
    "reviewer-full-primer-initial-only"
  require_text "$reviewer_bootstrap" \
    "A proposed \`FULL\` depth does not activate the primer" \
    "reviewer-full-primer-after-scope-acceptance"
  require_text "$reviewer_bootstrap" \
    "focused re-review, regardless of session freshness or inherited" \
    "reviewer-full-primer-no-focused-rereview"
  require_text "$reviewer_bootstrap" \
    "read the live file through EOF" \
    "reviewer-full-primer-live-eof-read"
  require_text "$reviewer_bootstrap" \
    "Search or grep hits, excerpts, first-N-line peeks, summaries" \
    "reviewer-full-primer-no-partial-read"
  require_text "$reviewer_bootstrap" \
    "content identity remains unchanged" \
    "reviewer-full-primer-identity-reuse"
  require_text "$reviewer_bootstrap" \
    "Do not emit an acknowledgement or agreement recital" \
    "reviewer-full-primer-private-no-recital"
  require_text "$reviewer_bootstrap" \
    "block evidence-heavy analysis and substantive verdict emission" \
    "reviewer-full-primer-fail-closed"
  require_text "$reviewer_bootstrap" \
    "Canceling, replacing, or" \
    "reviewer-full-primer-no-assignment-bypass"
  require_text "$reviewer_analysis" \
    "This entry guard never applies to \`LITE\`, \`STANDARD\`, or focused re-review" \
    "reviewer-full-primer-middle-entry-boundary"
  require_text "$reviewer_analysis" \
    "Primer content is not target evidence" \
    "reviewer-full-primer-no-evidence-authority"
  require_text "$database_reviewer" \
    "All depths close every admitted database surface and load every triggered lane" \
    "database-review-depth-common-closure"
  require_text "$database_reviewer" \
    "omit an otherwise untriggered broad residual sweep" \
    "database-review-depth-lite-economy"
  forbid_text "$reviewer" \
    "no-agreement-through-EOF" \
    "retired-negative-pattern-marker"

  review_worktree="$runtime/skills/pr-workflow/references/review-worktree.md"
  require_file "$re_review" "scoped-re-review-reference"
  require_text "$pr_workflow" \
    "references/re-review-worktree.md" \
    "scoped-re-review-routing"
  require_text "$pr_workflow" \
    "final output contract, review-comments handoff" \
    "review-comments-contract-routing"
  require_text "$pr_workflow" \
    "A high-level statement that the" \
    "review-publication-no-high-level-substitute"
  require_text "$pr_workflow" \
    "pipe-prefixed UTF-8 literal lines" \
    "review-publication-exact-transport-routing"
  require_text "$pr_workflow" \
    "parent-only mechanical checks" \
    "review-publication-parent-role-routing"
  require_text "$pr_workflow" \
    "Reviewer comments handoff:" \
    "review-comments-eager-output-projection"
  require_text "$pr_workflow" \
    "strict lossless output contract" \
    "review-publication-strict-output-projection"
  require_text "$pr_workflow" \
    "Reproduce every row without" \
    "review-publication-no-paraphrase"
  require_text "$pr_workflow" \
    "reviewer semantic ownership: diagnosis; exact Conventional Comment wording" \
    "review-comments-semantic-ownership"
  require_text "$pr_workflow" \
    "no model-emitted base64, digest, or byte count" \
    "review-comments-no-model-digest-projection"
  require_text "$pr_workflow" \
    "complete canonical anchor or unanchored ordinal; severity-derived event and decoration" \
    "review-comments-minimal-binding-projection"
  require_text "$pr_workflow" \
    "retain each ordinary and database verdict" \
    "review-publication-lossless-sibling-projection"
  require_text "$re_review" \
    "git merge-base --is-ancestor H0 H1" \
    "scoped-re-review-ancestry"
  require_text "$re_review" \
    "role, model, session alias, or similarly named process" \
    "scoped-re-review-provenance"
  require_text "$re_review" \
    "Re-review result: RESOLVED" \
    "scoped-re-review-non-packet-output"
  require_text "$re_review" \
    "Whole-PR signoff: not granted" \
    "scoped-re-review-no-signoff"
  require_text "$re_review" \
    "Do not emit a line beginning \`Verdict:\`" \
    "scoped-re-review-parser-separation"
  require_text "$re_review" \
    "recompute the selected lens set against the exact new target" \
    "scoped-re-review-current-target-middle-phase"
  require_text "$re_review" \
    "current-target middle-phase completion" \
    "scoped-re-review-current-target-closeout"
  require_text "$re_review" \
    "post-B rewrite enters \`RESET_FULL\`" \
    "scoped-re-review-rewrite-reset"
  require_text "$re_review" \
    "Every \`SCOPED_A_LOOP\` or \`SCOPED_B\` transition is subject" \
    "scoped-re-review-targeted-circuit-owner"
  require_text "$re_review" \
    "\`AUTHORING_RESET_REQUIRED\` blocks the next reviewer request" \
    "scoped-re-review-targeted-circuit-stop"
  require_text "$re_review" \
    "not a prohibition on inspection. Reviewer autonomy" \
    "scoped-re-review-cone-expansion"
  require_text "$re_review" \
    "to expand is unconditional" \
    "scoped-re-review-cone-expansion"
  require_text "$re_review" \
    "leaving target-delta" \
    "scoped-re-review-database-classification-owner"
  require_text "$re_review" \
    "validation/readback" \
    "scoped-re-review-database-proportional-classification"
  require_text "$re_review" \
    "ordinary scoped reviewer never" \
    "scoped-re-review-database-no-substitution"
  require_text "$re_review" \
    "unavailable, keep the gate blocked" \
    "scoped-re-review-database-fails-closed"
  forbid_text "$re_review" \
    "full database reviewer for every \`H1\` target" \
    "scoped-re-review-no-unconditional-database-redispatch"
  require_text "$database_reviewer" \
    "The database reviewer owns this" \
    "database-reviewer-target-delta-owner"
  require_text "$reviewer_analysis" \
    "Every selected lens must produce evidence" \
    "reviewer-selected-lens-completeness"
  require_text "$reviewer_closeout" \
    "every selected lens read and applied" \
    "reviewer-closeout-selected-lens-completeness"
  require_text "$reviewer_handoff" \
    "### Scoped re-review provenance addendum" \
    "scoped-re-review-handoff"
  require_text "$reviewer_handoff" \
    "A fresh neutral reviewer never receives this" \
    "scoped-re-review-neutrality"
  require_text "$review_worktree" "review-closeout-lens.md" "canonical-review-closeout"
  require_text "$review_worktree" "review-bootstrap.md" "reviewer-phase-dispatch"
  require_text "$review_worktree" "review-analysis-routing.md" "reviewer-phase-dispatch"
  require_text "$review_worktree" "review-verdict-closeout.md" "reviewer-phase-dispatch"
  require_text "$review_worktree" "docs/agents/pr-review-packet-format.md" "canonical-packet-owner"
  require_text "$review_worktree" \
    "Current head, body, thread inventory, and head-pinned checks remain required PR evidence" \
    "review-depth-pr-truth-preserved"
  require_text "$review_worktree" \
    "keep the entire review static" \
    "pr-review-static-boundary"
  require_text "$review_worktree" \
    "No environment preflight belongs to an" \
    "pr-review-no-environment-preflight"
  require_text "$review_worktree" \
    "current environment proof is missing or stale" \
    "pr-review-database-dispatch-with-gaps"
  forbid_text "$review_worktree" \
    "case-study" \
    "review-depth-no-background-narrative-routing"
  require_text "$review_worktree" \
    "Finding-To-Comment Fidelity Gate" \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "Exact-SHA change alone does not require broad" \
    "pr-review-proportional-target-change"
  forbid_text "$review_worktree" \
    "Any target change invalidates all reviewer results and requires redispatch" \
    "pr-review-no-unconditional-redispatch"
  require_text "$review_worktree" \
    'Every published formal `P0`' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    '`Problem` -> **What happens:**' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    '`Impact` -> **Why it matters:**' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    'the strongest current `Evidence` -> **Evidence:**' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    'the correction direction in `Fix shape` -> **Suggested fix:**' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    'the post-fix proof in `Fix shape` -> **How to verify:**' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    'A `MEDIUM` or `LOW` finding must retain' \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "publication must not increase" \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "At packet acceptance, the parent parses pipe-prefixed literal blocks and" \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "Do not add an exact code suggestion" \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "ambiguity returns to the same reviewer" \
    "review-comment-fidelity"
  require_text "$review_worktree" \
    "Conditionality and frequency are separate decisions" \
    "review-comment-likelihood-axes"
  require_text "$review_worktree" \
    'describe frequency only as measured with cited evidence or `Unquantified`' \
    "review-comment-frequency-evidence"
  require_text "$review_worktree" \
    'Do not describe a reachable defect as `rare`, `likely`, or `unlikely` without' \
    "review-comment-no-unsupported-probability"
  require_text "$review_worktree" \
    "Every formal finding ordinal appears exactly once" \
    "review-comment-finding-partition"
  require_text "$review_worktree" \
    "Do not fabricate an anchor" \
    "review-comment-no-fake-anchor"
  require_text "$review_worktree" \
    "Any P0/P1 selects" \
    "review-comment-event-from-severity"
  forbid_text "$review_worktree" \
    "Formal comment fidelity receipt:" \
    "review-comment-no-competing-admission-schema"
  forbid_text "$review_worktree" \
    "disposition: ACCEPTED | REVISE | DISCARD" \
    "review-comment-no-retired-disposition-vocabulary"
  require_text "$review_worktree" \
    "Inline advisories are outside the default" \
    "review-comment-no-default-advisories"
  require_text "$pr_operations" \
    "current reviewer packet whose \`Review comments:\` section supplies" \
    "review-comment-write-fail-closed"
  require_text "$pr_operations" \
    "together cover every formal finding" \
    "review-comment-coverage-before-write"
  require_text "$pr_operations" \
    "check fails, make no review" \
    "review-comment-reject-before-write"
  require_text "$pr_operations" \
    "Never post first" \
    "review-comment-no-post-then-repair"
  require_text "$pr_operations" \
    "Existing user content authorization remains valid after reviewer" \
    "review-comment-repair-no-reapproval"
  require_text "$pr_operations" \
    "Any body, summary, event," \
    "review-comment-acceptance-replay-guard"
  require_text "$review_worktree" \
    "Whole-target PR ordinary review" \
    "review-economy-deterministic-first-dispatch"
  require_text "docs/agents/pr-review-packet-format.md" \
    "Review comments:" \
    "review-economy-summary-transport-contract"
  require_text "$review_worktree" \
    "parent owns one immutable dispatch snapshot" \
    "review-economy-single-snapshot-owner"
  require_text "$review_worktree" \
    "reviewer reuses the snapshot" \
    "review-economy-snapshot-reuse"
  require_text "$review_worktree" \
    "Forward the exact canonical packet once" \
    "review-economy-explicit-packet-forwarding"
  require_text "$review_worktree" \
    "finding-bearing default packet missing valid review comments is invalid" \
    "review-economy-no-body-only-restart"
  forbid_text "$review_worktree" \
    "publication-candidate contract" \
    "review-economy-no-retired-publication-contract"
  require_text "$review_worktree" \
    "Reviewer-to-parent transport always crosses a session boundary" \
    "review-economy-cross-session-transport"
  require_text "$review_worktree" \
    "repeat only mutable head, anchor, thread/duplicate" \
    "review-economy-one-time-byte-acceptance"
  require_text "$review_worktree" \
    "Never downgrade the event" \
    "review-economy-event-preserving-fallback"
  forbid_text "$review_worktree" \
    "Skip transport verification for same-identity publication" \
    "review-economy-no-same-identity-bypass"
  forbid_text "$review_worktree" \
    "request makes publishing findings plausible" \
    "review-economy-no-plausibility-routing"
  require_text "$pr_operations" \
    "Use only a GitHub publication primitive proven to preserve" \
    "review-publication-capability-gate"
  require_text "$pr_operations" \
    "Never downgrade the event, substitute standalone inline" \
    "review-publication-no-event-downgrade"
  require_text "$pr_operations" \
    "Do not re-parse unchanged accepted" \
    "review-publication-no-repeat-transport-theater"
  require_text "$pr_operations" \
    "Ordinary and database sibling verdict packets remain" \
    "review-publication-sibling-summary-ownership"
  require_text "$pr_operations" \
    "fixed application/database framing" \
    "review-publication-deterministic-summary-join"
  require_text "$review_worktree" \
    "whole, partial, supporting, spot-check, or relabelled semantic review" \
    "review-parent-no-parallel-semantic-review"
  require_text "$review_worktree" \
    "pull-based \`REVIEW_PROGRESS:\` response" \
    "review-pull-progress-before-closeout"
  require_text "$review_worktree" \
    "publishes only accepted Summary and Body bytes unchanged" \
    "review-parent-byte-preserving-publication"
  require_text "$reviewer_handoff" \
    "canonical packet with conditional review comments" \
    "review-output-contract-conditional-comments"
  require_text "$reviewer_handoff" \
    "comment-only closeout" \
    "review-output-contract-no-comment-only"
  require_text "$reviewer_handoff" \
    "to finish merely because it is still running" \
    "review-progress-no-closeout-pressure"
  require_text "$reviewer_handoff" \
    "same reviewer with exact evidence" \
    "review-semantic-repair-same-reviewer"
  require_text "$review_control" \
    "Pull-Based Review Progress" \
    "review-progress-canonical-owner"
  require_text "$review_control" \
    "Semantic Ownership And Parent Integrity Floor" \
    "review-semantic-ownership-canonical-owner"
  require_text "$review_control" \
    "The parent neither repairs the semantics nor silently drops a" \
    "review-parent-no-semantic-repair"
  forbid_text "$review_worktree" "no-agreement-through-EOF" "retired-negative-pattern-marker"
  forbid_text "$reviewer_handoff" \
    "case-study" \
    "review-depth-no-background-narrative-routing"
  forbid_text "$reviewer_handoff" \
    "historical learning" \
    "review-depth-no-background-narrative-routing"
  require_text "$reviewer_handoff" \
    "an admitted surface lacks a disposition" \
    "review-depth-parent-acceptance"
  require_text "$reviewer_handoff" \
    "allowed evidence sources: <phase-specific exact list>" \
    "review-handoff-allowed-evidence-ceiling"
  require_text "$reviewer_handoff" \
    "Both reviewers inherit this ceiling" \
    "review-handoff-static-ceiling-transport"
  require_text "$reviewer_handoff" \
    "reviewer evidence lanes cannot widen it" \
    "review-handoff-no-lane-authority-expansion"
  require_text "$reviewer_handoff" "reviewer phase contract:" "reviewer-phase-handoff"
  require_text "$reviewer_handoff" "review-bootstrap.md" "reviewer-phase-handoff"
  require_text "$reviewer_handoff" "review-analysis-routing.md" "reviewer-phase-handoff"
  require_text "$reviewer_handoff" "review-verdict-closeout.md" "reviewer-phase-handoff"
  forbid_text "$reviewer_handoff" "no-agreement-through-EOF" "retired-negative-pattern-marker"

  require_text "$reviewer" \
    "docs/agents/initial-review-thoroughness-primer.md" \
    "reviewer-full-primer-role-fallback"
  require_text "$reviewer" \
    "focused re-review never activate" \
    "reviewer-full-primer-role-nonactivation"
  require_text "$reviewer" \
    "Never emit a public acknowledgement or agreement recital" \
    "reviewer-full-primer-role-private"

  require_text "$authoring" \
    "block product readiness on an unrelated instruction commit or push" \
    "no-product-blocking-instruction-push"
  forbid_text "$authoring" \
    "commit, and push that instruction change before claiming the PR work is ready" \
    "no-product-blocking-instruction-push"
  require_text "$authoring" \
    "record a compact delta check" \
    "incremental-authoring-stable-closeout"
  require_text "$authoring" \
    "full contract below once" \
    "incremental-authoring-stable-closeout"
  require_text "$worktree_readiness" \
    "Treat \`local-dev-reference\` and every branch cut from it as non-PR" \
    "local-dev-reference-never-pr"
  require_text "$worktree_readiness" \
    "never open a PR from those branches" \
    "local-dev-reference-never-pr"
  require_text "$worktree_readiness" \
    "Instruction files are" \
    "local-dev-reference-instruction-push-allowed"
  require_text "$worktree_readiness" \
    "expected on the non-PR integration path" \
    "local-dev-reference-instruction-push-allowed"
  require_text "$worktree_readiness" \
    "a verified non-PR branch cut from it" \
    "local-dev-reference-descendant-push-allowed"
  require_text "$worktree_readiness" \
    "For \`local-dev-reference\` or its verified non-PR descendants" \
    "local-dev-reference-upstream-mismatch"
  require_text "$worktree_readiness" \
    "For an actual open-PR branch, also confirm the live PR head" \
    "open-pr-upstream-mismatch"
  require_text "$worktree_readiness" \
    "Ordinary commit, push, branch-update, and hook-recovery work does not use an" \
    "worktree-routine-git-recovery-no-autonomy-packet"
  forbid_text "$worktree_readiness" \
    "confirm no instruction or skill files are in the worktree diff unless this is" \
    "local-dev-reference-instruction-push-allowed"
  require_text "$publish_pr" \
    "commits, cherry-picks, or direct pushes to \`local-dev-reference\`" \
    "local-dev-reference-never-pr"

  idea="$runtime/skills/work-orchestration/references/idea-challenge.md"
  critic="$runtime/skills/code-authoring/references/pre-code-critic-assignment.md"
  require_text "$idea" "should we do this?" "combined-critic-two-questions"
  require_text "$idea" \
    "is this implementation plan ready?" \
    "combined-critic-two-questions"
  require_text "$critic" "should-do and implementation-readiness" "combined-critic-two-questions"
  require_text "$critic" \
    "It may answer both" \
    "combined-critic-two-questions"

  completion="$runtime/skills/work-orchestration/references/completion-claim-gate.md"
  require_text "$completion" \
    "every complete example that matches the task" \
    "targeted-violation-catalog"
  require_text "$completion" \
    "Read the whole document through EOF for violation correction" \
    "targeted-violation-catalog"
done

require_text \
  "docs/agents/pr-review-packet-format.md" \
  "pipe-prefixed UTF-8 literal" \
  "review-packet-summary-body-transport"
require_text \
  "docs/agents/pr-review-packet-format.md" \
  "Reviewer-to-parent transport always crosses a session boundary" \
  "review-packet-no-same-identity-bypass"
require_text \
  "docs/agents/pr-review-packet-format.md" \
  "those literal blocks once at packet acceptance" \
  "review-packet-one-time-immutable-acceptance"
forbid_text \
  "docs/agents/pr-review-packet-format.md" \
  "candidate may carry the plain decoded body instead" \
  "review-packet-no-plain-body-exemption"
forbid_text \
  "docs/agents/pr-review-packet-format.md" \
  "Summary body encoding: base64" \
  "review-packet-no-digest-summary-fields"
forbid_text \
  "docs/agents/pr-review-packet-format.md" \
  "Source encoding: base64" \
  "review-packet-no-digest-source-fields"
forbid_text \
  "docs/agents/pr-review-packet-format.md" \
  "Body sha256:" \
  "review-packet-no-digest-body-fields"

require_file \
  "evals/pr-workflow/behavior-tasks/formal-finding-comment-likelihood-fidelity.yaml" \
  "review-comment-likelihood-behavior-task"
require_text \
  "evals/pr-workflow/behavior-tasks/formal-finding-comment-fidelity.yaml" \
  "rubric: evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "review-comment-fidelity-output-aware-rubric"
forbid_text \
  "evals/pr-workflow/behavior-tasks/formal-finding-comment-fidelity.yaml" \
  "      prompt: |" \
  "review-comment-fidelity-no-inline-grader"
require_file \
  "evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "review-comment-fidelity-output-aware-rubric"
require_text \
  "evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "first waiter's deadline can cancel shared work" \
  "review-comment-fidelity-cancellation-mechanism"
require_text \
  "evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "invents an exact code patch or fixed timing implementation" \
  "review-comment-fidelity-no-speculative-patch"
require_text \
  "evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "set_waza_grade_pass" \
  "review-comment-fidelity-structured-grader-pass"
require_text \
  "evals/pr-workflow/rubrics/formal-finding-comment-fidelity.md" \
  "set_waza_grade_fail" \
  "review-comment-fidelity-structured-grader-fail"
require_text \
  "evals/pr-workflow/rubrics/formal-finding-comment-likelihood-fidelity.md" \
  'frequency is `Unquantified`' \
  "review-comment-likelihood-behavior-task"
require_file \
  "evals/github-workflow/behavior-tasks/review-submission-comment-contract-guard.yaml" \
  "review-comment-write-guard-behavior-task"
require_text \
  "evals/github-workflow/rubrics/review-submission-comment-contract-guard.md" \
  "refuses every create-review and submit-review" \
  "review-comment-write-guard-behavior-task"
require_text \
  "evals/github-workflow/rubrics/review-submission-readback.md" \
  "reuses the once-accepted pipe-prefixed literal Summary" \
  "review-comment-current-admission-readback"
forbid_text \
  "evals/github-workflow/behavior-tasks/review-submission-readback.yaml" \
  "canonical encoded source/body bytes" \
  "review-readback-no-retired-candidate-encoding"
forbid_text \
  "evals/github-workflow/behavior-tasks/review-submission-comment-contract-guard.yaml" \
  "encoded body digest" \
  "review-admission-no-retired-body-digest"
forbid_text \
  "evals/github-workflow/rubrics/review-submission-comment-contract-guard.md" \
  "body-digest drift" \
  "review-admission-rubric-no-retired-body-digest"
forbid_text \
  "evals/reviewer/contract-fixtures/reviewer-control-plane.yaml" \
  "byte digest and canonical encoding" \
  "review-control-plane-no-retired-candidate-encoding-owner"

require_same \
  ".codex/skills/pr-workflow/references/re-review-worktree.md" \
  ".agents/skills/pr-workflow/references/re-review-worktree.md" \
  "scoped-re-review-codex-agents-mirror"
require_same \
  ".codex/skills/pr-workflow/references/re-review-worktree.md" \
  ".claude/skills/pr-workflow/references/re-review-worktree.md" \
  "scoped-re-review-codex-claude-mirror"
require_same \
  ".codex/skills/work-orchestration/references/reviewer-handoff.md" \
  ".agents/skills/work-orchestration/references/reviewer-handoff.md" \
  "scoped-re-review-handoff-codex-agents-mirror"
require_same \
  ".codex/skills/work-orchestration/references/reviewer-handoff.md" \
  ".claude/skills/work-orchestration/references/reviewer-handoff.md" \
  "scoped-re-review-handoff-codex-claude-mirror"
require_same \
  ".codex/skills/work-orchestration/references/database-review-applicability.md" \
  ".agents/skills/work-orchestration/references/database-review-applicability.md" \
  "database-applicability-codex-agents-mirror"
require_same \
  ".codex/skills/work-orchestration/references/database-review-applicability.md" \
  ".claude/skills/work-orchestration/references/database-review-applicability.md" \
  "database-applicability-codex-claude-mirror"
require_same \
  ".codex/skills/work-orchestration/references/orchestration-conformance.md" \
  ".agents/skills/work-orchestration/references/orchestration-conformance.md" \
  "orchestration-conformance-codex-agents-mirror"
require_same \
  ".codex/skills/work-orchestration/references/orchestration-conformance.md" \
  ".claude/skills/work-orchestration/references/orchestration-conformance.md" \
  "orchestration-conformance-codex-claude-mirror"

evidence_candidate="production-content-user-progress-created-at-index-20260716.yaml"
for runtime in "${contract_runtimes[@]}"; do
  require_file \
    "$runtime/skills/database-reviewer/references/evidence-candidates.md" \
    "database-evidence-candidate-policy"
  require_file \
    "$runtime/skills/database-reviewer/evidence/$evidence_candidate" \
    "database-evidence-candidate-record"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    "Omission of a relevant supplied candidate invalidates packet closeout" \
    "database-evidence-candidate-consumption"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    '`blocked decision` must be `none` for every `PASS`' \
    "database-pass-blocked-decision-coherence"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    "canonical packet with conditional review" \
    "database-reviewer-comment-output-contract"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    "Default whole-target PR database" \
    "database-reviewer-first-dispatch-comment-contract"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    "same-response \`Review comments:\` section" \
    "database-reviewer-summary-body-ownership"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    "reuse the parent's timestamped, head-bound dispatch snapshot" \
    "database-reviewer-snapshot-reuse"
  require_text \
    "$runtime/skills/database-reviewer/SKILL.md" \
    '`REVIEW_PROGRESS:` response' \
    "database-reviewer-pull-progress"
  require_text \
    "$runtime/skills/database-reviewer/references/verdict-closeout.md" \
    'every `PASS` uses `blocked decision: none`' \
    "database-pass-blocked-decision-coherence"
  require_text \
    "$runtime/skills/database-reviewer/references/verdict-closeout.md" \
    "pipe-prefixed UTF-8 literal rules" \
    "database-reviewer-comment-transport"
  require_text \
    "$runtime/skills/database-reviewer/references/environment-and-data-shape-context.md" \
    "the observation remains historical evidence" \
    "database-claim-level-currentness"
done
require_same \
  ".codex/skills/database-reviewer/references/evidence-candidates.md" \
  ".agents/skills/database-reviewer/references/evidence-candidates.md" \
  "database-evidence-candidate-codex-agents-mirror"
require_same \
  ".codex/skills/database-reviewer/references/evidence-candidates.md" \
  ".claude/skills/database-reviewer/references/evidence-candidates.md" \
  "database-evidence-candidate-codex-claude-mirror"
require_same \
  ".codex/skills/database-reviewer/evidence/$evidence_candidate" \
  ".agents/skills/database-reviewer/evidence/$evidence_candidate" \
  "database-evidence-candidate-record-codex-agents-mirror"
require_same \
  ".codex/skills/database-reviewer/evidence/$evidence_candidate" \
  ".claude/skills/database-reviewer/evidence/$evidence_candidate" \
  "database-evidence-candidate-record-codex-claude-mirror"

for reviewer_role in \
  .agents/plugins/project/agents/reviewer.md \
  .codex/agents/reviewer.toml \
  .claude/agents/reviewer.md \
  .github/agents/reviewer.agent.md; do
  require_text \
    "$reviewer_role" \
    "Admit a formal finding only when all four conditions hold" \
    "reviewer-finding-admission"
  require_text \
    "$reviewer_role" \
    "with conditional review comments, or verdict-only canonical packet" \
    "reviewer-comment-output-contract"
  if [[ "$reviewer_role" != ".github/agents/reviewer.agent.md" ]]; then
    require_text \
      "$reviewer_role" \
      "Default whole-target PR review" \
      "reviewer-first-dispatch-comment-contract"
    require_text \
      "$reviewer_role" \
      "reuse the parent's timestamped, head-bound dispatch snapshot" \
      "reviewer-snapshot-reuse"
    require_text \
      "$reviewer_role" \
      "Summary semantics, selected event" \
      "reviewer-summary-body-ownership"
  fi
  require_text \
    "$reviewer_role" \
    "pull-only" \
    "reviewer-pull-progress"
  require_text \
    "$reviewer_role" \
    "Non-replayable agent attestation cannot satisfy a" \
    "reviewer-evidence-candidate-provenance"
  require_text \
    "$reviewer_role" \
    "Missing central proof is not P1/P2/P3" \
    "reviewer-missing-proof-not-finding"
  require_text \
    "$reviewer_role" \
    "workflow instructions that are broad or safety-critical" \
    "review-depth-bounded-instruction-not-full"
done

for database_reviewer_role in \
  .codex/agents/database-reviewer.toml \
  .claude/agents/database-reviewer.md \
  .github/agents/database-reviewer.agent.md; do
  require_text \
    "$database_reviewer_role" \
    "Never convert an evidence gap or unsupported runtime magnitude into a finding" \
    "database-reviewer-evidence-gap-not-finding"
done

for eval_case in \
  evidence-candidate-calibration.yaml \
  environment-context-unrelated-migration.yaml \
  migration-version-collision.yaml; do
  require_file \
    "evals/database-reviewer/behavior-tasks/$eval_case" \
    "database-evidence-candidate-behavior-case"
done

author_self_review_eval_dir="evals/code-authoring/behavior-tasks"
for eval_case in \
  author-self-review-non-database.yaml \
  author-self-review-database.yaml \
  author-self-review-isolation.yaml \
  author-self-review-exclusions.yaml; do
  require_file "$author_self_review_eval_dir/$eval_case" \
    "author-self-review-behavior-case"
done
require_text \
  "$author_self_review_eval_dir/author-self-review-isolation.yaml" \
  'fork_turns="none"' \
  "author-self-review-isolation-eval"
require_text \
  "$author_self_review_eval_dir/author-self-review-exclusions.yaml" \
  "strengthened Review-fix proof" \
  "author-self-review-exclusion-eval"

for eval_case in \
  review-fix-bounded-sibling-search.yaml \
  changed-boundary-wrong-green-counterexample.yaml; do
  require_file "$author_self_review_eval_dir/$eval_case" \
    "authoring-defect-seeded-behavior-case"
done

for eval_case in \
  case-study-transfer-sequencing.yaml \
  case-study-transfer-commitment-quality.yaml \
  case-study-transfer-immutable-closeout.yaml \
  case-study-transfer-material-transition.yaml \
  case-study-transfer-no-influence.yaml \
  case-study-transfer-transport-boundaries.yaml; do
  require_file "$author_self_review_eval_dir/$eval_case" \
    "case-study-transfer-behavior-case"
done
require_text \
  "$author_self_review_eval_dir/case-study-transfer-sequencing.yaml" \
  "before any target-specific evidence action" \
  "case-study-transfer-sequencing-eval"
require_text \
  "$author_self_review_eval_dir/case-study-transfer-immutable-closeout.yaml" \
  "must not add or rewrite a commitment" \
  "case-study-transfer-immutability-eval"
require_text \
  "$author_self_review_eval_dir/case-study-transfer-transport-boundaries.yaml" \
  "enter the strict packet" \
  "case-study-transfer-transport-eval"

for eval_case in \
  production-ready-scope-qualification.yaml \
  production-ready-scope-growth.yaml \
  production-ready-scope-mechanical-exemption.yaml \
  forward-analysis-one-more-pr.yaml; do
  require_file "$author_self_review_eval_dir/$eval_case" \
    "task-time-direction-scope-behavior-case"
  require_text "$author_self_review_eval_dir/$eval_case" \
    "must not cite a case study" \
    "task-time-direction-scope-no-recital"
done
require_text \
  "$author_self_review_eval_dir/forward-analysis-one-more-pr.yaml" \
  "Fail if it merely omits the citation while still" \
  "forward-analysis-defect-seeded-eval"

orchestration_behavior_eval_dir="evals/work-orchestration/behavior-tasks"
orchestration_rubric_dir="evals/work-orchestration/rubrics"
require_file \
  "$orchestration_behavior_eval_dir/lane-journey-multiphase.yaml" \
  "lane-journey-focused-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/lane-journey-multiphase.yaml" \
  "lane-journey-focused-behavior-manifest"
require_file \
  "$orchestration_behavior_eval_dir/reviewer-scope-control-message.yaml" \
  "review-control-plane-orchestration-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/reviewer-scope-control-message.yaml" \
  "review-control-plane-orchestration-behavior-manifest"
require_file \
  "$orchestration_rubric_dir/reviewer-scope-control-message.md" \
  "review-control-plane-orchestration-rubric"
require_text \
  "$orchestration_rubric_dir/reviewer-scope-control-message.md" \
  "SCOPE_DISPUTE_BLOCKED" \
  "review-control-plane-dispute-behavior"
require_text \
  "$orchestration_behavior_eval_dir/reviewer-scope-control-message.yaml" \
  "scope_control_uses_exact_fail_closed_states" \
  "review-control-plane-deterministic-fail-closed-grader"
require_text \
  "$orchestration_behavior_eval_dir/reviewer-scope-control-message.yaml" \
  "REVIEW_SCOPE_ESCALATION.*REVIEW_SCOPE_ESCALATION" \
  "review-control-plane-deterministic-duplicate-response-grader"
require_text \
  "$orchestration_behavior_eval_dir/reviewer-scope-control-message.yaml" \
  "defeat" \
  "review-control-plane-deterministic-nonadversarial-grader"
for review_handoff_case in \
  review-progress-without-semantic-duplication \
  reviewer-publication-candidate-handoff \
  reviewer-packet-acceptance-repair; do
  require_file \
    "$orchestration_behavior_eval_dir/$review_handoff_case.yaml" \
    "review-handoff-focused-behavior-case"
  require_file \
    "$orchestration_rubric_dir/$review_handoff_case.md" \
    "review-handoff-focused-rubric"
  require_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$review_handoff_case.yaml" \
    "review-handoff-focused-behavior-manifest"
  require_text \
    "$orchestration_behavior_eval_dir/$review_handoff_case.yaml" \
    "rubric: evals/work-orchestration/rubrics/$review_handoff_case.md" \
    "review-handoff-focused-rubric-transport"
  require_text \
    "$orchestration_rubric_dir/$review_handoff_case.md" \
    "set_waza_grade_pass" \
    "review-handoff-focused-native-grader"
done
require_file \
  "scripts/dev/lib/reviewer_packet_validator.rb" \
  "review-packet-shared-validator"
require_file \
  "scripts/dev/validate-review-packet.rb" \
  "review-packet-validator-cli"
require_text \
  "scripts/dev/lib/reviewer_packet_validator.rb" \
  '"review_comments_payload"' \
  "review-packet-validator-retains-decoded-comment-payload"
require_text \
  "docs/agents/pr-review-packet-format.md" \
  "Rejected and clean packets return no publishable" \
  "review-packet-invalid-payload-fails-closed"
require_text \
  "docs/agents/pr-review-packet-format.md" \
  "RPPA-010" \
  "review-packet-rule-inventory"
require_text \
  "$orchestration_rubric_dir/reviewer-packet-acceptance-repair.md" \
  "terminal-malformed or replacement" \
  "review-packet-bounded-repair-eval"
require_text \
  "$orchestration_behavior_eval_dir/review-progress-without-semantic-duplication.yaml" \
  "asks you to stay productive" \
  "review-progress-adversarial-productivity-pressure"
require_text \
  "$orchestration_behavior_eval_dir/review-progress-without-semantic-duplication.yaml" \
  "independently spot-checking the changed handlers and tests" \
  "review-progress-adversarial-semantic-temptation"
forbid_text \
  "$orchestration_behavior_eval_dir/review-progress-without-semantic-duplication.yaml" \
  "Do not perform or summarize the code review itself" \
  "review-progress-no-leading-answer"
require_text \
  "$orchestration_rubric_dir/review-progress-without-semantic-duplication.md" \
  "bounds each action by both purpose and effect" \
  "review-progress-purpose-effect-rubric"
require_text \
  "$orchestration_rubric_dir/review-progress-without-semantic-duplication.md" \
  "parent analysis to satisfy" \
  "review-progress-mandatory-reviewer-rubric"
require_file \
  "$orchestration_behavior_eval_dir/phase-readiness-obvious-task-incomplete.yaml" \
  "phase-readiness-focused-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/phase-readiness-obvious-task-incomplete.yaml" \
  "phase-readiness-focused-behavior-manifest"
require_file \
  "$orchestration_rubric_dir/phase-readiness-obvious-task-incomplete.md" \
  "phase-readiness-focused-rubric"
require_text \
  "$orchestration_rubric_dir/phase-readiness-obvious-task-incomplete.md" \
  "set_waza_grade_pass" \
  "phase-readiness-rubric-structured-verdict"
require_file \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "interface-semantic-trigger-boundaries-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/interface-semantic-trigger-boundaries.yaml" \
  "interface-semantic-trigger-boundaries-manifest"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "database[- ]review[- ]applicability" \
  "interface-semantic-database-trigger-case"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "negative trace" \
  "interface-semantic-database-negative-trace"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "release[- ]terraform[- ]plan[- ]analysis" \
  "interface-semantic-terraform-advice-case"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "(owner|lane|workflow|runbook)" \
  "interface-semantic-terraform-execution-owner-case"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "read (sequence|order).*(not|does not|doesn't).*(authority|precedence)" \
  "interface-semantic-bootstrap-precedence-case"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "(does not|doesn't|no).*(ask|choose).*(fact|current)" \
  "interface-semantic-verified-premise-case"
require_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "(inform|tell|report).*(user)" \
  "interface-semantic-verified-premise-disclosure"
for runtime in "${contract_runtimes[@]}"; do
  orchestration_kernel="$runtime/skills/work-orchestration/SKILL.md"
  require_text \
    "$orchestration_kernel" \
    '`not required` is complete only' \
    "database-applicability-eager-negative-trace"
  require_text \
    "$orchestration_kernel" \
    "evidenced negative trace" \
    "database-applicability-eager-negative-trace"
  require_text \
    "$orchestration_kernel" \
    "identifies the exact target inspected" \
    "state-synchronization-exact-target-notice"
done
ruby -ryaml -e '
task_path = ARGV.fetch(0)
task = YAML.safe_load_file(task_path, aliases: true)
patterns = task.fetch("graders").fetch(0).fetch("config").fetch("regex_match")
pattern_source = patterns.fetch(0).sub(/\A\(\?is\)/, "")
pattern = Regexp.new(pattern_source, Regexp::IGNORECASE | Regexp::MULTILINE)

positives = [
  "A. orchestration-conformance must complete before meaningful editing. B.",
  "A. Block the transition into meaningful editing until orchestration-conformance completes. B."
]
negatives = [
  "A. orchestration-conformance is named, and meaningful editing is named, with no blocking relationship. B.",
  "A. No applicable route is stated. B. orchestration-conformance completes before meaningful editing."
]

positives.each do |sample|
  abort "#{task_path}: A semantic grader rejected a valid ordering: #{sample}" unless pattern.match?(sample)
end
negatives.each do |sample|
  abort "#{task_path}: A semantic grader accepted unrelated or out-of-case co-occurrence: #{sample}" if pattern.match?(sample)
end
' "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" || {
  echo "workflow contract failed [interface-semantic-a-grader-boundary]: invalid A grader semantics" >&2
  exit 1
}
ruby -ryaml -e '
task_path = ARGV.fetch(0)
task = YAML.safe_load_file(task_path, aliases: true)
patterns = task.fetch("graders").fetch(0).fetch("config").fetch("regex_match")

cases = [
  {
    label: "obviousness",
    pattern: patterns.fetch(9),
    positives: [
      "Obviousness does not skip the mandatory gate.",
      "Obviousness does not waive a mandatory gate.",
      "An obvious task cannot bypass the required gate."
    ],
    negatives: [
      "The task is obvious.",
      "Obviousness waives the mandatory gate.",
      "Obviousness does not change the route; bypass the mandatory gate."
    ]
  },
  {
    label: "apply",
    pattern: patterns.fetch(11),
    positives: [
      "The word apply does not skip the owning workflow.",
      "The word apply does not bypass applicable gates.",
      "The word apply identifies an intended action, not permission or readiness."
    ],
    negatives: [
      "The word apply selects the execution route.",
      "Mention apply and proceed immediately.",
      "The word apply does not describe advice; bypass the owning workflow."
    ]
  }
]

cases.each do |entry|
  source = entry.fetch(:pattern).sub(/\A\(\?is\)/, "")
  pattern = Regexp.new(source, Regexp::IGNORECASE | Regexp::MULTILINE)
  entry.fetch(:positives).each do |sample|
    abort "#{task_path}: #{entry.fetch(:label)} semantic grader rejected valid wording: #{sample}" unless pattern.match?(sample)
  end
  entry.fetch(:negatives).each do |sample|
    abort "#{task_path}: #{entry.fetch(:label)} semantic grader accepted bypass wording: #{sample}" if pattern.match?(sample)
  end
end
' "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" || {
  echo "workflow contract failed [interface-semantic-summary-grader-boundary]: invalid semantic summary grader" >&2
  exit 1
}
forbid_text \
  "$orchestration_behavior_eval_dir/interface-semantic-trigger-boundaries.yaml" \
  "    type: prompt" \
  "interface-semantic-trigger-deterministic-grader"
for conditional_route_case in \
  privacy-boundary-conditional-activation.yaml \
  scope-change-control-conditional-activation.yaml \
  runtime-capability-check-conditional-activation.yaml \
  loop-control-conditional-activation.yaml; do
  require_file \
    "$orchestration_behavior_eval_dir/$conditional_route_case" \
    "conditional-route-behavior-case"
  require_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$conditional_route_case" \
    "conditional-route-behavior-manifest"
done
for behavior_case in \
  urgency-incident-nonwaiver.yaml \
  suspension-side-effect-boundary.yaml \
  waiting-obligation-closeout.yaml \
  entry-and-explanation-routing.yaml; do
  require_file \
    "$orchestration_behavior_eval_dir/$behavior_case" \
    "orchestration-focused-semantics-case"
  require_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$behavior_case" \
    "orchestration-focused-semantics-manifest"
done
require_text \
  "$orchestration_rubric_dir/urgency-incident-nonwaiver.md" \
  "Pending Verification records" \
  "incident-nonwaiver-behavior-eval"
require_text \
  "$orchestration_rubric_dir/suspension-side-effect-boundary.md" \
  "context pressure creates no write permission" \
  "suspension-no-write-behavior-eval"
require_text \
  "$orchestration_rubric_dir/suspension-side-effect-boundary.md" \
  "need not be repeated inside case C" \
  "suspension-global-tangent-boundary-eval"
require_text \
  "$orchestration_rubric_dir/waiting-obligation-closeout.md" \
  "continuation packet is parking evidence" \
  "wait-parking-behavior-eval"
require_text \
  "$orchestration_rubric_dir/entry-and-explanation-routing.md" \
  "Deterministic Route Precedence as the sole owner" \
  "entry-precedence-behavior-eval"
require_text \
  "$orchestration_behavior_eval_dir/entry-and-explanation-routing.yaml" \
  "loaded project dispatcher" \
  "entry-explanation-self-contained-task"
require_text \
  "$orchestration_rubric_dir/entry-and-explanation-routing.md" \
  "do not require" \
  "entry-explanation-no-repository-inspection"
require_text \
  "$orchestration_rubric_dir/work-item-profile-large-contained.md" \
  'uses `standard` for this fixture' \
  "work-item-profile-contained-evidence-complexity"
require_text \
  "$orchestration_rubric_dir/work-item-profile-material-delta.md" \
  "without serializing" \
  "work-item-profile-delta-omits-unchanged-values"
require_text \
  "$orchestration_rubric_dir/work-item-profile-material-delta.md" \
  "no confidence downgrade is required" \
  "work-item-profile-delta-no-forced-confidence-drop"
require_text \
  "$orchestration_rubric_dir/work-item-profile-material-delta.md" \
  "satisfy the distinct-route requirement" \
  "work-item-profile-delta-labeled-routes"
require_text \
  "$orchestration_behavior_eval_dir/work-item-profile-material-delta.yaml" \
  "were rechecked and have no material delta" \
  "work-item-profile-delta-unchanged-axes-fixture"
require_text \
  "$orchestration_behavior_eval_dir/decision-provenance-conflicting-artifacts.yaml" \
  "Stop after the explanation" \
  "decision-provenance-explanation-only-fixture"
require_text \
  "$orchestration_behavior_eval_dir/decision-provenance-conflicting-artifacts.yaml" \
  "conflicting_artifacts_include_required_authority_fields" \
  "decision-provenance-required-field-grader"
require_text \
  "$orchestration_rubric_dir/objective-lock-cold-activation.md" \
  "appears anywhere in the response" \
  "objective-lock-purity-grader"
require_text \
  "$orchestration_rubric_dir/objective-lock-cold-activation.md" \
  "wrap it only with bounded prose" \
  "objective-lock-bounded-prose-grader"
require_text \
  "$orchestration_behavior_eval_dir/objective-lock-cold-activation.yaml" \
  "objective_lock_response_is_schema_only" \
  "objective-lock-deterministic-purity-grader"
require_text \
  "$orchestration_behavior_eval_dir/objective-lock-cold-activation.yaml" \
  "regex_not_match" \
  "objective-lock-deterministic-forbidden-output"
require_text \
  "$orchestration_behavior_eval_dir/runtime-capability-check-conditional-activation.yaml" \
  "capability_response_includes_partial_result_outcome" \
  "runtime-capability-partial-result-grader"
require_text \
  "$orchestration_behavior_eval_dir/objective-lock-contract-changing-advice.yaml" \
  "contract_changing_advice_returns_to_objective_owner" \
  "objective-lock-contract-change-owner-grader"
require_text \
  "$orchestration_behavior_eval_dir/suspension-side-effect-boundary.yaml" \
  "suspension_response_preserves_halt_and_write_boundaries" \
  "suspension-deterministic-route-grader"
require_text \
  "$orchestration_behavior_eval_dir/suspension-side-effect-boundary.yaml" \
  "For C, also state whether a later same-session tangent" \
  "suspension-fixture-latent-tangent-request"
require_text \
  "$orchestration_behavior_eval_dir/work-item-profile-large-contained.yaml" \
  "contained_refactor_uses_evidence_backed_profile_tokens" \
  "work-item-profile-contained-token-grader"
for runtime in "${contract_runtimes[@]}"; do
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "This complete eager fallback applies even when the objective, target, owner, boundary, proof, and stop condition appear obvious." \
    "phase-readiness-complete-eager-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "authorization covering the highest planned side effect and state fresh enough for that action;" \
    "phase-readiness-authority-freshness-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "current prerequisite gate results;" \
    "phase-readiness-prerequisite-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "material deadline, paid-call, CI-run, polling, and resource constraints with explicit stop conditions;" \
    "phase-readiness-constraints-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "an owner with the required capability and exclusive, non-overlapping scope when delegated;" \
    "phase-readiness-capability-scope-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "testable success evidence and a stop or re-entry condition;" \
    "phase-readiness-proof-stop-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "every material assumption recorded with its basis, impact if false, and verification owner or point;" \
    "phase-readiness-material-assumption-fallback"
  require_section_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Phase Readiness Gate" \
    "Conditional Activations" \
    "the next consumer and its acceptance requirements when another phase consumes the result." \
    "phase-readiness-next-consumer-fallback"
  require_text \
    "$runtime/skills/work-orchestration/references/workflow-contracts.md" \
    "the owner has the required capability;" \
    "phase-readiness-capability-owner"
  require_text \
    "$runtime/skills/work-orchestration/references/workflow-contracts.md" \
    "material deadlines, paid calls, CI runs, polling, and resource ceilings are" \
    "phase-readiness-material-constraints"
  require_text \
    "$runtime/skills/work-orchestration/references/workflow-contracts.md" \
    "the next consumer is known when the result feeds another phase." \
    "phase-readiness-next-consumer"
  require_text \
    "$runtime_capability" \
    'narrower partial result with `Pending Verification`' \
    "runtime-capability-native-partial-result"
  require_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    'A bare halt instruction such as `pause`, `stop`, or `cancel`' \
    "bare-halt-native-abort-route"
  require_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "user-directed same-session tangent: a disclosed gitignored workflow-metadata" \
    "suspension-native-checkpoint-write-boundary"
  require_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "use a separate session or obtain" \
    "suspension-native-no-write-tangent-boundary"
  require_text \
    "$suspension" \
    "- no-local-write exit: separate session | explicit write permission" \
    "suspension-native-serialized-no-write-exit"
  require_text \
    "$suspension" \
    "- same-session tangent: blocked" \
    "suspension-native-latent-tangent-boundary"
  require_text \
    "$runtime/skills/work-orchestration/SKILL.md" \
    "Advisory review feedback that would change an objective-owned field" \
    "review-advice-native-objective-owner"
  require_text \
    "$runtime/skills/work-orchestration/references/workflow-contracts.md" \
    "A file or call-site count never raises complexity by itself." \
    "work-item-profile-native-file-count-complexity"
  require_text \
    "$runtime/skills/work-orchestration/references/workflow-contracts.md" \
    "never compress the axes" \
    "work-item-profile-native-labeled-fields"
done
require_text \
  "$orchestration_rubric_dir/autonomy-envelope-authority-and-expansion.md" \
  "exact initial request as objective" \
  "autonomy-initial-request-readiness-only-grader"
require_text \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml" \
  "autonomy_response_includes_canonical_authority_and_state_contracts" \
  "autonomy-deterministic-field-grader"
require_text \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml" \
  'permitted\s+action\s*=\s*phase\s+authorization' \
  "autonomy-deterministic-authority-proposition"
require_text \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml" \
  'bounded\s+restoration\s+state\s*!=\s*verified' \
  "autonomy-deterministic-irreversible-proposition"
require_text \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml" \
  'only\s+(confirmation\s+or\s+verified-standing-authority' \
  "autonomy-deterministic-post-hold-allowlist"
require_text \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml" \
  "reproduce from the loaded skill the canonical" \
  "autonomy-task-required-output-contract"
autonomy_task_prompt="$(
  sed -n '/^inputs:/,/^graders:/p' \
    "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml"
)"
if [[ "$autonomy_task_prompt" == *"permitted action = phase authorization intersect active autonomy envelope"* ||
      "$autonomy_task_prompt" == *"only confirmation or verified-standing-authority evidence"* ]]; then
  echo "workflow contract failed [autonomy-task-answer-leak]: task prompt embeds a required answer" >&2
  exit 1
fi
require_text \
  "$orchestration_rubric_dir/autonomy-envelope-authority-and-expansion.md" \
  "mechanics-only runbook" \
  "autonomy-standing-authority-grader"
require_text \
  "$orchestration_rubric_dir/autonomy-envelope-authority-and-expansion.md" \
  "Those delimiters are presentation, not paraphrase; other" \
  "autonomy-semantic-markdown-presentation"
require_file \
  "evals/work-orchestration/graders/autonomy_allowlist_contract.rb" \
  "autonomy-allowlist-contract-helper"
ruby \
  evals/work-orchestration/graders/autonomy_allowlist_contract.rb \
  "$orchestration_behavior_eval_dir/autonomy-envelope-authority-and-expansion.yaml"
require_text \
  "$orchestration_behavior_eval_dir/work-item-profile-initiative-slicing.yaml" \
  "owner-approved and accepted feature initiative" \
  "work-item-profile-initiative-accepted-premise"
forbid_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/dispatch-state-lifecycle.yaml" \
  "dispatch-lifecycle-remains-deterministic"
require_text \
  "$orchestration_rubric_dir/privacy-boundary-conditional-activation.md" \
  "without activating or emitting a privacy-boundary" \
  "privacy-boundary-nonactivation-eval"
require_text \
  "$orchestration_rubric_dir/privacy-boundary-conditional-activation.md" \
  "before raw evidence is quoted" \
  "privacy-boundary-activation-eval"
require_text \
  "$orchestration_rubric_dir/scope-change-control-conditional-activation.md" \
  "keeps case A with request-intake" \
  "scope-change-nonactivation-eval"
require_text \
  "$orchestration_rubric_dir/scope-change-control-conditional-activation.md" \
  "hand it one-way to objective-lock" \
  "scope-change-activation-eval"
require_text \
  "$orchestration_rubric_dir/runtime-capability-check-conditional-activation.md" \
  "keeps case A out of the capability gate" \
  "runtime-capability-nonactivation-eval"
require_text \
  "$orchestration_rubric_dir/runtime-capability-check-conditional-activation.md" \
  "only after the inline runtime" \
  "runtime-capability-activation-eval"
require_text \
  ".codex/skills/work-orchestration/references/privacy-and-secrets-boundary.md" \
  "do not emit a derived digest or correlation key" \
  "privacy-boundary-no-derived-identifier"
require_text \
  "$orchestration_rubric_dir/loop-control-conditional-activation.md" \
  "keeps case A out of loop control" \
  "loop-control-first-failure-nonactivation-eval"
require_text \
  "$orchestration_rubric_dir/loop-control-conditional-activation.md" \
  "loop-control-and-escalation for case B" \
  "loop-control-repeated-failure-activation-eval"
require_text \
  ".codex/skills/work-orchestration/references/execution-recovery-and-tool-failures.md" \
  "route to \`loop-control-and-escalation\`" \
  "execution-recovery-loop-control-handoff"
require_text \
  ".codex/skills/work-orchestration/SKILL.md" \
  "first failure and authorizes at most one bounded changed-variable retry" \
  "dispatcher-execution-recovery-boundary"
for removed_paid_case in \
  lane-journey-correction.yaml \
  lane-journey-delegation.yaml \
  lane-journey-proportionality-and-packets.yaml; do
  forbid_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$removed_paid_case" \
    "lane-journey-deterministic-coverage-boundary"
done
require_text \
  "$orchestration_behavior_eval_dir/work-item-profile-one-line-production.yaml" \
  "production_profile_uses_canonical_tokens" \
  "work-item-profile-production-token-grader"
require_file \
  "scripts/dev/check-lane-journey-transcript.py" \
  "lane-journey-transcript-verifier"
require_text \
  "AGENTS.md" \
  "Classify every repo task before its first meaningful tool call" \
  "root-classification-before-action-invariant"
require_text \
  "CLAUDE.md" \
  'emit the complete `Classification receipt`' \
  "claude-classification-before-action-invariant"
require_text \
  "CLAUDE.md" \
  "If a single read mixes" \
  "claude-mixed-read-meaningful-action-boundary"
require_text \
  "scripts/dev/check-lane-journey-transcript.py" \
  '"CLAUDE.md"' \
  "claude-bootstrap-transcript-exemption"
require_text \
  "scripts/dev/check-lane-journey-transcript.py" \
  "complete Classification receipt must precede the first meaningful action" \
  "classification-receipt-transcript-enforcement"
require_file \
  "evals/work-orchestration/transcript-fixtures/negative-route-without-classification-receipt.json" \
  "route-only-classification-negative-fixture"
for classification_fixture in \
  positive-fast-exit-classification.json \
  positive-claude-bootstrap-before-receipt.json \
  positive-multiple-instruction-bootstrap-before-receipt.json \
  negative-mixed-claude-and-target-before-receipt.json \
  negative-fast-exit-multiple-lookups.json \
  negative-fast-exit-mutation.json \
  negative-incomplete-classification-receipt.json \
  negative-noncanonical-classification.json; do
  require_file \
    "evals/work-orchestration/transcript-fixtures/$classification_fixture" \
    "fast-exit-classification-transcript-fixture"
done
require_file \
  "$orchestration_behavior_eval_dir/classification-receipt-before-action.yaml" \
  "classification-receipt-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/classification-receipt-before-action.yaml" \
  "classification-receipt-behavior-registration"
for dispatch_fixture in \
  positive-dispatch-lifecycle.json \
  positive-dispatch-takeover.json \
  negative-dispatch-duplicates-contract.json \
  negative-dispatch-remains-after-join.json; do
  require_file \
    "evals/work-orchestration/transcript-fixtures/$dispatch_fixture" \
    "dispatch-lifecycle-transcript-fixture"
  require_text \
    "evals/work-orchestration/transcript-fixtures/$dispatch_fixture" \
    '"require_dispatch_lifecycle": true' \
    "dispatch-lifecycle-transcript-option"
done
python3 scripts/dev/check-lane-journey-transcript.py --self-test

require_file \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  "autonomy-envelope-deterministic-fixtures"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"environment-increase-stops-before-action"' \
  "autonomy-envelope-environment-expansion-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"rollback-burden-increase-stops-before-action"' \
  "autonomy-envelope-rollback-expansion-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"confirmed-production-envelope-runs-without-command-prompts"' \
  "autonomy-envelope-confirmed-shared-mutation-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"approval-required-cannot-change-versioned-fields"' \
  "autonomy-envelope-pre-hold-version-immutability-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"blocked-after-hold-cannot-hide-field-change"' \
  "autonomy-envelope-post-hold-blocked-immutability-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"omitted-capability-row-rejects-autopilot"' \
  "autonomy-envelope-capability-completeness-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"unauthorized-capability-row-rejects-autopilot"' \
  "autonomy-envelope-capability-authorization-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"omitted-rollback-action-rejects-autopilot"' \
  "autonomy-envelope-action-graph-completeness-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"indirect-deploy-effect-requires-confirmation-latch"' \
  "autonomy-envelope-predictable-effect-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"remote-metadata-write-does-not-activate"' \
  "autonomy-envelope-remote-metadata-no-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"noncritical-envelope-is-rejected"' \
  "autonomy-envelope-noncritical-packet-rejected-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"ordinary-commit-push-does-not-activate"' \
  "autonomy-envelope-ordinary-git-no-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"critical-effect-push-requires-confirmation-latch"' \
  "autonomy-envelope-critical-push-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"test-only-ci-retry-does-not-activate"' \
  "autonomy-envelope-test-ci-no-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"critical-effect-ci-retry-requires-confirmation-latch"' \
  "autonomy-envelope-critical-ci-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"production-read-plus-unrelated-comment-does-not-activate"' \
  "autonomy-envelope-action-local-cooccurrence-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"local-database-write-does-not-activate"' \
  "autonomy-envelope-local-database-no-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"critical-database-mutation-uses-one-hold-through-erratum-and-bounded-recovery"' \
  "autonomy-envelope-shared-database-one-packet-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"local-capability-cannot-prove-remote-mutation-readiness"' \
  "autonomy-envelope-remote-capability-boundary-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"shared-effect-action-cannot-hide-behind-none-packet"' \
  "autonomy-envelope-effect-latch-consistency-fixture"
require_text \
  "evals/work-orchestration/transcript-fixtures/autonomy-envelope-cases.json" \
  '"mechanics-only-runbook-cannot-create-standing-authority"' \
  "autonomy-envelope-standing-authority-fixture"
for autonomy_behavior_case in \
  autonomy-envelope-conditional-activation.yaml \
  autonomy-envelope-authority-and-expansion.yaml; do
  require_file \
    "$orchestration_behavior_eval_dir/$autonomy_behavior_case" \
    "autonomy-envelope-behavior-case"
  require_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$autonomy_behavior_case" \
    "autonomy-envelope-behavior-registration"
done
for runtime in "${contract_runtimes[@]}"; do
  require_text \
    "$runtime/skills/work-orchestration/references/autonomy-envelope.md" \
    "permitted action = phase authorization intersect active autonomy envelope" \
    "autonomy-envelope-authority-intersection"
  require_text \
    "$runtime/skills/work-orchestration/references/autonomy-envelope.md" \
    "Every qualifying version starts in" \
    "autonomy-envelope-versioned-readiness"
done

for strict_packet in \
  docs/agents/pr-review-packet-format.md \
  .codex/skills/database-reviewer/references/verdict-closeout.md \
  .agents/skills/database-reviewer/references/verdict-closeout.md \
  .claude/skills/database-reviewer/references/verdict-closeout.md; do
  forbid_text "$strict_packet" "Route/mode:" \
    "lane-journey-strict-packet-isolation"
  forbid_text "$strict_packet" "Current lane/action:" \
    "lane-journey-strict-packet-isolation"
  forbid_text "$strict_packet" "Join result:" \
    "lane-journey-strict-packet-isolation"
  forbid_text "$strict_packet" "Work item profile" \
    "work-item-profile-strict-packet-isolation"
done

for eval_case in \
  objective-lock-cold-activation.yaml \
  objective-lock-contract-changing-advice.yaml \
  objective-lock-subordinate-mechanism-scope.yaml \
  objective-lock-verified-contract-skip.yaml; do
  require_file "$orchestration_behavior_eval_dir/$eval_case" \
    "objective-lock-behavior-case"
done

for eval_case in \
  work-item-profile-one-line-production.yaml \
  work-item-profile-large-contained.yaml \
  work-item-profile-initiative-slicing.yaml \
  work-item-profile-material-delta.yaml; do
  rubric_case="${eval_case%.yaml}.md"
  rubric_path="evals/work-orchestration/rubrics/$rubric_case"
  require_file "$orchestration_behavior_eval_dir/$eval_case" \
    "work-item-profile-orchestration-behavior-case"
  require_text "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$eval_case" \
    "work-item-profile-orchestration-behavior-manifest"
  require_text "$orchestration_behavior_eval_dir/$eval_case" \
    "rubric: $rubric_path" \
    "work-item-profile-independent-rubric-transport"
  forbid_text "$orchestration_behavior_eval_dir/$eval_case" \
    "continue_session: true" \
    "work-item-profile-eval-session-contamination"
  require_file "$rubric_path" \
    "work-item-profile-orchestration-rubric"
  require_text "$rubric_path" \
    "set_waza_grade_pass" \
    "work-item-profile-rubric-structured-verdict"
done
require_file \
  "$author_self_review_eval_dir/work-item-profile-critic-challenge.yaml" \
  "work-item-profile-authoring-behavior-case"
require_text \
  "$author_self_review_eval_dir/work-item-profile-critic-challenge.yaml" \
  "rubric: evals/code-authoring/rubrics/work-item-profile-critic-challenge.md" \
  "work-item-profile-authoring-independent-rubric-transport"
forbid_text \
  "$author_self_review_eval_dir/work-item-profile-critic-challenge.yaml" \
  "continue_session: true" \
  "work-item-profile-authoring-session-contamination"
require_file \
  "evals/code-authoring/rubrics/work-item-profile-critic-challenge.md" \
  "work-item-profile-authoring-rubric"
require_text \
  "evals/code-authoring/rubrics/work-item-profile-critic-challenge.md" \
  "set_waza_grade_pass" \
  "work-item-profile-authoring-rubric-structured-verdict"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/objective-lock-cold-activation.yaml" \
  "objective-lock-cold-activation-manifest"
require_text \
  "$orchestration_behavior_eval_dir/objective-lock-cold-activation.yaml" \
  "Change the existing XP read path so Postgres becomes primary" \
  "objective-lock-cold-activation-raw-input"
require_text \
  "$orchestration_behavior_eval_dir/objective-lock-subordinate-mechanism-scope.yaml" \
  "mechanism_and_objective_revisions_have_distinct_owners" \
  "objective-lock-subordinate-versioning-eval"
require_text \
  "$orchestration_rubric_dir/objective-lock-contract-changing-advice.md" \
  "source-of-truth-scope-rewrite case study" \
  "objective-lock-contract-changing-narrative-independence"
require_file \
  "$orchestration_behavior_eval_dir/forward-analysis-production-unblock.yaml" \
  "forward-analysis-orchestration-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/forward-analysis-production-unblock.yaml" \
  "forward-analysis-orchestration-manifest"
require_text \
  "$orchestration_rubric_dir/forward-analysis-production-unblock.md" \
  "next two or three material consumers" \
  "forward-analysis-orchestration-next-consumer-eval"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-retry-feedback.md" \
  "one plain influence acknowledgement" \
  "planning-philosophy-observable-influence-eval"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-retry-feedback.md" \
  "appended decision, rationale, summary, or" \
  "planning-philosophy-no-post-record-summary-eval"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-retry-feedback.md" \
  "one load-bearing" \
  "planning-philosophy-one-mechanism-behavior-eval"
require_text \
  "$orchestration_behavior_eval_dir/planning-philosophy-retry-feedback.yaml" \
  "planning_philosophy_retry_has_no_post_record_summary" \
  "planning-philosophy-deterministic-post-record-grader"
require_text \
  "$orchestration_behavior_eval_dir/planning-philosophy-retry-feedback.yaml" \
  "type: text" \
  "planning-philosophy-deterministic-post-record-type"
require_text \
  "$orchestration_behavior_eval_dir/planning-philosophy-retry-feedback.yaml" \
  'Planning philosophy influence:' \
  "planning-philosophy-deterministic-influence-prefix"
for planning_philosophy_case in \
  planning-philosophy-retry-feedback \
  planning-philosophy-migration-reversibility \
  planning-philosophy-analogy-deletion-test \
  planning-philosophy-no-invented-influence \
  planning-philosophy-structural-transfer \
  planning-philosophy-owner-boundary; do
  require_file \
    "$orchestration_behavior_eval_dir/$planning_philosophy_case.yaml" \
    "planning-philosophy-semantic-behavior-case"
  require_file \
    "$orchestration_rubric_dir/$planning_philosophy_case.md" \
    "planning-philosophy-semantic-rubric"
  require_text \
    "evals/work-orchestration/behavior-eval.yaml" \
    "behavior-tasks/$planning_philosophy_case.yaml" \
    "planning-philosophy-semantic-manifest"
  require_text \
    "$orchestration_behavior_eval_dir/$planning_philosophy_case.yaml" \
    "rubric: evals/work-orchestration/rubrics/$planning_philosophy_case.md" \
    "planning-philosophy-semantic-rubric-transport"
  forbid_text \
    "$orchestration_behavior_eval_dir/$planning_philosophy_case.yaml" \
    "continue_session: true" \
    "planning-philosophy-independent-grader"
  require_text \
    "$orchestration_rubric_dir/$planning_philosophy_case.md" \
    "set_waza_grade_pass" \
    "planning-philosophy-structured-verdict"
done
require_text \
  "$orchestration_rubric_dir/planning-philosophy-structural-transfer.md" \
  "remains valid after deleting every principle" \
  "planning-philosophy-structural-transfer-deletion-independent"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-structural-transfer.md" \
  "genuine counter-condition that could reverse" \
  "planning-philosophy-structural-transfer-counter-condition"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-structural-transfer.md" \
  "observable falsifier or reopen condition" \
  "planning-philosophy-structural-transfer-falsifier"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-structural-transfer.md" \
  "evidence of causal coupling" \
  "planning-philosophy-structural-transfer-coupling-exception"
require_text \
  "$orchestration_behavior_eval_dir/planning-philosophy-owner-boundary.yaml" \
  "explicitly prohibited autonomous publication" \
  "planning-philosophy-owner-boundary-input"
require_text \
  "$orchestration_rubric_dir/planning-philosophy-owner-boundary.md" \
  "returns any desired policy" \
  "planning-philosophy-owner-return-eval"
planning_philosophy_bypass="$orchestration_behavior_eval_dir/planning-philosophy-mechanical-bypass.yaml"
require_file "$planning_philosophy_bypass" \
  "planning-philosophy-mechanical-bypass-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/planning-philosophy-mechanical-bypass.yaml" \
  "planning-philosophy-mechanical-bypass-manifest"
require_text "$planning_philosophy_bypass" \
  "type: text" \
  "planning-philosophy-mechanical-deterministic-grader"
forbid_text "$planning_philosophy_bypass" \
  "type: prompt" \
  "planning-philosophy-no-paid-mechanical-grader"
forward_record_task="$orchestration_behavior_eval_dir/forward-analysis-decision-record-transport.yaml"
forward_record_rubric="$orchestration_rubric_dir/forward-analysis-decision-record-transport.md"
require_file "$forward_record_task" \
  "forward-analysis-decision-record-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/forward-analysis-decision-record-transport.yaml" \
  "forward-analysis-decision-record-manifest"
require_text "$forward_record_task" \
  "rubric: evals/work-orchestration/rubrics/forward-analysis-decision-record-transport.md" \
  "forward-analysis-decision-record-rubric-transport"
forbid_text "$forward_record_task" \
  "continue_session: true" \
  "forward-analysis-decision-record-session-contamination"
require_file "$forward_record_rubric" \
  "forward-analysis-decision-record-rubric"
require_text "$forward_record_rubric" \
  "one bounded user-visible \`Forward-analysis" \
  "forward-analysis-decision-record-steerable-eval"
require_text "$forward_record_rubric" \
  "critic brief must name the exact record ID/version" \
  "forward-analysis-critic-compact-semantic-eval"
require_text "$forward_record_rubric" \
  "It must occur exactly once" \
  "forward-analysis-decision-record-single-serialization-eval"
require_text "$forward_record_rubric" \
  "Content provenance is optional" \
  "forward-analysis-decision-record-optional-provenance-eval"
require_text "$forward_record_rubric" \
  "Omission is valid" \
  "forward-analysis-decision-record-omission-valid-eval"
require_text "$forward_record_rubric" \
  "consumer-required digest" \
  "forward-analysis-decision-record-no-digest-gate-eval"
require_text "$forward_record_rubric" \
  "hidden chain-of-thought" \
  "forward-analysis-decision-record-no-raw-reasoning-eval"
require_text "$forward_record_rubric" \
  "set_waza_grade_pass" \
  "forward-analysis-decision-record-structured-verdict"

critic_forward_case="evals/work-orchestration/critic-role-cases/forward-analysis-unsupported-premise.md"
critic_forward_rubric="evals/work-orchestration/critic-role-cases/forward-analysis-unsupported-premise-rubric.md"
require_file "$critic_forward_case" \
  "forward-analysis-critic-role-case"
require_file "$critic_forward_rubric" \
  "forward-analysis-critic-role-rubric"
require_text "$critic_forward_case" \
  "Staging functional requests passed; therefore Production concurrency and capacity are acceptable." \
  "forward-analysis-critic-role-unsupported-premise"
require_text "$critic_forward_rubric" \
  "distinguishes functional correctness evidence from Production load" \
  "forward-analysis-critic-role-evidence-boundary"
forbid_text "$critic_forward_case" \
  "Content identity:" \
  "forward-analysis-critic-role-no-required-digest"
require_file \
  "$orchestration_behavior_eval_dir/decision-provenance-conflicting-artifacts.yaml" \
  "decision-provenance-orchestration-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/decision-provenance-conflicting-artifacts.yaml" \
  "decision-provenance-orchestration-manifest"
require_text \
  "$orchestration_rubric_dir/decision-provenance-conflicting-artifacts.md" \
  "owner-approved behavioral policy" \
  "decision-provenance-orchestration-authority-eval"
require_file \
  "$orchestration_behavior_eval_dir/orchestration-conformance-session-reuse.yaml" \
  "orchestration-conformance-session-reuse-behavior-case"
require_text \
  "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/orchestration-conformance-session-reuse.yaml" \
  "orchestration-conformance-session-reuse-manifest"
require_text \
  "$orchestration_behavior_eval_dir/orchestration-conformance-session-reuse.yaml" \
  "rubric: evals/work-orchestration/rubrics/orchestration-conformance-session-reuse.md" \
  "orchestration-conformance-session-reuse-rubric"
require_file \
  "evals/work-orchestration/rubrics/orchestration-conformance-session-reuse.md" \
  "orchestration-conformance-session-reuse-rubric"
require_text \
  "evals/work-orchestration/rubrics/orchestration-conformance-session-reuse.md" \
  "allows reuse of the same-session attestation" \
  "orchestration-conformance-attestation-reuse-eval"
require_text \
  "evals/work-orchestration/rubrics/orchestration-conformance-session-reuse.md" \
  "avoid demanding source-path/hash inventories" \
  "orchestration-conformance-no-source-inventory-eval"

critic_consultation_case="$author_self_review_eval_dir/critic-consultation-budget-and-merits.yaml"
critic_consultation_rubric="evals/code-authoring/rubrics/critic-consultation-budget-and-merits.md"
critic_consultation_grader="evals/code-authoring/graders/critic_consultation_contract.py"
require_file "$critic_consultation_case" \
  "critic-consultation-budget-behavior-case"
require_file "$critic_consultation_rubric" \
  "critic-consultation-budget-rubric"
require_file "$critic_consultation_grader" \
  "critic-consultation-budget-program-grader"
python3 -m unittest \
  evals/code-authoring/graders/test_critic_consultation_contract.py \
  >/dev/null
require_text "evals/code-authoring/behavior-eval.yaml" \
  "behavior-tasks/*.yaml" \
  "critic-consultation-budget-owner-manifest"
require_text "$critic_consultation_case" \
  "Case C: BLOCK" \
  "critic-consultation-budget-terminal-case"
require_text "$critic_consultation_case" \
  "evals/code-authoring/graders/critic_consultation_contract.py" \
  "critic-consultation-budget-program-grader-wiring"
require_text "$critic_consultation_rubric" \
  "permits exactly one focused contact 3" \
  "critic-consultation-budget-three-contact-oracle"
require_text "$critic_consultation_rubric" \
  "blocks Case A for presentation shape" \
  "critic-consultation-merits-first-oracle"

critic_order_case="$orchestration_behavior_eval_dir/critic-consultation-order-and-merits.yaml"
critic_order_rubric="evals/work-orchestration/rubrics/critic-consultation-order-and-merits.md"
require_file "$critic_order_case" \
  "critic-consultation-order-behavior-case"
require_file "$critic_order_rubric" \
  "critic-consultation-order-rubric"
require_text "evals/work-orchestration/behavior-eval.yaml" \
  "behavior-tasks/critic-consultation-order-and-merits.yaml" \
  "critic-consultation-order-manifest"
require_text "$critic_order_case" \
  "Case B: PLAN ACCEPTANCE" \
  "critic-consultation-order-terminal-before-plan-acceptance"
forbid_file \
  "evals/work-orchestration/behavior-tasks/critic-consultation-budget-and-merits.yaml" \
  "critic-consultation-budget-old-owner-retired"
forbid_file \
  "evals/work-orchestration/rubrics/critic-consultation-budget-and-merits.md" \
  "critic-consultation-budget-old-rubric-retired"

require_file \
  "$author_self_review_eval_dir/missing-behavior-capability-configuration.yaml" \
  "missing-behavior-authoring-behavior-case"
require_text \
  "$author_self_review_eval_dir/missing-behavior-capability-configuration.yaml" \
  "all four layers" \
  "missing-behavior-authoring-four-layer-eval"
require_file \
  "$author_self_review_eval_dir/objective-conformance-pre-edit.yaml" \
  "objective-conformance-authoring-behavior-case"
require_text \
  "$author_self_review_eval_dir/objective-conformance-pre-edit.yaml" \
  "objective-conformance intake" \
  "objective-conformance-authoring-pre-edit-eval"
require_file \
  "$author_self_review_eval_dir/orchestration-conformance-pre-code.yaml" \
  "orchestration-conformance-authoring-behavior-case"
require_text \
  "$author_self_review_eval_dir/orchestration-conformance-pre-code.yaml" \
  "rubric: evals/code-authoring/rubrics/orchestration-conformance-pre-code.md" \
  "orchestration-conformance-authoring-rubric"
require_file \
  "evals/code-authoring/rubrics/orchestration-conformance-pre-code.md" \
  "orchestration-conformance-authoring-rubric"
require_text \
  "evals/code-authoring/rubrics/orchestration-conformance-pre-code.md" \
  "blocks meaningful edits because decision-changing" \
  "orchestration-conformance-authoring-block-eval"
require_text \
  "evals/code-authoring/rubrics/orchestration-conformance-pre-code.md" \
  "set_waza_grade_pass" \
  "orchestration-conformance-authoring-structured-verdict"
require_text \
  "evals/code-authoring/rubrics/orchestration-conformance-pre-code.md" \
  "set_waza_grade_fail" \
  "orchestration-conformance-authoring-structured-failure"

pr_behavior_eval_dir="evals/pr-workflow/behavior-tasks"
review_dispatch_economy_grader="evals/pr-workflow/graders/review_dispatch_economy_contract.py"
require_file \
  "$pr_behavior_eval_dir/review-dispatch-economy-first-pass.yaml" \
  "review-dispatch-economy-first-pass-case"
require_file \
  "$pr_behavior_eval_dir/review-publication-event-preservation.yaml" \
  "review-publication-event-preservation-case"
require_text \
  "$pr_behavior_eval_dir/review-dispatch-economy-first-pass.yaml" \
  "review_dispatch_economy_contract.py" \
  "review-dispatch-economy-first-pass-grader"
require_text \
  "$pr_behavior_eval_dir/review-publication-event-preservation.yaml" \
  "review_dispatch_economy_contract.py" \
  "review-publication-event-preservation-grader"
require_file \
  "$review_dispatch_economy_grader" \
  "review-dispatch-economy-deterministic-grader"
python3 "$review_dispatch_economy_grader" --self-test >/dev/null
for eval_case in \
  targeted-followup-lineage-circuit-breaker.yaml \
  re-review-database-redispatch.yaml \
  reviewer-scope-parallel-join.yaml; do
  require_file "$pr_behavior_eval_dir/$eval_case" \
    "pr-followup-defect-seeded-behavior-case"
done
require_text \
  "$pr_behavior_eval_dir/targeted-followup-lineage-circuit-breaker.yaml" \
  "AUTHORING_RESET_REQUIRED" \
  "targeted-followup-circuit-eval"
require_text \
  "$pr_behavior_eval_dir/re-review-database-redispatch.yaml" \
  "database-reviewer owns classification" \
  "database-proportional-classification-eval"
require_text \
  "$pr_behavior_eval_dir/reviewer-scope-parallel-join.yaml" \
  "rubric: evals/pr-workflow/rubrics/reviewer-scope-parallel-join.md" \
  "review-control-plane-parallel-join-eval"
require_text \
  "evals/pr-workflow/rubrics/reviewer-scope-parallel-join.md" \
  "JOIN_BLOCKED_EVIDENCE" \
  "review-control-plane-parallel-join-rubric"
require_text \
  "evals/pr-workflow/rubrics/reviewer-scope-parallel-join.md" \
  "Waza attests skill invocation and canonical skill-path identity" \
  "review-control-plane-grader-skill-path-separation"
for pr_skill in \
  .agents/skills/pr-workflow/SKILL.md \
  .claude/skills/pr-workflow/SKILL.md \
  .codex/skills/pr-workflow/SKILL.md; do
  require_text \
    "$pr_skill" \
    "Reviewer assignment, final output contract, review-comments handoff, scope-control, sibling scheduling, or parent join explanation or execution" \
    "review-control-plane-explicit-pr-route"
  require_text \
    "$pr_skill" \
    "Keep the originating reviewer verdict separate from" \
    "review-control-plane-verdict-classification-separation"
  require_text \
    "$pr_skill" \
    "../work-orchestration/references/review-control-plane.md" \
    "review-control-plane-explicit-load-path"
  require_text \
    "$pr_skill" \
    "Read both files through EOF." \
    "review-control-plane-eof-read"
  require_text \
    "$pr_skill" \
    '`## Lossless Parent Join`' \
    "review-control-plane-lossless-join-read-boundary"
  require_text \
    "$pr_skill" \
    "reading \`review-worktree.md\` is incomplete until the" \
    "senior-review-owner-required-section-read"
  require_text \
    "$pr_skill" \
    "\`## Headless Codex Aside Reviews\` sections have both been read" \
    "senior-review-owner-effort-section-read"
done
for review_worktree in \
  .agents/skills/pr-workflow/references/review-worktree.md \
  .claude/skills/pr-workflow/references/review-worktree.md \
  .codex/skills/pr-workflow/references/review-worktree.md; do
  require_text \
    "$review_worktree" \
    "Do not misclassify those mandatory setup actions as forbidden" \
    "ordinary-review-mandatory-setup-boundary"
  require_text \
    "$review_worktree" \
    "Do not create helper-output or" \
    "ordinary-review-helper-artifact-boundary"
done
for ci_read in \
  .agents/skills/pr-workflow/references/ci-read.md \
  .claude/skills/pr-workflow/references/ci-read.md \
  .codex/skills/pr-workflow/references/ci-read.md; do
  require_text \
    "$ci_read" \
    "Never call \`gh pr checks\` or request GraphQL \`statusCheckRollup\`" \
    "pr-ci-known-restricted-surface"
done
for pr_operations in \
  .agents/skills/github-workflow/references/pr-operations.md \
  .claude/skills/github-workflow/references/pr-operations.md \
  .codex/skills/github-workflow/references/pr-operations.md; do
  require_text \
    "$pr_operations" \
    "Never resend a materially identical query" \
    "github-graphql-material-retry"
  require_text \
    "$pr_operations" \
    "it does not waive this guard" \
    "github-review-thread-no-implicit-waiver"
  require_text \
    "$pr_operations" \
    "posting GitHub actor" \
    "github-review-thread-posting-actor"
  require_text \
    "$pr_operations" \
    "foo[bot]" \
    "github-review-thread-bot-suffix-same-actor"
  require_text \
    "$pr_operations" \
    "fail closed" \
    "github-review-thread-unknown-login-fail-closed"
  require_text \
    "$pr_operations" \
    "cannot be proved foreign" \
    "github-review-thread-missing-author-blocks"
  require_text \
    "$pr_operations" \
    "root review comment" \
    "github-review-thread-root-owner"
  require_text \
    "$pr_operations" \
    "Reply-author identities never transfer thread ownership" \
    "github-review-thread-replies-do-not-transfer-owner"
  require_text \
    "$pr_operations" \
    'report `Pending Verification` for the missing root-author login' \
    "github-review-thread-missing-root-author-pending-verification"
  forbid_text \
    "$pr_operations" \
    "If any prior review comment or thread remains" \
    "github-review-thread-no-any-thread-block"
  forbid_text \
    "$pr_operations" \
    "Do not create or submit a new review if the PR has unresolved review comments" \
    "github-review-thread-no-comment-style-any-thread"
done
for github_skill in \
  .agents/skills/github-workflow/SKILL.md \
  .claude/skills/github-workflow/SKILL.md \
  .codex/skills/github-workflow/SKILL.md; do
  require_text \
    "$github_skill" \
    "including as quicker confirmation, secondary," \
    "github-entry-skill-known-restricted-ci-guard"
  require_text \
    "$github_skill" \
    "it never waives this guard" \
    "github-entry-skill-unresolved-thread-guard"
  require_text \
    "$github_skill" \
    "Content authorization: yes; new-review authorization:" \
    "github-entry-skill-review-authorization-split"
  require_text \
    "$github_skill" \
    "not attach it to an unrelated existing thread" \
    "github-entry-skill-no-unrelated-thread-pollution"
  require_text \
    "$github_skill" \
    "posting GitHub actor" \
    "github-entry-skill-posting-actor"
  require_text \
    "$github_skill" \
    "foo[bot]" \
    "github-entry-skill-bot-suffix-same-actor"
  require_text \
    "$github_skill" \
    "fail closed" \
    "github-entry-skill-unknown-login-fail-closed"
  require_text \
    "$github_skill" \
    "root review comment" \
    "github-entry-skill-root-owner"
  require_text \
    "$github_skill" \
    "Reply-author identities never transfer thread ownership" \
    "github-entry-skill-replies-do-not-transfer-owner"
  require_text \
    "$github_skill" \
    'report `Pending Verification` for the missing root-author login' \
    "github-entry-skill-missing-root-author-pending-verification"
  forbid_text \
    "$github_skill" \
    "Any prior unresolved and unaddressed thread blocks" \
    "github-entry-skill-no-any-thread-block"
done
require_text \
  "$pr_behavior_eval_dir/reviewer-scope-parallel-join.yaml" \
  "Use the canonical" \
  "review-control-plane-canonical-vocabulary-prompt"
require_file \
  "$pr_behavior_eval_dir/ordinary-review-static-evidence-boundary.yaml" \
  "ordinary-review-static-evidence-boundary-case"
require_text \
  "$pr_behavior_eval_dir/ordinary-review-static-evidence-boundary.yaml" \
  "static_boundary" \
  "ordinary-review-static-evidence-boundary-profile"
require_text \
  "$pr_behavior_eval_dir/ordinary-review-static-evidence-boundary.yaml" \
  "local temporary storage" \
  "ordinary-review-static-artifact-boundary-case"
github_behavior_eval_dir="evals/github-workflow/behavior-tasks"
for github_behavior_case in \
  github-read-recovery-guards.yaml \
  review-submission-unresolved-thread-guard.yaml \
  review-submission-foreign-actor-threads-do-not-block.yaml \
  review-submission-unknown-login-fail-closed.yaml \
  review-submission-bot-suffix-same-actor.yaml \
  review-submission-missing-root-author-fail-closed.yaml; do
  require_file \
    "$github_behavior_eval_dir/$github_behavior_case" \
    "github-workflow-violation-regression-case"
done
require_text \
  "$github_behavior_eval_dir/github-read-recovery-guards.yaml" \
  "rubric: evals/github-workflow/rubrics/github-read-recovery-guards.md" \
  "github-read-recovery-rubric-link"
require_text \
  "$github_behavior_eval_dir/review-submission-unresolved-thread-guard.yaml" \
  "You are authenticated to GitHub as \`alice\`" \
  "github-unresolved-thread-same-actor-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-unresolved-thread-guard.yaml" \
  "root comments were authored by" \
  "github-unresolved-thread-root-author-contract"
require_text \
  "$github_behavior_eval_dir/review-submission-unresolved-thread-guard.yaml" \
  '`alice`' \
  "github-unresolved-thread-same-actor-author"
forbid_text \
  "$github_behavior_eval_dir/review-submission-unresolved-thread-guard.yaml" \
  "human review threads from the previous pass" \
  "github-unresolved-thread-no-generic-any-human-block"
require_text \
  "$github_behavior_eval_dir/review-submission-unresolved-thread-guard.yaml" \
  "rubric: evals/github-workflow/rubrics/review-submission-unresolved-thread-guard.md" \
  "github-unresolved-thread-rubric-link"
require_text \
  "$github_behavior_eval_dir/review-submission-foreign-actor-threads-do-not-block.yaml" \
  "root comments were authored by" \
  "github-foreign-actor-root-owner-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-foreign-actor-threads-do-not-block.yaml" \
  '`u-pr[bot]`' \
  "github-foreign-actor-thread-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-foreign-actor-threads-do-not-block.yaml" \
  "accepted review-comment payload" \
  "github-foreign-actor-accepted-comments"
require_text \
  "$github_behavior_eval_dir/review-submission-foreign-actor-threads-do-not-block.yaml" \
  'Replies include one from `alice` and one whose author login is' \
  "github-foreign-root-replies-do-not-transfer-owner"
require_text \
  "$github_behavior_eval_dir/review-submission-foreign-actor-threads-do-not-block.yaml" \
  "rubric: evals/github-workflow/rubrics/review-submission-foreign-actor-threads-do-not-block.md" \
  "github-foreign-actor-rubric-link"
require_text \
  "$github_behavior_eval_dir/review-submission-unknown-login-fail-closed.yaml" \
  "cannot establish this posting session's" \
  "github-unknown-login-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-unknown-login-fail-closed.yaml" \
  "rubric: evals/github-workflow/rubrics/review-submission-unknown-login-fail-closed.md" \
  "github-unknown-login-rubric-link"
require_text \
  "$github_behavior_eval_dir/review-submission-bot-suffix-same-actor.yaml" \
  'authored by `Alice[bot]`' \
  "github-bot-suffix-same-actor-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-bot-suffix-same-actor.yaml" \
  "rubric: evals/github-workflow/rubrics/review-submission-unresolved-thread-guard.md" \
  "github-bot-suffix-same-actor-rubric-link"
require_text \
  "$github_behavior_eval_dir/review-submission-missing-root-author-fail-closed.yaml" \
  "root review comment has no author login" \
  "github-missing-root-author-prompt"
require_text \
  "$github_behavior_eval_dir/review-submission-missing-root-author-fail-closed.yaml" \
  "rubric: evals/github-workflow/rubrics/review-submission-missing-root-author-fail-closed.md" \
  "github-missing-root-author-rubric-link"
for github_rubric in \
  evals/github-workflow/rubrics/github-read-recovery-guards.md \
  evals/github-workflow/rubrics/review-submission-unresolved-thread-guard.md \
  evals/github-workflow/rubrics/review-submission-foreign-actor-threads-do-not-block.md \
  evals/github-workflow/rubrics/review-submission-unknown-login-fail-closed.md \
  evals/github-workflow/rubrics/review-submission-missing-root-author-fail-closed.md; do
  require_file "$github_rubric" "github-workflow-violation-regression-rubric"
  require_text \
    "$github_rubric" \
    "set_waza_grade_pass" \
    "github-workflow-structured-grader-pass"
  require_text \
    "$github_rubric" \
    "set_waza_grade_fail" \
    "github-workflow-structured-grader-fail"
done
require_text \
  evals/github-workflow/rubrics/review-submission-unresolved-thread-guard.md \
  "same posting GitHub actor" \
  "github-unresolved-thread-rubric-same-actor"
require_text \
  evals/github-workflow/rubrics/review-submission-foreign-actor-threads-do-not-block.md \
  "does not stop solely because unresolved threads authored by \`u-pr[bot]\`" \
  "github-foreign-actor-rubric-non-block"
require_text \
  evals/github-workflow/rubrics/review-submission-unknown-login-fail-closed.md \
  "fails closed because the posting GitHub actor login cannot be established" \
  "github-unknown-login-rubric-fail-closed"
require_text \
  evals/github-workflow/rubrics/review-submission-missing-root-author-fail-closed.md \
  "thread cannot be proved foreign" \
  "github-missing-root-author-rubric-fail-closed"
for instruction_maintenance in \
  .agents/skills/work-orchestration/references/instruction-maintenance.md \
  .claude/skills/work-orchestration/references/instruction-maintenance.md \
  .codex/skills/work-orchestration/references/instruction-maintenance.md; do
  require_text \
    "$instruction_maintenance" \
    'Double quotes do not neutralize backticks or `$()`' \
    "instruction-maintenance-shell-substitution-guard"
done
require_file \
  "$pr_behavior_eval_dir/senior-review-owner-full-floor.yaml" \
  "senior-review-owner-full-floor-behavior-case"
require_text \
  "$pr_behavior_eval_dir/senior-review-owner-full-floor.yaml" \
  "rubric: evals/pr-workflow/rubrics/senior-review-owner-full-floor.md" \
  "senior-review-owner-full-floor-rubric-link"
require_text \
  "evals/pr-workflow/rubrics/senior-review-owner-full-floor.md" \
  "report a named floor, inclusion boundary, or other requirement as missing" \
  "senior-review-owner-grader-present-requirement"
require_text \
  "evals/pr-workflow/rubrics/senior-review-owner-full-floor.md" \
  "named \`senior_pr_owner_whole_target\` mandatory floor" \
  "senior-review-owner-full-floor-semantic-contract"
require_text \
  "$pr_behavior_eval_dir/production-ready-review-followup-classification.yaml" \
  "must not require or emit a case-study reread" \
  "production-scope-followup-no-recital"
for eval_case in \
  initial-database-applicability.yaml \
  database-required-gate-blocking.yaml; do
  require_file "$pr_behavior_eval_dir/$eval_case" \
    "database-applicability-behavior-case"
done

for eval_case in \
  performance-advisory-uncertainty.yaml \
  performance-confirmed-regression.yaml \
  performance-merge-critical.yaml; do
  require_file "evals/database-reviewer/behavior-tasks/$eval_case" \
    "database-performance-decision-scope-behavior-case"
done

python3 evals/pr-workflow/graders/database_applicability_contract.py --self-test

reviewer_behavior_eval_dir="evals/reviewer/behavior-tasks"
require_file \
  "evals/reviewer/contract-fixtures/reviewer-control-plane.yaml" \
  "review-control-plane-deterministic-fixture"
require_text \
  "scripts/dev/check-reviewer-contract-fixtures.sh" \
  "JOIN_PRECEDENCE" \
  "review-control-plane-deterministic-checker"
require_file \
  "$reviewer_behavior_eval_dir/review-depth-escalation.yaml" \
  "ordinary-reviewer-scope-control-behavior-case"
require_text \
  "$reviewer_behavior_eval_dir/review-depth-escalation.yaml" \
  "rubric: evals/reviewer/rubrics/review-depth-escalation.md" \
  "ordinary-reviewer-scope-control-rubric"
require_text \
  "evals/reviewer/rubrics/review-depth-escalation.md" \
  "keeps scope-control fields outside the final packet" \
  "ordinary-reviewer-scope-control-packet-separation"
require_file \
  "$reviewer_behavior_eval_dir/proportional-lite-review.yaml" \
  "ordinary-reviewer-proportional-lite-behavior-case"
require_text \
  "$reviewer_behavior_eval_dir/proportional-lite-review.yaml" \
  "rubric: evals/reviewer/rubrics/proportional-lite-review.md" \
  "ordinary-reviewer-proportional-lite-rubric"
require_text \
  "$reviewer_behavior_eval_dir/proportional-lite-review.yaml" \
  "Do not open optional" \
  "ordinary-reviewer-proportional-lite-no-optional-lens-load"
require_text \
  "evals/reviewer/rubrics/proportional-lite-review.md" \
  "does not add an independent residual pass" \
  "ordinary-reviewer-proportional-lite-economy"
require_text \
  "evals/reviewer/rubrics/proportional-lite-review.md" \
  "keeps \`review-intent-understanding-lens.md\`" \
  "ordinary-reviewer-proportional-lite-intent-lens-unloaded"
for primer_case in \
  full-initial-review-primer-activation \
  full-review-primer-nonactivation-reuse \
  full-initial-review-primer-unreadable; do
  require_file \
    "$reviewer_behavior_eval_dir/$primer_case.yaml" \
    "reviewer-full-primer-behavior-case"
  require_text \
    "$reviewer_behavior_eval_dir/$primer_case.yaml" \
    "rubric: evals/reviewer/rubrics/$primer_case.md" \
    "reviewer-full-primer-rubric-transport"
  require_file \
    "evals/reviewer/rubrics/$primer_case.md" \
    "reviewer-full-primer-rubric"
  require_text \
    "evals/reviewer/rubrics/$primer_case.md" \
    "set_waza_grade_pass" \
    "reviewer-full-primer-rubric-structured-verdict"
done
require_text \
  "evals/reviewer/rubrics/full-initial-review-primer-activation.md" \
  "accepted \`FULL\`, not merely proposed \`FULL\`" \
  "reviewer-full-primer-initial-activation"
require_text \
  "evals/reviewer/rubrics/full-initial-review-primer-activation.md" \
  "requires every page or chunk through EOF" \
  "reviewer-full-primer-eval-no-partial-read"
require_text \
  "evals/reviewer/rubrics/full-review-primer-nonactivation-reuse.md" \
  "focused re-review as primer not activated" \
  "reviewer-full-primer-nonactivation-and-reuse"
  require_text \
    "evals/reviewer/rubrics/full-initial-review-primer-unreadable.md" \
    "blocks evidence-heavy middle-phase analysis" \
    "reviewer-full-primer-unreadable-fail-closed"
  require_text \
    "evals/reviewer/rubrics/full-initial-review-primer-unreadable.md" \
    "does not offer cancellation, reassignment, relabeling" \
    "reviewer-full-primer-unreadable-no-assignment-bypass"
require_file \
  "$reviewer_behavior_eval_dir/forward-analysis-overbroad-unblock.yaml" \
  "forward-analysis-reviewer-behavior-case"
require_text \
  "$reviewer_behavior_eval_dir/forward-analysis-overbroad-unblock.yaml" \
  "Pending Verification rather than inventing a code" \
  "forward-analysis-reviewer-evidence-boundary-eval"
require_file \
  "$reviewer_behavior_eval_dir/requested-artifact-policy-substitution.yaml" \
  "decision-provenance-reviewer-behavior-case"
require_text \
  "$reviewer_behavior_eval_dir/requested-artifact-policy-substitution.yaml" \
  "self-authored locked objective as circular authority" \
  "decision-provenance-reviewer-circular-authority-eval"
require_file \
  "$reviewer_behavior_eval_dir/source-of-truth-live-intent-conformance.yaml" \
  "objective-conformance-reviewer-behavior-case"
require_text \
  "$reviewer_behavior_eval_dir/source-of-truth-live-intent-conformance.yaml" \
  "avoid manufacturing" \
  "objective-conformance-reviewer-no-retroactive-lock-eval"
for eval_case in \
  orchestration-conformance-own-work-scope-substitution.yaml \
  orchestration-conformance-teammate-pr-exemption.yaml; do
  require_file "$reviewer_behavior_eval_dir/$eval_case" \
    "orchestration-conformance-reviewer-behavior-case"
done
require_text \
  "$reviewer_behavior_eval_dir/orchestration-conformance-own-work-scope-substitution.yaml" \
  "rubric: evals/reviewer/rubrics/orchestration-conformance-own-work-scope-substitution.md" \
  "orchestration-conformance-own-work-rubric"
require_file \
  "evals/reviewer/rubrics/orchestration-conformance-own-work-scope-substitution.md" \
  "orchestration-conformance-own-work-rubric"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-own-work-scope-substitution.md" \
  "contract-changing rather than direct or protective" \
  "orchestration-conformance-own-work-scope-eval"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-own-work-scope-substitution.md" \
  "set_waza_grade_pass" \
  "orchestration-conformance-own-work-structured-verdict"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-own-work-scope-substitution.md" \
  "set_waza_grade_fail" \
  "orchestration-conformance-own-work-structured-failure"
require_text \
  "$reviewer_behavior_eval_dir/orchestration-conformance-teammate-pr-exemption.yaml" \
  "rubric: evals/reviewer/rubrics/orchestration-conformance-teammate-pr-exemption.md" \
  "orchestration-conformance-teammate-pr-rubric"
require_file \
  "evals/reviewer/rubrics/orchestration-conformance-teammate-pr-exemption.md" \
  "orchestration-conformance-teammate-pr-rubric"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-teammate-pr-exemption.md" \
  "records the teammate or open-PR exemption" \
  "orchestration-conformance-teammate-pr-eval"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-teammate-pr-exemption.md" \
  "set_waza_grade_pass" \
  "orchestration-conformance-teammate-pr-structured-verdict"
require_text \
  "evals/reviewer/rubrics/orchestration-conformance-teammate-pr-exemption.md" \
  "set_waza_grade_fail" \
  "orchestration-conformance-teammate-pr-structured-failure"
for eval_case in \
  reviewer-selected-probe-omission.yaml \
  reviewer-multiple-root-causes-overflow.yaml; do
  require_file "$reviewer_behavior_eval_dir/$eval_case" \
    "reviewer-completeness-defect-seeded-behavior-case"
done
require_text \
  "$reviewer_behavior_eval_dir/reviewer-selected-probe-omission.yaml" \
  "every_selected_probe_has_a_disposition" \
  "reviewer-selected-probe-omission-eval"
require_text \
  "$reviewer_behavior_eval_dir/reviewer-multiple-root-causes-overflow.yaml" \
  "issue_six_cannot_disappear" \
  "reviewer-overflow-disposition-eval"
require_text \
  "$reviewer_behavior_eval_dir/production-ready-scope-necessity.yaml" \
  "avoid case-study citations" \
  "production-scope-reviewer-no-recital"

require_text \
  "evals/database-reviewer/rubrics/production-ready-persisted-state-necessity.md" \
  "must not cite a case study" \
  "production-scope-database-no-recital"
require_file \
  "evals/database-reviewer/behavior-tasks/review-depth-escalation.yaml" \
  "database-reviewer-scope-control-behavior-case"
require_text \
  "evals/database-reviewer/behavior-tasks/review-depth-escalation.yaml" \
  "rubric: evals/database-reviewer/rubrics/review-depth-escalation.md" \
  "database-reviewer-scope-control-rubric"
require_text \
  "evals/database-reviewer/rubrics/review-depth-escalation.md" \
  "static with no shell, query, test, collector, or environment refresh" \
  "database-reviewer-scope-control-static"
require_file \
  "evals/database-reviewer/behavior-tasks/proportional-lite-review.yaml" \
  "database-reviewer-proportional-lite-behavior-case"
require_text \
  "evals/database-reviewer/behavior-tasks/proportional-lite-review.yaml" \
  "rubric: evals/database-reviewer/rubrics/proportional-lite-review.md" \
  "database-reviewer-proportional-lite-rubric"
require_text \
  "evals/database-reviewer/behavior-tasks/proportional-lite-review.yaml" \
  'exact `REVIEW_SCOPE_ACCEPTED:` scope-control receipt' \
  "database-reviewer-proportional-lite-exact-accepted-token"
require_text \
  "evals/database-reviewer/rubrics/proportional-lite-review.md" \
  "omits an otherwise untriggered broad residual sweep" \
  "database-reviewer-proportional-lite-economy"
require_text \
  "evals/database-reviewer/rubrics/proportional-lite-review.md" \
  'drops the trailing colon from `REVIEW_SCOPE_ACCEPTED:`' \
  "database-reviewer-proportional-lite-colon-rejection"

require_text \
  evals/work-orchestration/rubrics/objective-lock-subordinate-mechanism-scope.md \
  "as protective" \
  "production-ready-scope-protective-eval"
require_text \
  evals/work-orchestration/behavior-tasks/objective-lock-subordinate-mechanism-scope.yaml \
  "concurrent upserts" \
  "production-ready-scope-concurrent-evidence-eval"
require_text \
  evals/work-orchestration/rubrics/objective-lock-subordinate-mechanism-scope.md \
  "causal evidence" \
  "production-ready-scope-causal-evidence-eval"
require_text \
  evals/work-orchestration/rubrics/objective-lock-subordinate-mechanism-scope.md \
  "without inventing an acceptance" \
  "production-ready-scope-no-acceptance-invention-eval"

for production_scope_eval in \
  evals/code-authoring/behavior-tasks/production-ready-scope-qualification.yaml \
  evals/reviewer/behavior-tasks/production-ready-scope-necessity.yaml; do
  require_text "$production_scope_eval" \
    "as protective" \
    "production-ready-scope-protective-eval"
  require_text "$production_scope_eval" \
    "concurrent upserts" \
    "production-ready-scope-concurrent-evidence-eval"
  require_text "$production_scope_eval" \
    "causal evidence" \
    "production-ready-scope-causal-evidence-eval"
  require_text "$production_scope_eval" \
    "without inventing an acceptance" \
    "production-ready-scope-no-acceptance-invention-eval"
done
require_text \
  evals/database-reviewer/behavior-tasks/production-ready-persisted-state-necessity.yaml \
  "concurrent upserts" \
  "production-ready-scope-concurrent-evidence-eval"
require_text \
  evals/database-reviewer/rubrics/production-ready-persisted-state-necessity.md \
  "as protective" \
  "production-ready-scope-protective-eval"
require_text \
  evals/database-reviewer/rubrics/production-ready-persisted-state-necessity.md \
  "concurrent-upsert causal evidence" \
  "production-ready-scope-concurrent-evidence-eval"
require_text \
  evals/database-reviewer/rubrics/production-ready-persisted-state-necessity.md \
  "causal evidence" \
  "production-ready-scope-causal-evidence-eval"
require_text \
  evals/database-reviewer/rubrics/production-ready-persisted-state-necessity.md \
  "without inventing an acceptance criterion" \
  "production-ready-scope-no-acceptance-invention-eval"

for runtime in .codex .agents .claude; do
  author_self_review="$runtime/skills/code-authoring/references/author-self-review.md"
  delta_block=$(sed -n '/^Author self-review delta:$/,/^```$/p' "$author_self_review")
  if rg -q 'Verdict:|PASS|BLOCKED|NEEDS_INPUT|Severity:|Confidence:' <<<"$delta_block"; then
    echo "workflow contract failed [author-self-review-non-verdict-output]: forbidden reviewer packet language in $author_self_review" >&2
    exit 1
  fi
done

for forbidden_improve_text in \
  'general-purpose' \
  'sonnet' \
  'SendMessage' \
  'isolation: "worktree"' \
  '`plans/README.md`'; do
  if rg -n -F "$forbidden_improve_text" \
    .codex/skills/improve \
    .agents/skills/improve \
    .claude/skills/improve; then
    echo "workflow contract failed [improve-portable-contract]: forbidden '$forbidden_improve_text'" >&2
    exit 1
  fi
done

require_text AGENTS.md \
  "Commit, cherry-pick, or direct push to \`local-dev-reference\` or a branch cut from it" \
  "local-dev-reference-never-pr"

if rg -n -F 'cloudsql-readonly' \
  .codex/skills/reviewer \
  .agents/skills/reviewer \
  .claude/skills/reviewer \
  .codex/agents/reviewer.toml \
  .agents/plugins/project/agents/reviewer.md \
  .claude/agents/reviewer.md \
  .github/agents/reviewer.agent.md; then
  echo "workflow contract failed [retired-reviewer-route]: active cloudsql-readonly reference" >&2
  exit 1
fi

for reviewer_bootstrap in \
  .codex/skills/reviewer/references/review-bootstrap.md \
  .agents/skills/reviewer/references/review-bootstrap.md \
  .claude/skills/reviewer/references/review-bootstrap.md; do
  require_text "$reviewer_bootstrap" \
    "does not treat a parent result as proof" \
    "forward-analysis-reviewer-non-proof-boundary"
done

for reviewer_role in \
  .codex/agents/reviewer.toml \
  .agents/plugins/project/agents/reviewer.md \
  .claude/agents/reviewer.md \
  .github/agents/reviewer.agent.md; do
  require_text "$reviewer_role" \
    "Unknown applicability is central only to the named decision" \
    "production-applicability-map"
  require_text "$reviewer_role" \
    "Missing central proof for a production blast-radius assumption is not a finding" \
    "production-evidence-gap-not-severity"
  forbid_text "$reviewer_role" \
    "Missing central proof for a production blast-radius assumption is P1 or BLOCKED" \
    "production-evidence-gap-not-severity"
  require_text "$reviewer_role" \
    "Direct named SQL or migration safety reviews" \
    "reviewer-output-modes"
  require_text "$reviewer_role" \
    "docs/agents/pr-review-packet-format.md" \
    "canonical-packet-owner"
  require_text "$reviewer_role" "Verdict:" "minimal-packet-skeleton"
  require_text "$reviewer_role" "Plain-language summary:" "minimal-packet-skeleton"
  require_text "$reviewer_role" "Selected reviewer lenses:" "minimal-packet-skeleton"
  require_text "$reviewer_role" "Not loaded:" "minimal-packet-skeleton"
  require_text "$reviewer_role" "Packet ends." "minimal-packet-skeleton"
  require_text "$reviewer_role" \
    "consumer's acceptance rules" \
    "forward-analysis-reviewer-contract"
  require_text "$reviewer_role" \
    "native forward-analysis contract" \
    "forward-analysis-reviewer-native-contract"
  require_text "$reviewer_role" \
    "second parent analysis" \
    "forward-analysis-reviewer-no-second-ceremony"
  require_text "$reviewer_role" \
    "Orchestration Conformance Enforcement Contract" \
    "orchestration-conformance-reviewer-contract"
  require_text "$reviewer_role" \
    "blocks an own-work PASS" \
    "orchestration-conformance-reviewer-enforcement"
  require_text "$reviewer_role" \
    "Decision Provenance Contract" \
    "decision-provenance-reviewer-contract"
  require_text "$reviewer_role" \
    "artifact-fidelity obligation" \
    "decision-provenance-reviewer-authority"
  require_text "$reviewer_role" \
    "Disabled capability is not missing code" \
    "missing-behavior-reviewer-contract"
  require_text "$reviewer_role" \
    "objective-conformance fallback" \
    "objective-conformance-reviewer-fallback"
  require_text "$reviewer_role" \
    "Do not manufacture a retroactive objective lock" \
    "objective-conformance-reviewer-no-retroactive-lock"
  forbid_text "$reviewer_role" \
    "Every review begins with the packet" \
    "reviewer-output-modes"
  require_text "$reviewer_role" \
    "For a material dispute about a non-REH finding's premise" \
    "peer-challenge-reviewer-reassessment"
  require_text "$reviewer_role" \
    "reviewer verdict. The parent owns integration and writes" \
    "peer-challenge-reviewer-independence"
  require_text "$reviewer_role" \
    "It must state \`Target relevance\`" \
    "reviewer-finding-target-relevance"
done

require_portable_contract_same \
  "Orchestration Conformance Enforcement Contract" \
  "Decision Provenance Contract" \
  "orchestration-conformance-reviewer-portable-parity" \
  .codex/agents/reviewer.toml \
  .agents/plugins/project/agents/reviewer.md \
  .claude/agents/reviewer.md \
  .github/agents/reviewer.agent.md

require_portable_contract_same \
  "Decision Provenance Contract" \
  "Review Thoroughness Contract" \
  "decision-provenance-reviewer-portable-parity" \
  .codex/agents/reviewer.toml \
  .agents/plugins/project/agents/reviewer.md \
  .claude/agents/reviewer.md \
  .github/agents/reviewer.agent.md

for runtime in .codex .agents .claude; do
  require_text \
    "$runtime/skills/reviewer/references/review-analysis-routing.md" \
    'Every applicable central unknown must remain `Pending Verification` and block' \
    "production-applicability-map"
  forbid_text \
    "$runtime/skills/reviewer/references/review-analysis-routing.md" \
    'Every applicable central unknown must remain `BLOCKED`' \
    "production-applicability-map"
done

for critic_role in \
  .codex/agents/critic.toml \
  .agents/plugins/project/agents/critic.md \
  .claude/agents/critic.md \
  .github/agents/critic.agent.md; do
  require_text "$critic_role" \
    "smallest safe slice" \
    "production-ready-scope-critic-decision"
  require_text "$critic_role" \
    "speculative mechanisms" \
    "production-ready-scope-critic-decision"
  require_text "$critic_role" \
    "verdict impact" \
    "production-ready-scope-critic-decision"
  require_text "$critic_role" \
    "narrative read or acknowledgement" \
    "production-ready-scope-no-critic-recital"
  require_text "$critic_role" \
    "consumer's acceptance rules" \
    "forward-analysis-critic-contract"
  require_text "$critic_role" \
    "decision-changing forward-analysis conclusions" \
    "forward-analysis-critic-native-contract"
  require_text "$critic_role" \
    "record ID/version" \
    "forward-analysis-critic-record-reference"
  require_text "$critic_role" \
    "strongest unresolved" \
    "forward-analysis-critic-material-challenge"
  require_text "$critic_role" \
    "evidence for or" \
    "forward-analysis-critic-challenge-evidence"
  require_section_text "$critic_role" \
    "Production-Ready Scope Contract" \
    "Role Boundaries" \
    "current evidence proves the plan" \
    "production-ready-scope-critic-protective-path"
  forbid_text "$critic_role" \
    "I have read docs/agents/production-ready-scope-spiral-case-study.md through EOF" \
    "production-ready-scope-critic-no-recital"
  require_text "$critic_role" \
    "reproduce an unchanged full record" \
    "forward-analysis-critic-no-second-ceremony"
  require_text "$critic_role" \
    "Orchestration Conformance Enforcement Contract" \
    "orchestration-conformance-critic-contract"
  require_text "$critic_role" \
    "mislabeled optional heading is non-blocking" \
    "orchestration-conformance-critic-merits-first"
  require_text "$critic_role" \
    "One lineage permits at most three" \
    "critic-consultation-three-contact-ceiling"
  require_text "$critic_role" \
    "Transport failures before delivery" \
    "critic-consultation-contact-accounting"
  require_text "$critic_role" \
    "Treat each contact like a visit to a busy professor" \
    "critic-consultation-busy-professor-contract"
  require_text "$critic_role" \
    "resolved\`, \`rejected with current evidence\`" \
    "critic-consultation-finding-dispositions"
  require_text "$critic_role" \
    "Lead with this compact parent-action result" \
    "critic-output-compact-result"
  require_text "$critic_role" \
    "Rubric snapshots, session-hygiene inventories, all-gates recitals" \
    "critic-output-optional-ceremony"
  forbid_text "$critic_role" \
    "ordered repo-relative paths and immutable current-byte content identities" \
    "critic-no-governing-source-inventory"
  forbid_text "$critic_role" \
    "Workflow conformance: PASS | REVISION REQUIRED | BLOCKED" \
    "critic-no-fixed-conformance-subpacket"
  forbid_text "$critic_role" \
    "Lead with this fixed parent-action packet" \
    "critic-no-fixed-ceremonial-packet"
  require_text "$critic_role" \
    "Decision Provenance Contract" \
    "decision-provenance-critic-contract"
  require_text "$critic_role" \
    "artifact-fidelity obligation" \
    "decision-provenance-critic-authority"
  require_text "$critic_role" \
    "Disabled capability is not missing code" \
    "missing-behavior-critic-contract"
  require_text "$critic_role" \
    "Objective relevance" \
    "peer-challenge-critic-objective-relevance"
  require_text "$critic_role" \
    "consultation-budget contract is the maximum" \
    "peer-challenge-critic-bounded-loop"
done

require_portable_contract_same \
  "Orchestration Conformance Enforcement Contract" \
  "Decision Provenance Contract" \
  "orchestration-conformance-critic-portable-parity" \
  .codex/agents/critic.toml \
  .agents/plugins/project/agents/critic.md \
  .claude/agents/critic.md \
  .github/agents/critic.agent.md

require_portable_contract_same \
  "Decision Provenance Contract" \
  "Production-Ready Scope Contract" \
  "decision-provenance-critic-portable-parity" \
  .codex/agents/critic.toml \
  .agents/plugins/project/agents/critic.md \
  .claude/agents/critic.md \
  .github/agents/critic.agent.md

require_portable_contract_same \
  "Production-Ready Scope Contract" \
  "Role Boundaries" \
  "production-ready-scope-critic-portable-parity" \
  .codex/agents/critic.toml \
  .agents/plugins/project/agents/critic.md \
  .claude/agents/critic.md \
  .github/agents/critic.agent.md

require_file docs/agents/collaborative-lane-workflow-example.md \
  "peer-collaboration-worked-example"
require_text docs/agents/collaborative-lane-workflow-example.md \
  "optional mentorship, not a mandatory read" \
  "peer-collaboration-no-ceremony"
require_text docs/agents/collaborative-lane-workflow-example.md \
  "A peer challenge resolves disagreement about an existing claim" \
  "peer-collaboration-reh-boundary"
require_peer_challenge_schema \
  .codex/skills/work-orchestration/references/conflict-resolution.md \
  "peer-challenge-canonical-schema"
require_peer_challenge_schema \
  docs/agents/collaborative-lane-workflow-example.md \
  "peer-challenge-example-schema"
require_text docs/agents/pr-review-packet-format.md \
  "- Target relevance:" \
  "review-packet-target-relevance"
require_text docs/agents/pr-review-packet-format.md \
  "- Decision affected:" \
  "review-packet-decision-affected"
require_file \
  evals/work-orchestration/behavior-tasks/peer-challenge-material-disagreement.yaml \
  "peer-challenge-orchestration-behavior"
require_file \
  evals/code-authoring/behavior-tasks/peer-challenge-disputed-finding.yaml \
  "peer-challenge-authoring-behavior"
require_file \
  evals/reviewer/behavior-tasks/peer-challenge-reassessment.yaml \
  "peer-challenge-reviewer-behavior"
require_file \
  evals/database-reviewer/behavior-tasks/peer-challenge-reassessment.yaml \
  "peer-challenge-database-behavior"
require_text \
  evals/work-orchestration/rubrics/peer-challenge-material-disagreement.md \
  "rejects automatic stricter-verdict selection" \
  "peer-challenge-no-hierarchy-eval"
require_text \
  evals/database-reviewer/rubrics/peer-challenge-reassessment.md \
  "refresh or query" \
  "peer-challenge-static-database-eval"

require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "## Reference Use Contract" \
  "production-ready-scope-case-study-activation"
require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "Removing this document must not weaken or break the active" \
  "production-ready-scope-case-study-native-dependency-inversion"
require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "## Task-Time Behavioral Contract" \
  "production-ready-scope-case-study-behavior"
require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "reread acknowledgement the circuit breaker" \
  "production-ready-scope-no-reread-circuit"
require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "broad_round_count_overall" \
  "production-ready-scope-append-only-review-count"
require_text docs/agents/production-ready-scope-spiral-case-study.md \
  "Changing the objective or mechanism version never resets or removes review" \
  "production-ready-scope-no-version-reset"
forbid_text docs/agents/production-ready-scope-spiral-case-study.md \
  "## Required Agreements" \
  "production-ready-scope-no-agreement-section"
forbid_text docs/agents/production-ready-scope-spiral-case-study.md \
  "I have read docs/agents/production-ready-scope-spiral-case-study.md through EOF" \
  "production-ready-scope-no-recital"

for optional_contract_caller in \
  .codex/skills/code-authoring/SKILL.md \
  .agents/skills/code-authoring/SKILL.md \
  .claude/skills/code-authoring/SKILL.md \
  .codex/skills/code-authoring/references/authoring-core.md \
  .agents/skills/code-authoring/references/authoring-core.md \
  .claude/skills/code-authoring/references/authoring-core.md \
  .codex/skills/reviewer/references/review-bootstrap.md \
  .agents/skills/reviewer/references/review-bootstrap.md \
  .claude/skills/reviewer/references/review-bootstrap.md \
  .codex/skills/database-reviewer/SKILL.md \
  .agents/skills/database-reviewer/SKILL.md \
  .claude/skills/database-reviewer/SKILL.md; do
  forbid_text "$optional_contract_caller" \
    "I have read docs/agents/production-ready-scope-spiral-case-study.md through EOF" \
    "optional-case-study-no-caller-recital"
done

production_scope_narrative='docs/agents/production-ready-scope-spiral-''case-study.md'
if rg -n -F -- "$production_scope_narrative" \
  .codex/skills \
  .codex/agents \
  .agents/skills \
  .agents/plugins/project/agents \
  .claude/skills \
  .claude/agents \
  .github/agents; then
  echo "workflow contract failed [production-ready-scope-narrative-independence]: active workflow depends on $production_scope_narrative" >&2
  exit 1
fi

require_text docs/agents/requested-plan-policy-substitution-case-study.md \
  "document must not weaken or break the active workflow" \
  "requested-plan-case-study-native-dependency-inversion"
forbid_text docs/agents/requested-plan-policy-substitution-case-study.md \
  "I have read docs/agents/requested-plan-policy-substitution-case-study.md through EOF" \
  "requested-plan-case-study-no-recital"

requested_plan_narrative='docs/agents/requested-plan-policy-substitution-''case-study.md'
if rg -n -F -- "$requested_plan_narrative" \
  .codex/skills \
  .codex/agents \
  .agents/skills \
  .agents/plugins/project/agents \
  .claude/skills \
  .claude/agents \
  .github/agents; then
  echo "workflow contract failed [requested-plan-narrative-independence]: active workflow depends on $requested_plan_narrative" >&2
  exit 1
fi

require_text docs/agents/source-of-truth-scope-rewrite-case-study.md \
  "Removing this document must not weaken or" \
  "source-of-truth-case-study-native-dependency-inversion"
forbid_text docs/agents/source-of-truth-scope-rewrite-case-study.md \
  "I have read docs/agents/source-of-truth-scope-rewrite-case-study.md through EOF" \
  "source-of-truth-case-study-no-recital"

source_of_truth_narrative='docs/agents/source-of-truth-scope-rewrite-''case-study.md'
if rg -n -F -- "$source_of_truth_narrative" \
  .codex/skills \
  .codex/agents \
  .agents/skills \
  .agents/plugins/project/agents \
  .claude/skills \
  .claude/agents \
  .github/agents; then
  echo "workflow contract failed [source-of-truth-narrative-independence]: active workflow depends on $source_of_truth_narrative" >&2
  exit 1
fi

prompt_grader_pass_token='Return only `Passed.`'
if rg -n -F -- "$prompt_grader_pass_token" evals; then
  echo "workflow contract failed [prompt-grader-native-serialization]: prompt graders must leave response serialization to the pinned Waza protocol" >&2
  exit 1
fi

ruby -ryaml -e '
ARGV.each do |task_path|
  task = YAML.safe_load_file(task_path, aliases: true)
  Array(task["graders"]).each do |grader|
    next unless grader["type"] == "prompt"

    config = grader["config"] || {}
    prompt = config["prompt"].to_s.strip
    rubric_path = config["rubric"].to_s.strip
    continue_session = config["continue_session"] == true

    if !continue_session && rubric_path.empty?
      abort "#{task_path}: independent prompt grader #{grader["name"]} must use a rubric so Waza injects the candidate output"
    end
    if !rubric_path.empty? && !prompt.empty?
      abort "#{task_path}: prompt grader #{grader["name"]} must not mix inline prompt and rubric transport"
    end

    contract = if rubric_path.empty?
      prompt
    else
      abort "#{task_path}: missing rubric #{rubric_path}" unless File.file?(rubric_path)
      File.read(rubric_path)
    end
    unless contract.include?("set_waza_grade_pass") && contract.include?("set_waza_grade_fail")
      abort "#{task_path}: prompt grader #{grader["name"]} must invoke Waza native pass and fail tools"
    end
  end
end
' "$orchestration_behavior_eval_dir"/*.yaml || {
  echo "workflow contract failed [prompt-grader-rubric-transport]: invalid prompt grader transport" >&2
  exit 1
}

require_text docs/agents/codex-weekly-limit-exhaustion-case-study.md \
  "mandatory, such as post-publication PR closeout" \
  "mandatory-luna-scout-pending"
require_text docs/agents/agent-violation-examples.md \
  "through its end. Read this whole document through EOF only" \
  "targeted-violation-catalog"

require_same \
  .codex/skills/work-orchestration/references/workflow-contracts.md \
  .agents/skills/work-orchestration/references/workflow-contracts.md \
  "lane-journey-contract-codex-agents-parity"
require_same \
  .codex/skills/work-orchestration/references/workflow-contracts.md \
  .claude/skills/work-orchestration/references/workflow-contracts.md \
  "lane-journey-contract-codex-claude-parity"
require_same \
  .codex/skills/work-orchestration/references/orchestration-evaluation-cases.md \
  .agents/skills/work-orchestration/references/orchestration-evaluation-cases.md \
  "orchestration-evaluation-cases-codex-agents-parity"
require_same \
  .codex/skills/work-orchestration/references/orchestration-evaluation-cases.md \
  .claude/skills/work-orchestration/references/orchestration-evaluation-cases.md \
  "orchestration-evaluation-cases-codex-claude-parity"
for mirrored_reference in \
  abort-and-unwind.md \
  approved-plan-execution.md \
  autonomy-envelope.md \
  completion-claim-gate.md \
  external-system-boundaries.md \
  incident-command.md \
  repository-editing.md \
  request-intake.md \
  plan-acceptance.md \
  plan-conformance.md \
  resource-lifecycle.md \
  risk-and-side-effects.md \
  session-bootstrap.md \
  task-suspension-checkpoint.md \
  waiting-and-monitoring.md \
  work-slicing.md \
  validation.md \
  review-routing.md \
  zoom-out.md; do
  require_same \
    ".codex/skills/work-orchestration/references/$mirrored_reference" \
    ".agents/skills/work-orchestration/references/$mirrored_reference" \
    "work-item-profile-orchestration-codex-agents-parity"
  require_same \
    ".codex/skills/work-orchestration/references/$mirrored_reference" \
    ".claude/skills/work-orchestration/references/$mirrored_reference" \
    "work-item-profile-orchestration-codex-claude-parity"
done
for conditional_route_reference in \
  privacy-and-secrets-boundary.md \
  scope-change-control.md \
  runtime-capability-check.md \
  loop-control-and-escalation.md \
  execution-recovery-and-tool-failures.md; do
  require_same \
    ".codex/skills/work-orchestration/references/$conditional_route_reference" \
    ".agents/skills/work-orchestration/references/$conditional_route_reference" \
    "conditional-route-codex-agents-parity"
  require_same \
    ".codex/skills/work-orchestration/references/$conditional_route_reference" \
    ".claude/skills/work-orchestration/references/$conditional_route_reference" \
    "conditional-route-codex-claude-parity"
done
for mirrored_reference in \
  impact-and-source-map.md \
  pre-code-critic-assignment.md; do
  require_same \
    ".codex/skills/code-authoring/references/$mirrored_reference" \
    ".agents/skills/code-authoring/references/$mirrored_reference" \
    "work-item-profile-authoring-codex-agents-parity"
  require_same \
    ".codex/skills/code-authoring/references/$mirrored_reference" \
    ".claude/skills/code-authoring/references/$mirrored_reference" \
    "work-item-profile-authoring-codex-claude-parity"
done
require_portable_contract_same \
  "Child Contract" \
  "Existing Plan Execution" \
  "delegation-dispatch-portable-parity" \
  .codex/skills/work-orchestration/references/delegation.md \
  .agents/skills/work-orchestration/references/delegation.md \
  .claude/skills/work-orchestration/references/delegation.md
require_portable_contract_same \
  "Operating Model" \
  "Early Delegation Invariant" \
  "orchestration-route-boundary-parity" \
  .codex/skills/work-orchestration/SKILL.md \
  .agents/skills/work-orchestration/SKILL.md \
  .claude/skills/work-orchestration/SKILL.md
require_portable_contract_same \
  "Next-Action Index" \
  "Fast Exit" \
  "orchestration-next-action-index-parity" \
  .codex/skills/work-orchestration/SKILL.md \
  .agents/skills/work-orchestration/SKILL.md \
  .claude/skills/work-orchestration/SKILL.md
require_portable_contract_same \
  "Route Boundary Contract" \
  "Trigger" \
  "skill-eval-route-boundary-parity" \
  .codex/skills/skill-quality-evals/SKILL.md \
  .agents/skills/skill-quality-evals/SKILL.md \
  .claude/skills/skill-quality-evals/SKILL.md
require_same \
  .codex/skills/skill-quality-evals/references/real-model-behavior-evaluation.md \
  .agents/skills/skill-quality-evals/references/real-model-behavior-evaluation.md \
  "real-model-behavior-eval-codex-agents-parity"
require_same \
  .codex/skills/skill-quality-evals/references/real-model-behavior-evaluation.md \
  .claude/skills/skill-quality-evals/references/real-model-behavior-evaluation.md \
  "real-model-behavior-eval-codex-claude-parity"
require_portable_contract_same \
  "Route Boundary Contract" \
  "Ownership" \
  "worktree-route-boundary-parity" \
  .codex/skills/worktree-readiness/SKILL.md \
  .agents/skills/worktree-readiness/SKILL.md \
  .claude/skills/worktree-readiness/SKILL.md
require_same \
  .codex/skills/pr-workflow/references/local-ci-checks.md \
  .agents/skills/pr-workflow/references/local-ci-checks.md \
  "frontend-local-ci-contract-codex-agents-parity"
require_same \
  .codex/skills/pr-workflow/references/local-ci-checks.md \
  .claude/skills/pr-workflow/references/local-ci-checks.md \
  "frontend-local-ci-contract-codex-claude-parity"
for runtime in "${contract_runtimes[@]}"; do
  worktree_skill="$runtime/skills/worktree-readiness/SKILL.md"
  local_ci_reference="$runtime/skills/pr-workflow/references/local-ci-checks.md"
  require_text "$worktree_skill" \
    'find "$frontend_modules" -depth -delete || {' \
    "frontend-dependency-cleanup-fails-closed"
  require_text "$worktree_skill" \
    "install --frozen-lockfile --non-interactive" \
    "frontend-dependency-install-uses-yarn1-contract"
  require_text "$worktree_skill" \
    "diff --exit-code -- app/yarn.lock" \
    "frontend-dependency-install-preserves-lockfile"
  require_text "$worktree_skill" \
    'nonwritable_next_path=$(find "$frontend_next" ! -writable -print -quit) || {' \
    "frontend-build-cache-detects-non-writable-state"
  require_text "$worktree_skill" \
    "could not inspect build cache ownership" \
    "frontend-build-cache-inspection-fails-closed"
  require_text "$worktree_skill" \
    'find "$frontend_next" -depth -delete || {' \
    "frontend-build-cache-cleanup-fails-closed"
  require_text "$local_ci_reference" \
    "yarn --cwd app prettier:files path/to/file.tsx" \
    "frontend-targeted-prettier-contract"
  forbid_text "$worktree_skill" \
    "--immutable --immutable-cache --update-lockfile" \
    "frontend-dependency-install-rejects-yarn2-flags"
  forbid_text "$local_ci_reference" \
    "--immutable --immutable-cache --update-lockfile" \
    "frontend-local-ci-rejects-yarn2-flags"
done
require_text app/package.json \
  '"prettier:files": "prettier --plugin=@trivago/prettier-plugin-sort-imports --check"' \
  "frontend-targeted-prettier-script"
require_text app/package.json \
  '"prettier:fix:files": "prettier --plugin=@trivago/prettier-plugin-sort-imports --write"' \
  "frontend-targeted-prettier-fix-script"
require_text scripts/dev/claude-format-on-edit.sh \
  "yarn --silent prettier:fix:files" \
  "claude-format-hook-uses-targeted-prettier-script"

require_text .codex/agents/reviewer.toml \
  'model = "gpt-6.1-sol"' \
  "senior-review-owner-native-codex-model"
require_text .codex/agents/reviewer.toml \
  'model_reasoning_effort = "max"' \
  "senior-review-owner-native-codex-effort"
for verdict_role in critic database-reviewer security-auditor devops; do
  require_text ".codex/agents/${verdict_role}.toml" \
    'model = "gpt-6.1-sol"' \
    "senior-review-owner-native-codex-model"
  require_text ".codex/agents/${verdict_role}.toml" \
    'model_reasoning_effort = "max"' \
    "senior-review-owner-native-codex-effort"
done
require_text .codex/skills/pr-workflow/references/review-worktree.md \
  "\`--model gpt-6.1-sol --effort high\`" \
  "senior-review-owner-headless-codex-effort"
require_text scripts/dev/agent-call-codex.sh \
  'effort="high"' \
  "codex-wrapper-default-effort"
require_text scripts/dev/agent-call-codex.sh \
  'effort="medium"' \
  "codex-wrapper-astra-default-effort"
require_text scripts/dev/agent-call-codex.sh \
  'xhigh|max|ultra)' \
  "codex-wrapper-elevated-effort-gate"
require_text scripts/dev/agent-call-codex.sh \
  '--allow-user-requested-elevated-effort because xhigh, max, and ultra are explicit-user-only' \
  "codex-wrapper-elevated-effort-authorization"
forbid_text .agents/skills/pr-workflow/references/review-worktree.md \
  "gpt-6.1-sol" \
  "senior-review-owner-no-codex-model-in-agents"
forbid_text .claude/skills/pr-workflow/references/review-worktree.md \
  "gpt-6.1-sol" \
  "senior-review-owner-no-codex-model-in-claude"

orchestration_evaluation_cases=.codex/skills/work-orchestration/references/orchestration-evaluation-cases.md
require_file "$orchestration_evaluation_cases" \
  "orchestration-evaluation-case-catalog"
require_text "$orchestration_evaluation_cases" \
  "write one secret-safe gitignored checkpoint owned by the stable session ID" \
  "orchestration-eval-same-session-checkpoint"
require_text "$orchestration_evaluation_cases" \
  "Possible work-unit decomposition" \
  "orchestration-eval-early-delegation-decision"
require_text "$orchestration_evaluation_cases" \
  'AUTHORING_RESET_REQUIRED' \
  "orchestration-eval-targeted-followup-circuit-breaker"
require_text "$orchestration_evaluation_cases" \
  "Third broad review request" \
  "orchestration-eval-third-broad-round"
forbid_text "$orchestration_evaluation_cases" \
  "Response-only checkpoint by default" \
  "orchestration-eval-no-response-only-tangent"
forbid_text "$orchestration_evaluation_cases" \
  "missing session ID or artifact-write permission must not freeze the tangent" \
  "orchestration-eval-no-session-identity-bypass"

for plan_behavior_case in \
  intent-alignment-activation-and-fallback \
  plan-acceptance-version-lifecycle \
  plan-conformance-bidirectional; do
  require_file \
    "evals/work-orchestration/behavior-tasks/$plan_behavior_case.yaml" \
    "plan-contract-behavior-case"
  require_file \
    "evals/work-orchestration/rubrics/$plan_behavior_case.md" \
    "plan-contract-behavior-rubric"
  require_text evals/work-orchestration/behavior-eval.yaml \
    "behavior-tasks/$plan_behavior_case.yaml" \
    "plan-contract-behavior-manifest"
done
require_text \
  evals/work-orchestration/rubrics/intent-alignment-activation-and-fallback.md \
  "ordinary localized reversible work proceeds" \
  "intent-alignment-ordinary-nonactivation-oracle"
require_text \
  evals/work-orchestration/rubrics/plan-acceptance-version-lifecycle.md \
  "terminal critic disposition, and only then obtains explicit user approval" \
  "plan-acceptance-critic-revision-oracle"
require_text \
  evals/work-orchestration/rubrics/plan-conformance-bidirectional.md \
  "two missing preserved README sections" \
  "plan-conformance-same-file-loss-oracle"
require_text \
  evals/work-orchestration/rubrics/plan-conformance-bidirectional.md \
  "reviewer must reconstruct both mappings from the diff" \
  "plan-conformance-reviewer-independent-oracle"
require_text \
  evals/work-orchestration/behavior-tasks/plan-conformance-bidirectional.yaml \
  "ledger.{0,50}(unsupported|contradicted|not proof)" \
  "plan-conformance-ledger-rejection-positive-proof"
forbid_text \
  evals/work-orchestration/behavior-tasks/plan-conformance-bidirectional.yaml \
  "(trust|accept).{0,30}(parent|author)" \
  "plan-conformance-no-negation-hostile-ledger-regex"

require_text .github/copilot-instructions.md \
  "If that tool is unavailable, ask one blocking plain-text question and stop" \
  "copilot-parent-question-capability-fallback"
require_text .github/copilot-instructions.md \
  "confidence do not waive explicit approval" \
  "copilot-high-impact-intent-approval"
for copilot_child in \
  .github/agents/security-auditor.agent.md \
  .github/agents/tester.agent.md; do
  require_text "$copilot_child" \
    "do not use #tool:vscode/askQuestions or ask the user directly" \
    "copilot-child-parent-question-ownership"
done

require_text docs/agents/agent-violation-examples.md \
  "## Treating File Scope As Plan Conformance" \
  "plan-conformance-violation-example"
require_text docs/agents/instruction-preservation-ledger.md \
  'Instruction preservation row `bidirectional-plan-conformance`:' \
  "plan-conformance-preservation-ledger"

require_file scripts/dev/run-behavior-eval.rb \
  "behavior-eval-vpn-route-selector"
require_text scripts/dev/run-behavior-eval.rb \
  'PI_PROVIDER = "openai-codex"' \
  "behavior-eval-pi-provider"
require_text scripts/dev/run-behavior-eval.rb \
  'PI_MODEL = "gpt-5.6-luna"' \
  "behavior-eval-pi-model"
require_text scripts/dev/run-behavior-eval.rb \
  'PI_THINKING = "low"' \
  "behavior-eval-pi-thinking"
require_text scripts/dev/run-behavior-eval.rb \
  'Pi model catalog does not advertise' \
  "behavior-eval-pi-model-catalog-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  'Pi auth is not ready through OpenAI Codex OAuth' \
  "behavior-eval-pi-oauth-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  '"--no-tools", "--no-extensions", "--no-skills", "--no-prompt-templates"' \
  "behavior-eval-pi-isolation-flags"
require_text scripts/dev/run-behavior-eval.rb \
  'inline config.prompt graders are unsupported' \
  "behavior-eval-inline-prompt-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  'VPN route requires --waza-model because the suite execution model is unresolved' \
  "behavior-eval-waza-model-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  'VPN route requires --waza-judge-model because a prompt-grader model is unresolved' \
  "behavior-eval-waza-judge-model-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  'with_waza_overlay' \
  "behavior-eval-waza-isolated-overlay"
require_text scripts/dev/run-behavior-eval.rb \
  'Waza behavior contract written to' \
  "behavior-eval-waza-result-contract"
require_text scripts/dev/run-behavior-eval.rb \
  'refusing to overwrite behavior result' \
  "behavior-eval-result-no-overwrite"
require_text scripts/dev/run-behavior-eval.rb \
  'candidate_digest' \
  "behavior-eval-candidate-digest"
require_text scripts/dev/run-behavior-eval.rb \
  'Pi trace contains tool activity' \
  "behavior-eval-tool-audit-fail-closed"
require_text scripts/dev/run-behavior-eval.rb \
  'Pi trace identity is not provider-side telemetry' \
  "behavior-eval-model-identity-honesty"
require_text evals/README.md \
  '--instruction-file .codex/skills/database-reviewer/references/verdict-closeout.md' \
  "behavior-eval-database-closeout-input"
require_text evals/README.md \
  '`--route no-vpn --dry-run`' \
  "behavior-eval-no-vpn-dry-run-example"
for database_prompt_case in \
  peer-challenge-reassessment \
  production-ready-persisted-state-necessity; do
  require_text \
    "evals/database-reviewer/behavior-tasks/$database_prompt_case.yaml" \
    "rubric: evals/database-reviewer/rubrics/$database_prompt_case.md" \
    "database-behavior-output-aware-rubric"
  forbid_text \
    "evals/database-reviewer/behavior-tasks/$database_prompt_case.yaml" \
    '      prompt: |' \
    "database-behavior-no-inline-prompt-grader"
  require_text \
    "evals/database-reviewer/rubrics/$database_prompt_case.md" \
    'set_waza_grade_pass' \
    "database-behavior-rubric-native-pass"
  require_text \
    "evals/database-reviewer/rubrics/$database_prompt_case.md" \
    'set_waza_grade_fail' \
    "database-behavior-rubric-native-fail"
done

if [[ "$runtime_scope" == "all" ]]; then
  diff -qr .codex/skills/code-authoring .agents/skills/code-authoring
  diff -qr .codex/skills/code-authoring .claude/skills/code-authoring
  diff -qr .codex/skills/reviewer .agents/skills/reviewer
  diff -qr .codex/skills/reviewer .claude/skills/reviewer
  diff -qr .codex/skills/database-reviewer .agents/skills/database-reviewer
  diff -qr .codex/skills/database-reviewer .claude/skills/database-reviewer
  diff -qr -x context-recovery.md \
    .agents/skills/work-orchestration \
    .claude/skills/work-orchestration
  require_text \
    .agents/skills/work-orchestration/references/context-recovery.md \
    "## Return From A Temporary Side Task" \
    "agents-claude-orchestration-divergence"
  require_text \
    .claude/skills/work-orchestration/references/context-recovery.md \
    "load the checkpoint created through" \
    "agents-claude-orchestration-divergence"
fi

require_text .codex/skills/work-orchestration/SKILL.md \
  "Before proposing a cross-harness council" \
  "codex-orchestration-divergence"
require_text .codex/skills/work-orchestration/SKILL.md \
  "Escalate to cross-harness council only when" \
  "codex-orchestration-divergence"
forbid_text .agents/skills/work-orchestration/SKILL.md \
  "Before proposing a cross-harness council" \
  "codex-orchestration-divergence"
forbid_text .claude/skills/work-orchestration/SKILL.md \
  "Before proposing a cross-harness council" \
  "codex-orchestration-divergence"

if [[ "$runtime_scope" == "codex" ]]; then
  echo "Codex workflow contract scenarios passed; mirror parity not assessed"
else
  echo "agent workflow contract scenarios passed"
fi
