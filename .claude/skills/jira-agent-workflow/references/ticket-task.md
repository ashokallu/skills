<!-- markdownlint-disable MD013 -->

# Task Template

For work with no direct user-facing outcome — setup, configuration, migration, infrastructure, chores, spikes.

## Summary

`[Task description]: brief, clear summary`

Example: `E2E artefacts: host GitHub Actions test output via Tessen`

## Description skeleton

```
[What needs to be done, and the context or purpose behind it.]

*Steps to Complete:*
# [First actionable step]
# [Second step]
# [Third step]

*Deadline:*
[Target completion date — use [TBC] if not given.]

*Dependencies:*
[Blockers, teams, or work items that must land first — omit if none.]
```

Steps should be actionable enough that someone else on the team could pick the ticket up. If the work is exploratory and the steps aren't knowable yet, say so explicitly rather than inventing a plan.

## Fields

| Field | Notes |
|---|---|
| Priority | DEMO uses `Normal` and similar, not Low/Medium/High — check with `jira_get_field_options` |
| Estimation | Story points or hours |
| Assignee | Person or team responsible |
| Label(s) | Apply only labels the user has named. Common on DEMO: `infrastructure`, `test`, `terraform`, `documentation`, `Learn` |

## Worked example

Summary: `E2E artefacts: host GitHub Actions test output via Tessen`

```
Playwright runs in CI produce HTML reports and traces that are currently only reachable by downloading the workflow artefact zip. Host them through Tessen so a failing run links straight to a readable report.

*Steps to Complete:*
# Request a Tessen bucket and confirm the retention policy for test artefacts.
# Add an upload step to the E2E workflow that publishes the Playwright report after each run.
# Post the resulting URL into the existing failure alert payload.
# Confirm links resolve for both scheduled and pull-request runs.

*Deadline:*
[TBC]

*Dependencies:*
Tessen bucket provisioning.
```

Priority: Normal · Estimation: 3 points · Labels: `infrastructure`, `test`
