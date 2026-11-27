<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# LLM And AI Integration Authoring

Use this lane when product or platform code calls an LLM or AI service at
runtime: prompt templates, model/provider selection, completion and embedding
calls, streaming handlers, tool/function-call plumbing, AI-generated content
rendering, retrieval pipelines, output parsers, evaluation harnesses, token or
cost budgets, and caching of model responses.

This lane owns runtime AI-calling code. It does not own durable agent
instruction documents, skills, or reviewer/authoring policy files; use
`instruction-skill-agent-authoring` for those.

## Mission

Treat the model as an untrusted, non-deterministic, priced external dependency.
Every model call needs a validated output contract, a bounded cost and latency
envelope, a deliberate failure behavior, and a trust boundary between user
input, retrieved content, and the instructions the model follows.

## Boundaries

Also load:

- `api-contracts-and-integrations` for provider request/response envelopes,
  streaming protocols, webhook callbacks, and old/new client compatibility;
- `resilience-and-fallbacks` for provider outage, timeout, rate-limit,
  truncation, and partial-stream behavior;
- `security-and-trust-boundary` for prompt injection, secret/PII leakage into
  prompts or logs, and untrusted output rendering;
- `concurrency-caching-consistency` when responses are cached, deduped, or
  streamed to multiple consumers;
- `efficiency-and-scale` when token spend, context size, or call fanout can
  materially change cost or latency;
- `test-quality` for deterministic seams around non-deterministic calls.

Do not add new model providers, agent frameworks, vector stores, or prompt
libraries for a narrow feature unless local precedent and the requirement
justify the ownership cost.

## Authoring Sequence

1. Name the call site contract before editing: model/version, input sources,
   maximum input size, output schema, temperature/determinism needs, latency
   budget, token/cost cap, and the caller that consumes the output.
2. Separate trust levels in the prompt: system/developer instructions, trusted
   application data, and untrusted user or retrieved content must be
   distinguishable, and untrusted content must not be able to rewrite the
   instruction contract silently.
3. Validate model output at the boundary. Parse into a typed schema; treat
   missing fields, extra prose, malformed JSON, truncation, refusals, and
   empty responses as first-class states with decided behavior, not as
   exceptions swallowed into defaults.
4. Bound the call: request timeout, max tokens, retry policy with backoff for
   retryable statuses only, and an idempotency or dedupe strategy when the
   caller can retry a mutation-triggering completion.
5. Decide degradation before editing: cached response, smaller model, static
   fallback content, explicit user-facing unavailability, or hard failure.
   Never silently substitute fabricated or stale content where users expect
   fresh model output.
6. Version prompts like code. Keep templates in tracked files, name their
   variables, and treat a prompt change as a behavior change that needs the
   same validation as a code change.
7. Keep humans and operators in the loop where output is consequential:
   AI-generated content that reaches learners, production data, or operator
   decisions needs provenance labeling, review gates, or both, per local
   product policy.
8. Wire cost and usage observability: log model, token counts, latency, cache
   hit/miss, and failure class per call site so operators can attribute spend
   and regressions.

## Prevention Probes

- Can untrusted user input, CMS content, or retrieved documents inject
  instructions that change tool calls, data access, or output policy?
- Does any code path interpolate secrets, tokens, internal URLs, PII, or
  learner records into a prompt, log line, or third-party payload?
- Is model output executed, rendered as HTML, used in SQL/GROQ, passed to a
  shell, or written to production data without validation or sandboxing?
- What happens on truncation mid-JSON, a refusal, an empty stream, a provider
  429/5xx, or a response that passes parsing but violates domain invariants?
- Can retries or stream reconnects double-apply a side effect triggered by the
  completion?
- Is nondeterminism isolated behind a seam so tests can run with recorded or
  stubbed responses instead of live calls?
- Does a model or prompt version change silently alter behavior that tests,
  docs, evals, or downstream consumers assume is stable?
- Are per-request and aggregate token/cost caps enforced in code, not only
  documented?
- Is AI-generated content labeled or attributable where product, legal, or
  trust requirements expect provenance?

## Validation

Prefer deterministic proof: unit tests with recorded/stubbed provider
responses covering malformed, truncated, refused, and slow outputs; schema
validation tests for the output parser; a bounded live smoke call only when an
integration credential and budget exist and the check is explicitly allowed.
Keep golden prompts and expected-shape fixtures under test so prompt drift is
visible in diffs. Mark unproven live-provider behavior `Pending Verification`
rather than assuming it from docs.

## Output

```text
LLM/AI integration authoring:
- call sites: <files/functions and model/provider>
- output contract: <schema and validation seam>
- failure behavior: <timeout/rate-limit/truncation/refusal handling>
- trust boundary: <injection and leakage controls>
- cost/latency bounds: <caps and observability>
- proof: <tests/fixtures or Pending Verification>
```
