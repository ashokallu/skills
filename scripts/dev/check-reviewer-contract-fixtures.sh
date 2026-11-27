#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v ruby >/dev/null 2>&1; then
  echo "ruby is required for reviewer contract fixture checks" >&2
  exit 1
fi

ruby <<'RUBY'
require "digest"
require "pathname"
require "yaml"

class FixtureError < StandardError; end

ROOT = Pathname.pwd.realpath
require ROOT.join("scripts/dev/lib/reviewer_packet_validator").to_s
SUITE_PATH = ROOT.join("evals/reviewer/contract-fixtures/fixtures.yaml")
CONTROL_FIXTURE_PATH = ROOT.join("evals/reviewer/contract-fixtures/reviewer-control-plane.yaml")
PACKET_DOC_PATH = ROOT.join("docs/agents/pr-review-packet-format.md")
DOCUMENTED_ORDER_PACKET_PATH = ROOT.join("evals/reviewer/contract-fixtures/documented-order-review-comments-packet.txt")
EXPECTED_ROUTE_FIELDS = %w[mode target side_effects risk_class success_evidence].freeze
EXPECTED_CLOSEOUT_CATEGORIES = %w[
  consequence_advisory
  simplification
  documentation_truth
  naming_readability
].freeze
EXPECTED_REVIEW_MODES = %w[github_pr branch_local direct_sql].freeze
EXPECTED_VERDICTS = %w[PASS PASS_WITH_FINDINGS FAIL BLOCKED].freeze
EXPECTED_DEPTHS = %w[LITE STANDARD FULL].freeze
EXPECTED_TOPOLOGIES = %w[single council].freeze
EXPECTED_COMMON_CLOSURE = %w[
  exact_target_and_base
  admitted_surface_inventory
  changed_contract_and_immediate_effects
  mandatory_floor_detection
  claimed_proof_assessment
  per_surface_disposition
  impact_cone_closure
  stop_proof
].freeze
EXPECTED_FULL_FLOORS = %w[
  auth_security_privacy
  shared_database_contract
  migration_data_integrity
  public_contract
  infrastructure_release
  production_blast_radius
  cross_system_ownership
  central_missing_proof
  unbounded_or_contested_cone
  senior_pr_owner_whole_target
].freeze
EXPECTED_SENIOR_REVIEW_EXCLUSIONS = %w[
  summary
  metadata
  ci
  existing_comments_only
  triage
  fix
  workflow_explanation
  targeted_re_review
].freeze
EXPECTED_DEPTH_MUTATIONS = %w[
  collapsed-depth-obligations
  missing-common-closure
  missing-full-floor
  suppressed-triggered-coverage
  scope-token-in-strict-packet
  parent-suppresses-escalation
  evidence-free-expansion
  missing-full-primer
  missing-preservation-row
  progress-in-strict-packet
  autonomous-progress
  repeated-unchanged-progress
  timer-derived-closeout
  parent-semantic-rewrite
  parent-parallel-review
  database-join-loss
].freeze
EXPECTED_EXPANSION_TRIGGERS = %w[
  reachable_caller_or_consumer
  crossed_runtime_data_auth_api_security_operator_boundary
  sibling_shared_invariant_or_failure_mechanism
  verdict_changing_artifact
  mandatory_floor
].freeze
EXPECTED_SCOPE_MESSAGES = %w[
  REVIEW_SCOPE_PROPOSAL
  REVIEW_SCOPE_ACCEPTED
  REVIEW_SCOPE_ESCALATION
  ESCALATION_ACCEPTED
  SCOPE_EVIDENCE_CORRECTION
  CORRECTED_AND_ACCEPTED
  SCOPE_DISPUTE_BLOCKED
].freeze
JOIN_PRECEDENCE = {
  "INPUT" => "JOIN_NEEDS_INPUT",
  "DEFECT" => "JOIN_BLOCKED_DEFECT",
  "EVIDENCE" => "JOIN_BLOCKED_EVIDENCE",
  "ACTION" => "JOIN_ACTION_REQUIRED",
  "CAVEATS" => "JOIN_READY_WITH_CAVEATS",
  "CLEAN" => "JOIN_READY_CLEAN"
}.freeze
CANONICAL_CLOSEOUT_PATHS = %w[
  .codex/skills/reviewer/references/review-closeout-lens.md
  .agents/skills/reviewer/references/review-closeout-lens.md
  .claude/skills/reviewer/references/review-closeout-lens.md
].freeze
LEGACY_CLOSEOUT_ALIASES = {
  "inline-advisory-review.md" => "consequence_advisory",
  "code-simplification-lens.md" => "simplification",
  "documentation-staleness-lens.md" => "documentation_truth",
  "nitpick-review-lane.md" => "naming_readability"
}.freeze
MANDATORY_PHASES = %w[
  review-bootstrap.md
  review-analysis-routing.md
  review-verdict-closeout.md
].freeze
EXPLICIT_ACTIVE_CALLER_PATHS = %w[
  .codex/skills/reviewer/SKILL.md
  .agents/skills/reviewer/SKILL.md
  .claude/skills/reviewer/SKILL.md
  .codex/agents/reviewer.toml
  .agents/plugins/project/agents/reviewer.md
  .claude/agents/reviewer.md
  .github/agents/reviewer.agent.md
  .codex/skills/pr-workflow/references/review-worktree.md
  .agents/skills/pr-workflow/references/review-worktree.md
  .claude/skills/pr-workflow/references/review-worktree.md
].freeze
ACTIVE_REFERENCE_PATHS = %w[.codex .agents .claude].flat_map do |runtime|
  Dir[ROOT.join(runtime, "skills/reviewer/references/*.md")].map do |path|
    Pathname(path).relative_path_from(ROOT).to_s
  end
end.reject do |relative|
  filename = File.basename(relative)
  filename == "review-closeout-lens.md" ||
    LEGACY_CLOSEOUT_ALIASES.key?(filename) ||
    MANDATORY_PHASES.include?(filename)
end.freeze
ACTIVE_CALLER_PATHS = (EXPLICIT_ACTIVE_CALLER_PATHS + ACTIVE_REFERENCE_PATHS).uniq.sort.freeze
ROLE_PATHS = %w[
  .codex/agents/reviewer.toml
  .agents/plugins/project/agents/reviewer.md
  .claude/agents/reviewer.md
  .github/agents/reviewer.agent.md
].freeze
STALE_ACTIVE_LOAD_PHRASES = [
  "documentation-staleness lens",
  "documentation staleness lens",
  "documentation staleness",
  "code-simplification lens",
  "stale-doc",
  "nitpick closeout",
  "full parser-facing packet below"
].freeze
EXPECTED_CASE_IDS = %w[
  packet-valid-skeleton
  packet-valid-with-finding
  packet-valid-unanchored-blocking
  packet-valid-review-comment-adversarial
  packet-invalid-skeleton-terminator
  central-blocking-verdict
  closeout-consequence-advisory
  closeout-simplification
  closeout-documentation-truth
  closeout-naming-readability
  overlap-dedupe-single-root
  pure-nit-suppression
  stale-operator-documentation
  unsafe-over-simplification
  clean-control
  branch-local-without-pr-packet
  direct-sql-without-pr-packet
].freeze

def fail_fixture(message)
  raise FixtureError, message
end

def expect_fixture_failure(label)
  yield
rescue FixtureError
  return
else
  fail_fixture("#{label} negative mutation was not rejected")
end

def load_yaml(path)
  YAML.safe_load(path.read, permitted_classes: [], aliases: false) || {}
rescue Psych::Exception => e
  fail_fixture("invalid YAML in #{path.relative_path_from(ROOT)}: #{e.message}")
end

def exact_keys!(mapping, required, allowed, context)
  fail_fixture("#{context} must be a mapping") unless mapping.is_a?(Hash)
  keys = mapping.keys.map(&:to_s)
  missing = required - keys
  unknown = keys - allowed
  fail_fixture("#{context} missing keys: #{missing.join(', ')}") unless missing.empty?
  fail_fixture("#{context} has unknown keys: #{unknown.join(', ')}") unless unknown.empty?
end

def resolve_repo_path(value, context)
  fail_fixture("#{context} path must be a non-empty string") unless value.is_a?(String) && !value.empty?
  path = ROOT.join(value).cleanpath
  unless path.to_s == ROOT.to_s || path.to_s.start_with?(ROOT.to_s + File::SEPARATOR)
    fail_fixture("#{context} path escapes repository: #{value}")
  end
  path
end

def validate_transport_reference(reference)
  exact_keys!(reference, %w[path sha256], %w[path sha256], "transport reference")
  path = resolve_repo_path(reference.fetch("path"), "transport reference")
  return :transport_missing unless path.file?

  digest = reference.fetch("sha256")
  fail_fixture("transport sha256 must be 64 lowercase hex characters") unless digest.is_a?(String) && digest.match?(/\A[0-9a-f]{64}\z/)
  return :transport_digest_mismatch unless Digest::SHA256.file(path).hexdigest == digest

  :ok
end

def packet_structure_errors(sample, transport, formal_findings:)
  lines = sample.lines(chomp: true)
  expected_target = lines.find { |line| line.start_with?("Review target:") }&.split(":", 2)&.last&.strip.to_s
  expected_mode = lines.find { |line| line.start_with?("Review mode:") }&.split(":", 2)&.last&.strip.to_s
  result = ReviewerPacketValidator.validate(
    source_bytes: sample,
    transport: transport,
    review_comments_transport: @review_comments_transport || {},
    expected_target: expected_target,
    expected_mode: expected_mode,
    review_comments: "optional"
  )
  errors = result.issues.filter_map do |issue|
    code = {
      "RPPA-002" => issue.code,
      "RPPA-004" => issue.code,
      "RPPA-005" => issue.code,
      "RPPA-007" => issue.code
    }[issue.rule_id]
    code == "content_after_or_duplicate_terminator" ? "content_after_terminator" : code
  end
  errors << "finding_count_mismatch" unless ReviewerPacketValidator.finding_blocks(sample).length == formal_findings
  errors.uniq
end

def finding_blocks(sample)
  ReviewerPacketValidator.finding_blocks(sample)
end

def actionable_finding_errors(sample)
  ReviewerPacketValidator.actionable_finding_errors(sample)
end

def review_comment_blocks(sample, transport)
  ReviewerPacketValidator.review_comment_blocks(sample, transport)
rescue ReviewerPacketValidator::DecodeError => e
  fail_fixture(e.message)
end

def review_comment_errors(sample, transport, required: false)
  ReviewerPacketValidator.review_comment_errors(sample, transport, required: required)
end

def packet_acceptance_result(sample, transport, review_comments_transport, target:, mode:, comments:)
  ReviewerPacketValidator.validate(
    source_bytes: sample,
    transport: transport,
    review_comments_transport: review_comments_transport,
    expected_target: target,
    expected_mode: mode,
    review_comments: comments
  )
end

def expect_packet_rule!(label, result, rule_id)
  fail_fixture("#{label} unexpectedly accepted") if result.accepted
  actual = result.issues.map(&:rule_id)
  fail_fixture("#{label} did not report #{rule_id}: #{actual.join(', ')}") unless actual.include?(rule_id)
end

