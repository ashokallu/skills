<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-06-09 -->

# Instruction, Skill, Agent, And Durable-Doc Lens

Use this lens when the review touches agents, skills, instructions, prompts,
TOML role files, durable Markdown guidance, ADRs, runbooks, packet formats,
reviewer/critic surfaces, or docs that future humans or agents will treat as
policy.

For these reviews, judge the effective runtime contract. More text is not
stronger unless it changes a trigger, decision rule, evidence requirement,
routing rule, validation gate, output contract, or future-maintenance outcome.

## Review Order

1. Identify the artifact type: runtime agent, skill, reference lens, durable doc,
   packet contract, ADR, workflow guide, or generated documentation.
2. Name the baseline and candidate when comparing versions.
3. Classify deltas as kept, strengthened, weakened, contradicted, duplicated,
   removed, or newly introduced.
4. Check priority, loadability, runtime authority, parser contract, mirror
   parity, and maintenance hygiene.
5. Emit findings only for behavior-changing defects, lost guardrails,
   impossible instructions, or durable confusion that can affect future reviews.

## Runtime Contract And Priority

- Check that role boundaries match the runtime surface. Reviewer must not become
  implementer, critic, QA planner, browser runner, security approver, product
  owner, or infra owner.
- Do not allow nested reviewer/critic loops or broad delegation that lets the
  reviewer outsource its own verdict.
- Hard rules must be enforceable by the target runtime. Tool claims, sandbox
  behavior, background work, hidden mutations, and file-loading assumptions need
  runtime evidence or careful fallback wording.
- Higher-priority instructions win. A skill or reference file must not silently
  override the reviewer role's read-only boundary, evidence law, packet, or
  hard blockers.
- If two instructions conflict, prefer the one that preserves safety, evidence,
  current target freshness, parser compatibility, and human authority.

## Skill And Reference Loading

- `SKILL.md` frontmatter should trigger only the intended use case and exclude
  implementation or planning if the skill is reviewer-only.
- Replacing a skill, agent, or reference folder requires a preservation ledger:
  current-only files, trigger language, eval-covered prompts, stale candidate
  references, runtime-specific path differences, and old callers/tests that
  depend on the current shape.
- Lazy-loaded lenses must be additive and conservative. They refine footguns;
  they must not own verdict, severity, evidence law, or output packet rules.
- Routing must fail closed: ambiguous or mixed paths load more lenses, missing
  lenses become `Pending Verification` when relevant, and monolithic fallback
  remains available during pilot.
- Every routed lens path must exist, and every original `*-lens.md` filename must
  either remain present or have all callers/tests updated.
- Selected-lens metadata belongs in parent-facing notes unless the parser-facing
  packet contract explicitly allows it.
- For Next.js 16+ projects with local bundled docs, instructions may tell agents
  to read `node_modules/next/dist/docs/`, but must not claim those docs exist or
  were read without evidence.

## Agent And TOML Role Files

- Parse TOML after edits and ensure multi-line strings, fenced packet blocks,
  nicknames, model fields, sandbox settings, and runtime frontmatter are not
  damaged.
- Runtime adapter fields such as model, effort, sandbox, tools, and nicknames
  should not be buried in portable skill text unless the runtime owns them there.
- The developer instruction body should preserve read-only role, no nested
  reviewer, stable target, evidence law, `Pending Verification` versus
  `BLOCKED`, hard blockers, modes, packet, candidate filter, severity/confidence,
  follow-up root-cause checks, contamination handling, and one-owner handoff.
- Avoid model/version claims that are stale-prone unless they are runtime config
  or explicitly marked for verification.
- If replacing a reviewer or critic artifact, require a real diff/change ledger;
  do not accept claims of improvement that are not present in the saved file.

## Durable Docs, ADRs, And Runbooks

- Durable docs should distinguish decision record, operational instruction,
  historical context, and temporary PR guidance.
- ADRs should have status, date, decision, options, rationale, consequences,
  rollout, rollback, security/privacy, test plan, acceptance criteria, and owner
  when the repo template expects them.
