#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "open3"
require "optparse"
require "pathname"
require "securerandom"
require "tmpdir"
require "time"
require "yaml"

class BehaviorEvalError < StandardError; end

class PiTraceAudit
  ALLOWED_TYPES = %w[
    session agent_start turn_start message_start message_update message_end
    turn_end agent_end auto_retry_start auto_retry_end agent_settled
  ].freeze
  SAFE_UPDATE_TYPES = %w[
    text_start text_delta text_end thinking_start thinking_delta thinking_end
  ].freeze
  SAFE_CONTENT_TYPES = %w[text thinking].freeze

  def self.parse(text, provider:, model:, api:)
    events = text.lines.reject { |line| line.strip.empty? }.map.with_index do |line, index|
      JSON.parse(line)
    rescue JSON::ParserError => e
      raise BehaviorEvalError, "Pi trace line #{index + 1} is not valid JSON: #{e.message}"
    end
    raise BehaviorEvalError, "Pi trace is empty" if events.empty?

    user_ends = []
    assistant_ends = []
    turn_ends = []

    events.each_with_index do |event, index|
      raise BehaviorEvalError, "Pi trace line #{index + 1} is not a JSON object" unless event.is_a?(Hash)

      type = event["type"]
      unless type.is_a?(String) && ALLOWED_TYPES.include?(type)
        raise BehaviorEvalError,
              "Pi trace line #{index + 1} has an unknown event type: #{type.inspect}"
      end
      reject_tool_activity!(event)

      if type == "message_update"
        update_type = event.dig("assistantMessageEvent", "type")
        unless update_type.is_a?(String) && SAFE_UPDATE_TYPES.include?(update_type)
          raise BehaviorEvalError, "Pi trace contains an unknown or tool-capable message update"
        end
      end
      user_ends << event if type == "message_end" && event.dig("message", "role") == "user"
      assistant_ends << event if type == "message_end" && event.dig("message", "role") == "assistant"
      turn_ends << event if type == "turn_end"
    end

    require_count!(events, "session", 1)
    require_count!(events, "agent_settled", 1)
    raise BehaviorEvalError, "Pi trace must contain exactly one user prompt message" unless user_ends.length == 1
    raise BehaviorEvalError, "Pi trace has no assistant terminal message" if assistant_ends.empty?

    run_count = assistant_ends.length
    require_count!(events, "agent_start", run_count)
    require_count!(events, "turn_start", run_count)
    require_count!(events, "agent_end", run_count)
    require_count!(events, "turn_end", run_count)
    require_count!(events, "message_start", run_count + 1)
    require_count!(events, "message_end", run_count + 1)
    retry_count = validate_retry_events!(events, run_count)
    validate_lifecycle!(events, run_count, retry_count)

    message_starts = events.select { |event| event["type"] == "message_start" }
    unless message_starts.map { |event| event.dig("message", "role") } == ["user", *Array.new(run_count, "assistant")]
      raise BehaviorEvalError, "Pi trace message starts are not one user prompt followed by assistant attempts"
    end
    agent_ends = events.select { |event| event["type"] == "agent_end" }
    agent_end = agent_ends.last
    raise BehaviorEvalError, "Pi trace ended with a pending retry" unless agent_end["willRetry"] == false

    user_message = user_ends.first.fetch("message")
    terminal_message = assistant_ends.last.fetch("message")
    raise BehaviorEvalError, "Pi user prompt messages disagree" unless message_starts.first.fetch("message") == user_message
    assistant_messages = assistant_ends.map { |event| event.fetch("message") }
    assistant_messages.each_with_index do |attempt, index|
      verify_identity!(attempt, provider:, model:, api:)
      unless attempt["role"] == "assistant" && attempt["content"].is_a?(Array) &&
             attempt["content"].all? { |block| block.is_a?(Hash) && SAFE_CONTENT_TYPES.include?(block["type"]) }
        raise BehaviorEvalError, "Pi assistant attempt has an unexpected schema"
      end
      turn = turn_ends.fetch(index)
      unless turn["toolResults"].is_a?(Array) && turn["toolResults"].empty?
        raise BehaviorEvalError, "Pi trace contains non-empty or malformed tool results"
      end
      raise BehaviorEvalError, "Pi turn messages disagree" unless turn["message"] == attempt
      next if index == assistant_messages.length - 1

      raise BehaviorEvalError, "Pi retry attempt did not end with an error" unless attempt["stopReason"] == "error"
      raise BehaviorEvalError, "Pi failed attempt was not marked for retry" unless agent_ends.fetch(index)["willRetry"] == true
    end
    unless terminal_message["stopReason"] == "stop"
      raise BehaviorEvalError, "Pi terminal message did not stop successfully"
    end
    expected_agent_messages = assistant_messages.map.with_index do |attempt, index|
      index.zero? ? [user_message, attempt] : [attempt]
    end
    unless agent_ends.map { |event| event["messages"] } == expected_agent_messages
      raise BehaviorEvalError, "Pi agent end messages disagree with the prompt and assistant attempts"
    end

    output = terminal_message["content"].filter_map do |block|
      block["text"] if block.is_a?(Hash) && block["type"] == "text" && block["text"].is_a?(String)
    end.join
    raise BehaviorEvalError, "Pi terminal result is empty" if output.strip.empty?

    {
      "event_count" => events.length,
      "tool_calls" => 0,
      "retry_count" => retry_count,
      "trace_provider" => terminal_message["provider"],
      "trace_model" => terminal_message["model"],
      "trace_api" => terminal_message["api"],
      "usage" => terminal_message["usage"],
      "output" => output
    }
  end

  def self.reject_tool_activity!(value)
    case value
    when Hash
      value.each do |key, child|
        if key == "type" && child.is_a?(String) && child.downcase.include?("tool")
          raise BehaviorEvalError, "Pi trace contains tool activity"
        elsif key == "role" && child == "toolResult"
          raise BehaviorEvalError, "Pi trace contains a tool result"
        end
        reject_tool_activity!(child)
      end
    when Array
      value.each { |child| reject_tool_activity!(child) }
    end
  end

  def self.require_count!(events, type, expected)
    count = events.count { |event| event["type"] == type }
    return if count == expected

    raise BehaviorEvalError, "Pi trace must contain exactly #{expected} #{type} event"
  end

  def self.validate_retry_events!(events, run_count)
    starts = events.select { |event| event["type"] == "auto_retry_start" }
    ends = events.select { |event| event["type"] == "auto_retry_end" }
    expected_count = run_count - 1
    unless starts.length == expected_count && ends.length == (expected_count.positive? ? 1 : 0)
      raise BehaviorEvalError, "Pi trace retry event count does not match assistant attempts"
    end
    return 0 if expected_count.zero?

    starts.each_with_index do |event, index|
      attempt = index + 1
      unless event["attempt"] == attempt && event["maxAttempts"].is_a?(Integer) &&
             event["maxAttempts"] >= attempt && event["delayMs"].is_a?(Integer) &&
             event["delayMs"] >= 0 && event["errorMessage"].is_a?(String) && !event["errorMessage"].empty?
        raise BehaviorEvalError, "Pi trace contains a malformed retry start event"
      end
    end
    finish = ends.first
    unless finish["success"] == true && finish["attempt"] == expected_count && !finish.key?("finalError")
      raise BehaviorEvalError, "Pi trace retry did not finish successfully"
    end
    expected_count
  end

  def self.validate_lifecycle!(events, run_count, retry_count)
    types = events.map { |event| event.fetch("type") }.reject { |type| type == "message_update" }
    expected = %w[session agent_start turn_start message_start message_end]
    run_count.times do |index|
      expected << "message_start" << "message_end"
      expected << "auto_retry_end" if retry_count.positive? && index == run_count - 1
      expected << "turn_end" << "agent_end"
      expected.concat(%w[auto_retry_start agent_start turn_start]) if index < run_count - 1
    end
    expected << "agent_settled"
    return if types == expected

    raise BehaviorEvalError, "Pi trace lifecycle is incomplete or out of order"
  end

  def self.verify_identity!(message, provider:, model:, api:)
    expected = { "provider" => provider, "model" => model, "api" => api }
    expected.each do |key, value|
      next if message[key] == value

      raise BehaviorEvalError, "Pi terminal #{key} does not match the requested execution identity"
    end
  end
