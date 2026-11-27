<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-06 (linked environment readiness and new authoring risk lanes) -->

# Diagnose

```text
Type: owning lane
Use when: behavior is wrong or a failure signal needs root-cause analysis
Skip when: the cause/direction is already established and the next phase is
           implementation
Owns: evidence-driven reproduction, hypothesis ranking, root-cause isolation, and the
      smallest proof-backed fix direction
Does not own: implementation, publication, or production mutation
Allowed side effects: read-only investigation and explicitly routed local reproduction
Inputs: symptom, expected behavior, exact target/environment, and available evidence
Exit states: diagnosed, narrowed, not reproduced, blocked
Outputs: evidence chain, root cause or ranked hypotheses, and next proof/action
Re-enter when: evidence changes the failure class, target, or required boundary
```

Use this skill to move from symptom to root cause with evidence. The main output is a tight feedback loop that can fail before the fix and pass after the fix.

Do not use this skill when the symptom is already diagnosed or the fix is
already validated. When no unexplained symptom remains, route to the repo's
publication or handoff workflow instead. That path does not need root-cause
diagnosis unless a new failure appears.

When the user shares a Sentry issue or production exception and asks only for a
workflow plan or "how would you fix it" answer before implementation, load
[workflow-synthesis-example.md](workflow-synthesis-example.md) first. Return to this lane for
root-cause work once execution starts or when the plan phase needs diagnosis
detail beyond the synthesis example.

## Default Posture

- If the symptom may be caused by local setup, toolchain, Docker, env files,
  generated state, cache, queue, or service startup, use
  [environment-tooling.md](environment-tooling.md) to
  classify the blocker before changing product code.
- If the symptom came from an external system, production signal, Sentry event,
  support report, or monitoring alert, establish privacy/source and external
  target boundaries before live reads. Use `risk-and-side-effects` only when a
  later read or mutation crosses its trigger.
- Reproduce the reported symptom before changing code.
- Prefer the smallest deterministic loop that exercises the real failure path.
- Search repo skills first with the concrete error text, command, issue name, or integration name.
- Verify the exact user claim. If the report says "X breaks Y", gather
  evidence for that relationship instead of proving a nearby failure.
- For substantial read-only mapping, log-source inventory, caller/test
  discovery, or validation-command discovery, consider `delegation` only when
  its actual entry triggers and net-benefit test are satisfied. Parent-owned
  investigation is the default; do not add a scout or a skip-reason ceremony
  merely to conserve context.
- For build, dependency, bootstrap, tooling, or test failures, first decide
  whether product code was reached. If not, route through `environment-tooling`.
  If product code was reached, read the exact error, relevant package or module
  config, lockfiles, README notes, and repo skill before installing,
  uninstalling, upgrading, replacing, or repairing tooling.
- Classify blockers as product, repo config, local machine, credential, VPN,
  sandbox, or external infrastructure before treating them as code defects. Use
  the next-best validation surface when the primary one is environment-blocked.
- If repeated searches, reads, or repro attempts stop narrowing the problem,
  state the blocker and switch strategy or ask for the smallest missing input.
- Keep debug artifacts under a task-scoped `tmp/` path only when the active
  local-reproduction boundary authorizes that write. Record ownership and
  cleanup; otherwise keep the evidence in the current response/context.
- Do not use production writes or externally visible actions unless the user explicitly approves them.
- Never leave temporary debug logs, probes, flags, broad catch blocks, auth
  bypasses, debug endpoints, or committed evidence artifacts behind.
- For auth, permissions, data integrity, security, or production-impact bugs,
  pause before fixing if the safe behavior or blast radius is unclear. Name the
  needed evidence or specialist route instead of guessing.

## Reproduction Exceptions And Escape Hatch

Reproduction is normally required before hypotheses or fixes. You may skip a
runtime repro only when all of these are true:

- the defect is statically obvious from source or config
- the fix is mechanical and low risk
- a regression check can still prove the corrected behavior
- the report says `Skipped reproduction` with the concrete reason

If three distinct repro attempts fail, stop repeating the same loop. Record
what was tried, what evidence is missing, and the smallest next artifact or
input needed, such as exact steps, data state, environment, browser/device, log,
trace, fixture, or failing command output.

## Collaborator Routing