- Runbooks should name current commands, environment, owner, prerequisites,
  rollback, safety checks, and expected evidence. They must not cite local tmp,
  backup, or machine-specific paths as durable truth.
- Operator docs for chunked, capped, sampled, paginated, or aggregate workflows
  must state what the bound actually limits. A bound on inputs, users, rows,
  pages, samples, or output payloads must not imply the whole query, job, or
  statement cost is bounded unless the implementation proves that.
- PR-temporal text must not become durable documentation unless generalized and
  verified.
- Generated docs must not invent APIs, commands, file paths, tool capabilities,
  approvals, or validation results.

## Mirror Parity And Drift

- Before claiming mirror parity, inspect the actual `.codex`, `.claude`,
  `.agents`, `.github`, and documented runtime surfaces that intentionally carry
  the same policy.
- Record intentional divergence when a runtime-first pilot, runtime limitation, or
  staged rollout leaves mirrors unsplit.
- `Last verified` comments should be updated only when the listed surfaces were
  actually checked.
- Mirror parity is not line equality. It is preservation of effective decisions,
  trigger behavior, safety boundaries, output contracts, and maintenance rules.
- A mirror that lacks lazy reference loading may need the monolithic fallback
  until loading is proven.
- Do not trim duplicated monolithic guidance into a lazy-loaded skill until the
  target runtime has a verified route to that skill. Keep runtimes without the
  route monolithic or document the staged divergence.

## Bloat, Duplication, And Contradiction

- Prefer consolidated decision rules over additive checklists. If two bullets
  express the same gate, keep the stronger one and remove or merge the weaker.
- Repeated slogans, generic best practices, and non-actionable scolding reduce
  review quality. Keep text that changes what future reviewers inspect or how
  they classify evidence.
- Watch for duplicated duties across reviewer, critic, QA, browser, security,
  code-mapping, and specialist roles available in the active runtime.
- A candidate that adds broad coverage but drops a hard guardrail is worse than a
  shorter baseline that preserves the guardrail.
- Version-specific reviewer guidance must be conditional on repo-confirmed
  package, module, toolchain, CI image, or local-doc evidence. Do not import
  release-note claims as durable instructions unless the current repo version
  supports them.
- Do not reward fluency, completeness theater, or longer file size without an
  effective contract improvement.

## Parser, Packet, And Output Contracts

- Packet-facing docs must preserve exact field names, accepted enum values,
  order, and examples when parsers depend on them.
- New fields, renamed verdicts, or mode labels need parser-owner coordination and
  tests before being placed in machine-sensitive output.
- Reviewer output should remain parent-actionable and GitHub-comment-compatible;
  no quality scores, fake metrics, or template padding.
- If docs instruct Conventional Comments, verify severity, file/symbol anchoring,
  and parent-summary separation remain intact.

## Validation For Instruction Changes

Use or request evidence appropriate to the changed surface:

- TOML parse with Python `tomllib` for TOML role files
- Markdown lint or repo docs checks for Markdown instruction files
- diff hygiene such as trailing whitespace and broken fenced blocks
- skill trigger/routing evals for skill frontmatter or routing changes
- mirror parity check for runtime surfaces that intentionally mirror each other
- targeted smoke of lens routing for backend-only, frontend-only, mixed, and
  ambiguous diffs before trimming a monolithic fallback

## High-Value Findings For This Lens

Formal findings are appropriate when current evidence proves one of these is
reachable:

- a replacement drops read-only, evidence, hard-blocker, packet, or owner
  authority guardrails
- instruction claims impossible tool/runtime behavior or hidden mutation
- lazy loading can under-load required lenses or hide selected-lens coverage
- monolithic fallback is removed before the runtime has a verified lazy-load
  route to the replacement guidance
- parser-sensitive packet fields are changed without parser contract update
- mirror parity is claimed without inspecting real mirror surfaces
- durable docs cite stale PR-temporal text, local tmp paths, or invented commands
- added text creates contradictions, nested-agent loops, or rubber-stamp behavior