end

class BehaviorEvalRunner
  PI_PROVIDER = "openai-codex"
  PI_MODEL = "gpt-5.6-luna"
  PI_API = "openai-codex-responses"
  PI_THINKING = "low"
  PI_ENVELOPE_VERSION = "pi-behavior-evaluation-v4"
  PI_PROMPT_FILE = "evaluation-prompt.md"
  PI_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are an isolated behavior-evaluation subject. Follow only the evaluation
    task and supplied context. Do not call tools; tools are disabled. Return the
    complete answer required by the task. Address every requested dimension and
    preserve exact labels, numeric bounds, statuses, ownership distinctions,
    and fail-closed conditions from the supplied context. Do not collapse
    explicitly separate requirements into a summary.
  PROMPT
  ROUTES = %w[auto vpn no-vpn].freeze

  attr_reader :options

  def initialize(options)
    @options = options
    configured_root = options[:repo_root]
    candidate_root = if configured_root
                       Pathname.new(configured_root)
                     else
                       Pathname.new(File.expand_path("../..", __dir__))
                     end
    if configured_root && !candidate_root.absolute?
      raise BehaviorEvalError, "--repo-root must be an absolute path"
    end
    unless candidate_root.directory?
      raise BehaviorEvalError, "repository root does not exist or is not a directory: #{candidate_root}"
    end
    @root = candidate_root.realpath
  end

  def run
    suite_path, suite, task_path, task, skill_root = load_contract
    route = select_route
    return emit_dry_run(route, suite_path, suite, task_path, task, skill_root) if options[:dry_run]

    if route == "vpn"
      run_waza(suite_path, suite, task_path, task, skill_root)
    else
      run_pi(suite_path, suite, task_path, task, skill_root)
    end
  rescue BehaviorEvalError => e
    warn "error: #{e.message}"
    1
  end

  private

  def load_contract
    raise BehaviorEvalError, "--suite is required" unless options[:suite]
    raise BehaviorEvalError, "--task is required" unless options[:task]

    suite_path = resolve_repo_file(options[:suite])
    suite = load_yaml(suite_path)
    task_patterns = Array(suite["tasks"])
    task_paths = task_patterns.flat_map { |pattern| Dir.glob(File.expand_path(pattern, suite_path.dirname)) }.uniq.sort
    task_pair = task_paths.lazy.map { |path| [Pathname.new(path), load_yaml(Pathname.new(path))] }
                          .find { |_path, value| value["id"] == options[:task] }
    raise BehaviorEvalError, "task ID not found in suite: #{options[:task]}" unless task_pair

    skill_name = suite["skill"]
    raise BehaviorEvalError, "suite has no skill" unless skill_name.is_a?(String) && !skill_name.empty?

    skill_root = Array(suite.dig("config", "skill_directories")).lazy.map do |directory|
      suite_path.dirname.join(directory, skill_name).cleanpath
    end.find { |path| path.join("SKILL.md").file? }
    raise BehaviorEvalError, "target SKILL.md was not found for #{skill_name}" unless skill_root

    [suite_path, suite, *task_pair, skill_root.realpath]
  end

  def load_yaml(path)
    value = YAML.safe_load(path.read, permitted_classes: [], aliases: false)
    raise BehaviorEvalError, "YAML root must be a mapping: #{relative(path)}" unless value.is_a?(Hash)
    value
  rescue Psych::Exception => e
    raise BehaviorEvalError, "invalid YAML at #{relative(path)}: #{e.message}"
  end

  def resolve_repo_file(path)
    candidate = @root.join(path).cleanpath
    raise BehaviorEvalError, "file does not exist: #{path}" unless candidate.file?
    ensure_under(candidate.realpath, @root.realpath, "path escapes repository: #{path}")
  end

  def selected_instruction_files(skill_root)
    requested = options[:instruction_files].map { |path| resolve_repo_file(path) }.uniq
    pending = requested.dup
    selected = []
    reference_sources = [skill_root.join("SKILL.md")]

    until pending.empty?
      accepted = pending.select do |candidate|
        next true if under?(candidate, skill_root)
        next false unless candidate.extname == ".md"

        referenced = relative(candidate)
        reference_sources.any? { |source| source.read.include?(referenced) }
      end
      if accepted.empty?
        paths = pending.map { |path| relative(path) }.join(", ")
        raise BehaviorEvalError,
              "instruction file is outside the target skill tree and not linked by supplied instructions: #{paths}"
      end

      selected.concat(accepted)
      reference_sources.concat(accepted)
      pending -= accepted
    end

    requested & selected
  end

  def under?(path, parent)
    path_string = path.realpath.to_s
    parent_string = parent.realpath.to_s
    path_string == parent_string || path_string.start_with?("#{parent_string}/")
  end

  def ensure_under(path, parent, message)
    path_string = path.to_s
    parent_string = parent.to_s
    return path if path_string == parent_string || path_string.start_with?("#{parent_string}/")
    raise BehaviorEvalError, message
  end

  def select_route
    route = options[:route]
    raise BehaviorEvalError, "unknown route: #{route}" unless ROUTES.include?(route)
    return route unless route == "auto"
    raise BehaviorEvalError, "--dry-run with route auto is ambiguous; select vpn or no-vpn" if options[:dry_run]

    smoke = @root.join("scripts/dev/agent-collab-vpn-smoke.sh")
    stdout, stderr, status = Open3.capture3(smoke.to_s, chdir: @root.to_s)
    $stdout.write(stdout)
    $stderr.write(stderr)
    if status.success?
      @vpn_smoke_passed = true
      "vpn"
    else
      "no-vpn"
    end
  end

  def run_waza(suite_path, suite, task_path, task, skill_root)
    require_vpn! unless @vpn_smoke_passed
    waza = executable("waza") || @root.join("tmp/waza-bin/waza").then { |path| path.executable? ? path.to_s : nil }
    raise BehaviorEvalError, "waza executable was not found" unless waza

    output = output_path(task["id"], "waza")
    ensure_new_output!(output)
    FileUtils.mkdir_p(output.dirname)
    instruction_files = selected_instruction_files(skill_root)
    models = resolve_waza_models(suite, task)
    inputs = digest_inputs(suite_path, skill_root, task_path, task, instruction_files)
    with_waza_overlay(
      suite_path,
      suite,
      task_path,
      skill_root,
      instruction_files,
      models
    ) do |overlay, overlay_suite, context_dir|
      command = [waza, "run", overlay_suite.to_s, "--task", task["id"], "--output", output.to_s]
      command.concat(["--context-dir", context_dir.to_s]) if context_dir
      success = system(*command, chdir: overlay.to_s)
      raise BehaviorEvalError, "Waza behavior evaluation failed" unless success
    end
    write_waza_contract(output, suite_path, task, models, inputs)
    puts "Waza behavior result written to #{relative(output)}"
    0
  end

  def resolve_waza_models(suite, task)
    execution_model = options[:waza_model] || suite.dig("config", "model")
    unless execution_model.is_a?(String) && !execution_model.empty? && execution_model != "auto"
      raise BehaviorEvalError, "VPN route requires --waza-model because the suite execution model is unresolved"
    end

    prompt_graders = task.fetch("graders").select { |grader| grader["type"] == "prompt" }
    judge_models = prompt_graders.map do |grader|
      model = options[:waza_judge_model] || grader.dig("config", "model")
      unless model.is_a?(String) && !model.empty? && model != "auto"
        raise BehaviorEvalError, "VPN route requires --waza-judge-model because a prompt-grader model is unresolved"
      end
      model
    end
    { "execution" => execution_model, "judges" => judge_models }
  end

  def with_waza_overlay(suite_path, suite, task_path, skill_root, instruction_files, models)
    Dir.mktmpdir("waza-behavior-") do |directory|
      overlay = Pathname.new(directory)
      relative_suite_dir = suite_path.dirname.realpath.relative_path_from(@root.realpath)
      overlay_suite_dir = overlay.join(relative_suite_dir)
      FileUtils.mkdir_p(overlay_suite_dir.dirname)
      FileUtils.cp_r(suite_path.dirname, overlay_suite_dir)

      overlay_skill_root = overlay.join(".codex/skills", suite.fetch("skill"))
      FileUtils.mkdir_p(overlay_skill_root.dirname)
      FileUtils.cp_r(skill_root, overlay_skill_root)

      overlay_suite = overlay_suite_dir.join(suite_path.basename)
      overlay_contract = load_yaml(overlay_suite)
      overlay_config = overlay_contract.fetch("config")
      overlay_config["model"] = models.fetch("execution")
      overlay_config["skill_directories"] = [
        overlay.join(".codex/skills").relative_path_from(overlay_suite.dirname).to_s
      ]

      overlay_task_path = overlay.join(task_path.realpath.relative_path_from(@root.realpath))
      overlay_task = load_yaml(overlay_task_path)
      judge_index = 0
      overlay_task.fetch("graders").each do |grader|
        next unless grader["type"] == "prompt"

        grader.fetch("config")["model"] = models.fetch("judges").fetch(judge_index)
        judge_index += 1
      end

      source_context = suite_path.dirname.join("fixtures")
      overlay_context = overlay_suite_dir.join("fixtures")
      FileUtils.cp_r(source_context, overlay_context) if source_context.directory? && !overlay_context.exist?
      selected_names = copy_context_files(
        instruction_files,
        overlay_context,
        relative_to: overlay_context,
        prefix: "selected"
      )
      existing_names = Array(overlay_config["instruction_files"])
      overlay_config["instruction_files"] = existing_names + selected_names unless selected_names.empty?
      overlay_suite.write(YAML.dump(overlay_contract))
      overlay_task_path.write(YAML.dump(overlay_task))

      needs_context = overlay_context.directory? || !Array(overlay_config["instruction_files"]).empty?
      yield overlay, overlay_suite, needs_context ? overlay_context : nil
    end
  end

  def require_vpn!
    smoke = @root.join("scripts/dev/agent-collab-vpn-smoke.sh")
    success = system(smoke.to_s, chdir: @root.to_s)
    raise BehaviorEvalError, "VPN route requires a passing collaboration VPN smoke" unless success
  end

  def run_pi(suite_path, suite, task_path, task, skill_root)
    validate_graders!(task)
    instruction_files = selected_instruction_files(skill_root)
    model_catalog = verify_pi_model_catalog!
    auth = verify_pi_auth!
    output = output_path(task["id"], "pi")
    ensure_new_output!(output)
    FileUtils.mkdir_p(output.dirname)
    inputs = digest_inputs(suite_path, skill_root, task_path, task, instruction_files)

    result = {
      "evidence_kind" => "pi-openai-codex-behavior",
      "route" => "no-vpn",
      "suite" => relative(suite_path),
      "task" => task["id"],
      "task_file" => relative(task_path),
      "requested_candidate_identity" => pi_identity,
      "requested_judge_identity" => pi_identity,
      "model_catalog_preflight" => model_catalog,
      "auth_preflight" => auth,
      "effective_provider_model" => "Pending Verification: Pi trace identity is not provider-side telemetry",
      "input_isolation" => "mechanically constrained by Pi discovery, session, and tool-disable flags; hidden provider context is not proven absent",
      "invocation_envelope_version" => PI_ENVELOPE_VERSION,
      "runner_sha256" => runner_sha256,
      "source_head" => source_head,
      "inputs" => inputs,
      "candidate_digest" => candidate_digest(inputs),
      "graders" => []
    }

    Dir.mktmpdir("pi-behavior-candidate-") do |candidate_dir|
      candidate_trace, candidate_contract = run_pi_subject(
        workspace: Pathname.new(candidate_dir),
        purpose: "candidate",
        prompt: task.dig("inputs", "prompt"),
        context_files: [skill_root.join("SKILL.md"), *instruction_files]
      )
      candidate_audit = audit_pi_trace(candidate_trace)
      candidate_output = candidate_audit.fetch("output")
      result["candidate"] = {
        "trace_sha256" => Digest::SHA256.hexdigest(candidate_trace),
        "trace_audit" => candidate_audit.reject { |key, _| key == "output" },
        "invocation_contract" => candidate_contract,
        "output" => candidate_output
      }

      task.fetch("graders").each do |grader|
        result["graders"] << grade(grader, task, candidate_output)
      end
    end

    result["passed"] = result["graders"].all? { |grader| grader["passed"] }
    output.write(JSON.pretty_generate(result) << "\n")
    outcome = result["passed"] ? "PASSED" : "FAILED"
    puts "Pi OpenAI Codex behavior #{outcome}: result written to #{relative(output)}"
    result["passed"] ? 0 : 1
  end

  def verify_pi_model_catalog!
    stdout, stderr, status = Open3.capture3(
      pi_environment,
      pi_binary!, "--list-models", PI_MODEL,
      chdir: @root.to_s
    )
    raise BehaviorEvalError, "Pi model catalog preflight failed: #{stderr.strip}" unless status.success?

    entry = stdout.lines.map { |line| line.split }.find do |fields|
      fields[0] == PI_PROVIDER && fields[1] == PI_MODEL
    end
    raise BehaviorEvalError, "Pi model catalog does not advertise #{PI_PROVIDER}/#{PI_MODEL}" unless entry

    {
      "provider" => PI_PROVIDER,
      "model" => PI_MODEL,
      "observed_at" => Time.now.utc.iso8601
    }
  end

  def verify_pi_auth!
    stdout, stderr, status = Open3.capture3(
      pi_environment,
      pi_binary!, "auth", "check", "--provider", PI_PROVIDER, "--model", PI_MODEL, "--json",
      chdir: @root.to_s
    )
    raise BehaviorEvalError, "Pi OAuth preflight failed: #{stderr.strip}" unless status.success?

    auth = JSON.parse(stdout)
    unless auth == { "status" => "ready", "provider" => PI_PROVIDER, "authType" => "oauth" }
      raise BehaviorEvalError, "Pi auth is not ready through OpenAI Codex OAuth"
    end
    auth.merge("observed_at" => Time.now.utc.iso8601)
  rescue JSON::ParserError => e
    raise BehaviorEvalError, "Pi auth preflight is not valid JSON: #{e.message}"
  end

  def grade(grader, task, candidate_output)
    case grader["type"]
    when "program"
      grade_program(grader, candidate_output)
    when "text"
      grade_text(grader, candidate_output)
    when "prompt"
      grade_prompt(grader, task, candidate_output)
    else
      raise BehaviorEvalError, "unsupported grader type: #{grader["type"]}"
    end
  end

  def grade_text(grader, candidate_output)
    config = grader.fetch("config", {})
    required = compile_patterns(config["regex_match"], "regex_match")
    forbidden = compile_patterns(config["regex_not_match"], "regex_not_match")
    if required.empty? && forbidden.empty?
      raise BehaviorEvalError, "text grader must declare regex_match or regex_not_match"
    end

    required_results = required.map do |pattern, regex|
      { "pattern" => pattern, "matched" => regex.match?(candidate_output) }
    end
    forbidden_results = forbidden.map do |pattern, regex|
      { "pattern" => pattern, "matched" => regex.match?(candidate_output) }
    end
    {
      "name" => grader["name"],
      "type" => "text-regex",
      "passed" => required_results.all? { |result| result["matched"] } &&
        forbidden_results.none? { |result| result["matched"] },
      "regex_match" => required_results,
      "regex_not_match" => forbidden_results
    }
  end

  def compile_patterns(raw_patterns, field)
    patterns = Array(raw_patterns)
    unless patterns.all? { |pattern| pattern.is_a?(String) && !pattern.empty? }
      raise BehaviorEvalError, "text grader #{field} must contain non-empty strings"
    end
    patterns.map do |pattern|
      source = pattern
      options = 0
      if (flags = /\A\(\?([ims]+)\)/.match(source))
        source = source.delete_prefix(flags[0])
        options |= Regexp::IGNORECASE if flags[1].include?("i")
        options |= Regexp::MULTILINE if flags[1].include?("s")
      end
      [pattern, Regexp.new(source, options)]
    end
  rescue RegexpError => e
    raise BehaviorEvalError, "text grader #{field} contains an invalid regular expression: #{e.message}"
  end

  def grade_program(grader, candidate_output)
    config = grader.fetch("config")
    command = config["command"]
    args = Array(config["args"])
    raise BehaviorEvalError, "program grader command is missing" unless command.is_a?(String) && !command.empty?
    raise BehaviorEvalError, "program grader args must be strings" unless args.all? { |arg| arg.is_a?(String) }

    stdout, stderr, status = Open3.capture3(command, *args, stdin_data: candidate_output, chdir: @root.to_s)
    {
      "name" => grader["name"],
      "type" => "program",
      "passed" => status.success?,
      "exit_status" => status.exitstatus,
      "stdout" => stdout,
      "stderr" => stderr
    }
  rescue Errno::ENOENT => e
    raise BehaviorEvalError, "program grader could not start: #{e.message}"
  end

  def grade_prompt(grader, task, candidate_output)
    config = grader.fetch("config")
    raise BehaviorEvalError, "inline config.prompt graders are unsupported in the Pi lane" if config.key?("prompt")
    rubric_path = config["rubric"]
    raise BehaviorEvalError, "prompt grader must use config.rubric" unless rubric_path.is_a?(String)

    rubric = resolve_repo_file(rubric_path).read
    derived = derive_rubric(rubric)
    judge_prompt = <<~PROMPT
      Grade the candidate response against every requirement in the grading contract.
      The first non-empty output line must be exactly PI_BEHAVIOR_GRADE: PASS
      or PI_BEHAVIOR_GRADE: FAIL. After that line, briefly name the decisive
      satisfied or failed requirements. Do not call tools.

      ## Original task
      #{task.dig("inputs", "prompt")}

      ## Candidate response
      #{candidate_output}

      ## Grading contract
      #{derived}
    PROMPT

    Dir.mktmpdir("pi-behavior-judge-") do |judge_dir|
      trace, contract = run_pi_subject(
        workspace: Pathname.new(judge_dir),
        purpose: "judge",
        prompt: judge_prompt,
        context_files: []
      )
      audit = audit_pi_trace(trace)
      judge_output = audit.fetch("output")
      grade = parse_grade(judge_output)
      {
        "name" => grader["name"],
        "type" => "prompt-rubric",
        "passed" => grade == "PASS",
        "rubric_sha256" => Digest::SHA256.hexdigest(rubric),
        "derived_prompt_sha256" => Digest::SHA256.hexdigest(judge_prompt),
        "trace_sha256" => Digest::SHA256.hexdigest(trace),
        "trace_audit" => audit.reject { |key, _| key == "output" },
        "invocation_contract" => contract,
        "output" => judge_output
      }
    end
  end

  def derive_rubric(rubric)
    pattern = /Call `set_waza_grade_pass` once if every requirement holds\. Otherwise call\s+`set_waza_grade_fail` once[^\n]*(?:\n[^\n]*)?\z/m
    replacement = <<~TEXT.strip
      For the Pi OpenAI Codex judge transport, preserve every requirement above.
      Emit `PI_BEHAVIOR_GRADE: PASS` only if every requirement holds;
      otherwise emit `PI_BEHAVIOR_GRADE: FAIL` and name the missing or contradicted requirement.
    TEXT
    derived, count = rubric.sub(pattern, replacement), rubric.scan(pattern).length
    raise BehaviorEvalError, "rubric must contain exactly one Waza native grade-tool closeout" unless count == 1
    derived
  end

  def parse_grade(output)
    first = output.lines.find { |line| !line.strip.empty? }&.strip
    match = /\API_BEHAVIOR_GRADE: (PASS|FAIL)\z/.match(first.to_s)
    raise BehaviorEvalError, "Pi judge output has a malformed grade" unless match
    match[1]
  end

  def validate_graders!(task)
    graders = task["graders"]
    raise BehaviorEvalError, "task must declare at least one grader" unless graders.is_a?(Array) && !graders.empty?
    graders.each do |grader|
      raise BehaviorEvalError, "grader must be a mapping" unless grader.is_a?(Hash)
      unless %w[program text prompt].include?(grader["type"])
        raise BehaviorEvalError, "unsupported grader type: #{grader["type"]}"
      end
      if grader["type"] == "prompt" && grader.fetch("config", {}).key?("prompt")
        raise BehaviorEvalError, "inline config.prompt graders are unsupported in the Pi lane"
      end
      compile_patterns(grader.dig("config", "regex_match"), "regex_match") if grader["type"] == "text"
      compile_patterns(grader.dig("config", "regex_not_match"), "regex_not_match") if grader["type"] == "text"
    end
  end

  def run_pi_subject(workspace:, purpose:, prompt:, context_files:)
    raise BehaviorEvalError, "task prompt is missing" unless prompt.is_a?(String) && !prompt.strip.empty?

    copied_context = copy_context_files(
      context_files,
      workspace.join("inputs"),
      relative_to: workspace
    )
    rendered_prompt = render_pi_prompt(workspace, prompt, copied_context)
    workspace.join(PI_PROMPT_FILE).binwrite(rendered_prompt)
    command = pi_command("@#{PI_PROMPT_FILE}")
    contract = pi_invocation_contract(command, rendered_prompt, copied_context)
    stdout, stderr, status = Open3.capture3(
      pi_environment,
      *command,
      chdir: workspace.to_s
    )
    raise BehaviorEvalError, "Pi #{purpose} call failed: #{stderr.strip}" unless status.success?
    raise BehaviorEvalError, "Pi #{purpose} wrote unexpected stderr: #{stderr.strip}" unless stderr.empty?

    [stdout, contract]
  end

  def copy_context_files(context_files, destination_root, relative_to:, prefix: nil)
    context_files.map do |source|
      validate_context_file!(source)
      parts = [prefix, Digest::SHA256.hexdigest(source.to_s)[0, 12], source.basename.to_s].compact
      destination = destination_root.join(*parts)
      FileUtils.mkdir_p(destination.dirname)
      FileUtils.cp(source, destination)
      destination.relative_path_from(relative_to).to_s
    end
  end

  def validate_context_file!(source)
    bytes = source.binread
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    raise BehaviorEvalError, "context file is not valid UTF-8: #{relative(source)}" unless text.valid_encoding?
    raise BehaviorEvalError, "context file contains a NUL byte: #{relative(source)}" if bytes.include?("\0")
  end

  def render_pi_prompt(workspace, prompt, copied_context)
    sections = copied_context.map do |path|
      raw = workspace.join(path).binread.force_encoding(Encoding::UTF_8)
      closing = raw.end_with?("\n") ? "```" : "\n```"
      "### File: #{path}\n```text\n#{raw}#{closing}"
    end
    ["## Evaluation task\n#{prompt}", "## Supplied context\n#{sections.join("\n\n")}"].join("\n\n")
  end

  def pi_command(prompt_reference)
    [
      pi_binary!, "--provider", PI_PROVIDER, "--model", PI_MODEL,
      "--thinking", PI_THINKING, "--mode", "json", "--print", "--no-session",
      "--no-tools", "--no-extensions", "--no-skills", "--no-prompt-templates",
      "--no-themes", "--no-context-files", "--no-approve",
      "--system-prompt", PI_SYSTEM_PROMPT, "--", prompt_reference
    ]
  end

  def pi_invocation_contract(command, rendered_prompt, copied_context)
    {
      "envelope_version" => PI_ENVELOPE_VERSION,
      "provider" => PI_PROVIDER,
      "model" => PI_MODEL,
      "api" => PI_API,
      "thinking" => PI_THINKING,
      "openai_api_key_removed_from_child" => true,
      "prompt_transport" => "explicit at-file in isolated workspace",
      "prompt_file" => PI_PROMPT_FILE,
      "prompt_sha256" => Digest::SHA256.hexdigest(rendered_prompt),
      "context_files" => copied_context,
      "pi_binary" => pi_runtime.fetch("pi_binary"),
      "node_binary" => pi_runtime.fetch("node_binary"),
      "runtime_bin" => pi_runtime.fetch("runtime_bin"),
      "pi_args_without_prompt" => command[1...-1]
    }
  end

  def pi_identity
    {
      "provider" => PI_PROVIDER,
      "model" => PI_MODEL,
      "api" => PI_API,
      "thinking" => PI_THINKING
    }
  end

  def audit_pi_trace(trace)
    PiTraceAudit.parse(trace, provider: PI_PROVIDER, model: PI_MODEL, api: PI_API)
  end

  def emit_dry_run(route, suite_path, suite, task_path, task, skill_root)
    validate_graders!(task) if route == "no-vpn"
    instruction_files = selected_instruction_files(skill_root)
    inputs = digest_inputs(suite_path, skill_root, task_path, task, instruction_files)
    payload = {
      "dry_run" => true,
      "route" => route,
      "suite" => relative(suite_path),
      "task" => task["id"],
      "task_file" => relative(task_path),
      "skill" => suite["skill"],
      "requested_model" => route == "no-vpn" ? pi_identity : suite.dig("config", "model"),
      "candidate_visible_inputs" => [relative(skill_root.join("SKILL.md")), *instruction_files.map { |path| relative(path) }],
      "judge_visible_inputs" => task.fetch("graders").filter_map { |grader| grader.dig("config", "rubric") },
      "inputs" => inputs,
      "candidate_digest" => candidate_digest(inputs),
      "runner_sha256" => runner_sha256,
      "provider_called" => false
    }
    if route == "no-vpn"
      Dir.mktmpdir("pi-behavior-dry-run-") do |dir|
        workspace = Pathname.new(dir)
        copied_context = copy_context_files(
          [skill_root.join("SKILL.md"), *instruction_files],
          workspace.join("inputs"),
          relative_to: workspace
        )
        rendered_prompt = render_pi_prompt(workspace, task.dig("inputs", "prompt"), copied_context)
        workspace.join(PI_PROMPT_FILE).binwrite(rendered_prompt)
        payload["invocation_contract"] = pi_invocation_contract(
          pi_command("@#{PI_PROMPT_FILE}"),
          rendered_prompt,
          copied_context
        )
        payload["grader_contracts"] = task.fetch("graders").map do |grader|
          if grader["type"] == "program"
            next({ "name" => grader["name"], "type" => "program" })
          elsif grader["type"] == "text"
            next({
              "name" => grader["name"],
              "type" => "text-regex",
              "regex_match_count" => Array(grader.dig("config", "regex_match")).length,
              "regex_not_match_count" => Array(grader.dig("config", "regex_not_match")).length
            })
          end

          rubric_path = resolve_repo_file(grader.fetch("config").fetch("rubric"))
          rubric = rubric_path.read
          derived = derive_rubric(rubric)
          {
            "name" => grader["name"],
            "type" => "prompt-rubric",
            "rubric" => relative(rubric_path),
            "rubric_sha256" => Digest::SHA256.hexdigest(rubric),
            "derived_rubric_sha256" => Digest::SHA256.hexdigest(derived)
          }
        end
      end
    else
      models = resolve_waza_models(suite, task)
      payload["required_preflight"] = "scripts/dev/agent-collab-vpn-smoke.sh"
      payload["execution_contract"] = "isolated temporary Waza overlay"
      payload["instruction_files"] = instruction_files.map { |path| relative(path) }
      payload["resolved_models"] = models
      payload["command"] = ["waza", "run", "<overlay>/#{relative(suite_path)}", "--task", task["id"]]
      with_waza_overlay(
        suite_path,
        suite,
        task_path,
        skill_root,
        instruction_files,
        models
      ) do |overlay, overlay_suite, context_dir|
        overlay_config = load_yaml(overlay_suite).fetch("config")
        overlay_task = load_yaml(overlay.join(relative(task_path)))
        payload["overlay_preflight"] = {
          "skill_present" => overlay.join(".codex/skills", suite.fetch("skill"), "SKILL.md").file?,
          "execution_model" => overlay_config["model"],
          "judge_models" => overlay_task.fetch("graders").filter_map do |grader|
            grader.dig("config", "model") if grader["type"] == "prompt"
          end,
          "instruction_files" => Array(overlay_config["instruction_files"]),
          "context_present" => !context_dir.nil?
        }
      end
    end
    puts JSON.pretty_generate(payload)
    0
  end

  def digest_inputs(suite_path, skill_root, task_path, task, instruction_files)
    paths = [suite_path, skill_root.join("SKILL.md"), task_path, *instruction_files]
    task.fetch("graders").each do |grader|
      rubric = grader.dig("config", "rubric")
      paths << resolve_repo_file(rubric) if rubric
      Array(grader.dig("config", "args")).each do |arg|
        candidate = @root.join(arg).cleanpath
        paths << resolve_repo_file(arg) if candidate.file?
      end
    end
    paths.uniq.map do |path|
      { "path" => relative(path), "sha256" => Digest::SHA256.file(path).hexdigest }
    end
  end

  def candidate_digest(inputs)
    Digest::SHA256.hexdigest(JSON.generate(inputs.sort_by { |entry| entry.fetch("path") }))
  end

  def write_waza_contract(output, suite_path, task, models, inputs)
    raise BehaviorEvalError, "Waza result was not written" unless output.file?

    result_bytes = output.binread
    result = JSON.parse(result_bytes)
    observed_model = result.dig("config", "model_id")
    unless observed_model == models.fetch("execution")
      raise BehaviorEvalError, "Waza result model does not match the selected execution model"
    end

    contract_path = output.sub_ext(".contract.json")
    ensure_new_output!(contract_path)
    contract = {
      "evidence_kind" => "waza-copilot-behavior",
      "route" => "vpn",
      "suite" => relative(suite_path),
      "task" => task.fetch("id"),
      "source_head" => source_head,
      "runner_sha256" => runner_sha256,
      "requested_models" => models,
      "observed_execution_model" => observed_model,
      "effective_judge_models" => "Pending Verification",
      "inputs" => inputs,
      "candidate_digest" => candidate_digest(inputs),
      "waza_result" => relative(output),
      "waza_result_sha256" => Digest::SHA256.hexdigest(result_bytes)
    }
    contract_path.write(JSON.pretty_generate(contract) << "\n")
    puts "Waza behavior contract written to #{relative(contract_path)}"
  rescue JSON::ParserError => e
    raise BehaviorEvalError, "Waza result is not valid JSON: #{e.message}"
  end

  def source_head
    stdout, stderr, status = Open3.capture3("git", "rev-parse", "HEAD", chdir: @root.to_s)
    raise BehaviorEvalError, "cannot resolve source HEAD: #{stderr.strip}" unless status.success?
    stdout.strip
  end

  def runner_sha256
    Digest::SHA256.file(Pathname.new(__FILE__)).hexdigest
  end

  def pi_binary!
    pi_runtime.fetch("pi_binary")
  end

  def pi_environment
    {
      "OPENAI_API_KEY" => nil,
      "PATH" => [pi_runtime.fetch("runtime_bin"), ENV.fetch("PATH", "")]
        .reject(&:empty?).join(File::PATH_SEPARATOR)
    }
  end

  def pi_runtime
    @pi_runtime ||= begin
      pi = options[:pi_bin] ? explicit_pi_binary(options[:pi_bin]) : discover_pi_binary
      runtime_bin = Pathname.new(pi).dirname
      node = runtime_bin.join("node")
      unless node.file? && node.executable?
        raise BehaviorEvalError,
              "Pi runtime is missing executable sibling node: #{node}; pass --pi-bin from one complete runtime"
      end
      {
        "pi_binary" => pi,
        "node_binary" => node.realpath.to_s,
        "runtime_bin" => runtime_bin.realpath.to_s
      }
    end
  end

  def explicit_pi_binary(raw)
    path = Pathname.new(raw)
    raise BehaviorEvalError, "--pi-bin must be an absolute path" unless path.absolute?
    validate_pi_binary(path)
  end

  def discover_pi_binary
    path_candidate = executable("pi")
    return validate_pi_binary(Pathname.new(path_candidate)) if path_candidate && !mise_shim?(path_candidate)

    mise = if path_candidate && mise_shim?(path_candidate)
             Pathname.new(path_candidate).realpath.to_s
           else
             executable("mise")
           end
    raise BehaviorEvalError, "Pi executable was not found; pass --pi-bin /absolute/runtime/bin/pi" unless mise

    stdout, = Open3.capture3(mise, "which", "pi", chdir: @root.to_s)
    resolved = stdout.strip
    if !resolved.empty? && Pathname.new(resolved).absolute?
      begin
        return validate_pi_binary(Pathname.new(resolved))
      rescue BehaviorEvalError
        nil
      end
    end

    stdout, stderr, status = Open3.capture3(mise, "ls", "--json", "node", chdir: @root.to_s)
    raise BehaviorEvalError, "cannot inventory installed Pi runtimes: #{stderr.strip}" unless status.success?
    installs = JSON.parse(stdout).filter_map do |entry|
      next unless entry.is_a?(Hash) && entry["installed"] == true && entry["install_path"].is_a?(String)
      candidate = Pathname.new(entry["install_path"]).join("bin/pi")
      candidate if candidate.file? && candidate.executable? && candidate.dirname.join("node").executable?
    end.uniq(&:to_s)
    if installs.length != 1
      raise BehaviorEvalError,
            "Pi runtime discovery found #{installs.length} complete installs; pass one exact --pi-bin /absolute/runtime/bin/pi"
    end
    validate_pi_binary(installs.first)
  rescue JSON::ParserError => e
    raise BehaviorEvalError, "installed Pi runtime inventory is not valid JSON: #{e.message}"
  end

  def validate_pi_binary(path)
    clean = path.cleanpath
    unless clean.file? && clean.executable?
      raise BehaviorEvalError, "Pi executable is unavailable or not executable: #{clean}"
    end
    raise BehaviorEvalError, "Pi executable resolves to a mise shim: #{clean}" if mise_shim?(clean)
    clean.to_s
  end

  def mise_shim?(path)
    Pathname.new(path).realpath.basename.to_s == "mise"
  rescue Errno::ENOENT
    false
  end

  def output_path(task_id, route)
    results_root = @root.join("tmp/waza-results").cleanpath
    if options[:output]
      candidate = @root.join(options[:output]).cleanpath
      return ensure_under(candidate, results_root, "output path must stay under tmp/waza-results: #{options[:output]}")
    end
    stamp = Time.now.utc.strftime("%Y%m%dT%H%M%S.%6NZ")
    results_root.join("behavior-routing/#{stamp}-#{route}-#{task_id}.json")
  end

  def ensure_new_output!(path)
    raise BehaviorEvalError, "refusing to overwrite behavior result: #{relative(path)}" if path.exist?
  end

  def executable(name)
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }
       .find { |path| File.file?(path) && File.executable?(path) }
  end

  def relative(path)
    Pathname.new(path).realpath.relative_path_from(@root.realpath).to_s
  rescue Errno::ENOENT
    Pathname.new(path).cleanpath.relative_path_from(@root).to_s
  end
