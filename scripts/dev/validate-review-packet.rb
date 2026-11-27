#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "pathname"
require_relative "lib/reviewer_packet_validator"

options = {
  packet: "-",
  transport: "evals/reviewer/contract-fixtures/canonical-transport.yaml"
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: validate-review-packet.rb [options]"
  opts.on("--packet PATH", "Packet file, or - for stdin") { |value| options[:packet] = value }
  opts.on("--expected-target VALUE", "Exact trusted Review target value") { |value| options[:expected_target] = value }
  opts.on("--expected-mode MODE", %w[LITE STANDARD FULL COUNCIL], "Trusted review mode") { |value| options[:expected_mode] = value }
  opts.on("--review-comments POLICY", %w[required_if_findings optional forbidden], "Trusted review-comments contract") { |value| options[:review_comments] = value }
  opts.on("--transport PATH", "Canonical transport YAML") { |value| options[:transport] = value }
end

parser.parse!
missing = %i[expected_target expected_mode review_comments].reject { |key| options[key] }
unless missing.empty?
  warn "missing required options: #{missing.join(', ')}"
  warn parser
  exit 2
end

root = Pathname.new(__dir__).join("../..").cleanpath
source = options[:packet] == "-" ? $stdin.read : File.binread(options[:packet])
transport_path = root.join(options[:transport]).cleanpath
github_transport, review_comments_transport = ReviewerPacketValidator.load_transport(transport_path)
result = ReviewerPacketValidator.validate(
  source_bytes: source,
  transport: github_transport,
  review_comments_transport: review_comments_transport,
  expected_target: options.fetch(:expected_target),
  expected_mode: options.fetch(:expected_mode),
  review_comments: options.fetch(:review_comments)
)
puts JSON.pretty_generate(result.to_h)
exit(result.accepted ? 0 : 1)
