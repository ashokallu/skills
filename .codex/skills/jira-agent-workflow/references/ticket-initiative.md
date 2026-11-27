<!-- markdownlint-disable MD013 -->

# Initiative Template

For a business-level effort spanning teams and quarters, usually containing several epics and carrying measurable targets.

## Summary

`[Initiative name]: concise title reflecting the purpose`

Example: `Release automation: move Learn to unattended multi-daily releases`

## Description skeleton

```
[High-level summary: context, purpose, and why this is being undertaken now.]

*Goal:*
[The primary objective and the value it delivers.]

*Scope*
*In scope:*
* [Deliverable or process]
* [Deliverable or process]

*Out of scope:*
* [Explicit exclusions — omit if none.]

*Success Criteria:*
* [Measurable target — percentage, metric, timeframe]
* [Qualitative measure where a number isn't available]

*Stakeholders:*
* [Role]: [Name]
* [Role]: [Name]

*Risks:*
* [Risk, with mitigation where known — omit section if none.]

*Dependencies:*
* [Cross-team, vendor or approval dependencies — omit if none.]

*Timeline:*
* *Start Date:* [date]
* *End Date:* [date]
* *Key Milestones:*
** [milestone: date]
```

Success criteria carry the weight here. If the user hasn't given numbers, ask rather than inventing targets — a fabricated "40% reduction" can end up quoted back in a business review.

## Fields

| Field | Notes |
|---|---|
| Assignee | Person accountable for the initiative |
| Target Start | When work begins |
| Target End | When it should be complete |

## Worked example

Summary: `Release automation: move Learn to unattended multi-daily releases`

```
Learn releases are currently gated on a person being available to run and watch them, which caps release frequency and concentrates risk in large batches. This initiative takes the platform through staged automation until releases run unattended several times a day.

*Goal:*
Reduce the cost and risk of shipping so that a merged change reaches production the same day without manual coordination.

*Scope*
*In scope:*
* Automated deployment pipeline covering test, staging and production.
* Ephemeral environments for validating pull requests before merge.
* E2E smoke tests gating each promotion, with actionable failure alerts.
* Progressive rollout and automated rollback on failed health checks.

*Out of scope:*
* Application feature work.
* Migration of services owned outside the Example App team.

*Success Criteria:*
* Production releases run without manual intervention on the happy path.
* Multiple releases per working day sustained over a full sprint.
* Failed releases roll back automatically without a human in the loop.
* No increase in production incident rate across the transition.

*Stakeholders:*
* Engineering Manager: [TBC]
* Senior Engineering Manager: [TBC]
* Project Manager: [TBC]

*Risks:*
* Automated releases amplify a bad change faster than a human would catch it. Mitigation: smoke tests gate each promotion and rollback is automatic on health-check failure.
* Knowledge concentrated in individual engineers. Mitigation: each phase lands with a TDD and runbook before it is relied on.

*Dependencies:*
* Infrastructure provisioning for ephemeral environments.
* DNS and load balancer changes owned by the PRE team.

*Timeline:*
* *Start Date:* [TBC]
* *End Date:* [TBC]
* *Key Milestones:*
** Phase deliverables tracked as separate epics, each with its own TDD.
```

Assignee: [TBC] · Target Start: [TBC] · Target End: [TBC]