end

def self_test
  runner = BehaviorEvalRunner.new(route: "no-vpn", instruction_files: [], dry_run: true)
  Dir.mktmpdir("behavior-repo-root-self-test-") do |directory|
    external_root = Pathname.new(directory).realpath
    fixture = external_root.join("fixture.txt")
    fixture.write("fixture\n")
    external = BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: [],
      dry_run: true,
      repo_root: external_root.to_s
    )
    resolved = external.send(:resolve_repo_file, "fixture.txt")
    raise "external repository root was not bound" unless resolved == fixture
    begin
      external.send(:resolve_repo_file, "../outside.txt")
      raise "external repository root permitted path escape"
    rescue BehaviorEvalError
      nil
    end
  end
  begin
    BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: [],
      dry_run: true,
      repo_root: "relative/root"
    )
    raise "relative repository root accepted"
  rescue BehaviorEvalError
    nil
  end
  user_message = {
    "role" => "user",
    "content" => [{ "type" => "text", "text" => "prompt\n" }],
    "timestamp" => 1
  }
  message = {
    "role" => "assistant",
    "content" => [{ "type" => "text", "text" => "answer\n" }],
    "api" => BehaviorEvalRunner::PI_API,
    "provider" => BehaviorEvalRunner::PI_PROVIDER,
    "model" => BehaviorEvalRunner::PI_MODEL,
    "stopReason" => "stop",
    "usage" => { "input" => 1, "output" => 1 }
  }
  message_end_line = JSON.generate("type" => "message_end", "message" => message)
  turn_end_line = JSON.generate("type" => "turn_end", "message" => message, "toolResults" => [])
  user_start_line = JSON.generate("type" => "message_start", "message" => user_message)
  user_end_line = JSON.generate("type" => "message_end", "message" => user_message)
  agent_end_line = JSON.generate("type" => "agent_end", "messages" => [user_message, message], "willRetry" => false)
  zero_tool = <<~JSONL
    {"type":"session","version":3,"id":"test"}
    {"type":"agent_start"}
    {"type":"turn_start"}
    #{user_start_line}
    #{user_end_line}
    {"type":"message_start","message":{"role":"assistant"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_start"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"answer\\n"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_end","content":"answer\\n"}}
    #{message_end_line}
    #{turn_end_line}
    #{agent_end_line}
    {"type":"agent_settled"}
  JSONL
  audit = PiTraceAudit.parse(
    zero_tool,
    provider: BehaviorEvalRunner::PI_PROVIDER,
    model: BehaviorEvalRunner::PI_MODEL,
    api: BehaviorEvalRunner::PI_API
  )
  raise "zero-tool trace rejected" unless audit["output"] == "answer\n"
  failed_message = message.merge(
    "content" => [],
    "stopReason" => "error",
    "errorMessage" => "transient overload"
  )
  failed_message_end = JSON.generate("type" => "message_end", "message" => failed_message)
  failed_turn_end = JSON.generate("type" => "turn_end", "message" => failed_message, "toolResults" => [])
  failed_agent_end = JSON.generate(
    "type" => "agent_end",
    "messages" => [user_message, failed_message],
    "willRetry" => true
  )
  retry_agent_end = JSON.generate("type" => "agent_end", "messages" => [message], "willRetry" => false)
  retry_trace = <<~JSONL
    {"type":"session","version":3,"id":"retry-test"}
    {"type":"agent_start"}
    {"type":"turn_start"}
    #{user_start_line}
    #{user_end_line}
    {"type":"message_start","message":{"role":"assistant"}}
    #{failed_message_end}
    #{failed_turn_end}
    #{failed_agent_end}
    {"type":"auto_retry_start","attempt":1,"maxAttempts":3,"delayMs":2000,"errorMessage":"transient overload"}
    {"type":"agent_start"}
    {"type":"turn_start"}
    {"type":"message_start","message":{"role":"assistant"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_start"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_delta","delta":"answer\\n"}}
    {"type":"message_update","assistantMessageEvent":{"type":"text_end","content":"answer\\n"}}
    #{message_end_line}
    {"type":"auto_retry_end","success":true,"attempt":1}
    #{turn_end_line}
    #{retry_agent_end}
    {"type":"agent_settled"}
  JSONL
  retry_audit = PiTraceAudit.parse(
    retry_trace,
    provider: BehaviorEvalRunner::PI_PROVIDER,
    model: BehaviorEvalRunner::PI_MODEL,
    api: BehaviorEvalRunner::PI_API
  )
  raise "valid retry trace rejected" unless retry_audit["output"] == "answer\n"
  raise "retry count evidence missing" unless retry_audit["retry_count"] == 1
  duplicate_terminal = message_end_line
  wrong_agent_end = JSON.generate("type" => "agent_end", "messages" => [message], "willRetry" => false)
  unknown_content_message = message.merge("content" => [{ "type" => "citation", "text" => "answer\n" }])
  unknown_content_end = JSON.generate("type" => "message_end", "message" => unknown_content_message)
  unknown_content_turn = JSON.generate("type" => "turn_end", "message" => unknown_content_message, "toolResults" => [])
  unknown_content_agent = JSON.generate(
    "type" => "agent_end",
    "messages" => [user_message, unknown_content_message],
    "willRetry" => false
  )

  rejected = [
    zero_tool.sub('{"type":"agent_settled"}', '{"type":"tool_execution_start","toolName":"bash"}\n{"type":"agent_settled"}'),
    zero_tool.sub('"toolResults":[]', '"toolResults":[{"role":"toolResult"}]'),
    zero_tool.sub('"model":"gpt-5.6-luna"', '"model":"wrong"'),
    zero_tool.sub('"stopReason":"stop"', '"stopReason":"length"'),
    zero_tool.sub('{"type":"agent_settled"}', '{"type":"mystery"}\n{"type":"agent_settled"}'),
    zero_tool.sub('{"type":"agent_settled"}', ''),
    zero_tool.sub("#{user_start_line}\n", ""),
    zero_tool.sub(user_end_line, JSON.generate("type" => "message_end", "message" => user_message.merge("timestamp" => 2))),
    zero_tool.sub('{"type":"agent_settled"}', "#{duplicate_terminal}\n{\"type\":\"agent_settled\"}"),
    zero_tool.sub("#{message_end_line}\n#{turn_end_line}", "#{turn_end_line}\n#{message_end_line}"),
    zero_tool.sub(agent_end_line, wrong_agent_end),
    zero_tool.sub("#{message_end_line}\n#{turn_end_line}\n#{agent_end_line}", "#{unknown_content_end}\n#{unknown_content_turn}\n#{unknown_content_agent}"),
    zero_tool.sub('"willRetry":false', '"willRetry":true'),
    retry_trace.sub('{"type":"auto_retry_end","success":true,"attempt":1}', '{"type":"auto_retry_end","success":false,"attempt":1,"finalError":"failed"}'),
    retry_trace.sub("#{failed_agent_end}\n", "#{failed_agent_end.sub('true', 'false')}\n"),
    retry_trace.sub('{"type":"auto_retry_start","attempt":1', '{"type":"auto_retry_start","attempt":2'),
    %(not-json\n),
    ""
  ]
  rejected.each do |trace|
    begin
      PiTraceAudit.parse(
        trace,
        provider: BehaviorEvalRunner::PI_PROVIDER,
        model: BehaviorEvalRunner::PI_MODEL,
        api: BehaviorEvalRunner::PI_API
      )
      raise "invalid trace accepted"
    rescue BehaviorEvalError
      nil
    end
  end

  rubric = <<~RUBRIC
    Pass only if the candidate preserves this requirement.

    Call `set_waza_grade_pass` once if every requirement holds. Otherwise call
    `set_waza_grade_fail` once and name the missing requirement.
  RUBRIC
  derived = runner.send(:derive_rubric, rubric)
  raise "rubric criteria changed" unless derived.include?("preserves this requirement")
  raise "Waza grade tools leaked into derived rubric" if derived.include?("set_waza_grade_")
  raise "valid grade rejected" unless runner.send(:parse_grade, "PI_BEHAVIOR_GRADE: PASS\nreason") == "PASS"
  text_grade = runner.send(
    :grade_text,
    {
      "name" => "text-contract",
      "type" => "text",
      "config" => {
        "regex_match" => ["(?is)complete.*answer"],
        "regex_not_match" => ["forbidden"]
      }
    },
    "Complete policy answer"
  )
  raise "valid text grader result rejected" unless text_grade["passed"]
  raise "text grader match evidence missing" unless text_grade.dig("regex_match", 0, "matched") == true
  begin
    runner.send(
      :grade_text,
      { "name" => "invalid-regex", "type" => "text", "config" => { "regex_match" => ["("] } },
      "answer"
    )
    raise "invalid text grader regular expression accepted"
  rescue BehaviorEvalError
    nil
  end
  Dir.mktmpdir("pi-runtime-self-test-") do |runtime_dir|
    runtime = Pathname.new(runtime_dir)
    node = runtime.join("node")
    pi = runtime.join("pi")
    [node, pi].each do |binary|
      binary.write("#!/usr/bin/bash\nexit 0\n")
      binary.chmod(0o755)
    end
    explicit = BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: [],
      dry_run: true,
      pi_bin: pi.to_s
    )
    bound = explicit.send(:pi_runtime)
    raise "explicit Pi runtime was not bound" unless bound["pi_binary"] == pi.to_s
    raise "Pi sibling Node runtime was not bound" unless bound["node_binary"] == node.realpath.to_s
    env = explicit.send(:pi_environment)
    raise "Pi runtime bin is not first on PATH" unless env.fetch("PATH").split(File::PATH_SEPARATOR).first == runtime.realpath.to_s
    raise "API key removal was lost" unless env.key?("OPENAI_API_KEY") && env["OPENAI_API_KEY"].nil?
    command = explicit.send(:pi_command, "@#{BehaviorEvalRunner::PI_PROMPT_FILE}")
    required_flags = %w[
      --no-session --no-tools --no-extensions --no-skills --no-prompt-templates
      --no-themes --no-context-files --no-approve
    ]
    raise "Pi isolation flag missing" unless required_flags.all? { |flag| command.count(flag) == 1 }
    raise "Pi provider changed" unless command[command.index("--provider") + 1] == BehaviorEvalRunner::PI_PROVIDER
    raise "Pi model changed" unless command[command.index("--model") + 1] == BehaviorEvalRunner::PI_MODEL
    raise "Pi thinking changed" unless command[command.index("--thinking") + 1] == BehaviorEvalRunner::PI_THINKING
    raise "Pi prompt is not explicit at-file transport" unless command.last == "@#{BehaviorEvalRunner::PI_PROMPT_FILE}"
    raise "Pi command grew with prompt content" unless command.join(" ").bytesize < 4096
  end
  begin
    BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: [],
      dry_run: true,
      pi_bin: "relative/pi"
    ).send(:pi_runtime)
    raise "relative Pi binary accepted"
  rescue BehaviorEvalError
    nil
  end
  Dir.mktmpdir("pi-shim-self-test-") do |runtime_dir|
    runtime = Pathname.new(runtime_dir)
    mise = runtime.join("mise")
    mise.write("#!/usr/bin/bash\nexit 0\n")
    mise.chmod(0o755)
    pi = runtime.join("pi")
    pi.make_symlink(mise)
    begin
      BehaviorEvalRunner.new(
        route: "no-vpn",
        instruction_files: [],
        dry_run: true,
        pi_bin: pi.to_s
      ).send(:pi_runtime)
      raise "mise Pi shim accepted"
    rescue BehaviorEvalError
      nil
    end
  end
  Dir.mktmpdir("pi-mise-discovery-self-test-") do |test_dir|
    root = Pathname.new(test_dir)
    shims = root.join("shims")
    runtime = root.join("runtime/bin")
    shims.mkpath
    runtime.mkpath
    node = runtime.join("node")
    pi = runtime.join("pi")
    [node, pi].each do |binary|
      binary.write("#!/usr/bin/bash\nexit 0\n")
      binary.chmod(0o755)
    end
    mise = root.join("mise")
    mise.write(<<~BASH)
      #!/usr/bin/bash
      if [[ "$1 $2" == "which pi" ]]; then
        printf '%s\n' #{pi.to_s.dump}
        exit 0
      fi
      exit 1
    BASH
    mise.chmod(0o755)
    shims.join("pi").make_symlink(mise)
    original_path = ENV["PATH"]
    begin
      ENV["PATH"] = [shims, original_path].compact.join(File::PATH_SEPARATOR)
      discovered = BehaviorEvalRunner.new(
        route: "no-vpn",
        instruction_files: [],
        dry_run: true
      ).send(:pi_runtime)
      raise "mise-backed Pi shim was not resolved" unless discovered["pi_binary"] == pi.to_s
      raise "discovered Pi sibling Node was not bound" unless discovered["node_binary"] == node.realpath.to_s
    ensure
      ENV["PATH"] = original_path
    end
  end
  repo_root = Pathname.new(File.expand_path("../..", __dir__))
  database_skill = repo_root.join(".codex/skills/database-reviewer").realpath
  linked_paths = [
    ".codex/skills/database-reviewer/references/verdict-closeout.md",
    "docs/agents/pr-review-packet-format.md",
    "docs/agents/pr-comment-conventions.md"
  ]
  linked_runner = BehaviorEvalRunner.new(
    route: "no-vpn",
    instruction_files: linked_paths,
    dry_run: true
  )
  selected_paths = linked_runner.send(:selected_instruction_files, database_skill).map do |path|
    path.relative_path_from(repo_root).to_s
  end
  raise "transitively linked instructions rejected" unless selected_paths == linked_paths
  begin
    BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: ["AGENTS.md"],
      dry_run: true
    ).send(:selected_instruction_files, database_skill)
    raise "unrelated outside-tree instruction accepted"
  rescue BehaviorEvalError
    nil
  end
  begin
    runner.send(:parse_grade, "PASS\nreason")
    raise "malformed grade accepted"
  rescue BehaviorEvalError
    nil
  end
  begin
    runner.send(
      :validate_graders!,
      "graders" => [{ "type" => "prompt", "config" => { "prompt" => "Pass if good" } }]
    )
    raise "inline prompt grader accepted"
  rescue BehaviorEvalError
    nil
  end
  begin
    BehaviorEvalRunner.new(
      route: "no-vpn",
      instruction_files: [],
      dry_run: true,
      output: "AGENTS.md"
    ).send(:output_path, "task", "pi")
    raise "output path outside tmp/waza-results accepted"
  rescue BehaviorEvalError
    nil
  end
  begin
    runner.send(:ensure_new_output!, Pathname.new(__FILE__))
    raise "existing behavior result path accepted"
  rescue BehaviorEvalError
    nil
  end
  puts "behavior evaluation runner self-tests passed"
  0
