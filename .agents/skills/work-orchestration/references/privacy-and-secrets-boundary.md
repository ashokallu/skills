<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (initial privacy and secrets boundary lane) -->

# Privacy And Secrets Boundary

```text
Type: decision gate
Use when: secrets, credentials, personal/customer data, private payloads, logs,
          screenshots, database rows, or sensitive operational evidence may be handled
Skip when: evidence is public/non-sensitive and no sensitive derivative will be created
Owns: sensitivity classification and rules for inspection, quotation, storage,
      delegation, commit, attachment, publication, and deletion of sensitive evidence
Does not own: domain analysis or permission to access data not otherwise authorized
Allowed side effects: bounded classification and redaction planning
Inputs: data class, source, purpose, destination, recipient/tool, and retention need
Exit states: safe boundary established, reroute, blocked, stop
Outputs: sensitivity class, allowed transports/persistence, redaction, and next owner
Re-enter when: data class, destination, recipient, purpose, or retention changes
```

Use this lane before a route reads, quotes, stores, forwards, delegates, commits,
or publishes material that may contain secrets, credentials, tokens, cookies,
session identifiers, personal data, customer data, private payloads, internal
operational logs, screenshots, crash reports, database rows, or proprietary
third-party output.

This lane does not own product implementation or security verdicts. It decides
what data may be inspected, what must be redacted or summarized, where evidence
may be persisted, and which owner may consume the sanitized result.

## Use For

- reading env files, credential files, secret manager output, OAuth/session
  material, cookies, JWTs, API keys, service-account data, SSH keys, or bearer
  tokens
- inspecting production, staging, support, Sentry, logging, monitoring,
  analytics, replay, screenshot, database, or customer-provided evidence that
  may include personal or private payload data
- preparing PR text, docs, tests, fixtures, comments, handoffs, artifacts, or
  prompts that mention sensitive runtime data
- passing evidence to subagents, external harnesses, plugins, SaaS tools,
  reviewers, or public systems
- deciding whether raw evidence can be quoted, screenshotted, saved, checked in,
  or attached to an issue/PR

## Do Not Use For

- ordinary public docs, repo source files, generated code, or already-redacted
  sample data with no realistic secret or personal payload risk
- security vulnerability review after the data boundary is already safe; route
  that verdict through `reviewer`, `security-auditor`, or the owning
  specialist
- permission decisions for destructive, production-writing, or external writes;
  use `risk-and-side-effects` after this lane defines the data boundary

## Classification

Classify the highest sensitivity present or reasonably possible in the next
phase, not the whole task:

| Class | Examples | Default handling |
| --- | --- | --- |
| Public | public docs, open-source issue text, public API docs | cite or quote normally within source rules |
| Internal | repo-private implementation detail, non-secret config, internal ticket text | summarize when broad; quote only the minimum needed |
| Sensitive operational | logs, traces, request IDs, IPs, tenant IDs, feature flags, internal URLs, support screenshots | inspect narrowly; summarize; avoid raw dumps |
| Personal/customer | names, emails, messages, profile data, classroom/student data, billing/support details, browser replay payloads | minimize fields; aggregate or redact; no raw persistence unless explicitly authorized |
| Credentials/secrets | tokens, cookies, passwords, private keys, secret values, session IDs, service-account keys | never print, paste, commit, attach, or delegate raw values; confirm existence or compare inside the safe surface and report only `same` or `different` |

When uncertain, choose the higher class until evidence narrows it.

## Handling Rules

1. **Need-to-know first:** inspect only fields needed for the current claim or
   next safe action. Do not broaden a query, log window, screenshot set, or file
   read merely because the tool makes it easy.
2. **Redact before transport:** before material leaves the current safe surface
   into chat, PR metadata, docs, tests, artifacts, subagent prompts, external
   tools, or handoffs, replace sensitive values with stable labels such as
   `<redacted-token>`, `<customer-email>`, or `<tenant-id>`. When equality
   comparison is required, compare inside the safe surface and report only
   `same` or `different`; do not emit a derived digest or correlation key.
3. **Summarize payloads:** for logs, events, replays, screenshots, database rows,
   and support reports, report the signal, counts, shape, and relevant fields;
   do not paste full raw payloads, headers, bodies, cookies, stack locals, or
   screenshots with visible private data.
4. **Keep secrets out of repo state:** never write live secrets, personal data,
   private payloads, or raw logs into source files, fixtures, docs, snapshots,
   golden files, PR bodies, comments, or commits. Use synthetic fixtures or
   redacted minimal examples.
5. **Do not transform secrets into new secrets:** do not base64-encode,
   URL-encode, screenshot, chunk, or otherwise repackage a sensitive value as a
   workaround. Treat transformed secret material as still secret.
6. **Avoid accidental echo:** when running commands that may print secrets, use
   safe flags, filtered projections, targeted fields, or local redaction. Avoid
   placing secret values in command arguments, URLs, shell history, process
   titles, CI logs, or reusable environment dumps; use the runtime's approved
   secret input mechanism. If a tool unexpectedly prints a secret, stop copying
   output, note that redaction is required, and route any cleanup through the
   appropriate owner.
7. **Delegation is sanitized by default:** children, external harnesses, and
   reviewers receive only redacted or synthetic evidence unless the selected
   workflow explicitly authorizes the sensitive read and the receiving role is
   appropriate for it. The parent remains responsible for the data boundary.
8. **Persistence needs a reason:** store sensitive-derived evidence only when it
   is needed for reproducibility, review, or operator action. Prefer repo-local
   ignored `tmp/` artifacts with redacted content; never assume artifacts are
   private after handoff.
9. **Publication is stricter than inspection:** material acceptable for a local
   private note may still be unsafe for PR metadata, issue comments, Confluence,
   Slack-like notifications, or public/customer-visible systems.
10. **Escalate real exposure:** if a live secret appears committed, published, or
    shared to an external system, freeze further propagation, route through
    `risk-and-side-effects`, and use the owning security/GitHub/worktree lane for
    containment, rotation, history cleanup, or disclosure steps.

## Output

```markdown
## Privacy And Secrets Boundary
- Decision: PROCEED SANITIZED | REROUTE | ASK | BLOCKED | STOP
- Data class: public | internal | sensitive operational | personal/customer | credentials/secrets
- Evidence needed: <minimum fields or artifacts>
- Allowed handling: <inspect | summarize | redact | aggregate | synthetic fixture | blocked>
- Forbidden handling: <raw quote, raw artifact, commit, public comment, subagent prompt, etc.>
- Redaction plan: <labels, aggregation, screenshot crop/blur, field projection, in-place comparison>
- Persistence boundary: <none | ignored tmp artifact | checked-in synthetic only | external owner>
- Delegation/share boundary: <parent-only | sanitized child packet | specialist with exact scope>
- Next owner: <dispatcher lane or specialist>
- Reopen condition: <sensitivity, transport, target, or permission change>
- Pending Verification: <sensitivity, permission, or redaction gaps>
```

Do not treat this lane as proof that the underlying behavior is safe, fixed, or
compliant. It only makes the evidence safe enough for the next route to consume.
