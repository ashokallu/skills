<!-- markdownlint-disable MD013 -->

# Collaboration Template

For coordinating several teams toward a shared outcome or date. The distinguishing feature against an Epic is that the work is owned by different teams and the ticket exists to keep them aligned.

## Summary

`[Collaboration topic]: concise title`

Example: `Test environment: stand up app.test.example.com across Learn, PRE and Ops`

## Description skeleton

```
[Purpose and context of the collaboration, and the outcome it aims for.]

*Objective:*
[The goal, and the value it delivers to the teams or project.]

*Involved Teams/People:*
* *[Team]*: [responsibilities]
* *[Team]*: [responsibilities]

*Action Items:*
# [Task, with owner and date]
# [Task, with owner and date]

*Timeline:*
*Start Date*: [date]
*End Date*: [date]

*Milestones:*
* [Milestone: date]
* [Milestone: date]

*Communication Plan:*
* [Channel and cadence — e.g. weekly status call, daily Slack check-in]
* [Stakeholder reporting]

*Dependencies:*
* [Cross-team inputs or approvals needed]

*Stakeholders:*
* [Name] ([role])
* [Name] ([role])
```

Every action item should have a named owner. An unowned action item on a cross-team ticket is the thing most likely to be missed, so where the user hasn't said who owns something, mark it `[owner TBC]` rather than leaving it implicit.

## Fields

| Field | Notes |
|---|---|
| Assignee | The individual overseeing execution overall |
| Target Start | When the collaboration begins |
| Target End | When the objective should be met |
| Label(s) | Apply only labels the user has named. `coordination` is used on DEMO for cross-team work |

## Worked example

Summary: `Test environment: stand up app.test.example.com across Learn, PRE and Ops`

```
Validating deploys before staging requires a dedicated test environment reachable on a real hostname. The Terraform and application work sits with the Example App team, but DNS and load balancer configuration are owned elsewhere, so the three strands have to land in order.

*Objective:*
Have app.test.example.com resolving to the test Cloud Run services, with a full deploy-and-E2E cycle demonstrated against it.

*Involved Teams/People:*
* *Example App*: Terraform for the test environment, Cloud Run services, E2E suite configuration.
* *PRE*: DNS record for app.test.example.com pointing at the HAProxy load balancers.
* *Ops*: HAProxy backend configuration in genesis-ops-connect-salt.

*Action Items:*
# Rewrite the test environment Terraform and apply it — Example App, [date TBC].
# Submit the PRE team's DNS request form — [owner TBC], blocks everything downstream.
# Add the HAProxy backend once DNS resolves — Ops, [date TBC].
# Add {{test}} as a recognised environment in the E2E suite config — Example App.
# Validate one full deploy and E2E cycle end to end — Example App.

*Timeline:*
*Start Date*: [TBC]
*End Date*: [TBC]

*Milestones:*
* Terraform applied and services booting cleanly: [TBC]
* Hostname resolving through HAProxy: [TBC]
* First green deploy-and-E2E cycle: [TBC]

*Communication Plan:*
* Progress tracked in the team's daily standup.
* Cross-team blockers raised in the shared Slack channel rather than DMs, so the handoffs stay visible.

*Dependencies:*
* DNS request turnaround sets the critical path — the HAProxy and validation steps cannot start until it completes.

*Stakeholders:*
* [TBC] (Engineering Manager, Example App)
* [TBC] (PRE team representative)
```

Assignee: [TBC] · Labels: `coordination`
