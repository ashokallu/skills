<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-09-03 (canonical public comment semantics and deterministic checks) -->

# PR Comment Conventions

## Ownership

This file is the single canonical source for the wording and shape of
project pull-request comments. It replaces the copies that previously
lived inside a GitHub mutation lane and inside the PR review workflow file.

Every producer reads this source directly. Its deterministic subset is enforced
by `scripts/dev/lib/reviewer_packet_validator.rb`; semantic quality remains the
reviewer's responsibility.

Consumers reference this file. Do not duplicate its rules:

| Consumer | Why it reads this file |
| --- | --- |
| A reviewer producing `Review comments:` | It owns the exact decoded Body and Summary bytes |
| `docs/agents/pr-review-packet-format.md` | Binds review-comment bodies to these rules |
| `pr-workflow` review and comment lanes | Parent-side posting and thread replies |
| `github-workflow` `references/pr-operations.md` | Authenticated submission mechanics |

## Reviewer Inline Comments

Every inline review comment authored as a reviewer uses Conventional Comments.

- Lead with a backticked label carrying a mandatory blocking decoration, for
  example `` `issue(blocking)` ``, `` `issue(non-blocking)` ``, or
  `` `suggestion(non-blocking)` ``. The backticks around the label are
  required, and the `(blocking)` or `(non-blocking)` decoration is mandatory
  and chosen from merge impact.
- Available labels: `issue`, `suggestion`, `question`, `todo`, `nitpick`,
  `note`.
- Follow the label with a one-line subject on the same line.
- Never emit one dense paragraph, regardless of length. Split further detail
  into short labeled parts separated by blank lines.

Use this default decoded body shape. Combine labeled parts only when every
required semantic stays obvious and independently actionable:

```text
`issue(<blocking-state>)` <finding title>

**What happens:** <failure mechanism>

**Why it matters:** <concrete consequence>

**Evidence:** <strongest current-source proof>

**Likelihood:** <include only when conditionality or frequency materially helps>

- **Trigger:** <condition and consequence once it holds>
- **Frequency:** <measured evidence or unquantified>

**Suggested fix:** <required outcome and ownership surface>

**How to verify:** <focused post-fix proof>
```

### Evidence economy

- Omit evidence for facts already visible at the anchor line. Cite exact lines
  only when the claim is not visible there.
- Keep reviewer-internal likelihood, confidence, and frequency narration out of
  the public body, except where the `Likelihood:` block genuinely helps the
  author act.
- State frequency only as measured with an exact cited source, or as
  unquantified. Severity describes impact and must not be weakened or amplified
  by unsupported likelihood language.
- When the finding evidence names why frequency is unquantified, preserve that
  measurement gap in the public likelihood block instead of reducing it to the
  word `Unquantified` alone.

### Certainty must not increase at publication

A finding held at `MEDIUM` or `LOW` confidence must retain a human-readable
uncertainty qualifier or name the missing proof. A published comment must never
read as more certain than the packet field behind it. `Frequency: Unquantified`
alone is not a confidence qualifier. When a source or test-coverage gap is part
of the finding's evidence, preserve that gap in the public body when it is
needed to justify the requested fix or verification.

### Anchoring and references

- Anchor to the narrowest current diff line that proves the concern.
- Use repository-relative paths only, for example
  `` `app/sanity/portableTextToMarkdown.ts` ``.
- When citing a path with line numbers, wrap the path and the line numbers
  together inside one backtick block, for example
  `` `app/components/templates/QuizContent/QuizAnswerList.tsx:74, 100` ``.

### Forbidden in any public comment body

- Emojis anywhere. They read as automated and unprofessional.
- Raw commit SHAs or other transient commit identifiers, unless the user
  explicitly asked for them or a reviewer asked about a specific commit.
- Absolute local paths, `file://` URLs, disposable worktree names, and
  local-only tool paths.
- Em dashes (U+2014). Use commas, colons, parentheses, or separate sentences.
  The parent publishes reviewer bytes unchanged, so a body that contains one
  must be fixed by the reviewer before acceptance, not edited at publication.
- Packet-only fields, `artifact:` markers, severity or confidence tokens, lens
  names, review-tool or harness names, and execution-log narration.

### Guidance style

Outcome-based guidance is the default. Add an exact code suggestion only when
the current source was rechecked and the edit is local, mechanical, complete,
aligned with one authoritative same-class convention, and does not choose among
materially different safe designs. Concurrency, lifecycle, cross-layer,
test-synchronization, and ownership decisions normally require a required
outcome and its proof rather than a speculative patch.

## Review Summary Body

The review summary is the main PR review body for the selected `COMMENT` or
`REQUEST_CHANGES` event.

- Keep the tone direct, professional, and warmly conversational.
- Avoid machine-like boilerplate such as "I have completed a thorough,
  maintainer-grade code review".
- Break it into clean, scannable sections with clear headers and bullets, for
  example `Verdict`, `What I checked`, and `Pending Verification`, rather than
  dense paragraphs.
- It must not contradict the verdict, findings, or `Pending Verification` of the
  packet it belongs to.
- The same forbidden-content list above applies.

## Author Replies

When replying as the PR author to an existing review thread:

- Do not use Conventional Comments labels or severity decorations.
- Answer the reviewer's actual question or concern directly: state the relevant
  fact, changed behavior, or reason for retaining the behavior.
- Use normal maintainer prose. Do not prepend canned dispositions such as
  `Fixed.`, `No code change needed:`, or `Already addressed:`, or introduce the
  topic with narration such as `For the architecture question:`. Comment
  classification belongs in working notes, not in the public reply.
- Include only rationale or concise validation that helps answer that concern.
  Use short paragraphs for separate points; simple replies need no headings
  or labeled sections.
- Before posting a batch, read each reply against its root comment. Remove
  openings that merely announce a triage decision instead of answering it.
  If wording repeats across several owned replies, edit every affected reply
  in place instead of adding correction comments.
- Do not include transient commit hashes. If an owned reply already contains a
  SHA-like reference, edit the reply to remove it before closing the
  review-comment task.

## Machine-Enforced Subset

`RPPA-011` in `scripts/dev/lib/reviewer_packet_validator.rb` checks the
deterministic subset of this file against decoded review-comment Body and
Summary values. The full comment contract still requires reviewer
judgment and focused fixture coverage.

| Rule | Enforced on |
| --- | --- |
| First line matches a backticked Conventional Comment label with a blocking decoration | every inline comment body |
| No common absolute local path rooted under `/home`, `/Users`, `/tmp`, or `/var`, and no `file://` URL | every inline comment body and the summary body |
| No em dash (U+2014) | every inline comment body and the summary body |

Required parts, evidence economy, tone, emoji avoidance, and commit-identifier
exceptions depend on meaning and context. The reviewer enforces those rules;
the validator does not pretend to decide them. A passing validation is not
evidence that a comment is well written.