def active_caller_errors(body)
  errors = LEGACY_CLOSEOUT_ALIASES.keys.select do |filename|
    basename = filename.delete_suffix(".md")
    body.match?(/#{Regexp.escape(basename)}(?:\.md)?/)
  end
  errors.concat(STALE_ACTIVE_LOAD_PHRASES.select { |phrase| body.include?(phrase) })
  errors
end

def erp_doc_errors(section, fields)
  errors = []
  errors << "packet_type_boundary" unless section.include?("not a final parser-facing PR review verdict packet") && section.include?("must not inherit")
  offsets = fields.map do |field|
    offset = section.index("#{field}:")
    errors << "missing_field:#{field}" unless offset
    offset
  end
  errors << "field_order" if offsets.none?(&:nil?) && offsets != offsets.sort
  errors
end

def reviewer_phase_graph_errors(skill)
  offsets = MANDATORY_PHASES.map do |filename|
    offset = skill.index("references/#{filename}")
    [filename, offset]
  end
  errors = offsets.filter_map { |filename, offset| "missing_phase:#{filename}" unless offset }
  present_offsets = offsets.map(&:last).compact
  errors << "phase_order" unless present_offsets == present_offsets.sort
  errors
end

def candidate_for(fixture)
  reviewer = fixture.fetch("reviewer")
  verdict = fixture.fetch("verdict")
  findings = fixture.fetch("findings")
  p01 = findings.any? { |severity| %w[P0 P1].include?(severity) }
  p23 = findings.any? { |severity| %w[P2 P3].include?(severity) }
  central = fixture.fetch("central_missing_proof")
  caveat = fixture.fetch("caveat")
  action = fixture.fetch("next_action")

  return "INPUT" if verdict == "NEEDS_INPUT"
  return "DEFECT" if reviewer == "ordinary" && verdict == "FAIL"
  return "DEFECT" if %w[ordinary database].include?(reviewer) && verdict == "BLOCKED" && p01
  return "INPUT" if p01
  return "EVIDENCE" if verdict == "BLOCKED" && central
  return "INPUT" if central || verdict == "BLOCKED" || verdict == "FAIL"
  return "ACTION" if p23 || action
  return "CAVEATS" if caveat && %w[PASS PASS_WITH_FINDINGS].include?(verdict)
  return "CLEAN" if verdict == "PASS"

  "INPUT"
end

def join_for(candidates, conflict)
  return "JOIN_NEEDS_INPUT" if conflict

  JOIN_PRECEDENCE.each do |candidate, join|
    return join if candidates.include?(candidate)
  end
  nil
end

def exact_contract_errors(actual, expected, label)
  return [] if actual == expected

  ["#{label}_drift"]
end

def strict_packet_scope_errors(sample, forbidden_tokens)
  forbidden_tokens.select { |token| sample.include?(token) }
end

def preservation_row_errors(body, row_ids)
  row_ids.reject do |row_id|
    body.include?("Instruction preservation row `#{row_id}`")
  end
end

closeout_bodies = CANONICAL_CLOSEOUT_PATHS.map do |relative|
  path = ROOT.join(relative)
  fail_fixture("canonical closeout lens missing: #{relative}") unless path.file?
  path.read
end
fail_fixture("canonical closeout lens mirror drift") unless closeout_bodies.uniq.length == 1

closeout_body = closeout_bodies.first
category_offsets = EXPECTED_CLOSEOUT_CATEGORIES.map do |category|
  offset = closeout_body.index("### `#{category}`")
  fail_fixture("canonical closeout lens missing ordered marker: #{category}") unless offset
  offset
end
fail_fixture("canonical closeout category order drifted") unless category_offsets == category_offsets.sort

%w[.codex .agents .claude].each do |runtime|
  references = ROOT.join(runtime, "skills/reviewer/references")
  LEGACY_CLOSEOUT_ALIASES.each do |filename, category|
    alias_path = references.join(filename)
    fail_fixture("legacy closeout alias missing: #{alias_path.relative_path_from(ROOT)}") unless alias_path.file?
    body = alias_path.read
    fail_fixture("legacy closeout alias too large: #{filename}") unless body.lines.length.between?(10, 18)
    fail_fixture("legacy closeout alias missing canonical pointer: #{filename}") unless body.include?("review-closeout-lens.md")
    fail_fixture("legacy closeout alias missing category: #{filename} -> #{category}") unless body.include?("##{category}")
    fail_fixture("legacy closeout alias contains divergent probes: #{filename}") if body.include?("## Review Probes")
  end

  skill = ROOT.join(runtime, "skills/reviewer/SKILL.md").read
  phase_errors = reviewer_phase_graph_errors(skill)
  fail_fixture("reviewer phase graph invalid for #{runtime}: #{phase_errors.join(', ')}") unless phase_errors.empty?

  phase_bodies = MANDATORY_PHASES.to_h do |filename|
    path = references.join(filename)
    fail_fixture("mandatory reviewer phase missing: #{path.relative_path_from(ROOT)}") unless path.file?
    [filename, path.read]
  end
  fail_fixture("bootstrap phase lost pre-evidence stop") unless phase_bodies.fetch("review-bootstrap.md").include?("before that session gathers")
  fail_fixture("analysis phase lost target recomputation") unless phase_bodies.fetch("review-analysis-routing.md").include?("recompute lenses")
  fail_fixture("verdict phase lost packet owner") unless phase_bodies.fetch("review-verdict-closeout.md").include?("docs/agents/pr-review-packet-format.md")
  fail_fixture("verdict phase must own one canonical closeout run") unless phase_bodies.fetch("review-verdict-closeout.md").scan(/run `review-closeout-lens\.md` exactly once/i).length == 1

  catalog = skill.split("## Eager Lens Catalog", 2).fetch(1).split("The following files are compatibility aliases", 2).first
  selectable = Dir[references.join("*.md")].map { |path| File.basename(path) }.select do |filename|
    filename.end_with?("-lens.md") && !LEGACY_CLOSEOUT_ALIASES.key?(filename)
  end
  selectable.each do |filename|
    count = catalog.scan("`#{filename}`").length
    fail_fixture("selectable lens must appear exactly once in eager catalog: #{runtime}/#{filename} -> #{count}") unless count == 1
  end
  LEGACY_CLOSEOUT_ALIASES.each_key do |filename|
    fail_fixture("compatibility alias became selectable in eager catalog: #{runtime}/#{filename}") if catalog.include?("`#{filename}`")
    fail_fixture("kernel does not identify compatibility alias: #{runtime}/#{filename}") unless skill.include?("`#{filename}`")
  end

  missing_bootstrap = skill.gsub("references/review-bootstrap.md", "references/missing-bootstrap.md")
  fail_fixture("missing beginning phase mutation was not rejected") unless reviewer_phase_graph_errors(missing_bootstrap).include?("missing_phase:review-bootstrap.md")
  missing_analysis = skill.gsub("references/review-analysis-routing.md", "references/missing-analysis.md")
  fail_fixture("missing middle phase mutation was not rejected") unless reviewer_phase_graph_errors(missing_analysis).include?("missing_phase:review-analysis-routing.md")
  missing_closeout = skill.gsub("references/review-verdict-closeout.md", "references/missing-closeout.md")
  fail_fixture("missing end phase mutation was not rejected") unless reviewer_phase_graph_errors(missing_closeout).include?("missing_phase:review-verdict-closeout.md")

  fail_fixture("direct SQL mode pulls in PR packet machinery") unless skill.include?("do not load PR-only packet machinery")
  fail_fixture("optional lens fallback missing") unless skill.include?("Missing an optional domain lens") && skill.include?("Pending Verification")
  fail_fixture("mandatory phase failure does not block") unless skill.include?("Missing mandatory phase reference") && skill.include?("blocks substantive verdict emission")
  fail_fixture("packet acceptance bypasses beginning phase") if skill.include?("routes directly to the end phase")
  fail_fixture("packet acceptance does not enter beginning phase") unless skill.include?("soft-pedaled proved gaps enters the beginning phase")
  fail_fixture("packet acceptance lacks bounded middle analysis") unless skill.include?("bounded packet-artifact inventory")
  fail_fixture("reviewer kernel lost accepted FULL primer activation") unless skill.include?("Accepted `FULL` scope activates") && skill.include?("newly admitted whole-target initial")
  fail_fixture("reviewer kernel lost exact live primer read") unless skill.include?("`docs/agents/pr-4713-review-thoroughness-case-study.md` through EOF") && skill.include?("every page or chunk")
  fail_fixture("reviewer kernel permits primer substitutes") unless skill.include?("first-N-line peeks, summaries, injected") && skill.include?("another agent's read are not substitutes")
  fail_fixture("reviewer kernel lost private primer identity") unless skill.include?("privately record the immutable identity")
  fail_fixture("reviewer kernel lets primer replace native review law") unless skill.include?("reviewer role, mandatory phase contracts, evidence law, mandatory floors,") && skill.include?("stop proof remain authoritative")
  fail_fixture("reviewer kernel permits assignment replacement bypass") unless skill.include?("Restoring live-file readability for that same accepted review is the") && skill.include?("Canceling, replacing, or relabeling the assignment")

  analysis = phase_bodies.fetch("review-analysis-routing.md")
  fail_fixture("PR matrix lost always-mandatory intent lens") unless analysis.include?("Every GitHub PR or PR-bound verdict") && analysis.include?("review-intent-understanding-lens.md")
  fail_fixture("PR matrix lost conditional stack/thread row") unless analysis.include?("Stack lineage, follow-up lineage, fetched prior threads/comments") && analysis.include?("pr-stack-followup-thread-lens.md")
  fail_fixture("PR matrix lost conditional AI/conventions row") unless analysis.include?("Broad, generated, refactor, mechanical, multi-domain, placeholder-heavy, or suspiciously fluent target") && analysis.include?("ai-large-change-lens.md") && analysis.include?("existing-conventions-lens.md")
  fail_fixture("tiny docs-only PR exemption lost") unless analysis.include?("Do not load AI/large-change or existing-conventions for tiny docs-only targets")
  fail_fixture("ordinary review lost common admitted-surface closure") unless analysis.include?("give every admitted surface a lens, bounded micro-probe,") && analysis.include?("evidenced `not loaded` disposition")
  fail_fixture("ordinary impact-cone expansion lacks evidence law") unless analysis.include?("Record the trigger, evidence, added boundary, and defect class")
  fail_fixture("ordinary LITE still forces an independent residual pass") unless analysis.include?("omit an otherwise untriggered residual pass")
  fail_fixture("ordinary LITE can preload optional lenses during receipt planning") unless analysis.include?("do not open an optional lens merely to learn whether its trigger") && analysis.include?("private rename's stated intent belongs to the common admission floor")

  bootstrap = phase_bodies.fetch("review-bootstrap.md")
  fail_fixture("review bootstrap lost conditional initial FULL primer") unless bootstrap.include?("newly admitted whole-target initial ordinary review") && bootstrap.include?("read the live file through EOF")
  fail_fixture("proposed FULL activates the primer") unless bootstrap.include?("A proposed `FULL` depth does not activate the primer")
  fail_fixture("focused re-review activates the primer") unless bootstrap.include?("focused re-review, regardless of session freshness or inherited")
  fail_fixture("review primer permits partial read") unless bootstrap.include?("Continue through every page or") && bootstrap.include?("Search or grep hits, excerpts, first-N-line peeks, summaries")
  fail_fixture("review primer reuse lacks content identity") unless bootstrap.include?("content identity remains unchanged")
  fail_fixture("review primer emits a public recital") unless bootstrap.include?("Do not emit an acknowledgement or agreement recital")
  fail_fixture("unreadable review primer does not fail closed") unless bootstrap.include?("block evidence-heavy analysis and substantive verdict emission")
  fail_fixture("unreadable review primer permits assignment replacement bypass") unless bootstrap.include?("Restoring live-file readability") && bootstrap.include?("Canceling, replacing, or")
  fail_fixture("review primer can control evidence or scope") unless bootstrap.include?("cannot select lenses, expand the impact cone, create a") && bootstrap.include?("finding quota, prove a finding")

  fail_fixture("review analysis lost FULL primer entry guard") unless analysis.include?("newly admitted whole-target initial ordinary review") && analysis.include?("accepted depth") && analysis.include?("completed the private")
  fail_fixture("review analysis applies primer to lower depth or re-review") unless analysis.include?("never applies to `LITE`, `STANDARD`, or focused re-review")
  fail_fixture("review analysis treats primer as target evidence") unless analysis.include?("Primer content is not target evidence")

  conventions = references.join("existing-conventions-lens.md").read
  fail_fixture("triggered conventions selection bypasses finding filter") unless conventions.include?("Selecting the lens is mandatory when") && conventions.include?("emitting") && conventions.include?("a finding is not") && conventions.include?("current, reachable,") && conventions.include?("material, actionable, and deduplicated")
  fail_fixture("bounded conventions micro-probe missing") unless conventions.include?("bounded owner-first micro-probe") && analysis.include?("perform a micro-probe")
  fail_fixture("authoritative single-precedent rule missing") unless conventions.include?("one authoritative") && conventions.include?("bounded competing-pattern search")
  fail_fixture("conflicting-precedent expansion is unbounded") unless conventions.include?("precedents conflict") && conventions.include?("do not perform repository-wide archaeology")
  fail_fixture("no-standard default disposition missing") unless conventions.include?("emit no finding by default") && conventions.include?("selected-lens audit")
  fail_fixture("no-standard Pending Verification is unconditional") unless conventions.include?("only when the unresolved standard is material to the")
  fail_fixture("stronger-lens convention dedupe missing") unless conventions.include?("keep convention evidence internal") && conventions.include?("selected-lens audit") && conventions.include?("exactly one root-cause finding under the stronger")
  fail_fixture("justified discoverable divergence is not suppressible") unless conventions.include?("documented divergence") && conventions.include?("leaves a clear standard for") && conventions.include?("the next change is not convention drift")
  fail_fixture("pure convention nits are not suppressed") unless conventions.include?("tiny local name improvement with no search, maintenance, or dual-path")
  fail_fixture("conventions lens still forces two precedents universally") if conventions.include?("Collect **at least two** precedents") || conventions.include?("Inspect at least two precedents")
  fail_fixture("conventions lens still forces automatic convergence") if conventions.include?("force the diff to converge") || conventions.include?("use appropriate severity; still emit")

  worktree = ROOT.join(runtime, "skills/pr-workflow/references/review-worktree.md").read
  MANDATORY_PHASES.each do |filename|
    fail_fixture("review worktree does not dispatch reviewer phase: #{runtime}/#{filename}") unless worktree.include?(filename)
  end
  fail_fixture("review worktree still duplicates mandatory lens catalog") if worktree.include?("Always load exactly the GitHub PR review mandatory context lenses")
  fail_fixture("review worktree advertises background narrative lookup") if worktree.downcase.match?(/case[- ]study|historical learning|negative-pattern/)
  fail_fixture("review worktree lost current PR truth outside stack lens") unless worktree.match?(/Current head, body, thread\s+inventory, and head-pinned\s+checks remain required PR evidence/)

  database_skill = ROOT.join(runtime, "skills/database-reviewer/SKILL.md").read
  fail_fixture("database reviewer lost common admission floor") unless database_skill.include?("complete changed database") && database_skill.include?("one disposition for every admitted surface")
  fail_fixture("database reviewer LITE still forces broad residual") unless database_skill.include?("omit an otherwise untriggered broad residual sweep")
  fail_fixture("database reviewer lost every-triggered-lane floor") unless database_skill.include?("All depths close every admitted database surface and load every triggered lane")
  fail_fixture("database reviewer lost exact accepted scope token") unless database_skill.include?("`REVIEW_SCOPE_ACCEPTED:`") && database_skill.include?("Preserve the\ntrailing colon")
end

preservation_ledger = ROOT.join("docs/agents/instruction-preservation-ledger.md").read
preservation_row_ids = %w[
  reviewer-depth-common-closure
  pr-4685-review-lane-application
  pr-4713-coherent-and-residual-review
  pr-4713-soft-pedal-and-edge-state
  pr-4706-current-pr-truth
  pr-4706-publication-gates
  reviewer-background-read-retirement
  reviewer-full-initial-thoroughness-primer
  reviewer-owned-publication-and-progress
].freeze
missing_preservation_rows = preservation_row_errors(preservation_ledger, preservation_row_ids)
fail_fixture("proportional-depth preservation rows missing: #{missing_preservation_rows.join(', ')}") unless missing_preservation_rows.empty?
fail_fixture("conditional FULL primer lacks append-only supersession") unless preservation_ledger.include?("supersede only the universal-runtime portion of `reviewer-background-read-retirement`") && preservation_ledger.include?("archival-runtime disposition of `pr-4713-soft-pedal-and-edge-state`")

packet_doc = PACKET_DOC_PATH.read
fail_fixture("ordinary packet carrier lost lens trigger") unless packet_doc.include?("current-target trigger") && packet_doc.include?("concrete PR surface")
fail_fixture("ordinary packet carrier lost impact-cone coverage") unless packet_doc.include?("proved impact cone") && packet_doc.include?("evidence-backed expansions")

ACTIVE_CALLER_PATHS.each do |relative|
  next if relative.end_with?("/skills/reviewer/SKILL.md")

  body = ROOT.join(relative).read
  errors = active_caller_errors(body)
  fail_fixture("active caller contains legacy closeout load language: #{relative} -> #{errors.join(', ')}") unless errors.empty?
end

{
  "load references/documentation-staleness-lens.md" => "documentation-staleness-lens.md",
  "defer to documentation-staleness-lens" => "documentation-staleness-lens.md",
  "run stale-doc and nitpick closeout" => "stale-doc"
}.each do |sample, expected_error|
  errors = active_caller_errors(sample)
  fail_fixture("active caller negative mutation missed #{expected_error}") unless errors.include?(expected_error)
end

ROLE_PATHS.each do |relative|
  body = ROOT.join(relative).read
  MANDATORY_PHASES.each do |filename|
    fail_fixture("reviewer role does not bind mandatory phase #{filename}: #{relative}") unless body.include?(filename)
  end
  fail_fixture("reviewer role lost optional lens fallback: #{relative}") unless body.include?("If an optional lens cannot be read")
  fail_fixture("reviewer role lost mandatory-phase block: #{relative}") unless body.include?("block substantive verdict emission")
  unless body.include?("`Evidence Response Packet For Reassessment` section")
    fail_fixture("reviewer role does not point to canonical Evidence Response Packet fields: #{relative}")
  end
  fail_fixture("reviewer role lacks shared scope-control owner: #{relative}") unless body.include?("review-control-plane.md")
  fail_fixture("reviewer role can force disputed narrowing: #{relative}") unless body.include?("SCOPE_DISPUTE_BLOCKED")
  fail_fixture("reviewer role lost FULL primer fallback: #{relative}") unless body.include?("docs/agents/pr-4713-review-thoroughness-case-study.md")
  fail_fixture("reviewer role permits partial primer read: #{relative}") unless body.include?("continuing through every page or chunk") && body.include?("Grep hits, excerpts, summaries")
  fail_fixture("reviewer role activates primer for focused re-review: #{relative}") unless body.match?(/focused re-review do\s+not\s+activate this private primer/)
  fail_fixture("reviewer role permits public primer acknowledgement: #{relative}") unless body.include?("Never emit an acknowledgement")
  fail_fixture("reviewer role permits assignment replacement bypass: #{relative}") unless body.include?("Restoring live-file readability for that same accepted review") && body.include?("canceling, replacing, or relabeling")
end

%w[.codex .agents .claude].each do |runtime|
  references = ROOT.join(runtime, "skills/reviewer/references")
  analysis = references.join("review-analysis-routing.md").read
  closeout = references.join("review-verdict-closeout.md").read
  fail_fixture("verdict phase does not defer Evidence Response Packet fields: #{runtime}") unless closeout.include?("Evidence Response Packets") && closeout.include?("Do not reproduce that schema here")
  %w[bounded\ inventory Direct\ named-path every\ changed\ file].each do |marker|
    fail_fixture("analysis phase lacks direct named-path inventory contract: #{runtime} -> #{marker}") unless analysis.include?(marker.tr("\\", ""))
  end
  fail_fixture("direct SQL closeout loads PR-only fields: #{runtime}") if closeout.split("### Direct named SQL or migration safety review", 2).fetch(1).split("## Final Acceptance", 2).first.include?("required PR packet")
end

retired_checker = ["check-reviewer", "behavior-fixtures.sh"].join("-")
retired_checker_roots = %w[scripts/dev .codex .agents .claude docs]
retired_checker_roots.each do |relative|
  root = ROOT.join(relative)
  next unless root.exist?

  paths = root.directory? ? Dir[root.join("**/*")].select { |path| File.file?(path) } : [root.to_s]
  paths.each do |path|
    next unless File.read(path).include?(retired_checker)

    fail_fixture("retired reviewer fixture checker remains active: #{Pathname(path).relative_path_from(ROOT)}")
  end
end

LEGACY_CLOSEOUT_ALIASES.each do |filename, category|
  eval_bodies = Dir[ROOT.join("evals/reviewer/tasks/*.yaml")].map { |path| File.read(path) }
  fail_fixture("eval tasks missing alias/category binding: #{filename} -> #{category}") unless eval_bodies.any? { |body| body.include?(filename) && body.include?(category) && body.include?("review-closeout-lens.md") }
end

{
  "pure-nit non-counting" => "Pure nits are non-counting.",
  "single-root dedupe" => "emit exactly one disposition",
  "shared advisory budget" => "All four categories share one advisory budget.",
  "documentation final pass" => "documentation final consistency/navigation",
  "unsafe over-simplification" => "unsafe over-simplification check"
}.each do |contract, marker|
  fail_fixture("canonical closeout lens missing #{contract} marker: #{marker}") unless closeout_body.include?(marker)
end

%w[machine-specific process\ labels routine\ copied\ CI stale\ pending-CI].each do |marker|
  fail_fixture("canonical documentation closeout lost PR-body hygiene marker: #{marker}") unless closeout_body.include?(marker.tr("\\", ""))
end

control = load_yaml(CONTROL_FIXTURE_PATH)
exact_keys!(
  control,
  %w[schema_version contract_id depths topologies scope_control_messages strict_packet_forbidden_tokens progress_contract semantic_ownership packet_acceptance common_closure mandatory_full_floors named_floor_cases packet_carriers ordinary_depth_cases database_depth_cases expansion_cases negative_mutations projection_cases scope_cases candidate_cases join_cases],
  %w[schema_version contract_id depths topologies scope_control_messages strict_packet_forbidden_tokens progress_contract semantic_ownership packet_acceptance common_closure mandatory_full_floors named_floor_cases packet_carriers ordinary_depth_cases database_depth_cases expansion_cases negative_mutations projection_cases scope_cases candidate_cases join_cases],
  "review control-plane fixture"
)
fail_fixture("review control-plane schema_version must be 4") unless control["schema_version"] == 4 && control["contract_id"] == "reviewer-control-plane-v4"
fail_fixture("review control-plane depths drifted") unless control["depths"] == EXPECTED_DEPTHS
fail_fixture("review control-plane topologies drifted") unless control["topologies"] == EXPECTED_TOPOLOGIES
fail_fixture("review scope-control messages drifted") unless control["scope_control_messages"] == EXPECTED_SCOPE_MESSAGES
forbidden_tokens = control.fetch("strict_packet_forbidden_tokens")
fail_fixture("strict packet forbidden tokens are incomplete") unless forbidden_tokens == EXPECTED_SCOPE_MESSAGES + ["REVIEW_PROGRESS"]

progress = control.fetch("progress_contract")
progress_keys = %w[token reviewer_kinds delivery safe_boundary_required strict_packet autonomous_periodic repeat_unchanged time_band_authority closeout_authority fields]
exact_keys!(progress, progress_keys, progress_keys, "review progress contract")
fail_fixture("review progress token drifted") unless progress["token"] == "REVIEW_PROGRESS"
fail_fixture("review progress reviewer coverage drifted") unless progress["reviewer_kinds"] == %w[ordinary database]
fail_fixture("review progress is not pull-only") unless progress["delivery"] == "pull_only"
unless progress.values_at("safe_boundary_required", "strict_packet", "autonomous_periodic", "repeat_unchanged") == [true, false, false, false]
  fail_fixture("review progress lifecycle drifted")
end
fail_fixture("review progress time band gained authority") unless progress["time_band_authority"] == "advisory_metadata_only"
fail_fixture("review progress can force closeout") unless progress["closeout_authority"] == "closure_and_stop_proof_only"
expected_progress_fields = ["exact target", "phase", "completed surfaces", "remaining surfaces", "active candidates", "blockers", "scope changes", "next milestone", "advisory time band"]
fail_fixture("review progress fields drifted") unless progress["fields"] == expected_progress_fields

ownership = control.fetch("semantic_ownership")
ownership_keys = %w[reviewer_owns parent_owns parent_forbidden semantic_return second_semantic_review_triggers]
exact_keys!(ownership, ownership_keys, ownership_keys, "review semantic ownership")
fail_fixture("reviewer lost exact comment ownership") unless ownership.fetch("reviewer_owns").include?("exact review comment and summary bytes")
fail_fixture("parent lost mechanical integrity ownership") unless ownership.fetch("parent_owns").include?("finding ordinal partition") && ownership.fetch("parent_owns").include?("literal-block UTF-8 anchor event and decoration validation") && ownership.fetch("parent_owns").include?("sibling join integrity")
%w[parallel\ whole\ target\ semantic\ review comment\ body\ rewrite invented\ review\ feedback].each do |forbidden|
  fail_fixture("parent semantic prohibition missing: #{forbidden}") unless ownership.fetch("parent_forbidden").include?(forbidden.tr("\\", ""))
end
fail_fixture("semantic repair no longer returns to same reviewer") unless ownership["semantic_return"] == "same_reviewer"
expected_second_review = %w[malformed_or_blocked_reviewer material_contradiction target_change explicit_independent_review_request]
fail_fixture("second semantic review triggers drifted") unless ownership["second_semantic_review_triggers"] == expected_second_review

acceptance = control.fetch("packet_acceptance")
acceptance_keys = %w[lifecycle trusted_inputs accepted_unlocks rejected_unlocks repair_owner repair_attempts corrected_packet_revalidation repeated_malformed_terminal parent_semantic_reconstruction]
exact_keys!(acceptance, acceptance_keys, acceptance_keys, "review packet acceptance")
fail_fixture("packet acceptance lifecycle drifted") unless acceptance["lifecycle"] == %w[RETURNED VALIDATING ACCEPTED REJECTED]
fail_fixture("packet acceptance trusted inputs drifted") unless acceptance["trusted_inputs"] == ["exact target", "review mode", "review-comments contract"]
fail_fixture("packet acceptance downstream gates drifted") unless acceptance["accepted_unlocks"] == ["sibling join", "bounded closeout", "publication", "packet-compliance claim"]
fail_fixture("rejected packets gained downstream authority") unless acceptance["rejected_unlocks"] == []
unless acceptance.values_at("repair_owner", "repair_attempts", "corrected_packet_revalidation", "repeated_malformed_terminal", "parent_semantic_reconstruction") == ["same reviewer", 1, "full", "terminal-malformed-or-replacement", "forbidden"]
  fail_fixture("packet repair lifecycle drifted")
end
closure_errors = exact_contract_errors(control["common_closure"], EXPECTED_COMMON_CLOSURE, "common_closure")
fail_fixture("common reviewer closure drifted") unless closure_errors.empty?
floor_errors = exact_contract_errors(control["mandatory_full_floors"], EXPECTED_FULL_FLOORS, "mandatory_full_floors")
fail_fixture("mandatory FULL floors drifted") unless floor_errors.empty?

named_floor_cases = control.fetch("named_floor_cases")
fail_fixture("expected one named review floor") unless named_floor_cases.length == 1
senior_floor = named_floor_cases.first
exact_keys!(
  senior_floor,
  %w[id route depth topology demotable excluded_intents],
  %w[id route depth topology demotable excluded_intents],
  "named senior review floor"
)
fail_fixture("senior review-owner floor id drifted") unless senior_floor["id"] == "senior-owner-teammate-whole-target"
fail_fixture("senior review-owner route drifted") unless senior_floor["route"] == "teammate_whole_target_pr_review"
fail_fixture("senior review-owner depth must be FULL") unless senior_floor["depth"] == "FULL"
fail_fixture("senior review-owner topology must remain single") unless senior_floor["topology"] == "single"
fail_fixture("senior review-owner floor became demotable") unless senior_floor["demotable"] == false
fail_fixture("senior review-owner exclusions drifted") unless senior_floor["excluded_intents"] == EXPECTED_SENIOR_REVIEW_EXCLUSIONS

packet_carriers = control.fetch("packet_carriers")
exact_keys!(packet_carriers, %w[ordinary database], %w[ordinary database], "review packet carriers")
fail_fixture("ordinary packet carriers drifted") unless packet_carriers["ordinary"] == ["Review mode", "Scope basis", "Coverage", "Selected reviewer lenses", "Not loaded"]
fail_fixture("database packet carriers drifted") unless packet_carriers["database"] == ["Selected lanes", "Not selected", "Not reviewed"]

validate_depth_cases = lambda do |cases, reviewer|
  ids = []
  by_depth = Hash.new { |hash, key| hash[key] = [] }
  cases.each do |fixture|
    exact_keys!(
      fixture,
      %w[id depth trigger required_work forbidden_without_trigger residual escalation],
      %w[id depth trigger required_work forbidden_without_trigger residual escalation],
      "#{reviewer} depth case"
    )
    ids << fixture.fetch("id")
    depth = fixture.fetch("depth")
    fail_fixture("#{fixture['id']}: invalid depth") unless EXPECTED_DEPTHS.include?(depth)
    fail_fixture("#{fixture['id']}: required_work must be nonempty") unless fixture["required_work"].is_a?(Array) && !fixture["required_work"].empty?
    fail_fixture("#{fixture['id']}: forbidden_without_trigger must be an array") unless fixture["forbidden_without_trigger"].is_a?(Array)
    fail_fixture("#{fixture['id']}: residual must be boolean") unless [true, false].include?(fixture["residual"])
    fail_fixture("#{fixture['id']}: invalid escalation") unless %w[none FULL].include?(fixture["escalation"])
    by_depth[depth] << fixture
  end
  fail_fixture("#{reviewer} depth case ids must be unique") unless ids.uniq.length == ids.length
  EXPECTED_DEPTHS.each do |depth|
    fail_fixture("#{reviewer} depth matrix lacks #{depth}") if by_depth[depth].empty?
  end
  primary = EXPECTED_DEPTHS.to_h do |depth|
    [depth, by_depth.fetch(depth).find { |fixture| fixture["depth"] == depth && fixture["escalation"] == "none" } || by_depth.fetch(depth).first]
  end
  obligations = primary.transform_values { |fixture| fixture.fetch("required_work").sort }
  fail_fixture("#{reviewer} depth obligations collapsed") unless obligations.values.uniq.length == EXPECTED_DEPTHS.length
  fail_fixture("#{reviewer} FULL lacks independent residual work") unless primary.fetch("FULL").fetch("residual")
  fail_fixture("#{reviewer} LITE unexpectedly requires residual work") if primary.fetch("LITE").fetch("residual")
  fail_fixture("#{reviewer} STANDARD unexpectedly requires residual work") if primary.fetch("STANDARD").fetch("residual")
  coverage_marker = reviewer == "ordinary" ? "every_triggered_lens" : "every_triggered_lane"
  %w[LITE STANDARD FULL].each do |depth|
    fail_fixture("#{reviewer} #{depth} suppresses triggered coverage") unless primary.fetch(depth).fetch("required_work").include?(coverage_marker)
  end
  floor_escalation = cases.any? do |fixture|
    EXPECTED_FULL_FLOORS.include?(fixture["trigger"]) && fixture["escalation"] == "FULL"
  end
  fail_fixture("#{reviewer} matrix lacks mandatory FULL escalation") unless floor_escalation
  ids
end

ordinary_depth_ids = validate_depth_cases.call(control.fetch("ordinary_depth_cases"), "ordinary")
database_depth_ids = validate_depth_cases.call(control.fetch("database_depth_cases"), "database")
fail_fixture("ordinary LITE economy case missing") unless ordinary_depth_ids.include?("ordinary-lite-contained")
fail_fixture("ordinary bounded instruction STANDARD case missing") unless ordinary_depth_ids.include?("ordinary-standard-bounded-instruction")
fail_fixture("database LITE economy case missing") unless database_depth_ids.include?("database-lite-advisory")

ordinary_primary = %w[LITE STANDARD FULL].to_h do |depth|
  cases = control.fetch("ordinary_depth_cases").select { |fixture| fixture["depth"] == depth }
  [depth, cases.find { |fixture| fixture["escalation"] == "none" } || cases.first]
end
fail_fixture("ordinary FULL lost initial-review primer") unless ordinary_primary.fetch("FULL").fetch("required_work").include?("full_initial_review_primer")
%w[LITE STANDARD].each do |depth|
  fixture = ordinary_primary.fetch(depth)
  fail_fixture("ordinary #{depth} unexpectedly requires initial-review primer") if fixture.fetch("required_work").include?("full_initial_review_primer")
  fail_fixture("ordinary #{depth} does not forbid initial-review primer") unless fixture.fetch("forbidden_without_trigger").include?("full_initial_review_primer")
end

expansion_case_ids = []
control.fetch("expansion_cases").each do |fixture|
  exact_keys!(
    fixture,
    %w[id trigger evidence added_boundary missed_defect_class allowed],
    %w[id trigger evidence added_boundary missed_defect_class allowed],
    "review expansion case"
  )
  expansion_case_ids << fixture.fetch("id")
  expected_allowed = EXPECTED_EXPANSION_TRIGGERS.include?(fixture.fetch("trigger")) &&
    !fixture.fetch("evidence").to_s.empty? &&
    !fixture.fetch("added_boundary").to_s.empty? &&
    !fixture.fetch("missed_defect_class").to_s.empty?
  fail_fixture("#{fixture['id']}: evidence-triggered expansion decision drifted") unless fixture.fetch("allowed") == expected_allowed
end
fail_fixture("review expansion case ids must be unique") unless expansion_case_ids.uniq.length == expansion_case_ids.length
fail_fixture("review expansion fixtures lack evidence-backed allowance") unless expansion_case_ids.include?("reachable-consumer-expansion")
fail_fixture("review expansion fixtures lack evidence-free rejection") unless expansion_case_ids.include?("reviewer-preference-is-not-evidence")

mutation_ids = control.fetch("negative_mutations").map do |fixture|
  exact_keys!(fixture, %w[id], %w[id], "review depth negative mutation")
  fixture.fetch("id")
end
fail_fixture("review depth mutation ids must be unique") unless mutation_ids.uniq.length == mutation_ids.length
fail_fixture("review depth negative mutations drifted") unless mutation_ids == EXPECTED_DEPTH_MUTATIONS

collapsed = Marshal.load(Marshal.dump(control.fetch("ordinary_depth_cases")))
baseline = collapsed.find { |fixture| fixture["id"] == "ordinary-lite-contained" }.fetch("required_work")
collapsed.each { |fixture| fixture["required_work"] = baseline.dup if fixture["escalation"] == "none" }
expect_fixture_failure("collapsed-depth-obligations") do
  validate_depth_cases.call(collapsed, "ordinary")
end

missing_closure = control.fetch("common_closure") - ["per_surface_disposition"]
expect_fixture_failure("missing-common-closure") do
  errors = exact_contract_errors(missing_closure, EXPECTED_COMMON_CLOSURE, "common_closure")
  fail_fixture(errors.join(", ")) unless errors.empty?
end
missing_floor = control.fetch("mandatory_full_floors") - ["shared_database_contract"]
expect_fixture_failure("missing-full-floor") do
  errors = exact_contract_errors(missing_floor, EXPECTED_FULL_FLOORS, "mandatory_full_floors")
  fail_fixture(errors.join(", ")) unless errors.empty?
end
suppressed_ordinary = control.fetch("ordinary_depth_cases").map { |fixture| Marshal.load(Marshal.dump(fixture)) }
suppressed_ordinary.each { |fixture| fixture["required_work"].delete("every_triggered_lens") }
expect_fixture_failure("suppressed-triggered-coverage") do
  validate_depth_cases.call(suppressed_ordinary, "ordinary")
end

scope_token_packet = "Verdict: PASS\nREVIEW_SCOPE_ACCEPTED:\nPacket ends.\n"
fail_fixture("scope-token-in-strict-packet negative mutation was not detected") if strict_packet_scope_errors(scope_token_packet, forbidden_tokens).empty?

evidence_free_expansion = Marshal.load(Marshal.dump(control.fetch("expansion_cases").find { |fixture| fixture["id"] == "reviewer-preference-is-not-evidence" }))
evidence_free_expansion["allowed"] = true
expected_evidence_free_allowed = EXPECTED_EXPANSION_TRIGGERS.include?(evidence_free_expansion.fetch("trigger")) &&
  !evidence_free_expansion.fetch("evidence").to_s.empty? &&
  !evidence_free_expansion.fetch("added_boundary").to_s.empty? &&
  !evidence_free_expansion.fetch("missed_defect_class").to_s.empty?
fail_fixture("evidence-free-expansion negative mutation was not detected") if evidence_free_expansion.fetch("allowed") == expected_evidence_free_allowed

missing_full_primer = Marshal.load(Marshal.dump(ordinary_primary.fetch("FULL")))
missing_full_primer["required_work"].delete("full_initial_review_primer")
expect_fixture_failure("missing-full-primer") do
  fail_fixture("ordinary FULL lost initial-review primer") unless missing_full_primer.fetch("required_work").include?("full_initial_review_primer")
end

missing_preservation_ledger = preservation_ledger.sub(
  "Instruction preservation row `reviewer-depth-common-closure`:",
  "Instruction preservation row removed by mutation:"
)
fail_fixture("missing-preservation-row negative mutation was not detected") if preservation_row_errors(missing_preservation_ledger, preservation_row_ids).empty?

progress_packet = "Verdict: PASS\nREVIEW_PROGRESS:\nPacket ends.\n"
fail_fixture("progress-in-strict-packet negative mutation was not detected") if strict_packet_scope_errors(progress_packet, forbidden_tokens).empty?
autonomous_progress = progress.merge("delivery" => "periodic", "autonomous_periodic" => true)
fail_fixture("autonomous-progress negative mutation was not detected") if autonomous_progress.values_at("delivery", "autonomous_periodic") == ["pull_only", false]
repeated_progress = progress.merge("repeat_unchanged" => true)
fail_fixture("repeated-unchanged-progress negative mutation was not detected") unless repeated_progress["repeat_unchanged"]
timer_closeout = progress.merge("time_band_authority" => "deadline", "closeout_authority" => "elapsed_time")
fail_fixture("timer-derived-closeout negative mutation was not detected") if timer_closeout.values_at("time_band_authority", "closeout_authority") == ["advisory_metadata_only", "closure_and_stop_proof_only"]
semantic_rewrite = ownership.fetch("parent_forbidden") - ["comment body rewrite"]
fail_fixture("parent-semantic-rewrite negative mutation was not detected") if semantic_rewrite.include?("comment body rewrite")
parallel_parent = ownership.fetch("parent_forbidden") - ["parallel whole target semantic review"]
fail_fixture("parent-parallel-review negative mutation was not detected") if parallel_parent.include?("parallel whole target semantic review")

projection_ids = []
control.fetch("projection_cases").each do |fixture|
  exact_keys!(
    fixture,
    %w[id depth topology ordinary_pr_mode retained_parent_depth],
    %w[id depth topology ordinary_pr_mode retained_parent_depth],
    "review projection case"
  )
  projection_ids << fixture.fetch("id")
  depth = fixture.fetch("depth")
  topology = fixture.fetch("topology")
  expected_mode = topology == "council" ? "COUNCIL" : depth
  fail_fixture("#{fixture['id']}: invalid depth") unless EXPECTED_DEPTHS.include?(depth)
  fail_fixture("#{fixture['id']}: invalid topology") unless EXPECTED_TOPOLOGIES.include?(topology)
  fail_fixture("#{fixture['id']}: lossy ordinary PR projection") unless fixture["ordinary_pr_mode"] == expected_mode
  fail_fixture("#{fixture['id']}: underlying depth was not retained") unless fixture["retained_parent_depth"] == depth
end
fail_fixture("review projection ids must be unique") unless projection_ids.uniq.length == projection_ids.length
fail_fixture("review projection lacks council FULL floor") unless projection_ids.include?("council-full-floor")

scope_ids = []
control.fetch("scope_cases").each do |fixture|
  exact_keys!(
    fixture,
    %w[id reviewer trigger terminal corrections],
    %w[id reviewer trigger terminal corrections],
    "review scope case"
  )
  scope_ids << fixture.fetch("id")
  fail_fixture("#{fixture['id']}: invalid reviewer") unless %w[ordinary database].include?(fixture["reviewer"])
  fail_fixture("#{fixture['id']}: invalid scope terminal") unless EXPECTED_SCOPE_MESSAGES.include?(fixture["terminal"])
  fail_fixture("#{fixture['id']}: corrections must be a nonnegative integer") unless fixture["corrections"].is_a?(Integer) && fixture["corrections"] >= 0
  if fixture["corrections"] > 1
    fail_fixture("#{fixture['id']}: repeated correction must fail closed") unless fixture["terminal"] == "SCOPE_DISPUTE_BLOCKED"
  end
end
fail_fixture("review scope ids must be unique") unless scope_ids.uniq.length == scope_ids.length
%w[bounded-proposal-accepted mandatory-floor-escalation correction-accepted-by-reviewer unresolved-narrowing repeated-correction-forbidden].each do |id|
  fail_fixture("review scope fixture missing #{id}") unless scope_ids.include?(id)
end
mandatory_floor_scope = control.fetch("scope_cases").find { |fixture| fixture["id"] == "mandatory-floor-escalation" }
fail_fixture("mandatory floor escalation must terminate with parent acceptance") unless mandatory_floor_scope.fetch("terminal") == "ESCALATION_ACCEPTED"
suppressed_escalation = Marshal.load(Marshal.dump(mandatory_floor_scope))
suppressed_escalation["terminal"] = "REVIEW_SCOPE_ACCEPTED"
expect_fixture_failure("parent-suppresses-escalation") do
  fail_fixture("mandatory floor escalation was suppressed") unless suppressed_escalation.fetch("terminal") == "ESCALATION_ACCEPTED"
end

candidate_ids = []
control.fetch("candidate_cases").each do |fixture|
  exact_keys!(
    fixture,
    %w[id reviewer verdict findings central_missing_proof caveat next_action candidate],
    %w[id reviewer verdict findings central_missing_proof caveat next_action candidate],
    "review candidate case"
  )
  candidate_ids << fixture.fetch("id")
  actual = candidate_for(fixture)
  fail_fixture("#{fixture['id']}: candidate mapping drifted, expected #{fixture['candidate']}, got #{actual}") unless actual == fixture["candidate"]
end
fail_fixture("review candidate ids must be unique") unless candidate_ids.uniq.length == candidate_ids.length
fail_fixture("ordinary no-action residual caveat case missing") unless candidate_ids.include?("ordinary-pass-with-residual-caveat")
fail_fixture("database no-action caveat case missing") unless candidate_ids.include?("database-pass-with-caveat")

join_ids = []
control.fetch("join_cases").each do |fixture|
  required = %w[id candidates join preserve]
  allowed = required + %w[conflict]
  exact_keys!(fixture, required, allowed, "review join case")
  join_ids << fixture.fetch("id")
  actual = join_for(fixture.fetch("candidates"), fixture["conflict"])
  fail_fixture("#{fixture['id']}: join mapping drifted, expected #{fixture['join']}, got #{actual}") unless actual == fixture["join"]
  missing_preserved = fixture.fetch("preserve") - fixture.fetch("candidates")
  fail_fixture("#{fixture['id']}: preserve lists absent candidates") unless missing_preserved.empty?
end
fail_fixture("review join ids must be unique") unless join_ids.uniq.length == join_ids.length
%w[input-precedes-defect defect-precedes-evidence database-action-preserved-under-ordinary-defect evidence-precedes-action action-precedes-caveats caveats-precede-clean all-clean same-claim-contradiction unresolved-scope-dispute].each do |id|
  fail_fixture("review join fixture missing #{id}") unless join_ids.include?(id)
end
database_join = control.fetch("join_cases").find { |fixture| fixture["id"] == "database-action-preserved-under-ordinary-defect" }
database_join_loss = database_join.merge("preserve" => [])
fail_fixture("database-join-loss negative mutation was not detected") unless database_join_loss["preserve"].empty? && database_join.fetch("preserve") == ["ACTION"]

suite = load_yaml(SUITE_PATH)
exact_keys!(
  suite,
  %w[schema_version suite_id canonical_transport negative_transport_cases required_case_ids cases],
  %w[schema_version suite_id canonical_transport negative_transport_cases required_case_ids cases],
  "fixture suite"
)
fail_fixture("fixture suite schema_version must be 1") unless suite["schema_version"] == 1

transport_status = validate_transport_reference(suite.fetch("canonical_transport"))
fail_fixture("canonical transport validation failed: #{transport_status}") unless transport_status == :ok
transport_path = resolve_repo_path(suite.dig("canonical_transport", "path"), "canonical transport")
transport = load_yaml(transport_path)
exact_keys!(
  transport,
  %w[schema_version transport_id required_route_fields review_modes evidence_response_packet review_comments closeout_categories verdicts],
  %w[schema_version transport_id required_route_fields review_modes evidence_response_packet review_comments closeout_categories verdicts],
  "canonical transport"
)
fail_fixture("canonical transport schema_version must be 3") unless transport["schema_version"] == 3
fail_fixture("canonical route fields drifted") unless transport["required_route_fields"] == EXPECTED_ROUTE_FIELDS
fail_fixture("canonical closeout categories drifted") unless transport["closeout_categories"] == EXPECTED_CLOSEOUT_CATEGORIES
fail_fixture("canonical verdicts drifted") unless transport["verdicts"] == EXPECTED_VERDICTS
fail_fixture("canonical review modes drifted") unless transport.fetch("review_modes").keys == EXPECTED_REVIEW_MODES

github_transport = transport.dig("review_modes", "github_pr")
exact_keys!(
  github_transport,
  %w[requires_pr_packet required_fields finding_block first_content_prefix terminator terminator_must_be_final],
  %w[requires_pr_packet required_fields finding_block first_content_prefix terminator terminator_must_be_final],
  "canonical GitHub PR transport"
)
fail_fixture("GitHub PR transport must require the packet") unless github_transport["requires_pr_packet"] == true
fail_fixture("GitHub PR transport first content must be Verdict:") unless github_transport["first_content_prefix"] == "Verdict:"
fail_fixture("GitHub PR transport terminator must be Packet ends.") unless github_transport["terminator"] == "Packet ends."
fail_fixture("GitHub PR transport terminator must be final") unless github_transport["terminator_must_be_final"] == true
fail_fixture("GitHub PR transport required_fields must be a non-empty unique list") unless github_transport["required_fields"].is_a?(Array) && !github_transport["required_fields"].empty? && github_transport["required_fields"].uniq.length == github_transport["required_fields"].length
finding_transport = github_transport.fetch("finding_block")
exact_keys!(finding_transport, %w[required_when_formal_findings first_content_prefix required_fields], %w[required_when_formal_findings first_content_prefix required_fields], "canonical finding block transport")
fail_fixture("finding blocks must be required for positive formal finding counts") unless finding_transport["required_when_formal_findings"] == true
fail_fixture("finding block prefix drifted") unless finding_transport["first_content_prefix"] == "Finding P"
fail_fixture("finding block fields must be a non-empty unique list") unless finding_transport["required_fields"].is_a?(Array) && !finding_transport["required_fields"].empty? && finding_transport["required_fields"].uniq.length == finding_transport["required_fields"].length

erp_transport = transport.fetch("evidence_response_packet")
exact_keys!(
  erp_transport,
  %w[purpose verdict_packet first_content_prefix required_fields],
  %w[purpose verdict_packet first_content_prefix required_fields],
  "Evidence Response Packet transport"
)
fail_fixture("Evidence Response Packet purpose drifted") unless erp_transport["purpose"] == "parent_to_reviewer_reassessment"
fail_fixture("Evidence Response Packet must not inherit verdict packet law") unless erp_transport["verdict_packet"] == false
fail_fixture("Evidence Response Packet first content drifted") unless erp_transport["first_content_prefix"] == "Evidence Response Packet:"
erp_fields = erp_transport.fetch("required_fields")
fail_fixture("Evidence Response Packet fields must be a non-empty unique list") unless erp_fields.is_a?(Array) && !erp_fields.empty? && erp_fields.uniq.length == erp_fields.length

review_comments_transport = transport.fetch("review_comments")
@review_comments_transport = review_comments_transport
review_comments_transport_keys = %w[
  output_contracts
  default_policy
  section_heading
  review_event_prefix
  unanchored_prefix
  comment_prefix
  fixed_after
  fixed_before
  fixed_before_patterns
  body_first_line_pattern
  forbidden_body_patterns
  review_events
  body_transport
  decoded_text
  trailing_newline
  unprefixed_lines_forbidden
  summary_literal_field
  comment_fields
  comment_literal_field
]
exact_keys!(review_comments_transport, review_comments_transport_keys, review_comments_transport_keys, "review comments transport")
fail_fixture("review comments output contracts drifted") unless review_comments_transport["output_contracts"] == ["canonical packet with conditional review comments", "verdict-only canonical packet"]
fail_fixture("review comments default policy drifted") unless review_comments_transport["default_policy"] == "required_if_findings"
fail_fixture("review comments section heading drifted") unless review_comments_transport["section_heading"] == "Review comments:"
fail_fixture("review comments event prefix drifted") unless review_comments_transport["review_event_prefix"] == "Review event:"
fail_fixture("review comments unanchored prefix drifted") unless review_comments_transport["unanchored_prefix"] == "Unanchored findings:"
fail_fixture("review comments placement drifted") unless review_comments_transport["fixed_after"] == "finding_blocks" && review_comments_transport["fixed_before"].include?("Plain-language summary:")
fail_fixture("review comments review events drifted") unless review_comments_transport["review_events"] == %w[REQUEST_CHANGES COMMENT]
unless review_comments_transport.values_at("body_transport", "decoded_text", "trailing_newline") == ["pipe_prefixed_literal", "UTF-8", "clip"] &&
       review_comments_transport["unprefixed_lines_forbidden"] == true
  fail_fixture("review comments literal-body contract drifted")
end
fail_fixture("review comments summary field drifted") unless review_comments_transport["summary_literal_field"] == "Summary"
fail_fixture("review comments fields drifted") unless review_comments_transport["comment_fields"] == ["Finding", "Anchor JSON"] && review_comments_transport["comment_literal_field"] == "Body"

packet_doc = PACKET_DOC_PATH.read
erp_section = packet_doc.split("## Evidence Response Packet For Reassessment", 2).fetch(1).split("\n## ", 2).first
erp_errors = erp_doc_errors(erp_section, erp_fields)
fail_fixture("canonical packet doc Evidence Response Packet contract drifted: #{erp_errors.join(', ')}") unless erp_errors.empty?
erp_negative = erp_doc_errors(erp_section.sub("Original concern ID:", "Original concern:"), erp_fields)
fail_fixture("Evidence Response Packet negative mutation did not detect a missing field") unless erp_negative.include?("missing_field:Original concern ID")

%w[branch_local direct_sql].each do |mode|
  mode_transport = transport.dig("review_modes", mode)
  exact_keys!(mode_transport, %w[requires_pr_packet required_fields], %w[requires_pr_packet required_fields], "canonical #{mode} transport")
  fail_fixture("#{mode} transport must not require the PR packet") unless mode_transport["requires_pr_packet"] == false
  fail_fixture("#{mode} required_fields must be a non-empty unique list") unless mode_transport["required_fields"].is_a?(Array) && !mode_transport["required_fields"].empty? && mode_transport["required_fields"].uniq.length == mode_transport["required_fields"].length
end

negative_cases = suite.fetch("negative_transport_cases")
fail_fixture("negative_transport_cases must contain missing and corrupt references") unless negative_cases.is_a?(Array) && negative_cases.length == 2
negative_results = {}
negative_cases.each do |negative|
  exact_keys!(negative, %w[id path sha256 expected_error], %w[id path sha256 expected_error], "negative transport case")
  status = validate_transport_reference("path" => negative["path"], "sha256" => negative["sha256"])
  expected = negative.fetch("expected_error").to_sym
  fail_fixture("negative transport case #{negative['id']} unexpectedly returned #{status}, expected #{expected}") unless status == expected
  negative_results[negative.fetch("id")] = status
end
fail_fixture("missing transport negative case absent") unless negative_results.value?(:transport_missing)
fail_fixture("corrupt digest negative case absent") unless negative_results.value?(:transport_digest_mismatch)

required_ids = suite.fetch("required_case_ids")
fail_fixture("required_case_ids drifted") unless required_ids == EXPECTED_CASE_IDS
cases = suite.fetch("cases")
fail_fixture("cases must be an array") unless cases.is_a?(Array)
case_ids = cases.map { |entry| entry.is_a?(Hash) ? entry["id"] : nil }
fail_fixture("case ids must be unique") unless case_ids.compact.uniq.length == case_ids.length
fail_fixture("case coverage differs from required_case_ids") unless case_ids == required_ids

case_allowed = %w[id description review_mode route route_fields seed expected]
route_allowed = EXPECTED_ROUTE_FIELDS
seed_allowed = %w[defect artifact packet_sample finding_sample semantic_class]
expected_allowed = %w[
  adjudication
  verdict
  requires_pr_packet
  packet_skeleton
  terminator
  formal_findings
  required_rejection_reasons
  central_unknown
  pass_forbidden
  reh_required
  candidate_categories
  emitted_root_causes
  advisory_max
  dedupe_root
  duplicate_findings_forbidden
  pure_nit_suppressed
  minimum_severity
  behavior_preserving_claim_rejected
  clean_control
  required_mode_fields
  review_comments
]

cases.each do |fixture|
  exact_keys!(fixture, case_allowed, case_allowed, "fixture case")
  id = fixture.fetch("id")
  fail_fixture("fixture id must be non-empty") unless id.is_a?(String) && !id.empty?
  fail_fixture("#{id}: description must be non-empty") unless fixture["description"].is_a?(String) && !fixture["description"].empty?
  mode = fixture.fetch("review_mode")
  fail_fixture("#{id}: unknown review_mode #{mode}") unless EXPECTED_REVIEW_MODES.include?(mode)
  fail_fixture("#{id}: route must be reviewer") unless fixture["route"] == "reviewer"

  route_fields = fixture.fetch("route_fields")
  exact_keys!(route_fields, route_allowed, route_allowed, "#{id}: route_fields")
  fail_fixture("#{id}: route_fields must preserve canonical order") unless route_fields.keys == route_allowed
  route_fields.each do |name, value|
    fail_fixture("#{id}: route field #{name} must be non-empty") unless value.is_a?(String) && !value.empty?
  end

  seed = fixture.fetch("seed")
  exact_keys!(seed, %w[defect artifact], seed_allowed, "#{id}: seed")
  seed.each do |name, value|
    fail_fixture("#{id}: seed #{name} must be non-empty") unless value.is_a?(String) && !value.empty?
  end

  expected = fixture.fetch("expected")
  exact_keys!(expected, %w[adjudication verdict requires_pr_packet], expected_allowed, "#{id}: expected")
  fail_fixture("#{id}: invalid adjudication") unless %w[accept reject].include?(expected["adjudication"])
  fail_fixture("#{id}: invalid verdict") unless EXPECTED_VERDICTS.include?(expected["verdict"])
  requires_pr_packet = transport.dig("review_modes", mode, "requires_pr_packet")
  fail_fixture("#{id}: requires_pr_packet contradicts canonical mode") unless expected["requires_pr_packet"] == requires_pr_packet

  categories = expected.fetch("candidate_categories", [])
  fail_fixture("#{id}: candidate_categories must be an array") unless categories.is_a?(Array)
  unknown_categories = categories - EXPECTED_CLOSEOUT_CATEGORIES
  fail_fixture("#{id}: unknown closeout categories: #{unknown_categories.join(', ')}") unless unknown_categories.empty?

  if mode == "github_pr"
    fail_fixture("#{id}: GitHub PR fixture must define packet_skeleton") unless expected.key?("packet_skeleton")
    fail_fixture("#{id}: GitHub PR fixture must define terminator") unless expected.key?("terminator")
  else
    fail_fixture("#{id}: non-PR mode must forbid packet_skeleton") unless expected["packet_skeleton"] == "forbidden"
    fail_fixture("#{id}: non-PR mode terminator must be not_applicable") unless expected["terminator"] == "not_applicable"
    required_mode_fields = transport.dig("review_modes", mode, "required_fields")
    fail_fixture("#{id}: required_mode_fields drifted") unless expected["required_mode_fields"] == required_mode_fields
  end
end

by_id = cases.to_h { |fixture| [fixture.fetch("id"), fixture] }

acceptance_sample = by_id.fetch("packet-valid-skeleton").dig("seed", "packet_sample")
accepted_raw = packet_acceptance_result(
  acceptance_sample.chomp,
  github_transport,
  review_comments_transport,
  target: "fixture head",
  mode: "STANDARD",
  comments: "required_if_findings"
)
fail_fixture("valid raw actual packet was rejected: #{accepted_raw.issues.map(&:rule_id).join(', ')}") unless accepted_raw.accepted && accepted_raw.transport == "raw"

accepted_fenced = packet_acceptance_result(
  "```text\n#{acceptance_sample.chomp}\n```\n",
  github_transport,
  review_comments_transport,
  target: "fixture head",
  mode: "STANDARD",
  comments: "required_if_findings"
)
unless accepted_fenced.accepted && accepted_fenced.transport == "fenced" &&
       accepted_fenced.packet_sha256 == accepted_raw.packet_sha256 &&
       accepted_fenced.source_sha256 != accepted_fenced.packet_sha256
  fail_fixture("valid fenced actual packet did not preserve dual packet/source identity")
end

acceptance_mutations = {
  "RPPA-001 prose transport" => ["summary\n#{acceptance_sample}", "fixture head", "STANDARD", "optional", "RPPA-001"],
  "RPPA-002 missing field" => [acceptance_sample.sub(/^Scope basis:.*\n/, ""), "fixture head", "STANDARD", "optional", "RPPA-002"],
  "RPPA-003 target mismatch" => [acceptance_sample, "different head", "STANDARD", "optional", "RPPA-003"],
  "RPPA-003 mode mismatch" => [acceptance_sample, "fixture head", "FULL", "optional", "RPPA-003"],
  "RPPA-004 finding mismatch" => [acceptance_sample.sub("P2/P3 findings: 0", "P2/P3 findings: 1 P2"), "fixture head", "STANDARD", "optional", "RPPA-004"],
  "RPPA-006 section order" => [acceptance_sample.sub("Plain-language summary: no material findings\nSelected reviewer lenses: fixture", "Selected reviewer lenses: fixture\nPlain-language summary: no material findings"), "fixture head", "STANDARD", "optional", "RPPA-006"],
  "RPPA-007 trailing prose" => ["#{acceptance_sample}footer\n", "fixture head", "STANDARD", "optional", "RPPA-007"],
  "RPPA-008 clean comments forbidden" => [acceptance_sample.sub("Next owner: none artifact: fixture", "Next owner: none artifact: fixture\nReview comments:\nReview event: COMMENT\nUnanchored findings: none\nSummary:\n  | clean"), "fixture head", "STANDARD", "required_if_findings", "RPPA-008"],
  "RPPA-010 duplicate singleton" => [acceptance_sample.sub("Variance ledger: N/A", "Variance ledger: N/A\nVariance ledger: duplicate"), "fixture head", "STANDARD", "optional", "RPPA-010"]
}
acceptance_mutations.each do |label, (sample, target, mode, comments, rule_id)|
  result = packet_acceptance_result(sample, github_transport, review_comments_transport, target: target, mode: mode, comments: comments)
  expect_packet_rule!(label, result, rule_id)
  fail_fixture("#{label}: rejected packet exposed a review-comments payload") if result.review_comments_payload
end

finding_acceptance_sample = by_id.fetch("packet-valid-with-finding").dig("seed", "packet_sample")
missing_finding_field = finding_acceptance_sample.sub(/^- Impact:.*\n/, "")
expect_packet_rule!(
  "RPPA-005 missing finding field",
  packet_acceptance_result(missing_finding_field, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-005"
)
finding_severity_mismatch = finding_acceptance_sample.sub("- Severity: P2", "- Severity: P1")
expect_packet_rule!(
  "RPPA-005 finding severity mismatch",
  packet_acceptance_result(finding_severity_mismatch, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-005"
)
duplicate_finding_severity = finding_acceptance_sample.sub("- Severity: P2", "- Severity: P2\n- Severity: P2")
expect_packet_rule!(
  "RPPA-005 duplicate finding field",
  packet_acceptance_result(duplicate_finding_severity, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-005"
)
unprefixed_review_body = finding_acceptance_sample.sub(/^  \| \*\*How to verify:\*\*.*$/, "How to verify: unprefixed")
expect_packet_rule!(
  "RPPA-009 unprefixed review body",
  packet_acceptance_result(unprefixed_review_body, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
invalid_anchor_type = finding_acceptance_sample.sub(/- Anchor JSON: \{.*\}/, "- Anchor JSON: []")
expect_packet_rule!(
  "RPPA-009 non-object anchor",
  packet_acceptance_result(invalid_anchor_type, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
invalid_anchor_line_type = finding_acceptance_sample.sub('"line":1', '"line":"1"')
expect_packet_rule!(
  "RPPA-009 invalid anchor line type",
  packet_acceptance_result(invalid_anchor_line_type, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
invalid_anchor_path = finding_acceptance_sample.sub('"path":"fixture/path"', '"path":"../fixture/path"')
expect_packet_rule!(
  "RPPA-009 parent-relative anchor path",
  packet_acceptance_result(invalid_anchor_path, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
invalid_anchor_range = finding_acceptance_sample.sub('"start_line":null,"start_side":null', '"start_line":2,"start_side":"RIGHT"')
expect_packet_rule!(
  "RPPA-009 inverted anchor range",
  packet_acceptance_result(invalid_anchor_range, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
invalid_anchor_single_line_range = finding_acceptance_sample.sub('"start_line":null,"start_side":null', '"start_line":1,"start_side":"RIGHT"')
expect_packet_rule!(
  "RPPA-009 degenerate anchor range",
  packet_acceptance_result(invalid_anchor_single_line_range, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-009"
)
valid_file_anchor = finding_acceptance_sample.sub(
  '{"line":1,"path":"fixture/path","side":"RIGHT","start_line":null,"start_side":null,"subject_type":"line"}',
  '{"line":null,"path":"fixture/path","side":null,"start_line":null,"start_side":null,"subject_type":"file"}'
)
fail_fixture("valid file-level anchor was rejected") unless review_comment_errors(valid_file_anchor, review_comments_transport, required: true).empty?

valid_packet = by_id.fetch("packet-valid-skeleton").fetch("expected")
fail_fixture("valid packet fixture must accept valid/final packet") unless valid_packet.values_at("adjudication", "packet_skeleton", "terminator") == ["accept", "valid", "final"]
valid_packet_errors = packet_structure_errors(by_id.fetch("packet-valid-skeleton").dig("seed", "packet_sample"), github_transport, formal_findings: valid_packet.fetch("formal_findings"))
fail_fixture("valid packet sample failed structural validation: #{valid_packet_errors.join(', ')}") unless valid_packet_errors.empty?

valid_finding_packet = by_id.fetch("packet-valid-with-finding").fetch("expected")
valid_finding_sample = by_id.fetch("packet-valid-with-finding").dig("seed", "packet_sample")
valid_finding_errors = packet_structure_errors(valid_finding_sample, github_transport, formal_findings: valid_finding_packet.fetch("formal_findings"))
fail_fixture("valid positive-finding packet sample failed structural validation: #{valid_finding_errors.join(', ')}") unless valid_finding_errors.empty?
actionable_errors = actionable_finding_errors(valid_finding_sample)
fail_fixture("valid positive-finding packet is not actionable: #{actionable_errors.join(', ')}") unless actionable_errors.empty?
valid_finding_comment_errors = review_comment_errors(valid_finding_sample, review_comments_transport, required: true)
fail_fixture("valid positive-finding review comments failed: #{valid_finding_comment_errors.join(', ')}") unless valid_finding_comment_errors.empty?
fail_fixture("valid positive-finding review-comment count drifted") unless review_comment_blocks(valid_finding_sample, review_comments_transport).length == valid_finding_packet.fetch("review_comments")
valid_finding_result = packet_acceptance_result(
  valid_finding_sample,
  github_transport,
  review_comments_transport,
  target: "fixture head",
  mode: "STANDARD",
  comments: "required_if_findings"
)
expected_finding_body = <<~BODY
  `issue(non-blocking)` Documentation contract mismatch

  **What happens:** The documented contract contradicts the inspected source.

  **Why it matters:** Reviewers can approve the wrong behavior.

  **Evidence:** `fixture/path:1` differs from source.

  **Suggested fix:** Update the contract paragraph to match the inspected source behavior.

  **How to verify:** Run the focused documentation contract check and assert both surfaces describe the same rule.
BODY
expected_finding_payload = {
  "review_event" => "COMMENT",
  "unanchored_findings" => [],
  "summary_body" => "One material documentation finding is ready for author follow-up.\n",
  "comments" => [
    {
      "comment_id" => "C-1",
      "finding" => 1,
      "anchor" => {
        "line" => 1,
        "path" => "fixture/path",
        "side" => "RIGHT",
        "start_line" => nil,
        "start_side" => nil,
        "subject_type" => "line"
      },
      "body" => expected_finding_body
    }
  ]
}
unless valid_finding_result.accepted && valid_finding_result.review_comments_payload == expected_finding_payload
  fail_fixture("accepted positive-finding packet did not return exact decoded review-comment bytes")
end
valid_finding_json = valid_finding_result.to_h
unless valid_finding_json["schema_version"] == 3 && valid_finding_json["review_comments_payload"] == expected_finding_payload
  fail_fixture("validator JSON contract omitted the accepted review-comments payload")
end
unanchored_packet = by_id.fetch("packet-valid-unanchored-blocking")
unanchored_sample = unanchored_packet.dig("seed", "packet_sample")
unanchored_errors = review_comment_errors(unanchored_sample, review_comments_transport, required: true)
fail_fixture("valid unanchored blocking packet failed: #{unanchored_errors.join(', ')}") unless unanchored_errors.empty?
unanchored_result = packet_acceptance_result(unanchored_sample, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings")
unless unanchored_result.accepted && unanchored_result.review_comments_payload["review_event"] == "REQUEST_CHANGES" &&
       unanchored_result.review_comments_payload["unanchored_findings"] == [1] &&
       unanchored_result.review_comments_payload["comments"].empty?
  fail_fixture("unanchored blocking finding did not preserve event and partition")
end
missing_fix_errors = actionable_finding_errors(valid_finding_sample.sub(/^- Fix shape:.*$/, ""))
fail_fixture("missing Fix shape mutation was accepted") unless missing_fix_errors.include?("missing_fix_shape")
generic_fix_errors = actionable_finding_errors(valid_finding_sample.sub(/^- Fix shape:.*$/, "- Fix shape: Fix it."))
fail_fixture("generic Fix shape mutation was accepted") unless generic_fix_errors.include?("generic_fix_shape")

adversarial_packet = by_id.fetch("packet-valid-review-comment-adversarial")
adversarial_expected = adversarial_packet.fetch("expected")
adversarial_sample = adversarial_packet.dig("seed", "packet_sample")
adversarial_structure_errors = packet_structure_errors(adversarial_sample, github_transport, formal_findings: adversarial_expected.fetch("formal_findings"))
fail_fixture("adversarial review-comment packet failed structural validation: #{adversarial_structure_errors.join(', ')}") unless adversarial_structure_errors.empty?
adversarial_comment_errors = review_comment_errors(adversarial_sample, review_comments_transport, required: true)
fail_fixture("adversarial review comment failed: #{adversarial_comment_errors.join(', ')}") unless adversarial_comment_errors.empty?
fail_fixture("adversarial review-comment count drifted") unless review_comment_blocks(adversarial_sample, review_comments_transport).length == adversarial_expected.fetch("review_comments")
adversarial_result = packet_acceptance_result(
  adversarial_sample,
  github_transport,
  review_comments_transport,
  target: "fixture head",
  mode: "STANDARD",
  comments: "required_if_findings"
)
expected_adversarial_body = <<~BODY
  `suggestion(non-blocking)` Preserve exact parser-like text

  **What happens:** The literal text below belongs to this comment body:

  Finding P2: not a packet finding
  REVIEW_SCOPE_ACCEPTED:
  Packet ends.
  ```text
  backticks and newlines stay intact
  ```

  **Suggested fix:** Publish these exact UTF-8 bytes without interpreting them as packet structure.
BODY
unless adversarial_result.accepted &&
       adversarial_result.review_comments_payload.dig("comments", 0, "body") == expected_adversarial_body
  fail_fixture("accepted adversarial packet did not preserve exact decoded body bytes")
end

raw_body_mutation = adversarial_sample.sub(
  /^  \| Packet ends\.$/,
  "Packet ends."
)
fail_fixture("raw body mutation was accepted") if review_comment_errors(raw_body_mutation, review_comments_transport, required: true).empty?
unprefixed_finding_mutation = adversarial_sample.sub(
  /^  \| Finding P2: not a packet finding$/,
  "Finding P2: not a packet finding"
)
fail_fixture("unprefixed reserved-token mutation was accepted") if review_comment_errors(unprefixed_finding_mutation, review_comments_transport, required: true).empty?
ordinal_mismatch_mutation = valid_finding_sample.sub("- Finding: 1", "- Finding: 2")
unless review_comment_errors(ordinal_mismatch_mutation, review_comments_transport, required: true).include?("review_comment_finding_partition")
  fail_fixture("finding ordinal mismatch mutation was accepted")
end
unanchored_grammar_mutation = unanchored_sample.sub("Unanchored findings: 1", "Unanchored findings: 1,1")
unless review_comment_errors(unanchored_grammar_mutation, review_comments_transport, required: true).include?("review_comments_unanchored_grammar")
  fail_fixture("unanchored grammar mutation was accepted")
end
ordered_errors = []
unless ReviewerPacketValidator.parse_unanchored_findings("2, 4", ordered_errors) == [2, 4] && ordered_errors.empty?
  fail_fixture("valid ascending unanchored ordinal list was rejected")
end
duplicate_errors = []
ReviewerPacketValidator.parse_unanchored_findings("1, 1", duplicate_errors)
fail_fixture("duplicate unanchored ordinals were accepted") unless duplicate_errors.include?("review_comments_unanchored_order")
unsorted_errors = []
ReviewerPacketValidator.parse_unanchored_findings("2, 1", unsorted_errors)
fail_fixture("unsorted unanchored ordinals were accepted") unless unsorted_errors.include?("review_comments_unanchored_order")
unanchored_overlap_mutation = valid_finding_sample.sub("Unanchored findings: none", "Unanchored findings: 1")
unless review_comment_errors(unanchored_overlap_mutation, review_comments_transport, required: true).include?("review_comment_ordinal_overlap")
  fail_fixture("anchored and unanchored overlap was accepted")
end
missing_pipe_mutation = valid_finding_sample.sub(/^- Body:\n(?:  \|.*\n)+/, "- Body:\n")
fail_fixture("missing pipe-prefix mutation was accepted") if review_comment_errors(missing_pipe_mutation, review_comments_transport, required: true).empty?
empty_summary_mutation = valid_finding_sample.sub(/^Summary:\n(?:  \|.*\n)+/, "Summary:\n")
fail_fixture("empty summary mutation was accepted") if review_comment_errors(empty_summary_mutation, review_comments_transport, required: true).empty?
blank_summary_mutation = valid_finding_sample.sub("  | One material documentation finding is ready for author follow-up.\n", "  |\n")
unless review_comment_errors(blank_summary_mutation, review_comments_transport, required: true).include?("review_comments_summary_empty")
  fail_fixture("blank-only summary mutation was accepted")
end
blank_body_mutation = valid_finding_sample.sub(/^- Body:\n(?:  \|.*\n)+/, "- Body:\n  |\n")
unless review_comment_errors(blank_body_mutation, review_comments_transport, required: true).include?("review_comment_body_empty")
  fail_fixture("blank-only body mutation was accepted")
end
invalid_utf8_mutation = valid_finding_sample.b.sub(
  "  | `issue(non-blocking)` Documentation contract mismatch".b,
  "  | `issue(non-blocking)` Documentation contract \xFF".b
)
unless review_comment_errors(invalid_utf8_mutation, review_comments_transport, required: true).include?("review_comment_literal_invalid_utf8")
  fail_fixture("invalid UTF-8 review-comment body was accepted")
end
event_mismatch_mutation = adversarial_sample.sub("Review event: COMMENT", "Review event: REQUEST_CHANGES")
fail_fixture("review event mismatch mutation was accepted") if review_comment_errors(event_mismatch_mutation, review_comments_transport, required: true).empty?
decoration_mismatch_mutation = valid_finding_sample.sub("`issue(non-blocking)`", "`issue(blocking)`")
unless review_comment_errors(decoration_mismatch_mutation, review_comments_transport, required: true).include?("review_comment_decoration_mismatch")
  fail_fixture("severity decoration mismatch was accepted")
end
missing_comments_mutation = valid_finding_sample.sub(/^Review comments:.*?(?=^Plain-language summary:)/m, "")
missing_comments_result = packet_acceptance_result(missing_comments_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings")
expect_packet_rule!("missing finding-bearing review comments", missing_comments_result, "RPPA-008")
verdict_only_result = packet_acceptance_result(missing_comments_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "forbidden")
fail_fixture("verdict-only finding packet without review comments was rejected") unless verdict_only_result.accepted
forbidden_comments_result = packet_acceptance_result(valid_finding_sample, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "forbidden")
expect_packet_rule!("review comments present under verdict-only contract", forbidden_comments_result, "RPPA-008")

colon_label_mutation = valid_finding_sample.sub("`issue(non-blocking)`", "`issue(non-blocking):`")
expect_packet_rule!(
  "RPPA-011 colon inside Conventional Comment label",
  packet_acceptance_result(colon_label_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-011"
)
absolute_path_mutation = valid_finding_sample.sub("`fixture/path:1`", "`/absolute-fixture-path/file:1`")
expect_packet_rule!(
  "RPPA-011 absolute local path",
  packet_acceptance_result(absolute_path_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-011"
)
file_url_mutation = valid_finding_sample.sub("`fixture/path:1`", "file://fixture/path")
expect_packet_rule!(
  "RPPA-011 file URL",
  packet_acceptance_result(file_url_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-011"
)
em_dash_mutation = valid_finding_sample.sub("`fixture/path:1`", "fixture \u2014 path")
expect_packet_rule!(
  "RPPA-011 em dash",
  packet_acceptance_result(em_dash_mutation, github_transport, review_comments_transport, target: "fixture head", mode: "STANDARD", comments: "required_if_findings"),
  "RPPA-011"
)

documented_order_sample = DOCUMENTED_ORDER_PACKET_PATH.read
documented_order_result = packet_acceptance_result(
  documented_order_sample,
  github_transport,
  review_comments_transport,
  target: "PR #1 example/repo, base main 2222222222222222222222222222222222222222, head 1111111111111111111111111111111111111111",
  mode: "FULL",
  comments: "required_if_findings"
)
fail_fixture("documented-order review-comments fixture was rejected") unless documented_order_result.accepted
comments_section = documented_order_sample[/^Review comments:.*?(?=^CI state:)/m]
misplaced_comments = documented_order_sample.sub(comments_section, "").sub(/^Plain-language summary:/, "#{comments_section}Plain-language summary:")
expect_packet_rule!(
  "RPPA-006 review comments after CI",
  packet_acceptance_result(misplaced_comments, github_transport, review_comments_transport, target: "PR #1 example/repo, base main 2222222222222222222222222222222222222222, head 1111111111111111111111111111111111111111", mode: "FULL", comments: "required_if_findings"),
  "RPPA-006"
)

ordinary_payload = valid_finding_result.review_comments_payload
database_payload = {
  "review_event" => "REQUEST_CHANGES",
  "unanchored_findings" => [1],
  "summary_body" => "One blocking database finding requires author follow-up.\n",
  "comments" => []
}
ordinary_only = ReviewerPacketValidator.join_review_comments(ordinary_payload, nil)
database_only = ReviewerPacketValidator.join_review_comments(nil, database_payload)
unless ordinary_only == ordinary_payload
  fail_fixture("ordinary-only review-comments join changed accepted bytes")
end
unless database_only == database_payload
  fail_fixture("database-only review-comments join changed accepted bytes")
end
joined_payload = ReviewerPacketValidator.join_review_comments(ordinary_payload, database_payload)
expected_joined_summary = "## Application review\n\n#{ordinary_payload.fetch('summary_body')}\n## Database review\n\n#{database_payload.fetch('summary_body')}"
unless joined_payload["review_event"] == "REQUEST_CHANGES" &&
       joined_payload["summary_body"] == expected_joined_summary &&
       joined_payload["comments"] == ordinary_payload["comments"]
  fail_fixture("ordinary/database review-comments join changed event, framing, order, or body bytes")
end
duplicate_payload = database_payload.merge("comments" => ordinary_payload.fetch("comments"))
deduped = ReviewerPacketValidator.join_review_comments(ordinary_payload, duplicate_payload)
fail_fixture("exact anchor-and-body duplicate was not retained once") unless deduped.fetch("comments").length == 1
different_body = ordinary_payload.fetch("comments").first.merge("body" => "`issue(non-blocking)` A distinct concern on the same anchor.\n")
same_anchor_distinct = ReviewerPacketValidator.join_review_comments(
  ordinary_payload,
  database_payload.merge("comments" => [different_body])
)
unless same_anchor_distinct.fetch("comments").length == 2 && same_anchor_distinct.fetch("comments").last.fetch("body") == different_body.fetch("body")
  fail_fixture("same-anchor different-body comments were not retained losslessly")
end

invalid_packet = by_id.fetch("packet-invalid-skeleton-terminator").fetch("expected")
fail_fixture("invalid packet fixture must reject invalid/trailing packet") unless invalid_packet.values_at("adjudication", "packet_skeleton", "terminator") == ["reject", "invalid", "trailing_content"]
fail_fixture("invalid packet fixture rejection reasons drifted") unless invalid_packet["required_rejection_reasons"] == %w[first_content_not_verdict content_after_terminator]
invalid_packet_errors = packet_structure_errors(by_id.fetch("packet-invalid-skeleton-terminator").dig("seed", "packet_sample"), github_transport, formal_findings: invalid_packet.fetch("formal_findings", 0))
fail_fixture("invalid packet sample structural errors drifted: #{invalid_packet_errors.join(', ')}") unless invalid_packet_errors == invalid_packet["required_rejection_reasons"]

central = by_id.fetch("central-blocking-verdict").fetch("expected")
fail_fixture("central unknown must be BLOCKED, pass-forbidden, REH-backed, and finding-free") unless central["verdict"] == "BLOCKED" && central["central_unknown"] == true && central["pass_forbidden"] == true && central["reh_required"] == true && central["formal_findings"] == 0

category_cases = {
  "closeout-consequence-advisory" => "consequence_advisory",
  "closeout-simplification" => "simplification",
  "closeout-documentation-truth" => "documentation_truth",
  "closeout-naming-readability" => "naming_readability"
}
category_cases.each do |id, category|
  actual = by_id.fetch(id).dig("expected", "candidate_categories")
  fail_fixture("#{id}: must uniquely exercise #{category}") unless actual == [category]
end

semantic_rules = {
  "material_finding" => lambda do |expected|
    expected["emitted_root_causes"].to_i >= 1 && expected["formal_findings"].to_i >= 1
  end,
  "non_formal_advisory" => lambda do |expected|
    expected["emitted_root_causes"] == 1 && expected["formal_findings"] == 0 && expected["advisory_max"].to_i >= 1
  end,
  "pure_nit" => lambda do |expected|
    expected["emitted_root_causes"] == 0 && expected["formal_findings"] == 0 && expected["pure_nit_suppressed"] == true
  end,
  "clean" => lambda do |expected|
    expected["emitted_root_causes"] == 0 && expected["formal_findings"] == 0 && expected["clean_control"] == true
  end
}
cases.each do |fixture|
  semantic_class = fixture.dig("seed", "semantic_class")
  next unless semantic_class

  rule = semantic_rules[semantic_class]
  fail_fixture("#{fixture['id']}: unknown semantic_class #{semantic_class}") unless rule
  fail_fixture("#{fixture['id']}: expected values contradict semantic_class #{semantic_class}") unless rule.call(fixture.fetch("expected"))
end

overlap = by_id.fetch("overlap-dedupe-single-root").fetch("expected")
fail_fixture("overlap fixture must exercise all closeout categories") unless overlap["candidate_categories"] == EXPECTED_CLOSEOUT_CATEGORIES
fail_fixture("overlap fixture must collapse to one root") unless overlap["emitted_root_causes"] == 1 && overlap["formal_findings"] == 1 && overlap["duplicate_findings_forbidden"] == true && !overlap["dedupe_root"].to_s.empty?

nit = by_id.fetch("pure-nit-suppression").fetch("expected")
fail_fixture("pure nit must be suppressed") unless nit["pure_nit_suppressed"] == true && nit["formal_findings"] == 0 && nit["emitted_root_causes"] == 0

stale_doc = by_id.fetch("stale-operator-documentation").fetch("expected")
fail_fixture("stale operator doc must remain material") unless stale_doc["candidate_categories"] == ["documentation_truth"] && stale_doc["formal_findings"] == 1 && stale_doc["minimum_severity"] == "P2"

unsafe_simplification = by_id.fetch("unsafe-over-simplification").fetch("expected")
fail_fixture("unsafe over-simplification must reject behavior-preserving claim") unless unsafe_simplification["candidate_categories"] == ["simplification"] && unsafe_simplification["verdict"] == "FAIL" && unsafe_simplification["minimum_severity"] == "P1" && unsafe_simplification["behavior_preserving_claim_rejected"] == true

clean = by_id.fetch("clean-control").fetch("expected")
fail_fixture("clean control must cover all categories and emit nothing") unless clean["candidate_categories"] == EXPECTED_CLOSEOUT_CATEGORIES && clean["verdict"] == "PASS" && clean["formal_findings"] == 0 && clean["emitted_root_causes"] == 0 && clean["clean_control"] == true

branch_local = by_id.fetch("branch-local-without-pr-packet").fetch("expected")
fail_fixture("clean branch-local verdict must not fabricate a finding") unless branch_local["formal_findings"] == 0

direct_sql = by_id.fetch("direct-sql-without-pr-packet")
fail_fixture("direct named SQL fixture must cover the no-diff mode") unless direct_sql.dig("route_fields", "target").include?("without an explicit diff") && !direct_sql.dig("seed", "artifact").include?("explicit diff")
fail_fixture("canonical closeout must define no-diff named target units") unless closeout_body.include?("direct named-path") && closeout_body.include?("review without a diff") && closeout_body.include?("not invent a diff or changed-file inventory")
direct_actionable_errors = actionable_finding_errors(direct_sql.dig("seed", "finding_sample"))
fail_fixture("direct SQL finding is not actionable: #{direct_actionable_errors.join(', ')}") unless direct_sql.dig("expected", "formal_findings") == 1 && direct_actionable_errors.empty?
verdict_closeout_body = ROOT.join(".codex/skills/reviewer/references/review-verdict-closeout.md").read
fail_fixture("compact/direct closeout lacks shared actionability law") unless verdict_closeout_body.include?("For every retained finding in any output mode") && verdict_closeout_body.include?("one to three distinct") && verdict_closeout_body.include?("post-fix proof") && verdict_closeout_body.include?("central-proof-only block must") && verdict_closeout_body.include?("not fabricate a finding or Fix shape")

puts "reviewer contract fixtures passed: #{cases.length} packet cases, #{control['candidate_cases'].length} control candidates, #{control['join_cases'].length} joins, #{EXPECTED_ROUTE_FIELDS.length} route fields, #{negative_cases.length} fail-closed transport references"
RUBY

python3 evals/reviewer/graders/existing_conventions_contract.py --self-test
