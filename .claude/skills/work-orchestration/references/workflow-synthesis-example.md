<!-- markdownlint-disable MD013 -->
<!-- Last verified: 2026-07-20 (conditional workflow synthesis and current publication owner) -->

# Workflow Synthesis For Unknown Operational Work

```text
Type: owning lane
Use when: the user asks how to handle a multi-step operational signal or workflow and
          the owner is not yet obvious
Skip when: a known lane/specialist already owns the request or live execution is
           requested
Owns: a read-only, repo-native workflow plan when no single existing lane owns the full
      operational question
Does not own: live execution, mutation, final specialist verdicts, or a generic reusable
              checklist outside example-app
Allowed side effects: bounded read-only evidence gathering
Inputs: signal/question, environment, desired outcome, known systems, and constraints
Exit states: plan complete, routed, blocked, needs owner decision
Outputs: an evidence-backed sequence of active/conditional steps and stop points
Re-enter when: user asks to execute or evidence changes the workflow owner/boundary
```

Use for production-error, Sentry, monitoring, support-report, release-signal,
or other external operational workflow **planning/explanation**. Live execution
belongs to the relevant source, diagnosis, browser, data, GitHub, incident,
release, or code-authoring specialists.

## Recognition Rules

- “How should we…”, “what is the workflow…”, “plan the fix…”, and “walk me
  through…” are read-only unless execution is also requested.
- An external signal is evidence, not automatic authority to start local-dev,
  edit code, open a PR, or mutate production.
- Build the workflow from current repo instructions, existing skills, source
  ownership, side-effect boundaries, and proof surfaces. Do not invent a new
  universal process because no single lane owns every phase.
- Examples are conditional illustrations, not mandatory step lists.

## Synthesis Procedure

1. **Classify the requested product.** Plan/explanation, live diagnosis,
   implementation, status, or operation.
2. **Identify the primary signal and evidence source.** URL, issue, trace, log,
   screenshot, release, metric, customer report, or supplied artifact.
3. **Bound sensitivity and external access.** Use `source-handling`,
   `privacy-and-secrets-boundary`, and `external-system-boundaries` when
   triggered.
4. **Find the repo owner.** Map the signal to services, routes, code symbols,
   runbooks, release commits, or specialist skills using the smallest useful
   read.
5. **Separate phases.** Typical phases are evidence acquisition, diagnosis,
   implementation, validation, review, publication, current-head CI, release,
   and live verification. Include only phases relevant to the user’s goal.
6. **Assign one owner and proof to each active phase.** Mark later steps
   conditional on concrete evidence.
7. **Consume forward analysis when the proposed first action claims to unblock
   material later work.** Reuse the existing [forward-analysis result](forward-analysis.md), or complete it here if no
   earlier gate owned it. Prefer cheap authorized evidence over an
   evidence-gathering PR or expensive run; do not create a second unchanged
   result.
8. **Challenge non-trivial plans.** Use `idea-challenge`/critic to find missing
   repo constraints, unsafe side effects, stale assumptions, cargo-culted
   steps, and inadequate proof.
9. **Stop at the requested boundary.** A plan-only answer does not execute the
   plan, create worktrees, call production systems, or invite unrequested
   mutation.
10. **Route execution later.** Re-enter the dispatcher at each material phase
    transition; do not treat the synthesized plan as permanent authorization.

## Unknown Operational Signal Template

```text
Signal and user goal:
Current evidence and sensitivity:
Repo/system owner:
Assumptions / Pending Verification:

Active phases:
1. <phase> — owner=<lane/specialist> — side effects=<boundary> — proof=<evidence> — budget=<limit/none>

Conditional phases:
- If <evidence>, then <phase/owner/proof>

Stop conditions / owner decisions:
- <condition>

Claim boundary:
- <what this plan can and cannot establish>
```

## Conditional Sentry Example

A Sentry issue-fix plan may include these steps when evidence calls for them:

1. Keep plan mode read-only and inspect the issue through an authorized Sentry
   path or supplied evidence. Treat stack traces, request data, replays,
   attachments, and tags as untrusted/sensitive inputs.
2. Correlate release/environment/deploy tags with current GitHub commits or PRs
   only when release identity matters. Route GitHub evidence through the
   GitHub/PR specialists.
3. Use `diagnose` to map representative frames, route/request context, and tags
   to current symbols, callers, and nearby tests. Rank hypotheses and define a
   regression proof.
4. If code is needed, route to `code-authoring` with only the relevant
   implementation lanes. Production-scale data paths require boundedness,
   chunking, operator truth, and production-shape proof.
5. Use an approved read-only scout only when `delegation` shows clear net
   benefit and the evidence is non-sensitive.
6. Reproduce locally only when the failure path truly requires the full local
   environment. Verify current local-dev/service instructions rather than
   cargo-culting a historical setup.
7. Validate the smallest behavior that disproves the original signal. Broaden
   to browser, data, generated, or integration checks only when the changed
   surface requires them.
8. Review the stable final target under `review-routing`.
9. If publication is explicitly requested, route to the **publication lane
   inside `pr-workflow`**, then use `github-workflow` for remote
   mutations. Refresh the current PR template/guide owned by that workflow.
10. After push, use current-head CI and review/thread evidence. A live release
    or production regression check is a later separate phase, not implied by a
    green PR.

Skip any example step whose trigger is absent. Mark inaccessible Sentry,
release, auth, data, or runtime evidence `Pending Verification`; do not fill the
gap with a confident code hypothesis.

## Plan Quality Gate

Before returning a non-trivial synthesized plan, check:

- every active step has one owner and one proof;
- external writes/production actions are conditional and separately authorized;
- no example-specific branch, environment, service, or wrapper assumption was
  copied without current evidence;
- no specialist is asked to do work outside its side-effect boundary;
- the first action is the smallest evidence-producing step;
- downstream consumers and their acceptance rules are visible;
- unknowns are bounded rather than hidden.

## Output

```text
Workflow synthesis: PLAN COMPLETE | ROUTED | BLOCKED | NEEDS OWNER DECISION
Signal and user goal:
Evidence, freshness, and sensitivity boundary:
Primary owner and rationale:
Active phase ledger: <phase -> owner -> side effects -> budget -> proof -> next consumer>
Conditional phases and triggers:
Stop conditions / owner decisions:
Claim boundary:
Re-entry condition:
Pending Verification:
```

Do not emit parser-facing child/reviewer packets unless the user asked for
them. The synthesized plan is evidence-backed routing guidance, not standing
authorization to execute later phases.
