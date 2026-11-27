# frozen_string_literal: true

require "digest"
require "json"
require "yaml"

module ReviewerPacketValidator
  Issue = Struct.new(:rule_id, :code, :detail, keyword_init: true) do
    def to_h
      { "rule_id" => rule_id, "code" => code, "detail" => detail }
    end
  end

  Result = Struct.new(
    :accepted,
    :transport,
    :source_sha256,
    :packet_sha256,
    :expected_target,
    :expected_mode,
    :review_comments,
    :review_comments_payload,
    :issues,
    keyword_init: true
  ) do
    def to_h
      {
        "schema_version" => 3,
        "accepted" => accepted,
        "transport" => transport,
        "source_sha256" => source_sha256,
        "packet_sha256" => packet_sha256,
        "expected_target" => expected_target,
        "expected_mode" => expected_mode,
        "review_comments" => review_comments,
        "review_comments_payload" => review_comments_payload,
        "issues" => issues.map(&:to_h)
      }
    end
  end

  class DecodeError < StandardError; end

  RULES = {
    "RPPA-001" => "exactly one unambiguous raw or fenced packet with no out-of-band prose",
    "RPPA-002" => "Verdict first and mandatory header fields present in canonical order",
    "RPPA-003" => "trusted review target and mode match exactly",
    "RPPA-004" => "header finding counts match formal finding blocks",
    "RPPA-005" => "formal finding blocks contain the required ordered fields",
    "RPPA-006" => "required packet sections are present in canonical order",
    "RPPA-007" => "Packet ends. is the unique final logical packet line",
    "RPPA-008" => "review-comment presence follows the trusted output contract and finding count",
    "RPPA-009" => "review comments preserve literal UTF-8 bodies, anchors, and finding coverage",
    "RPPA-010" => "singleton packet fields and sections are not duplicated or ambiguous",
    "RPPA-011" => "publishable comment bodies follow docs/agents/pr-comment-conventions.md"
  }.freeze

  module_function

  def load_transport(path)
    transport = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
    [transport.fetch("review_modes").fetch("github_pr"), transport.fetch("review_comments")]
  end

  def validate(source_bytes:, transport:, review_comments_transport:, expected_target:, expected_mode:, review_comments:)
    issues = []
    packet_bytes, transport_kind = extract_packet(source_bytes, issues)
    packet_bytes ||= ""
    lines = packet_bytes.lines(chomp: true)

    validate_headers(lines, transport, issues)
    validate_trusted_fields(lines, expected_target, expected_mode, issues)
    validate_findings(lines, transport.fetch("finding_block"), issues)
    validate_sections(lines, transport, review_comments_transport, issues)
    validate_terminator(lines, transport, issues)
    validate_singletons(lines, transport, review_comments_transport, issues)
    review_comments_payload = validate_review_comments(
      packet_bytes,
      review_comments_transport,
      review_comments,
      issues
    )
    accepted = issues.empty?

    Result.new(
      accepted: accepted,
      transport: transport_kind,
      source_sha256: Digest::SHA256.hexdigest(source_bytes),
      packet_sha256: Digest::SHA256.hexdigest(packet_bytes),
      expected_target: expected_target,
      expected_mode: expected_mode,
      review_comments: review_comments,
      review_comments_payload: accepted ? review_comments_payload : nil,
      issues: issues.uniq { |issue| [issue.rule_id, issue.code, issue.detail] }
    )
  end

  def extract_packet(source_bytes, issues)
    if source_bytes.start_with?("Verdict:")
      return [source_bytes, "raw"]
    end

    match = source_bytes.match(/\A```text\r?\n(?<packet>.*)\r?\n```(?:\r?\n)?\z/m)
    return [match[:packet], "fenced"] if match

    issues << issue("RPPA-001", "ambiguous_transport", "input must be one raw packet or one exact fenced text packet")
    [source_bytes, "invalid"]
  end

  def validate_headers(lines, transport, issues)
    unless lines.first&.start_with?(transport.fetch("first_content_prefix"))
      issues << issue("RPPA-002", "first_content_not_verdict", "first packet line must start with Verdict:")
    end

    offsets = transport.fetch("required_fields").map do |field|
      lines.index { |line| line.start_with?("#{field}:") }
    end
    if offsets.any?(&:nil?)
      missing = transport.fetch("required_fields").zip(offsets).filter_map { |field, offset| field unless offset }
      issues << issue("RPPA-002", "missing_required_field", "missing: #{missing.join(', ')}")
    elsif offsets != offsets.sort
      issues << issue("RPPA-002", "required_field_order", "mandatory packet fields are out of order")
    end
  end

  def validate_trusted_fields(lines, expected_target, expected_mode, issues)
    actual_target = field_value(lines, "Review target")
    actual_mode = field_value(lines, "Review mode")
    if actual_target != expected_target
      issues << issue("RPPA-003", "target_mismatch", "expected #{expected_target.inspect}, got #{actual_target.inspect}")
    end
    if actual_mode != expected_mode
      issues << issue("RPPA-003", "mode_mismatch", "expected #{expected_mode.inspect}, got #{actual_mode.inspect}")
    end
  end

  def validate_findings(lines, finding_transport, issues)
    blocks = finding_block_lines(lines, finding_transport.fetch("first_content_prefix"))
    expected_p01 = formal_count(field_value(lines, "P0/P1 findings"))
    expected_p23 = formal_count(field_value(lines, "P2/P3 findings"))
    actual_p01 = blocks.count { |block| block.first.match?(/\AFinding P[01]:/) }
    actual_p23 = blocks.count { |block| block.first.match?(/\AFinding P[23]:/) }
    if expected_p01.nil? || expected_p23.nil? || expected_p01 != actual_p01 || expected_p23 != actual_p23
      issues << issue(
        "RPPA-004",
        "finding_count_mismatch",
        "header counts #{[expected_p01, expected_p23].inspect} do not match blocks #{[actual_p01, actual_p23].inspect}"
      )
    end

    blocks.each do |block|
      offsets = finding_transport.fetch("required_fields").map do |field|
        block.index { |line| line.start_with?("- #{field}:") }
      end
      if offsets.any?(&:nil?)
        missing = finding_transport.fetch("required_fields").zip(offsets).filter_map { |field, offset| field unless offset }
        issues << issue("RPPA-005", "incomplete_finding_block", "#{block.first}: missing #{missing.join(', ')}")
      elsif offsets != offsets.sort
        issues << issue("RPPA-005", "finding_field_order", "#{block.first}: fields are out of order")
      end

      duplicates = finding_transport.fetch("required_fields").select do |field|
        block.count { |line| line.start_with?("- #{field}:") } > 1
      end
      unless duplicates.empty?
        issues << issue("RPPA-005", "duplicate_finding_field", "#{block.first}: duplicated #{duplicates.join(', ')}")
      end

      heading_severity = block.first[/\AFinding (P[0-3]):/, 1]
      field_severity = block.find { |line| line.start_with?("- Severity:") }&.split(":", 2)&.last&.strip
      if heading_severity && field_severity != heading_severity
        issues << issue(
          "RPPA-005",
          "finding_severity_mismatch",
          "#{block.first}: Severity must equal #{heading_severity}"
        )
      end
    end
  end

  def validate_sections(lines, transport, review_comments_transport, issues)
    ordered = transport.fetch("required_fields")
    offsets = ordered.map { |field| lines.index { |line| line.start_with?("#{field}:") } }
    if offsets.none?(&:nil?) && offsets != offsets.sort
      issues << issue("RPPA-006", "section_order", "required packet sections are out of order")
    end

    comments_offset = lines.index(review_comments_transport.fetch("section_heading"))
    return unless comments_offset

    boundary_offset = boundary_offset_after(lines, comments_offset, review_comments_transport)
    finding_offsets = lines.each_index.select { |index| lines[index].start_with?("Finding P") }
    content_start = finding_offsets.max || offsets.compact.max || -1
    evidence_offsets = boundary_offsets(lines, review_comments_transport).select { |offset| offset > content_start }
    unless boundary_offset && finding_offsets.all? { |offset| offset < comments_offset } &&
           evidence_offsets.all? { |offset| comments_offset < offset }
      issues << issue("RPPA-006", "review_comments_section_order", "review comments must follow every finding block and precede every evidence section")
    end
  end

  def validate_terminator(lines, transport, issues)
    terminator = transport.fetch("terminator")
    offsets = lines.each_index.select { |index| lines[index] == terminator }
    if offsets.empty?
      issues << issue("RPPA-007", "missing_terminator", "missing #{terminator}")
    elsif offsets.length != 1 || offsets.first != lines.length - 1
      issues << issue("RPPA-007", "content_after_or_duplicate_terminator", "terminator must occur once as the final logical line")
    end
  end

  def validate_singletons(lines, transport, review_comments_transport, issues)
    labels = transport.fetch("required_fields") + [review_comments_transport.fetch("section_heading").delete_suffix(":"), "Packet ends."]
    duplicates = labels.select do |label|
      if label == "Packet ends."
        lines.count(label) > 1
      else
        lines.count { |line| line.start_with?("#{label}:") } > 1
      end
    end
    return if duplicates.empty?

    issues << issue("RPPA-010", "duplicate_singleton", "duplicated: #{duplicates.join(', ')}")
  end

  def validate_review_comments(packet, transport, policy, issues)
    present = packet.lines(chomp: true).include?(transport.fetch("section_heading"))
    finding_count = finding_blocks(packet).length
    if policy == "required_if_findings" && finding_count.positive? && !present
      issues << issue("RPPA-008", "review_comments_section_missing", "finding-bearing review requires review comments")
      return nil
    end
    if policy == "required_if_findings" && finding_count.zero? && present
      issues << issue("RPPA-008", "review_comments_section_unexpected", "clean review must omit review comments")
      return nil
    end
    if policy == "forbidden" && present
      issues << issue("RPPA-008", "review_comments_section_forbidden", "trusted output contract forbids review comments")
      return nil
    end
    return nil unless present

    parsed = parse_review_comments(packet, transport, required: true)
    parsed.fetch(:errors).each do |code|
      issues << issue("RPPA-009", code, "review-comment transport integrity failed")
    end
    return nil unless parsed.fetch(:errors).empty?

    payload = parsed.fetch(:payload)
    validate_comment_conventions(payload, transport, issues)
    payload
  end

  # RPPA-011 enforces only the deterministic subset of
  # docs/agents/pr-comment-conventions.md. Wording quality stays reviewer
  # judgment; a pass here is not evidence that a comment is well written.
  def validate_comment_conventions(payload, transport, issues)
    return if payload.nil?

    forbidden = transport["forbidden_body_patterns"] || {}
    first_line_pattern = transport["body_first_line_pattern"]
    check_forbidden(payload["summary_body"].to_s, forbidden, "review summary body", issues)

    payload.fetch("comments", []).each do |comment|
      body = comment["body"].to_s
      label = comment["comment_id"].to_s
      first_line = body.lines.first.to_s.chomp
      match = first_line_pattern ? first_line.match(Regexp.new(first_line_pattern)) : nil
      if first_line_pattern && match.nil?
        issues << issue(
          "RPPA-011",
          "comment_body_missing_conventional_label",
          "#{label}: first line must be a backticked Conventional Comment label with a blocking decoration"
        )
      end

      check_forbidden(body, forbidden, label, issues)
    end
  end

  def check_forbidden(text, forbidden, label, issues)
    forbidden.each do |name, pattern|
      next unless text.match?(Regexp.new(pattern))

      issues << issue("RPPA-011", "forbidden_#{name}", "#{label}: forbidden by docs/agents/pr-comment-conventions.md (#{name})")
    end
  end

  def finding_blocks(sample)
    sample.scan(/^Finding P[0-3]:.*?(?=^Finding P[0-3]:|^Review comments:|^Plain-language summary:|\z)/m).map(&:strip)
  end

  def actionable_finding_errors(sample)
    errors = []
    finding_blocks(sample).each do |block|
      %w[Severity Confidence Category Location Problem Impact Evidence Fix\ shape].each do |field|
        label = field.tr("\\", "")
        errors << "missing_#{label.downcase.tr(' ', '_')}" unless block.match?(/^- #{Regexp.escape(label)}:/)
      end
      evidence = block[/^- Evidence:\s*\n((?:\s+- .+\n?)+)/, 1]
      bullet_count = evidence ? evidence.lines.count { |line| line.match?(/^\s+- /) } : 0
      errors << "evidence_bullet_bound" unless (1..3).cover?(bullet_count)
      fix_shape = block[/^- Fix shape:\s*(.+)$/, 1].to_s.strip
      errors << "generic_fix_shape" if fix_shape.length < 45
      errors << "missing_post_fix_proof" unless fix_shape.match?(/test|verify|assert|validation|check|probe|plan|metric|rehears/i)
    end
    errors.uniq
  end

  # `fixed_before` may be a single label or an ordered list of acceptable
  # closing labels. The first one occurring AFTER the section heading wins, so a
  # packet that omits an earlier evidence section still resolves, and a label
  # that also appears as a packet header field (such as `Variance ledger:`)
  # cannot be mistaken for the boundary.
  def boundary_labels(transport)
    value = transport.fetch("fixed_before")
    value.is_a?(Array) ? value : [value]
  end

  def boundary_patterns(transport)
    (transport["fixed_before_patterns"] || []).map { |pattern| Regexp.new(pattern) }
  end

  def boundary_line?(line, labels, patterns)
    labels.any? { |label| line.start_with?(label) } || patterns.any? { |pattern| line.match?(pattern) }
  end

  def boundary_offset_after(lines, start_offset, transport)
    labels = boundary_labels(transport)
    patterns = boundary_patterns(transport)
    lines.each_index.find do |index|
      index > start_offset && boundary_line?(lines[index], labels, patterns)
    end
  end

  def boundary_offsets(lines, transport)
    labels = boundary_labels(transport)
    patterns = boundary_patterns(transport)
    lines.each_index.select { |index| boundary_line?(lines[index], labels, patterns) }
  end

  def review_comment_blocks(sample, transport)
    lines = sample.lines(chomp: true)
    section_offset = lines.index(transport.fetch("section_heading"))
    return [] unless section_offset

    before_offset = boundary_offset_after(lines, section_offset, transport)
    raise DecodeError, "review comments section lacks fixed closing boundary" unless before_offset

    section = lines[(section_offset + 1)...before_offset]
    offsets = section.each_index.select { |index| section[index].start_with?(transport.fetch("comment_prefix")) }
    offsets.map.with_index do |offset, index|
      boundary = offsets[index + 1] || section.length
      section[offset...boundary]
    end
  end

  def review_comment_errors(sample, transport, required: false)
    parse_review_comments(sample, transport, required: required).fetch(:errors)
  end

  def parse_review_comments(sample, transport, required: false)
    errors = []
    lines = sample.lines(chomp: true)
    section_offset = lines.index(transport.fetch("section_heading"))
    unless section_offset
      errors << "review_comments_section_missing" if required
      return { errors: errors, payload: nil }
    end

    finding_offsets = lines.each_index.select { |index| lines[index].start_with?("Finding P") }
    boundary_offset = boundary_offset_after(lines, section_offset, transport)
    errors << "review_comments_position" unless boundary_offset && finding_offsets.all? { |offset| offset < section_offset }
    unless boundary_offset
      errors << "review_comments_closing_boundary"
      return { errors: errors.uniq, payload: nil }
    end

    section_lines = lines[(section_offset + 1)...boundary_offset]
    event_line = section_lines[0]
    unanchored_line = section_lines[1]
    unless event_line&.start_with?(transport.fetch("review_event_prefix"))
      errors << "review_comments_event_missing"
    end
    event = event_line&.delete_prefix(transport.fetch("review_event_prefix"))&.strip
    errors << "review_comments_event" unless transport.fetch("review_events").include?(event)

    unanchored_value = unanchored_line&.delete_prefix(transport.fetch("unanchored_prefix"))&.strip if
      unanchored_line&.start_with?(transport.fetch("unanchored_prefix"))
    unanchored = parse_unanchored_findings(unanchored_value, errors)
    summary, summary_end, summary_errors = consume_literal(section_lines, 2, "Summary", transport, prefix: "")
    errors.concat(summary_errors)

    comment_start = section_lines.index { |line| line.start_with?(transport.fetch("comment_prefix")) } || section_lines.length
    errors << "review_comments_header_unknown_line" unless summary_end == comment_start
    errors << "review_comments_summary_empty" if summary.to_s.strip.empty?

    finding_data = finding_blocks(sample).map do |block|
      severity = block[/^- Severity:\s*(P[0-3])\s*$/, 1]
      severity || block.lines.first.to_s[/\AFinding (P[0-3]):/, 1]
    end
    comments = review_comment_blocks(sample, transport)
    parsed_comments = []
    comment_ids = []
    inline_ordinals = []
    comments.each_with_index do |block, index|
      expected_id = "Comment C-#{index + 1}:"
      comment_ids << block.first
      errors << "review_comment_id_sequence" unless block.first == expected_id
      parsed, parse_errors = parse_comment_block(block, transport)
      errors.concat(parse_errors)
      next if parsed.nil?

      ordinal = parsed.fetch(:finding)
      inline_ordinals << ordinal
      severity = finding_data[ordinal - 1] if ordinal&.positive?
      errors << "review_comment_finding_ordinal" unless severity
      first_line = parsed.fetch(:body).to_s.lines.first.to_s.chomp
      label_match = first_line.match(Regexp.new(transport.fetch("body_first_line_pattern")))
      if label_match && severity
        expected_decoration = %w[P0 P1].include?(severity) ? "blocking" : "non-blocking"
        errors << "review_comment_decoration_mismatch" unless label_match[2] == expected_decoration
      end
      parsed_comments << {
        "comment_id" => block.first.delete_prefix("Comment ").delete_suffix(":"),
        "finding" => ordinal,
        "anchor" => parsed.fetch(:anchor),
        "body" => parsed.fetch(:body)
      }
    end

    errors << "review_comment_duplicate_id" unless comment_ids.uniq.length == comment_ids.length
    errors << "review_comment_inline_order" unless inline_ordinals == inline_ordinals.sort && inline_ordinals.uniq == inline_ordinals
    errors << "review_comment_ordinal_overlap" unless (inline_ordinals & unanchored).empty?
    expected_ordinals = (1..finding_data.length).to_a
    errors << "review_comment_finding_partition" unless (inline_ordinals + unanchored).sort == expected_ordinals

    expected_event = finding_data.any? { |severity| %w[P0 P1].include?(severity) } ? "REQUEST_CHANGES" : "COMMENT"
    errors << "review_comments_event_severity_mismatch" unless event == expected_event
    errors.uniq!
    payload = {
      "review_event" => event,
      "unanchored_findings" => unanchored,
      "summary_body" => summary,
      "comments" => parsed_comments
    }
    { errors: errors, payload: errors.empty? ? payload : nil }
  rescue DecodeError => e
    { errors: (errors << e.message).uniq, payload: nil }
  end

  def parse_unanchored_findings(value, errors)
    return [] if value == "none"
    unless value&.match?(/\A[1-9]\d*(?:, [1-9]\d*)*\z/)
      errors << "review_comments_unanchored_grammar"
      return []
    end

    ordinals = value.split(", ").map(&:to_i)
    errors << "review_comments_unanchored_order" unless ordinals == ordinals.sort && ordinals.uniq == ordinals
    ordinals
  end

  def parse_comment_block(block, transport)
    errors = []
    field_lines = block.drop(1)
    finding_line = field_lines[0]
    anchor_line = field_lines[1]
    unless finding_line&.match?(/\A- Finding: [1-9]\d*\z/) && anchor_line&.start_with?("- Anchor JSON: ")
      errors << "review_comment_missing_field"
      return [nil, errors]
    end
    ordinal = finding_line.delete_prefix("- Finding: ").to_i
    anchor_value = anchor_line.delete_prefix("- Anchor JSON: ")
    anchor = validate_anchor(anchor_value, errors)
    body, index, body_errors = consume_literal(field_lines, 2, "Body", transport)
    errors.concat(body_errors)
    errors << "review_comment_raw_or_unknown_line" if index < field_lines.length
    errors << "review_comment_body_empty" if body.to_s.strip.empty?
    [{ finding: ordinal, anchor: anchor, body: body }, errors]
  end

  def consume_literal(lines, start_index, field, transport, prefix: "- ")
    header = lines[start_index]
    return [nil, start_index, ["review_comment_literal_missing_header"]] unless header == "#{prefix}#{field}:"
    same_line = header.split(":", 2).fetch(1).strip
    return [nil, start_index, ["review_comment_literal_same_line"]] unless same_line.empty?

    index = start_index + 1
    pipe_lines = []
    while index < lines.length && lines[index].start_with?("  |")
      pipe_lines << lines[index]
      index += 1
    end
    if index < lines.length
      allowed_next = lines[index].start_with?("- ") ||
                     lines[index].start_with?(transport.fetch("comment_prefix")) ||
                     boundary_line?(lines[index], boundary_labels(transport), boundary_patterns(transport))
      return [nil, index, ["review_comment_literal_unprefixed"]] unless allowed_next
    end
    return [nil, index, ["review_comment_literal_empty"]] if pipe_lines.empty?

    decoded = decode_pipe_lines(pipe_lines).dup.force_encoding(Encoding::UTF_8)
    return [nil, index, ["review_comment_literal_invalid_utf8"]] unless decoded.valid_encoding?
    [decoded, index, []]
  end

  def decode_pipe_lines(pipe_lines)
    decoded_lines = pipe_lines.map do |line|
      rest = line.delete_prefix("  |")
      rest = rest.delete_prefix(" ") if rest.start_with?(" ")
      rest
    end
    text = decoded_lines.join("\n")
    return text if text.empty?
    text.end_with?("\n") ? text : "#{text}\n"
  end

  def validate_anchor(value, errors)
    anchor = parse_anchor(value)
    expected_keys = %w[line path side start_line start_side subject_type]
    unless anchor.is_a?(Hash)
      errors << "review_comment_anchor_keys"
      return nil
    end

    errors << "review_comment_anchor_keys" unless anchor.keys.sort == expected_keys
    errors << "review_comment_anchor_canonical" unless JSON.generate(anchor.sort.to_h) == value
    validate_anchor_values(anchor, errors) if anchor.keys.sort == expected_keys
    anchor
  rescue JSON::ParserError
    errors << "review_comment_anchor_json"
    nil
  end

  def parse_anchor(value)
    JSON.parse(value)
  end

  def validate_anchor_values(anchor, errors)
    path = anchor.fetch("path")
    subject_type = anchor.fetch("subject_type")
    line = anchor.fetch("line")
    side = anchor.fetch("side")
    start_line = anchor.fetch("start_line")
    start_side = anchor.fetch("start_side")

    path_segments = path.is_a?(String) ? path.split("/", -1) : []
    valid_path = path.is_a?(String) && !path.empty? && !path.start_with?("/") &&
                 !path.include?("\0") &&
                 path_segments.none? { |segment| segment.empty? || %w[. ..].include?(segment) }
    errors << "review_comment_anchor_path" unless valid_path

    case subject_type
    when "file"
      errors << "review_comment_anchor_file_shape" unless [line, side, start_line, start_side].all?(&:nil?)
    when "line"
      valid_line = line.is_a?(Integer) && line.positive? && %w[LEFT RIGHT].include?(side)
      errors << "review_comment_anchor_line_shape" unless valid_line
      if start_line.nil?
        errors << "review_comment_anchor_start_shape" unless start_side.nil?
      else
        valid_start = start_line.is_a?(Integer) && start_line.positive? &&
                      line.is_a?(Integer) && start_line < line &&
                      start_side == side
        errors << "review_comment_anchor_start_shape" unless valid_start
      end
    else
      errors << "review_comment_anchor_subject_type"
    end
  end

  def values_for(fields, lines)
    return {} unless fields.all? { |field| lines.any? { |line| line.start_with?("- #{field}:") } }

    fields.to_h do |field|
      line = lines.find { |candidate| candidate.start_with?("- #{field}:") }
      [field, line.split(":", 2).fetch(1).strip]
    end
  end

  def finding_block_lines(lines, prefix)
    offsets = lines.each_index.select { |index| lines[index].start_with?(prefix) }
    offsets.map.with_index do |offset, index|
      boundary = offsets[index + 1] || lines.length
      lines[offset...boundary]
    end
  end

  def join_review_comments(ordinary_payload, database_payload)
    payloads = [ordinary_payload, database_payload].compact
    return nil if payloads.empty?
    return payloads.first if payloads.length == 1

    ordinary = ordinary_payload
    database = database_payload
    event = payloads.any? { |payload| payload.fetch("review_event") == "REQUEST_CHANGES" } ? "REQUEST_CHANGES" : "COMMENT"
    summary = "## Application review\n\n#{ordinary.fetch('summary_body')}\n## Database review\n\n#{database.fetch('summary_body')}"
    comments = (ordinary.fetch("comments") + database.fetch("comments")).uniq do |comment|
      [JSON.generate(comment.fetch("anchor").sort.to_h), comment.fetch("body")]
    end
    { "review_event" => event, "summary_body" => summary, "comments" => comments }
  end

  def formal_count(value)
    return nil unless value
    match = value.match(/\A(\d+) code findings\b/) || value.match(/\A(\d+)\b/)
    return match[1].to_i if match

    nil
  end

  def field_value(lines, field)
    line = lines.find { |candidate| candidate.start_with?("#{field}:") }
    line&.split(":", 2)&.last&.strip
  end

  def issue(rule_id, code, detail)
    Issue.new(rule_id: rule_id, code: code, detail: detail)
  end
end