Use `delegation` and `cross-harness-workflow` only when the user requests a
collaborator or a bounded second harness materially improves diagnosis. Honor an
explicitly named harness when available. Otherwise select from current verified
capabilities; do not encode durable model/vendor preferences in this lane.
Sanitize any logs, repro notes, patches, or `tmp/**` evidence before transport,
and pass artifacts only through the collaboration workflow's current
secret-safe mechanism. A collaborator's hypothesis remains advisory until the
parent verifies it against the target.

## Browser And E2E Routing

For E2E, Playwright, browser, local auth, visual-regression, retry-healed
workflow, or GitHub Actions E2E flake classification, load `browser-e2e`
and let that skill choose the flakiness, Playwright CLI, or Playwright MCP
reference. Keep this diagnosis skill as the parent loop only when the root
cause also spans non-browser systems.

Do not duplicate the E2E workflow inventory, artifact rules, local-auth setup,
or Playwright command catalog here; those belong in `browser-e2e` and its
one-hop references so browser/E2E work can lazy-load only the lane it needs.

For UI symptoms, capture concrete before/after evidence when practical:
visible steps, expected versus actual behavior, console or network errors, DOM
or component state, screenshot or trace paths, and browser/device coverage. If
root cause is ambiguous, eliminate data/API and network behavior before blaming
component state or CSS. Mark untested browsers or devices `Pending
Verification`.

## Build The Loop

Try the cheapest loop that proves the user-visible symptom:

1. Targeted unit or integration test at the real behavior surface
2. Existing local CI-equivalent command from `.github/workflows/**` or the relevant repo skill
3. HTTP or CLI repro script under `tmp/` with an explicit timeout
4. Playwright or browser MCP flow for UI, auth, routing, console, or network behavior
5. Captured artifact replay: logs, HAR, event payload, DB fixture, trace, or CI artifact
6. Repeated stress loop for flakes, with failure rate recorded
7. Differential or bisection loop when the symptom appears between two commits, configs, datasets, or environments

If no loop is possible, say `Pending Verification`, list what was tried, and name the smallest artifact or access needed next.

## Diagnose

1. Confirm the loop reproduces the same symptom the user reported.
2. Capture the exact evidence: command, failure text, route, request, trace, timing, or affected data.
3. Write 2-5 ranked hypotheses with a falsifiable prediction for each.
4. Test one hypothesis at a time. Prefer debugger, structured inspection, targeted logs, or query plans over broad logging.
5. Tag temporary logs or probes with a unique prefix and remove them before handoff.
6. Convert the minimized repro into a regression test when there is a real seam for it.
7. Route the smallest proven fix to `code-authoring`. After the owning
   authoring phase returns a stable target, rerun the original loop and the
   targeted regression check through `validation`.
8. Before handoff, check changed files for debug leftovers and explain any
   remaining artifacts under `Pending Verification` or remove them.

## Runtime Routing

- PR CI or workflow failure: use the `pr-workflow` local-ci lane; for PR
  worktree reproduction use the `pr-workflow` ci-worktree lane.
- Browser, local auth, UI automation, Playwright, visual-regression, or E2E
  flake classification: use `browser-e2e` for the browser/E2E lane.
  Keep this diagnose lane as the parent loop only when the root cause spans
  non-browser systems too.
- Sanity CMS behavior: use the sanity-schema lane in `code-authoring`.
- Backend SQLC, migrations, mocks, or generated code: use the backend-codegen or
  SQL/migrations lane in `code-authoring` as appropriate.
- API contract, webhook, SDK/client, auth, permission, feature flag, resilience,
  observability, cache, concurrency, job, queue, or scheduler failures: route the
  fix through the matching `code-authoring` lane after the root cause is
  proven.
- Staging Mongo access or Mongo 3.2 behavior: use `readonly-data-access`.
- Need independent or second-model review after evidence exists: return to
  `review-routing`/`delegation` and verify the current reviewer capability; do
  not hardcode a vendor-specific helper or model here.

## Output

```text
Diagnosis result: DIAGNOSED | NARROWED | NOT REPRODUCED | BLOCKED
Target and symptom:
Repro status and loop:
Evidence and freshness:
Hypotheses tested:
Root cause or ranked remaining hypotheses:
Recommended fix direction or owning authoring result:
Regression proof required:
Debug artifacts and cleanup ownership:
Next owner / re-entry condition:
Pending Verification / remaining risk:
```

Use `Pending Verification` for any claim not proven by the loop or a cited
artifact. A diagnosis result is not permission to edit, publish, or operate.
