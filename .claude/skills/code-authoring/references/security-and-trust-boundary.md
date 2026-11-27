<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 -->

# Security And Trust Boundary

Use this lane for auth, permissions, tenant scope, privacy, secrets, sensitive
logs, workflow permissions, dependencies, suspicious network/file/system
access, or supply-chain risk.

This lane is adapted from the Agentics `malicious-code-scan` workflow. Keep the
changed-code suspicious-pattern catalog, but do not copy code-scanning alert
mechanics, fixed three-day windows, cache paths, or bot output protocols into
ordinary code authoring.

For environment key parity, config defaults, and secret reference movement,
also load `environment-config-and-secrets`. For prompt injection, model output
trust, and PII in prompts or vendor payloads, also load
`llm-and-ai-integration`; this lane keeps severity and trust-boundary
judgment.

## Probes

- Does the change alter authentication, authorization, tenant scope, role
  checks, redirects, cookies, sessions, or public API exposure?
- Can input cross a trust boundary into SQL, NoSQL, shell, templates, URLs,
  file paths, SSRF-like fetches, logs, telemetry, or generated output?
- Are secrets, tokens, cookies, PII, saved auth state, or private keys exposed
  through logs, errors, screenshots, artifacts, health endpoints, or PR text?
- Does the change add external network calls, unusual file writes, shell
  execution, obfuscated content, executables, dependency scripts, or workflow
  permission expansion?
- Does a new dependency or action run privileged lifecycle code or change
  supply-chain trust?
- Are environment variables, credentials, or sensitive-looking values encoded,
  serialized, logged, or sent over a new network path?
- Does code appear out of context for the package, such as crypto,
  compression, process spawning, hidden files, or executable artifacts in
  places that do not normally use them?
- Are shell commands built from user-controlled input or writing under
  sensitive paths such as `/etc`, `/sys`, `/proc`, hidden directories, or temp
  locations used for data transfer?
- Are long base64 or hex strings, obfuscated names, unexpected binaries, or
  generated-looking payloads introduced in changed files?

## Rules

- Validate external inputs at the boundary.
- Keep user-facing errors generic and put technical detail in safe logs.
- Never paste raw secrets or sensitive payloads as evidence.
- Security findings need a reachable path and calibrated impact.
- Minimize false positives: unusual code is not suspicious unless context,
  data flow, or privilege makes it relevant.
- Sanitize outputs so alerts, comments, logs, and final responses do not leak
  sensitive values while explaining the path and risk.
- If the safe behavior or blast radius is unclear, stop and route for
  specialist security or owner review before treating the implementation as
  ready.
- For remediation code, write the exploit or abuse path in implementation
  notes before editing: attacker capability, entrypoint, trust boundary,
  vulnerable behavior, and expected blocked behavior.
- For auth, permissions, crypto, PII, or tenant-scope changes, require a human
  or specialist security review before release even when local tests pass.
- When using severity during authoring, calibrate by likelihood and impact.
  Do not mark a risk critical without a reachable exploit path and high impact.
- Run dependency or secret scans when the change adds dependencies, workflow
  permissions, environment variables, auth handling, or suspicious file/network
  behavior. If the scan cannot run, name the unavailable command under
  `Pending Verification`.

## Triage

Use severity only after reachability is clear:

- Critical or high: active exfiltration, backdoor behavior, malicious payload,
  privilege escalation, or highly confident secret exposure.
- Medium: unusual but plausible suspicious behavior that needs owner review.
- Low or info: minor anomaly or style inconsistency; record as residual risk
  rather than blocking code authoring.
