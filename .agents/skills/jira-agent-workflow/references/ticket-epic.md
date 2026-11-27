<!-- markdownlint-disable MD013 -->

# Epic Template

For a body of work that needs breaking down into several stories and tasks.

## Summary

`[Epic name]: clear, concise title`

Example: `Decommission legacy Example App infrastructure`

## Description skeleton

```
[What the epic focuses on and the problem or opportunity it addresses — enough context for a stakeholder to understand why it matters.]

*Goal:*
[The primary outcome, framed as value to the business or users.]

*Scope*
*In scope:*
* [Deliverable]
* [Deliverable]

*Out of scope:*
* [Explicitly excluded work — omit the sub-section if there is none, but naming exclusions is the main defence against scope creep.]

*Acceptance Criteria:*
* [Specific, measurable condition]
* [Functional, non-functional or edge case condition]

*Definition of Done:*
* All related stories and tasks are complete, tested and deployed.
* [Any epic-specific closing conditions.]
```

## Fields

| Field | Notes |
|---|---|
| Priority | Relative to other backlog work |
| Assignee | Person driving the epic to completion |
| Related Stories/Tasks | The breakdown — list names or links |
| Timeline | Start date, end date, key milestones |
| Label(s) | Apply only labels the user has named. Common on DEMO: `infrastructure`, `legacy-decommission`, `Learn` |

## Worked example

Summary: `Decommission legacy Example App infrastructure`

```
Learn now serves production traffic from the current platform, but the preceding stack is still running: unused Cloud Run services, orphaned buckets, DNS records and HAProxy backends pointing at retired hosts. It carries cost and on-call surface for no benefit, and every stale record is a chance to route traffic somewhere wrong.

*Goal:*
Remove the legacy stack entirely so infrastructure spend and operational surface reflect what is actually serving traffic.

*Scope*
*In scope:*
* Inventory every legacy service, bucket, DNS record and load balancer backend.
* Confirm zero live traffic on each before removal.
* Remove resources through Terraform rather than console edits, so state stays accurate.
* Retire the corresponding HAProxy backends.

*Out of scope:*
* Data migration off legacy stores — completed under a separate epic.
* Changes to the current production topology.

*Acceptance Criteria:*
* Each decommissioned resource shows zero requests over a 30-day observation window before removal.
* Terraform plan is clean; no orphaned resources remain outside state.
* No increase in 4xx or 5xx rates on the current platform after each removal step.

*Definition of Done:*
* All related tasks complete and applied to production.
* Infrastructure documentation updated to describe only the current topology.
* Cost reduction confirmed against the following month's billing.
```

Related: Task — inventory legacy resources · Task — verify traffic before removal · Task — retire HAProxy backends · Task — update infrastructure docs

Timeline: [TBC] · Labels: `infrastructure`, `legacy-decommission`
