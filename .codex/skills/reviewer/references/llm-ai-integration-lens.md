<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# LLM And AI Integration Lens

## Mission

Review runtime AI-calling code: prompt templates, model/provider selection,
completion and embedding calls, streaming handlers, tool/function-call
plumbing, model output parsing and validation, AI-generated content rendering,
retrieval pipelines, token/cost budgets, and caching of model responses.

## Ownership And Boundaries

This lens owns the model-as-untrusted-dependency contract: trust boundaries in
prompts, output validation, nondeterminism handling, and cost/latency bounds.
It does not own durable agent instruction documents, skills, or reviewer
policy files; defer those to `instruction-skill-agent-doc-lens`. Defer
provider request/response envelope compatibility to
`api-contracts-integration-lens`, swallowed provider failures to
`silent-failure-fallback-lens`, secret/PII exposure severity to
`security-privacy-lens`, response caching correctness to
`concurrency-caching-consistency-lens`, and proof quality to
`tests-validation-lens`.

Do not object to model use itself or demand determinism where the product
accepts variance; surface only reachable correctness, safety, cost, or
trust-boundary defects.

## Evidence And Dedupe

A finding needs the concrete call site, the input source feeding it, and the
reachable bad state (injected instruction, unvalidated output path, unbounded
spend, or silent substitution). Group repeated instances of the same missing
validation or same injection path by root cause across call sites. Prompt
files, typed output schemas, provider client config, retry wrappers, fixtures,
and cost/usage logging are all in-scope evidence at the reviewed head.

## Review Probes

- Can untrusted user input, CMS content, or retrieved documents rewrite the
  instruction contract — change tool calls, data access, output policy, or
  system behavior — because trust levels are concatenated without separation?
- Is model output executed, rendered as HTML, interpolated into SQL/GROQ or a
  shell, or written to production data without schema validation or
  sandboxing?
- Are truncation mid-JSON, refusals, empty streams, provider 429/5xx, and
  schema-valid-but-invariant-violating responses handled as decided states, or
  swallowed into defaults that keep the happy path green?
- Do prompts, logs, error reports, or third-party payloads carry secrets,
  tokens, internal URLs, PII, or learner records?
- Can retries or stream reconnects double-apply a side effect triggered by a
  completion, with no idempotency key?
- Are per-request and aggregate token/cost caps enforced in code, and can a
  loop, retry storm, or unbounded context accumulation exceed them?
- Is nondeterminism isolated behind a seam so tests use recorded/stubbed
  responses, or do tests hit live providers (flaky, costly) or assert nothing
  real?
- Does a prompt or model-version change alter behavior that tests, docs, or
  downstream consumers assume is stable, with no eval or golden-fixture
  update?
- Is AI-generated content labeled or provenance-tracked where product or
  policy expects it?

## Triage

Promote to formal findings: reachable prompt injection into tool calls or
data access, unvalidated output reaching execution/persistence/rendering,
secret or learner-data leakage into prompts or vendor payloads, unbounded
retry/cost loops, and silent fabricated-or-stale content substitution on paths
users trust as fresh. Keep style preferences about prompt wording, model
choice within approved providers, and speculative injection paths with no
reachable input as advisory only.

## Output Discipline

For findings, name the call site, the input source, the concrete bad state
sequence, and the smallest validation seam or bound that closes it. When
central safety depends on live provider behavior, production spend data, or an
eval run the reviewer cannot execute read-only, use Risk Evidence Handoff with
the exact artifact needed. If clean, the selected-lens audit can state which
call sites, trust boundaries, and output-validation seams were inspected.