end

options = { route: "auto", instruction_files: [], dry_run: false }
parser = OptionParser.new do |opts|
  opts.banner = "Usage: scripts/dev/run-behavior-eval.rb --suite PATH --task ID [options]"
  opts.on("--repo-root PATH", "Absolute repository root containing the suite and candidate skill") { |value| options[:repo_root] = value }
  opts.on("--suite PATH", "Behavior eval YAML") { |value| options[:suite] = value }
  opts.on("--task ID", "Focused task ID") { |value| options[:task] = value }
  opts.on("--route ROUTE", BehaviorEvalRunner::ROUTES, "auto, vpn, or no-vpn") { |value| options[:route] = value }
  opts.on("--instruction-file PATH", "Additional target-skill or transitively linked Markdown instruction file") { |value| options[:instruction_files] << value }
  opts.on("--waza-model MODEL", "Explicit VPN-lane Waza execution model") { |value| options[:waza_model] = value }
  opts.on("--waza-judge-model MODEL", "Explicit VPN-lane Waza prompt-grader model") { |value| options[:waza_judge_model] = value }
  opts.on("--pi-bin PATH", "Absolute Pi launcher; sibling node is required and prepended for child calls") { |value| options[:pi_bin] = value }
  opts.on("--output PATH", "Result JSON path under the repository") { |value| options[:output] = value }
  opts.on("--dry-run", "Validate and print the selected route without provider calls") { options[:dry_run] = true }
  opts.on("--self-test", "Run deterministic parser and rejection tests") { options[:self_test] = true }
  opts.on("-h", "--help", "Show help") { puts opts; exit 0 }
end

begin
  parser.parse!
  exit(options[:self_test] ? self_test : BehaviorEvalRunner.new(options).run)
rescue OptionParser::ParseError => e
  warn "error: #{e.message}"
  warn parser
  exit 2
rescue BehaviorEvalError => e
  warn "error: #{e.message}"
  exit 1
end
